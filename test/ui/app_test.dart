import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_dial/domain/access_state.dart';

import '../support/fake_dialer_platform.dart';

void main() {
  group('Default Phone role', () {
    testWidgets(
      'banner offered when not default; granting hides it and asks for notifications',
      (tester) async {
        final p = FakeDialerPlatform(
          access: FakeDialerPlatform.allGranted(defaultDialer: false)
              .withResults({
                AppPermission.postNotifications: PermissionStatus.denied,
              }),
        );
        await pumpApp(tester, p);
        expect(
          find.byKey(const ValueKey('default-role-banner')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('default-role-action')));
        await tester.pumpAndSettle();
        expect(p.log, contains('requestDefaultDialer'));
        expect(
          p.permissionRequests,
          anyElement(equals([AppPermission.postNotifications])),
        );
        expect(find.byKey(const ValueKey('default-role-banner')), findsNothing);
      },
    );

    testWidgets('declining keeps the banner and the app usable', (
      tester,
    ) async {
      final p = FakeDialerPlatform(
        access: FakeDialerPlatform.allGranted(defaultDialer: false),
        grantRoleOnRequest: false,
      );
      await pumpApp(tester, p);
      await tester.tap(find.byKey(const ValueKey('default-role-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('default-role-banner')), findsOneWidget);
      // Basic-dialer fallback still places calls through Telecom.
      await tester.tap(find.byKey(const ValueKey('dialkey-1')));
      await tester.tap(find.byKey(const ValueKey('dialkey-2')));
      await tester.tap(find.byKey(const ValueKey('dialkey-1')));
      await tester.tap(find.byKey(const ValueKey('call-button')));
      await tester.pumpAndSettle();
      expect(p.placedCalls, [('121', null)]);
    });

    testWidgets('"Not now" dismisses the banner', (tester) async {
      await pumpApp(
        tester,
        FakeDialerPlatform(
          access: FakeDialerPlatform.allGranted(defaultDialer: false),
        ),
      );
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('default-role-banner')), findsNothing);
    });

    testWidgets('role revoked in Settings is detected on resume', (
      tester,
    ) async {
      final p = FakeDialerPlatform();
      await pumpApp(tester, p);
      expect(find.byKey(const ValueKey('default-role-banner')), findsNothing);
      p.access = p.access.withDefaultDialer(false);
      await backgroundAndResume(tester);
      expect(find.byKey(const ValueKey('default-role-banner')), findsOneWidget);
    });

    testWidgets('no banner on devices without the dialer role', (tester) async {
      final a = FakeDialerPlatform.allGranted(defaultDialer: false);
      await pumpApp(
        tester,
        FakeDialerPlatform(
          access: AccessState(permissions: a.permissions, loaded: true),
        ),
      );
      expect(find.byKey(const ValueKey('default-role-banner')), findsNothing);
    });
  });

  testWidgets('DIAL intent while on another tab switches to the keypad', (
    tester,
  ) async {
    final p = FakeDialerPlatform();
    await pumpApp(tester, p);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Recents'),
      ),
    );
    await tester.pumpAndSettle();
    p.emitDialIntent('9847012345');
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('number-display'))).data,
      '98470 12345',
    );
  });

  group('Localization & accessibility', () {
    testWidgets('Malayalam UI renders', (tester) async {
      await pumpApp(tester, FakeDialerPlatform(), locale: const Locale('ml'));
      expect(find.text('കീപാഡ്'), findsOneWidget);
      expect(find.text('സമീപകാലം'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keypad survives 2x font scale on a small phone', (
      tester,
    ) async {
      await pumpApp(
        tester,
        FakeDialerPlatform(
          access: FakeDialerPlatform.allGranted(defaultDialer: false),
        ),
        textScale: 2.0,
        size: const Size(360, 640),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('call-button')), findsOneWidget);
    });

    testWidgets('dark theme builds', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpApp(tester, FakeDialerPlatform());
      final ctx = tester.element(find.byKey(const ValueKey('call-button')));
      expect(Theme.of(ctx).brightness, Brightness.dark);
    });

    testWidgets('tap targets meet Android guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, FakeDialerPlatform());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
