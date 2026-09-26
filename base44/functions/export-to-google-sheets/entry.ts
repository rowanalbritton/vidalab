import { createClientFromRequest } from 'npm:@base44/sdk@0.8.48';
import { initSupabase } from "../../shared/supabaseServer.ts";

const SHEETS_CONNECTOR_ID = "6ab20846a57ea61357fd535a";

export default async function (req: Request) {
  const base44 = createClientFromRequest(req);
  const { user, entities } = await initSupabase(req);
  if (!user) return Response.json({ error: "Unauthorized" }, { status: 401 });

  let accessToken: string;
  try {
    const conn = await base44.asServiceRole.connectors.getCurrentAppUserConnection(SHEETS_CONNECTOR_ID);
    accessToken = conn.accessToken;
  } catch (e) {
    return Response.json({ error: "Google Sheets not connected" }, { status: 403 });
  }

  // Fetch user's check-ins and treatments
  const checkins = await entities.DailyCheckin.list("-checkin_date", 500);
  const treatments = await entities.Treatment.list("-created_date", 200);

  const headers = { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" };

  // Create a new spreadsheet with two sheets
  const createRes = await fetch("https://sheets.googleapis.com/v4/spreadsheets", {
    method: "POST",
    headers,
    body: JSON.stringify({
      properties: { title: `Vida Lab Health Export — ${new Date().toISOString().slice(0, 10)}` },
      sheets: [
        { properties: { title: "Daily Check-ins" } },
        { properties: { title: "Treatments" } },
      ],
    }),
  });
  if (!createRes.ok) {
    console.error("export-to-google-sheets: create failed", await createRes.text());
    return Response.json({ error: "Failed to create spreadsheet" }, { status: 502 });
  }
  const spreadsheet = await createRes.json();
  const spreadsheetId = spreadsheet.spreadsheetId;
  const spreadsheetUrl = spreadsheet.spreadsheetUrl;

  // Write check-ins
  const checkinValues = [
    ["Date", "Energy", "Sleep Hours", "Sleep Quality", "Mood", "Pain Level", "Cycle Phase", "Symptoms", "Practices", "Notes", "Insight"],
    ...checkins.map((c: any) => [
      c.checkin_date?.slice(0, 10) ?? "",
      c.energy ?? "",
      c.sleep_hours ?? "",
      c.sleep_quality ?? "",
      c.mood ?? "",
      c.pain_level ?? "",
      c.cycle_phase ?? "",
      (c.symptoms || []).join(", "),
      (c.practices || []).join(", "),
      c.notes ?? "",
      c.insight ?? "",
    ]),
  ];

  await fetch(`https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/Daily Check-ins!A1:append`, {
    method: "POST",
    headers,
    body: JSON.stringify({ values: checkinValues }),
  });

  // Write treatments
  const treatmentValues = [
    ["Name", "Type", "Status", "Start Date", "End Date", "Dosage", "Effectiveness", "Side Effects", "Notes"],
    ...treatments.map((t: any) => [
      t.name ?? "",
      t.type ?? "",
      t.status ?? "",
      t.start_date ?? "",
      t.end_date ?? "",
      t.dosage ?? "",
      t.effectiveness ?? "",
      t.side_effects ?? "",
      t.notes ?? "",
    ]),
  ];

  await fetch(`https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/Treatments!A1:append`, {
    method: "POST",
    headers,
    body: JSON.stringify({ values: treatmentValues }),
  });

  return Response.json({
    url: spreadsheetUrl,
    spreadsheetId,
    checkinCount: checkins.length,
    treatmentCount: treatments.length,
  });
}