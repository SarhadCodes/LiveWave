import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'nav_bar_icon.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = <_BottomNavItem>[
    _BottomNavItem(assetPath: NavBarAssets.home, label: 'Home'),
    _BottomNavItem(icon: Icons.sensors_rounded, label: 'Live'),
    _BottomNavItem(icon: Icons.movie_filter_rounded, label: 'Movies'),
    _BottomNavItem(assetPath: NavBarAssets.tvShow, label: 'Shows'),
    _BottomNavItem(icon: Icons.graphic_eq_rounded, label: 'Music'),
    _BottomNavItem(assetPath: NavBarAssets.search, label: 'Search'),
    _BottomNavItem(assetPath: NavBarAssets.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF121212).withOpacity(0.8),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                _items.length,
                (index) => _buildItem(index, _items[index]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index, _BottomNavItem item) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withOpacity(0.1)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: NavBarIcon(
                assetPath: item.assetPath,
                icon: item.icon,
                isSelected: isSelected,
                size: isSelected ? 22 : 20,
              ),
            ),
            if (isSelected)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem {
  final String? assetPath;
  final IconData? icon;
  final String label;

  const _BottomNavItem({
    this.assetPath,
    this.icon,
    required this.label,
  });
}
