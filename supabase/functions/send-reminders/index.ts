import { initSupabase, adminListUsers } from "../_shared/entities.ts";
import { sendEmail } from "../_shared/email.ts";
import { isAllowedScheduledCaller } from "../_shared/cron.ts";

// Ported from Base44. Two changes from the original:
// - Email goes through Resend (_shared/email.ts) instead of a Gmail connector.
// - Base44's web push integration has no Supabase equivalent, so it is gone.
//   iOS members get their reminder from the app itself.

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

Deno.serve(async (req: Request) => {
  try {
    const { user, serviceEntities } = await initSupabase(req);

    // Admins, or the scheduler once CRON_SECRET is set (see _shared/cron.ts).
    if (!isAllowedScheduledCaller(req, user)) {
      return new Response(JSON.stringify({ error: "Forbidden" }), { status: 403 });
    }

    const appUrl = (Deno.env.get("WIX_CHECKOUT_APP_URL") || "").replace(/\/$/, "");
    if (!appUrl) {
      console.error("send-reminders: WIX_CHECKOUT_APP_URL not set");
      return new Response(JSON.stringify({ error: "App URL not configured" }), { status: 500 });
    }

    // Fetch all users with emails + profile data from Supabase
    const users = await adminListUsers();

    const now = new Date();
    const since = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    // Fetch recent content from Supabase
    const newContent: { title: string; type: string; url: string }[] = [];
    try {
      const [reports, explainers, articles, papers] = await Promise.all([
        serviceEntities.DiseaseReport.list("-created_date", 50),
        serviceEntities.Explainer.list("-created_date", 50),
        serviceEntities.SubstackArticle.list("-created_date", 50),
        serviceEntities.ResearchPaper.list("-created_date", 50),
      ]);

      reports
        .filter((r: any) => new Date(r.created_date) >= since && r.is_public !== false)
        .forEach((r: any) => newContent.push({ title: r.name, type: "Library report", url: `${appUrl}/library/${r.slug}` }));

      explainers
        .filter((e: any) => new Date(e.created_date) >= since && e.is_public !== false)
        .forEach((e: any) => newContent.push({ title: e.title, type: "Explainer", url: `${appUrl}/research` }));

      articles
        .filter((a: any) => new Date(a.created_date) >= since)
        .forEach((a: any) => newContent.push({ title: a.title, type: "Article", url: a.link || `${appUrl}/research` }));

      papers
        .filter((p: any) => new Date(p.created_date) >= since)
        .forEach((p: any) => newContent.push({ title: p.title, type: "Research paper", url: `${appUrl}/rowans-work` }));
    } catch (e) {
      console.error("send-reminders: failed to fetch content", e);
    }

    let sentCount = 0;
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
        await sendEmail({ to: u.email, subject, html: emailWrapper(appUrl, sections.join(""), u.email) });
        sentCount++;
      } catch (e) {
        console.error(`send-reminders: failed to email ${u.email}`, e);
      }

      try { await serviceEntities.User.update(u.id, { last_reminder_date: dateStr }); } catch (_) {}
    }

    console.log(`send-reminders: processed ${processedCount} users, sent ${sentCount} emails, ${newContent.length} content items`);
    return new Response(JSON.stringify({ ok: true, processed: processedCount, sent: sentCount, newContent: newContent.length }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("send-reminders: unhandled error", error);
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : String(error) }), { status: 500 });
  }
});
