import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_dial/domain/access_state.dart';
import 'package:smart_dial/domain/sim.dart';
import 'package:smart_dial/platform/dialer_platform.dart';

import '../support/fake_dialer_platform.dart';

Future<void> typeDigits(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.byKey(ValueKey('dialkey-$d')));
    await tester.pump();
  }
}

String displayed(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('number-display')))
    .data!
    .trim();

void main() {
  testWidgets('typing shows a country-formatted number', (tester) async {
    await pumpApp(tester, FakeDialerPlatform(countryIso: 'IN'));
    await typeDigits(tester, '9847012345');
    expect(displayed(tester), '98470 12345');
  });

  testWidgets('backspace deletes one digit, long-press clears', (tester) async {
    await pumpApp(tester, FakeDialerPlatform());
    await typeDigits(tester, '123');
    await tester.tap(find.byKey(const ValueKey('backspace')));
    await tester.pump();
    expect(displayed(tester), '12');
    await tester.longPress(find.byKey(const ValueKey('backspace')));
    await tester.pumpAndSettle();
    expect(displayed(tester), '');
    expect(find.byKey(const ValueKey('backspace')), findsNothing);
  });

  testWidgets('long-press 0 enters +', (tester) async {
    await pumpApp(tester, FakeDialerPlatform(countryIso: ''));
    await tester.longPress(find.byKey(const ValueKey('dialkey-0')));
    await tester.pump();
    await typeDigits(tester, '91');
    expect(displayed(tester), '+91');
  });

  testWidgets('empty number shows an error and places no call', (tester) async {
    final p = FakeDialerPlatform();
    await pumpApp(tester, p);
    await tester.tap(find.byKey(const ValueKey('call-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('number-error')), findsOneWidget);
    expect(find.text('Enter a number'), findsOneWidget);
    expect(p.placedCalls, isEmpty);
  });

  testWidgets('too-short number is rejected', (tester) async {
    final p = FakeDialerPlatform();
    await pumpApp(tester, p);
    await typeDigits(tester, '12');
    await tester.tap(find.byKey(const ValueKey('call-button')));
    await tester.pumpAndSettle();
    expect(find.text("That doesn't look like a valid number"), findsOneWidget);
    expect(p.placedCalls, isEmpty);
  });

  testWidgets('valid number is placed, normalized, on the default SIM', (
    tester,
  ) async {
    final p = FakeDialerPlatform();
    await pumpApp(tester, p);
    await typeDigits(tester, '9847012345');
    await tester.tap(find.byKey(const ValueKey('call-button')));
    await tester.pumpAndSettle();
    expect(p.placedCalls, [('9847012345', null)]);
  });

  testWidgets('emergency number is passed straight to the platform', (
    tester,
  ) async {
    final p = FakeDialerPlatform(countryIso: 'IN');
    await pumpApp(tester, p);
    await typeDigits(tester, '112');
    await tester.tap(find.byKey(const ValueKey('call-button')));
    await tester.pumpAndSettle();
    expect(p.placedCalls, [('112', null)]);
  });

  testWidgets('dual SIM without a default asks which SIM', (tester) async {
    final p = FakeDialerPlatform(
      accounts: const PhoneAccounts(
        permitted: true,
        accounts: [
          PhoneAccount(id: 'a', label: 'Jio', slot: 0),
          PhoneAccount(id: 'b', label: 'Airtel', slot: 1),
        ],
      ),
    );
    await pumpApp(tester, p);
    await typeDigits(tester, '9847012345');
    await tester.tap(find.byKey(const ValueKey('call-button')));
    await tester.pumpAndSettle();
    expect(find.text('Call with'), findsOneWidget);
    await tester.tap(find.text('Airtel'));
    await tester.pumpAndSettle();
    expect(p.placedCalls, [('9847012345', 'b')]);
  });

  testWidgets('dismissing the SIM picker cancels the call', (tester) async {
    final p = FakeDialerPlatform(
      accounts: const PhoneAccounts(
        permitted: true,
        accounts: [
          PhoneAccount(id: 'a', label: 'Jio'),
          PhoneAccount(id: 'b', label: 'Airtel', slot: 1),
        ],
      ),
    );
    await pumpApp(tester, p);
    await typeDigits(tester, '9847012345');
    await tester.tap(find.byKey(const ValueKey('call-button')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 50)); // scrim
    await tester.pumpAndSettle();
    expect(p.placedCalls, isEmpty);
  });

  testWidgets('dual SIM with a system default does not ask', (tester) async {
    final p = FakeDialerPlatform(
      accounts: const PhoneAccounts(
        permitted: true,
        defaultId: 'a',
        accounts: [
          PhoneAccount(id: 'a', label: 'Jio'),
          PhoneAccount(id: 'b', label: 'Airtel', slot: 1),
        ],
      ),
    );
    await pumpApp(tester, p);
    await typeDigits(tester, '9847012345');
    await tester.tap(find.byKey(const ValueKey('call-button')));
    await tester.pumpAndSettle();
    expect(find.text('Call with'), findsNothing);
    expect(p.placedCalls, [('9847012345', null)]);
  });

  testWidgets('call permission requested just-in-time; denial is explained', (
    tester,
  ) async {
    final p = FakeDialerPlatform(
      access: FakeDialerPlatform.noneGranted(),
      grantOnRequest: false,
    );
    await pumpApp(tester, p);
    expect(
      p.permissionRequests,
      isEmpty,
      reason: 'nothing requested before the user acts',
    );
    await typeDigits(tester, '9847012345');
    await tester.tap(find.byKey(const ValueKey('call-button')));
    await tester.pumpAndSettle();
    expect(p.permissionRequests.single, containsAll([AppPermission.callPhone]));
    expect(
      find.text('Phone permission is needed to place calls'),
      findsOneWidget,
    );
    expect(p.placedCalls, isEmpty);
  });

  testWidgets('call permission granted on request then call proceeds', (
    tester,
  ) async {
    final p = FakeDialerPlatform(access: FakeDialerPlatform.noneGranted());
    await pumpApp(tester, p);
    await typeDigits(tester, '9847012345');
    await tester.tap(find.byKey(const ValueKey('call-button')));
    await tester.pumpAndSettle();
    expect(p.placedCalls.length, 1);
  });

  testWidgets('platform failure shows an error', (tester) async {
    final p = FakeDialerPlatform()
      ..placeCallError = const DialerException(DialerException.callFailed);
    await pumpApp(tester, p);
    await typeDigits(tester, '9847012345');
    await tester.tap(find.byKey(const ValueKey('call-button')));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't place the call"), findsOneWidget);
  });

  testWidgets('DIAL intent number pre-fills the keypad', (tester) async {
    await pumpApp(tester, FakeDialerPlatform(initialNumber: '+91 98470 12345'));
    expect(displayed(tester), '+91 98470 12345');
  });

  testWidgets('keypad keys have spoken labels', (tester) async {
    await pumpApp(tester, FakeDialerPlatform());
    expect(find.bySemanticsLabel('2, A B C'), findsOneWidget);
    expect(find.bySemanticsLabel('pound'), findsOneWidget);
  });
}
