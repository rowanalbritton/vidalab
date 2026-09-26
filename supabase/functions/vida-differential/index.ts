// The Vida Differential — maps a member's logged patterns to conditions worth
// exploring, with tests to ask for and specialists to see.
//
// Ported from base44/functions/vida-differential. Two things changed beyond the
// LLM call:
//
//   1. The educational framing moved into `HEALTH_SYSTEM_PROMPT` in the shared
//      helper. It used to live in this prompt string, which meant it was one
//      careless edit away from being lost on the single feature that most needs
//      it — App Review guideline 1.4.1 reads "patterns mapped to conditions" as
//      diagnosis unless the wording is careful.
//   2. A refusal is now surfaced as its own response rather than an empty
//      differential. The old code would have rendered a blank result.
//
// Vida+ membership is verified server-side against a paid purchase row, never
// against a client-writable profile field.

import { createClient } from "@supabase/supabase-js";
import { askJSON, LLMRefusal, LLMUnavailable } from "../_shared/claude.ts";
import { hasVidaPlus } from "../_shared/membership.ts";

const corsHeaders = {
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Origin": "*",
    "Content-Type": "application/json"
};

/// Minimum history before a differential says anything. Below this the honest
/// answer is "keep tracking", not a low-confidence guess.
const minimumCheckIns = 7;

const DIFFERENTIAL_SCHEMA = {
    type: "object",
    properties: {
        summary: {
            type: "string",
            description: "One-line headline for the differential, warm and empowering"
        },
        patterns: {
            type: "array",
            items: { type: "string" },
            description: "2-3 key patterns identified from the check-in data"
        },
        differentials: {
            type: "array",
            items: {
                type: "object",
                properties: {
                    condition: { type: "string", description: "Name of the condition worth exploring" },
                    match_strength: {
                        type: "string",
                        enum: ["low", "moderate", "high"],
                        description: "How well their patterns match this condition"
                    },
                    why: { type: "string", description: "Why this is worth exploring, referencing their data" },
                    tests_to_consider: {
                        type: "array",
                        items: { type: "string" },
                        description: "Tests that help rule this in or out"
                    },
                    specialists: {
                        type: "array",
                        items: { type: "string" },
                        description: "Specialists who evaluate this condition"
                    },
                    red_flags: {
                        type: "array",
                        items: { type: "string" },
                        description: "Symptoms that warrant prompt evaluation"
                    }
                },
                required: ["condition", "match_strength", "why", "tests_to_consider", "specialists", "red_flags"]
            }
        },
        advocacy_notes: {
            type: "array",
            items: { type: "string" },
            description: "How to advocate for yourself if dismissed"
        },
        next_steps: {
            type: "array",
            items: { type: "string" },
            description: "Concrete, actionable next steps"
        },
        disclaimer: { type: "string", description: "Brief educational disclaimer" }
    },
    // Structured outputs require every property to be listed as required.
    // `red_flags` and `next_steps` were optional under Base44's looser schema
    // handling; they are listed here and the prompt allows empty arrays.
    required: ["summary", "patterns", "differentials", "advocacy_notes", "next_steps", "disclaimer"]
};

interface CheckInRow {
    checkin_date: string;
    [key: string]: unknown;
}

/// Renders check-ins oldest-first as plain lines. Replaces the shared
/// `formatCheckins` helper, which was shaped around Base44's entity wrapper.
function formatCheckIns(rows: CheckInRow[]): string {
    return rows
        .slice()
        .sort((a, b) => a.checkin_date.localeCompare(b.checkin_date))
        .map((row) => {
            const fields = Object.entries(row)
                .filter(([key, value]) =>
                    key !== "checkin_date"
                    && key !== "id"
                    && key !== "user_id"
                    && value !== null
                    && value !== ""
                )
                .map(([key, value]) => `${key}: ${value}`)
                .join(", ");
            return `${row.checkin_date} — ${fields || "no details"}`;
        })
        .join("\n");
}

