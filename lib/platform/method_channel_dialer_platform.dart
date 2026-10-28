import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/access_state.dart';
import '../domain/call_log.dart';
import '../domain/call_state.dart';
import '../domain/contact.dart';
import '../domain/reminder.dart';
import '../domain/sim.dart';
import 'dialer_platform.dart';

class MethodChannelDialerPlatform implements DialerPlatform {
  MethodChannelDialerPlatform() {
    _methods.setMethodCallHandler((call) async {
      if (call.method == 'onIntent') {
        final i = AppIntent.fromMap(call.arguments);
        if (i != null) _intents.add(i);
      }
      return null;
    });
  }

  static const _methods = MethodChannel('smart_dial/telecom');
  static const _events = EventChannel('smart_dial/calls');

  final _intents = StreamController<AppIntent>.broadcast();
  Stream<CallSnapshot>? _snapshots;

  @override
  Stream<CallSnapshot> get callSnapshots => _snapshots ??= _events
      .receiveBroadcastStream()
      .map((e) => e is Map ? CallSnapshot.fromMap(e) : CallSnapshot.empty);

  @override
  Stream<AppIntent> get intents => _intents.stream;

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _methods.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw DialerException(e.code, e.message);
    } on MissingPluginException {
      throw const DialerException('unavailable');
    }
  }

  @override
  Future<AccessState> getAccessState() async => AccessState.fromMap(
    await _invoke<Map<Object?, Object?>>('getAccessState') ?? const {},
  );

  @override
  Future<bool> requestDefaultDialer() async =>
      await _invoke<bool>('requestDefaultDialer') ?? false;

  @override
  Future<Map<AppPermission, PermissionStatus>> requestPermissions(
    List<AppPermission> permissions,
  ) async {
    final raw =
        await _invoke<Map<Object?, Object?>>('requestPermissions', {
          'permissions': [for (final p in permissions) p.key],
        }) ??
        const {};
    final out = <AppPermission, PermissionStatus>{};
    raw.forEach((k, v) {
      final p = AppPermission.fromKey('$k');
      if (p != null) out[p] = PermissionStatus.fromKey(v);
    });
    return out;
  }

  @override
  Future<void> openAppSettings() => _invoke('openAppSettings');

  @override
  Future<AppIntent?> getInitialIntent() async => AppIntent.fromMap(
    await _invoke<Map<Object?, Object?>>('getInitialIntent'),
  );

  @override
  Future<String> getCountryIso() async =>
      await _invoke<String>('getCountryIso') ?? '';

  @override
  Future<void> placeCall(String number, {String? accountId}) =>
      _invoke('placeCall', {'number': number, 'accountId': accountId});

  @override
  Future<PhoneAccounts> getPhoneAccounts() async => PhoneAccounts.fromMap(
    await _invoke<Map<Object?, Object?>>('getPhoneAccounts') ?? const {},
  );

  @override
  Future<List<CallLogEntry>> getCallLog({int limit = 500}) async {
    final raw =
        await _invoke<List<Object?>>('getCallLog', {'limit': limit}) ??
        const [];
    return [
      for (final e in raw)
        if (e is Map) CallLogEntry.fromMap(e),
    ];
  }

  @override
  Future<int> deleteCallLogEntries(List<String> ids) async =>
      await _invoke<int>('deleteCallLogEntries', {'ids': ids}) ?? 0;

  @override
  Future<List<Contact>> getContacts() async {
    final raw = await _invoke<List<Object?>>('getContacts') ?? const [];
    return [
      for (final e in raw)
        if (e is Map) Contact.fromMap(e),
    ];
  }

  @override
  Future<Uint8List?> loadPhoto(String uri) =>
      _invoke<Uint8List>('loadPhoto', {'uri': uri});

  @override
  Future<void> answer(String callId) => _invoke('answer', {'id': callId});
  @override
  Future<void> reject(String callId) => _invoke('reject', {'id': callId});
  @override
  Future<void> disconnect(String callId) =>
      _invoke('disconnect', {'id': callId});
  @override
  Future<void> hold(String callId) => _invoke('hold', {'id': callId});
  @override
  Future<void> unhold(String callId) => _invoke('unhold', {'id': callId});
  @override
  Future<void> playDtmf(String callId, String digit) =>
      _invoke('playDtmf', {'id': callId, 'digit': digit});
  @override
  Future<void> stopDtmf(String callId) => _invoke('stopDtmf', {'id': callId});
  @override
  Future<void> setMuted(bool muted) => _invoke('setMuted', {'muted': muted});
  @override
  Future<void> setAudioRoute(int route) =>
      _invoke('setAudioRoute', {'route': route});

  @override
  Future<void> callVoicemail({String? accountId}) =>
      _invoke('callVoicemail', {'accountId': accountId});
  @override
  Future<void> markMissedCallsRead() => _invoke('markMissedCallsRead');
  @override
  Future<void> setStarred(String contactId, bool starred) =>
      _invoke('setStarred', {'contactId': contactId, 'starred': starred});
  @override
  Future<bool> sendMessage(String number) async =>
      await _invoke<bool>('sendMessage', {'number': number}) ?? false;
  @override
  Future<bool> openContact(String contactId) async =>
      await _invoke<bool>('openContact', {'contactId': contactId}) ?? false;
  @override
  Future<bool> addContact(String number) async =>
      await _invoke<bool>('addContact', {'number': number}) ?? false;
  @override
  Future<String?> loadAppData() => _invoke<String>('loadAppData');
  @override
  Future<void> saveAppData(String json) =>
      _invoke('saveAppData', {'json': json});
  @override
  Future<void> clearAppData() => _invoke('clearAppData');
  @override
  Future<int?> getDynamicAccent() => _invoke<int>('getDynamicAccent');
  @override
  Future<void> playKeyTone(String digit) =>
      _invoke('playKeyTone', {'digit': digit});
  @override
  Future<void> setAppShortcuts(List<ShortcutContact> items) =>
      _invoke('setAppShortcuts', {
        'items': [for (final i in items) i.toMap()],
      });
  @override
  Future<bool> pinShortcut(ShortcutContact item) async =>
      await _invoke<bool>('pinShortcut', {'item': item.toMap()}) ?? false;

  @override
  Future<String?> loadBlob(String name) =>
      _invoke<String>('loadBlob', {'name': name});
  @override
  Future<void> saveBlob(String name, String json) =>
      _invoke('saveBlob', {'name': name, 'json': json});
  @override
  Future<List<Reminder>> getReminders() async {
    final raw = await _invoke<List<Object?>>('getReminders') ?? const [];
    return [for (final r in raw) ?Reminder.fromMap(r)];
  }

  @override
  Future<void> saveReminder(Reminder reminder) =>
      _invoke('saveReminder', {'reminder': reminder.toMap()});
  @override
  Future<void> deleteReminder(String id) =>
      _invoke('deleteReminder', {'id': id});
  @override
  Future<bool> canScheduleExactAlarms() async =>
      await _invoke<bool>('canScheduleExactAlarms') ?? true;
  @override
  Future<void> openExactAlarmSettings() => _invoke('openExactAlarmSettings');
  @override
  Future<AppInfo> getAppInfo() async =>
      AppInfo.fromMap(await _invoke<Map<Object?, Object?>>('getAppInfo'));
}
