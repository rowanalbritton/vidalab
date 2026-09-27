# App Store Connect: paste these in

## App Information > Subtitle
Track symptoms, see patterns

## Version 1.0 > Description (three edits, leave the rest as is)
- Replace "An account is optional; reviewers can use the core app without signing in." with:
  A free account keeps your journal encrypted and backed up across your devices.
- Replace "Account creation and Apple Health access are not required to explore the core app." with:
  Apple Health access is optional.
- Replace "Vida Lab is for adults 16 and over." with:
  Vida Lab is for ages 16 and over.

## Version 1.0 > App Review Information > Notes
VIDA LAB is a wellness journaling app for people managing chronic illness. It surfaces correlations in a user's own logged data and never diagnoses, treats, or claims causation.

A free account is required because each member's journal is encrypted on-device (AES-GCM) and backed up to that account; our servers store ciphertext and cannot read symptom content. Please use the demo account provided in the Sign-In Information fields.

Accounts are for ages 16 and over, confirmed with a date-of-birth check at sign-up. The birth date is not stored.

Ask Vida answers from a cited in-app library first. Only if the library has no answer, and only after a one-time permission prompt that names OpenAI, is the typed question sent to OpenAI. Permission can be withdrawn in Settings.

The Vida+ tools Body Weather, the Vida Differential, and the Appointment Concierge send a summary of the member's own check-in scores and tags to Anthropic (Claude) to write an educational result, only after a one-time permission prompt that names Anthropic and lists what is and isn't sent. Notes, meals, medications, and Apple Health data are never sent. Every result says it is educational and not a diagnosis. Permission can be withdrawn in Settings > Vida+ tools.

The Appointment Concierge can find nearby doctors from VIDA LAB's curated directory and Apple Maps. Using the device location is optional (When In Use, only on tap); a city or ZIP code works instead, and location is not stored or sent to our servers. Appointment requests are saved to the member's account; the member books by calling the office, emailing from their own Mail app, or the practice's website. The app does not book on a practice's behalf.

Community posts can be reported and authors blocked from each post and reply; moderators can hide posts.

Apple Health access is optional and read-only. Account deletion is available in-app at Settings > Delete account and data.

Vida+ is an auto-renewing subscription sold only through In-App Purchase. Viewing an already-generated report is never paywalled.

## Sign-In Information
The demo username is currently "rowanalbritton". The app signs in with an email address, so change it to the demo account's full email and make sure that account can actually sign in.

## Each subscription (Monthly, Yearly, Family) > Review Information
Upload one screenshot of the Vida+ paywall (any iPhone screenshot size). This is the last thing keeping all three at "Missing Metadata".

## Age Rating
Answer the questionnaire honestly (Medical/Treatment Information: Frequent; user-generated content/social features: Yes). If the result is below 16+, use the override to set 16+.

## Sandbox tester
Users and Access > Sandbox > add a tester with an email you control and haven't used as an Apple Account. Sign in with it on your iPhone under Settings > Developer > Sandbox Apple Account.
