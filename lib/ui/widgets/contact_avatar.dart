import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/contact.dart';
import '../../state/app_controller.dart';

/// Photo when available, otherwise initials on a stable per-name color.
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({
    super.key,
    required this.name,
    this.photoUri,
    this.radius = 20,
  });

  final String name;
  final String? photoUri;
  final double radius;

  static final Map<String, Future<Uint8List?>> _cache = {};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = [
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.tertiaryContainer,
    ];
    final onPalette = [
      scheme.onPrimaryContainer,
      scheme.onSecondaryContainer,
      scheme.onTertiaryContainer,
    ];
    final i = name.isEmpty
        ? 0
        : name.codeUnits.fold<int>(0, (a, b) => a + b) % palette.length;

    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: palette[i],
      child: name.trim().isEmpty
          ? Icon(Icons.person, color: onPalette[i], size: radius)
          : Text(
              initialsFor(name),
              style: TextStyle(
                color: onPalette[i],
                fontWeight: FontWeight.w600,
                fontSize: radius * 0.7,
              ),
            ),
    );

    final uri = photoUri;
    if (uri == null) return ExcludeSemantics(child: fallback);
    final future = _cache.putIfAbsent(
      uri,
      () => AppScope.read(
        context,
      ).platform.loadPhoto(uri).catchError((_) => null),
    );
    return ExcludeSemantics(
      child: FutureBuilder<Uint8List?>(
        future: future,
        builder: (context, snap) {
          final bytes = snap.data;
          if (bytes == null || bytes.isEmpty) return fallback;
          return CircleAvatar(
            radius: radius,
            backgroundImage: MemoryImage(bytes),
          );
        },
      ),
    );
  }
}
