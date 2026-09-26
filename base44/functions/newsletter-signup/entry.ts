import { createClientFromRequest } from 'npm:@base44/sdk@0.8.44';
import { secrets } from 'base44:runtime';
import { initSupabase } from "../../shared/supabaseServer.ts";

export default async function(req) {
  try {
    const base44 = createClientFromRequest(req);
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
    } catch (e) {}
    if (!alreadyInDb) {
      await serviceEntities.NewsletterSignup.create({ email, source: "site" });
    }

    // ===== Mailchimp sync (stays on Base44 connector) =====
    try {
      const listId = secrets.get("MAILCHIMP_LIST_ID");
      const { accessToken } = await base44.asServiceRole.connectors.getConnection("mailchimp");

      const metaRes = await fetch("https://login.mailchimp.com/oauth2/metadata", {
        headers: { Authorization: `OAuth ${accessToken}` }
      });
      const meta = await metaRes.json();
      const dc = meta.dc;

      const mcRes = await fetch(`https://${dc}.api.mailchimp.com/3.0/lists/${listId}/members`, {
        method: "POST",
        headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
        body: JSON.stringify({ email_address: email, status: "subscribed" })
      });

      if (!mcRes.ok) {
        const mcErr = await mcRes.json().catch(() => ({}));
        if (mcErr.title !== "Member Exists") {
          console.error("Mailchimp add error:", mcErr);
        }
      }
    } catch (mcError) {
      console.error("Mailchimp sync failed:", mcError);
    }

    return Response.json({ ok: true, message: "You're in. Stay curious." });
  } catch (error) {
    console.error("Newsletter signup error:", error);
    return Response.json({ error: "Something went wrong. Please try again." }, { status: 500 });
  }
}