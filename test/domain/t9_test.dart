import 'package:flutter_test/flutter_test.dart';
import 'package:smart_dial/domain/contact.dart';
import 'package:smart_dial/domain/t9.dart';

Contact c(
  String id,
  String name,
  List<String> numbers, {
  bool starred = false,
}) => Contact(
  id: id,
  name: name,
  starred: starred,
  phones: [for (final n in numbers) ContactPhone(n)],
);

List<String> ids(List<T9Match> m) => [for (final x in m) x.contact.id];

void main() {
  group('mapping', () {
    test('letters to keypad digits', () {
      expect(toT9('Anu Mathew'), '268628439');
      expect(toT9('PQRS tuv wxyz'), '77778889999');
      expect(toT9("O'Brien"), '627436');
      expect(toT9('José'), '5673');
      expect(toT9('Room 101'), '7666101');
    });
    test('non-Latin scripts have no digits', () {
      expect(toT9('അനു'), '');
      expect(t9Digit(' '), isNull);
    });
  });

  group('matching tiers', () {
    final index = T9Index([
      c('anu', 'Anu Mathew', ['9847012345']),
      c('mat', 'Mathew Thomas', ['9000000001']),
      c('bin', 'Bindu Nair', ['04712345678']),
      c('amb', 'Ambili', ['+91 99999 26861']),
      c('ml', 'അനു', ['9895550000']),
    ]);

    test('first-word prefix beats later-word prefix', () {
      final r = index.search('628');
      expect(ids(r), ['mat', 'anu']);
      expect(r[0].tier, 0);
      expect(r[1].tier, 1);
    });

    test('prefix runs across words', () {
      final r = index.search('2686');
      expect(r.first.contact.id, 'anu');
      expect(r.first.nameHighlight, {0, 1, 2, 4});
    });

    test('initials match', () {
      // Bindu Nair → B(2) N(6)
      final r = index.search('26');
      expect(r.map((m) => (m.contact.id, m.tier)), contains(('bin', 2)));
      expect(
        r.first.tier,
        0,
        reason: 'name prefixes still rank above initials',
      );
    });

    test('number prefix, with and without country code / trunk 0', () {
      expect(index.search('98470').single.contact.id, 'anu');
      expect(index.search('98470').single.tier, 3);
      expect(index.search('4712').single.contact.id, 'bin');
      final amb = index.search('99999');
      expect(amb.single.contact.id, 'amb');
      expect(amb.single.phoneHighlight, (
        2,
        7,
      ), reason: 'offset past the 91 prefix');
    });

    test('mid-word name contains needs ≥3 digits', () {
      // "thew" → 8439 is inside "Mathew"
      expect(
        index.search('8439').map((m) => m.contact.id),
        containsAll(['anu', 'mat']),
      );
      expect(
        index.search('43'),
        isEmpty,
        reason: '2 digits is too short for contains',
      );
    });

    test('number contains', () {
      final r = index.search('12345');
      expect(ids(r), containsAll(['anu', 'bin']));
      expect(r.every((m) => m.tier == 5 || m.tier == 3), isTrue);
    });

    test('non-Latin names still match by number', () {
      expect(index.search('98955').single.contact.id, 'ml');
    });

    test('+ * # queries only match numbers', () {
      expect(index.search('+26'), isEmpty);
      expect(ids(index.search('+9198470')), ['anu']);
    });

    test('empty query', () => expect(index.search(''), isEmpty));
  });

  group('ranking ties', () {
    final index = T9Index([
      c('1', 'Anil', ['1']),
      c('2', 'Anitha', ['2']),
      c('3', 'Anand', ['3'], starred: true),
    ]);
    test('frequency first, then starred, then name', () {
      expect(ids(index.search('264')), [
        '1',
        '2',
      ], reason: 'alphabetical when equal');
      expect(ids(index.search('26')), [
        '3',
        '1',
        '2',
      ], reason: 'starred beats name');
      expect(ids(index.search('26', frequency: {'2': 5.0, '1': 1.0})), [
        '2',
        '1',
        '3',
      ]);
    });
    test('limit', () => expect(index.search('26', limit: 1).length, 1));
  });

  test('responsive on 20 000 contacts', () {
    final names = [
      'Anu',
      'Bindu',
      'Ravi',
      'Sreeja',
      'Thomas',
      'Mathew',
      'Lakshmi',
      'Joseph',
    ];
    final list = [
      for (var i = 0; i < 20000; i++)
        c('$i', '${names[i % 8]} ${names[(i ~/ 8) % 8]} $i', [
          '98${i.toString().padLeft(8, '0')}',
        ]),
    ];
    final sw = Stopwatch()..start();
    final index = T9Index(list);
    final build = sw.elapsedMilliseconds;
    sw.reset();
    for (final q in ['2', '26', '268', '7', '98000', '1234']) {
      index.search(q);
    }
    final perQuery = sw.elapsedMilliseconds / 6;
    expect(build, lessThan(1500));
    expect(perQuery, lessThan(150));
  });
}
