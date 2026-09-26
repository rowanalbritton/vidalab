// Vida Experiments — AI-powered n=1 experiment analysis for Vida+ members.
//
// Reads an experiment and its daily adherence logs, joins them with the user's
// check-in data for the experiment period, computes metric comparisons
// (adherent vs non-adherent days), and uses InvokeLLM to interpret whether
// the intervention appeared to help, hurt, or had no clear effect.
//
// Honest about n=1 limitations — small samples mean low confidence. Educational
// and wellness-focused, never medical claims.

import { hasVidaPlus } from "../_shared/membership.ts";
import { initSupabase } from "../_shared/entities.ts";
import { askJSON, LLMRefusal, LLMUnavailable } from "../_shared/claude.ts";

const RESULTS_SCHEMA = {
  type: "object",
  properties: {
    verdict: {
      type: "string",
      description: "Overall assessment: did the intervention appear to help, hurt, or have no clear effect?",
    },
    confidence: {
      type: "string",
      enum: ["low", "moderate", "high"],
      description: "How confident this analysis is, given sample size and data quality",
    },
    on_days_summary: {
      type: "string",
      description: "Summary of metrics on adherent days (when they did the intervention)",
    },
    off_days_summary: {
      type: "string",
      description: "Summary of metrics on non-adherent days (when they didn't)",
    },
    key_findings: {
      type: "array",
      items: { type: "string" },
      description: "3-5 key findings from the comparison",
    },
    recommendations: {
      type: "array",
      items: { type: "string" },
      description: "Next steps: extend, adjust, or stop the experiment",
    },
    disclaimer: { type: "string", description: "Brief educational disclaimer about n=1 limitations" },
  },
  required: ["verdict", "confidence", "key_findings", "disclaimer"],
};

function avg(nums: number[]): number | null {
  if (!nums.length) return null;
  return +(nums.reduce((s, n) => s + n, 0) / nums.length).toFixed(2);
}

