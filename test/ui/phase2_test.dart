import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_dial/domain/access_state.dart';
import 'package:smart_dial/domain/app_settings.dart';
import 'package:smart_dial/domain/call_log.dart';
import 'package:smart_dial/domain/contact.dart';
import 'package:smart_dial/domain/sim.dart';
import 'package:smart_dial/platform/dialer_platform.dart';

import '../support/fake_dialer_platform.dart';

const anu = Contact(
  id: 'anu',
  name: 'Anu Mathew',
  phones: [ContactPhone('9847012345', label: 'Mobile')],
);
const anil = Contact(
  id: 'anil',
  name: 'Anil',
  phones: [ContactPhone('9000000001')],
);
const anitha = Contact(
  id: 'anitha',
  name: 'Anitha',
  phones: [ContactPhone('9000000002')],
);
const bindu = Contact(
  id: 'bindu',
  name: 'Bindu Nair',
  starred: true,
  phones: [ContactPhone('04712345678', label: 'Work')],
);

const dualSim = PhoneAccounts(
  permitted: true,
  accounts: [
    PhoneAccount(id: 'a', label: 'Jio'),
    PhoneAccount(id: 'b', label: 'Airtel', slot: 1),
  ],
);

Future<void> typeDigits(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.byKey(ValueKey('dialkey-$d')));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-settings')));
  await tester.pumpAndSettle();
}

String settingsJson(AppSettings s) => s.encode();

