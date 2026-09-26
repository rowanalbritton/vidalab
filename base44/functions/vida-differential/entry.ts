// The Vida Differential — AI-powered pattern-to-condition mapping for Vida+ members.
//
// Analyzes the user's check-in history and maps their patterns to conditions worth
// exploring — with tests to ask for, specialists to see, and advocacy notes.
//
// This is NOT a diagnosis. It's an educational tool for someone who feels stuck or
// dismissed — it helps them understand what might be going on and how to advocate
// for proper evaluation. Uses language like "worth exploring," "patterns are
// consistent with," never "you have."

import { createClientFromRequest } from "npm:@base44/sdk@0.8.48";
import { formatCheckins } from "../../shared/formatCheckins.ts";
import { hasVidaPlus } from "../../shared/membership.ts";
import { initSupabase } from "../../shared/supabaseServer.ts";

const DIFFERENTIAL_SCHEMA = {
  type: "object",
  properties: {
    summary: {
      type: "string",
      description: "One-line headline for the differential, warm and empowering",
    },
    patterns: {
      type: "array",
      items: { type: "string" },
      description: "2-3 key patterns identified from the check-in data",
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
            description: "How well their patterns match this condition",
          },
          why: { type: "string", description: "Why this is worth exploring, referencing their data" },
          tests_to_consider: {
            type: "array",
            items: { type: "string" },
            description: "Tests that help rule this in or out",
          },
          specialists: {
            type: "array",
            items: { type: "string" },
            description: "Specialists who evaluate this condition",
          },
          red_flags: {
            type: "array",
            items: { type: "string" },
            description: "Symptoms that warrant prompt evaluation",
          },
        },
        required: ["condition", "match_strength", "why", "tests_to_consider", "specialists"],
      },
    },
    advocacy_notes: {
      type: "array",
      items: { type: "string" },
      description: "How to advocate for yourself if dismissed",
    },
    next_steps: {
      type: "array",
      items: { type: "string" },
      description: "Concrete, actionable next steps",
    },
    disclaimer: { type: "string", description: "Brief educational disclaimer" },
  },
  required: ["summary", "patterns", "differentials", "advocacy_notes", "disclaimer"],
};

export default async function (req: Request): Promise<Response> {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
    }

    const base44 = createClientFromRequest(req);
    const { user, entities, serviceEntities } = await initSupabase(req);
    if (!user) return new Response(JSON.stringify({ error: "Not authenticated" }), { status: 401 });

    const isVidaPlus = await hasVidaPlus(serviceEntities, user.id, user.email);
    if (!isVidaPlus) {
      return new Response(JSON.stringify({ error: "Vida+ required" }), { status: 403 });
    }

    const checkins = await entities.DailyCheckin.list("-checkin_date", 90);

    if (!checkins || checkins.length < 7) {
      return new Response(
        JSON.stringify({
          status: "insufficient_data",
          message:
            "You need at least 7 check-ins to generate a differential. Keep tracking — your patterns are building.",
          checkinCount: checkins?.length || 0,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const today = new Date().toISOString().slice(0, 10);
    const checkinText = formatCheckins(checkins);

    const prompt = `You are Vida, a warm, knowledgeable health companion for Vida Lab — a platform that translates emerging science into actionable wellness insights.

You're generating "The Vida Differential" — a structured analysis that maps the user's check-in patterns to conditions worth exploring. This is NOT a diagnosis. It's an educational tool that helps someone who feels stuck or dismissed understand what might be going on and how to advocate for proper evaluation.

IMPORTANT GUIDELINES:
- This is educational and wellness-focused. NEVER diagnose. Use language like "worth exploring," "patterns are consistent with," "could be worth discussing with a doctor."
- Identify 2-4 conditions that best match their symptom patterns. Be specific — reference their actual data.
- For each condition, explain WHY it's worth exploring, which tests help rule it in or out, which specialists evaluate it, and any red flags that warrant prompt evaluation.
- Include advocacy notes — how to advocate for yourself if dismissed.
- Be warm and empowering, not alarming. Frame this as "here's what to explore," not "here's what you have."
- If patterns are vague or don't clearly match any condition, say so honestly and suggest tracking more data.
- Consider cycle-related patterns, sleep-energy links, symptom clusters, and chronic patterns.
- Consider conditions common in young patients that are often dismissed or delayed in diagnosis (endometriosis, PCOS, thyroid, autoimmune, dysautonomia/POTS, ADHD, iron deficiency, etc.) when patterns fit.

Today's date is ${today}.

Here is the user's check-in history (most recent ${checkins.length} entries, oldest first):

${checkinText}

Generate a Vida Differential. Identify 2-4 conditions worth exploring based on their patterns. For each, explain why, list tests to consider, specialists to see, and any red flags. Then provide advocacy notes and concrete next steps.`;

    const llmResponse = await base44.asServiceRole.integrations.Core.InvokeLLM({
      prompt,
      response_json_schema: DIFFERENTIAL_SCHEMA,
    });

    const result = typeof llmResponse === "string" ? JSON.parse(llmResponse) : llmResponse;

    return new Response(
      JSON.stringify({
        status: "ok",
        differential: result,
        generatedAt: new Date().toISOString(),
        checkinCount: checkins.length,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("vida-differential: unhandled error", err);
    return new Response(JSON.stringify({ error: "Internal error" }), { status: 500 });
  }
}