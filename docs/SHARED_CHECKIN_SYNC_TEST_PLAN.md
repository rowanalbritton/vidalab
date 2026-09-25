# Shared encrypted check-in sync — test plan

Run this only after the reviewed additive `ios_checkin_events` migration is
applied to an isolated Supabase development branch or another non-production
environment. Use synthetic accounts and fictional entries only.

## Test accounts

- **Account A** on two iOS simulators/devices and one browser.
- **Account B** on a separate simulator/device.
- Use distinct fake email addresses and no production health entries.

## Required cases

1. **First restore**
   - Log a morning and an evening reading for Account A on device 1.
   - Sign in as Account A on device 2 and unlock the same escrowed key.
   - Confirm both readings and their local date/time zone appear once.

2. **Offline queue and retry**
   - Disable networking on device 1, create a reading, then return online.
   - Confirm the local save remains visible while offline and the same stable
     client ID reaches the server exactly once after retry.

3. **Concurrent periods**
   - Create a morning reading on device 1 and an evening reading on device 2
     for the same local date before either syncs.
   - Reconnect both. Confirm both readings survive; neither device may replace
     the whole day with its own copy.

4. **Same-reading conflict**
   - Edit the same reading on two devices with distinguishable values.
   - Submit the newer edit first, then the older delayed retry.
   - Confirm the newest `client_updated_at` wins and the older retry returns
     the accepted server record without overwriting it.

5. **Deletion tombstone**
   - Delete a synced reading while offline, reconnect, then sync another
     device that still has the old value.
   - Confirm the tombstone wins and the old device cannot resurrect it.

6. **Timezone and backdating**
   - Log entries around a timezone change and add a backdated entry.
   - Confirm `local_date` remains the member's intended calendar date and
     `recordedAt` remains an absolute timestamp.

7. **Account isolation / RLS**
   - Attempt reads and RPC writes as Account B using Account A client IDs.
   - Confirm no Account A rows are visible or mutable. Verify RLS with the
     Supabase dashboard's RLS tester as both authenticated accounts.

8. **Website interoperability**
   - In a browser, unlock Account A's escrowed key locally with its passphrase.
   - Confirm browser code can decrypt and render its encrypted events without
     transmitting the passphrase or a service-role key.

## Production readiness gate

Do not deploy until every case passes, the Data API exposes the new table to
authenticated clients, RLS policies are verified, and Supabase Security and
Performance Advisors have been reviewed. Keep the existing encrypted
`check_ins` dual-write in place through the transition; do not replace or
backfill the plaintext `daily_checkins` table from encrypted health data.
