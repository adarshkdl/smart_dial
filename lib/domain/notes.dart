/// Notes attached to a phone number (and therefore to its contact and calls).
/// App-owned data: stored encrypted on the device, never uploaded.
library;

import 'dart:convert';

import 'app_settings.dart';

class CallNote {
  const CallNote({
    required this.id,
    required this.number,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  static const maxLength = 1000;

  final String id;

  /// Number as dialled / shown; matching uses [key].
  final String number;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get key => AppSettings.numberKey(number);

  CallNote copyWith({String? text, DateTime? updatedAt}) => CallNote(
    id: id,
    number: number,
    text: text ?? this.text,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'number': number,
    'text': text,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  static CallNote? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], number = j['number'], text = j['text'];
    if (id is! String ||
        number is! String ||
        text is! String ||
        text.trim().isEmpty) {
      return null;
    }
    DateTime t(Object? v) =>
        DateTime.fromMillisecondsSinceEpoch(v is int ? v : 0);
    return CallNote(
      id: id,
      number: number,
      text: text,
      createdAt: t(j['createdAt']),
      updatedAt: t(j['updatedAt']),
    );
  }
}

/// Immutable collection of notes with number-keyed lookup.
class NotesBook {
  const NotesBook([this.notes = const []]);

  static const empty = NotesBook();

  final List<CallNote> notes;

  /// Notes for [number] (any formatting / country prefix), newest first.
  List<CallNote> forNumber(String number) {
    final k = AppSettings.numberKey(number);
    if (k.isEmpty) return const [];
    final list = [
      for (final n in notes)
        if (n.key == k) n,
    ];
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// Notes for any of [numbers] (a contact with several numbers), newest first.
  List<CallNote> forNumbers(Iterable<String> numbers) {
    final keys = {for (final n in numbers) AppSettings.numberKey(n)}
      ..remove('');
    final list = [
      for (final n in notes)
        if (keys.contains(n.key)) n,
    ];
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  bool hasNotes(String number) => forNumber(number).isNotEmpty;

  /// Adds or replaces (by id). Empty text deletes.
  NotesBook upsert(CallNote note) {
    final trimmed = note.text.trim();
    final others = [
      for (final n in notes)
        if (n.id != note.id) n,
    ];
    if (trimmed.isEmpty) return NotesBook(others);
    final clipped = trimmed.length > CallNote.maxLength
        ? trimmed.substring(0, CallNote.maxLength)
        : trimmed;
    return NotesBook([...others, note.copyWith(text: clipped)]);
  }

  NotesBook remove(String id) => NotesBook([
    for (final n in notes)
      if (n.id != id) n,
  ]);

  String encode() => jsonEncode({
    'version': 1,
    'notes': [for (final n in notes) n.toJson()],
  });

  static NotesBook decode(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    try {
      final j = jsonDecode(raw);
      if (j is! Map || j['notes'] is! List) return empty;
      return NotesBook([
        for (final n in j['notes'] as List) ?CallNote.fromJson(n),
      ]);
    } on FormatException {
      return empty;
    }
  }
}