Deno.serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (req.method !== "POST") {
        return new Response(JSON.stringify({ error: "Method not allowed." }), { status: 405, headers: corsHeaders });
    }

    const supabaseURL = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!supabaseURL || !anonKey) {
        return new Response(JSON.stringify({ error: "Server configuration error." }), { status: 500, headers: corsHeaders });
    }

    const authorization = req.headers.get("Authorization");
    if (!authorization) {
        return new Response(JSON.stringify({ error: "Authentication required." }), { status: 401, headers: corsHeaders });
    }

    const memberClient = createClient(supabaseURL, anonKey, {
        auth: { autoRefreshToken: false, persistSession: false },
        global: { headers: { Authorization: authorization } }
    });
    const { data: userData, error: userError } = await memberClient.auth.getUser();
    if (userError || !userData.user) {
        return new Response(JSON.stringify({ error: "Authentication required." }), { status: 401, headers: corsHeaders });
    }
    const user = userData.user;

    // Verified server-side against a paid purchase row. The shared helper also
    // accepts the yearly and family products, which an inline monthly-only
    // check would have locked out.
    if (!await hasVidaPlus(user.id, user.email)) {
        return new Response(JSON.stringify({ error: "Vida+ required." }), { status: 403, headers: corsHeaders });
    }

    // Read through the member's own client so RLS scopes the rows.
    const { data: checkIns, error: checkInError } = await memberClient
        .from("daily_checkins")
        .select("*")
        .order("checkin_date", { ascending: false })
        .limit(90);
    if (checkInError) {
        console.error("vida-differential check-in read failed", checkInError.code);
        return new Response(JSON.stringify({ error: "Could not read your check-ins." }), { status: 500, headers: corsHeaders });
    }

    const rows = (checkIns ?? []) as CheckInRow[];
    if (rows.length < minimumCheckIns) {
        return new Response(
            JSON.stringify({
                status: "insufficient_data",
                message: `You need at least ${minimumCheckIns} check-ins to generate a differential. Keep tracking — your patterns are building.`,
                checkinCount: rows.length
            }),
            { status: 200, headers: corsHeaders }
        );
    }

    const today = new Date().toISOString().slice(0, 10);
    const prompt = `Generate a Vida Differential for this member.

Identify 2 to 4 conditions worth exploring based on their logged patterns. For each one, explain why it is worth exploring with reference to their own data, which tests help rule it in or out, which specialists evaluate it, and any red-flag symptoms that deserve prompt attention. Then give advocacy notes for if they are dismissed, and concrete next steps.

Weigh conditions that are commonly missed or diagnosed late when the patterns fit — endometriosis, PCOS, thyroid disorders, autoimmune conditions, dysautonomia and POTS, ADHD, iron deficiency. Look at cycle-linked patterns, sleep and energy links, symptom clusters, and anything persistent.

If the patterns are too vague to point anywhere, say that plainly and suggest what to track next rather than naming conditions that don't fit. Use empty arrays for any field you have nothing real to put in.

Today is ${today}. Here are their most recent ${rows.length} check-ins, oldest first:

${formatCheckIns(rows)}`;

    try {
        // `high` effort: this is the feature where a shallow read produces a
        // misleading differential, which is the one outcome worth paying for.
        const differential = await askJSON({
            prompt,
            schema: DIFFERENTIAL_SCHEMA,
            effort: "high",
            maxTokens: 8192
        });

        return new Response(
            JSON.stringify({
                status: "ok",
                differential,
                generatedAt: new Date().toISOString(),
                checkinCount: rows.length
            }),
            { status: 200, headers: corsHeaders }
        );
    } catch (error) {
        if (error instanceof LLMRefusal) {
            // Distinct from a failure: retrying is pointless, and a blank
            // differential must not be rendered as though it were an answer.
            return new Response(
                JSON.stringify({
                    status: "declined",
                    message: "Vida couldn't put a differential together for this history. Bring your tracking to a clinician and ask them to look at it with you."
                }),
                { status: 200, headers: corsHeaders }
            );
        }
        if (error instanceof LLMUnavailable) {
            return new Response(
                JSON.stringify({ error: error.message }),
                { status: error.retryable ? 503 : 500, headers: corsHeaders }
            );
        }
        console.error("vida-differential unhandled error");
        return new Response(JSON.stringify({ error: "Internal error." }), { status: 500, headers: corsHeaders });
    }
});
