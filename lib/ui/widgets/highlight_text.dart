import 'package:flutter/material.dart';

/// Text with selected character indices emphasised (T9 matches).
class HighlightText extends StatelessWidget {
  const HighlightText(
    this.text, {
    super.key,
    this.highlight = const {},
    this.style,
    this.maxLines = 1,
  });

  /// Highlights the [start, end) range of *digits* within [number], skipping formatting characters.
  factory HighlightText.digits(
    String number,
    (int, int)? range, {
    Key? key,
    TextStyle? style,
  }) {
    final set = <int>{};
    if (range != null) {
      var d = 0;
      for (var i = 0; i < number.length; i++) {
        final c = number.codeUnitAt(i);
        if (c >= 0x30 && c <= 0x39) {
          if (d >= range.$1 && d < range.$2) set.add(i);
          d++;
        }
      }
    }
    return HighlightText(number, key: key, highlight: set, style: style);
  }

  final String text;
  final Set<int> highlight;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final hl = base.copyWith(
      fontWeight: FontWeight.w800,
      color: Theme.of(context).colorScheme.primary,
    );
    final spans = <TextSpan>[];
    final buf = StringBuffer();
    bool? on;
    for (var i = 0; i < text.length; i++) {
      final h = highlight.contains(i);
      if (on != null && h != on) {
        spans.add(TextSpan(text: buf.toString(), style: on ? hl : null));
        buf.clear();
      }
      on = h;
      buf.write(text[i]);
    }
    if (buf.isNotEmpty) {
      spans.add(
        TextSpan(text: buf.toString(), style: (on ?? false) ? hl : null),
      );
    }
    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      semanticsLabel: text,
    );
  }
}
