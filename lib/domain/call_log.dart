import 'phone_number.dart';

enum CallType {
  incoming,
  outgoing,
  missed,
  voicemail,
  rejected,
  blocked,
  answeredExternally,
  unknown,
}

/// Maps `android.provider.CallLog.Calls.TYPE`.
CallType callTypeFromAndroid(int? v) => switch (v) {
  1 => CallType.incoming,
  2 => CallType.outgoing,
  3 => CallType.missed,
  4 => CallType.voicemail,
  5 => CallType.rejected,
  6 => CallType.blocked,
  7 => CallType.answeredExternally,
  _ => CallType.unknown,
};

class CallLogEntry {
  const CallLogEntry({
    required this.id,
    required this.number,
    required this.type,
    required this.date,
    this.name,
    this.duration = Duration.zero,
    this.accountId,
  });

  final String id;
  final String number;
  final String? name;
  final CallType type;
  final DateTime date;
  final Duration duration;
  final String? accountId;

  factory CallLogEntry.fromMap(Map<Object?, Object?> m) => CallLogEntry(
    id: '${m['id']}',
    number: (m['number'] as String?) ?? '',
    name: (m['name'] as String?)?.trim().isEmpty ?? true
        ? null
        : (m['name'] as String).trim(),
    type: callTypeFromAndroid((m['type'] as num?)?.toInt()),
    date: DateTime.fromMillisecondsSinceEpoch(
      (m['date'] as num?)?.toInt() ?? 0,
    ),
    duration: Duration(seconds: (m['duration'] as num?)?.toInt() ?? 0),
    accountId: m['accountId'] as String?,
  );
}

/// Consecutive calls with the same number on the same calendar day.
class CallLogGroup {
  CallLogGroup(this.entries) : assert(entries.isNotEmpty);

  /// Newest first.
  final List<CallLogEntry> entries;

  CallLogEntry get latest => entries.first;
  String get number => latest.number;
  String? get name => entries
      .map((e) => e.name)
      .firstWhere((n) => n != null, orElse: () => null);
  int get count => entries.length;
  List<String> get ids => [for (final e in entries) e.id];
  bool get hasMissed => entries.any((e) => e.type == CallType.missed);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Groups a newest-first list. Input order is preserved; nothing is re-sorted.
List<CallLogGroup> groupCallLog(List<CallLogEntry> entries) {
  final groups = <CallLogGroup>[];
  List<CallLogEntry>? current;
  for (final e in entries) {
    final head = current?.first;
    final joinable =
        head != null &&
        !PhoneNumbers.isPrivate(e.number) &&
        PhoneNumbers.sameNumber(head.number, e.number) &&
        _sameDay(head.date, e.date);
    if (joinable) {
      current!.add(e);
    } else {
      if (current != null) groups.add(CallLogGroup(current));
      current = [e];
    }
  }
  if (current != null) groups.add(CallLogGroup(current));
  return groups;
}

enum CallLogFilter { all, missed, incoming, outgoing, declined }

List<CallLogEntry> filterCallLog(
  List<CallLogEntry> entries, {
  CallLogFilter filter = CallLogFilter.all,
  String query = '',

  /// Only calls made/received on this phone account (SIM); null = any.
  String? accountId,
}) {
  final q = query.trim().toLowerCase();
  final qDigits = PhoneNumbers.digitsOnly(q);
  bool typeOk(CallLogEntry e) => switch (filter) {
    CallLogFilter.all => true,
    CallLogFilter.missed => e.type == CallType.missed,
    CallLogFilter.incoming =>
      e.type == CallType.incoming || e.type == CallType.answeredExternally,
    CallLogFilter.outgoing => e.type == CallType.outgoing,
    CallLogFilter.declined =>
      e.type == CallType.rejected || e.type == CallType.blocked,
  };
  bool queryOk(CallLogEntry e) {
    if (q.isEmpty) return true;
    if ((e.name ?? '').toLowerCase().contains(q)) return true;
    return qDigits.isNotEmpty &&
        PhoneNumbers.digitsOnly(e.number).contains(qDigits);
  }

  return [
    for (final e in entries)
      if (typeOk(e) &&
          queryOk(e) &&
          (accountId == null || e.accountId == accountId))
        e,
  ];
}

/// `0:45`, `12:03`, `1:02:03`.
String formatCallDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}
