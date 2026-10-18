# Privacy Policy — Bé Vui Học

Effective date: 18 October 2026

Bé Vui Học is a learn-through-play app for children aged 3–6. This policy explains what data the app handles, where it is kept and how parents can delete it. In short: **no accounts, no email, no ads, no analytics, no in-app purchases, no tracking, and no selling or sharing of data**. Learning progress stays on the family's device.

## 1. Data stored on the device

- Child profile: **only a nickname** typed by the parent or child (up to 20 characters; a home nickname is enough, no real full name needed) and the mascot the child picks. No birth date, photo, email, phone number or address.
- Learning progress: stars, completed lessons, right/wrong answers and common mix-ups (used to suggest review), minutes played per day, play tickets, in-game items and pets.
- Settings: language, sound, music, time limit and other choices in the Parents area.

This data is kept in the app's private storage on the device (shared_preferences) and is **not sent anywhere**, unless a parent turns on "Use on several devices" ("Dùng trên nhiều máy", section 2).

## 2. Multi-device sync with a family code (optional, off by default)

Parents can turn on sync in the Parents area (behind the parental gate) or enter a family code when creating a profile on a new device.

- The app creates a random 16-character **family code** on the device. No email, password or account is needed.
- From this code the device derives an encryption key (PBKDF2-SHA-256) and a storage slot name (a SHA-256 hash of the code). The family code itself is **never sent**.
- The data in section 1 is **end-to-end encrypted on the device** (AES-256-GCM) before it is sent to **Google Cloud Firestore** (Google's Firebase service, servers in Singapore, region asia-southeast1). The server only holds: the slot name (a hash), a version number, the encrypted data block and the time of the last update.
- Nobody can read that data block without the family code — not the developer and not Google. We do not have your family code and cannot link a storage slot to any person.
- The server copy is kept until a parent deletes it. Tap **"Delete the server copy"** ("Xoá bản trên máy chủ") in the Parents area to delete it immediately. If the code is lost, nobody can recover the server copy.

## 3. Remote configuration (Firebase Remote Config)

When it starts, the app downloads a few general settings from Google's Firebase Remote Config (for example turning sync on or off, or a short notice for parents). To do this the Firebase library creates a **Firebase installation ID**: a random string tied to this installation of the app on this device, which does not contain and is not linked to any name, email or account. Together with this ID, Google receives the technical information needed to deliver the configuration (app and operating-system version, Firebase library version, device language/region) and the IP address of the connection. We only use Remote Config to send the same configuration to every device and **do not use it for analytics, advertising or identifying users**. The app does not use Google Analytics, Crashlytics or any crash-reporting or measurement tool. The installation ID is removed when the app is uninstalled.

## 4. Read-aloud and the microphone

- The "Read aloud" activity only turns on the microphone after **a parent agrees and passes the parental gate**. Parents can choose "Not now" and mark answers themselves, or tap "Ask about the microphone again" ("Hỏi lại về micro") in the Parents area.
- When enabled, the child's voice is turned into text by the **operating system's built-in speech recognizer running on the device** (Apple on iPhone/iPad, Google on Android). The app requires **on-device** recognition: if the device has no on-device Vietnamese recognizer, the microphone stays off and parents mark answers themselves — the child's voice is never sent over the network.
- Bé Vui Học **does not record, store or send** audio anywhere; it only uses the recognized text at that moment to praise the child.
- The microphone permission (and speech recognition permission on iOS) is only requested at that point; parents can revoke it at any time in the device Settings.

## 5. Backup, sharing and external links

- **Backup** creates a file on the device; the parent chooses where to save or send it. The app does not upload this file anywhere.
- **Certificates** are images drawn on the device. Sharing a certificate, recommending the app or opening a web page (such as this policy, or photo author pages on Wikimedia Commons) **always requires the parental gate** and uses the device's share sheet or browser.

## 6. What we do not do

- No ads, no in-app purchases, no social login.
- No collection of location, contacts, photos, advertising IDs or device identifiers for tracking.
- No behavioural analytics and no tracking across other apps or websites.
- No selling, renting or sharing of data with third parties. The only party processing data for us is Google (Firebase) as described in sections 2 and 3; speech recognition (section 4) runs on the device, provided by its operating system.

## 7. Children

The app is made for children and is designed around the requirements of COPPA (US), the GDPR (EU) and the App Store and Google Play (Families) policies for children's apps. We do not ask for, and do not knowingly collect, personal information from children. The child's nickname stays on the device; if a parent enables sync it only exists inside the encrypted data block that we cannot read. All grown-up areas (Parents area, microphone, sharing, external links) are behind a parental gate.

## 8. How parents review and delete data

- Review progress: Parents → Child report ("Báo cáo của con").
- Delete a child: Parents → Children → Delete.
- Delete the sync copy: Parents → "Dùng trên nhiều máy" (Use on several devices) → "Xoá bản trên máy chủ" (Delete the server copy).
- Delete everything on the device: uninstall the app (removes learning data and the Firebase installation ID).

## 9. Security

Connections to Firebase use TLS encryption. The sync copy is end-to-end encrypted with a key that only exists on devices that know the family code. The server access rules only allow reading or writing a single slot when its name is known, and do not allow listing slots.

## 10. Changes to this policy

When this policy changes we update this page and the effective date at the top; important changes will also be mentioned in the app's release notes.

## 11. Contact

Bé Vui Học developer — email: [EMAIL LIÊN HỆ]

Web version: https://bevuihoc-app.web.app/privacy/en
