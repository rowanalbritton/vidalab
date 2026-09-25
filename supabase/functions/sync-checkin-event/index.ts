import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Origin": "*",
    "Content-Type": "application/json"
};

const maximumBatchSize = 50;

type CheckInEventRequest = {
    clientId: string;
    localDate: string;
    period: "morning" | "evening";
    timezone?: string | null;
    ciphertext: string;
    schemaVersion: number;
    clientUpdatedAt: string;
    deletedAt?: string | null;
};

function isISODate(value: unknown): value is string {
    return typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value);
}

function isTimestamp(value: unknown): value is string {
    return typeof value === "string" && !Number.isNaN(Date.parse(value));
}

function isEvent(value: unknown): value is CheckInEventRequest {
    if (!value || typeof value !== "object") return false;
    const event = value as Partial<CheckInEventRequest>;
    return typeof event.clientId === "string"
        && event.clientId.length > 0
        && isISODate(event.localDate)
        && (event.period === "morning" || event.period === "evening")
        && (event.timezone === undefined || event.timezone === null || typeof event.timezone === "string")
        && typeof event.ciphertext === "string"
        && event.ciphertext.length > 0
        && Number.isInteger(event.schemaVersion)
        && event.schemaVersion > 0
        && isTimestamp(event.clientUpdatedAt)
        && (event.deletedAt === undefined || event.deletedAt === null || isTimestamp(event.deletedAt));
}

function eventsFrom(value: unknown): CheckInEventRequest[] | null {
    const events = Array.isArray(value)
        ? value
        : (value && typeof value === "object" && Array.isArray((value as { events?: unknown }).events))
            ? (value as { events: unknown[] }).events
            : [value];
    return events.length > 0 && events.length <= maximumBatchSize && events.every(isEvent)
        ? events
        : null;
}

Deno.serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (req.method !== "POST") {
        return new Response(JSON.stringify({ error: "Method not allowed." }), { status: 405, headers: corsHeaders });
    }

    const authorization = req.headers.get("Authorization");
    if (!authorization) {
        return new Response(JSON.stringify({ error: "Authentication required." }), { status: 401, headers: corsHeaders });
    }

    let rawPayload: unknown;
    try { rawPayload = await req.json(); } catch {
        return new Response(JSON.stringify({ error: "Invalid request body." }), { status: 400, headers: corsHeaders });
    }
    const events = eventsFrom(rawPayload);
    if (!events) {
        return new Response(JSON.stringify({ error: "Provide 1 to 50 valid check-in events." }), { status: 400, headers: corsHeaders });
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

    const serverClient = createClient(supabaseURL, serviceRoleKey, {
        auth: { autoRefreshToken: false, persistSession: false }
    });
    const accepted = [];
    for (const event of events) {
        const { data, error } = await serverClient.rpc("apply_ios_checkin_event", {
            p_user_id: userData.user.id,
            p_client_id: event.clientId,
            p_local_date: event.localDate,
            p_period: event.period,
            p_timezone: event.timezone ?? null,
            p_ciphertext: event.ciphertext,
            p_schema_version: event.schemaVersion,
            p_client_updated_at: event.clientUpdatedAt,
            p_deleted_at: event.deletedAt ?? null
        });
        if (error) {
            console.error("sync-checkin-event failed", error.code);
            return new Response(JSON.stringify({ error: "Check-in sync failed." }), { status: 500, headers: corsHeaders });
        }
        accepted.push(data);
    }

    return new Response(JSON.stringify({ events: accepted }), { status: 200, headers: corsHeaders });
});
