import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';

class PlatformDetector {
  // Check if running on Android TV or similar large landscape screen
  static bool get isTV {
    if (kIsWeb) return false;
    
    // Heuristic: Android + Landscape + Large Screen + No Touch (ideally)
    // In Flutter, we can check the physical size and pixel ratio
    try {
      final window = PlatformDispatcher.instance.views.first;
      final size = window.physicalSize / window.devicePixelRatio;
      
      // Typical TV criteria: 
      // 1. Landscape orientation (width > height)
      // 2. Large width (typically >= 960 logical pixels for 720p/1080p TVs)
      final isLandscape = size.width > size.height;
      final isLargeWidth = size.width >= 900;
      
      if (Platform.isAndroid && isLandscape && isLargeWidth) {
        return true;
      }
    } catch (_) {
      // Fallback
    }
    return false;
  }

  // Check if running on mobile (Phone/Tablet)
  static bool get isMobile {
    if (kIsWeb) return true; // Default to mobile-like for web
    return Platform.isAndroid || Platform.isIOS;
  }

  static String get autoDetectLayout {
    return isTV ? 'tv' : 'mobile';
  }

  // Get device type as string for debugging
  static String get deviceType {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return isTV ? 'Android TV' : 'Android Mobile';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}
