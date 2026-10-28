import 'package:flutter_test/flutter_test.dart';
import 'package:smart_dial/domain/app_settings.dart';
import 'package:smart_dial/domain/call_log.dart';
import 'package:smart_dial/domain/contact.dart';
import 'package:smart_dial/domain/frequency.dart';

void main() {
  final now = DateTime(2026, 10, 20, 12);
  CallLogEntry e(
    String n,
    CallType t,
    int daysAgo, {
    String id = 'x',
    String? acc,
  }) => CallLogEntry(
    id: id,
    number: n,
    type: t,
    date: now.subtract(Duration(days: daysAgo)),
    accountId: acc,
  );

  group('frequency', () {
    test('recent connected calls weigh more than old or missed ones', () {
      final s = numberScores([
        e('9847012345', CallType.outgoing, 0),
        e('+919847012345', CallType.incoming, 1),
        e('9000000000', CallType.outgoing, 20),
        e('9111111111', CallType.missed, 0),
        e('9222222222', CallType.outgoing, 45),
        e('', CallType.incoming, 0),
      ], now: now);
      expect(s.keys, containsAll(['9847012345', '9000000000', '9111111111']));
      expect(
        s.containsKey('9222222222'),
        isFalse,
        reason: 'outside 30-day window',
      );
      expect(s.length, 3, reason: 'private numbers ignored');
      expect(s['9847012345']!, greaterThan(s['9000000000']!));
      expect(s['9000000000']!, greaterThan(0));
      expect(s['9111111111']!, closeTo(0.3, 0.01));
    });

    test(
      'contact scores sum their numbers; frequent list excludes starred',
      () {
        const contacts = [
          Contact(
            id: 'a',
            name: 'Anu',
            phones: [ContactPhone('9847012345'), ContactPhone('9000000000')],
          ),
          Contact(id: 'b', name: 'Bindu', phones: [ContactPhone('9111111111')]),
          Contact(
            id: 's',
            name: 'Star',
            starred: true,
            phones: [ContactPhone('9333333333')],
          ),
          Contact(id: 'n', name: 'Never', phones: [ContactPhone('9444444444')]),
        ];
        final byNum = numberScores([
          e('9847012345', CallType.outgoing, 0),
          e('9000000000', CallType.outgoing, 0),
          e('9111111111', CallType.outgoing, 0),
          e('9333333333', CallType.outgoing, 0),
          e('9333333333', CallType.outgoing, 0),
          e('9333333333', CallType.outgoing, 0),
        ], now: now);
        final scores = contactScores(contacts, byNum);
        expect(scores['a'], closeTo(2.0, 0.01));
        expect(scores.containsKey('n'), isFalse);
        expect(frequentContacts(contacts, scores).map((c) => c.id), ['a', 'b']);
        expect(
          frequentContacts(contacts, scores, excludeStarred: false).first.id,
          's',
        );
        expect(frequentContacts(contacts, scores, limit: 1).length, 1);
      },
    );
  });

  group('advanced call-log filters', () {
    final log = [
      e('1', CallType.rejected, 0, id: '1', acc: 'sim1'),
      e('2', CallType.blocked, 0, id: '2', acc: 'sim2'),
      e('3', CallType.outgoing, 0, id: '3', acc: 'sim2'),
      e('4', CallType.missed, 0, id: '4', acc: 'sim1'),
    ];
    test('declined covers rejected + blocked', () {
      expect(
        filterCallLog(log, filter: CallLogFilter.declined).map((x) => x.id),
        ['1', '2'],
      );
    });
    test('by SIM', () {
      expect(filterCallLog(log, accountId: 'sim2').map((x) => x.id), [
        '2',
        '3',
      ]);
      expect(
        filterCallLog(log, filter: CallLogFilter.missed, accountId: 'sim2'),
        isEmpty,
      );
    });
  });

  group('AppSettings', () {
    test('round-trips through JSON', () {
      final s = AppSettings.defaults
          .copyWith(
            theme: ThemePreference.dark,
            accent: AccentColor.purple,
            keypadSize: KeypadSize.large,
            keypadTones: false,
          )
          .withSpeedDial(
            2,
            const SpeedDialEntry(number: '9847012345', name: 'Anu'),
          )
          .withSimFor('+91 98470 12345', 'sim2');
      final back = AppSettings.decode(s.encode());
      expect(back.theme, ThemePreference.dark);
      expect(back.accent, AccentColor.purple);
      expect(back.keypadSize, KeypadSize.large);
      expect(back.keypadTones, isFalse);
      expect(back.speedDial[2]!.name, 'Anu');
      expect(
        back.simFor('09847012345'),
        'sim2',
        reason: 'matched by last 10 digits',
      );
    });

    test('corrupt or unknown data falls back to defaults without throwing', () {
      expect(AppSettings.decode(null).theme, ThemePreference.system);
      expect(AppSettings.decode('{not json').accent, AccentColor.teal);
      expect(AppSettings.decode('[1,2]').keypadSize, KeypadSize.normal);
      final weird = AppSettings.decode(
        '{"theme":"neon","keypadTones":"yes","speedDial":{"1":{"number":"x"},"5":{"number":"55555"},"x":{}},"simByNumber":{"1":2}}',
      );
      expect(weird.theme, ThemePreference.system);
      expect(weird.keypadTones, isTrue);
      expect(
        weird.speedDial.keys,
        [5],
        reason: 'key 1 is voicemail; non-numeric keys dropped',
      );
      expect(weird.simByNumber, isEmpty);
    });

    test('speed dial remove and SIM memory toggle', () {
      final s = AppSettings.defaults
          .withSpeedDial(3, const SpeedDialEntry(number: '123'))
          .withSpeedDial(3, null);
      expect(s.speedDial, isEmpty);
      final remembered = AppSettings.defaults.withSimFor('9847012345', 'a');
      expect(remembered.simFor('9847012345'), 'a');
      expect(
        remembered.copyWith(rememberSimPerContact: false).simFor('9847012345'),
        isNull,
      );
    });

    test('keypad scale', () {
      expect(
        AppSettings.defaults
            .copyWith(keypadSize: KeypadSize.compact)
            .keypadScale,
        lessThan(1),
      );
      expect(
        AppSettings.defaults.copyWith(keypadSize: KeypadSize.large).keypadScale,
        greaterThan(1),
      );
    });
  });

  test('Contact.copyWith keeps everything but starred', () {
    const a = Contact(
      id: '1',
      name: 'A',
      company: 'C',
      phones: [ContactPhone('1')],
    );
    final b = a.copyWith(starred: true);
    expect(b.starred, isTrue);
    expect(b.company, 'C');
    expect(b.phones.length, 1);
  });
}
