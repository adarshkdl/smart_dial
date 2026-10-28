import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/phone_number.dart';
import '../domain/reminder.dart';
import '../l10n/app_localizations.dart';
import '../state/app_controller.dart';
import 'call_actions.dart';
import 'widgets/contact_avatar.dart';
import 'widgets/state_views.dart';

String formatReminderTime(BuildContext context, DateTime t) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final l = AppLocalizations.of(context);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final time = DateFormat.jm(locale).format(t);
  if (day == today) return '${l.today}, $time';
  if (day == today.add(const Duration(days: 1))) return '${l.tomorrow}, $time';
  if (day == today.subtract(const Duration(days: 1))) {
    return '${l.yesterday}, $time';
  }
  return '${DateFormat.MMMEd(locale).format(t)}, $time';
}

/// Quick options + custom date/time. Returns null when dismissed.
Future<DateTime?> pickReminderTime(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final now = DateTime.now();
  final options = <(QuickReminder, String)>[
    (QuickReminder.in15Minutes, l.remindIn15),
    (QuickReminder.in1Hour, l.remindIn1h),
    (QuickReminder.thisEvening, l.remindThisEvening),
    (QuickReminder.tomorrowMorning, l.remindTomorrowMorning),
  ];
  final choice = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l.remindMe,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
            ),
            for (final (q, label) in options)
              if (quickReminderTime(q, now) case final t?)
                ListTile(
                  key: ValueKey('remind-${q.name}'),
                  leading: const Icon(Icons.alarm),
                  title: Text(label),
                  subtitle: Text(formatReminderTime(ctx, t)),
                  onTap: () => Navigator.pop(ctx, t),
                ),
            ListTile(
              key: const ValueKey('remind-custom'),
              leading: const Icon(Icons.edit_calendar_outlined),
              title: Text(l.pickDateTime),
              onTap: () => Navigator.pop(ctx, 'custom'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
  if (choice is DateTime) return choice;
  if (choice != 'custom' || !context.mounted) return null;
  final date = await showDatePicker(
    context: context,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 365)),
    initialDate: now,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
  );
  if (time == null) return null;
  final picked = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
  // A time already in the past today fires right away — nudge it a minute ahead.
  return picked.isBefore(now) ? now.add(const Duration(minutes: 1)) : picked;
}

/// "Remind me to call …" flow used from Recents, contact details and the call-ended state.
Future<void> remindToCall(
  BuildContext context, {
  required String number,
  String? name,
}) async {
  final l = AppLocalizations.of(context);
  final c = AppScope.read(context);
  final t = await pickReminderTime(context);
  if (t == null || !context.mounted) return;
  final canNotify = await c.addReminder(number: number, name: name, dueAt: t);
  if (!context.mounted) return;
  showSnack(
    context,
    canNotify
        ? l.reminderSetFor(formatReminderTime(context, t))
        : l.reminderNoNotifications,
  );
}

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = AppScope.of(context);
    final now = DateTime.now();
    final list = c.reminders;
    final iso = c.countryIso;

    return Scaffold(
      appBar: AppBar(title: Text(l.reminders)),
      body: Column(
        children: [
          if (!c.exactAlarms && c.pendingReminderCount > 0)
            MaterialBanner(
              key: const ValueKey('exact-alarm-banner'),
              leading: const Icon(Icons.timer_outlined),
              content: Text(l.exactAlarmHint),
              actions: [
                TextButton(
                  onPressed: c.openExactAlarmSettings,
                  child: Text(l.allowExactAlarms),
                ),
              ],
            ),
          Expanded(
            child: list.isEmpty
                ? EmptyView(icon: Icons.alarm_off, message: l.noReminders)
                : RefreshIndicator(
                    onRefresh: c.refreshReminders,
                    child: ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final r = list[i];
                        final overdue = r.isOverdue(now);
                        final who =
                            r.name ??
                            PhoneNumbers.format(r.number, countryIso: iso);
                        final theme = Theme.of(context);
                        return Dismissible(
                          key: ValueKey('reminder-${r.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: theme.colorScheme.errorContainer,
                            alignment: AlignmentDirectional.centerEnd,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Icon(
                              Icons.delete_outline,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          onDismissed: (_) => c.deleteReminder(r),
                          child: ListTile(
                            leading: ContactAvatar(name: r.name ?? ''),
                            title: Text(
                              who,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: r.done
                                  ? const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                    )
                                  : null,
                            ),
                            subtitle: Text(
                              [
                                if (overdue) l.overdue,
                                formatReminderTime(context, r.dueAt),
                                if (r.note != null) r.note!,
                              ].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: overdue
                                  ? TextStyle(color: theme.colorScheme.error)
                                  : null,
                            ),
                            onTap: r.done
                                ? null
                                : () async {
                                    final outcome = await callNumber(
                                      context,
                                      r.number,
                                    );
                                    if (outcome == PlaceCallOutcome.placed) {
                                      await c.setReminderDone(r, true);
                                    }
                                  },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  key: ValueKey('reminder-done-${r.id}'),
                                  value: r.done,
                                  semanticLabel: l.reminderDone,
                                  onChanged: (v) =>
                                      c.setReminderDone(r, v ?? false),
                                ),
                                IconButton(
                                  key: ValueKey('reminder-delete-${r.id}'),
                                  tooltip: l.delete,
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => c.deleteReminder(r),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
