import 'package:flutter/material.dart';

/// Language-aware type. English uses the platform sans-serif stack
/// (Roboto on Android, San Francisco on Apple OS). Kurdish uses the
/// bundled K24 face for Arabic-script coverage.
abstract final class AppTypography {
  static const kurdishFamily = 'K24Kurdish';

  static String? fontFamily(String language) {
    return language == 'ku' ? kurdishFamily : 'sans-serif';
  }

  static List<String> fontFamilyFallback(String language) {
    if (language == 'ku') return const [kurdishFamily, 'sans-serif'];
    return const [
      '.SF Pro Display',
      '.SF Pro Text',
      'SF Pro Display',
      'SF Pro Text',
      'Helvetica Neue',
      'sans-serif',
    ];
  }

  static double tracking(String language, {bool display = false}) {
    if (language == 'ku') return 0;
    return display ? -0.45 : -0.24;
  }

  static TextTheme textTheme(String language, {required Color primary, required Color secondary, required Color tertiary}) {
    final family = fontFamily(language);
    final fallback = fontFamilyFallback(language);
    final displayTracking = tracking(language, display: true);
    final bodyTracking = tracking(language);

    TextStyle base({
      required double size,
      FontWeight weight = FontWeight.w400,
      Color? color,
      double? spacing,
      double height = 1.25,
    }) {
      return TextStyle(
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: size,
        fontWeight: weight,
        color: color ?? primary,
        letterSpacing: spacing ?? bodyTracking,
        height: height,
      );
    }

    return TextTheme(
      displayLarge: base(size: 32, weight: FontWeight.w700, spacing: displayTracking),
      displayMedium: base(size: 28, weight: FontWeight.w700, spacing: displayTracking),
      displaySmall: base(size: 24, weight: FontWeight.w700, spacing: displayTracking),
      headlineLarge: base(size: 20, weight: FontWeight.w600, spacing: displayTracking),
      headlineMedium: base(size: 18, weight: FontWeight.w600),
      headlineSmall: base(size: 16, weight: FontWeight.w600),
      titleLarge: base(size: 17, weight: FontWeight.w600),
      titleMedium: base(size: 15, weight: FontWeight.w600),
      titleSmall: base(size: 13, weight: FontWeight.w600, color: secondary),
      bodyLarge: base(size: 16, color: primary, height: 1.35),
      bodyMedium: base(size: 14, color: secondary, height: 1.35),
      bodySmall: base(size: 12, color: tertiary),
      labelLarge: base(size: 13, weight: FontWeight.w600),
      labelMedium: base(size: 11, weight: FontWeight.w600, color: secondary),
      labelSmall: base(size: 10, weight: FontWeight.w600, color: tertiary, spacing: language == 'ku' ? 0 : 0.6),
    );
  }
}
