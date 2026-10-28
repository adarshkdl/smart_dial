import 'package:flutter/material.dart';

import '../domain/access_state.dart';
import '../domain/contact.dart';
import '../l10n/app_localizations.dart';
import '../platform/dialer_platform.dart';
import '../state/app_controller.dart';
import 'contact_sheet.dart';
import 'widgets/contact_avatar.dart';
import 'widgets/state_views.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

enum _Load { idle, loading, loaded, error }

class _ContactsScreenState extends State<ContactsScreen> {
  _Load _load = _Load.idle;
  List<Contact> _contacts = const [];
  String _query = '';
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = AppScope.of(context);
    if (c.access.granted(AppPermission.readContacts)) _asked = true;
    if (c.access.granted(AppPermission.readContacts) && _load == _Load.idle) {
      _reload();
    } else if (!_asked &&
        c.access.loaded &&
        c.access.access(AppPermission.readContacts) == FeatureAccess.request) {
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestPermission());
    }
  }

  Future<void> _requestPermission() async {
    final s = await AppScope.read(
      context,
    ).ensurePermission(AppPermission.readContacts);
    if (s == PermissionStatus.granted && mounted) _reload();
  }

  Future<void> _reload() async {
    if (_load == _Load.loading) return;
    final c = AppScope.read(context);
    setState(() => _load = _Load.loading);
    try {
      final list = await c.loadContacts(force: true);
      if (!mounted) return;
      setState(() {
        _contacts = list.where((x) => x.phones.isNotEmpty).toList();
        _load = _Load.loaded;
      });
    } on DialerException catch (e) {
      if (!mounted) return;
      if (e.code == DialerException.permissionDenied) {
        await c.refreshAccess();
        if (mounted) setState(() => _load = _Load.idle);
      } else {
        setState(() => _load = _Load.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = AppScope.of(context);

    if (!c.access.loaded) return const LoadingView();
    final access = c.access.access(AppPermission.readContacts);
    if (access != FeatureAccess.available) {
      return PermissionView(
        icon: Icons.contacts_outlined,
        title: l.contactsPermissionTitle,
        body: l.contactsPermissionBody,
        needsSettings: access == FeatureAccess.openSettings,
        onGrant: _requestPermission,
        onOpenSettings: c.openAppSettings,
      );
    }

    // The controller's cache reflects star changes made elsewhere.
    final contacts = [
      for (final x in c.contacts ?? _contacts)
        if (x.phones.isNotEmpty) x,
    ];
    final results = searchContacts(contacts, _query);
    Widget body;
    switch (_load) {
      case _Load.idle:
      case _Load.loading:
        body = const LoadingView();
      case _Load.error:
        body = ErrorView(onRetry: _reload);
      case _Load.loaded:
        if (contacts.isEmpty) {
          body = EmptyView(
            icon: Icons.person_off_outlined,
            message: l.noContacts,
          );
        } else if (results.isEmpty) {
          body = EmptyView(icon: Icons.search_off, message: l.noResults);
        } else {
          body = RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              itemCount: results.length,
              itemExtent: 64,
              itemBuilder: (context, i) {
                final contact = results[i];
                return ListTile(
                  key: ValueKey('contact-${contact.id}'),
                  leading: ContactAvatar(
                    name: contact.name,
                    photoUri: contact.photoUri,
                  ),
                  title: Text(
                    contact.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: contact.company == null
                      ? null
                      : Text(
                          contact.company!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: contact.starred
                      ? Icon(
                          Icons.star,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                          semanticLabel: l.tabFavorites,
                        )
                      : null,
                  onTap: () => showContactSheet(context, contact),
                );
              },
            ),
          );
        }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SearchBar(
            key: const ValueKey('contacts-search'),
            hintText: l.searchContacts,
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}
