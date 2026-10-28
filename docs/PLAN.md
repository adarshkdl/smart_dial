# smart_dial — Execution Plan (Phase 0 → Phase 1 MVP)

Source spec: `android_dialer_feature_specification.md` (repo root).
Status date: 2026-10-20.

---

## 1. Decisions (spec §10)

| Decision | Choice | Notes |
|---|---|---|
| Product type | **Smart dialer, phased** | Full default-Phone-role replacement first (Phase 1), smart features in Phase 2 |
| Framework | **Flutter UI + native Kotlin** | Telecom, `InCallService`, `RoleManager`, providers live in Kotlin; Flutter talks over one MethodChannel + one EventChannel |
| Distribution | **Private APK** | Avoids Play's default-handler / call-log declaration review for now; revisit before any Play release |
| Min / target SDK | **minSdk 29 (Android 10)** / target = Flutter default (35/36) | API 29 gives `RoleManager.ROLE_DIALER`; no legacy `ACTION_CHANGE_DEFAULT_DIALER` path needed |
| T9 search | Required — **Phase 2** | Phase 1 ships plain name/number/company search |
| Spam detection | **Not planned** (Phase 3 review) | Unknown numbers are clearly labelled only |
| Dual SIM | **Required, basic** | Picker when >1 call-capable account and no system default |
| Privacy model | **Offline-first** | No network permission use, no analytics SDKs, nothing leaves the device |
| Localization | **English + Malayalam** | `gen-l10n`, ARB files in `lib/l10n/` |
| Call recording | **Excluded** | Not implemented; separate legal/feasibility review required |
| Package / appId | `com.example.smart_dial` (Kotlin namespace) | Rename before any public release |

## 2. Architecture (spec §6)

```
lib/
  domain/        pure Dart, no Flutter imports → 100% unit-testable
    phone_number.dart      normalize, validate, country-aware display format, emergency detection (info only)
    call_log.dart          CallLogEntry model, grouping, filtering
    contact.dart           Contact model, initials, search
    call_state.dart        ActiveCall / AudioState models parsed from native snapshots
    access_state.dart      role + permission state → capability decisions
  platform/
    dialer_platform.dart   abstract interface (the seam for tests)
    method_channel_dialer_platform.dart   real implementation
  state/app_controller.dart  ChangeNotifier: access, calls snapshot, accounts
  ui/                    keypad, recents, contacts, in-call, onboarding, shared state views
  l10n/                  app_en.arb, app_ml.arb (+ generated)

android/app/src/main/kotlin/com/example/smart_dial/
  MainActivity.kt        channels, role request, runtime permissions, DIAL intents, lock-screen flags
  DialerInCallService.kt system-bound InCallService (UI provider when default dialer)
  CallManager.kt         single source of truth for live calls + audio; emits full snapshots
  CallNotifications.kt   incoming full-screen-intent + ongoing-call notification
  CallActionReceiver.kt  notification Answer / Decline / Hang up
  TelecomBridge.kt       placeCall, phone accounts, call-log & contacts queries (background thread)
```

Rules:
- **System data stays system-owned.** Contacts and call log are read on demand from providers; nothing is copied to app storage.
- **Full snapshots, not deltas.** Native emits the whole call list + audio state on every change, so Flutter can never hold stale or double-applied state; on re-subscribe (process/engine recreation) the current snapshot is replayed.
- **Emergency calls are never intercepted.** Numbers go straight to `TelecomManager.placeCall`; Telecom owns emergency routing. Dart only *detects* emergency numbers so it never blocks them with validation.
- **No phone numbers in logs.** Kotlin logs only call ids / state codes.

## 3. Permissions (spec §3.11, §4) — requested just-in-time

