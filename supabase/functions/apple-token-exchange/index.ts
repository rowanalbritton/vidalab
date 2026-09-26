import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { exchangeAuthorizationCode, isAppleConfigured } from "../_shared/apple.ts";

// Called by the app right after Sign in with Apple, with the one-time
// authorization code from that sign-in. Stores Apple's refresh token so
// delete-account can revoke it later (Guideline 5.1.1(v)).
//
// Never fails the sign-in: every outcome is a 200 with `stored` saying whether
// a token was kept, because a member is already signed in by the time this
// runs and there's nothing useful for them to retry.

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Content-Type": "application/json"
};

function reply(body: Record<string, unknown>, status = 200) {
    return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

Deno.serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (req.method !== "POST") return reply({ error: "Method not allowed." }, 405);

    const authorization = req.headers.get("Authorization");
    if (!authorization) return reply({ error: "Authentication required." }, 401);

    const supabaseURL = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseURL || !anonKey || !serviceRoleKey) {
        return reply({ error: "Server configuration error." }, 500);
    }

    const memberClient = createClient(supabaseURL, anonKey, {
        auth: { autoRefreshToken: false, persistSession: false },
        global: { headers: { Authorization: authorization } }
    });
    const { data: userData, error: userError } = await memberClient.auth.getUser();
    if (userError || !userData.user) return reply({ error: "Authentication required." }, 401);

    if (!isAppleConfigured()) return reply({ stored: false, reason: "not_configured" });

    let code = "";
    try {
        const body = await req.json();
        code = typeof body?.code === "string" ? body.code : "";
    } catch {
        // Fall through to the empty-code reply.
    }
    if (!code) return reply({ stored: false, reason: "missing_code" });

    try {
        const refreshToken = await exchangeAuthorizationCode(code);
        if (!refreshToken) return reply({ stored: false, reason: "exchange_failed" });

        const serverClient = createClient(supabaseURL, serviceRoleKey, {
            auth: { autoRefreshToken: false, persistSession: false }
        });
        const { error } = await serverClient.from("apple_sign_in_tokens").upsert({
            user_id: userData.user.id,
            refresh_token: refreshToken,
            updated_at: new Date().toISOString()
        });
        if (error) throw error;

        return reply({ stored: true });
    } catch (error) {
        console.error("apple-token-exchange failed", error);
        return reply({ stored: false, reason: "server_error" });
    }
});
