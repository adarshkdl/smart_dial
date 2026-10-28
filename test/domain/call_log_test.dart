import 'package:flutter_test/flutter_test.dart';
import 'package:smart_dial/domain/call_log.dart';

CallLogEntry e(
  String id,
  String number,
  CallType t,
  DateTime d, {
  String? name,
  int secs = 0,
}) => CallLogEntry(
  id: id,
  number: number,
  type: t,
  date: d,
  name: name,
  duration: Duration(seconds: secs),
);

void main() {
  final day1 = DateTime(2026, 10, 20, 10);
  final day0 = DateTime(2026, 10, 19, 22);

  group('callTypeFromAndroid', () {
    test('maps provider constants', () {
      expect(callTypeFromAndroid(1), CallType.incoming);
      expect(callTypeFromAndroid(2), CallType.outgoing);
      expect(callTypeFromAndroid(3), CallType.missed);
      expect(callTypeFromAndroid(5), CallType.rejected);
      expect(callTypeFromAndroid(6), CallType.blocked);
      expect(callTypeFromAndroid(99), CallType.unknown);
      expect(callTypeFromAndroid(null), CallType.unknown);
    });
  });

  group('fromMap', () {
    test('parses native map and trims blank names', () {
      final x = CallLogEntry.fromMap({
        'id': '7',
        'number': '9847012345',
        'name': '  ',
        'type': 3,
        'date': 1000,
        'duration': 65,
        'accountId': 'sim1',
      });
      expect(x.id, '7');
      expect(x.name, isNull);
      expect(x.type, CallType.missed);
      expect(x.duration, const Duration(seconds: 65));
      expect(x.accountId, 'sim1');
    });
  });

  group('groupCallLog', () {
    test('groups consecutive same-number calls on the same day', () {
      final groups = groupCallLog([
        e(
          '1',
          '+919847012345',
          CallType.missed,
          day1.add(const Duration(minutes: 30)),
        ),
        e('2', '9847012345', CallType.incoming, day1, name: 'Anu'),
        e('3', '9847012345', CallType.outgoing, day0),
        e(
          '4',
          '121',
          CallType.outgoing,
          day0.subtract(const Duration(hours: 1)),
        ),
      ]);
      expect(groups.length, 3);
      expect(groups[0].count, 2);
      expect(groups[0].ids, ['1', '2']);
      expect(
        groups[0].name,
        'Anu',
        reason: 'name taken from any entry in the group',
      );
      expect(groups[0].hasMissed, isTrue);
      expect(groups[1].ids, ['3'], reason: 'different day starts a new group');
      expect(groups[2].number, '121');
    });

    test('non-consecutive calls are not merged', () {
      final groups = groupCallLog([
        e('1', '111222333', CallType.outgoing, day1),
        e('2', '444555666', CallType.outgoing, day1),
        e('3', '111222333', CallType.outgoing, day1),
      ]);
      expect(groups.map((g) => g.count), [1, 1, 1]);
    });

    test('private numbers are never grouped together', () {
      final groups = groupCallLog([
        e('1', '', CallType.missed, day1),
        e('2', '', CallType.missed, day1),
      ]);
      expect(groups.length, 2);
    });

    test('empty input', () => expect(groupCallLog(const []), isEmpty));
  });

  group('filterCallLog', () {
    final list = [
      e('1', '9847012345', CallType.missed, day1, name: 'Anu Mathew'),
      e('2', '4155550100', CallType.incoming, day1),
      e('3', '9847099999', CallType.outgoing, day1, name: 'Ravi'),
      e(
        '4',
        '9847012345',
        CallType.answeredExternally,
        day0,
        name: 'Anu Mathew',
      ),
    ];
    test('by type', () {
      expect(
        filterCallLog(list, filter: CallLogFilter.missed).map((x) => x.id),
        ['1'],
      );
      expect(
        filterCallLog(list, filter: CallLogFilter.incoming).map((x) => x.id),
        ['2', '4'],
      );
      expect(
        filterCallLog(list, filter: CallLogFilter.outgoing).map((x) => x.id),
        ['3'],
      );
      expect(filterCallLog(list).length, 4);
    });
    test('by name, case-insensitive', () {
      expect(filterCallLog(list, query: 'anu').map((x) => x.id), ['1', '4']);
    });
    test('by partial number ignoring formatting', () {
      expect(filterCallLog(list, query: '555-01').map((x) => x.id), ['2']);
    });
    test('type and query combined', () {
      expect(
        filterCallLog(list, filter: CallLogFilter.missed, query: 'ravi'),
        isEmpty,
      );
    });
  });

  test('formatCallDuration', () {
    expect(formatCallDuration(const Duration(seconds: 5)), '0:05');
    expect(
      formatCallDuration(const Duration(minutes: 12, seconds: 3)),
      '12:03',
    );
    expect(
      formatCallDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });
}
