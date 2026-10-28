import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Consistent loading / empty / error / permission states (spec §3.9).
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    this.body,
    this.actions = const [],
  });
  final IconData icon;
  final String title;
  final String? body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) =>
      _CenteredMessage(icon: icon, title: message);
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _CenteredMessage(
      icon: Icons.error_outline,
      title: l.errorLoading,
      actions: [FilledButton.tonal(onPressed: onRetry, child: Text(l.retry))],
    );
  }
}

class PermissionView extends StatelessWidget {
  const PermissionView({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.needsSettings,
    required this.onGrant,
    required this.onOpenSettings,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool needsSettings;
  final VoidCallback onGrant;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _CenteredMessage(
      icon: icon,
      title: title,
      body: needsSettings ? '$body\n\n${l.permissionSettingsHint}' : body,
      actions: [
        if (needsSettings)
          FilledButton(onPressed: onOpenSettings, child: Text(l.openSettings))
        else
          FilledButton(onPressed: onGrant, child: Text(l.allowAccess)),
      ],
    );
  }
}
