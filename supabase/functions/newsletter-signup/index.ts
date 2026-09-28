import { serveWithCors } from "../_shared/cors.ts";
import { initSupabase } from "../_shared/entities.ts";

// Mailchimp was reached through Base44's OAuth connector. On Supabase it uses
// a standard API key instead, set with:
//   supabase secrets set MAILCHIMP_API_KEY=... MAILCHIMP_LIST_ID=...
// The key ends in its data-center suffix (for example "-us21"), which is also
// the API host. Without both secrets the sync is skipped and the signup is
// still saved, so the form never fails because Mailchimp is unconfigured.
const MAILCHIMP_API_KEY = Deno.env.get("MAILCHIMP_API_KEY") || "";
const MAILCHIMP_LIST_ID = Deno.env.get("MAILCHIMP_LIST_ID") || "";

async function syncToMailchimp(email: string) {
  if (!MAILCHIMP_API_KEY || !MAILCHIMP_LIST_ID) return;
  const dc = MAILCHIMP_API_KEY.split("-").pop();
  if (!dc) return;

  const res = await fetch(`https://${dc}.api.mailchimp.com/3.0/lists/${MAILCHIMP_LIST_ID}/members`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(`vida:${MAILCHIMP_API_KEY}`)}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ email_address: email, status: "subscribed" }),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    if (err.title !== "Member Exists") {
      console.error("newsletter-signup: Mailchimp add error", err);
    }
  }
}

serveWithCors(async (req: Request) => {
  try {
    const { body, serviceEntities } = await initSupabase(req);
    const email = body?.email?.trim().toLowerCase();
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return Response.json({ error: "Valid email required" }, { status: 400 });
    }

    // Save to Supabase (skip if already captured)
    let alreadyInDb = false;
    try {
      const existing = await serviceEntities.NewsletterSignup.filter({ email });
      if (existing.length > 0) alreadyInDb = true;
    } catch (e) {
      console.error("newsletter-signup: lookup failed", e);
    }
    if (!alreadyInDb) {
      await serviceEntities.NewsletterSignup.create({ email, source: "site" });
    }

    try {
      await syncToMailchimp(email);
    } catch (mcError) {
      console.error("newsletter-signup: Mailchimp sync failed", mcError);
    }

    return Response.json({ ok: true, message: "You're in. Stay curious." });
  } catch (error) {
    console.error("newsletter-signup: unhandled error", error);
    return Response.json({ error: "Something went wrong. Please try again." }, { status: 500 });
  }
});