| Permission | Requested when | Feature | If denied |
|---|---|---|---|
| `ROLE_DIALER` (role) | Onboarding banner tap | In-call UI, call control | App works as basic dialer; system in-call UI is used |
| `CALL_PHONE` | First Call press | Outgoing calls | Snackbar + falls back to `ACTION_DIAL` handoff |
| `READ_CALL_LOG` | Recents tab opened | Recents | Permission-denied state with Grant / Settings |
| `WRITE_CALL_LOG` | Delete entry | Delete history | Delete hidden |
| `READ_CONTACTS` | Contacts tab opened | Contacts, caller name | Permission-denied state; in-call shows number only |
| `READ_PHONE_STATE` | Call with >1 SIM | SIM list / picker | Telecom default account is used |
| `POST_NOTIFICATIONS` (33+) | After role granted | Incoming / missed / ongoing notifications | In-app UI only |
| `USE_FULL_SCREEN_INTENT` | Manifest (auto for dialer role) | Lock-screen incoming UI | Heads-up notification |

Not requested: SMS, internet-based features, microphone (Telecom owns audio), location.

## 4. Device / API compatibility matrix (spec Phase 0)

| Android | API | Key differences to verify |
|---|---|---|
| 10 | 29 | `RoleManager` dialer role; background-activity-start limits begin |
| 11 | 30 | `Call.Details.contactDisplayName`; package visibility |
| 12 | 31 | `Call.Details.state` replaces `Call.getState()`; exact PendingIntent mutability flags |
| 13 | 33 | `POST_NOTIFICATIONS` runtime permission |
| 14 | 34 | `USE_FULL_SCREEN_INTENT` restricted to calling/alarm apps |
| 15–16 | 35–36 | Edge-to-edge enforced; predictive back |

OEMs to cover on real devices: Samsung (One UI dual-SIM), Xiaomi/Redmi (MIUI/HyperOS autostart & lock-screen permissions), Realme/Oppo (ColorOS), Pixel (reference), Motorola. Connected test device in this session: `10MFC3FHYZ000JQ`.

## 5. Risk register

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | Incoming call UI not shown on lock screen (OEM restrictions) | Med | High | Full-screen-intent notification + `setShowWhenLocked`; manual OEM checklist |
| R2 | Flutter engine cold start delays incoming UI | Med | High | Notification with Answer/Decline actions works without Flutter; Telecom plays ringtone (no `IN_CALL_SERVICE_RINGING`) |
| R3 | Process death mid-call | Low | High | `CallManager` lives in service process; snapshot replay on re-listen |
| R4 | User declines / revokes dialer role | High | Med | Basic-dialer fallback; access re-checked on every resume |
| R5 | Dual-SIM APIs differ by OEM | Med | Med | Use only `TelecomManager` phone accounts; respect system default |
| R6 | Emergency call regressions | Low | Critical | No validation/blocking on emergency numbers; never placed during testing |
| R7 | Large contact / call-log sets jank UI | Med | Med | Provider queries on background executor; call log limited to 500; `ListView.builder` |
| R8 | Bluetooth route changes mid-call | Med | Med | Audio state driven by `onCallAudioStateChanged` only |
| R9 | Play policy (if later published) | — | High | Private APK now; declaration form review before Play |

## 6. Acceptance criteria — Phase 1 features (spec §9 template, condensed)

**F1 Dial pad & outgoing call**
- Expected: 0–9 * # entry, backspace (long-press clears), long-press 0 → `+`, copy/paste via long-press on number, live formatting, Call places call via Telecom on chosen SIM.
- Failure: empty/invalid input → inline error, no call; `CALL_PHONE` denied → message; placeCall exception → error snackbar.
- Privacy: number never logged or stored by the app.
- Tests: unit (normalize/validate/format), widget (entry, delete, +, call invocation, invalid input, SIM picker).

**F2 Default Phone role**
- Expected: banner explains role; tap → system role dialog; granted → banner gone, notifications permission asked.
- Failure: declined → banner stays, app usable as basic dialer; revoked → detected on resume.
- Tests: unit (access state), widget (banner visibility & request call).

