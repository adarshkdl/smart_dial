import 'package:flutter/material.dart';

import '../domain/sim.dart';
import '../l10n/app_localizations.dart';
import '../state/app_controller.dart';

/// SIM picker with an optional "remember for this number" checkbox.
Future<SimChoice?> showSimPicker(
  BuildContext context,
  List<PhoneAccount> accounts, {
  bool offerRemember = true,
}) {
  final l = AppLocalizations.of(context);
  var remember = false;
  return showModalBottomSheet<SimChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l.chooseSim,
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
              ),
              for (final a in accounts)
                ListTile(
                  key: ValueKey('sim-${a.id}'),
                  leading: CircleAvatar(child: Text('${a.slot + 1}')),
                  title: Text(a.label),
                  onTap: () =>
                      Navigator.of(ctx).pop(SimChoice(a, remember: remember)),
                ),
              if (offerRemember)
                CheckboxListTile(
                  key: const ValueKey('sim-remember'),
                  value: remember,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(l.rememberSim),
                  onChanged: (v) => setSheet(() => remember = v ?? false),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}

void _report(
  BuildContext context,
  ScaffoldMessengerState? messenger,
  PlaceCallOutcome outcome,
) {
  final l = AppLocalizations.of(context);
  final msg = switch (outcome) {
    PlaceCallOutcome.invalidNumber => l.errorInvalidNumber,
    PlaceCallOutcome.permissionDenied => l.errorCallPermission,
    PlaceCallOutcome.failed => l.errorCallFailed,
    _ => null,
  };
  if (msg != null) {
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// Places a call and reports failures in a SnackBar. Returns the outcome for callers/tests.
Future<PlaceCallOutcome> callNumber(BuildContext context, String number) async {
  final controller = AppScope.read(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final outcome = await controller.placeCall(
    number,
    chooseSim: (accs) => showSimPicker(
      context,
      accs,
      offerRemember: controller.settings.rememberSimPerContact,
    ),
  );
  if (context.mounted) _report(context, messenger, outcome);
  return outcome;
}

Future<PlaceCallOutcome> callVoicemail(BuildContext context) async {
  final controller = AppScope.read(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final outcome = await controller.callVoicemail(
    chooseSim: (accs) => showSimPicker(context, accs, offerRemember: false),
  );
  if (context.mounted) _report(context, messenger, outcome);
  return outcome;
}

void showSnack(BuildContext context, String message) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(content: Text(message)));
}
