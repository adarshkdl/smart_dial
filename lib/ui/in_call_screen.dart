import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/call_log.dart';
import '../domain/call_state.dart';
import '../domain/phone_number.dart';
import '../l10n/app_localizations.dart';
import '../state/app_controller.dart';
import 'widgets/contact_avatar.dart';
import 'widgets/dial_pad.dart';

class InCallScreen extends StatefulWidget {
  const InCallScreen({super.key});

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  Timer? _ticker;
  bool _showKeypad = false;
  String _dtmf = '';

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _statusText(AppLocalizations l, ActiveCall c) => switch (c.status) {
    CallStatus.ringing => l.statusIncoming,
    CallStatus.dialing ||
    CallStatus.newCall ||
    CallStatus.selectPhoneAccount => l.statusDialing,
    CallStatus.connecting => l.statusConnecting,
    CallStatus.holding => l.statusOnHold,
    CallStatus.active => formatCallDuration(c.elapsed(DateTime.now())),
    CallStatus.disconnected || CallStatus.disconnecting =>
      c.disconnectLabel?.isNotEmpty == true
          ? c.disconnectLabel!
          : l.statusEnded,
    CallStatus.unknown => '',
  };

  String _title(AppLocalizations l, ActiveCall c, String iso) {
    if (c.name != null) return c.name!;
    if (PhoneNumbers.isPrivate(c.number)) return l.privateNumber;
    return PhoneNumbers.format(c.number, countryIso: iso);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = AppScope.of(context);
    final snap = controller.calls;
    final call = snap.primary;
    final theme = Theme.of(context);
    if (call == null) return const Scaffold();

    final iso = controller.countryIso;
    final title = _title(l, call, iso);
    final subtitle = call.name != null && !PhoneNumbers.isPrivate(call.number)
        ? PhoneNumbers.format(call.number, countryIso: iso)
        : null;
    final ringing = call.isRinging;
    final others = snap.others;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: [
            if (others.isNotEmpty)
              _OtherCallBanner(
                call: others.first,
                primary: call,
                title: _title(l, others.first, iso),
              ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      if (!_showKeypad || ringing) ...[
                        ContactAvatar(name: call.name ?? '', radius: 48),
                        const SizedBox(height: 16),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          title,
                          key: const ValueKey('call-title'),
                          style: theme.textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (subtitle != null)
                        Text(subtitle, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _statusText(l, call),
                          key: const ValueKey('call-status'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (ringing)
              _RingingControls(call: call)
            else if (_showKeypad)
              _InCallKeypad(
                call: call,
                typed: _dtmf,
                onTyped: (d) => setState(() => _dtmf += d),
                onHide: () => setState(() => _showKeypad = false),
              )
            else
              _ActiveControls(
                call: call,
                onKeypad: () => setState(() => _showKeypad = true),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _OtherCallBanner extends StatelessWidget {
  const _OtherCallBanner({
    required this.call,
    required this.primary,
    required this.title,
  });
  final ActiveCall call;
  final ActiveCall primary;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = AppScope.read(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ListTile(
        leading: const Icon(Icons.pause_circle_outline),
        title: Text(
          call.isOnHold ? l.onHoldWith(title) : title,
          key: const ValueKey('other-call-title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: primary.isRinging
            ? null
            : TextButton(
                key: const ValueKey('swap-button'),
                onPressed: () => controller.swapTo(call),
                child: Text(l.swap),
              ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.color,
    this.foreground,
    this.size = 64,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;
  final Color? color;
  final Color? foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg =
        color ?? (active ? scheme.primary : scheme.surfaceContainerHighest);
    final fg = foreground ?? (active ? scheme.onPrimary : scheme.onSurface);
    return Semantics(
      button: true,
      toggled: color == null ? active : null,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: SizedBox(
        width: size + 28,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: bg,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: size,
                  child: Icon(icon, color: fg, size: size * 0.45),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _RingingControls extends StatelessWidget {
  const _RingingControls({required this.call});
  final ActiveCall call;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = AppScope.read(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundAction(
          key: const ValueKey('decline-button'),
          icon: Icons.call_end,
          label: l.decline,
          color: Colors.red.shade600,
          foreground: Colors.white,
          size: 72,
          onPressed: () => controller.reject(call),
        ),
        _RoundAction(
          key: const ValueKey('answer-button'),
          icon: Icons.call,
          label: l.answer,
          color: Colors.green.shade600,
          foreground: Colors.white,
          size: 72,
          onPressed: () => controller.answer(call),
        ),
      ],
    );
  }
}

class _ActiveControls extends StatelessWidget {
  const _ActiveControls({required this.call, required this.onKeypad});
  final ActiveCall call;
  final VoidCallback onKeypad;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = AppScope.of(context);
    final audio = controller.calls.audio;
    final live = call.isLive;
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 16,
          children: [
            _RoundAction(
              key: const ValueKey('mute-button'),
              icon: audio.muted ? Icons.mic_off : Icons.mic_none,
              label: l.mute,
              active: audio.muted,
              onPressed: live && call.canMute ? controller.toggleMute : null,
            ),
            _RoundAction(
              key: const ValueKey('keypad-button'),
              icon: Icons.dialpad,
              label: l.keypad,
              onPressed: live ? onKeypad : null,
            ),
            _RoundAction(
              key: const ValueKey('speaker-button'),
              icon: Icons.volume_up_outlined,
              label: l.speaker,
              active: audio.onSpeaker,
              onPressed: live ? controller.toggleSpeaker : null,
            ),
            if (audio.supports(AudioRoute.bluetooth))
              _RoundAction(
                key: const ValueKey('bluetooth-button'),
                icon: Icons.bluetooth_audio,
                label: audio.bluetoothName ?? l.bluetooth,
                active: audio.onBluetooth,
                onPressed: live ? controller.toggleBluetooth : null,
              ),
            if (call.canHold || call.isOnHold)
              _RoundAction(
                key: const ValueKey('hold-button'),
                icon: call.isOnHold ? Icons.play_arrow : Icons.pause,
                label: l.hold,
                active: call.isOnHold,
                onPressed: live ? () => controller.toggleHold(call) : null,
              ),
          ],
        ),
        const SizedBox(height: 32),
        _RoundAction(
          key: const ValueKey('end-call-button'),
          icon: Icons.call_end,
          label: l.endCall,
          color: Colors.red.shade600,
          foreground: Colors.white,
          size: 72,
          onPressed: live ? () => controller.hangUp(call) : null,
        ),
      ],
    );
  }
}

class _InCallKeypad extends StatelessWidget {
  const _InCallKeypad({
    required this.call,
    required this.typed,
    required this.onTyped,
    required this.onHide,
  });
  final ActiveCall call;
  final String typed;
  final ValueChanged<String> onTyped;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = AppScope.read(context);
    return Column(
      children: [
        Text(
          typed.isEmpty ? ' ' : typed,
          key: const ValueKey('dtmf-display'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 320,
          child: DialPad(
            maxKeySize: 72,
            onKeyTap: onTyped,
            onKeyDown: (d) => controller.dtmfDown(call, d),
            onKeyUp: () => controller.dtmfUp(call),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              key: const ValueKey('hide-keypad'),
              onPressed: onHide,
              child: Text(l.hideKeypad),
            ),
            _RoundAction(
              key: const ValueKey('end-call-button'),
              icon: Icons.call_end,
              label: l.endCall,
              color: Colors.red.shade600,
              foreground: Colors.white,
              onPressed: () => controller.hangUp(call),
            ),
          ],
        ),
      ],
    );
  }
}
