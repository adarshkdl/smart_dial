# Smart Dial — Privacy Policy

_Last updated: 20 October 2026 · App version 0.3.0_

Smart Dial is a phone (dialer) app. It is built to work **entirely on your phone**.

## Summary

- Smart Dial **has no internet access**. The release app does not request Android's `INTERNET` permission, so it cannot send anything off your device.
- Your **contacts and call history are read from Android** when you open those screens. Smart Dial does not copy them into its own storage.
- Smart Dial stores **only its own data**: settings, speed-dial entries, remembered SIM choices, notes, call reminders and an error log. This data is **encrypted on the device** with a key held in the Android Keystore.
- Smart Dial data is **excluded from cloud backup and from device-to-device transfer**.
- There are **no ads, analytics, tracking or third-party SDKs**.
- You can delete everything Smart Dial stored from **Settings → Clear Smart Dial data**.

## What the app accesses and why

| Data | Why | Stored by Smart Dial? |
|---|---|---|
| Phone calls (Telecom) | To place, answer and manage calls when Smart Dial is your Phone app | No |
| Call history | To show Recents, call frequency and missed calls | No (read on demand). Deleting an entry deletes it from Android's call log |
| Contacts | To show names, search, favorites and caller names | No (read on demand). Starring a contact updates Android Contacts |
| Phone state / SIM list | To let you choose a SIM on dual-SIM phones | Only your remembered SIM per number (encrypted) |
| Notifications | Incoming, ongoing and missed-call notifications; reminders | No |
| Alarms | To deliver call reminders on time | Reminder time, number, name and note (encrypted) |

Each permission is requested only when you first use the feature that needs it. You can refuse; the related feature then shows an explanation instead.

## Data Smart Dial stores itself

All of it is kept in app-private storage on your phone and encrypted with AES-256-GCM.

- **Settings:** theme, colour, keypad size, language, tones and similar choices.
- **Speed dial:** the numbers and names you assign to keys 2–9.
- **SIM memory:** which SIM to use for numbers where you ticked "Remember".
- **Notes:** text you write about a contact or number.
- **Reminders:** who to call, when, and an optional note.
- **Diagnostics:** up to 100 recent error messages, with phone numbers, e-mail addresses and content links removed before saving. They are never sent anywhere. You can view, copy or clear them in Settings → Diagnostics.

Uninstalling Smart Dial, or using **Clear Smart Dial data**, permanently deletes all of the above. Your contacts and call history in Android are not affected.

## Sharing

Smart Dial does not share data with anyone. Some actions hand off to other apps on your phone only when you tap them:

- **Message** opens your SMS app with the number filled in.
- **Open in Contacts** and **Add to contacts** open the system Contacts app.
- **Add to home screen** asks your launcher to create a shortcut showing the contact's name.

## Children

Smart Dial is a general-purpose phone app and is not directed at children.

## Changes and contact

If this policy changes, the date at the top will change with it. For questions, contact the app owner: _[add contact e-mail before distribution]_.
