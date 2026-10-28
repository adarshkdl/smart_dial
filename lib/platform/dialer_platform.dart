import 'dart:typed_data';

import '../domain/access_state.dart';
import '../domain/call_log.dart';
import '../domain/call_state.dart';
import '../domain/contact.dart';
import '../domain/reminder.dart';
import '../domain/sim.dart';

class DialerException implements Exception {
  const DialerException(this.code, [this.message]);
  final String code;
  final String? message;

  static const permissionDenied = 'permission_denied';
  static const callFailed = 'call_failed';
  static const invalidNumber = 'invalid_number';

  @override
  String toString() => 'DialerException($code)';
}

enum AppIntentAction { dial, call, openTab }

/// An Android intent routed to Flutter: DIAL/VIEW tel: (pre-fill keypad), a launcher
/// shortcut (place the call), or a notification tap (open a tab).
class AppIntent {
  const AppIntent(this.action, {this.number, this.tab});
  final AppIntentAction action;
  final String? number;
  final String? tab;

  static AppIntent? fromMap(Object? m) {
    if (m is! Map) return null;
    final action = switch (m['action']) {
      'dial' => AppIntentAction.dial,
      'call' => AppIntentAction.call,
      'openTab' => AppIntentAction.openTab,
      _ => null,
    };
    if (action == null) return null;
    return AppIntent(
      action,
      number: m['number'] as String?,
      tab: m['tab'] as String?,
    );
  }
}

/// What a launcher shortcut needs to call a favorite.
class ShortcutContact {
  const ShortcutContact({
    required this.id,
    required this.name,
    required this.number,
    this.photoUri,
  });
  final String id;
  final String name;
  final String number;
  final String? photoUri;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'number': number,
    'photoUri': photoUri,
  };
}

/// Version / device facts for the diagnostics report (no identifiers).
class AppInfo {
  const AppInfo({
    this.versionName = '',
    this.sdkInt = 0,
    this.manufacturer = '',
    this.model = '',
  });
  final String versionName;
  final int sdkInt;
  final String manufacturer;
  final String model;

  String get platform => 'Android API $sdkInt · $manufacturer $model'.trim();

  static AppInfo fromMap(Object? m) => m is Map
      ? AppInfo(
          versionName: (m['versionName'] as String?) ?? '',
          sdkInt: (m['sdkInt'] as num?)?.toInt() ?? 0,
          manufacturer: (m['manufacturer'] as String?) ?? '',
          model: (m['model'] as String?) ?? '',
        )
      : const AppInfo();
}

/// The seam between Flutter and Android Telecom. Widget tests use a fake.
abstract class DialerPlatform {
  /// Full snapshots of live calls; emits the current snapshot on listen.
  Stream<CallSnapshot> get callSnapshots;

  /// Intents delivered while the app is running.
  Stream<AppIntent> get intents;

  Future<AccessState> getAccessState();
  Future<bool> requestDefaultDialer();
  Future<Map<AppPermission, PermissionStatus>> requestPermissions(
    List<AppPermission> permissions,
  );
  Future<void> openAppSettings();

  /// The intent that launched the app (consumed once).
  Future<AppIntent?> getInitialIntent();
  Future<String> getCountryIso();

  /// Throws [DialerException] on failure.
  Future<void> placeCall(String number, {String? accountId});
  Future<PhoneAccounts> getPhoneAccounts();

  Future<List<CallLogEntry>> getCallLog({int limit = 500});
  Future<int> deleteCallLogEntries(List<String> ids);
  Future<List<Contact>> getContacts();
  Future<Uint8List?> loadPhoto(String uri);

  Future<void> answer(String callId);
  Future<void> reject(String callId);
  Future<void> disconnect(String callId);
  Future<void> hold(String callId);
  Future<void> unhold(String callId);
  Future<void> playDtmf(String callId, String digit);
  Future<void> stopDtmf(String callId);
  Future<void> setMuted(bool muted);
  Future<void> setAudioRoute(int route);

  // ---- Phase 2 ----

  /// Calls the voicemail number of [accountId] (or the default SIM).
  Future<void> callVoicemail({String? accountId});
  Future<void> markMissedCallsRead();

  /// Needs [AppPermission.writeContacts].
  Future<void> setStarred(String contactId, bool starred);
  Future<bool> sendMessage(String number);
  Future<bool> openContact(String contactId);
  Future<bool> addContact(String number);

  /// App-owned settings JSON (see AppSettings).
  Future<String?> loadAppData();
  Future<void> saveAppData(String json);
  Future<void> clearAppData();

  /// Android 12+ wallpaper accent as ARGB, or null.
  Future<int?> getDynamicAccent();
  Future<void> playKeyTone(String digit);

  Future<void> setAppShortcuts(List<ShortcutContact> items);
  Future<bool> pinShortcut(ShortcutContact item);

  // ---- Phase 3 ----

  /// Named app-owned blobs (notes, diagnostics), encrypted at rest natively.
  Future<String?> loadBlob(String name);
  Future<void> saveBlob(String name, String json);

  /// Reminders are stored and scheduled natively (work with the app closed).
  Future<List<Reminder>> getReminders();
  Future<void> saveReminder(Reminder reminder);
  Future<void> deleteReminder(String id);
  Future<bool> canScheduleExactAlarms();
  Future<void> openExactAlarmSettings();

  Future<AppInfo> getAppInfo();
}
