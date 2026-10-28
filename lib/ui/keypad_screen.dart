import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/access_state.dart';
import '../domain/app_settings.dart';
import '../domain/phone_number.dart';
import '../domain/t9.dart';
import '../l10n/app_localizations.dart';
import '../state/app_controller.dart';
import 'call_actions.dart';
import 'contact_sheet.dart';
import 'widgets/contact_avatar.dart';
import 'widgets/dial_pad.dart';
import 'widgets/highlight_text.dart';

class KeypadScreen extends StatefulWidget {
  const KeypadScreen({super.key});

  @override
  State<KeypadScreen> createState() => _KeypadScreenState();
}

class _KeypadScreenState extends State<KeypadScreen> {
  String _number = '';
  String? _error;
  bool _calling = false;
  AppController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = AppScope.of(context);
    if (!identical(c, _controller)) {
      _controller?.pendingDialNumber.removeListener(_consumePending);
      _controller = c..pendingDialNumber.addListener(_consumePending);
      WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
    }
    // Suggestions load lazily and only with permissions the user already granted.
    if (c.settings.t9Suggestions &&
        c.contacts == null &&
        c.access.granted(AppPermission.readContacts)) {
      c.ensureSearchData();
    }
  }

  @override
  void dispose() {
    _controller?.pendingDialNumber.removeListener(_consumePending);
    super.dispose();
  }

  void _consumePending() {
    final n = _controller?.pendingDialNumber.value;
    if (n == null || !mounted) return;
    _controller!.pendingDialNumber.value = null;
    setState(() {
      _number = PhoneNumbers.normalize(n);
      _error = null;
    });
  }

  void _append(String k) {
    _controller?.keyFeedback(k);
    setState(() {
      _number += k;
      _error = null;
    });
  }

  void _backspace() {
    if (_number.isEmpty) return;
    setState(() {
      _number = _number.substring(0, _number.length - 1);
      _error = null;
    });
  }

  void _clear() => setState(() {
    _number = '';
    _error = null;
  });

  bool _longPress(String k) {
    if (k == '0') {
      _append('+');
      return true;
    }
    // Speed dial / voicemail only from an empty keypad (otherwise it's just a digit).
    if (_number.isNotEmpty) return false;
    if (k == '1') {
      callVoicemail(context);
      return true;
    }
    final key = int.tryParse(k);
    if (key != null && AppSettings.speedDialKeys.contains(key)) {
      _speedDial(key);
      return true;
    }
    return false;
  }

  Future<void> _speedDial(int key) async {
    final c = AppScope.read(context);
    final entry = c.settings.speedDial[key];
    if (entry != null) {
      await callNumber(context, entry.number);
      return;
    }
    final l = AppLocalizations.of(context);
    final assign = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.speedDialNotSetTitle(key)),
        content: Text(l.speedDialNotSetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.notNow),
          ),
          FilledButton(
            key: const ValueKey('assign-speed-dial'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.assign),
          ),
        ],
      ),
    );
    if (assign != true || !mounted) return;
    await assignSpeedDial(context, key);
  }

  Future<void> _call() async {
    final l = AppLocalizations.of(context);
    final iso = AppScope.read(context).countryIso;
    final v = PhoneNumbers.validate(_number, countryIso: iso);
    if (v != NumberValidation.ok) {
      setState(
        () => _error = v == NumberValidation.empty
            ? l.enterNumber
            : l.errorInvalidNumber,
      );
      return;
    }
    setState(() => _calling = true);
    try {
      await callNumber(context, _number);
    } finally {
      if (mounted) setState(() => _calling = false);
    }
  }

  Future<void> _showNumberMenu(Offset position) async {
    final l = AppLocalizations.of(context);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        if (_number.isNotEmpty)
          PopupMenuItem(value: 'copy', child: Text(l.copy)),
        PopupMenuItem(value: 'paste', child: Text(l.paste)),
        if (_number.isNotEmpty)
          PopupMenuItem(value: 'add', child: Text(l.addContact)),
      ],
    );
    if (!mounted) return;
    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: _number));
      if (mounted) showSnack(context, l.numberCopied);
    } else if (choice == 'paste') {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final pasted = PhoneNumbers.normalize(data?.text ?? '');
      if (pasted.isNotEmpty && mounted) {
        setState(() {
          _number += pasted;
          _error = null;
        });
      }
    } else if (choice == 'add') {
      await AppScope.read(context).addContact(_number);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = AppScope.of(context);
    final iso = c.countryIso;
    final display = PhoneNumbers.format(_number, countryIso: iso);
    final matches = _number.isEmpty
        ? const <T9Match>[]
        : c.t9Search(_number, limit: 30);
    final offerContacts =
        _number.isNotEmpty &&
        c.settings.t9Suggestions &&
        c.access.access(AppPermission.readContacts) == FeatureAccess.request;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          // Suggestions + number display
          Expanded(
            flex: 3,
            // The display gets up to 84 px and shrinks (scaling text) when space is tight,
            // e.g. large fonts on small phones; suggestions take whatever is left.
            child: LayoutBuilder(
              builder: (context, box) => Column(
                children: [
                  Expanded(
                    child: _Suggestions(
                      matches: matches,
                      onTap: (m) => callNumber(context, m.phone!.number),
                      onLongPress: (m) => showContactSheet(context, m.contact),
                      offerPermission: offerContacts,
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPressStart: (d) => _showNumberMenu(d.globalPosition),
                    child: SizedBox(
                      height: box.maxHeight < 84 ? box.maxHeight : 84,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Semantics(
                                liveRegion: true,
                                label: _number.isEmpty ? l.enterNumber : null,
                                child: Text(
                                  display.isEmpty ? ' ' : display,
                                  key: const ValueKey('number-display'),
                                  maxLines: 1,
                                  style: theme.textTheme.displaySmall,
                                ),
                              ),
                              SizedBox(
                                height: 24,
                                child: _error == null
                                    ? null
                                    : Text(
                                        _error!,
                                        key: const ValueKey('number-error'),
                                        style: TextStyle(
                                          color: theme.colorScheme.error,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Keypad
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: DialPad(
                  onKeyTap: _append,
                  onKeyLongPress: _longPress,
                  maxKeySize: 84 * c.settings.keypadScale,
                  haptics: c.settings.keypadHaptics,
                ),
              ),
            ),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                SizedBox.square(
                  dimension: 64,
                  child: FloatingActionButton(
                    key: const ValueKey('call-button'),
                    heroTag: null,
                    tooltip: l.call,
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    onPressed: _calling ? null : _call,
                    child: const Icon(Icons.call, size: 30),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _number.isEmpty
                        ? const SizedBox(width: 48)
                        : IconButton(
                            key: const ValueKey('backspace'),
                            tooltip: l.backspace,
                            iconSize: 28,
                            onPressed: _backspace,
                            onLongPress: _clear,
                            icon: const Icon(Icons.backspace_outlined),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.matches,
    required this.onTap,
    required this.onLongPress,
    required this.offerPermission,
  });

  final List<T9Match> matches;
  final ValueChanged<T9Match> onTap;
  final ValueChanged<T9Match> onLongPress;
  final bool offerPermission;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = AppScope.read(context);
    if (offerPermission) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: TextButton.icon(
          key: const ValueKey('suggestions-permission'),
          icon: const Icon(Icons.contacts_outlined),
          label: Text(l.showContactSuggestions),
          onPressed: () async {
            final ok = await c.ensurePermission(AppPermission.readContacts);
            if (ok == PermissionStatus.granted) await c.ensureSearchData();
          },
        ),
      );
    }
    if (matches.isEmpty) return const SizedBox.expand();
    return ListView.builder(
      key: const ValueKey('t9-suggestions'),
      reverse: true, // best match sits right above the number
      itemCount: matches.length,
      itemBuilder: (context, i) {
        final m = matches[i];
        final phone = m.phone!;
        return ListTile(
          key: ValueKey('t9-${m.contact.id}'),
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: ContactAvatar(
            name: m.contact.name,
            photoUri: m.contact.photoUri,
            radius: 16,
          ),
          title: HighlightText(m.contact.name, highlight: m.nameHighlight),
          subtitle: HighlightText.digits(
            [
              if (phone.label.isNotEmpty) '${phone.label} ',
              phone.number,
            ].join(),
            m.phoneHighlight == null
                ? null
                : (m.phoneHighlight!.$1, m.phoneHighlight!.$2),
          ),
          onTap: () => onTap(m),
          onLongPress: () => onLongPress(m),
        );
      },
    );
  }
}

/// Lets the user pick a contact number for speed-dial [key]. Shared with Settings.
Future<void> assignSpeedDial(BuildContext context, int key) async {
  final l = AppLocalizations.of(context);
  final c = AppScope.read(context);
  final ok = await c.ensurePermission(AppPermission.readContacts);
  if (ok != PermissionStatus.granted || !context.mounted) return;
  final picked = await pickContactNumber(
    context,
    title: l.speedDialAssignTitle(key),
  );
  if (picked == null) return;
  await c.updateSettings(
    c.settings.withSpeedDial(
      key,
      SpeedDialEntry(number: picked.$2.number, name: picked.$1.name),
    ),
  );
  if (context.mounted) {
    showSnack(context, l.speedDialSaved(key, picked.$1.name));
  }
}
