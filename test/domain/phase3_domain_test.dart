import 'package:flutter_test/flutter_test.dart';
import 'package:smart_dial/domain/app_settings.dart';
import 'package:smart_dial/domain/diagnostics.dart';
import 'package:smart_dial/domain/notes.dart';
import 'package:smart_dial/domain/reminder.dart';

void main() {
  final t0 = DateTime(2026, 10, 20, 10);

  group('NotesBook', () {
    CallNote n(String id, String number, String text, int minutes) => CallNote(
      id: id,
      number: number,
      text: text,
      createdAt: t0,
      updatedAt: t0.add(Duration(minutes: minutes)),
    );

    test('lookup ignores formatting and country code; newest first', () {
      final b = const NotesBook()
          .upsert(n('1', '+91 98470 12345', 'first', 0))
          .upsert(n('2', '09847012345', 'second', 5))
          .upsert(n('3', '9000000000', 'other', 1));
      expect(b.forNumber('9847012345').map((x) => x.id), ['2', '1']);
      expect(b.hasNotes('9000000000'), isTrue);
      expect(b.hasNotes('1234567'), isFalse);
      expect(b.forNumbers(['9000000000', '+919847012345']).map((x) => x.id), [
        '2',
        '3',
        '1',
      ]);
      expect(b.forNumber(''), isEmpty);
    });

    test('upsert replaces by id, trims, clips, and empty text deletes', () {
      var b = const NotesBook().upsert(n('1', '123456', '  hello  ', 0));
      expect(b.notes.single.text, 'hello');
      b = b.upsert(n('1', '123456', 'edited', 1));
      expect(b.notes.single.text, 'edited');
      b = b.upsert(n('2', '123456', 'x' * 5000, 2));
      expect(b.forNumber('123456').first.text.length, CallNote.maxLength);
      b = b.upsert(n('1', '123456', '   ', 3));
      expect(b.notes.map((x) => x.id), ['2']);
      expect(b.remove('2').notes, isEmpty);
    });

    test('JSON round trip and corrupt input', () {
      final b = const NotesBook().upsert(n('1', '123456', 'ശ്രദ്ധിക്കുക', 0));
      final back = NotesBook.decode(b.encode());
      expect(back.notes.single.text, 'ശ്രദ്ധിക്കുക');
      expect(back.notes.single.updatedAt, b.notes.single.updatedAt);
      expect(NotesBook.decode('nope').notes, isEmpty);
      expect(
        NotesBook.decode(
          '{"notes":[{"id":1},{"id":"a","number":"1","text":""}]}',
        ).notes,
        isEmpty,
      );
    });
  });

  group('Reminder', () {
    test('map round trip and tolerant parsing', () {
      final r = Reminder(
        id: 'r1',
        number: '9847012345',
        name: 'Anu',
        dueAt: t0,
        note: 'about rent',
      );
      final back = Reminder.fromMap(r.toMap())!;
      expect(back.name, 'Anu');
      expect(back.dueAt, t0);
      expect(back.done, isFalse);
      expect(Reminder.fromMap({'id': 'x'}), isNull);
      expect(
        Reminder.fromMap({
          'id': 'x',
          'number': '1',
          'dueAt': 5,
          'name': ' ',
        })!.name,
        isNull,
      );
    });

    test('overdue and sorting', () {
      final list = [
        Reminder(
          id: 'later',
          number: '1',
          dueAt: t0.add(const Duration(hours: 3)),
        ),
        Reminder(
          id: 'done-old',
          number: '1',
          dueAt: t0.subtract(const Duration(days: 2)),
          done: true,
        ),
        Reminder(
          id: 'overdue',
          number: '1',
          dueAt: t0.subtract(const Duration(hours: 1)),
        ),
        Reminder(
          id: 'done-new',
          number: '1',
          dueAt: t0.subtract(const Duration(hours: 2)),
          done: true,
        ),
      ];
      expect(sortReminders(list).map((r) => r.id), [
        'overdue',
        'later',
        'done-new',
        'done-old',
      ]);
      expect(list[2].isOverdue(t0), isTrue);
      expect(list[1].isOverdue(t0), isFalse, reason: 'done is never overdue');
    });

    test('quick times', () {
      final morning = DateTime(2026, 10, 20, 10, 30);
      expect(
        quickReminderTime(QuickReminder.in15Minutes, morning),
        DateTime(2026, 10, 20, 10, 45),
      );
      expect(
        quickReminderTime(QuickReminder.in1Hour, morning),
        DateTime(2026, 10, 20, 11, 30),
      );
      expect(
        quickReminderTime(QuickReminder.thisEvening, morning),
        DateTime(2026, 10, 20, 19),
      );
      expect(
        quickReminderTime(
          QuickReminder.thisEvening,
          DateTime(2026, 10, 20, 18, 5),
        ),
        isNull,
      );
      expect(
        quickReminderTime(
          QuickReminder.tomorrowMorning,
          DateTime(2026, 10, 31, 23),
        ),
        DateTime(2026, 11, 1, 9),
      );
    });

    test('local ids are unique', () {
      final ids = {for (var i = 0; i < 100; i++) newLocalId(t0)};
      expect(ids.length, 100);
    });
  });

  group('diagnostics scrubbing', () {
    test('removes phone numbers in any format', () {
      for (final s in [
        'call to 9847012345 failed',
        'call to +91 98470 12345 failed',
        'call to (415) 555-0100 failed',
        'call to 0471-2345678 failed',
      ]) {
        final out = scrubPii(s);
        expect(out, 'call to <number> failed', reason: s);
      }
    });

    test(
      'keeps short codes, versions and error codes; removes uris and emails',
      () {
        expect(
          scrubPii('HTTP 404 at line 12, api 34'),
          'HTTP 404 at line 12, api 34',
        );
        expect(
          scrubPii('open content://com.android.contacts/contacts/1234 x'),
          'open <uri> x',
        );
        expect(scrubPii('tel:9847012345 bad'), '<uri> bad');
        expect(scrubPii('from anu@example.com'), 'from <email>');
      },
    );

    test('truncates and collapses whitespace', () {
      expect(scrubPii('a   b\n\nc'), 'a b c');
      expect(scrubPii('x' * 500).length, 301);
    });

    test('log caps entries, scrubs on add, round-trips', () {
      var log = DiagnosticsLog.empty;
      for (var i = 0; i < 130; i++) {
        log = log.add(
          'channel',
          'failed for 98470123$i',
          t0.add(Duration(seconds: i)),
        );
      }
      expect(log.entries.length, DiagnosticsLog.maxEntries);
      expect(log.entries.first.at, t0.add(const Duration(seconds: 30)));
      expect(log.entries.every((e) => !e.message.contains('98470')), isTrue);
      final back = DiagnosticsLog.decode(log.encode());
      expect(back.entries.length, 100);
      final report = back.report(appVersion: '0.3.0', platform: 'Android 14');
      expect(report.split('\n').first, 'Smart Dial 0.3.0 · Android 14');
      expect(report, isNot(contains('98470')));
      expect(DiagnosticsLog.decode('garbage').entries, isEmpty);
    });
  });

  group('language setting', () {
    test('persists and tolerates unknown codes', () {
      final s = AppSettings.defaults.copyWith(language: AppLanguage.malayalam);
      expect(AppSettings.decode(s.encode()).language, AppLanguage.malayalam);
      expect(
        AppSettings.decode('{"language":"fr"}').language,
        AppLanguage.system,
      );
      expect(AppLanguage.malayalam.localeCode, 'ml');
      expect(AppLanguage.system.localeCode, isNull);
    });
  });
}
