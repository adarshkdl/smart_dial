import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_dial/domain/access_state.dart';
import 'package:smart_dial/domain/call_log.dart';
import 'package:smart_dial/domain/contact.dart';
import 'package:smart_dial/platform/dialer_platform.dart';

import '../support/fake_dialer_platform.dart';

final _now = DateTime.now();

List<CallLogEntry> sampleLog() => [
  CallLogEntry(
    id: '1',
    number: '9847012345',
    name: 'Anu Mathew',
    type: CallType.missed,
    date: _now.subtract(const Duration(minutes: 5)),
  ),
  CallLogEntry(
    id: '2',
    number: '+919847012345',
    name: 'Anu Mathew',
    type: CallType.incoming,
    date: _now.subtract(const Duration(minutes: 10)),
    duration: const Duration(seconds: 65),
  ),
  CallLogEntry(
    id: '3',
    number: '4155550100',
    type: CallType.outgoing,
    date: _now.subtract(const Duration(minutes: 20)),
  ),
  CallLogEntry(
    id: '4',
    number: '',
    type: CallType.missed,
    date: _now.subtract(const Duration(minutes: 30)),
  ),
];

const sampleContacts = [
  Contact(
    id: '1',
    name: 'Anu Mathew',
    company: 'Acme',
    phones: [ContactPhone('9847012345', label: 'Mobile')],
  ),
  Contact(
    id: '2',
    name: 'Bindu Nair',
    phones: [
      ContactPhone('9847000001', label: 'Mobile'),
      ContactPhone('04712345678', label: 'Work'),
    ],
  ),
  Contact(id: '3', name: 'No Number'),
];

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Recents', () {
    testWidgets('groups same-number calls and labels private numbers', (
      tester,
    ) async {
      await pumpApp(tester, FakeDialerPlatform(callLog: sampleLog()));
      await openTab(tester, 'Recents');
      expect(find.text('Anu Mathew (2)'), findsOneWidget);
      expect(find.text('Private number'), findsOneWidget);
      // Device country is IN, so a bare 10-digit number gets Indian 5+5 grouping.
      expect(find.text('41555 50100'), findsOneWidget);
    });

    testWidgets('missed filter and search', (tester) async {
      await pumpApp(tester, FakeDialerPlatform(callLog: sampleLog()));
      await openTab(tester, 'Recents');
      await tester.tap(find.byKey(const ValueKey('filter-missed')));
      await tester.pumpAndSettle();
      expect(
        find.text('Anu Mathew'),
        findsOneWidget,
        reason: 'only the missed call remains in the group',
      );
      expect(find.text('41555 50100'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('filter-all')));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('recents-search')),
          matching: find.byType(TextField),
        ),
        '555',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Anu'), findsNothing);
      expect(find.text('41555 50100'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('recents-search')),
          matching: find.byType(TextField),
        ),
        'zzz',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);
    });

    testWidgets('one-tap callback', (tester) async {
      final p = FakeDialerPlatform(callLog: sampleLog());
      await pumpApp(tester, p);
      await openTab(tester, 'Recents');
      await tester.tap(find.byKey(const ValueKey('recent-call-1')));
      await tester.pumpAndSettle();
      expect(p.placedCalls, [('9847012345', null)]);
    });

    testWidgets('delete a group from the detail sheet', (tester) async {
      final p = FakeDialerPlatform(callLog: sampleLog());
      await pumpApp(tester, p);
      await openTab(tester, 'Recents');
      await tester.tap(find.text('Anu Mathew (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-entry')));
      await tester.pumpAndSettle();
      expect(p.log, contains('delete:1,2'));
      expect(find.textContaining('Anu Mathew'), findsNothing);
      expect(find.text('Deleted'), findsOneWidget);
    });

    testWidgets('empty call log', (tester) async {
      await pumpApp(tester, FakeDialerPlatform());
      await openTab(tester, 'Recents');
      expect(find.text('No recent calls'), findsOneWidget);
    });

    testWidgets('load error offers retry', (tester) async {
      final p = FakeDialerPlatform()
        ..callLogError = const DialerException('query_failed');
      await pumpApp(tester, p);
      await openTab(tester, 'Recents');
      expect(find.text("Couldn't load this list"), findsOneWidget);
      p
        ..callLogError = null
        ..callLog = sampleLog();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Anu Mathew (2)'), findsOneWidget);
    });

    testWidgets(
      'permission asked on first visit; permanent denial routes to Settings',
      (tester) async {
        final p = FakeDialerPlatform(
          access: FakeDialerPlatform.noneGranted(defaultDialer: true),
          grantOnRequest: false,
        );
        await pumpApp(tester, p);
        expect(p.permissionRequests, isEmpty);
        await openTab(tester, 'Recents');
        expect(p.permissionRequests.single, [AppPermission.readCallLog]);
        expect(find.text('See your call history'), findsOneWidget);
        await tester.tap(find.text('Open settings'));
        await tester.pumpAndSettle();
        expect(p.log, contains('openAppSettings'));
      },
    );

    testWidgets('permission granted on first visit loads the list', (
      tester,
    ) async {
      final p = FakeDialerPlatform(
        access: FakeDialerPlatform.noneGranted(defaultDialer: true),
        callLog: sampleLog(),
      );
      await pumpApp(tester, p);
      await openTab(tester, 'Recents');
      expect(find.text('Anu Mathew (2)'), findsOneWidget);
    });

    testWidgets('revoked permission while running shows the denied state', (
      tester,
    ) async {
      final p = FakeDialerPlatform(callLog: sampleLog());
      await pumpApp(tester, p);
      await openTab(tester, 'Recents');
      expect(find.text('Anu Mathew (2)'), findsOneWidget);
      p.access = p.access.withResults({
        AppPermission.readCallLog: PermissionStatus.denied,
      });
      await backgroundAndResume(tester);
      expect(find.text('Allow access'), findsOneWidget);
    });
  });

  group('Contacts', () {
    testWidgets('lists contacts with numbers and searches', (tester) async {
      await pumpApp(tester, FakeDialerPlatform(contacts: sampleContacts));
      await openTab(tester, 'Contacts');
      expect(find.text('Anu Mathew'), findsOneWidget);
      expect(find.text('Bindu Nair'), findsOneWidget);
      expect(find.text('No Number'), findsNothing);

      final field = find.descendant(
        of: find.byKey(const ValueKey('contacts-search')),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'acme');
      await tester.pumpAndSettle();
      expect(find.text('Anu Mathew'), findsOneWidget);
      expect(find.text('Bindu Nair'), findsNothing);

      await tester.enterText(field, '0471');
      await tester.pumpAndSettle();
      expect(find.text('Bindu Nair'), findsOneWidget);
    });

    testWidgets('detail sheet shows every number and calls the chosen one', (
      tester,
    ) async {
      final p = FakeDialerPlatform(contacts: sampleContacts);
      await pumpApp(tester, p);
      await openTab(tester, 'Contacts');
      await tester.tap(find.text('Bindu Nair'));
      await tester.pumpAndSettle();
      expect(find.text('Work'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('phone-04712345678')));
      await tester.pumpAndSettle();
      expect(p.placedCalls, [('04712345678', null)]);
    });

    testWidgets('empty address book', (tester) async {
      await pumpApp(tester, FakeDialerPlatform());
      await openTab(tester, 'Contacts');
      expect(find.text('No contacts on this phone'), findsOneWidget);
    });

    testWidgets('denied permission can be requested again', (tester) async {
      final p = FakeDialerPlatform(
        access: FakeDialerPlatform.noneGranted(defaultDialer: true),
        grantOnRequest: false,
        contacts: sampleContacts,
      );
      await pumpApp(tester, p);
      // Simulate a plain (not permanent) denial so the Allow button is shown.
      p.grantOnRequest = true;
      await openTab(tester, 'Contacts');
      expect(find.text('Anu Mathew'), findsOneWidget);
    });
  });
}
