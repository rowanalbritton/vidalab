import { serveWithCors } from "../_shared/cors.ts";
import { hasVidaPlus } from "../_shared/membership.ts";
import { initSupabase } from "../_shared/entities.ts";
import { sendEmail, EmailUnavailable } from "../_shared/email.ts";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Sends a Vida+ member's health snapshot to a doctor's practice via email.
// Called from the BookingModal when a member opts to include their snapshot.
serveWithCors(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return Response.json({ error: "Method not allowed" }, { status: 405 });
    }
    const { body, user, serviceEntities } = await initSupabase(req);
    if (!user) return Response.json({ error: "Unauthorized" }, { status: 401 });

    // Verify Vida+ entitlement server-side from paid purchase records —
    // never trust the client-writable User.membership field.
    const isVidaPlus = await hasVidaPlus(user.id, user.email);
    if (!isVidaPlus) {
      return Response.json({ error: "Vida+ membership required" }, { status: 403 });
    }

    const doctorId: string = String(body.doctorId ?? "").trim();
    const appointmentDate: string = String(body.appointmentDate ?? "");
    const appointmentTime: string = String(body.appointmentTime ?? "");
    const reason: string = String(body.reason ?? "");
    const snapshot = body.snapshot;

    if (!doctorId) {
      return Response.json({ error: "Doctor ID is required" }, { status: 400 });
    }
    if (!snapshot || !snapshot.total) {
      return Response.json({ error: "Snapshot data is required" }, { status: 400 });
    }

    // Look up the doctor server-side — never trust a client-supplied email
    // address (prevents open email relay / spam / phishing).
    const doctor = await serviceEntities.Doctor.get(doctorId).catch(() => null);
    if (!doctor || !doctor.email || !EMAIL_RE.test(doctor.email)) {
      return Response.json({ error: "Doctor email not available" }, { status: 400 });
    }
    const doctorEmail = doctor.email;
    const doctorName = doctor.practice_name || doctor.specialty || "";

    const memberName = user.full_name || user.email || "Vida+ Member";
    const dateStr = appointmentDate
      ? new Date(appointmentDate + "T00:00:00").toLocaleDateString("en-US", {
          weekday: "long",
          year: "numeric",
          month: "long",
          day: "numeric",
        })
      : "—";

    const html = buildEmailHtml({
      memberName,
      doctorName,
      dateStr,
      time: appointmentTime,
      reason,
      snapshot,
    });

    await sendEmail({
      to: doctorEmail,
      fromName: "Vida Lab",
      subject: `Appointment Request from ${memberName} — Vida Health Snapshot enclosed`,
      html,
    });

    return Response.json({ status: "sent" });
  } catch (error) {
    console.error("send-appointment-snapshot error:", error);
    return Response.json(
      { error: error instanceof Error ? error.message : "Internal error" },
      { status: 500 }
    );
  }
});

function buildEmailHtml({
  memberName,
  doctorName,
  dateStr,
  time,
  reason,
  snapshot,
}: {
  memberName: string;
  doctorName: string;
  dateStr: string;
  time: string;
  reason: string;
  snapshot: any;
}): string {
  const firstDate = new Date(snapshot.first + "T00:00:00").toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
  const lastDate = new Date(snapshot.last + "T00:00:00").toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });

  const metrics = [
    { label: "Avg energy", value: `${escapeHtml(String(snapshot.avgEnergy ?? ""))}/5` },
    { label: "Avg sleep", value: snapshot.avgSleep ? `${escapeHtml(String(snapshot.avgSleep))}h` : "—" },
    { label: "Low-energy days", value: escapeHtml(String(snapshot.lowEnergyDays ?? "")) },
    { label: "Poor-sleep days", value: escapeHtml(String(snapshot.poorSleepDays ?? "")) },
  ];

  const metricCells = metrics
    .map(
      (m) => `
        <td style="width:25%;padding:0 6px;">
          <div style="background:#F9F8F5;border:1px solid #E8E5DF;border-radius:12px;padding:14px;text-align:center;">
            <p style="text-transform:uppercase;letter-spacing:0.1em;font-size:10px;color:#5a655e;margin:0 0 6px;">${m.label}</p>
            <p style="font-family:'Newsreader',Georgia,serif;font-size:22px;color:#2E463E;margin:0;">${m.value}</p>
          </div>
        </td>`
    )
    .join("");

  const symptomsBlock =
    snapshot.topSymptoms?.length > 0
      ? `
        <h3 style="font-family:'Newsreader',Georgia,serif;font-size:16px;color:#2E463E;margin:0 0 10px;">Most frequent symptoms</h3>
        <table style="width:100%;font-size:13px;margin-bottom:20px;">
          ${snapshot.topSymptoms
            .map(
              (s: any) =>
                `<tr><td style="padding:5px 0;border-bottom:1px solid #E8E5DF;color:#2E463E;">${escapeHtml(String(s.symptom ?? ""))}</td><td style="padding:5px 0;text-align:right;border-bottom:1px solid #E8E5DF;color:#5a655e;">${escapeHtml(String(s.count ?? ""))} ${s.count === 1 ? "time" : "times"}</td></tr>`
            )
            .join("")}
        </table>`
      : "";

  const moodBlock =
    snapshot.topMoods?.length > 0
      ? `
        <h3 style="font-family:'Newsreader',Georgia,serif;font-size:16px;color:#2E463E;margin:0 0 10px;">Mood summary</h3>
        <p style="font-size:13px;color:#5a655e;margin:0 0 20px;">
          ${snapshot.topMoods.map((m: any) => `${escapeHtml(String(m.mood ?? ""))} (${escapeHtml(String(m.count ?? ""))}×)`).join(" · ")}
        </p>`
      : "";

  const questionsBlock =
    snapshot.questions?.length > 0
      ? `
        <div style="background:#BDE0E9;border-radius:12px;padding:16px 18px;">
          <h3 style="font-family:'Newsreader',Georgia,serif;font-size:16px;color:#2E463E;margin:0 0 10px;">Questions the member is considering</h3>
          <ul style="margin:0;padding-left:18px;font-size:13px;color:#2E463E;line-height:1.7;">
            ${snapshot.questions.map((q: string) => `<li>${escapeHtml(String(q ?? ""))}</li>`).join("")}
          </ul>
        </div>`
      : "";

  const reasonBlock = reason
    ? `<p style="text-transform:uppercase;letter-spacing:0.12em;font-size:11px;color:#3c6b4f;font-weight:600;margin:16px 0 6px;">Reason for visit</p><p style="font-size:14px;color:#2E463E;margin:0;">${escapeHtml(reason)}</p>`
    : "";

  return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"></head>
