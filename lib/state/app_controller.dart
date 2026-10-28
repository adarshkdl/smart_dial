import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/access_state.dart';
import '../domain/app_settings.dart';
import '../domain/call_log.dart';
import '../domain/call_state.dart';
import '../domain/contact.dart';
import '../domain/diagnostics.dart';
import '../domain/frequency.dart';
import '../domain/notes.dart';
import '../domain/phone_number.dart';
import '../domain/reminder.dart';
import '../domain/sim.dart';
import '../domain/t9.dart';
import '../platform/dialer_platform.dart';

enum PlaceCallOutcome {
  placed,
  invalidNumber,
  permissionDenied,
  cancelled,
  failed,
}

/// Result of the SIM picker.
class SimChoice {
  const SimChoice(this.account, {this.remember = false});
  final PhoneAccount account;
  final bool remember;
}

typedef SimChooser = Future<SimChoice?> Function(List<PhoneAccount> accounts);

/// App-wide state: access/role, live calls, settings, and shared caches of
/// contacts / call log (read from system providers on demand, never persisted).
class AppController extends ChangeNotifier {
  AppController(this.platform);

  final DialerPlatform platform;

  AccessState access = AccessState.unknown;
  CallSnapshot calls = CallSnapshot.empty;
  String countryIso = '';
  AppSettings settings = AppSettings.defaults;
  int? dynamicAccent;

  /// Number pushed into the keypad by a DIAL intent; the keypad consumes it.
  final ValueNotifier<String?> pendingDialNumber = ValueNotifier(null);

  /// Number to call from a launcher shortcut; the home shell consumes it (needs UI for SIM choice).
  final ValueNotifier<String?> pendingCallNumber = ValueNotifier(null);

  /// Tab to show (e.g. "recents" from a missed-call notification).
  final ValueNotifier<String?> pendingTab = ValueNotifier(null);

  List<Contact>? _contacts;
  List<CallLogEntry>? _callLog;
  T9Index? _t9;
  Map<String, double> _frequency = const {};

  NotesBook notes = NotesBook.empty;
  List<Reminder> reminders = const [];
  bool exactAlarms = true;
  DiagnosticsLog diagnostics = DiagnosticsLog.empty;
  AppInfo appInfo = const AppInfo();

  List<Contact>? get contacts => _contacts;
  List<CallLogEntry>? get callLog => _callLog;
  Map<String, double> get frequency => _frequency;

  final List<StreamSubscription<Object?>> _subs = [];
  bool _disposed = false;

  Future<void> init() async {
    _subs.add(
      platform.callSnapshots.listen((s) {
        calls = s;
        _notify();
      }),
    );
    _subs.add(platform.intents.listen(_handleIntent));
    DiagnosticsSink.handler = recordDiagnostic;
    try {
      notes = NotesBook.decode(await platform.loadBlob(_notesBlob));
      diagnostics = DiagnosticsLog.decode(await platform.loadBlob(_diagBlob));
      appInfo = await platform.getAppInfo();
    } on DialerException catch (e) {
      recordDiagnostic('init', e.code);
    }
    await refreshReminders();
    try {
      settings = AppSettings.decode(await platform.loadAppData());
      dynamicAccent = await platform.getDynamicAccent();
    } on DialerException {
      // Defaults are fine.
    }
    try {
      countryIso = await platform.getCountryIso();
      final initial = await platform.getInitialIntent();
      if (initial != null) _handleIntent(initial);
    } on DialerException {
      // Non-fatal: formatting falls back to generic rules.
    }
    await refreshAccess();
  }

  void _handleIntent(AppIntent i) {
    switch (i.action) {
      case AppIntentAction.dial:
        if (i.number != null) pendingDialNumber.value = i.number;
      case AppIntentAction.call:
        if (i.number != null) pendingCallNumber.value = i.number;
      case AppIntentAction.openTab:
        pendingTab.value = i.tab;
    }
  }

  Future<void> refreshAccess() async {
    try {
      access = access.refreshedWith(await platform.getAccessState());
    } on DialerException {
      access = access.refreshedWith(const AccessState(loaded: true));
    }
    _notify();
  }

  /// Back in the foreground: role/permissions and provider data may have changed.
  Future<void> onResume() async {
    await refreshAccess();
    // Reminders may have been snoozed / completed from their notification.
    await refreshReminders();
    if (_contacts != null && access.granted(AppPermission.readContacts)) {
      try {
        await loadContacts(force: true);
      } on DialerException {
        // Keep the old cache.
      }
    }
    if (_callLog != null && access.granted(AppPermission.readCallLog)) {
      try {
        await loadCallLog(force: true);
      } on DialerException {
        // Keep the old cache.
      }
    }
  }

