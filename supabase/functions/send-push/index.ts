// Sends an APNs notification to one member's devices.
//
// Called by Vida's own scheduled jobs, never by the app, so it requires the
// service-role key rather than a member's session. A member-callable sender
// would let anyone push arbitrary text to any account.
//
// Deliberately narrow: the caller passes a title and body and nothing else.
// There is no template lookup, no health data, and no way to include a symptom
// or score — a lock screen is visible to whoever is holding the phone, and
// guideline 5.1.3 treats what is on it as health data leaving the app.
//
// Required secrets (supabase secrets set ...):
//   APNS_KEY_ID        — the 10-character Key ID of the .p8
//   APNS_TEAM_ID       — the 10-character Apple Developer Team ID
//   APNS_PRIVATE_KEY   — contents of the AuthKey_XXXXXXXXXX.p8, newlines intact
//   APNS_BUNDLE_ID     — the app's bundle identifier, used as apns-topic
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const corsHeaders = {
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Origin": "*",
    "Content-Type": "application/json"
};

const apnsHost = {
    sandbox: "https://api.sandbox.push.apple.com",
    production: "https://api.push.apple.com"
};

type PushRequest = {
    userId: string;
    title: string;
    body: string;
    /// Groups related notifications so a second reminder replaces the first
    /// rather than stacking three of them on the lock screen.
    collapseId?: string;
};

/// APNs provider tokens are valid for up to an hour. Cached because minting one
/// per send would re-import the signing key on every notification.
let cachedToken: { value: string; expiresAt: number } | null = null;

async function providerToken(keyId: string, teamId: string, privateKeyPEM: string): Promise<string> {
    const now = Date.now();
    if (cachedToken && cachedToken.expiresAt > now + 60_000) return cachedToken.value;

    const pkcs8 = privateKeyPEM
        .replace(/-----BEGIN PRIVATE KEY-----/, "")
        .replace(/-----END PRIVATE KEY-----/, "")
        .replace(/\s/g, "");
    const der = Uint8Array.from(atob(pkcs8), (c) => c.charCodeAt(0));
    const key = await crypto.subtle.importKey(
        "pkcs8",
        der,
        { name: "ECDSA", namedCurve: "P-256" },
        false,
        ["sign"]
    );

    const token = await create(
        { alg: "ES256", kid: keyId, typ: "JWT" },
        { iss: teamId, iat: getNumericDate(0) },
        key
    );

    // Refreshed well inside the one-hour limit.
    cachedToken = { value: token, expiresAt: now + 45 * 60 * 1000 };
    return token;
}

function isRequest(value: unknown): value is PushRequest {
    if (!value || typeof value !== "object") return false;
    const request = value as Partial<PushRequest>;
    return typeof request.userId === "string" && request.userId.length > 0
        && typeof request.title === "string" && request.title.trim().length > 0
        && typeof request.body === "string" && request.body.trim().length > 0
        && (request.collapseId === undefined || typeof request.collapseId === "string");
}

Deno.serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (req.method !== "POST") {
        return new Response(JSON.stringify({ error: "Method not allowed." }), { status: 405, headers: corsHeaders });
    }

    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const supabaseURL = Deno.env.get("SUPABASE_URL");
    const keyId = Deno.env.get("APNS_KEY_ID");
    const teamId = Deno.env.get("APNS_TEAM_ID");
    const privateKey = Deno.env.get("APNS_PRIVATE_KEY");
    const bundleId = Deno.env.get("APNS_BUNDLE_ID");
    if (!serviceRoleKey || !supabaseURL || !keyId || !teamId || !privateKey || !bundleId) {
        return new Response(JSON.stringify({ error: "Server configuration error." }), { status: 500, headers: corsHeaders });
    }

    // Constant-time-ish check against the service-role key. This function is
    // for Vida's schedulers only; a member's JWT must not reach it.
    const authorization = req.headers.get("Authorization") ?? "";
    if (authorization !== `Bearer ${serviceRoleKey}`) {
        return new Response(JSON.stringify({ error: "Not authorised." }), { status: 401, headers: corsHeaders });
    }

    let payload: unknown;
    try { payload = await req.json(); } catch {
        return new Response(JSON.stringify({ error: "Invalid request body." }), { status: 400, headers: corsHeaders });
    }
    if (!isRequest(payload)) {
        return new Response(JSON.stringify({ error: "Provide userId, title and body." }), { status: 400, headers: corsHeaders });
    }

    const serverClient = createClient(supabaseURL, serviceRoleKey, {
        auth: { autoRefreshToken: false, persistSession: false }
    });

    const { data: tokens, error: tokensError } = await serverClient
        .from("push_tokens")
        .select("device_token, environment")
        .eq("user_id", payload.userId)
        .eq("enabled", true);
    if (tokensError) {
        console.error("send-push token lookup failed", tokensError.code);
        return new Response(JSON.stringify({ error: "Could not send." }), { status: 500, headers: corsHeaders });
    }
    if (!tokens || tokens.length === 0) {
        return new Response(JSON.stringify({ sent: 0, retired: 0 }), { status: 200, headers: corsHeaders });
    }

    const jwt = await providerToken(keyId, teamId, privateKey);
    const apsBody = JSON.stringify({
        aps: {
            alert: { title: payload.title, body: payload.body },
            sound: "default"
        }
    });

    let sent = 0;
    const retired: string[] = [];

    for (const row of tokens) {
        const host = apnsHost[row.environment as "sandbox" | "production"] ?? apnsHost.production;
        const headers: Record<string, string> = {
            authorization: `bearer ${jwt}`,
            "apns-topic": bundleId,
            "apns-push-type": "alert"
        };
        if (payload.collapseId) headers["apns-collapse-id"] = payload.collapseId;

        const response = await fetch(`${host}/3/device/${row.device_token}`, {
            method: "POST",
            headers,
            body: apsBody
        });

        if (response.ok) {
            sent += 1;
            continue;
        }

        // 410 Gone means the app was deleted from that device; 400
        // BadDeviceToken means the token was never valid for this topic or
        // environment. Both are permanent, so stop trying that device rather
        // than retrying it forever on every reminder.
        const detail = await response.text();
        if (response.status === 410 || detail.includes("BadDeviceToken")) {
            retired.push(row.device_token);
        } else {
            console.error("send-push rejected", response.status, detail.slice(0, 200));
        }
    }

    if (retired.length > 0) {
        await serverClient.from("push_tokens").delete().in("device_token", retired);
    }

    return new Response(
        JSON.stringify({ sent, retired: retired.length }),
        { status: 200, headers: corsHeaders }
    );
});
