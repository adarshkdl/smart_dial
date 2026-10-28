/// T9 (keypad-letter) contact matching and ranking. Pure Dart.
///
/// Ranking rules (lower tier wins; see test/domain/t9_test.dart):
///   0. name prefix from the first word        ("268" → "Anu Mathew"; "2686" runs into "Mathew")
///   1. prefix starting at a later word         ("628" → "Anu Mathew")
///   2. initials prefix (≥2 digits)             ("26"  → "A"nu "M"athew when no tier-0 hit)
///   3. phone number prefix (also without +91/0)
///   4. name contains, mid-word (≥3 digits)
///   5. phone number contains (≥3 digits)
/// Ties: higher call frequency, then starred, then name A→Z, then original order.
///
/// Names in scripts without keypad letters (e.g. Malayalam) cannot match by name;
/// their numbers still match.
library;

import 'contact.dart';
import 'phone_number.dart';

const Map<String, String> _letterToDigit = {
  'a': '2', 'b': '2', 'c': '2', 'd': '3', 'e': '3', 'f': '3',
  'g': '4', 'h': '4', 'i': '4', 'j': '5', 'k': '5', 'l': '5',
  'm': '6', 'n': '6', 'o': '6', 'p': '7', 'q': '7', 'r': '7', 's': '7',
  't': '8', 'u': '8', 'v': '8', 'w': '9', 'x': '9', 'y': '9', 'z': '9',
  // Common accented Latin letters.
  'á': '2', 'à': '2', 'â': '2', 'ä': '2', 'ã': '2', 'å': '2', 'ç': '2',
  'é': '3',
  'è': '3',
  'ê': '3',
  'ë': '3',
  'í': '4',
  'ì': '4',
  'î': '4',
  'ï': '4',
  'ñ': '6', 'ó': '6', 'ò': '6', 'ô': '6', 'ö': '6', 'õ': '6',
  'ú': '8', 'ù': '8', 'û': '8', 'ü': '8', 'ý': '9', 'ÿ': '9',
};

/// Keypad digit for a character, or null when it has none (spaces, punctuation, other scripts).
String? t9Digit(String ch) {
  final c = ch.toLowerCase();
  if (c.length == 1 && c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39) {
    return c;
  }
  return _letterToDigit[c];
}

/// "Anu Mathew" → "26862839".
String toT9(String text) {
  final b = StringBuffer();
  for (final ch in text.split('')) {
    final d = t9Digit(ch);
    if (d != null) b.write(d);
  }
  return b.toString();
}

class _Entry {
  _Entry(this.contact, this.order);
  final Contact contact;
  final int order;

  /// T9 digits of the whole name and, for each digit, the char index in [Contact.name].
  String digits = '';
  List<int> charIdx = const [];

  /// Positions in [digits] where a word starts.
  List<int> wordStarts = const [];
  String initials = '';
  List<int> initialsCharIdx = const [];

  /// (phone, digit variants: full, without country code / trunk 0)
  List<(ContactPhone, List<String>)> phones = const [];
  String nameKey = '';
}

class T9Match {
  const T9Match({
    required this.contact,
    required this.tier,
    this.nameHighlight = const {},
    this.phone,
    this.phoneHighlight,
  });

  final Contact contact;
  final int tier;

  /// Char indices of [Contact.name] to highlight.
  final Set<int> nameHighlight;

  /// The number to dial for this match (the matching one, or the first).
  final ContactPhone? phone;

  /// (start, end) of matching digits within the digits of [phone].
  final (int, int)? phoneHighlight;

  bool get matchedNumber => tier == 3 || tier == 5;
}

/// Precomputed index; build once per contact list (O(total name length)).
class T9Index {
  T9Index(List<Contact> contacts) {
    for (var i = 0; i < contacts.length; i++) {
      final c = contacts[i];
      final e = _Entry(c, i)..nameKey = c.name.toLowerCase();
      final digits = StringBuffer();
      final idx = <int>[];
      final starts = <int>[];
      final initials = StringBuffer();
      final initIdx = <int>[];
      var inWord = false;
      final chars = c.name.split('');
      for (var j = 0; j < chars.length; j++) {
        final d = t9Digit(chars[j]);
        final isSeparator =
            chars[j].trim().isEmpty || '-_.,()&/'.contains(chars[j]);
        if (d == null) {
          // Apostrophes etc. don't break a word; whitespace and separators do.
          if (isSeparator) inWord = false;
          continue;
        }
        if (!inWord) {
          starts.add(digits.length);
          initials.write(d);
          initIdx.add(j);
          inWord = true;
        }
        digits.write(d);
        idx.add(j);
      }
      e
        ..digits = digits.toString()
        ..charIdx = idx
        ..wordStarts = starts
        ..initials = initials.toString()
        ..initialsCharIdx = initIdx
        ..phones = [
          for (final p in c.phones)
            (p, _numberVariants(PhoneNumbers.digitsOnly(p.number))),
        ];
      _entries.add(e);
    }
  }

