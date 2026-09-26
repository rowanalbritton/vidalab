import { createClientFromRequest } from 'npm:@base44/sdk@0.8.44';
import { initSupabase, adminListUsers } from "../../shared/supabaseServer.ts";

// Returns the user's current local hour (0-23) and date string (YYYY-MM-DD)
// in their IANA timezone, computed from the current UTC time.
function getLocalHourAndDate(timezone: string): { hour: number; dateStr: string } {
  const now = new Date();
  const fmt = new Intl.DateTimeFormat("en-CA", {
    timeZone: timezone || "UTC",
    hour: "2-digit",
    hour12: false,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const parts = fmt.formatToParts(now);
  const get = (type: string) => parts.find((p) => p.type === type)?.value || "";
  let hour = parseInt(get("hour"), 10);
  if (hour === 24) hour = 0;
  const dateStr = `${get("year")}-${get("month")}-${get("day")}`;
  return { hour, dateStr };
}

function checkInReminderHTML(appUrl: string): string {
  return `
    <div style="background:#ffffff;border:1px solid #E8E5DF;border-radius:22px;padding:32px;margin-bottom:20px;">
      <h1 style="font-family:Georgia,serif;font-size:28px;color:#2E463E;margin:0 0 12px;font-weight:400;letter-spacing:-0.02em;">You haven't checked in today</h1>
      <p style="font-size:15px;color:#5a655e;line-height:1.65;margin:0 0 24px;">Your patterns build one check-in at a time. It takes two minutes — energy, sleep, mood, and symptoms. Your future self will thank you.</p>
      <a href="${appUrl}/daily-signals" style="display:inline-block;background:#2E463E;color:#F9F8F5;padding:13px 26px;border-radius:100px;font-size:14px;font-weight:600;text-decoration:none;">Log today's signals &rarr;</a>
    </div>`;
}

function contentHTML(items: { title: string; type: string; url: string }[]): string {
  const itemsHTML = items
    .map(
      (c) => `
      <div style="padding:16px 0;border-bottom:1px solid #E8E5DF;">
        <p style="font-size:10px;text-transform:uppercase;letter-spacing:0.14em;color:#3c6b4f;font-weight:600;margin:0 0 6px;">${c.type}</p>
        <a href="${c.url}" style="font-family:Georgia,serif;font-size:18px;color:#2E463E;text-decoration:none;font-weight:400;line-height:1.3;">${c.title} &rarr;</a>
      </div>`
    )
    .join("");
  return `
    <div style="background:#ffffff;border:1px solid #E8E5DF;border-radius:22px;padding:32px;">
      <p style="font-size:11px;letter-spacing:0.17em;text-transform:uppercase;font-weight:600;color:#3c6b4f;margin:0 0 20px;">New on Vida Lab</p>
      ${itemsHTML}
    </div>`;
}

function emailWrapper(appUrl: string, body: string, email?: string): string {
  const unsubLink = email
    ? ` <a href="${appUrl}/unsubscribe?email=${encodeURIComponent(email)}" style="color:#3c6b4f;text-decoration:underline;">Unsubscribe</a>`
    : "";
  return `<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#F9F8F5;font-family:'DM Sans',Helvetica,Arial,sans-serif;">
  <div style="max-width:560px;margin:0 auto;padding:40px 24px;">
    <div style="text-align:center;margin-bottom:32px;">
      <span style="font-family:Georgia,serif;font-size:22px;color:#2E463E;letter-spacing:0.04em;font-weight:500;">VIDA LAB</span>
    </div>
    ${body}
    <div style="margin-top:40px;padding-top:24px;border-top:1px solid #E8E5DF;font-size:12px;color:#756a59;line-height:1.6;">
      <p style="margin:0 0 8px;">You're receiving this because you enabled reminders in your Vida Lab account. <a href="${appUrl}/daily-signals" style="color:#3c6b4f;text-decoration:underline;">Adjust your settings</a> anytime.${unsubLink}</p>
      <p style="margin:0;color:#a3b3a3;">VIDA LAB is an educational platform, not medical advice. Always consult a qualified healthcare professional.</p>
    </div>
  </div>
</body></html>`;
}

function base64UrlEncode(str: string): string {
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function sendGmail(accessToken: string, to: string, subject: string, html: string): Promise<void> {
  const mime = `To: ${to}\r\nSubject: ${subject}\r\nContent-Type: text/html; charset=UTF-8\r\nMIME-Version: 1.0\r\n\r\n${html}`;
  const raw = base64UrlEncode(mime);
  const res = await fetch("https://gmail.googleapis.com/gmail/v1/users/me/messages/send", {
    method: "POST",
    headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
    body: JSON.stringify({ raw }),
  });
  if (!res.ok) {
    const errText = await res.text();
    console.error("sendGmail: failed", { status: res.status, errText: errText.slice(0, 200) });
    throw new Error(`Gmail send failed (${res.status})`);
  }
}

export default async function (req: Request) {
  try {
    const base44 = createClientFromRequest(req);
    const { user, serviceEntities } = await initSupabase(req);

    // If called with a user token, require admin. Workflow calls (no token) are allowed.
    if (user && user.role !== "admin") {
      return new Response(JSON.stringify({ error: "Forbidden" }), { status: 403 });
    }

    const appUrl = (Deno.env.get("WIX_CHECKOUT_APP_URL") || "").replace(/\/$/, "");
    if (!appUrl) {
      console.error("send-reminders: WIX_CHECKOUT_APP_URL not set");
      return new Response(JSON.stringify({ error: "App URL not configured" }), { status: 500 });
    }

    // Get Gmail access token (SHARED connector — builder's Gmail sends reminders)
    let gmailToken: string;
    try {
      const conn = await base44.asServiceRole.connectors.getConnection("gmail");
      gmailToken = conn.accessToken;
    } catch (e) {
      console.error("send-reminders: Gmail not connected", e);
      return new Response(JSON.stringify({ error: "Gmail not connected" }), { status: 503 });
    }

    // Fetch all users with emails + profile data from Supabase
    const users = await adminListUsers();

    const now = new Date();
    const since = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    // Fetch recent content from Supabase
    let newContent: { title: string; type: string; url: string }[] = [];
    try {
      const [reports, explainers, articles, papers] = await Promise.all([
        serviceEntities.DiseaseReport.list("-created_date", 50),
        serviceEntities.Explainer.list("-created_date", 50),
        serviceEntities.SubstackArticle.list("-created_date", 50),
        serviceEntities.ResearchPaper.list("-created_date", 50),
      ]);

      reports
        .filter((r) => new Date(r.created_date) >= since && r.is_public !== false)
        .forEach((r) => newContent.push({ title: r.name, type: "Library report", url: `${appUrl}/library/${r.slug}` }));

      explainers
        .filter((e) => new Date(e.created_date) >= since && e.is_public !== false)
        .forEach((e) => newContent.push({ title: e.title, type: "Explainer", url: `${appUrl}/research` }));

      articles
        .filter((a) => new Date(a.created_date) >= since)
        .forEach((a) => newContent.push({ title: a.title, type: "Article", url: a.link || `${appUrl}/research` }));

      papers
        .filter((p) => new Date(p.created_date) >= since)
        .forEach((p) => newContent.push({ title: p.title, type: "Research paper", url: `${appUrl}/rowans-work` }));
    } catch (e) {
      console.error("send-reminders: failed to fetch content", e);
    }

    let sentCount = 0;
    let pushCount = 0;
    let processedCount = 0;

    for (const u of users) {
      if (!u.reminder_enabled && !u.content_updates_enabled) continue;

      const timezone = u.reminder_timezone || "UTC";
      const preferredHour = parseInt((u.reminder_time || "20:00").split(":")[0], 10) || 20;

      const { hour, dateStr } = getLocalHourAndDate(timezone);

      if (hour !== preferredHour) continue;
      if (u.last_reminder_date === dateStr) continue;

      // Skip if user already checked in today
      try {
        const userCheckins = await serviceEntities.DailyCheckin.filter({ created_by_id: u.id }, "-checkin_date", 5);
        const alreadyCheckedIn = userCheckins.some((c: any) => {
          const cDate = typeof c.checkin_date === "string" ? c.checkin_date.split("T")[0] : "";
          return cDate === dateStr;
        });
        if (alreadyCheckedIn) {
          try { await serviceEntities.User.update(u.id, { last_reminder_date: dateStr }); } catch (_) {}
          continue;
        }
      } catch (e) {
        console.error("send-reminders: failed to check checkins for " + u.email, e);
      }

      processedCount++;

      const sections: string[] = [];
      if (u.reminder_enabled) sections.push(checkInReminderHTML(appUrl));
      if (u.content_updates_enabled && newContent.length > 0) sections.push(contentHTML(newContent));

      if (sections.length === 0) {
        try { await serviceEntities.User.update(u.id, { last_reminder_date: dateStr }); } catch (_) {}
        continue;
      }

      const hasReminder = u.reminder_enabled;
      const hasContent = u.content_updates_enabled && newContent.length > 0;
      const subject = hasReminder && hasContent
        ? "Your Vida Lab digest"
        : hasContent ? "New on Vida Lab" : "Time for your daily check-in";

      try {
        await sendGmail(gmailToken, u.email, subject, emailWrapper(appUrl, sections.join(""), u.email));
        sentCount++;
      } catch (e) {
        console.error(`send-reminders: failed to email ${u.email}`, e);
      }

      if (u.reminder_enabled) {
        try {
          await base44.asServiceRole.integrations.Core.SendPushNotification({
            user_id: u.id,
            title: "Your daily check-in is waiting",
            content: "Two minutes to log your energy, mood, and symptoms. Your patterns build one check-in at a time.",
            action_label: "Check in now",
            action_url: `${appUrl}/daily-signals`,
          });
          pushCount++;
        } catch (e) {
          console.error(`send-reminders: failed to push notify ${u.email}`, e);
        }
      }

      try { await serviceEntities.User.update(u.id, { last_reminder_date: dateStr }); } catch (_) {}
    }

    console.log(`send-reminders: processed ${processedCount} users, sent ${sentCount} emails, ${pushCount} push, ${newContent.length} content items`);
    return new Response(JSON.stringify({ ok: true, processed: processedCount, sent: sentCount, push: pushCount, newContent: newContent.length }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("send-reminders: unhandled error", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
}