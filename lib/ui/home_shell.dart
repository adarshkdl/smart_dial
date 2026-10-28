import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../state/app_controller.dart';
import 'call_actions.dart';
import 'contacts_screen.dart';
import 'favorites_screen.dart';
import 'keypad_screen.dart';
import 'recents_screen.dart';
import 'reminders_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static const keypadTab = 0, favoritesTab = 1, recentsTab = 2, contactsTab = 3;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = HomeShell.keypadTab;
  final Set<int> _visited = {HomeShell.keypadTab};
  bool _bannerDismissed = false;

  AppController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = AppScope.read(context);
    if (!identical(c, _controller)) {
      _detach();
      _controller = c
        ..pendingDialNumber.addListener(_onDial)
        ..pendingCallNumber.addListener(_onCall)
        ..pendingTab.addListener(_onTab);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onCall();
        _onTab();
      });
    }
  }

  void _detach() {
    _controller?.pendingDialNumber.removeListener(_onDial);
    _controller?.pendingCallNumber.removeListener(_onCall);
    _controller?.pendingTab.removeListener(_onTab);
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _select(int i) {
    setState(() {
      _tab = i;
      _visited.add(i);
    });
    // Viewing Recents counts as having seen missed calls.
    if (i == HomeShell.recentsTab) _controller?.markMissedCallsRead();
  }

  /// A DIAL intent always brings the keypad forward.
  void _onDial() {
    if (mounted &&
        _controller?.pendingDialNumber.value != null &&
        _tab != HomeShell.keypadTab) {
      _select(HomeShell.keypadTab);
    }
  }

  /// Launcher shortcut → call (via the normal flow so SIM choice / permissions apply).
  void _onCall() {
    final n = _controller?.pendingCallNumber.value;
    if (!mounted || n == null) return;
    _controller!.pendingCallNumber.value = null;
    callNumber(context, n);
  }

  void _onTab() {
    final t = _controller?.pendingTab.value;
    if (!mounted || t == null) return;
    _controller!.pendingTab.value = null;
    if (t == 'reminders') {
      _openReminders();
      return;
    }
    final i = switch (t) {
      'recents' => HomeShell.recentsTab,
      'favorites' => HomeShell.favoritesTab,
      'contacts' => HomeShell.contactsTab,
      _ => HomeShell.keypadTab,
    };
    _select(i);
  }

  void _openReminders() {
    _controller?.refreshReminders();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RemindersScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = AppScope.of(context);
    final pending = controller.pendingReminderCount;
    final showBanner =
        controller.access.shouldOfferDefaultRole && !_bannerDismissed;

    // Tabs are built lazily on first visit, then kept alive (IndexedStack).
    Widget lazy(int i, Widget w) => _visited.contains(i) ? w : const SizedBox();
    final pages = <Widget>[
      const KeypadScreen(),
      lazy(HomeShell.favoritesTab, const FavoritesScreen()),
      lazy(HomeShell.recentsTab, const RecentsScreen()),
      lazy(HomeShell.contactsTab, const ContactsScreen()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          IconButton(
            key: const ValueKey('open-reminders'),
            tooltip: l.reminders,
            icon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.alarm),
            ),
            onPressed: _openReminders,
          ),
          IconButton(
            key: const ValueKey('open-settings'),
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (showBanner)
            MaterialBanner(
              key: const ValueKey('default-role-banner'),
              leading: const Icon(Icons.phone_in_talk_outlined),
              // Capped so large fonts on small phones can't push the keypad off-screen.
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.defaultRoleTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(l.defaultRoleBody),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _bannerDismissed = true),
                  child: Text(l.notNow),
                ),
                FilledButton(
                  key: const ValueKey('default-role-action'),
                  onPressed: controller.requestDefaultRole,
                  child: Text(l.defaultRoleAction),
                ),
              ],
            ),
          Expanded(
            child: IndexedStack(index: _tab, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _select,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dialpad),
            label: l.tabKeypad,
          ),
          NavigationDestination(
            icon: const Icon(Icons.star_outline),
            selectedIcon: const Icon(Icons.star),
            label: l.tabFavorites,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            label: l.tabRecents,
          ),
          NavigationDestination(
            icon: const Icon(Icons.contacts_outlined),
            label: l.tabContacts,
          ),
        ],
      ),
    );
  }
}
