import 'dart:ui';

import 'package:flutter/material.dart';

import 'app.dart';
import 'domain/diagnostics.dart';
import 'platform/method_channel_dialer_platform.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Unexpected errors go to the on-device, number-scrubbed diagnostics log only.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    DiagnosticsSink.record('flutter', details.exceptionAsString());
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    DiagnosticsSink.record('uncaught', error.toString());
    return false;
  };

  runApp(SmartDialApp(platform: MethodChannelDialerPlatform()));
}
