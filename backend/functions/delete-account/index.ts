// Permanent account deletion, callable only by the account's own owner.
//
// The app already deletes its own rows under row-level security before calling
// this, but an auth user can only be erased with the service-role key. Apple
// requires in-app account deletion to actually remove the account — leaving the
// auth record behind would also let the same email collide on a later sign-up.
//
// Order here is deliberate: verify the caller's session, delete any remaining
// data rows with admin privileges (so nothing is orphaned if the client-side
// pass partially failed), then delete the auth user last. Deleting the user
// first would invalidate the session mid-operation.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (authHeader.length === 0) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Identity comes from the verified token only — never from the request
    // body, or one signed-in user could delete another's account.
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Sweep every table that holds anything belonging to this person, so a
    // partially-failed client-side delete cannot leave data behind.
    for (const table of ["check_ins", "experiments", "doctor_preps", "saved_articles"]) {
      const { error } = await admin.from(table).delete().eq("user_id", user.id);
      if (error) throw error;
    }
    for (const table of ["entitlement_log", "entitlements"]) {
      const { error } = await admin.from(table).delete().eq("user_id", user.id);
      if (error) throw error;
    }
    const { error: profileError } = await admin.from("profiles").delete().eq("id", user.id);
    if (profileError) throw profileError;

    // Last, because this invalidates the session that authorised it.
    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError) throw deleteError;

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Account deletion failed:", err);
    // The client treats a failure as "nothing has been erased yet" and keeps
    // the local copy intact, so a retry is always safe.
    return new Response(JSON.stringify({ error: "Deletion failed" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
