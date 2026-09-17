// RevenueCat webhook → entitlements / entitlement_log writer.
//
// The app reads entitlements but is SELECT-only by design (a client write
// path would mean free Vida+). This function is the only writer: RevenueCat
// posts purchase lifecycle events here, we verify the shared secret, map the
// event to the app's vocabulary, and upsert the user's entitlement row plus
// an append-only log row.
//
// Verification: RevenueCat sends the authorization header value configured in
// its dashboard verbatim, so we compare it against REVENUECAT_WEBHOOK_SECRET
// (set as a project env var, pushed to the function via syncEdgeFunctionSecrets).
// The value may or may not carry a "Bearer " prefix depending on what was
// entered in the dashboard, so both forms are accepted.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

interface RCEvent {
  type: string;
  app_user_id?: string | null;
  aliases?: string[] | null;
  product_id?: string | null;
  transaction_id?: string | null;
  expiration_at_ms?: number | null;
  event_timestamp_ms?: number;
  store?: string | null;
  environment?: string | null;
}

interface Mapping {
  status: string;
  tier: string;
}

// Maps RevenueCat event types onto the app's EntitlementStatus values.
// Anything unmapped is logged but never touches the entitlement row.
function mapEvent(type: string): Mapping | null {
  switch (type) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "PRODUCT_CHANGE":
    case "UNCANCELLATION":
      return { status: "active", tier: "plus" };
    case "BILLING_ISSUE":
      return { status: "grace", tier: "plus" };
    case "CANCELLATION":
      // Auto-renew turned off; access continues until expiry.
      return { status: "cancelled", tier: "plus" };
    case "EXPIRATION":
      return { status: "expired", tier: "free" };
    case "REFUND":
    case "REFUND_REVERSAL":
      return { status: "revoked", tier: "free" };
    case "REFUND_REVERSED":
      return { status: "active", tier: "plus" };
    default:
      return null;
  }
}

// EntitlementSource in the app is appStore/promo only; anything unexpected
// still maps to appStore because iOS is the only real store here.
function mapSource(store: string | null | undefined): string {
  if (store === "promotional") return "promo";
  return "appStore";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  if (!secret) {
    console.error("REVENUECAT_WEBHOOK_SECRET not configured — rejecting");
    return new Response(JSON.stringify({ error: "Webhook not configured" }), {
      status: 503,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Fail closed: no valid secret, no writes.
  const provided = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (provided.length === 0 || provided !== secret) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const payload = await req.json();
    const event: RCEvent | undefined = payload?.event;
    if (!event?.type) {
      return new Response(JSON.stringify({ error: "Missing event" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // RevenueCat's "Send test" button from the dashboard.
    if (event.type === "TEST") {
      return new Response(JSON.stringify({ ok: true, test: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // The app links RevenueCat to the Rork user id at sign-in (logIn).
    // Anonymous installs have nothing to attribute events to — skip quietly.
    const userID = event.app_user_id?.startsWith("$RCAnonymousID:")
      ? null
      : event.app_user_id ?? null;
    if (!userID) {
      return new Response(JSON.stringify({ ok: true, skipped: "no attributable user" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Both tables carry an FK to profiles. If the profile row hasn't been
    // written yet (purchase before first sync), accept the event but leave
    // state alone — returning 200 stops pointless retries we can't satisfy.
    const { data: profile } = await admin
      .from("profiles")
      .select("id")
      .eq("id", userID)
      .maybeSingle();
    if (!profile) {
      return new Response(JSON.stringify({ ok: true, skipped: "profile not found" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const source = mapSource(event.store);
    const mapping = mapEvent(event.type);
    const occurredAt = event.event_timestamp_ms
      ? new Date(event.event_timestamp_ms).toISOString()
      : new Date().toISOString();

    const { error: logError } = await admin.from("entitlement_log").insert({
      user_id: userID,
      event: event.type,
      status: mapping?.status ?? null,
      product_id: event.product_id ?? null,
      transaction_id: event.transaction_id ?? null,
      source,
      occurred_at: occurredAt,
    });
    if (logError) throw logError;

    if (mapping) {
      const { error: upsertError } = await admin.from("entitlements").upsert(
        {
          user_id: userID,
          tier: mapping.tier,
          status: mapping.status,
          source,
          product_id: event.product_id ?? null,
          expires_at: event.expiration_at_ms
            ? new Date(event.expiration_at_ms).toISOString()
            : null,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "user_id" },
      );
      if (upsertError) throw upsertError;
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Webhook processing failed:", err);
    // 500 tells RevenueCat to retry — correct for transient DB errors.
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
