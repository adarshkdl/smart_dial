import 'package:flutter/material.dart';

import '../domain/contact.dart';
import '../domain/phone_number.dart';
import '../l10n/app_localizations.dart';
import '../state/app_controller.dart';
import 'call_actions.dart';
import 'notes_section.dart';
import 'reminders_screen.dart' show remindToCall;
import 'widgets/contact_avatar.dart';

/// Contact details with call / message per number, star, open in Contacts and
/// add-to-home-screen. Shared by Contacts, Favorites and keypad suggestions.
Future<void> showContactSheet(BuildContext context, Contact contact) {
  final l = AppLocalizations.of(context);
  final controller = AppScope.read(context);
  final iso = controller.countryIso;
  var current = contact;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ContactAvatar(
                name: current.name,
                photoUri: current.photoUri,
                radius: 40,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  current.name,
                  style: Theme.of(ctx).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              if (current.company != null) Text(current.company!),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  TextButton.icon(
                    key: const ValueKey('star-toggle'),
                    icon: Icon(
                      current.starred ? Icons.star : Icons.star_outline,
                    ),
                    label: Text(
                      current.starred ? l.removeFavorite : l.addFavorite,
                    ),
                    onPressed: () async {
                      final ok = await controller.setStarred(
                        current,
                        !current.starred,
                      );
                      if (ok) {
                        setSheet(
                          () => current = current.copyWith(
                            starred: !current.starred,
                          ),
                        );
                      } else if (ctx.mounted) {
                        showSnack(context, l.errorFavoritePermission);
                      }
                    },
                  ),
                  TextButton.icon(
                    key: const ValueKey('open-contact'),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l.openInContacts),
                    onPressed: () => controller.openContact(current),
                  ),
                  TextButton.icon(
                    key: const ValueKey('contact-remind'),
                    icon: const Icon(Icons.alarm_add),
                    label: Text(l.remindMe),
                    onPressed: current.phones.isEmpty
                        ? null
                        : () => remindToCall(
                            context,
                            number: current.phones.first.number,
                            name: current.name,
                          ),
                  ),
                ],
              ),
              const Divider(),
              for (final p in current.phones)
                ListTile(
                  key: ValueKey('phone-${p.number}'),
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(PhoneNumbers.format(p.number, countryIso: iso)),
                  subtitle: p.label.isEmpty ? null : Text(p.label),
                  onTap: () {
                    Navigator.pop(ctx);
                    callNumber(context, p.number);
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: ValueKey('sms-${p.number}'),
                        tooltip: l.message,
                        icon: const Icon(Icons.message_outlined),
                        onPressed: () => controller.sendMessage(p.number),
                      ),
                      IconButton(
                        key: ValueKey('pin-${p.number}'),
                        tooltip: l.addToHomeScreen,
                        icon: const Icon(Icons.add_to_home_screen),
                        onPressed: () async {
                          final ok = await controller.pinShortcut(current, p);
                          if (!ok && ctx.mounted) {
                            showSnack(context, l.errorShortcut);
                          }
                        },
                      ),
                      IconButton(
                        tooltip: l.callNumberLabel(p.number),
                        icon: const Icon(Icons.call),
                        onPressed: () {
                          Navigator.pop(ctx);
                          callNumber(context, p.number);
                        },
                      ),
                    ],
                  ),
                ),
              const Divider(),
              NotesSection(numbers: [for (final p in current.phones) p.number]),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Contact + number picker (speed dial assignment). Returns null when dismissed.
Future<(Contact, ContactPhone)?> pickContactNumber(
  BuildContext context, {
  required String title,
}) async {
  final controller = AppScope.read(context);
  final l = AppLocalizations.of(context);
  final List<Contact> contacts;
  try {
    contacts = await controller.loadContacts();
  } catch (_) {
    if (context.mounted) showSnack(context, l.contactsPermissionTitle);
    return null;
  }
  if (!context.mounted) return null;
  var query = '';
  return showModalBottomSheet<(Contact, ContactPhone)>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final rows = <(Contact, ContactPhone)>[
          for (final c in searchContacts([
            for (final c in contacts)
              if (c.phones.isNotEmpty) c,
          ], query))
            for (final p in c.phones) (c, p),
        ];
        return SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  key: const ValueKey('picker-search'),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l.searchContacts,
                  ),
                  onChanged: (v) => setSheet(() => query = v),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final (c, p) = rows[i];
                    return ListTile(
                      key: ValueKey('pick-${c.id}-${p.number}'),
                      leading: ContactAvatar(
                        name: c.name,
                        photoUri: c.photoUri,
                      ),
                      title: Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [if (p.label.isNotEmpty) p.label, p.number].join(' · '),
                      ),
                      onTap: () => Navigator.pop(ctx, (c, p)),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
