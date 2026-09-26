import { initSupabase } from "../_shared/entities.ts";
import { sendEmail, EmailUnavailable } from "../_shared/email.ts";
import { isAllowedScheduledCaller } from "../_shared/cron.ts";

function newsletterHTML(
  appUrl: string,
  items: { title: string; type: string; url: string }[],
  unsubUrl: string
): string {
  const itemsHTML = items
    .map(
      (c) => `
      <div style="padding:16px 0;border-bottom:1px solid #E8E5DF;">
        <p style="font-size:10px;text-transform:uppercase;letter-spacing:0.14em;color:#3c6b4f;font-weight:600;margin:0 0 6px;">${c.type}</p>
        <a href="${c.url}" style="font-family:Georgia,serif;font-size:18px;color:#2E463E;text-decoration:none;font-weight:400;line-height:1.3;">${c.title} &rarr;</a>
      </div>`
    )
    .join("");

  return `<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#F9F8F5;font-family:'DM Sans',Helvetica,Arial,sans-serif;">
  <div style="max-width:560px;margin:0 auto;padding:40px 24px;">
    <div style="text-align:center;margin-bottom:32px;">
      <span style="font-family:Georgia,serif;font-size:22px;color:#2E463E;letter-spacing:0.04em;font-weight:500;">VIDA LAB</span>
    </div>
    <p style="font-size:11px;letter-spacing:0.17em;text-transform:uppercase;font-weight:600;color:#3c6b4f;margin:0 0 8px;">This Week</p>
    <h1 style="font-family:Georgia,serif;font-size:32px;color:#2E463E;margin:0 0 16px;font-weight:400;letter-spacing:-0.02em;">What's new in the lab</h1>
    <p style="font-size:15px;color:#5a655e;line-height:1.65;margin:0 0 32px;">Here's what we added to Vida Lab this week — clear, careful explanations of what's changing in medicine.</p>
    <div style="background:#ffffff;border:1px solid #E8E5DF;border-radius:22px;padding:32px;margin-bottom:20px;">
      ${itemsHTML}
    </div>
    <div style="text-align:center;margin:32px 0;">
      <a href="${appUrl}/library" style="display:inline-block;background:#2E463E;color:#F9F8F5;padding:13px 26px;border-radius:100px;font-size:14px;font-weight:600;text-decoration:none;">Explore the full library &rarr;</a>
    </div>
    <div style="margin-top:40px;padding-top:24px;border-top:1px solid #E8E5DF;font-size:12px;color:#756a59;line-height:1.6;">
      <p style="margin:0 0 8px;">You're receiving this because you subscribed to the Vida Lab newsletter. <a href="${unsubUrl}" style="color:#3c6b4f;text-decoration:underline;">Unsubscribe</a> anytime.</p>
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
      console.error("send-weekly-newsletter: WIX_CHECKOUT_APP_URL not set");
      return new Response(JSON.stringify({ error: "App URL not configured" }), { status: 500 });
    }

    const now = new Date();
    const since = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000); // last 7 days

    // Fetch content from the past week
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
      console.error("send-weekly-newsletter: failed to fetch content", e);
    }

    if (newContent.length === 0) {
      console.log("send-weekly-newsletter: no new content this week, skipping");
      return new Response(JSON.stringify({ ok: true, sent: 0, reason: "no new content" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Get all subscribers — include old records without a status field (treat as subscribed)
    const allSubs = await serviceEntities.NewsletterSignup.list("-created_date", 5000);
    const subscribers = allSubs.filter((s) => !s.status || s.status === "subscribed");

    let sentCount = 0;
    for (const sub of subscribers) {
      // Ensure a proof-of-ownership token exists on the record so the
      // unsubscribe endpoint can verify the link came from this email.
      let token = sub.unsubscribe_token;
      if (!token) {
        token = (crypto.randomUUID() + crypto.randomUUID()).replace(/-/g, "");
        try {
          await serviceEntities.NewsletterSignup.update(sub.id, { unsubscribe_token: token });
        } catch (e) {
          console.error(`send-weekly-newsletter: failed to store token for ${sub.email}`, e);
        }
      }
      const unsubUrl = `${appUrl}/unsubscribe?email=${encodeURIComponent(sub.email)}&token=${token}`;
      try {
        await sendEmail({
          to: sub.email,
          subject: "This week on Vida Lab",
          html: newsletterHTML(appUrl, newContent, unsubUrl),
        });
        sentCount++;
      } catch (e) {
        console.error(`send-weekly-newsletter: failed to email ${sub.email}`, e);
      }
    }

    console.log(`send-weekly-newsletter: sent ${sentCount} newsletters to ${subscribers.length} subscribers, ${newContent.length} new content items`);
    return new Response(JSON.stringify({ ok: true, sent: sentCount, subscribers: subscribers.length, newContent: newContent.length }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("send-weekly-newsletter: unhandled error", error);
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : String(error) }), { status: 500 });
  }
});
