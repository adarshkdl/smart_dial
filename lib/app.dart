import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'domain/app_settings.dart';
import 'l10n/app_localizations.dart';
import 'platform/dialer_platform.dart';
import 'state/app_controller.dart';
import 'ui/home_shell.dart';
import 'ui/in_call_screen.dart';

class SmartDialApp extends StatefulWidget {
  const SmartDialApp({super.key, required this.platform, this.locale});

  final DialerPlatform platform;

  /// Forces a locale (tests); otherwise follows the device.
  final Locale? locale;

  @override
  State<SmartDialApp> createState() => _SmartDialAppState();
}

class _SmartDialAppState extends State<SmartDialApp>
    with WidgetsBindingObserver {
  late final AppController _controller = AppController(widget.platform);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// Role or permissions may have changed in Settings while we were away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.onResume();
  }

  final Map<(Brightness, int), ThemeData> _themes = {};

  /// Cached: the app rebuilds on every controller change, themes only change with settings.
  ThemeData _theme(Brightness b, Color seed) => _themes.putIfAbsent(
    (b, seed.toARGB32()),
    () => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: b),
    ),
  );

  Color _seed(AppSettings s) {
    if (s.accent == AccentColor.dynamic) {
      final d = _controller.dynamicAccent;
      if (d != null) return Color(d);
      return Color(AccentColor.teal.argb);
    }
    return Color(s.accent.argb);
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _app(context),
      ),
    );
  }

  Widget _app(BuildContext context) {
    final s = _controller.settings;
    final seed = _seed(s);
    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light, seed),
      darkTheme: _theme(Brightness.dark, seed),
      themeMode: switch (s.theme) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      },
      locale:
          widget.locale ??
          (s.language.localeCode == null
              ? null
              : Locale(s.language.localeCode!)),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Root(),
    );
  }
}

/// Shows the in-call screen whenever Telecom reports a call; otherwise the tabs.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final hasCalls = AppScope.of(context).calls.hasCalls;
    return PopScope(
      canPop: !hasCalls,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: hasCalls
            ? const InCallScreen(key: ValueKey('in-call'))
            : const HomeShell(key: ValueKey('home')),
      ),
    );
  }
}
