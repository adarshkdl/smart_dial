import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const List<(String, String)> dialKeys = [
  ('1', ''),
  ('2', 'ABC'),
  ('3', 'DEF'),
  ('4', 'GHI'),
  ('5', 'JKL'),
  ('6', 'MNO'),
  ('7', 'PQRS'),
  ('8', 'TUV'),
  ('9', 'WXYZ'),
  ('*', ''),
  ('0', '+'),
  ('#', ''),
];

/// 4×3 phone keypad that sizes itself to the space it gets (phones, tablets, large fonts).
class DialPad extends StatelessWidget {
  const DialPad({
    super.key,
    required this.onKeyTap,
    this.onKeyLongPress,
    this.onKeyDown,
    this.onKeyUp,
    this.maxKeySize = 84,
    this.haptics = true,
  });

  final ValueChanged<String> onKeyTap;

  /// Return true when the long press was handled (then no tap is emitted).
  final bool Function(String key)? onKeyLongPress;
  final ValueChanged<String>? onKeyDown;
  final VoidCallback? onKeyUp;
  final double maxKeySize;
  final bool haptics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final byWidth = c.maxWidth / 3;
        final byHeight = c.hasBoundedHeight ? c.maxHeight / 4 : maxKeySize + 8;
        final cell = byWidth < byHeight ? byWidth : byHeight;
        final key = (cell - 8).clamp(40.0, maxKeySize);
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < 4; r++)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var col = 0; col < 3; col++)
                      Padding(
                        padding: EdgeInsets.all(
                          (cell - key) / 2 > 0 ? (cell - key) / 2 : 0,
                        ),
                        child: _Key(
                          digit: dialKeys[r * 3 + col].$1,
                          letters: dialKeys[r * 3 + col].$2,
                          size: key,
                          onTap: onKeyTap,
                          onLongPress: onKeyLongPress,
                          onDown: onKeyDown,
                          onUp: onKeyUp,
                          haptics: haptics,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.digit,
    required this.letters,
    required this.size,
    required this.onTap,
    this.onLongPress,
    this.onDown,
    this.onUp,
    this.haptics = true,
  });

  final bool haptics;
  final String digit;
  final String letters;
  final double size;
  final ValueChanged<String> onTap;
  final bool Function(String)? onLongPress;
  final ValueChanged<String>? onDown;
  final VoidCallback? onUp;

  String get _semanticLabel {
    final spoken = switch (digit) {
      '*' => 'star',
      '#' => 'pound',
      _ => digit,
    };
    return letters.isEmpty ? spoken : '$spoken, ${letters.split('').join(' ')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: _semanticLabel,
      excludeSemantics: true,
      onTap: () => onTap(digit),
      child: Material(
        key: ValueKey('dialkey-$digit'),
        color: scheme.surfaceContainerHigh,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (haptics) HapticFeedback.selectionClick();
            onTap(digit);
          },
          onLongPress: onLongPress == null
              ? null
              : () {
                  if (onLongPress!(digit)) {
                    if (haptics) HapticFeedback.mediumImpact();
                  } else {
                    onTap(digit);
                  }
                },
          onTapDown: onDown == null ? null : (_) => onDown!(digit),
          onTapUp: onUp == null ? null : (_) => onUp!(),
          onTapCancel: onUp,
          child: SizedBox.square(
            dimension: size,
            child: Padding(
              padding: EdgeInsets.all(size * 0.12),
              child: FittedBox(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The asterisk glyph is drawn near the top of its line box,
                    // so nudge it down to look centred on the key.
                    Transform.translate(
                      offset: Offset(
                        0,
                        digit == '*'
                            ? (text.headlineMedium?.fontSize ?? 28) * 0.18
                            : 0,
                      ),
                      child: Text(
                        digit,
                        style: text.headlineMedium?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (letters.isNotEmpty)
                      Text(
                        letters,
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 1.5,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
