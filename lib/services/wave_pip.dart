import 'package:flutter/services.dart';

/// Android Picture-in-Picture for Wave watch.
/// Hidden background YouTube playback is not used (YouTube IFrame policy).
class WavePip {
  static const _channel = MethodChannel('com.livewave.wave/pip');
  static void Function(bool inPip)? onChanged;
  static bool _handlerBound = false;

  static void bind() {
    if (_handlerBound) return;
    _handlerBound = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipChanged') {
        onChanged?.call(call.arguments == true);
      }
    });
  }

  static Future<void> setEnabled(bool enabled) async {
    bind();
    try {
      await _channel.invokeMethod('setEnabled', enabled);
    } on MissingPluginException {
      // Android-only. iOS / tests have no PiP channel.
    } on PlatformException {
      // Activity may not support PiP on this device.
    }
  }
}
