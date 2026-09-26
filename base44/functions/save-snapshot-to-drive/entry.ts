import { createClientFromRequest } from 'npm:@base44/sdk@0.8.48';
import { initSupabase } from "../../shared/supabaseServer.ts";

const DRIVE_CONNECTOR_ID = "6ab2085199c20e180bff3ebf";

export default async function (req: Request) {
  const base44 = createClientFromRequest(req);
  const { user, entities } = await initSupabase(req);
  if (!user) return Response.json({ error: "Unauthorized" }, { status: 401 });

  let accessToken: string;
  try {
    const conn = await base44.asServiceRole.connectors.getCurrentAppUserConnection(DRIVE_CONNECTOR_ID);
    accessToken = conn.accessToken;
  } catch (e) {
    return Response.json({ error: "Google Drive not connected" }, { status: 403 });
  }

  // Fetch user's health data
  const checkins = await entities.DailyCheckin.list("-checkin_date", 90);
  const treatments = await entities.Treatment.list("-created_date", 50);
  const appointments = await entities.Appointment.filter({ status: "confirmed" }, "appointment_date", 20);

  const dateStr = new Date().toISOString().slice(0, 10);

  // Build a readable HTML snapshot
  const checkinRows = checkins.map((c: any) => `
    <tr>
      <td>${c.checkin_date?.slice(0, 10) ?? ""}</td>
      <td>${c.energy ?? ""}/5</td>
      <td>${c.sleep_hours ?? ""}h</td>
      <td>${c.mood ?? ""}</td>
      <td>${c.pain_level ?? 0}/3</td>
      <td>${(c.symptoms || []).join(", ")}</td>
      <td>${(c.practices || []).join(", ")}</td>
    </tr>`).join("");

  const treatmentRows = treatments.map((t: any) => `
    <tr>
      <td>${t.name ?? ""}</td>
      <td>${t.type ?? ""}</td>
      <td>${t.status ?? ""}</td>
      <td>${t.dosage ?? ""}</td>
      <td>${t.effectiveness ?? ""}/5</td>
    </tr>`).join("");

  const apptRows = appointments.map((a: any) => `
    <tr>
      <td>${a.appointment_date ?? ""}</td>
      <td>${a.appointment_time ?? ""}</td>
      <td>${a.doctor_name ?? ""}</td>
      <td>${a.specialty ?? ""}</td>
      <td>${a.reason ?? ""}</td>
    </tr>`).join("");

  const html = `<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Vida Lab Health Snapshot — ${dateStr}</title>
<style>
  body { font-family: Georgia, serif; color: #2E463E; max-width: 800px; margin: 40px auto; padding: 0 20px; }
  h1 { font-size: 28px; } h2 { font-size: 20px; margin-top: 32px; }
  table { width: 100%; border-collapse: collapse; margin: 12px 0; font-size: 13px; }
  th { text-align: left; border-bottom: 2px solid #2E463E; padding: 6px; font-family: sans-serif; }
  td { border-bottom: 1px solid #E8E5DF; padding: 6px; }
  .meta { color: #756a59; font-size: 14px; }
</style></head><body>
<h1>Vida Lab Health Snapshot</h1>
<p class="meta">Generated ${dateStr} for ${user.email}</p>

<h2>Daily Check-ins (${checkins.length})</h2>
<table><tr><th>Date</th><th>Energy</th><th>Sleep</th><th>Mood</th><th>Pain</th><th>Symptoms</th><th>Practices</th></tr>
${checkinRows}</table>

<h2>Treatments (${treatments.length})</h2>
<table><tr><th>Name</th><th>Type</th><th>Status</th><th>Dosage</th><th>Effectiveness</th></tr>
${treatmentRows}</table>

<h2>Upcoming Appointments (${appointments.length})</h2>
<table><tr><th>Date</th><th>Time</th><th>Doctor</th><th>Specialty</th><th>Reason</th></tr>
${apptRows}</table>

<p class="meta">This snapshot is for educational purposes only and is not a substitute for professional medical advice.</p>
</body></html>`;

  // Multipart upload to Google Drive
  const boundary = "vida_boundary_" + Date.now();
  const metadata = JSON.stringify({
    name: `Vida Lab Health Snapshot — ${dateStr}.html`,
    mimeType: "text/html",
  });
  const body = `--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${metadata}\r\n--${boundary}\r\nContent-Type: text/html\r\n\r\n${html}\r\n--${boundary}--`;

  const uploadRes = await fetch("https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,webViewLink", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": `multipart/related; boundary=${boundary}`,
    },
    body,
  });
  if (!uploadRes.ok) {
    console.error("save-snapshot-to-drive: upload failed", await uploadRes.text());
    return Response.json({ error: "Failed to upload to Drive" }, { status: 502 });
  }

  const file = await uploadRes.json();
  return Response.json({ url: file.webViewLink, fileId: file.id });
}