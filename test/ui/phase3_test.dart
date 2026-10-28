import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_dial/domain/access_state.dart';
import 'package:smart_dial/domain/app_settings.dart';
import 'package:smart_dial/domain/call_log.dart';
import 'package:smart_dial/domain/contact.dart';
import 'package:smart_dial/domain/diagnostics.dart';
import 'package:smart_dial/domain/notes.dart';
import 'package:smart_dial/domain/reminder.dart';
import 'package:smart_dial/platform/dialer_platform.dart';

import '../support/fake_dialer_platform.dart';

const anu = Contact(
  id: 'anu',
  name: 'Anu Mathew',
  phones: [ContactPhone('9847012345', label: 'Mobile')],
);

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

Future<void> scrollSettingsTo(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    300,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('settings-list')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
}

/// Scrolls inside the open bottom sheet until [finder] is visible.
Future<void> scrollSheetTo(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find.byType(SingleChildScrollView).last,
    const Offset(0, -200),
  );
  await tester.pumpAndSettle();
}

List<CallLogEntry> log() => [
  CallLogEntry(
    id: '1',
    number: '9847012345',
    name: 'Anu Mathew',
    type: CallType.missed,
    date: DateTime.now(),
  ),
];

String notesJson(String number, String text) {
  final now = DateTime.now();
  return const NotesBook()
      .upsert(
        CallNote(
          id: 'n1',
          number: number,
          text: text,
          createdAt: now,
          updatedAt: now,
        ),
      )
      .encode();
}

