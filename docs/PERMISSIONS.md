# Permissions & Store-Policy Review — Smart Dial 0.3.0

Distribution today: **private APK** (decision in PLAN.md §1). The Google Play notes below matter only if that changes.

## Manifest permissions (release build)

| Permission | Type | Used for | Requested when | If denied |
|---|---|---|---|---|
| `CALL_PHONE` | runtime | Placing calls via `TelecomManager.placeCall` | First Call press | Explained; no call placed |
| `READ_PHONE_STATE` | runtime | Listing SIMs (phone accounts) | With the first call | Default SIM is used |
| `READ_CALL_LOG` | runtime | Recents, frequency, missed calls | Opening Recents | Recents shows an "access off" screen |
| `WRITE_CALL_LOG` | runtime | Deleting entries; marking missed calls seen | Delete / opening Recents | Delete unavailable |
| `READ_CONTACTS` | runtime | Names, search, T9, favorites | Opening Contacts / Favorites, or the keypad suggestions button | Numbers only |
| `WRITE_CONTACTS` | runtime | Star / unstar favorites | Tapping the star | Explained; no change |
| `POST_NOTIFICATIONS` (13+) | runtime | Call, missed-call and reminder notifications | After becoming the default Phone app, or when setting a reminder | In-app only; the user is told reminders can't alert |
| `USE_FULL_SCREEN_INTENT` | special (granted to dialer-role apps) | Incoming-call UI on the lock screen | Manifest | Heads-up notification |
| `SCHEDULE_EXACT_ALARM` (12+) | special, user-granted on 13+ | On-time reminders | User taps "Allow" on the Reminders banner | Reminders fire within a 10-minute window |
| `RECEIVE_BOOT_COMPLETED` | normal | Re-arming reminders after reboot | Manifest | — |
| `WAKE_LOCK` | normal | Screen off near the ear during calls | Manifest | — |
| `VIBRATE` | normal | Keypad haptics | Manifest | — |

**Not requested:** `INTERNET`, SMS, location, microphone, camera, `BLUETOOTH_CONNECT` (so a Bluetooth device's name isn't shown; routing still works), `QUERY_ALL_PACKAGES`.

## Roles

- `android.app.role.DIALER` is requested from the banner or Settings, and only when the user taps. Declining keeps a working basic dialer (calls go through the system UI). Revocation is detected each time the app returns to the foreground.

## Google Play policy checklist (only if publishing)

- [ ] **Call Log / SMS permissions policy:** Play allows `READ_CALL_LOG` / `WRITE_CALL_LOG` only for apps that are, or can be, the default Phone handler. Smart Dial qualifies. You must file the **Permissions Declaration Form** and show the default-handler prompt before using these permissions.
- [ ] **Default handler:** the app must make its core function work only once it holds the dialer role, or clearly offer it. The current banner and Settings entry satisfy this; record a demo video for review.
- [ ] **Full-screen intent (Android 14+):** allowed for calling apps; state the use in the Play Console declaration.
- [ ] **Exact alarms:** `SCHEDULE_EXACT_ALARM` is user-granted. Do **not** switch to `USE_EXACT_ALARM`, which is restricted to alarm and calendar apps.
- [ ] **Data safety form:** "No data collected / no data shared". All data stays on the device and is encrypted; users can request deletion with "Clear Smart Dial data".
- [ ] **Privacy policy URL:** host `docs/PRIVACY.md` publicly and fill in the contact e-mail.
- [ ] **Package name:** change `com.example.smart_dial`; Play rejects `com.example`.
- [ ] **Target SDK:** must meet Play's current minimum at upload time (Flutter's default target is used).
- [ ] **Emergency calls:** never blocked or modified; Telecom routes them. Note this in testing instructions. Never test with real emergency numbers.

## Data handling summary

- No network: the release manifest has no `INTERNET` permission.
- App-owned data is encrypted with AES-256-GCM using an Android Keystore key, and excluded from backup and device transfer (`allowBackup=false`, `data_extraction_rules.xml`).
- System data (contacts, call log) is read on demand, cached in memory only, and never written elsewhere.
- Logs: Kotlin logs contain only call ids and state codes; the in-app diagnostics log scrubs numbers, e-mails and URIs.
