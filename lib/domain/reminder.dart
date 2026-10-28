/// "Call X back" reminders. Scheduling and storage live natively (so alarms work with
/// the app closed and after reboot); this is the Dart view of them.
library;

class Reminder {
  const Reminder({
    required this.id,
    required this.number,
    required this.dueAt,
    this.name,
    this.note,
    this.done = false,
  });

  final String id;
  final String number;
  final String? name;
  final DateTime dueAt;
  final String? note;
  final bool done;

  bool isOverdue(DateTime now) => !done && dueAt.isBefore(now);

  Reminder copyWith({DateTime? dueAt, bool? done, String? note}) => Reminder(
    id: id,
    number: number,
    name: name,
    dueAt: dueAt ?? this.dueAt,
    note: note ?? this.note,
    done: done ?? this.done,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'number': number,
    'name': name,
    'dueAt': dueAt.millisecondsSinceEpoch,
    'note': note,
    'done': done,
  };

  static Reminder? fromMap(Object? m) {
    if (m is! Map) return null;
    final id = m['id'], number = m['number'], due = m['dueAt'];
    if (id is! String || number is! String || due is! num) return null;
    final name = m['name'], note = m['note'];
    return Reminder(
      id: id,
      number: number,
      name: name is String && name.trim().isNotEmpty ? name : null,
      note: note is String && note.trim().isNotEmpty ? note : null,
      dueAt: DateTime.fromMillisecondsSinceEpoch(due.toInt()),
      done: m['done'] == true,
    );
  }
}

/// Pending first (soonest / most overdue on top), then done (most recent first).
List<Reminder> sortReminders(Iterable<Reminder> list) {
  final pending = [
    for (final r in list)
      if (!r.done) r,
  ]..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  final done = [
    for (final r in list)
      if (r.done) r,
  ]..sort((a, b) => b.dueAt.compareTo(a.dueAt));
  return [...pending, ...done];
}

enum QuickReminder { in15Minutes, in1Hour, thisEvening, tomorrowMorning }

/// Concrete time for a quick option, or null when it no longer makes sense
/// (e.g. "this evening" after 6 pm).
DateTime? quickReminderTime(QuickReminder q, DateTime now) => switch (q) {
  QuickReminder.in15Minutes => now.add(const Duration(minutes: 15)),
  QuickReminder.in1Hour => now.add(const Duration(hours: 1)),
  QuickReminder.thisEvening =>
    now.hour < 18 ? DateTime(now.year, now.month, now.day, 19) : null,
  QuickReminder.tomorrowMorning => DateTime(
    now.year,
    now.month,
    now.day + 1,
    9,
  ),
};

/// Unique enough for local ids (time + counter); no randomness needed.
String newLocalId(DateTime now) => '${now.microsecondsSinceEpoch}-${_seq++}';
int _seq = 0;
