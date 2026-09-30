import 'package:flutter/material.dart';

import 'app_typography.dart';

class AppTheme {
  // Ultra-premium dark gray and white color palette
  static const Color primaryColor = Color(0xFFFFFFFF); // Pure white
  static const Color secondaryColor = Color(0xFFE5E5E5); // Light gray
  static const Color backgroundColor = Color(0xFF0D0D0D); // Almost black
  static const Color surfaceColor = Color(0xFF1A1A1A); // Dark gray surface
  static const Color cardColor = Color(0xFF242424); // Card background
  
  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFFB8B8B8); // Medium gray
  static const Color textTertiary = Color(0xFF6B6B6B); // Dark gray
  
  // Accent colors - subtle and premium
  static const Color accentRed = Color(0xFFE63946); // Muted red for live
  static const Color accentGreen = Color(0xFF2A9D8F); // Muted teal
  static const Color accentGold = Color(0xFFD4AF37); // Gold accent
  
  // Focus colors for TV - subtle white glow
  static const Color focusColor = Color(0xFFFFFFFF);
  static const Color focusGlow = Color(0x33FFFFFF); // Subtle white glow
  
  // Category colors - muted and sophisticated
  static const Map<String, Color> categoryColors = {
    'News': Color(0xFFE63946), // Muted red
    'Sports': Color(0xFF2A9D8F), // Muted teal
    'Entertainment': Color(0xFFD4AF37), // Gold
    'Movies': Color(0xFF9D4EDD), // Muted purple
    'Music': Color(0xFFE76F51), // Muted coral
    'Kids': Color(0xFF06AED5), // Muted cyan
    'Documentary': Color(0xFF588157), // Muted green
    'General': Color(0xFFB8B8B8), // Medium gray
  };

  // Get category color with fallback
  static Color getCategoryColor(String category) {
    return categoryColors[category] ?? categoryColors['General']!;
  }

  // Dark theme configuration
  static ThemeData get darkTheme => darkThemeFor('en');

  static ThemeData darkThemeFor(String language) {
    final text = AppTypography.textTheme(
      language,
      primary: textPrimary,
      secondary: textSecondary,
      tertiary: textTertiary,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTypography.fontFamily(language),
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: accentRed,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall?.copyWith(fontSize: 22, color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      textTheme: text,
      focusColor: focusColor,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primaryColor,
        selectionColor: primaryColor.withValues(alpha: 0.3),
        selectionHandleColor: primaryColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: backgroundColor,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      iconTheme: const IconThemeData(
        color: textPrimary,
      ),
    );
  }

  // Spacing constants
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // Border radius - more sharp/modern
  static const double radiusS = 8.0;
  static const double radiusM = 10.0;
  static const double radiusL = 14.0;
  static const double radiusXL = 20.0;
  
  // TV-specific dimensions - Compact and sleek
  static const double tvCardWidth = 320.0;
  static const double tvCardHeight = 210.0;
  static const double tvFocusScale = 1.10;
  static const double tvFocusBorderWidth = 3.5;

  // Mobile-specific dimensions
  static const double mobileCardAspectRatio = 16 / 9;
  static const double mobileGridSpacing = 12.0;
}
