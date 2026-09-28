import { serveWithCors } from "../_shared/cors.ts";
// Appointment Concierge — AI-powered doctor visit prep for Vida+ members.
//
// Reads the user's check-in history (and optionally a condition report from the
// library) and generates a comprehensive visit prep guide: a prioritized symptom
// narrative, questions to ask, tests to request, an advocacy script, and what
// to bring. Educational and empowering — helps the user walk in prepared and
// be heard, not dismissed.

import { formatCheckins } from "../_shared/formatCheckins.ts";
import { hasVidaPlus } from "../_shared/membership.ts";
import { initSupabase } from "../_shared/entities.ts";
import { askJSON, LLMRefusal, LLMUnavailable } from "../_shared/claude.ts";

const CONCIERGE_SCHEMA = {
  type: "object",
  properties: {
    visit_summary: {
      type: "string",
      description: "2-3 sentence summary of why they're visiting and what to focus on",
    },
    symptom_narrative: {
      type: "string",
      description: "A prioritized narrative of their symptoms to share with the doctor, written in first person",
    },
    key_metrics: {
      type: "array",
      items: {
        type: "object",
        properties: {
          label: { type: "string", description: "Metric name" },
          value: { type: "string", description: "The value or range" },
          context: { type: "string", description: "Why this matters for this visit" },
        },
        required: ["label", "value"],
      },
      description: "Key metrics from their tracking to share with the doctor",
    },
    questions_to_ask: {
      type: "array",
      items: { type: "string" },
      description: "Specific questions to ask the doctor, tailored to their patterns",
    },
    tests_to_request: {
      type: "array",
      items: { type: "string" },
      description: "Tests worth asking about, framed as questions not demands",
    },
    advocacy_script: {
      type: "string",
      description: "What to say if they feel dismissed or their concerns are minimized",
    },
    what_to_bring: {
      type: "array",
      items: { type: "string" },
      description: "What to bring to the appointment",
    },
    disclaimer: { type: "string", description: "Brief educational disclaimer" },
  },
  required: ["visit_summary", "symptom_narrative", "questions_to_ask", "advocacy_script", "disclaimer"],
};

serveWithCors(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
    }
    const { body, user, entities, serviceEntities } = await initSupabase(req);
    if (!user) return new Response(JSON.stringify({ error: "Not authenticated" }), { status: 401 });

    const isVidaPlus = await hasVidaPlus(user.id, user.email);
    if (!isVidaPlus) {
      return new Response(JSON.stringify({ error: "Vida+ required" }), { status: 403 });
    }

    // Optional inputs: condition slug to focus the prep, and free-text visit reason.
    const conditionSlug = body.conditionSlug || null;
    const visitReason = body.visitReason || null;

    const checkins = await entities.DailyCheckin.list("-checkin_date", 90);

    if (!checkins || checkins.length < 3) {
      return new Response(
        JSON.stringify({
          status: "insufficient_data",
          message:
            "You need at least 3 check-ins to generate visit prep. Log a few days of tracking first.",
          checkinCount: checkins?.length || 0,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const today = new Date().toISOString().slice(0, 10);
    const checkinText = formatCheckins(checkins);

    // If a condition slug is provided, load the condition report for context.
    let conditionContext = "";
    if (conditionSlug) {
      try {
        const reports = await serviceEntities.DiseaseReport.filter(
          { slug: conditionSlug, is_public: true },
          "sort_order",
          1
        );
        if (reports && reports.length > 0) {
          const r = reports[0];
          conditionContext = `\n\nThe user is preparing for a visit related to: ${r.name}\nSummary: ${r.summary || ""}\n`;
          if (r.symptoms) conditionContext += `Known symptoms: ${r.symptoms.replace(/[#*]/g, "").slice(0, 500)}\n`;
          if (r.diagnosis) conditionContext += `Diagnosis approach: ${r.diagnosis.replace(/[#*]/g, "").slice(0, 500)}\n`;
          if (r.doctors_guide) conditionContext += `Doctors to see: ${r.doctors_guide.replace(/[#*]/g, "").slice(0, 500)}\n`;
        }
      } catch (_) {
        // Condition lookup failed — proceed without it.
      }
    }

    const reasonText = visitReason ? `\n\nThe user's reason for this visit: "${visitReason}"` : "";

    const prompt = `You are Vida, a warm, knowledgeable health companion for Vida Lab.

You're generating an "Appointment Concierge" prep — a comprehensive guide to help the user walk into their doctor's appointment prepared, heard, and not dismissed.

IMPORTANT GUIDELINES:
- Educational and empowering. Help them tell their story clearly and advocate for themselves.
- Create a prioritized symptom narrative — the most important things to share, in order, written in first person so they can read it aloud.
- Suggest specific questions to ask the doctor, tailored to their patterns.
- Suggest tests to request, if patterns warrant them (frame as "worth asking about," not demands).
- Include an advocacy script — what to say if they feel dismissed or their concerns are minimized. This is critical — many patients, especially young patients, are dismissed. Give them exact words.
- List what to bring to the appointment.
- Be specific — reference their actual data and patterns, not generic advice.
- If a condition is specified, tailor the prep to that condition's typical evaluation.
- Warm, confident tone — like a knowledgeable friend coaching them before the visit.

Today's date is ${today}.${conditionContext}${reasonText}

Here is the user's check-in history (most recent ${checkins.length} entries, oldest first):

${checkinText}

Generate an Appointment Concierge prep. Include a visit summary, a first-person symptom narrative, key metrics to share, specific questions to ask, tests to request, an advocacy script for if they're dismissed, and what to bring.`;

    const llmResponse = await askJSON({
      prompt,
      schema: CONCIERGE_SCHEMA,
      effort: "medium",
      });

    const result = typeof llmResponse === "string" ? JSON.parse(llmResponse) : llmResponse;

    return new Response(
      JSON.stringify({
        status: "ok",
        prep: result,
        generatedAt: new Date().toISOString(),
        checkinCount: checkins.length,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("appointment-concierge: unhandled error", err);
    return new Response(JSON.stringify({ error: "Internal error" }), { status: 500 });
  }
});
