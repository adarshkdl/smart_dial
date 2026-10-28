/// Phone number helpers. Pure Dart — no Flutter or platform dependencies.
library;

enum NumberValidation {
  ok,
  empty,
  invalidCharacters,
  misplacedPlus,
  tooShort,
  tooLong,
}

class PhoneNumbers {
  PhoneNumbers._();

  static final RegExp _formatting = RegExp(r'[\s\-(). /]');
  static final RegExp _allowedRaw = RegExp(r'^[0-9*#+,;\s\-(). /]*$');

  /// Emergency numbers by ISO country. Used only so validation never blocks them —
  /// routing is always left to Android Telecom.
  static const Map<String, Set<String>> _emergencyByCountry = {
    'IN': {'100', '101', '102', '108', '112', '1091', '1098'},
    'US': {'911'},
    'CA': {'911'},
    'GB': {'999', '112'},
    'AU': {'000', '112'},
  };
  static const Set<String> _globalEmergency = {'112', '911'};

  /// Strips visual formatting. Keeps digits, `*`, `#`, pause/wait (`,` `;`) and a
  /// single leading `+`.
  static String normalize(String raw) {
    final stripped = raw.replaceAll(_formatting, '');
    final buf = StringBuffer();
    for (var i = 0; i < stripped.length; i++) {
      final c = stripped[i];
      if (c == '+') {
        if (buf.isEmpty) buf.write(c);
      } else if ('0123456789*#,;'.contains(c)) {
        buf.write(c);
      }
    }
    return buf.toString();
  }

  static String digitsOnly(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

  static bool isEmergency(String raw, {String countryIso = ''}) {
    final n = normalize(raw);
    if (n.isEmpty || n.contains(RegExp(r'[*#+,;]'))) return false;
    return _globalEmergency.contains(n) ||
        (_emergencyByCountry[countryIso.toUpperCase()]?.contains(n) ?? false);
  }

  /// USSD / MMI codes such as `*123#` or `*#06#`.
  static bool isServiceCode(String raw) {
    final n = normalize(raw);
    return n.length >= 2 &&
        (n.startsWith('*') || n.startsWith('#')) &&
        n.endsWith('#');
  }

  static NumberValidation validate(String raw, {String countryIso = ''}) {
    if (raw.trim().isEmpty) return NumberValidation.empty;
    if (!_allowedRaw.hasMatch(raw)) return NumberValidation.invalidCharacters;
    final stripped = raw.replaceAll(_formatting, '');
    if (stripped.lastIndexOf('+') > 0) return NumberValidation.misplacedPlus;
    if (isEmergency(raw, countryIso: countryIso) || isServiceCode(raw)) {
      return NumberValidation.ok;
    }
    final digits = digitsOnly(stripped.split(RegExp(r'[,;]')).first);
    if (digits.length < 3) return NumberValidation.tooShort;
    if (digits.length > 17) return NumberValidation.tooLong;
    return NumberValidation.ok;
  }

  /// Display formatting while typing and in lists. Unknown patterns are returned
  /// normalized but otherwise untouched (never "corrects" what the user typed).
  static String format(String raw, {String countryIso = ''}) {
    final n = normalize(raw);
    if (n.isEmpty || n.contains(RegExp(r'[*#,;]'))) return n;
    final cc = countryIso.toUpperCase();

    if (n.startsWith('+91') || (cc == 'IN' && !n.startsWith('+'))) {
      return _formatIndia(n);
    }
    if (n.startsWith('+1') ||
        ((cc == 'US' || cc == 'CA') && !n.startsWith('+'))) {
      return _formatNanp(n);
    }
    return n;
  }

  static String _formatIndia(String n) {
    if (n.startsWith('+91')) {
      final rest = n.substring(3);
      if (rest.isEmpty) return '+91';
      return '+91 ${_group55(rest)}';
    }
    if (n.startsWith('0') && n.length > 1 && n.length <= 11) {
      return '0${_group55(n.substring(1))}';
    }
    if (n.length <= 10) return _group55(n);
    return n;
  }

  static String _group55(String d) {
    if (d.length <= 5 || d.length > 10) return d;
    return '${d.substring(0, 5)} ${d.substring(5)}';
  }

  static String _formatNanp(String n) {
    var prefix = '';
    var d = n;
    if (n.startsWith('+1')) {
      prefix = '+1 ';
      d = n.substring(2);
      if (d.isEmpty) return '+1';
    } else if (n.startsWith('1') && n.length == 11) {
      prefix = '1 ';
      d = n.substring(1);
    }
    if (d.length > 10) return n;
    if (d.length <= 3) return '$prefix$d'.trim();
    if (d.length <= 6) return '$prefix(${d.substring(0, 3)}) ${d.substring(3)}';
    return '$prefix(${d.substring(0, 3)}) ${d.substring(3, 6)}-${d.substring(6)}';
  }

  /// Loose equality used for grouping and caller matching: compares the trailing
  /// 10 digits when both numbers are long enough, otherwise exact normalized match.
  static bool sameNumber(String a, String b) {
    final da = digitsOnly(a), db = digitsOnly(b);
    if (da.isEmpty || db.isEmpty) {
      return normalize(a) == normalize(b) && normalize(a).isNotEmpty;
    }
    if (da.length >= 7 && db.length >= 7) {
      String tail(String s) => s.length > 10 ? s.substring(s.length - 10) : s;
      return tail(da) == tail(db);
    }
    return da == db;
  }

  /// Android reports withheld / unknown numbers as empty or negative-presentation values.
  static bool isPrivate(String raw) {
    final n = raw.trim();
    return n.isEmpty || n == '-1' || n == '-2' || n == '-3';
  }
}
