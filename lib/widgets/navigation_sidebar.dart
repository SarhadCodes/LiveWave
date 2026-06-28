import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../providers/settings_provider.dart';
import 'package:provider/provider.dart';

class NavigationSidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const NavigationSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  NavigationSidebarState createState() => NavigationSidebarState();
}

class NavigationSidebarState extends State<NavigationSidebar>
    with TickerProviderStateMixin {
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  late AnimationController _glowController;

  /// Focus a sidebar item — used to auto-focus Home on TV app open.
  void requestFocusOnItem(int index) {
    if (index < 0 || index >= _focusNodes.length) return;
    _focusNodes[index].requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) requestFocusOnItem(widget.selectedIndex);
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  static const List<_NavItemData> _items = [
    _NavItemData(Icons.explore_rounded, 'Discover'),
    _NavItemData(Icons.sensors_rounded, 'Live'),
    _NavItemData(Icons.movie_filter_rounded, 'Movies'),
    _NavItemData(Icons.slideshow_rounded, 'Shows'),
    _NavItemData(Icons.manage_search_rounded, 'Search'),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isRtl = settings.isRtl;

    return Container(
      width: 72,
      decoration: BoxDecoration(
        // Glassmorphism base
        color: const Color(0xFF0F0F0F).withOpacity(0.85),
        border: Border(
          right: isRtl
              ? BorderSide.none
              : BorderSide(
                  color: Colors.white.withOpacity(0.06),
                  width: 1,
                ),
          left: isRtl
              ? BorderSide(
                  color: Colors.white.withOpacity(0.06),
                  width: 1,
                )
              : BorderSide.none,
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Navigation Items
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_items.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: _buildNavItem(
                            icon: _items[i].icon,
                            label: _items[i].label,
                            index: i,
                            focusNode: _focusNodes[i],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),

              // Bottom separator
              Container(
                width: 28,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Settings at bottom
              _buildNavItem(
                icon: Icons.tune_rounded,
                label: 'Settings',
                index: 5,
                focusNode: _focusNodes[5],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required FocusNode focusNode,
  }) {
    final isSelected = widget.selectedIndex == index;
    final isRtl =
        Provider.of<SettingsProvider>(context, listen: false).isRtl;

    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            widget.onItemSelected(index);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (isRtl) {
              return KeyEventResult.handled;
            } else {
              return KeyEventResult.ignored;
            }
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (isRtl) {
              return KeyEventResult.ignored;
            } else {
              return KeyEventResult.handled;
            }
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            final prevIndex = index > 0 ? index - 1 : 5;
            _focusNodes[prevIndex].requestFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            final nextIndex = index < 5 ? index + 1 : 0;
            _focusNodes[nextIndex].requestFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;

          return GestureDetector(
            onTap: () => widget.onItemSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isFocused
                    ? Colors.white.withOpacity(0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: isSelected
                        ? Colors.white
                        : isFocused
                            ? Colors.white.withOpacity(0.9)
                            : Colors.white.withOpacity(0.35),
                    size: 22,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white.withOpacity(0.9)
                          : isFocused
                              ? Colors.white.withOpacity(0.7)
                              : Colors.white.withOpacity(0.2),
                      fontSize: 8,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Red accent line under selected item
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    width: isSelected ? 20 : 0,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.accentRed.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ]
                          : [],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData(this.icon, this.label);
}