<body style="margin:0;padding:0;background:#F9F8F5;font-family:'DM Sans',sans-serif;color:#2E463E;">
  <div style="max-width:600px;margin:0 auto;padding:32px 24px;">
    <div style="text-align:center;margin-bottom:28px;">
      <div style="display:inline-flex;align-items:center;gap:8px;margin-bottom:12px;">
        <span style="width:26px;height:26px;border-radius:50%;background:#2E463E;display:inline-flex;align-items:center;justify-content:center;color:#F9F8F5;font-size:13px;line-height:1;">✦</span>
        <span style="font-family:'Newsreader',Georgia,serif;font-size:18px;color:#2E463E;">Vida Lab</span>
      </div>
      <h1 style="font-family:'Newsreader',Georgia,serif;font-size:26px;color:#2E463E;margin:0 0 6px;font-weight:400;">Appointment Request</h1>
      <p style="color:#5a655e;font-size:13px;margin:0;">A Vida+ member would like to schedule a visit${doctorName ? ` with ${escapeHtml(doctorName)}` : ""}.</p>
    </div>

    <div style="background:#FFFFFF;border:1px solid #E8E5DF;border-radius:16px;padding:22px;margin-bottom:14px;">
      <p style="text-transform:uppercase;letter-spacing:0.12em;font-size:11px;color:#3c6b4f;font-weight:600;margin:0 0 6px;">Member</p>
      <p style="font-family:'Newsreader',Georgia,serif;font-size:19px;color:#2E463E;margin:0 0 14px;">${escapeHtml(memberName)}</p>
      <table style="width:100%;font-size:13px;">
        <tr>
          <td style="padding:3px 0;color:#5a655e;">Requested date:</td>
          <td style="padding:3px 0;text-align:right;color:#2E463E;font-weight:500;">${escapeHtml(dateStr)}</td>
        </tr>
        <tr>
          <td style="padding:3px 0;color:#5a655e;">Requested time:</td>
          <td style="padding:3px 0;text-align:right;color:#2E463E;font-weight:500;">${escapeHtml(time || "—")}</td>
        </tr>
      </table>
      ${reasonBlock}
    </div>

    <div style="background:#FFFFFF;border:1px solid #E8E5DF;border-radius:16px;padding:22px;margin-bottom:14px;">
      <p style="text-transform:uppercase;letter-spacing:0.12em;font-size:11px;color:#3c6b4f;font-weight:600;margin:0 0 4px;">Vida Health Snapshot</p>
      <p style="font-family:'Newsreader',Georgia,serif;font-size:17px;color:#2E463E;margin:0 0 14px;font-weight:400;">Self-reported wellness tracking summary</p>
      <p style="font-size:12px;color:#5a655e;margin:0 0 18px;">Tracking period: ${escapeHtml(firstDate)} – ${escapeHtml(lastDate)} · ${escapeHtml(String(snapshot.total ?? ""))} check-ins</p>
      <table style="width:100%;border-collapse:collapse;margin-bottom:20px;">
        <tr>${metricCells}</tr>
      </table>
      ${symptomsBlock}
      ${moodBlock}
      ${questionsBlock}
    </div>

    <p style="font-size:11px;color:#756a59;line-height:1.6;margin:20px 0 0;">
      This snapshot summarizes self-reported wellness tracking from Vida Lab. It is not a medical record, a diagnosis, or a substitute for clinical advice. The member is sharing it as a conversation starter. Please contact the member directly to confirm the appointment.
    </p>
  </div>
</body>
</html>`;
}

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}