  /// Requests [p] only if it isn't granted yet. Never prompts for a permanently denied one.
  Future<PermissionStatus> ensurePermission(AppPermission p) async {
    if (access.granted(p)) return PermissionStatus.granted;
    if (access.status(p) == PermissionStatus.permanentlyDenied) {
      return PermissionStatus.permanentlyDenied;
    }
    final res = await platform.requestPermissions([p]);
    access = access.withResults(res);
    _notify();
    return access.status(p);
  }

  Future<bool> requestDefaultRole() async {
    final held = await platform.requestDefaultDialer();
    access = access.withDefaultDialer(held);
    _notify();
    if (held) {
      // Call notifications only make sense once we provide the in-call UI.
      await ensurePermission(AppPermission.postNotifications);
      await refreshAccess();
    }
    return held;
  }

  Future<void> openAppSettings() => platform.openAppSettings();

  // ---- settings (app-owned data) -----------------------------------------

  Future<void> updateSettings(AppSettings next) async {
    final shortcutsChanged =
        next.favoriteShortcuts != settings.favoriteShortcuts;
    settings = next;
    _notify();
    try {
      await platform.saveAppData(next.encode());
    } on DialerException {
      // Stays in memory for this session.
    }
    if (shortcutsChanged) await syncShortcuts();
  }

  /// Removes everything Smart Dial stored itself. System contacts / call log are untouched.
  Future<void> clearAppData() async {
    try {
      await platform.clearAppData();
    } on DialerException {
      // Ignore; in-memory reset below still applies.
    }
    settings = AppSettings.defaults;
    notes = NotesBook.empty;
    reminders = const [];
    diagnostics = DiagnosticsLog.empty;
    _notify();
  }

  // ---- notes (encrypted app-owned data) ----------------------------------

  static const _notesBlob = 'notes';
  static const _diagBlob = 'diagnostics';

  Future<void> _saveNotes() async {
    try {
      await platform.saveBlob(_notesBlob, notes.encode());
    } on DialerException catch (e) {
      recordDiagnostic('notes', e.code);
    }
  }

  Future<void> addNote(String number, String text) async {
    final now = DateTime.now();
    notes = notes.upsert(
      CallNote(
        id: newLocalId(now),
        number: number,
        text: text,
        createdAt: now,
        updatedAt: now,
      ),
    );
    _notify();
    await _saveNotes();
  }

  Future<void> editNote(CallNote note, String text) async {
    notes = notes.upsert(note.copyWith(text: text, updatedAt: DateTime.now()));
    _notify();
    await _saveNotes();
  }

  Future<void> deleteNote(CallNote note) async {
    notes = notes.remove(note.id);
    _notify();
    await _saveNotes();
  }

  // ---- reminders (stored & scheduled natively) ----------------------------

  int get pendingReminderCount => reminders.where((r) => !r.done).length;

  Future<void> refreshReminders() async {
    try {
      reminders = sortReminders(await platform.getReminders());
      exactAlarms = await platform.canScheduleExactAlarms();
    } on DialerException catch (e) {
      recordDiagnostic('reminders', e.code);
    }
    _notify();
  }

  /// Returns false when notifications are blocked (the reminder is still saved,
  /// but it can't alert the user).
  Future<bool> addReminder({
    required String number,
    String? name,
    required DateTime dueAt,
    String? note,
  }) async {
    final notify = await ensurePermission(AppPermission.postNotifications);
    final r = Reminder(
      id: newLocalId(DateTime.now()),
      number: number,
      name: name,
      dueAt: dueAt,
      note: note,
    );
    try {
      await platform.saveReminder(r);
    } on DialerException catch (e) {
      recordDiagnostic('reminders', e.code);
    }
    await refreshReminders();
    return notify == PermissionStatus.granted;
  }

  Future<void> setReminderDone(Reminder r, bool done) async {
    await _safe(() => platform.saveReminder(r.copyWith(done: done)));
    await refreshReminders();
  }

  Future<void> deleteReminder(Reminder r) async {
    await _safe(() => platform.deleteReminder(r.id));
    await refreshReminders();
  }

  Future<void> openExactAlarmSettings() =>
      _safe(platform.openExactAlarmSettings);

  // ---- diagnostics (scrubbed, on-device only) -----------------------------

  void recordDiagnostic(String kind, String message) {
    if (_disposed) return;
    diagnostics = diagnostics.add(kind, message, DateTime.now());
    unawaited(
      platform
          .saveBlob(_diagBlob, diagnostics.encode())
          .catchError((Object _) {}),
    );
  }

  String diagnosticsReport() => diagnostics.report(
    appVersion: appInfo.versionName,
    platform: appInfo.platform,
  );

  Future<void> clearDiagnostics() async {
    diagnostics = DiagnosticsLog.empty;
    _notify();
    try {
      await platform.saveBlob(_diagBlob, diagnostics.encode());
    } on DialerException {
      // Nothing else to do.
    }
  }

