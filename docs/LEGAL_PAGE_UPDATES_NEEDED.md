# vidalab.co legal pages: updates needed before App Review

Checked 2026-09-26 against the live site (the `legalContent` bundle on vidalab.co) and the app as built. Nothing here has been changed. This is suggested wording for Rowan to review, edit, and publish.

Apple reviewers compare the privacy policy with the app's behavior and its App Privacy answers. The four gaps below are places where the live policy contradicts the app.

## 1. Age: 13 on the site, 16 in the app

The app blocks sign-up under 16, and the App Store listing says 16+.

**Privacy Policy, section 10 (Age requirement).** Replace the paragraph with:

> VIDA LAB is for people aged 16 and over. We do not knowingly collect personal information from anyone under 16. If you are 16 or older but under the age of majority where you live, please use VIDA LAB with a parent or guardian's involvement. If you believe someone under 16 has created an account, contact us at rowan@vidalab.co and we will delete it.

**Terms of Use, section 11 (Age requirement).** Replace the first two sentences with:

> You must be at least 16 to use VIDA LAB. If you are 16 or older but under the age of majority where you live, you may use VIDA LAB only with the involvement of a parent or guardian, who should review these terms with you and must agree to any purchase.

## 2. AI providers: not mentioned at all

The policy says "We do not share your check-in data with third parties." The Vida+ tools in the app send a check-in summary to Anthropic (with consent), which that sentence contradicts directly. In the app, when Ask Vida's own library has no answer and the member has agreed to a one-time prompt naming OpenAI, the typed question goes to OpenAI. If the member also turns on the health-summary setting, a short summary of their logged patterns goes with it. On the website, the Vida chat now sends messages to Anthropic (Claude).

Apple's Guideline 5.1.2(i) requires the policy to name third-party AI that receives personal data. Suggested new section, placed before "7. What we don't do":

> **AI features.** Some answers come from AI models run by other companies. In the iOS app, if Ask Vida can't answer from our own library, and only after you agree to a one-time prompt, your question is sent to OpenAI to generate a reply. If you also turn on "Include my approved health summary" in Settings, a short summary of your logged patterns is sent with it. It never includes your raw entries, Apple Health samples, meals, medications, name, or email. On our website, messages you send to the Vida chat are processed by Anthropic. In the iOS app, Vida+ tools (Body Weather, the Vida Differential, and the Appointment Concierge) send Anthropic a summary of up to 90 days of your check-in scores and tags, plus the focus areas and conditions you chose, only after you agree to a one-time prompt; your notes, meals, medications, Apple Health data, name, and email are not included. These providers process the text only to return an answer and do not use it to train their models. You can turn off AI features in the app at any time in Settings.

Confirm the "do not use it to train" line matches your OpenAI and Anthropic account settings (API data isn't used for training by default on either platform), then adjust section 7 to match:

> We do not share your check-in data with third parties, except as described under "AI features," and only when you choose to use those features.

## 3. Account deletion: "by contacting us" vs in-app

Section 8 says "You can delete your account at any time by contacting us." The app has self-serve deletion, which Apple requires. Suggested:

> Delete your account: You can delete your account and all of its data at any time in the app, under Settings > Delete account and data, or by contacting us at rowan@vidalab.co. This permanently deletes ...

(keep the rest of that sentence as it is).

## 4. Sign-in providers

The app now offers Sign in with Apple and Google. Suggested addition to the section on what you collect:

> If you sign in with Apple or Google, we receive your name and email address from that provider (with Apple, you can choose to hide your email, in which case we receive a private relay address). We don't receive your Apple or Google password. When you delete your account, we also revoke VIDA LAB's access to your Apple sign-in.

## 5. Location and appointment requests (added 2026-09-27)

The app's Appointment Concierge can now find doctors near the member and save appointment requests. Suggested addition:

> **Finding a doctor and requesting appointments.** If you choose "Use my location" in the Appointment Concierge, your device's location is used only for that search: it is sent to Apple Maps to find nearby practices and is not saved or sent to VIDA LAB. Appointment requests you save (the practice, your preferred date and time, and the reason and notes you type) are stored in your account so you can see them in the app and on vidalab.co, and are deleted when you delete your account. If you email a practice, the email is sent from your own email app; VIDA LAB doesn't see it.
>
> **Meditation.** Meditation sessions you complete, and the optional before-and-after stress answers, are stored only on your device. Sessions with a guide use AI-generated voices, made by VIDA LAB with ElevenLabs; they are not recordings of real people reading the sessions. Only VIDA LAB's own scripts were sent to ElevenLabs to make them, never anything about you. The audio is downloaded from VIDA LAB's storage the first time you play a session and kept on your device afterward. These downloads don't include your account or any health information. If a file can't be downloaded, and for library sessions, your device's built-in voice reads the words instead, and nothing is sent to a server.

App Store Connect note: the guide voices are generated with ElevenLabs under VIDA LAB's paid plan (commercial use included). Only the scripts are sent, once, at production time, so no App Privacy answers change: no member data reaches ElevenLabs.

## App Store Connect: App Privacy answers

Make these match the manifest in the app (`PrivacyInfo.xcprivacy`), all linked to the user, none used for tracking, all for App Functionality: Health, Email Address, Name, User ID, Purchase History, Other User Content (community posts and Ask Vida questions).
