import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { askJSON, LLMRefusal, LLMUnavailable } from "../_shared/claude.ts";
import { hasVidaPlus } from "../_shared/vidaplus.ts";

// Vida+ AI tools for the app: Body Weather, the Vida Differential, and the
// Appointment Concierge. The website has the same three, reading its own
// plaintext check-ins. The app's check-ins are encrypted on the device, so the
// server can't read them; instead the app sends a summary with each request,
// after the member has agreed to a prompt that names Anthropic.
//
// That summary carries daily scores and tags only. Free-text notes, meals,
// medications, Apple Health samples, and anything identifying stay on the
// device. Nothing sent here is stored.
//
//   POST { feature, today, checkIns: [{ date, scores, tags }], context }
//   -> { status: "ok", feature, result, generatedAt }
//    | { status: "insufficient_data" | "declined", message }
//    | { error }

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Content-Type": "application/json"
};

function reply(body: Record<string, unknown>, status = 200) {
    return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

type Feature = "body_weather" | "differential" | "concierge";

interface DayInput {
    date: string;
    scores: Record<string, number>;
    tags: string[];
}

interface ContextInput {
    focusAreas: string[];
    conditions: string[];
    tracksCycle: boolean;
    visitReason: string;
    conditionName: string;
}

const knownSignals: Record<string, string> = {
    sleep: "sleep (hours)",
    energy: "energy (0-10, higher is better)",
    mood: "mood steadiness (0-10, higher is better)",
    focus: "focus (0-10, higher is better)",
    movement: "movement (0-10, higher is more)",
    nutrition: "nourishment (0-10, higher is better)",
    skin: "skin (0-10, higher is better)",
    digestion: "digestion (0-10, higher is better)",
    pain: "pain (0-10, higher is worse)",
    headache: "head pain (0-10, higher is worse)",
    stress: "stress (0-10, higher is worse)",
    cycle: "bleeding (0 none to 10 very heavy)",
};

const minimumDays: Record<Feature, number> = { body_weather: 7, differential: 7, concierge: 3 };

// MARK: - Validation

const isoDate = /^\d{4}-\d{2}-\d{2}$/;

function text(value: unknown, limit: number): string {
    return typeof value === "string" ? value.trim().slice(0, limit) : "";
}

function textList(value: unknown, count: number, limit: number): string[] {
    if (!Array.isArray(value)) return [];
    return value.map((item) => text(item, limit)).filter(Boolean).slice(0, count);
}

/// Keeps only well-formed days: a real date, known signals with numeric
/// scores in range, and short tags. At most 90 days, newest kept.
function parseDays(raw: unknown): DayInput[] {
    if (!Array.isArray(raw)) return [];
    const days: DayInput[] = [];
    for (const item of raw) {
        const date = text(item?.date, 10);
        if (!isoDate.test(date)) continue;
        const scores: Record<string, number> = {};
        for (const [key, value] of Object.entries(item?.scores ?? {})) {
            if (!(key in knownSignals) || typeof value !== "number" || !Number.isFinite(value)) continue;
            const max = key === "sleep" ? 24 : 10;
            if (value < 0 || value > max) continue;
            scores[key] = Math.round(value * 10) / 10;
        }
        const tags = textList(item?.tags, 15, 40);
        if (Object.keys(scores).length === 0 && tags.length === 0) continue;
        days.push({ date, scores, tags });
    }
    return days.sort((a, b) => a.date.localeCompare(b.date)).slice(-90);
}

function parseContext(raw: unknown): ContextInput {
    const value = (raw ?? {}) as Record<string, unknown>;
    return {
        focusAreas: textList(value.focusAreas, 12, 40),
        conditions: textList(value.conditions, 12, 80),
        tracksCycle: value.tracksCycle === true,
        visitReason: text(value.visitReason, 500),
        conditionName: text(value.conditionName, 120),
    };
}

function formatDays(days: DayInput[]): string {
    return days.map((day) => {
        const scores = Object.entries(day.scores).map(([key, value]) => `${key} ${value}`).join(", ");
        const tags = day.tags.length ? ` | tags: ${day.tags.join(", ")}` : "";
        return `${day.date}: ${scores || "no scores"}${tags}`;
    }).join("\n");
}

function formatContext(context: ContextInput): string {
    const lines: string[] = [];
    if (context.focusAreas.length) lines.push(`Areas they chose to focus on: ${context.focusAreas.join(", ")}.`);
    if (context.conditions.length) lines.push(`Conditions they told the app they live with or are exploring: ${context.conditions.join(", ")}.`);
    lines.push(context.tracksCycle ? "They track their menstrual cycle." : "They don't track a menstrual cycle in the app.");
    return lines.join("\n");
}

const scaleNote = `Scales: ${Object.values(knownSignals).join("; ")}. Tags are short labels the member attached to that day. A missing signal means it wasn't logged that day, not that it was zero.`;

// MARK: - Features

const BODY_WEATHER_SCHEMA = {
    type: "object",
    properties: {
        summary: { type: "string", description: "One-line headline for the week, like a weather forecast summary" },
        patterns: { type: "array", items: { type: "string" }, description: "2-3 key patterns from their tracking" },
        forecast: {
            type: "array",
            description: "Exactly 7 days starting today",
            items: {
                type: "object",
                properties: {
                    day: { type: "string", description: "Today, Tomorrow, or a weekday abbreviation" },
                    date: { type: "string", description: "YYYY-MM-DD" },
                    energy: { type: "string", enum: ["low", "moderate", "high"] },
                    mood: { type: "string", description: "Mood tendency in one or two words" },
                    risk_level: { type: "string", enum: ["low", "moderate", "elevated", "high"] },
                    risk_areas: { type: "array", items: { type: "string" }, description: "Areas at risk, such as fatigue or head pain; may be empty" },
                    headline: { type: "string", description: "Short headline for the day" },
                    why: { type: "string", description: "1-2 sentences referencing their patterns" },
                    actions: { type: "array", items: { type: "string" }, description: "1-2 specific things to try that day" },
                },
            },
        },
        top_triggers: { type: "array", items: { type: "string" }, description: "Top 2-3 factors driving their patterns" },
        weekly_actions: { type: "array", items: { type: "string" }, description: "2-3 things to focus on this week" },
        disclaimer: { type: "string", description: "One sentence: educational, not medical advice" },
    },
};

const DIFFERENTIAL_SCHEMA = {
    type: "object",
    properties: {
        summary: { type: "string", description: "One-line headline, warm and empowering" },
        patterns: { type: "array", items: { type: "string" }, description: "2-3 key patterns from their tracking" },
        differentials: {
            type: "array",
            description: "2 to 4 conditions worth exploring, or empty if the patterns don't point anywhere",
            items: {
                type: "object",
                properties: {
                    condition: { type: "string" },
                    match_strength: { type: "string", enum: ["low", "moderate", "high"], description: "How well their patterns fit" },
                    why: { type: "string", description: "Why it's worth exploring, referencing their data" },
                    tests_to_consider: { type: "array", items: { type: "string" }, description: "Tests that help rule it in or out" },
                    specialists: { type: "array", items: { type: "string" } },
                    red_flags: { type: "array", items: { type: "string" }, description: "Symptoms that deserve prompt evaluation; may be empty" },
                },
            },
        },
        advocacy_notes: { type: "array", items: { type: "string" }, description: "How to advocate for yourself if dismissed" },
        next_steps: { type: "array", items: { type: "string" }, description: "Concrete next steps, including what to track next" },
        disclaimer: { type: "string", description: "One sentence: educational, not a diagnosis" },
    },
};

const CONCIERGE_SCHEMA = {
    type: "object",
    properties: {
        visit_summary: { type: "string", description: "2-3 sentences on why they're visiting and what to focus on" },
        symptom_narrative: { type: "string", description: "A prioritized first-person narrative they can read aloud" },
        key_metrics: {
            type: "array",
            items: {
                type: "object",
                properties: {
                    label: { type: "string" },
                    value: { type: "string", description: "The value or range from their tracking" },
                    context: { type: "string", description: "Why it matters for this visit" },
                },
            },
        },
        questions_to_ask: { type: "array", items: { type: "string" } },
        tests_to_request: { type: "array", items: { type: "string" }, description: "Framed as worth asking about; may be empty" },
        advocacy_script: { type: "string", description: "Exact words to use if they feel dismissed" },
        what_to_bring: { type: "array", items: { type: "string" } },
        disclaimer: { type: "string", description: "One sentence: educational, not medical advice" },
    },
};

function buildRequest(feature: Feature, today: string, days: DayInput[], context: ContextInput) {
    const history = `Today is ${today}.\n${formatContext(context)}\n${scaleNote}\n\nTheir check-ins, oldest first (${days.length} days):\n${formatDays(days)}`;

    switch (feature) {
        case "body_weather":
            return {
                schema: BODY_WEATHER_SCHEMA,
                effort: "medium" as const,
                system: `You're writing a "Body Weather" forecast: a 7-day look ahead at likely energy, mood, and symptom risk, based on this person's own patterns, with specific things to try before a pattern hits. It is a forecast of tendencies, never a prediction of medical events. Use "likely", "tends to", "based on your patterns".`,
                prompt: `${history}\n\nWrite a 7-day Body Weather forecast starting today. For each day give energy, mood tendency, overall risk level, specific areas at risk, a short headline, why (referencing their patterns, such as sleep-to-energy links, cycle timing, or tags that tend to come before harder days), and one or two specific things to try. Then name their top triggers and two or three things to focus on this week.`,
            };
        case "differential":
            return {
                schema: DIFFERENTIAL_SCHEMA,
                effort: "high" as const,
                system: `You're writing a "Vida Differential": conditions this person's logged patterns may be worth exploring with a clinician, with tests to ask about and specialists who evaluate them. It is a list of questions to bring to a doctor, never a diagnosis. Weigh conditions that are commonly missed or diagnosed late when the patterns fit, such as endometriosis, PCOS, thyroid disorders, autoimmune conditions, dysautonomia and POTS, ADHD, and iron deficiency. If the patterns are too vague to point anywhere, say so plainly, return no differentials, and suggest what to track next.`,
                prompt: `${history}\n\nWrite a Vida Differential with 2 to 4 conditions worth exploring (or none, if nothing fits), each with why it's worth exploring in terms of their own data, tests that help rule it in or out, specialists who evaluate it, and red flags that deserve prompt attention. Then give advocacy notes for if they're dismissed, and concrete next steps. Use empty arrays for anything you have nothing real to put in.`,
            };
        case "concierge": {
            const focus = [
                context.visitReason ? `Their reason for this visit, in their words: "${context.visitReason}"` : "",
                context.conditionName ? `The visit is related to: ${context.conditionName}.` : "",
            ].filter(Boolean).join("\n");
            return {
                schema: CONCIERGE_SCHEMA,
                effort: "medium" as const,
                system: `You're preparing this person for a doctor's appointment so they walk in prepared and are heard rather than dismissed. Help them tell their story clearly, in order of importance, and advocate for themselves. Frame tests as worth asking about, never as demands. Many patients, especially young women, are dismissed, so give exact words for the advocacy script.`,
                prompt: `${history}${focus ? `\n\n${focus}` : ""}\n\nWrite their Appointment Concierge prep: a visit summary, a first-person symptom narrative they can read aloud, key metrics from their tracking to share, specific questions to ask, tests worth asking about, an advocacy script for if they're dismissed, and what to bring.`,
            };
        }
    }
}

// MARK: - Handler

Deno.serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (req.method !== "POST") return reply({ error: "Method not allowed." }, 405);

    const authorization = req.headers.get("Authorization");
    const supabaseURL = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!supabaseURL || !anonKey) return reply({ error: "Server configuration error." }, 500);
    if (!authorization) return reply({ error: "Authentication required." }, 401);

    const memberClient = createClient(supabaseURL, anonKey, {
        auth: { autoRefreshToken: false, persistSession: false },
        global: { headers: { Authorization: authorization } }
    });
    const { data: userData, error: userError } = await memberClient.auth.getUser();
    if (userError || !userData.user) return reply({ error: "Authentication required." }, 401);
    const user = userData.user;

    let body: Record<string, unknown> = {};
    try {
        body = await req.json();
    } catch {
        return reply({ error: "That request couldn't be read." }, 400);
    }

    const feature = body.feature as Feature;
    if (!(feature in minimumDays)) return reply({ error: "Unknown feature." }, 400);

    if (!await hasVidaPlus(user.id, user.email)) return reply({ error: "Vida+ required." }, 403);

    const days = parseDays(body.checkIns);
    const minimum = minimumDays[feature];
    if (days.length < minimum) {
        return reply({
            status: "insufficient_data",
            message: `This needs at least ${minimum} days of check-ins, and there are ${days.length} so far. Keep checking in and it will be ready soon.`,
        });
    }

    const today = isoDate.test(text(body.today, 10)) ? text(body.today, 10) : new Date().toISOString().slice(0, 10);
    const request = buildRequest(feature, today, days, parseContext(body.context));

    try {
        const result = await askJSON<Record<string, unknown>>(request);
        return reply({ status: "ok", feature, result, generatedAt: new Date().toISOString() });
    } catch (error) {
        if (error instanceof LLMRefusal) {
            return reply({
                status: "declined",
                message: "Vida couldn't put this together for your history. Your tracking is still worth bringing to a clinician to look at with you.",
            });
        }
        if (error instanceof LLMUnavailable) {
            return reply({ error: "Vida couldn't answer just now. Please try again in a moment." }, error.retryable ? 503 : 500);
        }
        console.error("vida-plus-insights unhandled error");
        return reply({ error: "Something went wrong. Please try again." }, 500);
    }
});
