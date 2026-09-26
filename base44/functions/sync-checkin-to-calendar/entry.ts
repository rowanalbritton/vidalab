// Creates an all-day Google Calendar event from a user's daily check-in.
// Uses the app-user Google Calendar connector (each member connects their own
// Google account), so the event lands in their personal calendar automatically.

import { createClientFromRequest } from "npm:@base44/sdk@0.8.48";
import { initSupabase } from "../../shared/supabaseServer.ts";

const CONNECTOR_ID = "6aaf624372f1397928edeb5e";
const CALENDAR_API = "https://www.googleapis.com/calendar/v3";

const MOOD_LABELS: Record<string, string> = {
  calm: "Calm",
  happy: "Happy",
  neutral: "Neutral",
  anxious: "Anxious",
  sad: "Sad",
  irritable: "Irritable",
  motivated: "Motivated",
};

const SYMPTOM_LABELS: Record<string, string> = {
  headache: "Headache",
  cramps: "Cramps",
  bloating: "Bloating",
  fatigue: "Fatigue",
  breast_tenderness: "Breast tenderness",
  acne: "Acne",
  backache: "Backache",
  nausea: "Nausea",
  brain_fog: "Brain fog",
  cravings: "Cravings",
  none: "None",
};

const PRACTICE_LABELS: Record<string, string> = {
  meditation: "Meditation",
  gentle_exercise: "Gentle exercise",
  anti_inflammatory_meal: "Anti-inflammatory meal",
  supplement: "Supplement",
  breathing_exercise: "Breathing exercise",
  nature_time: "Time in nature",
  sleep_hygiene: "Sleep hygiene",
  hydration: "Hydration",
  gratitude: "Gratitude",
  stretching: "Stretching",
};

export default async function (req: Request): Promise<Response> {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
    }

    const base44 = createClientFromRequest(req);
    const { body, user, serviceEntities } = await initSupabase(req);
    if (!user) return new Response(JSON.stringify({ error: "Not authenticated" }), { status: 401 });

    const { checkinId } = body;

    if (!checkinId) {
      return new Response(JSON.stringify({ error: "Missing checkinId" }), { status: 400 });
    }

    let checkin;
    try {
      checkin = await serviceEntities.DailyCheckin.get(checkinId);
    } catch (_) {
      return new Response(JSON.stringify({ error: "Check-in not found" }), { status: 404 });
    }
    if (checkin.created_by_id !== user.id) {
      return new Response(JSON.stringify({ error: "Not authorized" }), { status: 403 });
    }

    // Get the user's Google Calendar connection (app-user connector)
    let accessToken: string;
    try {
      const conn = await base44.asServiceRole.connectors.getCurrentAppUserConnection(CONNECTOR_ID);
      accessToken = conn.accessToken;
    } catch (_) {
      return new Response(JSON.stringify({ error: "Google Calendar not connected" }), { status: 403 });
    }

    // Build a readable summary from the check-in data
    const energyBar = "▮".repeat(checkin.energy || 0) + "▯".repeat(5 - (checkin.energy || 0));
    const moodLabel = MOOD_LABELS[checkin.mood] || checkin.mood || "—";

    const descLines: string[] = [
      `Energy: ${energyBar} (${checkin.energy || 0}/5)`,
      `Mood: ${moodLabel}`,
    ];

    if (checkin.sleep_hours != null) {
      descLines.push(`Sleep: ${checkin.sleep_hours}h` + (checkin.sleep_quality ? ` (quality ${checkin.sleep_quality}/5)` : ""));
    }
    if (checkin.pain_level != null && checkin.pain_level > 0) {
      descLines.push(`Pain: ${["—", "Mild", "Moderate", "Severe"][checkin.pain_level] || checkin.pain_level}`);
    }
    if (checkin.cycle_phase && checkin.cycle_phase !== "not_tracking") {
      descLines.push(`Cycle: ${checkin.cycle_phase.charAt(0).toUpperCase() + checkin.cycle_phase.slice(1)}`);
    }
    if (Array.isArray(checkin.symptoms) && checkin.symptoms.length > 0 && !checkin.symptoms.includes("none")) {
      descLines.push("Symptoms: " + checkin.symptoms.map((s: string) => SYMPTOM_LABELS[s] || s).join(", "));
    }
    if (Array.isArray(checkin.practices) && checkin.practices.length > 0) {
      descLines.push("Practices: " + checkin.practices.map((p: string) => PRACTICE_LABELS[p] || p).join(", "));
    }
    if (checkin.notes) {
      descLines.push("", `Notes: ${checkin.notes}`);
    }
    if (checkin.insight) {
      descLines.push("", `💡 ${checkin.insight}`);
    }
    descLines.push("", "— Logged via Vida Lab");

    const dateStr: string = checkin.checkin_date;

    const event = {
      summary: `🩺 Vida Check-in — ${moodLabel}, Energy ${checkin.energy || 0}/5`,
      description: descLines.join("\n"),
      start: { date: dateStr },
      end: { date: dateStr },
      colorId: "9", // teal — health/wellness
    };

    const eventRes = await fetch(`${CALENDAR_API}/calendars/primary/events`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(event),
    });

    if (!eventRes.ok) {
      const errText = await eventRes.text();
      console.error("sync-checkin-to-calendar: failed to create event", {
        status: eventRes.status,
        errText,
      });
      return new Response(JSON.stringify({ error: "Failed to create calendar event" }), { status: 502 });
    }

    const eventData = await eventRes.json();

    return new Response(
      JSON.stringify({
        status: "created",
        eventId: eventData.id,
        htmlLink: eventData.htmlLink,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("sync-checkin-to-calendar: unhandled error", err);
    return new Response(JSON.stringify({ error: "Internal error" }), { status: 500 });
  }
}