import 'package:flutter/material.dart';

import '../domain/app_settings.dart';
import '../l10n/app_localizations.dart';
import '../state/app_controller.dart';
import 'call_actions.dart';
import 'diagnostics_screen.dart';
import 'keypad_screen.dart' show assignSpeedDial;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static String accentLabel(AppLocalizations l, AccentColor a) => switch (a) {
    AccentColor.teal => l.accentTeal,
    AccentColor.blue => l.accentBlue,
    AccentColor.indigo => l.accentIndigo,
    AccentColor.purple => l.accentPurple,
    AccentColor.pink => l.accentPink,
    AccentColor.orange => l.accentOrange,
    AccentColor.green => l.accentGreen,
    AccentColor.dynamic => l.accentDynamic,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = AppScope.of(context);
    final s = c.settings;
    void update(AppSettings next) => c.updateSettings(next);

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        key: const ValueKey('settings-list'),
        children: [
          // ---- Appearance
          _Section(l.appearance),
          ListTile(
            title: Text(l.theme),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<ThemePreference>(
                key: const ValueKey('theme-selector'),
                segments: [
                  ButtonSegment(
                    value: ThemePreference.system,
                    label: Text(l.themeSystem),
                  ),
                  ButtonSegment(
                    value: ThemePreference.light,
                    label: Text(l.themeLight),
                  ),
                  ButtonSegment(
                    value: ThemePreference.dark,
                    label: Text(l.themeDark),
                  ),
                ],
                selected: {s.theme},
                onSelectionChanged: (v) => update(s.copyWith(theme: v.first)),
              ),
            ),
          ),
          ListTile(
            title: Text(l.accentColor),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in AccentColor.values)
                    if (a != AccentColor.dynamic || c.dynamicAccent != null)
                      ChoiceChip(
                        key: ValueKey('accent-${a.name}'),
                        avatar: CircleAvatar(
                          backgroundColor: Color(
                            a == AccentColor.dynamic
                                ? c.dynamicAccent!
                                : a.argb,
                          ),
                        ),
                        label: Text(accentLabel(l, a)),
                        selected: s.accent == a,
                        onSelected: (_) => update(s.copyWith(accent: a)),
                      ),
                ],
              ),
            ),
          ),
          ListTile(
            title: Text(l.keypadSize),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<KeypadSize>(
                key: const ValueKey('keypad-size-selector'),
                segments: [
                  ButtonSegment(
                    value: KeypadSize.compact,
                    label: Text(l.sizeCompact),
                  ),
                  ButtonSegment(
                    value: KeypadSize.normal,
                    label: Text(l.sizeNormal),
                  ),
                  ButtonSegment(
                    value: KeypadSize.large,
                    label: Text(l.sizeLarge),
                  ),
                ],
                selected: {s.keypadSize},
                onSelectionChanged: (v) =>
                    update(s.copyWith(keypadSize: v.first)),
              ),
            ),
          ),

          // ---- Keypad
          ListTile(
            title: Text(l.language),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<AppLanguage>(
                key: const ValueKey('language-selector'),
                segments: [
                  ButtonSegment(
                    value: AppLanguage.system,
                    label: Text(l.themeSystem),
                  ),
                  const ButtonSegment(
                    value: AppLanguage.english,
                    label: Text('English'),
                  ),
                  const ButtonSegment(
                    value: AppLanguage.malayalam,
                    label: Text('മലയാളം'),
                  ),
                ],
                selected: {s.language},
                onSelectionChanged: (v) =>
                    update(s.copyWith(language: v.first)),
              ),
            ),
          ),

          _Section(l.keypad),
          SwitchListTile(
            key: const ValueKey('toggle-t9'),
            title: Text(l.t9Suggestions),
            subtitle: Text(l.t9SuggestionsHint),
            value: s.t9Suggestions,
            onChanged: (v) => update(s.copyWith(t9Suggestions: v)),
          ),
          SwitchListTile(
            key: const ValueKey('toggle-tones'),
            title: Text(l.keypadTones),
            subtitle: Text(l.keypadTonesHint),
            value: s.keypadTones,
            onChanged: (v) => update(s.copyWith(keypadTones: v)),
          ),
          SwitchListTile(
            key: const ValueKey('toggle-haptics'),
            title: Text(l.keypadHaptics),
            value: s.keypadHaptics,
            onChanged: (v) => update(s.copyWith(keypadHaptics: v)),
          ),

          // ---- Speed dial
          _Section(l.speedDial),
          ListTile(
            dense: true,
            leading: const CircleAvatar(child: Text('1')),
            title: Text(l.voicemail),
          ),
          for (final k in AppSettings.speedDialKeys)
            ListTile(
              key: ValueKey('speed-dial-$k'),
              leading: CircleAvatar(child: Text('$k')),
              title: Text(
                s.speedDial[k]?.name ?? s.speedDial[k]?.number ?? l.notSet,
              ),
              subtitle: s.speedDial[k]?.name == null
                  ? null
                  : Text(s.speedDial[k]!.number),
              trailing: s.speedDial[k] == null
                  ? null
                  : IconButton(
                      key: ValueKey('speed-dial-clear-$k'),
                      tooltip: l.remove,
                      icon: const Icon(Icons.close),
                      onPressed: () => update(s.withSpeedDial(k, null)),
                    ),
              onTap: () => assignSpeedDial(context, k),
            ),

          // ---- Calls & SIM
          _Section(l.callsAndSim),
          SwitchListTile(
            key: const ValueKey('toggle-remember-sim'),
            title: Text(l.rememberSimSetting),
            subtitle: Text(l.rememberSimHint(s.simByNumber.length)),
            value: s.rememberSimPerContact,
            onChanged: (v) => update(s.copyWith(rememberSimPerContact: v)),
          ),
          if (s.simByNumber.isNotEmpty)
            ListTile(
              key: const ValueKey('clear-sim-prefs'),
              leading: const Icon(Icons.sim_card_outlined),
              title: Text(l.clearSimChoices),
              onTap: () => update(s.copyWith(simByNumber: const {})),
            ),
          SwitchListTile(
            key: const ValueKey('toggle-shortcuts'),
            title: Text(l.favoriteShortcuts),
            subtitle: Text(l.favoriteShortcutsHint),
            value: s.favoriteShortcuts,
            onChanged: (v) => update(s.copyWith(favoriteShortcuts: v)),
          ),
          ListTile(
            leading: Icon(
              c.access.isDefaultDialer
                  ? Icons.check_circle
                  : Icons.phone_in_talk_outlined,
            ),
            title: Text(
              c.access.isDefaultDialer ? l.isDefaultApp : l.defaultRoleTitle,
            ),
            onTap: c.access.isDefaultDialer || !c.access.roleAvailable
                ? null
                : c.requestDefaultRole,
          ),

          // ---- Privacy
          _Section(l.privacy),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l.privacySummary),
          ),
          ListTile(
            key: const ValueKey('open-diagnostics'),
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(l.diagnostics),
            subtitle: Text(
              l.diagnosticsHint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DiagnosticsScreen(),
              ),
            ),
          ),
          ListTile(
            key: const ValueKey('clear-app-data'),
            leading: const Icon(Icons.delete_outline),
            title: Text(l.clearAppData),
            subtitle: Text(l.clearAppDataHint),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l.clearAppData),
                  content: Text(l.clearAppDataConfirm),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l.cancel),
                    ),
                    FilledButton(
                      key: const ValueKey('confirm-clear'),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l.clear),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await c.clearAppData();
                if (context.mounted) showSnack(context, l.appDataCleared);
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );
}
