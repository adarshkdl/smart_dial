import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_dial/app.dart';
import 'package:smart_dial/domain/access_state.dart';
import 'package:smart_dial/domain/call_log.dart';
import 'package:smart_dial/domain/call_state.dart';
import 'package:smart_dial/domain/contact.dart';
import 'package:smart_dial/domain/reminder.dart';
import 'package:smart_dial/domain/sim.dart';
import 'package:smart_dial/platform/dialer_platform.dart';

/// In-memory platform that records every call made to it.
class FakeDialerPlatform implements DialerPlatform {
  FakeDialerPlatform({
    AccessState? access,
    this.countryIso = 'IN',
    this.callLog = const [],
    this.contacts = const [],
    this.accounts = PhoneAccounts.none,
    this.grantOnRequest = true,
    this.grantRoleOnRequest = true,
    this.initialNumber,
    this.initialIntent,
    this.appData,
    this.dynamicAccent,
  }) : access = access ?? allGranted();

  static AccessState allGranted({bool defaultDialer = true}) => AccessState(
    isDefaultDialer: defaultDialer,
    roleAvailable: true,
    loaded: true,
    permissions: {
      for (final p in AppPermission.values) p: PermissionStatus.granted,
    },
  );

  static AccessState noneGranted({bool defaultDialer = false}) => AccessState(
    isDefaultDialer: defaultDialer,
    roleAvailable: true,
    loaded: true,
    permissions: {
      for (final p in AppPermission.values) p: PermissionStatus.denied,
    },
  );

  AccessState access;
  String countryIso;
  List<CallLogEntry> callLog;
  List<Contact> contacts;
  PhoneAccounts accounts;
  bool grantOnRequest;
  bool grantRoleOnRequest;
  String? initialNumber;
  AppIntent? initialIntent;
  String? appData;
  final Map<String, String> blobs = {};
  List<Reminder> reminders = [];
  bool exactAlarms = true;
  int? dynamicAccent;
  List<ShortcutContact> shortcuts = const [];
  final List<ShortcutContact> pinned = [];
  final List<(String?,)> voicemailCalls = [];
  DialerException? placeCallError;
  Object? callLogError;

  final List<String> log = [];
  final List<(String, String?)> placedCalls = [];
  final List<List<AppPermission>> permissionRequests = [];

  final _snapshots = StreamController<CallSnapshot>.broadcast();
  final _intents = StreamController<AppIntent>.broadcast();

  void emitCalls(CallSnapshot s) => _snapshots.add(s);
  void emitDialIntent(String n) =>
      _intents.add(AppIntent(AppIntentAction.dial, number: n));
  void emitIntent(AppIntent i) => _intents.add(i);

  @override
  Stream<CallSnapshot> get callSnapshots => _snapshots.stream;
  @override
  Stream<AppIntent> get intents => _intents.stream;

  @override
  Future<AccessState> getAccessState() async => access;

  @override
  Future<bool> requestDefaultDialer() async {
    log.add('requestDefaultDialer');
    if (grantRoleOnRequest) {
      access = access.withDefaultDialer(true);
    }
    return access.isDefaultDialer;
  }

  @override
  Future<Map<AppPermission, PermissionStatus>> requestPermissions(
    List<AppPermission> permissions,
  ) async {
    permissionRequests.add(permissions);
    final result = {
      for (final p in permissions)
        p: grantOnRequest
            ? PermissionStatus.granted
            : PermissionStatus.permanentlyDenied,
    };
    access = access.withResults(result);
    return result;
  }

  @override
  Future<void> openAppSettings() async => log.add('openAppSettings');
  @override
  Future<AppIntent?> getInitialIntent() async =>
      initialIntent ??
      (initialNumber == null
          ? null
          : AppIntent(AppIntentAction.dial, number: initialNumber));
  @override
  Future<String> getCountryIso() async => countryIso;

  @override
  Future<void> placeCall(String number, {String? accountId}) async {
    if (placeCallError != null) throw placeCallError!;
    placedCalls.add((number, accountId));
  }

  @override
  Future<PhoneAccounts> getPhoneAccounts() async => accounts;

  @override
  Future<List<CallLogEntry>> getCallLog({int limit = 500}) async {
    if (callLogError != null) throw callLogError!;
    return callLog;
  }

