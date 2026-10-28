import 'package:flutter_test/flutter_test.dart';
import 'package:smart_dial/domain/call_state.dart';

Map<String, Object?> callMap(
  String id,
  int state, {
  String number = '9847012345',
  String? name,
  int connect = 0,
  bool canHold = true,
}) => {
  'id': id,
  'number': number,
  'name': name,
  'state': state,
  'connectTimeMillis': connect,
  'canHold': canHold,
};

void main() {
  test('callStatusFromAndroid maps Telecom states', () {
    expect(callStatusFromAndroid(1), CallStatus.dialing);
    expect(callStatusFromAndroid(2), CallStatus.ringing);
    expect(callStatusFromAndroid(3), CallStatus.holding);
    expect(callStatusFromAndroid(4), CallStatus.active);
    expect(callStatusFromAndroid(7), CallStatus.disconnected);
    expect(callStatusFromAndroid(9), CallStatus.connecting);
    expect(callStatusFromAndroid(13), CallStatus.ringing);
    expect(callStatusFromAndroid(-5), CallStatus.unknown);
  });

  group('ActiveCall', () {
    test('fromMap and elapsed', () {
      final t = DateTime(2026, 10, 20, 10).millisecondsSinceEpoch;
      final c = ActiveCall.fromMap(callMap('1', 4, connect: t, name: ' '));
      expect(c.name, isNull);
      expect(c.status, CallStatus.active);
      expect(
        c.elapsed(DateTime(2026, 10, 20, 10, 1, 5)),
        const Duration(minutes: 1, seconds: 5),
      );
    });
    test('elapsed is zero before connect or when clock is behind', () {
      expect(
        ActiveCall.fromMap(callMap('1', 1)).elapsed(DateTime.now()),
        Duration.zero,
      );
      final future = DateTime.now()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch;
      expect(
        ActiveCall.fromMap(
          callMap('1', 4, connect: future),
        ).elapsed(DateTime.now()),
        Duration.zero,
      );
    });
    test('isLive', () {
      expect(ActiveCall.fromMap(callMap('1', 4)).isLive, isTrue);
      expect(ActiveCall.fromMap(callMap('1', 7)).isLive, isFalse);
    });
  });

  group('CallSnapshot', () {
    test('empty map', () {
      final s = CallSnapshot.fromMap(const {});
      expect(s.hasCalls, isFalse);
      expect(s.primary, isNull);
    });

    test('ringing call wins during call waiting', () {
      final s = CallSnapshot.fromMap({
        'calls': [callMap('1', 4), callMap('2', 2, number: '111')],
        'audio': {'muted': true, 'route': 8, 'supportedRouteMask': 1 | 2 | 8},
      });
      expect(s.primary!.id, '2');
      expect(s.others.map((c) => c.id), ['1']);
      expect(s.audio.muted, isTrue);
      expect(s.audio.onSpeaker, isTrue);
      expect(s.audio.supports(AudioRoute.bluetooth), isTrue);
    });

    test('active beats held', () {
      final s = CallSnapshot.fromMap({
        'calls': [callMap('1', 3), callMap('2', 4)],
      });
      expect(s.primary!.id, '2');
      expect(s.others.single.isOnHold, isTrue);
    });

    test('disconnected calls are not listed as others', () {
      final s = CallSnapshot.fromMap({
        'calls': [callMap('1', 4), callMap('2', 7)],
      });
      expect(s.others, isEmpty);
    });
  });

  group('CallAudio.privateRoute', () {
    test('prefers bluetooth, then wired, then earpiece', () {
      expect(
        const CallAudio(supportedMask: 1 | 2 | 8).privateRoute,
        AudioRoute.bluetooth,
      );
      expect(
        const CallAudio(supportedMask: 4 | 8).privateRoute,
        AudioRoute.wiredHeadset,
      );
      expect(
        const CallAudio(supportedMask: 1 | 8).privateRoute,
        AudioRoute.earpiece,
      );
    });
  });
}
