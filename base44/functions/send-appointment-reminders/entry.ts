// Sends email reminders 24 hours before a member's confirmed/requested appointment.
// Runs on a schedule. For each appointment scheduled for tomorrow, it emails the
// owner and marks reminder_sent=true.

import { createClientFromRequest } from "npm:@base44/sdk@0.8.48";
import { initSupabase, adminListUsers } from "../../shared/supabaseServer.ts";

export default async function (req: Request) {
  try {
    const base44 = createClientFromRequest(req);
    const { user, serviceEntities } = await initSupabase(req);

    // If called with a user token, require admin. Workflow calls (no token) are allowed.
    if (user && user.role !== "admin") {
      return new Response(JSON.stringify({ error: "Forbidden" }), { status: 403 });
    }

    const appUrl = (Deno.env.get("WIX_CHECKOUT_APP_URL") || "").replace(/\/$/, "");

    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const y = tomorrow.getFullYear();
    const m = String(tomorrow.getMonth() + 1).padStart(2, "0");
    const d = String(tomorrow.getDate()).padStart(2, "0");
    const tomorrowStr = `${y}-${m}-${d}`;

    const appointments = await serviceEntities.Appointment.filter({
      appointment_date: tomorrowStr,
    });

    const eligible = appointments.filter(
      (a: any) => !a.reminder_sent && (a.status === "confirmed" || a.status === "requested")
    );

    // Get all users with emails for lookup
    const allUsers = await adminListUsers();
    const userMap: Record<string, any> = {};
    allUsers.forEach((u: any) => { userMap[u.id] = u; });

    let sentCount = 0;
    for (const apt of eligible) {
      try {
        const u = userMap[apt.created_by_id];
        if (!u?.email) continue;

        const html = buildEmail(apt, appUrl);
        await base44.asServiceRole.integrations.Core.SendEmail({
          to: u.email,
          subject: `Reminder: Your appointment tomorrow — ${apt.practice_name || apt.doctor_name || "Doctor"}`,
          html,
        });

        await serviceEntities.Appointment.update(apt.id, { reminder_sent: true });
        sentCount++;
      } catch (e) {
        console.error(`send-appointment-reminders: failed for appointment ${apt.id}`, e);
      }
    }

    console.log(`send-appointment-reminders: sent ${sentCount} reminders for ${tomorrowStr}`);
    return new Response(JSON.stringify({ ok: true, sent: sentCount, date: tomorrowStr }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("send-appointment-reminders: unhandled error", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
}

function buildEmail(apt: any, appUrl: string): string {
  const time = apt.appointment_time || "";
  const dateTime = time ? `${apt.appointment_date} at ${time}` : apt.appointment_date;
  const practice = apt.practice_name || apt.doctor_name || "your appointment";

  return `<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#F9F8F5;font-family:'DM Sans',Helvetica,Arial,sans-serif;">
  <div style="max-width:560px;margin:0 auto;padding:40px 24px;">
    <div style="text-align:center;margin-bottom:32px;">
      <span style="font-family:Georgia,serif;font-size:22px;color:#2E463E;letter-spacing:0.04em;font-weight:500;">VIDA LAB</span>
    </div>
    <div style="background:#ffffff;border:1px solid #E8E5DF;border-radius:22px;padding:32px;margin-bottom:20px;">
      <h1 style="font-family:Georgia,serif;font-size:26px;color:#2E463E;margin:0 0 12px;font-weight:400;letter-spacing:-0.02em;">Your appointment is tomorrow</h1>
      <p style="font-size:15px;color:#5a655e;line-height:1.65;margin:0 0 24px;">A friendly reminder from Vida Lab.</p>
      <div style="background:#F9F8F5;border-radius:16px;padding:20px;margin-bottom:24px;">
        <p style="margin:0 0 8px;font-size:13px;color:#5a655e;"><strong style="color:#2E463E;">When:</strong> ${dateTime}</p>
        <p style="margin:0 0 8px;font-size:13px;color:#5a655e;"><strong style="color:#2E463E;">Where:</strong> ${practice}</p>
        ${apt.specialty ? `<p style="margin:0 0 8px;font-size:13px;color:#5a655e;"><strong style="color:#2E463E;">Specialty:</strong> ${apt.specialty}</p>` : ""}
        ${apt.reason ? `<p style="margin:0;font-size:13px;color:#5a655e;"><strong style="color:#2E463E;">Reason:</strong> ${apt.reason}</p>` : ""}
      </div>
      ${appUrl ? `<a href="${appUrl}/doctor-finder" style="display:inline-block;background:#2E463E;color:#F9F8F5;padding:13px 26px;border-radius:100px;font-size:14px;font-weight:600;text-decoration:none;">View appointment details</a>` : ""}
    </div>
    <div style="margin-top:40px;padding-top:24px;border-top:1px solid #E8E5DF;font-size:12px;color:#a3b3a3;line-height:1.6;">
      <p style="margin:0;">VIDA LAB is an educational platform, not medical advice. Always consult a qualified healthcare professional.</p>
    </div>
  </div>
</body></html>`;
}