  // ---- contacts & call log caches ----------------------------------------

  Future<List<Contact>> loadContacts({bool force = false}) async {
    final cached = _contacts;
    if (cached != null && !force) return cached;
    final list = await platform.getContacts();
    _setContacts(list);
    unawaited(syncShortcuts());
    return list;
  }

  void _setContacts(List<Contact> list) {
    _contacts = list;
    _t9 = T9Index([
      for (final c in list)
        if (c.phones.isNotEmpty) c,
    ]);
    _recomputeFrequency();
    _notify();
  }

  Future<List<CallLogEntry>> loadCallLog({bool force = false}) async {
    final cached = _callLog;
    if (cached != null && !force) return cached;
    final list = await platform.getCallLog();
    _callLog = list;
    _recomputeFrequency();
    _notify();
    return list;
  }

  void removeCallLogEntries(Set<String> ids) {
    final log = _callLog;
    if (log == null) return;
    _callLog = [
      for (final e in log)
        if (!ids.contains(e.id)) e,
    ];
    _recomputeFrequency();
    _notify();
  }

  void _recomputeFrequency() {
    final c = _contacts, l = _callLog;
    _frequency = (c == null || l == null)
        ? const {}
        : contactScores(c, numberScores(l, now: DateTime.now()));
  }

  Future<void>? _searchLoad;

  /// Loads whatever the keypad suggestions need, without prompting for permissions.
  /// Concurrent callers share one load.
  Future<void> ensureSearchData() =>
      _searchLoad ??= _loadSearchData().whenComplete(() => _searchLoad = null);

  Future<void> _loadSearchData() async {
    try {
      if (_contacts == null && access.granted(AppPermission.readContacts)) {
        await loadContacts();
      }
      if (_callLog == null && access.granted(AppPermission.readCallLog)) {
        await loadCallLog();
      }
    } on DialerException {
      // Suggestions are best-effort.
    }
  }

  List<T9Match> t9Search(String query, {int limit = 20}) {
    final index = _t9;
    if (!settings.t9Suggestions || index == null) return const [];
    return index.search(query, frequency: _frequency, limit: limit);
  }

  List<Contact> get favorites => [
    for (final c in _contacts ?? const <Contact>[])
      if (c.starred && c.phones.isNotEmpty) c,
  ];

  List<Contact> get frequent => frequentContacts([
    for (final c in _contacts ?? const <Contact>[])
      if (c.phones.isNotEmpty) c,
  ], _frequency);

  /// Star / unstar in the system address book. Returns false when not permitted.
  Future<bool> setStarred(Contact c, bool starred) async {
    final s = await ensurePermission(AppPermission.writeContacts);
    if (s != PermissionStatus.granted) return false;
    try {
      await platform.setStarred(c.id, starred);
    } on DialerException {
      return false;
    }
    final list = _contacts;
    if (list != null) {
      _setContacts([
        for (final x in list) x.id == c.id ? x.copyWith(starred: starred) : x,
      ]);
    }
    await syncShortcuts();
    return true;
  }

  // ---- shortcuts & system hand-offs ---------------------------------------

  ShortcutContact _shortcut(Contact c, [ContactPhone? p]) => ShortcutContact(
    id: c.id,
    name: c.name,
    number: (p ?? c.phones.first).number,
    photoUri: c.photoUri,
  );

  Future<void> syncShortcuts() async {
    try {
      await platform.setAppShortcuts(
        settings.favoriteShortcuts
            ? [for (final c in favorites.take(4)) _shortcut(c)]
            : const [],
      );
    } on DialerException {
      // Launcher shortcuts are optional.
    }
  }

  Future<bool> pinShortcut(Contact c, ContactPhone p) async {
    try {
      return await platform.pinShortcut(_shortcut(c, p));
    } on DialerException {
      return false;
    }
  }

  Future<bool> sendMessage(String number) =>
      _bool(() => platform.sendMessage(number));
  Future<bool> openContact(Contact c) =>
      _bool(() => platform.openContact(c.id));
  Future<bool> addContact(String number) =>
      _bool(() => platform.addContact(number));

  Future<bool> _bool(Future<bool> Function() f) async {
    try {
      return await f();
    } on DialerException catch (e) {
      recordDiagnostic('action', e.code);
      return false;
    }
  }

  Future<void> markMissedCallsRead() => _safe(platform.markMissedCallsRead);

  void keyFeedback(String digit) {
    if (settings.keypadTones) {
      unawaited(_safe(() => platform.playKeyTone(digit)));
    }
  }

  // ---- calling -------------------------------------------------------------

