import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_dial/domain/call_state.dart';

import '../support/fake_dialer_platform.dart';

CallSnapshot snap(
  List<ActiveCall> calls, {
  CallAudio audio = const CallAudio(),
}) => CallSnapshot(calls: calls, audio: audio);

const ringing = ActiveCall(
  id: '1',
  number: '9847012345',
  name: 'Anu Mathew',
  status: CallStatus.ringing,
  isIncoming: true,
);

Future<FakeDialerPlatform> withCall(
  WidgetTester tester,
  CallSnapshot s, {
  double textScale = 1,
}) async {
  final p = FakeDialerPlatform();
  await pumpApp(tester, p, textScale: textScale);
  p.emitCalls(s);
  await tester.pumpAndSettle();
  return p;
}

void main() {
  testWidgets('incoming call shows caller and answer / decline', (
    tester,
  ) async {
    final p = await withCall(tester, snap([ringing]));
    expect(find.text('Anu Mathew'), findsOneWidget);
    expect(find.text('98470 12345'), findsOneWidget);
    expect(find.text('Incoming call'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('answer-button')));
    await tester.pump();
    expect(p.log, contains('answer:1'));
    await tester.tap(find.byKey(const ValueKey('decline-button')));
    await tester.pump();
    expect(p.log, contains('reject:1'));
  });

  testWidgets('unknown caller shows formatted number only', (tester) async {
    await withCall(
      tester,
      snap([
        const ActiveCall(
          id: '1',
          number: '9847012345',
          status: CallStatus.ringing,
        ),
      ]),
    );
    expect(find.text('98470 12345'), findsOneWidget);
  });

  testWidgets('private caller is labelled', (tester) async {
    await withCall(
      tester,
      snap([const ActiveCall(id: '1', number: '', status: CallStatus.ringing)]),
    );
    expect(find.text('Private number'), findsOneWidget);
  });

  testWidgets('active call: timer, mute, speaker, end', (tester) async {
    final p = await withCall(
      tester,
      snap([
        ActiveCall(
          id: '7',
          number: '9847012345',
          status: CallStatus.active,
          canHold: true,
          connectTime: DateTime.now().subtract(const Duration(seconds: 65)),
        ),
      ]),
    );
    expect(find.textContaining(RegExp(r'^1:0[5-7]$')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mute-button')));
    await tester.tap(find.byKey(const ValueKey('speaker-button')));
    await tester.tap(find.byKey(const ValueKey('hold-button')));
    await tester.tap(find.byKey(const ValueKey('end-call-button')));
    await tester.pump();
    expect(
      p.log,
      containsAll([
        'mute:true',
        'route:${AudioRoute.speaker}',
        'hold:7',
        'disconnect:7',
      ]),
    );
    expect(find.byKey(const ValueKey('bluetooth-button')), findsNothing);
  });

  testWidgets('speaker off returns to bluetooth when available', (
    tester,
  ) async {
    final p = await withCall(
      tester,
      snap(
        [
          const ActiveCall(
            id: '1',
            number: '1234567',
            status: CallStatus.active,
          ),
        ],
        audio: const CallAudio(
          route: AudioRoute.speaker,
          supportedMask: 1 | 2 | 8,
          bluetoothName: 'Buds',
        ),
      ),
    );
    expect(find.text('Buds'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('speaker-button')));
    await tester.pump();
    expect(p.log, contains('route:${AudioRoute.bluetooth}'));
  });

  testWidgets('hold button hidden when the network does not allow hold', (
    tester,
  ) async {
    await withCall(
      tester,
      snap([
        const ActiveCall(id: '1', number: '1234567', status: CallStatus.active),
      ]),
    );
    expect(find.byKey(const ValueKey('hold-button')), findsNothing);
  });

  testWidgets('in-call keypad sends DTMF down/up', (tester) async {
    final p = await withCall(
      tester,
      snap([
        const ActiveCall(
          id: '3',
          number: '18001234',
          status: CallStatus.active,
        ),
      ]),
    );
    await tester.tap(find.byKey(const ValueKey('keypad-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dialkey-5')));
    await tester.tap(find.byKey(const ValueKey('dialkey-#')));
    await tester.pump();
    expect(
      p.log,
      containsAllInOrder(['dtmf:3:5', 'dtmfStop:3', 'dtmf:3:#', 'dtmfStop:3']),
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('dtmf-display'))).data,
      '5#',
    );
    await tester.tap(find.byKey(const ValueKey('hide-keypad')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mute-button')), findsOneWidget);
  });

  testWidgets(
    'call waiting: ringing second call is primary, active one shown above',
    (tester) async {
      final p = await withCall(
        tester,
        snap([
          const ActiveCall(
            id: '1',
            number: '1111111',
            name: 'Ravi',
            status: CallStatus.active,
          ),
          const ActiveCall(
            id: '2',
            number: '2222222',
            name: 'Anu',
            status: CallStatus.ringing,
          ),
        ]),
      );
      expect(find.byKey(const ValueKey('call-title')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('call-title'))).data,
        'Anu',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('other-call-title')))
            .data,
        'Ravi',
      );
      expect(find.byKey(const ValueKey('swap-button')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('answer-button')));
      await tester.pump();
      expect(p.log, contains('answer:2'));
    },
  );

  testWidgets('held call can be swapped in', (tester) async {
    final p = await withCall(
      tester,
      snap([
        const ActiveCall(
          id: '1',
          number: '1111111',
          name: 'Ravi',
          status: CallStatus.holding,
        ),
        const ActiveCall(
          id: '2',
          number: '2222222',
          name: 'Anu',
          status: CallStatus.active,
        ),
      ]),
    );
    expect(find.text('On hold: Ravi'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('swap-button')));
    await tester.pump();
    expect(p.log, contains('unhold:1'));
  });

  testWidgets('UI follows snapshots: dialing → active → ended → home', (
    tester,
  ) async {
    final p = FakeDialerPlatform();
    await pumpApp(tester, p);
    p.emitCalls(
      snap([
        const ActiveCall(
          id: '1',
          number: '1234567',
          status: CallStatus.dialing,
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Calling…'), findsOneWidget);

    p.emitCalls(
      snap([
        ActiveCall(
          id: '1',
          number: '1234567',
          status: CallStatus.active,
          connectTime: DateTime.now(),
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Calling…'), findsNothing);

    p.emitCalls(
      snap([
        const ActiveCall(
          id: '1',
          number: '1234567',
          status: CallStatus.disconnected,
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Call ended'), findsOneWidget);
    expect(find.byKey(const ValueKey('end-call-button')), findsOneWidget);

    p.emitCalls(CallSnapshot.empty);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('call-button')),
      findsOneWidget,
      reason: 'back on the keypad',
    );
  });

  testWidgets('in-call screen survives 2x font scale without overflow', (
    tester,
  ) async {
    await withCall(
      tester,
      snap([
        const ActiveCall(
          id: '1',
          number: '9847012345',
          name: 'A very long contact name for testing',
          status: CallStatus.active,
          canHold: true,
        ),
      ], audio: const CallAudio(supportedMask: 1 | 2 | 8)),
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);
  });
}