Deno.serve(async (req: Request) => {
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

    const experimentId = body.experimentId;
    if (!experimentId) {
      return new Response(JSON.stringify({ error: "Experiment ID required" }), { status: 400 });
    }

    // Load the experiment (user-scoped — RLS ensures ownership).
    let experiment = null;
    try {
      experiment = await entities.Experiment.get(experimentId);
    } catch (_) {
      return new Response(JSON.stringify({ error: "Experiment not found" }), { status: 404 });
    }
    if (!experiment) {
      return new Response(JSON.stringify({ error: "Experiment not found" }), { status: 404 });
    }

    // Load adherence logs for this experiment.
    const logs = await entities.ExperimentLog.filter(
      { experiment_id: experimentId },
      "log_date",
      200
    );

    // Load check-ins for the experiment period.
    const checkins = await entities.DailyCheckin.list("-checkin_date", 200);

    // Build a map of log_date → adhered.
    const adherenceMap: Record<string, boolean> = {};
    logs.forEach((l) => {
      adherenceMap[l.log_date] = l.adhered;
    });

    // Join check-ins with adherence data.
    const startDate = experiment.start_date;
    const endDate = experiment.end_date || new Date().toISOString().slice(0, 10);

    const periodCheckins = checkins.filter((c) => {
      const d = (c.checkin_date || "").slice(0, 10);
      return d >= startDate && d <= endDate;
    });

    const adherentCheckins = periodCheckins.filter((c) => adherenceMap[(c.checkin_date || "").slice(0, 10)] === true);
    const nonAdherentCheckins = periodCheckins.filter((c) => adherenceMap[(c.checkin_date || "").slice(0, 10)] === false);

    // Compute stats.
    const stats = {
      adherent: {
        count: adherentCheckins.length,
        avgEnergy: avg(adherentCheckins.map((c) => c.energy).filter((n) => n != null)),
        avgSleepHours: avg(adherentCheckins.map((c) => c.sleep_hours).filter((n) => n != null)),
        avgSleepQuality: avg(adherentCheckins.map((c) => c.sleep_quality).filter((n) => n != null)),
        avgPain: avg(adherentCheckins.map((c) => c.pain_level).filter((n) => n != null && n > 0)),
      },
      nonAdherent: {
        count: nonAdherentCheckins.length,
        avgEnergy: avg(nonAdherentCheckins.map((c) => c.energy).filter((n) => n != null)),
        avgSleepHours: avg(nonAdherentCheckins.map((c) => c.sleep_hours).filter((n) => n != null)),
        avgSleepQuality: avg(nonAdherentCheckins.map((c) => c.sleep_quality).filter((n) => n != null)),
        avgPain: avg(nonAdherentCheckins.map((c) => c.pain_level).filter((n) => n != null && n > 0)),
      },
    };

    // Build stats text for the prompt.
    const fmt = (label: string, val: number | null) => `${val != null ? val : "—"}`;
    const statsText = `Adherent days (${stats.adherent.count}):
  Avg energy: ${fmt("energy", stats.adherent.avgEnergy)}/5
  Avg sleep: ${fmt("sleep", stats.adherent.avgSleepHours)}h (quality ${fmt("quality", stats.adherent.avgSleepQuality)}/5)
  Avg pain on symptomatic days: ${fmt("pain", stats.adherent.avgPain)}/3

Non-adherent days (${stats.nonAdherent.count}):
  Avg energy: ${fmt("energy", stats.nonAdherent.avgEnergy)}/5
  Avg sleep: ${fmt("sleep", stats.nonAdherent.avgSleepHours)}h (quality ${fmt("quality", stats.nonAdherent.avgSleepQuality)}/5)
  Avg pain on symptomatic days: ${fmt("pain", stats.nonAdherent.avgPain)}/3`;

    // Build daily log text.
    const logsText = logs
      .sort((a, b) => (a.log_date < b.log_date ? -1 : 1))
      .map((l) => `${l.log_date}: ${l.adhered ? "Did intervention" : "Did NOT do intervention"}${l.notes ? ` — "${l.notes}"` : ""}`)
      .join("\n");

    const metricsList = experiment.metrics_to_watch?.length
      ? experiment.metrics_to_watch.join(", ")
      : "energy, sleep, mood, pain, symptoms";

    const prompt = `You are Vida, a warm, knowledgeable health companion for Vida Lab.

You're analyzing the results of a user's n=1 self-experiment. The user tested an intervention and tracked their metrics. Your job is to interpret whether the intervention seemed to help, hurt, or had no clear effect.

IMPORTANT GUIDELINES:
- Educational and wellness-focused. Never make medical claims. Use language like "appears to," "suggests," "in this experiment."
- Compare metrics on days they adhered to the intervention vs days they didn't.
- Be honest about confidence — n=1 experiments have real limitations. Small sample sizes mean low confidence. Say so.
- If there's no clear difference, say so plainly. That's a valid and useful result.
- Suggest concrete next steps: extend the experiment, try a different dose, control for a confounder, or stop.
- Warm, encouraging tone — celebrate that they ran an experiment on their own health.

Experiment: ${experiment.title}
Intervention: ${experiment.intervention}
Hypothesis: ${experiment.hypothesis}
Duration: ${experiment.duration_days} days (${startDate} to ${endDate})
Metrics watched: ${metricsList}

Adherence summary:
- Adherent days (with check-in data): ${stats.adherent.count}
- Non-adherent days (with check-in data): ${stats.nonAdherent.count}
- Total logs: ${logs.length}

Metric comparison (adherent vs non-adherent days):
${statsText}

Daily adherence logs:
${logsText || "No daily logs recorded."}

Analyze this experiment. Did the intervention appear to help? Provide a clear verdict, confidence level, summaries of on-days vs off-days, key findings, and recommendations for next steps.`;

    const llmResponse = await askJSON({
      prompt,
      schema: RESULTS_SCHEMA,
      effort: "medium",
      });

    const result = typeof llmResponse === "string" ? JSON.parse(llmResponse) : llmResponse;

    // Store the results summary on the experiment.
    try {
      await entities.Experiment.update(experimentId, {
        results_summary: JSON.stringify(result),
        status: "completed",
      });
    } catch (e) {
      console.error("experiment-results: could not store results on experiment", e);
    }

    return new Response(
      JSON.stringify({
        status: "ok",
        results: result,
        stats,
        generatedAt: new Date().toISOString(),
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("experiment-results: unhandled error", err);
    return new Response(JSON.stringify({ error: "Internal error" }), { status: 500 });
  }
});
