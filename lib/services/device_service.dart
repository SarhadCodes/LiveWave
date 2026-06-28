import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reads a stable device identifier used for MAC-based activation.
class DeviceService {
  static const MethodChannel _channel =
      MethodChannel('com.livewave.player/utils');

  static String? _cachedMac;

  /// Returns MAC-style address (AA:BB:CC:DD:EE:FF) or a stable fallback ID.
  static Future<String> getMacAddress() async {
    if (_cachedMac != null && _cachedMac!.isNotEmpty) return _cachedMac!;

    String? mac;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        mac = await _channel
            .invokeMethod<String>('getMacAddress')
            .timeout(const Duration(seconds: 5));
        debugPrint('[DeviceService] Native MAC/id: $mac');
      } catch (e) {
        debugPrint('[DeviceService] Native MAC failed: $e');
      }
    }

    mac ??= await _fallbackDeviceId();
    if (mac.isEmpty || mac == 'unknown') {
      mac = await _fallbackDeviceId();
    }
    _cachedMac = normalizeMac(mac);
    debugPrint('[DeviceService] Using device id: $_cachedMac');
    return _cachedMac!;
  }

  static Future<String> _fallbackDeviceId() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (!kIsWeb && Platform.isAndroid) {
        final info = await plugin.androidInfo;
        final id = info.id;
        if (id.isNotEmpty) return id;
      }
      if (!kIsWeb && Platform.isIOS) {
        final info = await plugin.iosInfo;
        return info.identifierForVendor ?? 'ios-unknown';
      }
      if (!kIsWeb && Platform.isWindows) {
        final info = await plugin.windowsInfo;
        return info.deviceId;
      }
    } catch (e) {
      debugPrint('[DeviceService] fallback id failed: $e');
    }
    return 'device-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Normalize to uppercase colon-separated form for Firestore doc IDs.
  static String normalizeMac(String raw) {
    final cleaned = raw.trim().toUpperCase().replaceAll('-', ':');
    if (RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$').hasMatch(cleaned)) {
      return cleaned;
    }
    // Fallback IDs (Android ID, etc.) — use as-is but safe for Firestore doc id.
    return cleaned.replaceAll(RegExp(r'[^A-Z0-9]'), '_');
  }

  static String macToDocId(String mac) =>
      normalizeMac(mac).replaceAll(':', '-');

  static String formatDisplayMac(String mac) {
    if (mac.trim().isEmpty) return '';
    final normalized = normalizeMac(mac);
    if (RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$').hasMatch(normalized)) {
      return normalized;
    }
    return normalized;
  }
}
