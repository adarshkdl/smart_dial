import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../state/app_controller.dart';
import 'call_actions.dart';
import 'widgets/state_views.dart';

/// On-device error log (already scrubbed of numbers). Nothing is sent anywhere;
/// the user may copy it into a support message themselves.
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = AppScope.of(context);
    final entries = c.diagnostics.entries.reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(l.diagnostics),
        actions: [
          IconButton(
            key: const ValueKey('copy-report'),
            tooltip: l.copyReport,
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: c.diagnosticsReport()),
              );
              if (context.mounted) showSnack(context, l.reportCopied);
            },
          ),
          IconButton(
            key: const ValueKey('clear-diagnostics'),
            tooltip: l.clear,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: entries.isEmpty ? null : c.clearDiagnostics,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l.diagnosticsHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? EmptyView(
                    icon: Icons.check_circle_outline,
                    message: l.noDiagnostics,
                  )
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final e = entries[i];
                      return ListTile(
                        dense: true,
                        title: Text('[${e.kind}] ${e.message}'),
                        subtitle: Text(
                          e.at.toLocal().toString().split('.').first,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