void main() {
  group('T9 suggestions on the keypad', () {
    testWidgets('typing letters-as-digits suggests and calls the contact', (
      tester,
    ) async {
      final p = FakeDialerPlatform(contacts: const [anu, bindu]);
      await pumpApp(tester, p);
      await typeDigits(tester, '268'); // A-N-U
      expect(find.byKey(const ValueKey('t9-anu')), findsOneWidget);
      expect(find.byKey(const ValueKey('t9-bindu')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('t9-anu')));
      await tester.pumpAndSettle();
      expect(p.placedCalls, [('9847012345', null)]);
    });

    testWidgets('number prefix also matches', (tester) async {
      await pumpApp(tester, FakeDialerPlatform(contacts: const [anu, bindu]));
      await typeDigits(tester, '0471');
      expect(find.byKey(const ValueKey('t9-bindu')), findsOneWidget);
    });

    testWidgets(
      'frequently called contacts rank first (closest to the number)',
      (tester) async {
        final now = DateTime.now();
        final p = FakeDialerPlatform(
          contacts: const [anil, anitha],
          callLog: [
            for (var i = 0; i < 5; i++)
              CallLogEntry(
                id: '$i',
                number: '9000000002',
                type: CallType.outgoing,
                date: now.subtract(Duration(hours: i)),
              ),
          ],
        );
        await pumpApp(tester, p);
        await typeDigits(tester, '264');
        final yAnitha = tester
            .getCenter(find.byKey(const ValueKey('t9-anitha')))
            .dy;
        final yAnil = tester
            .getCenter(find.byKey(const ValueKey('t9-anil')))
            .dy;
        expect(
          yAnitha,
          greaterThan(yAnil),
          reason: 'list is reversed: best match is lowest, next to the number',
        );
      },
    );

    testWidgets('can be turned off in settings', (tester) async {
      final p = FakeDialerPlatform(
        contacts: const [anu],
        appData: settingsJson(
          AppSettings.defaults.copyWith(t9Suggestions: false),
        ),
      );
      await pumpApp(tester, p);
      await typeDigits(tester, '268');
      expect(find.byKey(const ValueKey('t9-anu')), findsNothing);
    });

    testWidgets(
      'without contacts access offers to enable suggestions (never auto-prompts)',
      (tester) async {
        final p = FakeDialerPlatform(
          access: FakeDialerPlatform.allGranted().withResults({
            AppPermission.readContacts: PermissionStatus.denied,
          }),
          contacts: const [anu],
        );
        await pumpApp(tester, p);
        await typeDigits(tester, '268');
        expect(p.permissionRequests, isEmpty);
        await tester.tap(find.byKey(const ValueKey('suggestions-permission')));
        await tester.pumpAndSettle();
        expect(p.permissionRequests.single, [AppPermission.readContacts]);
        expect(find.byKey(const ValueKey('t9-anu')), findsOneWidget);
      },
    );

    testWidgets('long-press on a suggestion opens contact details', (
      tester,
    ) async {
      await pumpApp(tester, FakeDialerPlatform(contacts: const [anu]));
      await typeDigits(tester, '268');
      await tester.longPress(find.byKey(const ValueKey('t9-anu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('star-toggle')), findsOneWidget);
    });
  });

  group('Speed dial & voicemail', () {
    testWidgets('long-press an assigned key calls it', (tester) async {
      final p = FakeDialerPlatform(
        appData: settingsJson(
          AppSettings.defaults.withSpeedDial(
            2,
            const SpeedDialEntry(number: '9847012345', name: 'Anu'),
          ),
        ),
      );
      await pumpApp(tester, p);
      await tester.longPress(find.byKey(const ValueKey('dialkey-2')));
      await tester.pumpAndSettle();
      expect(p.placedCalls, [('9847012345', null)]);
    });

    testWidgets('long-press an empty key offers to assign, then saves', (
      tester,
    ) async {
      final p = FakeDialerPlatform(contacts: const [anu, bindu]);
      await pumpApp(tester, p);
      await tester.longPress(find.byKey(const ValueKey('dialkey-3')));
      await tester.pumpAndSettle();
      expect(find.text("Speed dial 3 isn't set"), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('assign-speed-dial')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pick-anu-9847012345')));
      await tester.pumpAndSettle();
      expect(find.text('Speed dial 3: Anu Mathew'), findsOneWidget);
      expect(AppSettings.decode(p.appData).speedDial[3]!.number, '9847012345');
      expect(p.placedCalls, isEmpty);
    });

    testWidgets('long-press 1 calls voicemail', (tester) async {
      final p = FakeDialerPlatform();
      await pumpApp(tester, p);
      await tester.longPress(find.byKey(const ValueKey('dialkey-1')));
      await tester.pumpAndSettle();
      expect(p.voicemailCalls.length, 1);
    });

    testWidgets('with digits already typed, long-press just types the digit', (
      tester,
    ) async {
      final p = FakeDialerPlatform(
        countryIso: '',
        appData: settingsJson(
          AppSettings.defaults.withSpeedDial(
            2,
            const SpeedDialEntry(number: '111'),
          ),
        ),
      );
      await pumpApp(tester, p);
      await typeDigits(tester, '9');
      await tester.longPress(find.byKey(const ValueKey('dialkey-2')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('number-display'))).data,
        '92',
      );
      expect(p.placedCalls, isEmpty);
    });

    testWidgets('settings lists and clears speed dial entries', (tester) async {
      final p = FakeDialerPlatform(
        appData: settingsJson(
          AppSettings.defaults.withSpeedDial(
            5,
            const SpeedDialEntry(number: '555', name: 'Five'),
          ),
        ),
      );
      await pumpApp(tester, p);
      await openSettings(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('speed-dial-5')),
        200,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('settings-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('speed-dial-5')));
      await tester.pumpAndSettle();
      expect(find.text('Five'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('speed-dial-clear-5')));
      await tester.pumpAndSettle();
      expect(AppSettings.decode(p.appData).speedDial, isEmpty);
    });
  });

  group('Dual SIM', () {
    testWidgets('"remember" skips the picker next time and is persisted', (
      tester,
    ) async {
      final p = FakeDialerPlatform(accounts: dualSim);
      await pumpApp(tester, p);
      await typeDigits(tester, '9847012345');
      await tester.tap(find.byKey(const ValueKey('call-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sim-remember')));
      await tester.pump();
      await tester.tap(find.text('Airtel'));
      await tester.pumpAndSettle();
      expect(p.placedCalls.last, ('9847012345', 'b'));
      expect(AppSettings.decode(p.appData).simFor('+919847012345'), 'b');

      await tester.tap(find.byKey(const ValueKey('call-button')));
      await tester.pumpAndSettle();
      expect(find.text('Call with'), findsNothing);
      expect(p.placedCalls.last, ('9847012345', 'b'));
    });

    testWidgets(
      'a remembered SIM that no longer exists falls back to the picker',
      (tester) async {
        final p = FakeDialerPlatform(
          accounts: dualSim,
          appData: settingsJson(
            AppSettings.defaults.withSimFor('9847012345', 'removed-sim'),
          ),
        );
        await pumpApp(tester, p);
        await typeDigits(tester, '9847012345');
        await tester.tap(find.byKey(const ValueKey('call-button')));
        await tester.pumpAndSettle();
        expect(find.text('Call with'), findsOneWidget);
      },
    );
  });

  group('Favorites tab', () {
    testWidgets('starred grid + frequent list; tap calls; long-press actions', (
      tester,
    ) async {
      final now = DateTime.now();
      final p = FakeDialerPlatform(
        contacts: const [anu, bindu],
        callLog: [
          CallLogEntry(
            id: '1',
            number: '9847012345',
            type: CallType.outgoing,
            date: now,
          ),
        ],
      );
      await pumpApp(tester, p);
      await openTab(tester, 'Favorites');
      expect(find.byKey(const ValueKey('fav-bindu')), findsOneWidget);
      expect(find.byKey(const ValueKey('frequent-anu')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('fav-bindu')));
      await tester.pumpAndSettle();
      expect(p.placedCalls, [('04712345678', null)]);

      await tester.longPress(find.byKey(const ValueKey('fav-bindu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('fav-action-message')));
      await tester.pumpAndSettle();
      expect(p.log, contains('sms:04712345678'));
    });

    testWidgets('empty state', (tester) async {
      await pumpApp(tester, FakeDialerPlatform(contacts: const [anu]));
      await openTab(tester, 'Favorites');
      expect(find.text('Star contacts to see them here'), findsOneWidget);
    });

    testWidgets(
      'starring from contact details updates favorites and launcher shortcuts',
      (tester) async {
        final p = FakeDialerPlatform(contacts: const [anu]);
        await pumpApp(tester, p);
        await openTab(tester, 'Contacts');
        await tester.tap(find.text('Anu Mathew'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('star-toggle')));
        await tester.pumpAndSettle();
        expect(p.log, contains('star:anu:true'));
        expect(find.text('Remove favorite'), findsOneWidget);
        expect(p.shortcuts.map((s) => s.id), ['anu']);
        await tester.tapAt(const Offset(200, 40));
        await tester.pumpAndSettle();
        await openTab(tester, 'Favorites');
        expect(find.byKey(const ValueKey('fav-anu')), findsOneWidget);
      },
    );

    testWidgets('starring needs contacts write access; denial is explained', (
      tester,
    ) async {
      final p = FakeDialerPlatform(
        contacts: const [anu],
        access: FakeDialerPlatform.allGranted().withResults({
          AppPermission.writeContacts: PermissionStatus.permanentlyDenied,
        }),
      );
      await pumpApp(tester, p);
      await openTab(tester, 'Contacts');
      await tester.tap(find.text('Anu Mathew'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('star-toggle')));
      await tester.pumpAndSettle();
      expect(p.log.where((e) => e.startsWith('star:')), isEmpty);
      expect(
        find.text('Contacts access is needed to change favorites'),
        findsOneWidget,
      );
    });

    testWidgets('add to home screen pins a shortcut', (tester) async {
      final p = FakeDialerPlatform(contacts: const [anu]);
      await pumpApp(tester, p);
      await openTab(tester, 'Contacts');
      await tester.tap(find.text('Anu Mathew'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pin-9847012345')));
      await tester.pumpAndSettle();
      expect(p.pinned.single.number, '9847012345');
    });

    testWidgets('shortcuts setting off clears launcher shortcuts', (
      tester,
    ) async {
      final p = FakeDialerPlatform(contacts: const [bindu]);
      await pumpApp(tester, p);
      await openTab(tester, 'Favorites');
      expect(p.shortcuts.length, 1);
      await openSettings(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('toggle-shortcuts')),
        200,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('settings-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('toggle-shortcuts')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('toggle-shortcuts')));
      await tester.pumpAndSettle();
      expect(p.shortcuts, isEmpty);
    });
  });

  group('Settings', () {
    testWidgets('theme, accent and keypad size apply immediately and persist', (
      tester,
    ) async {
      final p = FakeDialerPlatform();
      await pumpApp(tester, p);
      final before = Theme.of(
        tester.element(find.byKey(const ValueKey('open-settings'))),
      ).colorScheme.primary;
      await openSettings(tester);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('accent-purple')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Large'));
      await tester.pumpAndSettle();
      final saved = AppSettings.decode(p.appData);
      expect(saved.theme, ThemePreference.dark);
      expect(saved.accent, AccentColor.purple);
      expect(saved.keypadSize, KeypadSize.large);
      await tester.pageBack();
      await tester.pumpAndSettle();
      final theme = Theme.of(
        tester.element(find.byKey(const ValueKey('call-button'))),
      );
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, isNot(before));
    });

    testWidgets('dynamic accent offered only when the device provides one', (
      tester,
    ) async {
      await pumpApp(tester, FakeDialerPlatform());
      await openSettings(tester);
      expect(find.byKey(const ValueKey('accent-dynamic')), findsNothing);
    });

    testWidgets('dynamic accent chip shown on Android 12+', (tester) async {
      await pumpApp(tester, FakeDialerPlatform(dynamicAccent: 0xFF336699));
      await openSettings(tester);
      expect(find.byKey(const ValueKey('accent-dynamic')), findsOneWidget);
    });

    testWidgets('keypad tones follow the setting', (tester) async {
      final p = FakeDialerPlatform();
      await pumpApp(tester, p);
      await typeDigits(tester, '5');
      expect(p.log, contains('tone:5'));
      p.log.clear();
      await openSettings(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('toggle-tones')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('toggle-tones')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await typeDigits(tester, '6');
      expect(p.log.where((e) => e.startsWith('tone:')), isEmpty);
    });

    testWidgets('clear app data resets everything Smart Dial stored', (
      tester,
    ) async {
      final p = FakeDialerPlatform(
        appData: settingsJson(
          AppSettings.defaults
              .copyWith(theme: ThemePreference.dark)
              .withSpeedDial(4, const SpeedDialEntry(number: '444')),
        ),
      );
      await pumpApp(tester, p);
      await openSettings(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('clear-app-data')),
        300,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('settings-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('clear-app-data')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('clear-app-data')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-clear')));
      await tester.pumpAndSettle();
      expect(p.log, contains('clearAppData'));
      expect(find.text('Smart Dial data cleared'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        Theme.of(
          tester.element(find.byKey(const ValueKey('call-button'))),
        ).brightness,
        Brightness.light,
      );
    });

    testWidgets('settings survive 2x font scale', (tester) async {
      await pumpApp(
        tester,
        FakeDialerPlatform(),
        textScale: 2.0,
        size: const Size(360, 640),
      );
      await openSettings(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('Intents & notifications', () {
    testWidgets('launcher shortcut places the call on start', (tester) async {
      final p = FakeDialerPlatform(
        initialIntent: const AppIntent(
          AppIntentAction.call,
          number: '9847012345',
        ),
      );
      await pumpApp(tester, p);
      expect(p.placedCalls, [('9847012345', null)]);
    });

    testWidgets(
      'missed-call notification opens Recents and marks missed calls seen',
      (tester) async {
        final p = FakeDialerPlatform();
        await pumpApp(tester, p);
        p.emitIntent(const AppIntent(AppIntentAction.openTab, tab: 'recents'));
        await tester.pumpAndSettle();
        expect(find.text('No recent calls'), findsOneWidget);
        expect(p.log, contains('markMissedRead'));
      },
    );
  });

  group('Recents (advanced)', () {
    final now = DateTime.now();
    List<CallLogEntry> log() => [
      CallLogEntry(
        id: '1',
        number: '1111111',
        type: CallType.rejected,
        date: now,
        accountId: 'a',
      ),
      CallLogEntry(
        id: '2',
        number: '2222222',
        type: CallType.blocked,
        date: now,
        accountId: 'b',
      ),
      CallLogEntry(
        id: '3',
        number: '3333333',
        type: CallType.outgoing,
        date: now,
        accountId: 'b',
      ),
    ];

    testWidgets('declined filter', (tester) async {
      await pumpApp(tester, FakeDialerPlatform(callLog: log(), countryIso: ''));
      await openTab(tester, 'Recents');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('filter-declined')),
        100,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('recents-filters')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('filter-declined')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter-declined')));
      await tester.pumpAndSettle();
      expect(find.textContaining('1111111'), findsOneWidget);
      expect(find.textContaining('2222222'), findsOneWidget);
      expect(find.textContaining('3333333'), findsNothing);
    });

    testWidgets('SIM filter appears with two SIMs', (tester) async {
      await pumpApp(
        tester,
        FakeDialerPlatform(callLog: log(), accounts: dualSim, countryIso: ''),
      );
      await openTab(tester, 'Recents');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('sim-filter-b')),
        100,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('recents-filters')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('sim-filter-b')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sim-filter-b')));
      await tester.pumpAndSettle();
      expect(find.textContaining('1111111'), findsNothing);
      expect(find.textContaining('3333333'), findsOneWidget);
    });

    testWidgets('unknown number can be added to contacts or messaged', (
      tester,
    ) async {
      final p = FakeDialerPlatform(callLog: log(), countryIso: '');
      await pumpApp(tester, p);
      await openTab(tester, 'Recents');
      await tester.tap(find.textContaining('3333333'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('recent-add-contact')));
      await tester.pumpAndSettle();
      expect(p.log, contains('add:3333333'));
      await tester.tap(find.textContaining('3333333'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('recent-message')));
      await tester.pumpAndSettle();
      expect(p.log, contains('sms:3333333'));
    });
  });

  testWidgets('favorites grid survives 2x font scale', (tester) async {
    await pumpApp(
      tester,
      FakeDialerPlatform(contacts: const [bindu, anu]),
      textScale: 2.0,
      size: const Size(360, 640),
    );
    await openTab(tester, 'Favorites');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Malayalam: new screens render', (tester) async {
    await pumpApp(
      tester,
      FakeDialerPlatform(contacts: const [bindu]),
      locale: const Locale('ml'),
    );
    await openTab(tester, 'പ്രിയപ്പെട്ടവ');
    expect(tester.takeException(), isNull);
    await openSettings(tester);
    expect(find.text('ക്രമീകരണങ്ങൾ'), findsOneWidget);
  });
}
