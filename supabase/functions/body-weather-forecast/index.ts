import { serveWithCors } from "../_shared/cors.ts";
// Body Weather — AI-powered predictive health forecast for Vida+ members.
//
// Analyzes the user's daily check-in history and generates a 7-day "body
// weather" forecast: predicted energy, mood, and symptom risk for each day,
// plus proactive interventions to try before patterns hit.
//
// This is the daily-engagement engine of the Vida+ suite — it builds the habit
// (check in daily) and the data foundation (rich patterns) that the other
// premium tools (Differential, Experiments, Appointment Concierge) run on.
//
// Wellness-focused and educational — never diagnoses or claims certainty.
// Uses language like "likely," "tends to," "based on your patterns."

import { formatCheckins } from "../_shared/formatCheckins.ts";
import { hasVidaPlus } from "../_shared/membership.ts";
import { initSupabase } from "../_shared/entities.ts";
import { askJSON, LLMRefusal, LLMUnavailable } from "../_shared/claude.ts";

const FORECAST_SCHEMA = {
  type: "object",
  properties: {
    summary: {
      type: "string",
      description: "One-line headline for the week, like a weather forecast summary",
    },
    patterns: {
      type: "array",
      items: { type: "string" },
      description: "2-3 key patterns identified from the check-in data",
    },
    forecast: {
      type: "array",
      items: {
        type: "object",
        properties: {
          day: { type: "string", description: "Day label: Today, Tomorrow, or weekday abbreviation" },
          date: { type: "string", description: "ISO date YYYY-MM-DD" },
          energy: { type: "string", enum: ["low", "moderate", "high"], description: "Predicted energy level" },
          mood: { type: "string", description: "Predicted mood tendency, one or two words" },
          risk_level: { type: "string", enum: ["low", "moderate", "elevated", "high"], description: "Overall symptom/flare risk" },
          risk_areas: {
            type: "array",
            items: { type: "string" },
            description: "Specific areas at risk: fatigue, mood dip, cramps, brain fog, etc.",
          },
          headline: { type: "string", description: "Short forecast headline for this day" },
          why: { type: "string", description: "1-2 sentence explanation referencing their patterns" },
          actions: {
            type: "array",
            items: { type: "string" },
            description: "1-2 proactive, specific interventions to try",
          },
        },
        required: ["day", "date", "energy", "mood", "risk_level", "headline", "why", "actions"],
      },
    },
    top_triggers: {
      type: "array",
      items: { type: "string" },
      description: "Top 2-3 factors driving the user's patterns",
    },
    weekly_actions: {
      type: "array",
      items: { type: "string" },
      description: "2-3 things to focus on this week",
    },
    disclaimer: { type: "string", description: "Brief educational disclaimer" },
  },
  required: ["summary", "patterns", "forecast", "top_triggers", "weekly_actions", "disclaimer"],
};

serveWithCors(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
    }
    const { user, entities, serviceEntities } = await initSupabase(req);
    if (!user) return new Response(JSON.stringify({ error: "Not authenticated" }), { status: 401 });

    // Gate to Vida+ members — verified server-side from paid purchase records.
    const isVidaPlus = await hasVidaPlus(user.id, user.email);
    if (!isVidaPlus) {
      return new Response(JSON.stringify({ error: "Vida+ required" }), { status: 403 });
    }

    // Load check-in history (last 90 days for pattern detection).
    const checkins = await entities.DailyCheckin.list("-checkin_date", 90);

    if (!checkins || checkins.length < 7) {
      return new Response(
        JSON.stringify({
          status: "insufficient_data",
          message:
            "You need at least 7 check-ins to generate a forecast. Keep tracking — your body weather is on the way.",
          checkinCount: checkins?.length || 0,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const today = new Date().toISOString().slice(0, 10);
    const checkinText = formatCheckins(checkins);

    const prompt = `You are Vida, a warm, knowledgeable health companion for Vida Lab — a platform that translates emerging science into actionable wellness insights for people.

You're generating a "Body Weather Forecast" — a 7-day predictive forecast based on the user's daily check-in patterns. Think of it like a weather forecast, but for the body: it predicts likely energy, mood, and symptom risk for each of the next 7 days, and suggests proactive, specific interventions to try BEFORE patterns hit.

IMPORTANT GUIDELINES:
- This is educational and wellness-focused. NEVER diagnose or claim to predict medical events with certainty. Use language like "likely," "tends to," "based on your patterns."
- Identify real patterns from the data: sleep-energy links, symptom clusters, mood trends, trigger relationships.
- Be specific and actionable — not generic. Reference the user's actual data and patterns.
- Warm, empowering tone — like a knowledgeable friend, not a clinical report.
- Keep each day's "why" and "actions" concise (1-2 sentences each).
- Generate exactly 7 forecast entries starting from today.

Today's date is ${today}.

Here is the user's check-in history (most recent ${checkins.length} entries, oldest first):

${checkinText}

Generate a 7-day Body Weather Forecast starting from today. For each day, predict energy, mood tendency, overall symptom/flare risk level, specific areas at risk, a short headline, why you predict this (referencing their patterns), and 1-2 proactive interventions to try that day.

Also identify the top triggers driving their patterns and 2-3 things to focus on this week.`;

    const llmResponse = await askJSON({
      prompt,
      schema: FORECAST_SCHEMA,
      effort: "medium",
      });

    // With response_json_schema, InvokeLLM returns a dict directly.
    const forecast = typeof llmResponse === "string" ? JSON.parse(llmResponse) : llmResponse;

    return new Response(
      JSON.stringify({
        status: "ok",
        forecast,
        generatedAt: new Date().toISOString(),
        checkinCount: checkins.length,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("body-weather-forecast: unhandled error", err);
    return new Response(JSON.stringify({ error: "Internal error" }), { status: 500 });
  }
});
