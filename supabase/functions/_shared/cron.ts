// Who may trigger a scheduled send (reminders, newsletter).
//
// On Base44 a workflow call arrived with no user token, so "no token" meant
// "the scheduler". On Supabase any visitor holding the public anon key also
// arrives without a user, so that rule alone would let anyone set off a send.
//
// Set `CRON_SECRET` (supabase secrets set CRON_SECRET=...) and have the
// scheduled job send it in an `x-cron-secret` header. Until the secret is set,
// the old rule applies so existing schedules keep working.

export function isAllowedScheduledCaller(
  req: Request,
  user: { role?: string } | null,
): boolean {
  if (user) return user.role === "admin";

  const secret = Deno.env.get("CRON_SECRET");
  if (!secret) return true;
  return req.headers.get("x-cron-secret") === secret;
}
