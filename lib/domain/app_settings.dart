/// App-owned preferences (the only data Smart Dial itself stores). Kept on-device in
/// app-private storage with backup disabled; clearable from Settings.
library;

import 'dart:convert';

import 'phone_number.dart';

enum ThemePreference { system, light, dark }

enum KeypadSize { compact, normal, large }

enum AppLanguage {
  system(null),
  english('en'),
  malayalam('ml');

  const AppLanguage(this.localeCode);

  /// null = follow the device language.
  final String? localeCode;
}

/// Accent seed colours (ARGB). `dynamic` uses the Android 12+ wallpaper colour.
enum AccentColor {
  teal(0xFF00796B),
  blue(0xFF1565C0),
  indigo(0xFF3949AB),
  purple(0xFF7B1FA2),
  pink(0xFFC2185B),
  orange(0xFFEF6C00),
  green(0xFF2E7D32),
  dynamic(0);

  const AccentColor(this.argb);
  final int argb;
}

class SpeedDialEntry {
  const SpeedDialEntry({required this.number, this.name});
  final String number;
  final String? name;

  Map<String, Object?> toJson() => {
    'number': number,
    if (name != null) 'name': name,
  };
  static SpeedDialEntry? fromJson(Object? j) {
    if (j is! Map || j['number'] is! String) return null;
    return SpeedDialEntry(
      number: j['number'] as String,
      name: j['name'] as String?,
    );
  }
}

class AppSettings {
  const AppSettings({
    this.theme = ThemePreference.system,
    this.accent = AccentColor.teal,
    this.keypadSize = KeypadSize.normal,
    this.keypadTones = true,
    this.keypadHaptics = true,
    this.t9Suggestions = true,
    this.rememberSimPerContact = true,
    this.favoriteShortcuts = true,
    this.speedDial = const {},
    this.simByNumber = const {},
    this.language = AppLanguage.system,
  });

  static const current = 1;
  static const defaults = AppSettings();

  /// Keys 2–9. Key 1 is reserved for voicemail.
  static const speedDialKeys = [2, 3, 4, 5, 6, 7, 8, 9];

  final ThemePreference theme;
  final AccentColor accent;
  final KeypadSize keypadSize;
  final bool keypadTones;
  final bool keypadHaptics;
  final bool t9Suggestions;
  final bool rememberSimPerContact;
  final bool favoriteShortcuts;
  final Map<int, SpeedDialEntry> speedDial;

  /// Last-10-digit number key → phone account id.
  final Map<String, String> simByNumber;

  /// App language; system follows the device.
  final AppLanguage language;

  static String numberKey(String number) {
    final d = PhoneNumbers.digitsOnly(number);
    return d.length > 10 ? d.substring(d.length - 10) : d;
  }

  String? simFor(String number) =>
      rememberSimPerContact ? simByNumber[numberKey(number)] : null;

  double get keypadScale => switch (keypadSize) {
    KeypadSize.compact => 0.82,
    KeypadSize.normal => 1.0,
    KeypadSize.large => 1.18,
  };

  AppSettings copyWith({
    ThemePreference? theme,
    AccentColor? accent,
    KeypadSize? keypadSize,
    bool? keypadTones,
    bool? keypadHaptics,
    bool? t9Suggestions,
    bool? rememberSimPerContact,
    bool? favoriteShortcuts,
    Map<int, SpeedDialEntry>? speedDial,
    Map<String, String>? simByNumber,
    AppLanguage? language,
  }) => AppSettings(
    theme: theme ?? this.theme,
    accent: accent ?? this.accent,
    keypadSize: keypadSize ?? this.keypadSize,
    keypadTones: keypadTones ?? this.keypadTones,
    keypadHaptics: keypadHaptics ?? this.keypadHaptics,
    t9Suggestions: t9Suggestions ?? this.t9Suggestions,
    rememberSimPerContact: rememberSimPerContact ?? this.rememberSimPerContact,
    favoriteShortcuts: favoriteShortcuts ?? this.favoriteShortcuts,
    speedDial: speedDial ?? this.speedDial,
    simByNumber: simByNumber ?? this.simByNumber,
    language: language ?? this.language,
  );

  AppSettings withSpeedDial(int key, SpeedDialEntry? entry) {
    assert(speedDialKeys.contains(key));
    final m = {...speedDial};
    if (entry == null) {
      m.remove(key);
    } else {
      m[key] = entry;
    }
    return copyWith(speedDial: m);
  }

  AppSettings withSimFor(String number, String accountId) =>
      copyWith(simByNumber: {...simByNumber, numberKey(number): accountId});

  Map<String, Object?> toJson() => {
    'version': current,
    'theme': theme.name,
    'accent': accent.name,
    'keypadSize': keypadSize.name,
    'keypadTones': keypadTones,
    'keypadHaptics': keypadHaptics,
    't9Suggestions': t9Suggestions,
    'rememberSimPerContact': rememberSimPerContact,
    'favoriteShortcuts': favoriteShortcuts,
    'speedDial': {
      for (final e in speedDial.entries) '${e.key}': e.value.toJson(),
    },
    'simByNumber': simByNumber,
    'language': language.name,
  };

  String encode() => jsonEncode(toJson());

  /// Tolerant decoding: unknown / corrupt values fall back to defaults, never throw.
  static AppSettings decode(String? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    Object? j;
    try {
      j = jsonDecode(raw);
    } on FormatException {
      return defaults;
    }
    if (j is! Map) return defaults;
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return fallback;
    }

    bool flag(String k, bool d) => j is Map && j[k] is bool ? j[k] as bool : d;

    final sd = <int, SpeedDialEntry>{};
    final rawSd = j['speedDial'];
    if (rawSd is Map) {
      rawSd.forEach((k, v) {
        final key = int.tryParse('$k');
        final entry = SpeedDialEntry.fromJson(v);
        if (key != null && speedDialKeys.contains(key) && entry != null) {
          sd[key] = entry;
        }
      });
    }
    final sims = <String, String>{};
    final rawSims = j['simByNumber'];
    if (rawSims is Map) {
      rawSims.forEach((k, v) {
        if (v is String) sims['$k'] = v;
      });
    }
    return AppSettings(
      theme: pick(ThemePreference.values, j['theme'], defaults.theme),
      accent: pick(AccentColor.values, j['accent'], defaults.accent),
      keypadSize: pick(KeypadSize.values, j['keypadSize'], defaults.keypadSize),
      keypadTones: flag('keypadTones', defaults.keypadTones),
      keypadHaptics: flag('keypadHaptics', defaults.keypadHaptics),
      t9Suggestions: flag('t9Suggestions', defaults.t9Suggestions),
      rememberSimPerContact: flag(
        'rememberSimPerContact',
        defaults.rememberSimPerContact,
      ),
      favoriteShortcuts: flag('favoriteShortcuts', defaults.favoriteShortcuts),
      speedDial: sd,
      simByNumber: sims,
      language: pick(AppLanguage.values, j['language'], defaults.language),
    );
  }
}
