You are working in the VIDA LAB iOS project at:
/Users/rowan/Desktop/vida-lab/vida lab/VIDA_LAB_RECOVERED/ios-vida-signals (VIDALAB.xcodeproj, SwiftUI, Supabase, RevenueCat).

Goal: get the app building cleanly and ready for App Store submission. Work through the tasks in order, build after each one (Cmd+B), and fix any compile errors you introduce. Don't redesign any screens or rewrite the copy. Make only the changes listed here. When you finish, give me a short list of what you changed and anything you couldn't do.

CONTEXT: CHANGES ALREADY MADE (review them, don't redo them)
- VIDALAB/Utilities/AIDisclosure.swift: providerDescription is now "OpenAI, a third-party AI provider". The deployed Supabase Edge Function `ask-vida` calls OpenAI's Responses API, so this wording is correct.
- VIDALAB/Views/SignInView.swift: Create account now asks for a date of birth. minimumAge = 16. The picker starts at today's date, so nobody passes by leaving it untouched. If the date shows someone under 16, the device flag "vida.signup.ageIneligible" is set and account creation stays blocked on that device. The birth date is never stored.
- VIDALAB/Services/AuthManager.swift: signUp(email:password:name:ageConfirmed:) writes `age_confirmed_16_plus` to the Supabase user metadata. ageConfirmed defaults to false.
- metadata/app-info/en-US.json: subtitle is now "Track symptoms, see patterns".
- metadata/version/1.0/en-US.json: the description now says a free account is required and "Vida Lab is for ages 16 and over."
- Sign-in stays REQUIRED (ContentView shows SignInView until auth.isSignedIn). This is intentional. Don't make it optional.

TASKS
1. Build the project. Fix any compile errors in SignInView.swift and AuthManager.swift without changing their behavior. Then search the whole project for other calls to `signUp(` (for example in WebAccessView.swift) and make sure they still compile.
2. Check the new date-of-birth field on Create account in light and dark mode and at the largest Dynamic Type size. It should match the existing labeledField styling (Vida.paper background, 14pt continuous corner radius, Vida.hairline border). Only adjust spacing if something is clipped or misaligned.
3. Delete VIDALAB/RCProbe_TEMP.swift and remove its call from VIDALABApp.swift (the `#if DEBUG RCProbeTemp.runIfRequested()` block). Also remove the file reference from the target if the project doesn't use synchronized folders.
4. Add a StoreKit Configuration file (VIDALAB/VidaPlus.storekit) for local testing. Create a subscription group named "vidalab+" containing:
   - vida_plus_monthly, 1 month, $9.99, display name "Vida+ Monthly"
   - vida_plus_yearly, 1 year, $69.99, display name "Vida+ Yearly"
   - vida_plus_family, 1 year, $89.99, display name "Vida+ Family"
   Select it under Scheme > Run > Options > StoreKit Configuration ONLY for local testing, and tell me how to switch it off. With it on, StoreKit purchases don't go through the real sandbox. Also note that RevenueCat only uses this file when it is configured with a `test_` key or in StoreKit testing mode. Don't add any API keys yourself.
5. Check Secrets.plist and .gitignore: Secrets.plist and Config.swift must stay gitignored. Don't print, move, or commit any key values.
6. Search the project for any remaining "13" age references or "account is optional" wording in Swift strings, Settings, onboarding, or docs, and update them to 16+ and required sign-in. Leave vidalab.co legal-page text alone (it already says 16+).
7. Check that PrivacyInfo.xcprivacy still matches reality: health data and email are collected and linked to the user, nothing is used for tracking, and the Ask Vida question text goes to OpenAI. Report any mismatch rather than guessing.
8. Run the unit tests (VIDALABTests) and report failures. Fix only the ones caused by the changes above.
9. Archive a Release build (Product > Archive) to confirm it compiles in Release, where the RevenueCat test key path is excluded.

DON'T
- Don't touch the Supabase Edge Functions, RevenueCat dashboard, or App Store Connect.
- Don't add third-party packages.
- Don't use em dashes in any user-facing copy.
