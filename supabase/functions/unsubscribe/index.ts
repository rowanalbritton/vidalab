import { initSupabase } from "../_shared/entities.ts";

Deno.serve(async (req: Request) => {
  try {
    const { body, user, serviceEntities } = await initSupabase(req);
    const email = body?.email?.trim().toLowerCase();
    const token = String(body?.token || "");
    const reason = String(body?.reason || "");
    const feedback = String(body?.feedback || "");

    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return new Response(JSON.stringify({ error: "Valid email required" }), { status: 400 });
    }

    const reasonText = [reason, feedback].filter(Boolean).join(": ") || "no reason given";

    // 1. Unsubscribe from the newsletter list — requires a valid token
    try {
      const existing = await serviceEntities.NewsletterSignup.filter({ email });
      if (existing.length > 0) {
        const record = existing[0];
        if (!record.unsubscribe_token || record.unsubscribe_token !== token) {
          return new Response(
            JSON.stringify({ error: "Invalid or missing unsubscribe token. Please use the unsubscribe link from your email." }),
            { status: 403, headers: { "Content-Type": "application/json" } }
          );
        }
        await serviceEntities.NewsletterSignup.update(record.id, {
          status: "unsubscribed",
          unsubscribe_reason: reasonText,
        });
      }
    } catch (e) {
      console.error("unsubscribe: failed to update NewsletterSignup", e);
    }

    // 2. Disable email reminders — only if the caller is authenticated as the user matching this email
    try {
      if (user && user.email && user.email.toLowerCase() === email) {
        await serviceEntities.User.update(user.id, {
          reminder_enabled: false,
          content_updates_enabled: false,
        });
        console.log("unsubscribe: disabled reminders for authenticated user", { email });
      }
    } catch (e) {
      console.error("unsubscribe: failed to disable user reminders", e);
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("unsubscribe: unhandled error", error);
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : String(error) }), { status: 500 });
  }
});
