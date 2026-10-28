import 'package:characters/characters.dart';

import 'phone_number.dart';

class ContactPhone {
  const ContactPhone(this.number, {this.label = ''});
  final String number;
  final String label;
}

class Contact {
  const Contact({
    required this.id,
    required this.name,
    this.phones = const [],
    this.photoUri,
    this.starred = false,
    this.company,
  });

  final String id;
  final String name;
  final List<ContactPhone> phones;
  final String? photoUri;
  final bool starred;
  final String? company;

  String get initials => initialsFor(name);

  Contact copyWith({bool? starred}) => Contact(
    id: id,
    name: name,
    phones: phones,
    photoUri: photoUri,
    starred: starred ?? this.starred,
    company: company,
  );

  factory Contact.fromMap(Map<Object?, Object?> m) => Contact(
    id: '${m['id']}',
    name: (m['name'] as String?) ?? '',
    photoUri: m['photoUri'] as String?,
    starred: m['starred'] == true,
    company: (m['company'] as String?)?.trim().isEmpty ?? true
        ? null
        : (m['company'] as String).trim(),
    phones: [
      for (final p in (m['phones'] as List<Object?>? ?? const []))
        if (p is Map)
          ContactPhone('${p['number']}', label: (p['label'] as String?) ?? ''),
    ],
  );
}

/// Up to two leading graphemes (works for Malayalam conjuncts), `#` when no letter.
String initialsFor(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '#';
  final letters = <String>[];
  for (final w in words) {
    final first = w.characters.first;
    if (RegExp(r'[0-9+*#()\-]').hasMatch(first)) continue;
    letters.add(first.toUpperCase());
    if (letters.length == 2) break;
  }
  return letters.isEmpty ? '#' : letters.join();
}

/// Plain (non-T9) search over name, company and phone digits.
/// Ranking: name prefix > word prefix > name contains > company > number.
List<Contact> searchContacts(List<Contact> contacts, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return contacts;
  final qDigits = PhoneNumbers.digitsOnly(q);
  final numericQuery =
      qDigits.isNotEmpty &&
      qDigits.length == q.replaceAll(RegExp(r'[\s+\-()]'), '').length;

  int score(Contact c) {
    final name = c.name.toLowerCase();
    if (name.startsWith(q)) return 0;
    if (name.split(RegExp(r'\s+')).any((w) => w.startsWith(q))) return 1;
    if (name.contains(q)) return 2;
    if ((c.company ?? '').toLowerCase().contains(q)) return 3;
    if (numericQuery &&
        qDigits.length >= 2 &&
        c.phones.any(
          (p) => PhoneNumbers.digitsOnly(p.number).contains(qDigits),
        )) {
      return 4;
    }
    return -1;
  }

  final scored = <(int, int, Contact)>[];
  for (var i = 0; i < contacts.length; i++) {
    final s = score(contacts[i]);
    if (s >= 0) scored.add((s, i, contacts[i]));
  }
  scored.sort(
    (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
  );
  return [for (final s in scored) s.$3];
}

/// Finds the saved contact for a number (used to label recents and calls).
Contact? contactForNumber(List<Contact> contacts, String number) {
  if (PhoneNumbers.isPrivate(number)) return null;
  for (final c in contacts) {
    if (c.phones.any((p) => PhoneNumbers.sameNumber(p.number, number))) {
      return c;
    }
  }
  return null;
}
