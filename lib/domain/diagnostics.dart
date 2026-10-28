/// Privacy-conscious, on-device diagnostics. Messages are scrubbed of phone numbers
/// and other long digit runs, truncated, and capped in count. Never uploaded; the user
/// can view, copy or clear them in Settings.
library;

import 'dart:convert';

final RegExp _digitRun = RegExp(r'\+?\(?\d[\d\s\-().]{3,}\d');
final RegExp _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');
final RegExp _uri = RegExp(
  r'(content|tel|smsto|file|voicemail):(//)?[^\s)]+',
  caseSensitive: false,
);

/// Removes anything that could identify a person: digit runs of 5+ (phone numbers,
/// ids), e-mail addresses and content/tel URIs.
String scrubPii(String input, {int maxLength = 300}) {
  var s = input.replaceAll(_uri, '<uri>').replaceAll(_email, '<email>');
  s = s.replaceAllMapped(_digitRun, (m) {
    final digits = m[0]!.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 5 ? '<number>' : m[0]!;
  });
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.length > maxLength ? '${s.substring(0, maxLength)}…' : s;
}

class DiagnosticEntry {
  const DiagnosticEntry({
    required this.at,
    required this.kind,
    required this.message,
  });
  final DateTime at;
  final String kind;
  final String message;

  Map<String, Object?> toJson() => {
    'at': at.millisecondsSinceEpoch,
    'kind': kind,
    'message': message,
  };

  static DiagnosticEntry? fromJson(Object? j) {
    if (j is! Map ||
        j['at'] is! int ||
        j['kind'] is! String ||
        j['message'] is! String) {
      return null;
    }
    return DiagnosticEntry(
      at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
      kind: j['kind'] as String,
      message: j['message'] as String,
    );
  }
}

class DiagnosticsLog {
  const DiagnosticsLog([this.entries = const []]);

  static const maxEntries = 100;
  static const empty = DiagnosticsLog();

  /// Newest last.
  final List<DiagnosticEntry> entries;

  DiagnosticsLog add(String kind, String message, DateTime at) {
    final e = DiagnosticEntry(
      at: at,
      kind: scrubPii(kind, maxLength: 40),
      message: scrubPii(message),
    );
    final list = [...entries, e];
    return DiagnosticsLog(
      list.length > maxEntries ? list.sublist(list.length - maxEntries) : list,
    );
  }

  /// Plain-text report for the user to copy (already scrubbed).
  String report({required String appVersion, required String platform}) {
    final b = StringBuffer('Smart Dial $appVersion · $platform\n');
    for (final e in entries.reversed) {
      b.writeln('${e.at.toIso8601String()}  [${e.kind}]  ${e.message}');
    }
    return b.toString();
  }

  String encode() => jsonEncode({
    'version': 1,
    'entries': [for (final e in entries) e.toJson()],
  });

  static DiagnosticsLog decode(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    try {
      final j = jsonDecode(raw);
      if (j is! Map || j['entries'] is! List) return empty;
      return DiagnosticsLog([
        for (final e in j['entries'] as List) ?DiagnosticEntry.fromJson(e),
      ]);
    } on FormatException {
      return empty;
    }
  }
}

/// Global hook so framework-level errors (installed in main.dart) reach the
/// controller's log without the UI depending on it.
abstract final class DiagnosticsSink {
  static void Function(String kind, String message)? handler;
  static void record(String kind, String message) =>
      handler?.call(kind, message);
}