  Future<PhoneAccounts> phoneAccounts() async {
    if (!access.canReadSims) return PhoneAccounts.none;
    try {
      return await platform.getPhoneAccounts();
    } on DialerException {
      return PhoneAccounts.none;
    }
  }

  Future<bool> _ensureCallPermission() async {
    if (access.canPlaceCalls) return true;
    // Ask for SIM access in the same prompt so dual-SIM users can choose.
    final res = await platform.requestPermissions([
      AppPermission.callPhone,
      AppPermission.readPhoneState,
    ]);
    access = access.withResults(res);
    _notify();
    return access.canPlaceCalls;
  }

  Future<PlaceCallOutcome> placeCall(
    String rawNumber, {
    SimChooser? chooseSim,
  }) async {
    if (PhoneNumbers.validate(rawNumber, countryIso: countryIso) !=
        NumberValidation.ok) {
      return PlaceCallOutcome.invalidNumber;
    }
    final number = PhoneNumbers.normalize(rawNumber);
    if (!await _ensureCallPermission()) {
      return PlaceCallOutcome.permissionDenied;
    }

    String? accountId;
    final accounts = await phoneAccounts();
    final remembered = accounts.accounts.length > 1
        ? accounts.byId(settings.simFor(number))
        : null;
    if (remembered != null) {
      accountId = remembered.id;
    } else if (accounts.needsChoice && chooseSim != null) {
      final choice = await chooseSim(accounts.accounts);
      if (choice == null) return PlaceCallOutcome.cancelled;
      accountId = choice.account.id;
      if (choice.remember &&
          !PhoneNumbers.isEmergency(number, countryIso: countryIso)) {
        await updateSettings(settings.withSimFor(number, accountId));
      }
    }

    try {
      await platform.placeCall(number, accountId: accountId);
      return PlaceCallOutcome.placed;
    } on DialerException catch (e) {
      recordDiagnostic('placeCall', e.code);
      if (e.code == DialerException.permissionDenied) {
        return PlaceCallOutcome.permissionDenied;
      }
      return PlaceCallOutcome.failed;
    }
  }

  /// Long-press 1.
  Future<PlaceCallOutcome> callVoicemail({SimChooser? chooseSim}) async {
    if (!await _ensureCallPermission()) {
      return PlaceCallOutcome.permissionDenied;
    }
    String? accountId;
    final accounts = await phoneAccounts();
    if (accounts.needsChoice && chooseSim != null) {
      final choice = await chooseSim(accounts.accounts);
      if (choice == null) return PlaceCallOutcome.cancelled;
      accountId = choice.account.id;
    }
    try {
      await platform.callVoicemail(accountId: accountId);
      return PlaceCallOutcome.placed;
    } on DialerException catch (e) {
      return e.code == DialerException.permissionDenied
          ? PlaceCallOutcome.permissionDenied
          : PlaceCallOutcome.failed;
    }
  }

  // ---- in-call actions ---------------------------------------------------

  Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } on DialerException catch (e) {
      // The next snapshot reflects the real state; just note it for diagnostics.
      recordDiagnostic('platform', e.code);
    }
  }

  Future<void> answer(ActiveCall c) => _safe(() => platform.answer(c.id));
  Future<void> reject(ActiveCall c) => _safe(() => platform.reject(c.id));
  Future<void> hangUp(ActiveCall c) => _safe(() => platform.disconnect(c.id));
  Future<void> toggleHold(ActiveCall c) =>
      _safe(() => c.isOnHold ? platform.unhold(c.id) : platform.hold(c.id));

  /// Resume [other]; Telecom holds the currently active call automatically.
  Future<void> swapTo(ActiveCall other) =>
      _safe(() => platform.unhold(other.id));

  Future<void> toggleMute() =>
      _safe(() => platform.setMuted(!calls.audio.muted));

  Future<void> toggleSpeaker() => _safe(
    () => platform.setAudioRoute(
      calls.audio.onSpeaker ? calls.audio.privateRoute : AudioRoute.speaker,
    ),
  );

  Future<void> toggleBluetooth() => _safe(
    () => platform.setAudioRoute(
      calls.audio.onBluetooth ? AudioRoute.earpiece : AudioRoute.bluetooth,
    ),
  );

  Future<void> dtmfDown(ActiveCall c, String digit) =>
      _safe(() => platform.playDtmf(c.id, digit));
  Future<void> dtmfUp(ActiveCall c) => _safe(() => platform.stopDtmf(c.id));

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (DiagnosticsSink.handler == recordDiagnostic) {
      DiagnosticsSink.handler = null;
    }
    for (final s in _subs) {
      s.cancel();
    }
    pendingDialNumber.dispose();
    pendingCallNumber.dispose();
    pendingTab.dispose();
    super.dispose();
  }
}

/// Provides the [AppController] to the widget tree.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing to rebuilds.
  static AppController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
