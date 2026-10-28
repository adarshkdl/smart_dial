/// "Frequently contacted" scoring from the system call log. Computed on demand, never stored.
library;

import 'call_log.dart';
import 'contact.dart';
import 'phone_number.dart';

String _key(String number) {
  final d = PhoneNumbers.digitsOnly(number);
  return d.length > 10 ? d.substring(d.length - 10) : d;
}

/// Per-number score over the last [window]: connected calls count 1.0, missed /
/// declined 0.3, decayed by age (a call a week ago counts half).
Map<String, double> numberScores(
  List<CallLogEntry> log, {
  required DateTime now,
  Duration window = const Duration(days: 30),
}) {
  final out = <String, double>{};
  for (final e in log) {
    if (PhoneNumbers.isPrivate(e.number)) continue;
    final age = now.difference(e.date);
    if (age.isNegative || age > window) continue;
    final base = switch (e.type) {
      CallType.outgoing => 1.0,
      CallType.incoming || CallType.answeredExternally => 1.0,
      CallType.missed || CallType.rejected => 0.3,
      _ => 0.0,
    };
    if (base == 0) continue;
    final w = base / (1 + age.inHours / (24 * 7));
    final k = _key(e.number);
    out[k] = (out[k] ?? 0) + w;
  }
  return out;
}

/// Contact id → summed score of all its numbers.
Map<String, double> contactScores(
  List<Contact> contacts,
  Map<String, double> byNumber,
) {
  if (byNumber.isEmpty) return const {};
  final out = <String, double>{};
  for (final c in contacts) {
    var s = 0.0;
    final seen = <String>{};
    for (final p in c.phones) {
      final k = _key(p.number);
      if (seen.add(k)) s += byNumber[k] ?? 0;
    }
    if (s > 0) out[c.id] = s;
  }
  return out;
}

/// Most frequently contacted, highest first. Starred contacts are excluded when
/// [excludeStarred] (they already sit in the Favorites grid).
List<Contact> frequentContacts(
  List<Contact> contacts,
  Map<String, double> scores, {
  int limit = 8,
  bool excludeStarred = true,
}) {
  final list = [
    for (final c in contacts)
      if ((scores[c.id] ?? 0) > 0 && !(excludeStarred && c.starred)) c,
  ];
  list.sort((a, b) => scores[b.id]!.compareTo(scores[a.id]!));
  return list.take(limit).toList();
}
