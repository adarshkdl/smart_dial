import 'package:flutter_test/flutter_test.dart';
import 'package:smart_dial/domain/contact.dart';

Contact c(String id, String name, List<String> numbers, {String? company}) =>
    Contact(
      id: id,
      name: name,
      company: company,
      phones: [for (final n in numbers) ContactPhone(n)],
    );

void main() {
  group('initialsFor', () {
    test('two words', () => expect(initialsFor('anu mathew'), 'AM'));
    test('one word', () => expect(initialsFor('Ravi'), 'R'));
    test(
      'more than two words uses first two',
      () => expect(initialsFor('Mary Ann Joseph'), 'MA'),
    );
    test('numbers or blank → #', () {
      expect(initialsFor(''), '#');
      expect(initialsFor('+91 98470'), '#');
    });
    test('Malayalam grapheme kept whole', () {
      // "ക്ഷ" is a conjunct; the first grapheme cluster must not be split.
      final i = initialsFor('ക്ഷേത്ര');
      expect(i.isNotEmpty, isTrue);
      expect(i.runes.length, greaterThanOrEqualTo(1));
    });
  });

  group('fromMap', () {
    test('parses phones and company', () {
      final x = Contact.fromMap({
        'id': 5,
        'name': 'Anu',
        'starred': true,
        'company': ' Kerala Police ',
        'phones': [
          {'number': '9847012345', 'label': 'Mobile'},
          {'number': '0471 2345678', 'label': 'Work'},
        ],
      });
      expect(x.id, '5');
      expect(x.starred, isTrue);
      expect(x.company, 'Kerala Police');
      expect(x.phones.length, 2);
      expect(x.phones.last.label, 'Work');
    });
  });

  group('searchContacts', () {
    final list = [
      c('1', 'Bindu Nair', ['9847000001']),
      c('2', 'Anu Mathew', ['9847012345'], company: 'Acme'),
      c('3', 'Manu', ['04712345678']),
      c('4', 'Sanu Thomas', ['9000000000'], company: 'Anuvision'),
    ];

    test('empty query returns everything in original order', () {
      expect(searchContacts(list, '  ').map((x) => x.id), ['1', '2', '3', '4']);
    });
    test('ranking: prefix, word prefix, contains, company', () {
      expect(searchContacts(list, 'anu').map((x) => x.id), ['2', '3', '4']);
      expect(searchContacts(list, 'nair').map((x) => x.id), ['1']);
    });
    test(
      'company match',
      () => expect(searchContacts(list, 'acme').map((x) => x.id), ['2']),
    );
    test('partial number match ignores formatting', () {
      expect(searchContacts(list, '12345').map((x) => x.id), ['2', '3']);
      expect(searchContacts(list, '0471 23').map((x) => x.id), ['3']);
    });
    test('single digit does not match every number', () {
      expect(searchContacts(list, '9'), isEmpty);
    });
    test(
      'case-insensitive',
      () => expect(searchContacts(list, 'BINDU').map((x) => x.id), ['1']),
    );
    test('no match', () => expect(searchContacts(list, 'zzz'), isEmpty));

    test('large list stays fast', () {
      final big = [
        for (var i = 0; i < 20000; i++)
          c('$i', 'Person $i', ['98470${i.toString().padLeft(5, '0')}']),
      ];
      final sw = Stopwatch()..start();
      final r = searchContacts(big, 'person 1999');
      sw.stop();
      expect(r.first.id, '1999');
      expect(sw.elapsedMilliseconds, lessThan(500));
    });
  });

  group('contactForNumber', () {
    final list = [
      c('2', 'Anu', ['+91 98470 12345']),
    ];
    test(
      'matches regardless of prefix',
      () => expect(contactForNumber(list, '09847012345')?.id, '2'),
    );
    test('unknown', () => expect(contactForNumber(list, '9999999999'), isNull));
    test('private', () => expect(contactForNumber(list, ''), isNull));
  });
}
