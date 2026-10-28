# Release Guide — Smart Dial

## 1. One-time: create a release signing key

Keep this key and its passwords safe. Losing the key means you can't ship updates that install over existing copies.

```powershell
keytool -genkey -v -keystore D:\keys\smart_dial_release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias smartdial
```

Create `android/key.properties` (it is git-ignored, so never commit it):

```properties
storeFile=D:\\keys\\smart_dial_release.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=smartdial
keyPassword=YOUR_KEY_PASSWORD
```

Without this file, release builds are signed with the debug key. That's fine on your own phone, but not for handing the APK to others.

## 2. Before every release

1. Bump `version:` in `pubspec.yaml`: `MAJOR.MINOR.PATCH+BUILD`, and the build number must always increase.
2. Run the checks:
   ```powershell
   flutter pub get
   flutter analyze
   flutter test
   ```
3. Build:
   ```powershell
   flutter build apk --release
   ```
   Output: `build\app\outputs\flutter-apk\app-release.apk`. Code shrinking (R8) is on; rules are in `android/app/proguard-rules.pro`.
4. Install over the previous version, which keeps your data:
   ```powershell
   adb install -r build\app\outputs\flutter-apk\app-release.apk
   ```

## 3. Release smoke test (real phone; never call emergency numbers)

- [ ] App opens; set as default Phone app
- [ ] Outgoing call on each SIM; end the call
- [ ] Incoming call with the screen locked; answer and decline from the notification
- [ ] Missed call → notification → Call back
- [ ] Mute, speaker, Bluetooth, keypad tones in an IVR menu
- [ ] T9 suggestions; speed dial; favorites shortcut from the launcher
- [ ] Add a note; set a "15 minutes" reminder; it fires; Snooze and Done work
- [ ] Reboot the phone with a pending reminder → it still fires
- [ ] Settings → Malayalam; largest font size; dark theme
- [ ] Settings → Diagnostics shows no unexpected errors
- [ ] Upgrade from the previous APK keeps settings, notes and reminders

## 4. Known limitations (state these in release notes)

- No spam detection or call blocking (by decision).
- No backup: uninstalling or switching phones loses notes and reminders, by design for privacy.
- Bluetooth device names aren't shown, because `BLUETOOTH_CONNECT` isn't requested.
- Call recording isn't supported.
- Some OEMs (Xiaomi, Oppo and others) need "Autostart" or "No battery restrictions" enabled for reminders to fire reliably after a reboot.
