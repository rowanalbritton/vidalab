import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Content-Type": "application/json"
};

Deno.serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (req.method !== "POST") {
        return new Response(JSON.stringify({ error: "Method not allowed." }), { status: 405, headers: corsHeaders });
    }

    const authorization = req.headers.get("Authorization");
    if (!authorization) {
        return new Response(JSON.stringify({ error: "Authentication required." }), { status: 401, headers: corsHeaders });
    }

    const supabaseURL = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseURL || !anonKey || !serviceRoleKey) {
        return new Response(JSON.stringify({ error: "Server configuration error." }), { status: 500, headers: corsHeaders });
    }

    const memberClient = createClient(supabaseURL, anonKey, {
        auth: { autoRefreshToken: false, persistSession: false },
        global: { headers: { Authorization: authorization } }
    });
    const { data: userData, error: userError } = await memberClient.auth.getUser();
    if (userError || !userData.user) {
        return new Response(JSON.stringify({ error: "Authentication required." }), { status: 401, headers: corsHeaders });
    }

    const userID = userData.user.id;
    const serverClient = createClient(supabaseURL, serviceRoleKey, {
        auth: { autoRefreshToken: false, persistSession: false }
    });

    try {
        for (const table of [
            "ios_checkin_events", "daily_checkins", "check_ins", "experiments",
            "experiment_logs", "doctor_preps", "appointments", "treatments",
            "favorites", "saved_articles", "sync_keys", "google_connections",
            "ai_processing_consents", "agent_conversations", "push_tokens",
            "purchases", "entitlement_log", "entitlements"
        ]) {
            const { error } = await serverClient.from(table).delete().eq("user_id", userID);
            if (error) throw error;
        }

        // Community content keys the owner as `author_id`, not `user_id`, so it
        // cannot ride along in the loop above. Deleting it by the wrong column
        // is not a silent no-op: PostgREST rejects the unknown column, which
        // failed the whole request and left the account undeleted.
        for (const table of ["community_replies", "community_posts"]) {
            const { error } = await serverClient.from(table).delete().eq("author_id", userID);
            if (error) throw error;
        }

        const { error: flagsError } = await serverClient
            .from("community_flags")
            .delete()
            .eq("reporter_id", userID);
        if (flagsError) throw flagsError;

        // Both directions. Rows where this member is the blocker are theirs to
        // take with them; rows where they are the blocked party have to go too,
        // or a deleted account leaves its author_id behind in other people's
        // block lists forever.
        for (const column of ["blocker_id", "blocked_author_id"]) {
            const { error } = await serverClient
                .from("community_blocks")
                .delete()
                .eq(column, userID);
            if (error) throw error;
        }

        const { error: profileError } = await serverClient
            .from("profiles")
            .delete()
            .eq("id", userID);
        if (profileError) throw profileError;

        const { error: deleteError } = await serverClient.auth.admin.deleteUser(userID);
        if (deleteError) throw deleteError;

        return new Response(JSON.stringify({ ok: true }), { status: 200, headers: corsHeaders });
    } catch (error) {
        console.error("delete-account failed", error);
        return new Response(JSON.stringify({ error: "Account deletion failed." }), { status: 500, headers: corsHeaders });
    }
});
