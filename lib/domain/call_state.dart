/// Live call models parsed from the native `CallManager` snapshot.
library;

enum CallStatus {
  newCall,
  dialing,
  ringing,
  holding,
  active,
  disconnected,
  selectPhoneAccount,
  connecting,
  disconnecting,
  unknown,
}

/// Maps `android.telecom.Call.STATE_*`.
CallStatus callStatusFromAndroid(int? v) => switch (v) {
  0 => CallStatus.newCall,
  1 => CallStatus.dialing,
  2 => CallStatus.ringing,
  3 => CallStatus.holding,
  4 => CallStatus.active,
  7 => CallStatus.disconnected,
  8 => CallStatus.selectPhoneAccount,
  9 => CallStatus.connecting,
  10 => CallStatus.disconnecting,
  11 => CallStatus.connecting, // pulling
  12 => CallStatus.connecting, // audio processing (call screening)
  13 => CallStatus.ringing, // simulated ringing
  _ => CallStatus.unknown,
};

class ActiveCall {
  const ActiveCall({
    required this.id,
    required this.status,
    this.number = '',
    this.name,
    this.connectTime,
    this.canHold = false,
    this.canSwap = false,
    this.canMute = true,
    this.isConference = false,
    this.isIncoming = false,
    this.disconnectLabel,
  });

  final String id;
  final String number;
  final String? name;
  final CallStatus status;
  final DateTime? connectTime;
  final bool canHold;
  final bool canSwap;
  final bool canMute;
  final bool isConference;
  final bool isIncoming;
  final String? disconnectLabel;

  bool get isRinging => status == CallStatus.ringing;
  bool get isLive =>
      status != CallStatus.disconnected && status != CallStatus.disconnecting;
  bool get isOnHold => status == CallStatus.holding;

  Duration elapsed(DateTime now) {
    final t = connectTime;
    if (t == null ||
        status != CallStatus.active && status != CallStatus.holding) {
      return Duration.zero;
    }
    final d = now.difference(t);
    return d.isNegative ? Duration.zero : d;
  }

  factory ActiveCall.fromMap(Map<Object?, Object?> m) {
    final connect = (m['connectTimeMillis'] as num?)?.toInt() ?? 0;
    final name = m['name'] as String?;
    return ActiveCall(
      id: '${m['id']}',
      number: (m['number'] as String?) ?? '',
      name: name == null || name.trim().isEmpty ? null : name.trim(),
      status: callStatusFromAndroid((m['state'] as num?)?.toInt()),
      connectTime: connect > 0
          ? DateTime.fromMillisecondsSinceEpoch(connect)
          : null,
      canHold: m['canHold'] == true,
      canSwap: m['canSwap'] == true,
      canMute: m['canMute'] != false,
      isConference: m['isConference'] == true,
      isIncoming: m['isIncoming'] == true,
      disconnectLabel: m['disconnectLabel'] as String?,
    );
  }
}

/// `android.telecom.CallAudioState.ROUTE_*` bit values.
abstract final class AudioRoute {
  static const earpiece = 1;
  static const bluetooth = 2;
  static const wiredHeadset = 4;
  static const speaker = 8;
}

class CallAudio {
  const CallAudio({
    this.muted = false,
    this.route = AudioRoute.earpiece,
    this.supportedMask = AudioRoute.earpiece | AudioRoute.speaker,
    this.bluetoothName,
  });

  final bool muted;
  final int route;
  final int supportedMask;
  final String? bluetoothName;

  bool supports(int r) => supportedMask & r != 0;
  bool get onSpeaker => route == AudioRoute.speaker;
  bool get onBluetooth => route == AudioRoute.bluetooth;

  /// Route to return to when speaker is turned off.
  int get privateRoute {
    if (supports(AudioRoute.bluetooth)) return AudioRoute.bluetooth;
    if (supports(AudioRoute.wiredHeadset)) return AudioRoute.wiredHeadset;
    return AudioRoute.earpiece;
  }

  factory CallAudio.fromMap(Map<Object?, Object?> m) => CallAudio(
    muted: m['muted'] == true,
    route: (m['route'] as num?)?.toInt() ?? AudioRoute.earpiece,
    supportedMask:
        (m['supportedRouteMask'] as num?)?.toInt() ??
        (AudioRoute.earpiece | AudioRoute.speaker),
    bluetoothName: m['bluetoothName'] as String?,
  );
}

class CallSnapshot {
  const CallSnapshot({this.calls = const [], this.audio = const CallAudio()});

  static const empty = CallSnapshot();

  final List<ActiveCall> calls;
  final CallAudio audio;

  bool get hasCalls => calls.isNotEmpty;

  /// The call the in-call screen focuses on: a ringing call wins (call waiting),
  /// then active, then dialing/connecting, then held, then whatever is left.
  ActiveCall? get primary {
    if (calls.isEmpty) return null;
    const order = [
      CallStatus.ringing,
      CallStatus.active,
      CallStatus.dialing,
      CallStatus.connecting,
      CallStatus.newCall,
      CallStatus.selectPhoneAccount,
      CallStatus.holding,
    ];
    for (final s in order) {
      for (final c in calls) {
        if (c.status == s) return c;
      }
    }
    return calls.first;
  }

  /// Other live calls (e.g. the one on hold during call waiting).
  List<ActiveCall> get others {
    final p = primary;
    return [
      for (final c in calls)
        if (c.id != p?.id && c.isLive) c,
    ];
  }

  factory CallSnapshot.fromMap(Map<Object?, Object?> m) {
    final rawCalls = (m['calls'] as List<Object?>?) ?? const [];
    final audio = m['audio'];
    return CallSnapshot(
      calls: [
        for (final c in rawCalls)
          if (c is Map) ActiveCall.fromMap(c),
      ],
      audio: audio is Map ? CallAudio.fromMap(audio) : const CallAudio(),
    );
  }
}