**F3 Incoming / ongoing / outgoing call UI**
- Expected: ringing → Answer / Decline; dialing/active → name, number, state, timer, Mute, Speaker, Keypad (DTMF), Hold (if capable), End; Bluetooth route button when available; second call → swap/hold controls.
- Failure: missing contacts permission → number only, "Unknown" label.
- Tests: widget (each state's controls, actions reach platform, DTMF), unit (snapshot parsing, durations).

**F4 Contacts & search** — list sorted by name, initials/photo avatars, multiple numbers, search by name/number/company, tap → detail sheet → call.
Failure: permission denied / empty address book states. Tests: unit (search), widget (filter, empty, denied).

**F5 Call history** — newest first, type icons (in/out/missed/rejected/blocked), date/time/duration/SIM, consecutive same-number grouping with count, one-tap callback, filter (All / Missed), search, delete entry.
Failure: permission denied state. Tests: unit (grouping, filtering), widget (render, callback, denied).

**F6 Accessibility basics** — semantic labels on all icon buttons and keypad keys ("2, A B C"), ≥48 dp targets, layouts survive 2.0× text scale. Tests: widget test at 2.0× text scale (no overflow).

**F7 Localization** — every user-facing string in ARB; `ml` locale renders. Tests: widget test pumps app in Malayalam.

## 7. Execution plan

| Step | Work | Automated verification |
|---|---|---|
| 1 | Scaffold, minSdk 29, l10n setup | `flutter pub get`, analyzer |
| 2 | Kotlin layer (manifest, service, bridge) | Gradle debug build on device |
| 3 | Domain layer | Unit tests |
| 4 | Platform interface + fake | Used by widget tests |
| 5 | UI screens | Widget tests incl. text-scale & Malayalam |
| 6 | Wire-up & launch on device | `launch_app`, runtime-error check |
| 7 | Manual real-device checklist (below) | Human — cannot be automated safely |

## 8. Manual real-device checklist (cannot be automated safely)

Use a second phone / test number. **Never call emergency services.**
- [ ] Set as default Phone app from banner; decline once and confirm fallback works
- [ ] Outgoing call on SIM 1 and SIM 2; end call from app and from far end
- [ ] Incoming call: screen on (heads-up), screen off / locked (full screen), answer + decline from notification
- [ ] Mute, speaker, Bluetooth headset route, DTMF into an IVR
- [ ] Hold / resume; second incoming call while active (call waiting) and swap
- [ ] Revoke contacts & call-log permissions in Settings → app shows denied states, no crash
- [ ] Remove default role in Settings → banner returns on resume
- [ ] Kill app during call (recents swipe) → reopen → call UI restored
- [ ] Switch device language to Malayalam; font size to largest

## 9. Out of scope for this iteration (tracked for Phase 2+)
T9 matching & ranking, favorites/speed dial, missed-call notification, advanced filters, home-screen shortcuts/widget, custom accent colors, libphonenumber-grade formatting, contact editing, blocking, caller ID/spam, reminders/notes, backup.

---

## 10. Status — 2026-10-20

**Built (Phase 1 MVP code complete):** F1 keypad & outgoing call, F2 default-role flow, F3 in-call UI (answer/decline, mute, speaker, Bluetooth, hold, swap, DTMF, timer, lock-screen + full-screen notification), F4 contacts & search, F5 recents (grouping, filter, search, callback, delete), F6 accessibility basics, F7 English + Malayalam.

**Automated verification**
| Check | Result |
|---|---|
| `flutter analyze` | No errors, no warnings |
| Unit tests (`test/domain`, 68) | All pass — formatting, validation, emergency pass-through, call-log grouping, filters, search ranking (20k contacts < 500 ms), call snapshots, role/permission state, SIM choice |
| Widget tests (`test/ui`, 49) | All pass — keypad, SIM picker, permission just-in-time/denied/permanently-denied/revoked, recents, contacts, in-call states, call waiting, role grant/decline/revoke, DIAL intents, Malayalam, dark theme, 2× font scale, Android tap-target & label guidelines |
| **Total** | **117 / 117 passing** |

Bugs found & fixed by the tests: keypad overflow at 2× font on 360×640 (role banner now height-capped); Recents/Contacts re-prompted after a revoke instead of showing the denied state.

**Not yet verified automatically:** Android Gradle build / Kotlin compile and on-device run (launch tooling unavailable in this session). Run:
```
flutter run -d 10MFC3FHYZ000JQ
```
then work through the §8 manual checklist.

## 11. Next (Phase 2)
T9 matching + ranking (reuse `searchContacts` seam), favorites & speed dial, missed-call notification, libphonenumber-grade formatting, home-screen shortcuts, accent colours, `integration_test` suite on device.

---

## 12. Phase 2 status — 2026-10-20

**Built:** T9 smart search on the keypad (ranked: name prefix → later word → initials → number prefix → contains; boosted by call frequency; highlight; +91/0 tolerant), Favorites tab (starred grid + Frequent from call log, long-press call/message/details/unstar), star/unstar (WRITE_CONTACTS on demand), speed dial 2–9 + voicemail on 1, Settings (theme, accent incl. Android 12+ wallpaper colour, keypad size, tones, haptics, T9 toggle, speed dial, SIM memory, shortcuts, clear app data), per-contact SIM memory, Recents filters (incoming/outgoing/declined + per-SIM), message / add-contact from Recents, missed-call notification (Call back / Message, marked read on viewing Recents), launcher + home-screen shortcuts, app-owned storage (SharedPreferences, backup off).

**Automated verification:** 172 / 172 tests passing (unit + widget) — includes T9 ranking & 20k-contact performance, settings JSON robustness, SIM memory, speed dial flows, favorites, settings persistence, intents, 2× font, Malayalam. Analyzer: no code issues (its only reports are a stale cache of the generated l10n file, which compiles).

Bug caught by tests and fixed: keypad number display overflowed at 2× font on 360×640 after adding suggestions.

**Manual on-device checks still needed:** missed-call notification + actions, launcher/pinned shortcuts, wallpaper accent, keypad tones respecting silent mode, star/unstar writing to Contacts, Kotlin build (`flutter run`).

**Deferred:** home-screen favorites widget (optional in spec).

**2026-10-20 (later):** User confirmed the app builds and runs on device — Kotlin/Gradle build verified.

---

## 13. Phase 3 status — 2026-10-20

**Decisions:** spam protection / blocking **skipped**; backup **not offered** (privacy: data stays on the phone).

**Built:**
- Call reminders: quick options (15 min / 1 h / this evening / tomorrow 9 am) or a custom date & time, from Recents, contact details and the Reminders screen (app-bar badge). Stored and scheduled natively (AlarmManager, exact when allowed, otherwise a 10-min window), re-armed after reboot / app update, with Call / Snooze 10 min / Done notification actions. Calling a reminder completes it.
- Notes on numbers/contacts: add, edit, delete in contact details and Recents details; Recents shows a note icon.
- App-owned data encrypted at rest (AES-256-GCM, Android Keystore); legacy plaintext re-encrypted on next save; excluded from cloud backup and device transfer.
- Diagnostics: on-device log (100 entries) of platform failures and uncaught errors, with phone numbers, e-mails and URIs scrubbed; view / copy / clear in Settings.
- Language setting (System / English / Malayalam).
- Release hardening: R8 minify + resource shrinking, release signing via `android/key.properties`, version 0.3.0+3, no INTERNET permission in the release build. Docs: `PRIVACY.md`, `PERMISSIONS.md`, `RELEASE.md`.

**Automated verification:** 200 / 200 tests passing; analyzer clean.

**Manual on-device checks needed:** `flutter build apk --release` (first R8 build), reminder firing / snooze / done, reminder after reboot, exact-alarm prompt, encrypted settings surviving an app upgrade from 0.2.
