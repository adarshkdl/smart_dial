import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../domain/access_state.dart';
import '../domain/call_log.dart';
import '../domain/phone_number.dart';
import '../domain/sim.dart';
import '../l10n/app_localizations.dart';
import '../platform/dialer_platform.dart';
import '../state/app_controller.dart';
import 'call_actions.dart';
import 'notes_section.dart';
import 'reminders_screen.dart' show remindToCall;
import 'widgets/contact_avatar.dart';
import 'widgets/state_views.dart';

class RecentsScreen extends StatefulWidget {
  const RecentsScreen({super.key});

  @override
  State<RecentsScreen> createState() => _RecentsScreenState();
}

enum _Load { idle, loading, loaded, error }

class _RecentsScreenState extends State<RecentsScreen> {
  _Load _load = _Load.idle;
  List<CallLogEntry> _entries = const [];
  PhoneAccounts _accounts = PhoneAccounts.none;
  CallLogFilter _filter = CallLogFilter.all;
  String? _simFilter;
  String _query = '';
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = AppScope.of(context);
    // Auto-prompt only on the very first visit; a later revocation shows the denied state.
    if (c.access.granted(AppPermission.readCallLog)) _asked = true;
    if (c.access.granted(AppPermission.readCallLog) && _load == _Load.idle) {
      _reload();
    } else if (!_asked &&
        c.access.loaded &&
        c.access.access(AppPermission.readCallLog) == FeatureAccess.request) {
      // First visit: ask right away — the tab itself is the explanation (just-in-time).
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestPermission());
    }
  }

  Future<void> _requestPermission() async {
    final c = AppScope.read(context);
    final s = await c.ensurePermission(AppPermission.readCallLog);
    if (s == PermissionStatus.granted && mounted) _reload();
  }

  Future<void> _reload() async {
    final c = AppScope.read(context);
    if (_load == _Load.loading) return;
    setState(() => _load = _Load.loading);
    try {
      final entries = await c.loadCallLog(force: true);
      final accounts = await c.phoneAccounts();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _accounts = accounts;
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

  Future<void> _delete(CallLogGroup g) async {
    final c = AppScope.read(context);
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final s = await c.ensurePermission(AppPermission.writeCallLog);
    if (s != PermissionStatus.granted) return;
    try {
      await c.platform.deleteCallLogEntries(g.ids);
      c.removeCallLogEntries(g.ids.toSet());
      if (!mounted) return;
      setState(
        () => _entries = [
          for (final e in _entries)
            if (!g.ids.contains(e.id)) e,
        ],
      );
      messenger.showSnackBar(SnackBar(content: Text(l.deleted)));
    } on DialerException {
      messenger.showSnackBar(SnackBar(content: Text(l.errorLoading)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = AppScope.of(context);

    if (!c.access.loaded) return const LoadingView();
    final access = c.access.access(AppPermission.readCallLog);
    if (access != FeatureAccess.available) {
      return PermissionView(
        icon: Icons.history,
        title: l.recentsPermissionTitle,
        body: l.recentsPermissionBody,
        needsSettings: access == FeatureAccess.openSettings,
        onGrant: _requestPermission,
        onOpenSettings: c.openAppSettings,
      );
    }

    final filtered = filterCallLog(
      _entries,
      filter: _filter,
      query: _query,
      accountId: _simFilter,
    );
    final groups = groupCallLog(filtered);

    Widget body;
    switch (_load) {
      case _Load.idle:
      case _Load.loading:
        body = const LoadingView();
      case _Load.error:
        body = ErrorView(onRetry: _reload);
      case _Load.loaded:
        if (_entries.isEmpty) {
          body = EmptyView(icon: Icons.history, message: l.noRecents);
        } else if (groups.isEmpty) {
          body = EmptyView(icon: Icons.search_off, message: l.noResults);
        } else {
          body = RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, i) => _RecentTile(
                group: groups[i],
                accounts: _accounts,
                onCall: () => callNumber(context, groups[i].number),
                onDelete: () => _delete(groups[i]),
              ),
            ),
          );
        }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SearchBar(
            key: const ValueKey('recents-search'),
            hintText: l.searchRecents,
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            key: const ValueKey('recents-filters'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final (f, label) in [
                (CallLogFilter.all, l.filterAll),
                (CallLogFilter.missed, l.filterMissed),
                (CallLogFilter.incoming, l.callTypeIncoming),
                (CallLogFilter.outgoing, l.callTypeOutgoing),
                (CallLogFilter.declined, l.filterDeclined),
              ])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    key: ValueKey('filter-${f.name}'),
                    label: Text(label),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
              if (_accounts.accounts.length > 1) ...[
                const VerticalDivider(width: 16, indent: 10, endIndent: 10),
                for (final a in [null, ..._accounts.accounts])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      key: ValueKey('sim-filter-${a?.id ?? 'all'}'),
                      avatar: const Icon(Icons.sim_card_outlined, size: 18),
                      label: Text(a?.label ?? l.allSims),
                      selected: _simFilter == a?.id,
                      onSelected: (_) => setState(() => _simFilter = a?.id),
                    ),
                  ),
              ],
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({
    required this.group,
    required this.accounts,
    required this.onCall,
    required this.onDelete,
  });

  final CallLogGroup group;
  final PhoneAccounts accounts;
  final VoidCallback onCall;
  final VoidCallback onDelete;

  static IconData iconFor(CallType t) => switch (t) {
    CallType.incoming || CallType.answeredExternally => Icons.call_received,
    CallType.outgoing => Icons.call_made,
    CallType.missed => Icons.call_missed,
    CallType.rejected => Icons.call_end,
    CallType.blocked => Icons.block,
    CallType.voicemail => Icons.voicemail,
    CallType.unknown => Icons.call,
  };

  static String typeLabel(AppLocalizations l, CallType t) => switch (t) {
    CallType.incoming || CallType.answeredExternally => l.callTypeIncoming,
    CallType.outgoing => l.callTypeOutgoing,
    CallType.missed => l.callTypeMissed,
    CallType.rejected => l.callTypeRejected,
    CallType.blocked => l.callTypeBlocked,
    CallType.voicemail => l.callTypeVoicemail,
    CallType.unknown => '',
  };

  static String when(BuildContext context, DateTime d) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final time = DateFormat.jm(locale).format(d);
    if (day == today) return time;
    if (day == today.subtract(const Duration(days: 1))) {
      return '${l.yesterday}, $time';
    }
    return '${DateFormat.MMMd(locale).format(d)}, $time';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final iso = AppScope.read(context).countryIso;
    final e = group.latest;
    final private = PhoneNumbers.isPrivate(group.number);
    final formatted = private
        ? l.privateNumber
        : PhoneNumbers.format(group.number, countryIso: iso);
    final title = group.name ?? formatted;
    final missed = e.type == CallType.missed;
    final sim = accounts.accounts.length > 1
        ? accounts.byId(e.accountId)?.label
        : null;

    final subtitleParts = [
      when(context, e.date),
      ?sim,
      if (e.duration > Duration.zero) formatCallDuration(e.duration),
    ];

    return ListTile(
      leading: ContactAvatar(name: group.name ?? ''),
      title: Row(
        children: [
          Flexible(
            child: Text(
              group.count > 1 ? '$title (${group.count})' : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: missed ? TextStyle(color: theme.colorScheme.error) : null,
            ),
          ),
          if (!private && AppScope.of(context).notes.hasNotes(group.number))
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6),
              child: Icon(
                Icons.sticky_note_2_outlined,
                key: ValueKey('has-note-${e.id}'),
                size: 16,
                color: theme.colorScheme.primary,
                semanticLabel: l.notes,
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Icon(
            iconFor(e.type),
            size: 16,
            color: missed
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
            semanticLabel: typeLabel(l, e.type),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              subtitleParts.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: private
          ? null
          : IconButton(
              key: ValueKey('recent-call-${e.id}'),
              tooltip: l.callNumberLabel(formatted),
              icon: const Icon(Icons.call),
              onPressed: onCall,
            ),
      onTap: () => _showDetails(context, formatted, private),
    );
  }

  void _showDetails(BuildContext context, String formatted, bool private) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: ContactAvatar(name: group.name ?? '', radius: 24),
                title: Text(
                  group.name ?? formatted,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                subtitle: group.name != null ? Text(formatted) : null,
              ),
              const Divider(),
              for (final e in group.entries)
                ListTile(
                  dense: true,
                  leading: Icon(iconFor(e.type)),
                  title: Text(typeLabel(l, e.type)),
                  subtitle: Text(when(ctx, e.date)),
                  trailing: e.duration > Duration.zero
                      ? Text(formatCallDuration(e.duration))
                      : null,
                ),
              const Divider(),
              if (!private) ...[
                ListTile(
                  leading: const Icon(Icons.call),
                  title: Text(l.call),
                  onTap: () {
                    Navigator.pop(ctx);
                    onCall();
                  },
                ),
                ListTile(
                  key: const ValueKey('recent-message'),
                  leading: const Icon(Icons.message_outlined),
                  title: Text(l.message),
                  onTap: () {
                    Navigator.pop(ctx);
                    AppScope.read(context).sendMessage(group.number);
                  },
                ),
                if (group.name == null)
                  ListTile(
                    key: const ValueKey('recent-add-contact'),
                    leading: const Icon(Icons.person_add_alt),
                    title: Text(l.addContact),
                    onTap: () {
                      Navigator.pop(ctx);
                      AppScope.read(context).addContact(group.number);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: Text(l.copy),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: group.number));
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  key: const ValueKey('recent-remind'),
                  leading: const Icon(Icons.alarm_add),
                  title: Text(l.remindToCallBack),
                  onTap: () {
                    Navigator.pop(ctx);
                    remindToCall(
                      context,
                      number: group.number,
                      name: group.name,
                    );
                  },
                ),
                NotesSection(numbers: [group.number]),
              ],
              ListTile(
                key: const ValueKey('delete-entry'),
                leading: const Icon(Icons.delete_outline),
                title: Text(l.deleteEntry),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