  final List<_Entry> _entries = [];

  int get length => _entries.length;

  static List<String> _numberVariants(String d) {
    final out = <String>[d];
    if (d.startsWith('91') && d.length == 12) out.add(d.substring(2));
    if (d.startsWith('1') && d.length == 11) out.add(d.substring(1));
    if (d.startsWith('0') && d.length > 6) out.add(d.substring(1));
    return out;
  }

  /// [query] is what's on the keypad. Non-digit queries (+, *, #) only match numbers.
  /// [frequency] maps contact id → score (higher = called more).
  List<T9Match> search(
    String query, {
    Map<String, double> frequency = const {},
    int limit = 50,
  }) {
    final q = PhoneNumbers.digitsOnly(query);
    if (q.isEmpty) return const [];
    final allowNames = !query.contains(RegExp(r'[+*#]'));

    // Typed "+91 98470…" / "098470…" should also find numbers saved without the prefix.
    final qNumbers = <String>[q];
    if (query.trim().startsWith('+91') && q.length > 2) {
      qNumbers.add(q.substring(2));
    }
    if (query.trim().startsWith('+1') && q.length > 1) {
      qNumbers.add(q.substring(1));
    }
    if (q.startsWith('0') && q.length > 1) qNumbers.add(q.substring(1));

    final found = <(T9Match, _Entry)>[];
    for (final e in _entries) {
      final m = _match(e, q, qNumbers, allowNames);
      if (m != null) found.add((m, e));
    }
    found.sort((a, b) {
      final t = a.$1.tier.compareTo(b.$1.tier);
      if (t != 0) return t;
      final fa = frequency[a.$2.contact.id] ?? 0,
          fb = frequency[b.$2.contact.id] ?? 0;
      if (fa != fb) return fb.compareTo(fa);
      if (a.$2.contact.starred != b.$2.contact.starred) {
        return a.$2.contact.starred ? -1 : 1;
      }
      final n = a.$2.nameKey.compareTo(b.$2.nameKey);
      if (n != 0) return n;
      return a.$2.order.compareTo(b.$2.order);
    });
    return [for (final f in found.take(limit)) f.$1];
  }

  T9Match? _match(_Entry e, String q, List<String> qNumbers, bool allowNames) {
    final c = e.contact;
    final firstPhone = c.phones.isEmpty ? null : c.phones.first;

    if (allowNames && e.digits.isNotEmpty) {
      // Tier 0 / 1: prefix at a word start (may run across following words).
      for (var w = 0; w < e.wordStarts.length; w++) {
        final s = e.wordStarts[w];
        if (e.digits.startsWith(q, s)) {
          return T9Match(
            contact: c,
            tier: w == 0 ? 0 : 1,
            nameHighlight: {
              for (var k = s; k < s + q.length; k++) e.charIdx[k],
            },
            phone: firstPhone,
          );
        }
      }
      // Tier 2: initials.
      if (q.length >= 2 && e.initials.startsWith(q)) {
        return T9Match(
          contact: c,
          tier: 2,
          nameHighlight: {
            for (var k = 0; k < q.length; k++) e.initialsCharIdx[k],
          },
          phone: firstPhone,
        );
      }
    }

    // Tier 3: number prefix.
    for (final (p, variants) in e.phones) {
      for (final v in variants) {
        for (final qn in qNumbers) {
          if (v.startsWith(qn)) {
            final offset = variants.first.length - v.length;
            return T9Match(
              contact: c,
              tier: 3,
              phone: p,
              phoneHighlight: (offset, offset + qn.length),
            );
          }
        }
      }
    }

    if (q.length < 3) return null;

    // Tier 4: name contains.
    if (allowNames) {
      final at = e.digits.indexOf(q);
      if (at >= 0) {
        return T9Match(
          contact: c,
          tier: 4,
          nameHighlight: {
            for (var k = at; k < at + q.length; k++) e.charIdx[k],
          },
          phone: firstPhone,
        );
      }
    }

    // Tier 5: number contains.
    for (final (p, variants) in e.phones) {
      for (final qn in qNumbers) {
        if (qn.length < 3) continue;
        final at = variants.first.indexOf(qn);
        if (at >= 0) {
          return T9Match(
            contact: c,
            tier: 5,
            phone: p,
            phoneHighlight: (at, at + qn.length),
          );
        }
      }
    }
    return null;
  }
}
