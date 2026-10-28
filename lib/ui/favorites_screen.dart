import 'package:flutter/material.dart';

import '../domain/access_state.dart';
import '../domain/contact.dart';
import '../l10n/app_localizations.dart';
import '../platform/dialer_platform.dart';
import '../state/app_controller.dart';
import 'call_actions.dart';
import 'contact_sheet.dart';
import 'widgets/contact_avatar.dart';
import 'widgets/state_views.dart';

/// Starred contacts as a grid (tap = call) plus "Frequent" from the call log.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _asked = false;
  bool _loading = false;
  bool _error = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = AppScope.of(context);
    if (c.access.granted(AppPermission.readContacts)) {
      _asked = true;
      if (c.contacts == null && !_loading && !_error) _load();
    } else if (!_asked &&
        c.access.loaded &&
        c.access.access(AppPermission.readContacts) == FeatureAccess.request) {
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _request());
    }
  }

  Future<void> _request() async {
    final s = await AppScope.read(
      context,
    ).ensurePermission(AppPermission.readContacts);
    if (s == PermissionStatus.granted && mounted) _load();
  }

  Future<void> _load({bool force = false}) async {
    final c = AppScope.read(context);
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      await c.loadContacts(force: force);
      // Frequency needs the call log; never prompt for it from this tab.
      if (c.access.granted(AppPermission.readCallLog)) {
        await c.loadCallLog(force: force);
      }
    } on DialerException {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _quickCall(Contact c) {
    if (c.phones.length == 1) {
      callNumber(context, c.phones.first.number);
    } else {
      showContactSheet(context, c);
    }
  }

  Future<void> _longPress(Contact contact) async {
    final l = AppLocalizations.of(context);
    final c = AppScope.read(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                contact.name,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              key: const ValueKey('fav-action-call'),
              leading: const Icon(Icons.call),
              title: Text(l.call),
              onTap: () => Navigator.pop(ctx, 'call'),
            ),
            ListTile(
              key: const ValueKey('fav-action-message'),
              leading: const Icon(Icons.message_outlined),
              title: Text(l.message),
              onTap: () => Navigator.pop(ctx, 'message'),
            ),
            ListTile(
              key: const ValueKey('fav-action-details'),
              leading: const Icon(Icons.person_outline),
              title: Text(l.details),
              onTap: () => Navigator.pop(ctx, 'details'),
            ),
            if (contact.starred)
              ListTile(
                key: const ValueKey('fav-action-unstar'),
                leading: const Icon(Icons.star_outline),
                title: Text(l.removeFavorite),
                onTap: () => Navigator.pop(ctx, 'unstar'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'call':
        _quickCall(contact);
      case 'message':
        await c.sendMessage(contact.phones.first.number);
      case 'details':
        await showContactSheet(context, contact);
      case 'unstar':
        final ok = await c.setStarred(contact, false);
        if (!ok && mounted) showSnack(context, l.errorFavoritePermission);
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
        icon: Icons.star_outline,
        title: l.contactsPermissionTitle,
        body: l.contactsPermissionBody,
        needsSettings: access == FeatureAccess.openSettings,
        onGrant: _request,
        onOpenSettings: c.openAppSettings,
      );
    }
    if (_error) return ErrorView(onRetry: () => _load(force: true));
    if (c.contacts == null) return const LoadingView();

    final favs = c.favorites;
    final frequent = c.frequent;
    if (favs.isEmpty && frequent.isEmpty) {
      return EmptyView(icon: Icons.star_outline, message: l.noFavorites);
    }

    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: CustomScrollView(
        slivers: [
          if (favs.isNotEmpty) ...[
            _Header(l.tabFavorites),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120,
                  mainAxisExtent: 124,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _FavoriteTile(
                    contact: favs[i],
                    onTap: () => _quickCall(favs[i]),
                    onLongPress: () => _longPress(favs[i]),
                  ),
                  childCount: favs.length,
                ),
              ),
            ),
          ],
          if (frequent.isNotEmpty) ...[
            _Header(l.frequent),
            SliverList.builder(
              itemCount: frequent.length,
              itemBuilder: (context, i) {
                final f = frequent[i];
                return ListTile(
                  key: ValueKey('frequent-${f.id}'),
                  leading: ContactAvatar(name: f.name, photoUri: f.photoUri),
                  title: Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: l.callNumberLabel(f.name),
                    icon: const Icon(Icons.call),
                    onPressed: () => _quickCall(f),
                  ),
                  onTap: () => showContactSheet(context, f),
                  onLongPress: () => _longPress(f),
                );
              },
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Semantics(
        header: true,
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      ),
    ),
  );
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({
    required this.contact,
    required this.onTap,
    required this.onLongPress,
  });
  final Contact contact;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l.callNumberLabel(contact.name),
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: InkWell(
        key: ValueKey('fav-${contact.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(8),
          // Scales down instead of overflowing at large font sizes.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 96,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ContactAvatar(
                    name: contact.name,
                    photoUri: contact.photoUri,
                    radius: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    contact.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