  @override
  Future<int> deleteCallLogEntries(List<String> ids) async {
    log.add('delete:${ids.join(',')}');
    callLog = [
      for (final e in callLog)
        if (!ids.contains(e.id)) e,
    ];
    return ids.length;
  }

  @override
  Future<List<Contact>> getContacts() async => contacts;
  @override
  Future<Uint8List?> loadPhoto(String uri) async => null;

  @override
  Future<void> answer(String callId) async => log.add('answer:$callId');
  @override
  Future<void> reject(String callId) async => log.add('reject:$callId');
  @override
  Future<void> disconnect(String callId) async => log.add('disconnect:$callId');
  @override
  Future<void> hold(String callId) async => log.add('hold:$callId');
  @override
  Future<void> unhold(String callId) async => log.add('unhold:$callId');
  @override
  Future<void> playDtmf(String callId, String digit) async =>
      log.add('dtmf:$callId:$digit');
  @override
  Future<void> stopDtmf(String callId) async => log.add('dtmfStop:$callId');
  @override
  Future<void> setMuted(bool muted) async => log.add('mute:$muted');
  @override
  Future<void> setAudioRoute(int route) async => log.add('route:$route');

  @override
  Future<void> callVoicemail({String? accountId}) async =>
      voicemailCalls.add((accountId,));
  @override
  Future<void> markMissedCallsRead() async => log.add('markMissedRead');
  @override
  Future<void> setStarred(String contactId, bool starred) async {
    log.add('star:$contactId:$starred');
    contacts = [
      for (final c in contacts)
        c.id == contactId ? c.copyWith(starred: starred) : c,
    ];
  }

  @override
  Future<bool> sendMessage(String number) async {
    log.add('sms:$number');
    return true;
  }

  @override
  Future<bool> openContact(String contactId) async {
    log.add('open:$contactId');
    return true;
  }

  @override
  Future<bool> addContact(String number) async {
    log.add('add:$number');
    return true;
  }

  @override
  Future<String?> loadAppData() async => appData;
  @override
  Future<void> saveAppData(String json) async => appData = json;
  @override
  Future<void> clearAppData() async {
    log.add('clearAppData');
    appData = null;
    blobs.clear();
    reminders = [];
  }

  @override
  Future<int?> getDynamicAccent() async => dynamicAccent;
  @override
  Future<void> playKeyTone(String digit) async => log.add('tone:$digit');
  @override
  Future<void> setAppShortcuts(List<ShortcutContact> items) async =>
      shortcuts = items;
  @override
  Future<bool> pinShortcut(ShortcutContact item) async {
    pinned.add(item);
    return true;
  }

  @override
  Future<String?> loadBlob(String name) async => blobs[name];
  @override
  Future<void> saveBlob(String name, String json) async => blobs[name] = json;
  @override
  Future<List<Reminder>> getReminders() async => List.of(reminders);
  @override
  Future<void> saveReminder(Reminder reminder) async {
    log.add('saveReminder:${reminder.id}:${reminder.done}');
    reminders = [
      for (final r in reminders)
        if (r.id != reminder.id) r,
      reminder,
    ];
  }

  @override
  Future<void> deleteReminder(String id) async {
    log.add('deleteReminder:$id');
    reminders = [
      for (final r in reminders)
        if (r.id != id) r,
    ];
  }

  @override
  Future<bool> canScheduleExactAlarms() async => exactAlarms;
  @override
  Future<void> openExactAlarmSettings() async => log.add('exactAlarmSettings');
  @override
  Future<AppInfo> getAppInfo() async => const AppInfo(
    versionName: '0.3.0',
    sdkInt: 34,
    manufacturer: 'Test',
    model: 'Phone',
  );
}

/// Pumps the full app on a phone-sized surface.
Future<void> pumpApp(
  WidgetTester tester,
  FakeDialerPlatform platform, {
  Locale? locale = const Locale('en'),
  double textScale = 1.0,
  Size size = const Size(400, 860),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(SmartDialApp(platform: platform, locale: locale));
  await tester.pumpAndSettle();
}

/// Background → foreground using the state sequence the framework allows.
Future<void> backgroundAndResume(WidgetTester tester) async {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pumpAndSettle();
}
