import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Shared navigation icon paths.
abstract final class NavBarAssets {
  static const home = 'assets/icons/home.png';
  static const tvShow = 'assets/icons/tvshow.png';
  static const search = 'assets/icons/search.png';
  static const settings = 'assets/icons/setting.png';

  static IconData iconFor(String assetPath) {
    switch (assetPath) {
      case home:
        return Icons.home_rounded;
      case tvShow:
        return Icons.live_tv_rounded;
      case search:
        return Icons.search_rounded;
      case settings:
        return Icons.settings_rounded;
      default:
        return Icons.circle_outlined;
    }
  }
}

class NavBarIcon extends StatelessWidget {
  final String? assetPath;
  final IconData? icon;
  final bool isSelected;
  final bool isFocused;
  final double size;
  final Color? selectedColor;

  const NavBarIcon({
    super.key,
    this.assetPath,
    this.icon,
    required this.isSelected,
    this.isFocused = false,
    this.size = 24,
    this.selectedColor,
  }) : assert(assetPath != null || icon != null);

  Color get _color {
    if (isSelected) return selectedColor ?? AppTheme.primaryColor;
    if (isFocused) return Colors.white.withOpacity(0.9);
    return Colors.white54;
  }

  @override
  Widget build(BuildContext context) {
    if (assetPath != null) {
      return Image.asset(
        assetPath!,
        width: size,
        height: size,
        color: _color,
        colorBlendMode: BlendMode.srcIn,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            NavBarAssets.iconFor(assetPath!),
            color: _color,
            size: size,
          );
        },
      );
    }

    return Icon(
      icon,
      color: _color,
      size: size,
    );
  }
}
