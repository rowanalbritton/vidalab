// Adds a confirmed doctor appointment to the calling user's Google Calendar
// via the app-user Google Calendar connector. Each member connects their own
// Google account, so the event lands in their personal calendar automatically.

import { createClientFromRequest } from "npm:@base44/sdk@0.8.48";
import { initSupabase } from "../../shared/supabaseServer.ts";

const CONNECTOR_ID = "6aaf624372f1397928edeb5e";
const CALENDAR_API = "https://www.googleapis.com/calendar/v3";

export default async function (req: Request): Promise<Response> {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
    }

    const base44 = createClientFromRequest(req);
    const { body, user, serviceEntities } = await initSupabase(req);
    if (!user) return new Response(JSON.stringify({ error: "Not authenticated" }), { status: 401 });

    const { appointmentId } = body;

    if (!appointmentId) {
      return new Response(JSON.stringify({ error: "Missing appointmentId" }), { status: 400 });
    }

    // Fetch the appointment (service role to read, then verify ownership)
    let appointment;
    try {
      appointment = await serviceEntities.Appointment.get(appointmentId);
    } catch (_) {
      return new Response(JSON.stringify({ error: "Appointment not found" }), { status: 404 });
    }
    if (appointment.created_by_id !== user.id) {
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

    // Get the user's primary calendar timezone so the event time is correct
    const calRes = await fetch(`${CALENDAR_API}/calendars/primary`, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!calRes.ok) {
      const errText = await calRes.text();
      console.error("add-google-calendar-event: failed to get primary calendar", {
        status: calRes.status,
        errText,
      });
      return new Response(JSON.stringify({ error: "Failed to access Google Calendar" }), { status: 502 });
    }
    const calData = await calRes.json();
    const timeZone = calData.timeZone || "America/New_York";

    // Build the event datetime (appointment_date + appointment_time, 1-hour duration)
    const dateStr: string = appointment.appointment_date;
    const timeStr: string = appointment.appointment_time || "09:00";
    const [h, m] = timeStr.split(":").map(Number);
    const endH = (h + 1) % 24;

    const startDateTime = `${dateStr}T${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}:00`;
    const endDateTime = `${dateStr}T${String(endH).padStart(2, "0")}:${String(m).padStart(2, "0")}:00`;

    const summary = `Appointment — ${appointment.practice_name || appointment.doctor_name || "Doctor"}`;
    const description = [
      appointment.doctor_name ? `Doctor: ${appointment.doctor_name}` : "",
      appointment.specialty ? `Specialty: ${appointment.specialty}` : "",
      appointment.reason ? `Reason for visit: ${appointment.reason}` : "",
      appointment.notes ? `Notes: ${appointment.notes}` : "",
      "— Added via Vida Lab",
    ]
      .filter(Boolean)
      .join("\n");

    const event = {
      summary,
      location: appointment.practice_name || appointment.doctor_name || "",
      description,
      start: { dateTime: startDateTime, timeZone },
      end: { dateTime: endDateTime, timeZone },
    };

    // Create the event in the user's primary calendar
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
      console.error("add-google-calendar-event: failed to create event", {
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
    console.error("add-google-calendar-event: unhandled error", err);
    return new Response(JSON.stringify({ error: "Internal error" }), { status: 500 });
  }
}