void main() {
  group('Notes', () {
    testWidgets('add, edit and delete a note from contact details', (
      tester,
    ) async {
      final p = FakeDialerPlatform(contacts: const [anu]);
      await pumpApp(tester, p);
      await openTab(tester, 'Contacts');
      await tester.tap(find.text('Anu Mathew'));
      await tester.pumpAndSettle();
      await scrollSheetTo(tester, find.byKey(const ValueKey('add-note')));
      await tester.tap(find.byKey(const ValueKey('add-note')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('note-field')),
        'Prefers calls after 6 pm',
      );
      await tester.tap(find.byKey(const ValueKey('note-save')));
      await tester.pumpAndSettle();
      expect(find.text('Prefers calls after 6 pm'), findsOneWidget);
      expect(
        NotesBook.decode(
          p.blobs['notes'],
        ).forNumber('+919847012345').single.text,
        'Prefers calls after 6 pm',
      );

      // Edit
      await tester.tap(find.text('Prefers calls after 6 pm'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('note-field')),
        'After 7 pm',
      );
      await tester.tap(find.byKey(const ValueKey('note-save')));
      await tester.pumpAndSettle();
      expect(find.text('After 7 pm'), findsOneWidget);

      // Delete
      final id = NotesBook.decode(p.blobs['notes']).notes.single.id;
      await tester.tap(find.byKey(ValueKey('note-delete-$id')));
      await tester.pumpAndSettle();
      expect(find.text('After 7 pm'), findsNothing);
      expect(NotesBook.decode(p.blobs['notes']).notes, isEmpty);
    });

    testWidgets(
      'recents marks numbers that have notes and shows them in details',
      (tester) async {
        final p = FakeDialerPlatform(callLog: log())
          ..blobs['notes'] = notesJson('+91 98470 12345', 'Owes me a call');
        await pumpApp(tester, p);
        await openTab(tester, 'Recents');
        expect(find.byKey(const ValueKey('has-note-1')), findsOneWidget);
        await tester.tap(find.text('Anu Mathew'));
        await tester.pumpAndSettle();
        await scrollSheetTo(tester, find.text('Owes me a call'));
        expect(find.text('Owes me a call'), findsOneWidget);
      },
    );

    testWidgets('saving an empty edit deletes the note', (tester) async {
      final p = FakeDialerPlatform(contacts: const [anu])
        ..blobs['notes'] = notesJson('9847012345', 'temp');
      await pumpApp(tester, p);
      await openTab(tester, 'Contacts');
      await tester.tap(find.text('Anu Mathew'));
      await tester.pumpAndSettle();
      await scrollSheetTo(tester, find.text('temp'));
      await tester.tap(find.text('temp'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('note-field')), '   ');
      await tester.tap(find.byKey(const ValueKey('note-save')));
      await tester.pumpAndSettle();
      expect(NotesBook.decode(p.blobs['notes']).notes, isEmpty);
    });
  });

  group('Reminders', () {
    testWidgets('remind me to call back from Recents (quick option)', (
      tester,
    ) async {
      final p = FakeDialerPlatform(callLog: log());
      await pumpApp(tester, p);
      await openTab(tester, 'Recents');
      await tester.tap(find.text('Anu Mathew'));
      await tester.pumpAndSettle();
      await scrollSheetTo(tester, find.byKey(const ValueKey('recent-remind')));
      await tester.tap(find.byKey(const ValueKey('recent-remind')));
      await tester.pumpAndSettle();
      final before = DateTime.now();
      await tester.tap(find.byKey(const ValueKey('remind-in1Hour')));
      await tester.pumpAndSettle();
      final r = p.reminders.single;
      expect(r.number, '9847012345');
      expect(r.name, 'Anu Mathew');
      expect(r.dueAt.difference(before).inMinutes, inInclusiveRange(59, 61));
      expect(find.textContaining('Reminder set'), findsOneWidget);
      // Badge on the app bar
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('open-reminders')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('remind from contact details', (tester) async {
      final p = FakeDialerPlatform(contacts: const [anu]);
      await pumpApp(tester, p);
      await openTab(tester, 'Contacts');
      await tester.tap(find.text('Anu Mathew'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contact-remind')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('remind-in15Minutes')));
      await tester.pumpAndSettle();
      expect(p.reminders.single.name, 'Anu Mathew');
    });

    testWidgets(
      'notifications blocked: reminder is saved and the user is told',
      (tester) async {
        final p = FakeDialerPlatform(
          callLog: log(),
          access: FakeDialerPlatform.allGranted().withResults({
            AppPermission.postNotifications: PermissionStatus.permanentlyDenied,
          }),
        );
        await pumpApp(tester, p);
        await openTab(tester, 'Recents');
        await tester.tap(find.text('Anu Mathew'));
        await tester.pumpAndSettle();
        await scrollSheetTo(
          tester,
          find.byKey(const ValueKey('recent-remind')),
        );
        await tester.tap(find.byKey(const ValueKey('recent-remind')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('remind-in15Minutes')));
        await tester.pumpAndSettle();
        expect(p.reminders.length, 1);
        expect(
          find.text('Reminder saved, but notifications are off for Smart Dial'),
          findsOneWidget,
        );
      },
    );

    testWidgets('reminders screen: overdue first, complete, delete, call', (
      tester,
    ) async {
      final now = DateTime.now();
      final p = FakeDialerPlatform()
        ..reminders = [
          Reminder(
            id: 'future',
            number: '9000000001',
            name: 'Later',
            dueAt: now.add(const Duration(hours: 2)),
          ),
          Reminder(
            id: 'late',
            number: '9000000002',
            name: 'Late',
            dueAt: now.subtract(const Duration(hours: 1)),
          ),
          Reminder(
            id: 'old',
            number: '9000000003',
            name: 'Old',
            dueAt: now.subtract(const Duration(days: 1)),
            done: true,
          ),
        ];
      await pumpApp(tester, p);
      await tester.tap(find.byKey(const ValueKey('open-reminders')));
      await tester.pumpAndSettle();
      expect(find.text('Reminders'), findsOneWidget);
      final yLate = tester.getCenter(find.text('Late')).dy;
      final yLater = tester.getCenter(find.text('Later')).dy;
      final yOld = tester.getCenter(find.text('Old')).dy;
      expect(yLate < yLater && yLater < yOld, isTrue);
      expect(find.textContaining('Overdue'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('reminder-done-future')));
      await tester.pumpAndSettle();
      expect(p.log, contains('saveReminder:future:true'));

      await tester.tap(find.byKey(const ValueKey('reminder-delete-old')));
      await tester.pumpAndSettle();
      expect(p.log, contains('deleteReminder:old'));
      expect(find.text('Old'), findsNothing);

      await tester.tap(find.text('Late'));
      await tester.pumpAndSettle();
      expect(p.placedCalls, [('9000000002', null)]);
      expect(
        p.log,
        contains('saveReminder:late:true'),
        reason: 'calling completes the reminder',
      );
    });

    testWidgets('exact-alarm banner when the permission is missing', (
      tester,
    ) async {
      final p = FakeDialerPlatform()
        ..exactAlarms = false
        ..reminders = [
          Reminder(
            id: 'a',
            number: '1234567',
            dueAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        ];
      await pumpApp(tester, p);
      await tester.tap(find.byKey(const ValueKey('open-reminders')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('exact-alarm-banner')), findsOneWidget);
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
      expect(p.log, contains('exactAlarmSettings'));
    });

    testWidgets('empty state', (tester) async {
      await pumpApp(tester, FakeDialerPlatform());
      await tester.tap(find.byKey(const ValueKey('open-reminders')));
      await tester.pumpAndSettle();
      expect(find.text('No reminders'), findsOneWidget);
      expect(find.byKey(const ValueKey('exact-alarm-banner')), findsNothing);
    });

    testWidgets('tapping a reminder notification opens the reminders screen', (
      tester,
    ) async {
      final p = FakeDialerPlatform();
      await pumpApp(tester, p);
      p.emitIntent(const AppIntent(AppIntentAction.openTab, tab: 'reminders'));
      await tester.pumpAndSettle();
      expect(find.text('No reminders'), findsOneWidget);
    });

    testWidgets('changes made from the notification show up after resume', (
      tester,
    ) async {
      final p = FakeDialerPlatform()
        ..reminders = [
          Reminder(
            id: 'a',
            number: '1234567',
            dueAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        ];
      await pumpApp(tester, p);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('open-reminders')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      p.reminders = [
        p.reminders.single.copyWith(done: true),
      ]; // "Done" tapped in the notification
      await backgroundAndResume(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('open-reminders')),
          matching: find.text('1'),
        ),
        findsNothing,
      );
    });

    testWidgets('reminders screen survives 2x font scale', (tester) async {
      final p = FakeDialerPlatform()
        ..exactAlarms = false
        ..reminders = [
          Reminder(
            id: 'a',
            number: '1234567',
            name: 'A rather long contact name',
            note: 'Discuss the plan',
            dueAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        ];
      await pumpApp(tester, p, textScale: 2.0, size: const Size(360, 640));
      await tester.tap(find.byKey(const ValueKey('open-reminders')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Diagnostics', () {
    testWidgets('failures are logged without phone numbers; copy and clear', (
      tester,
    ) async {
      final p = FakeDialerPlatform()
        ..placeCallError = const DialerException(DialerException.callFailed);
      await pumpApp(tester, p);
      for (final d in '9847012345'.split('')) {
        await tester.tap(find.byKey(ValueKey('dialkey-$d')));
      }
      await tester.tap(find.byKey(const ValueKey('call-button')));
      await tester.pumpAndSettle();
      DiagnosticsSink.record('flutter', 'Exception while calling 9847012345');
      await tester.pumpAndSettle();

      await openSettings(tester);
      await scrollSettingsTo(tester, const ValueKey('open-diagnostics'));
      await tester.tap(find.byKey(const ValueKey('open-diagnostics')));
      await tester.pumpAndSettle();
      expect(find.textContaining('[placeCall] call_failed'), findsOneWidget);
      expect(
        find.textContaining('[flutter] Exception while calling <number>'),
        findsOneWidget,
      );
      expect(find.textContaining('9847012345'), findsNothing);
      expect(p.blobs['diagnostics'], isNot(contains('9847012345')));

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('copy-report')));
      await tester.pumpAndSettle();
      expect(find.text('Report copied'), findsOneWidget);
      expect(copied, contains('Smart Dial 0.3.0'));
      expect(copied, contains('call_failed'));
      expect(copied, isNot(contains('9847012345')));

      await tester.tap(find.byKey(const ValueKey('clear-diagnostics')));
      await tester.pumpAndSettle();
      expect(find.text('No problems recorded'), findsOneWidget);
    });
  });

  group('Language', () {
    testWidgets('switching to Malayalam applies immediately and persists', (
      tester,
    ) async {
      final p = FakeDialerPlatform();
      await pumpApp(tester, p, locale: null);
      await openSettings(tester);
      await tester.tap(find.text('മലയാളം'));
      await tester.pumpAndSettle();
      expect(AppSettings.decode(p.appData).language, AppLanguage.malayalam);
      expect(find.text('ക്രമീകരണങ്ങൾ'), findsOneWidget);
      await tester.tap(
        find.byType(BackButton),
      ); // pageBack() looks for an English tooltip
      await tester.pumpAndSettle();
      expect(find.text('കീപാഡ്'), findsOneWidget);
    });

    testWidgets('saved language is used on start', (tester) async {
      final p = FakeDialerPlatform(
        appData: AppSettings.defaults
            .copyWith(language: AppLanguage.malayalam)
            .encode(),
      );
      await pumpApp(tester, p, locale: null);
      expect(find.text('സമീപകാലം'), findsOneWidget);
    });
  });

  testWidgets('clear app data also removes notes and reminders', (
    tester,
  ) async {
    final p = FakeDialerPlatform(contacts: const [anu])
      ..blobs['notes'] = notesJson('9847012345', 'secret')
      ..reminders = [
        Reminder(
          id: 'a',
          number: '1234567',
          dueAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      ];
    await pumpApp(tester, p);
    await openSettings(tester);
    await scrollSettingsTo(tester, const ValueKey('clear-app-data'));
    await tester.tap(find.byKey(const ValueKey('clear-app-data')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-clear')));
    await tester.pumpAndSettle();
    expect(p.blobs, isEmpty);
    expect(p.reminders, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('open-reminders')),
        matching: find.text('1'),
      ),
      findsNothing,
    );
    await openTab(tester, 'Contacts');
    await tester.tap(find.text('Anu Mathew'));
    await tester.pumpAndSettle();
    expect(find.text('secret'), findsNothing);
  });
}
