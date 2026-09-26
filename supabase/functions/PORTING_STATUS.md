# Base44 to Supabase: Edge Function status

Updated 2026-09-26. Everything here is local only. Nothing has been deployed.

## Ported (16), type-check clean

`deno check --config deno.json */index.ts _shared/*.ts` passes with no errors.

| Function | Needs these secrets | Notes |
| --- | --- | --- |
| appointment-concierge | ANTHROPIC_API_KEY | |
| body-weather-forecast | ANTHROPIC_API_KEY | |
| vida-differential | ANTHROPIC_API_KEY | |
| experiment-results | ANTHROPIC_API_KEY | |
| vida-chat | ANTHROPIC_API_KEY | New. Replaces vida-chat-gate, vida-chat-send and the Base44 "vida" agent. Stateless: the page sends the conversation each time and nothing is stored. `src/pages/Sasha.jsx` already calls it. |
| create-checkout | WIX_CHECKOUT_API_KEY, WIX_CHECKOUT_SITE_ID, WIX_CHECKOUT_APP_URL | |
| check-payment-status | WIX_CHECKOUT_API_KEY, WIX_CHECKOUT_SITE_ID | |
| payments-webhook | WIX_CHECKOUT_WEBHOOK_PUBLIC_KEY | Deploy with `--no-verify-jwt` (Wix doesn't send a Supabase token; its own signature is checked instead). Point the Wix webhook at the new URL after deploying. |
| send-reminders | RESEND_API_KEY, VIDA_FROM_EMAIL, WIX_CHECKOUT_APP_URL, CRON_SECRET (optional) | Gmail replaced with Resend. Base44 web push dropped; the iOS app sends its own reminders. |
| send-weekly-newsletter | RESEND_API_KEY, VIDA_FROM_EMAIL, CRON_SECRET (optional) | |
| send-appointment-reminders | RESEND_API_KEY, VIDA_FROM_EMAIL | |
| send-appointment-snapshot | RESEND_API_KEY, VIDA_FROM_EMAIL | |
| newsletter-signup | MAILCHIMP_API_KEY, MAILCHIMP_LIST_ID (both optional) | Without them, signups still save and the Mailchimp sync is skipped. |
| unsubscribe | none | |
| flag-community-content | none | |

Every function also uses SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY, which Supabase provides automatically.

### CRON_SECRET

The scheduled sends (send-reminders, send-weekly-newsletter) used to trust any caller without a user token, which on Supabase includes anyone holding the public anon key. After `supabase secrets set CRON_SECRET=<random>`, they only run for an admin or for a request with an `x-cron-secret: <same value>` header, so add that header to the scheduled jobs at the same time.

## Retired, not ported

- **mobile-checkin, mobile-dashboard, mobile-favorite-toggle.** Nothing calls them. The iOS app reads and writes Supabase directly.
- **vida-chat-gate, vida-chat-send.** Replaced by vida-chat.

## Needs a decision (8)

These use Base44 OAuth connectors to Rowan's own Google and Instagram accounts. Porting each one means registering an OAuth app with Google or Meta and storing a refresh token as a secret, so they stay on Base44 until Rowan decides which ones are still wanted:

- Google (6): add-google-calendar-event, sync-checkin-to-calendar, sync-doctors-to-contacts, sync-practices-to-tasks, export-to-google-sheets, save-snapshot-to-drive.
- Instagram (2): instagram-insights, post-daily-instagram. These share one Meta connection.

## To go live

1. `supabase secrets set` for the secrets above.
2. `supabase functions deploy <name>` for each function (payments-webhook with `--no-verify-jwt`).
3. Switch the site's `base44.functions.invoke(...)` calls to `supabase.functions.invoke(...)`, as Sasha.jsx now does.
4. Move the four Base44 schedules (send-reminders, send-appointment-reminders, send-weekly-newsletter, post-daily-instagram) to Supabase cron.
