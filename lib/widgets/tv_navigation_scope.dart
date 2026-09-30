import 'package:flutter/material.dart';

/// Exposes TV shell actions (e.g. return focus to the side nav) to tab content.
class TvNavigationScope extends InheritedWidget {
  final VoidCallback focusSidebar;
  final VoidCallback? focusPrimaryContent;
  final bool isTvLayout;

  const TvNavigationScope({
    super.key,
    required this.focusSidebar,
    this.focusPrimaryContent,
    required this.isTvLayout,
    required super.child,
  });

  static TvNavigationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TvNavigationScope>();
  }

  @override
  bool updateShouldNotify(TvNavigationScope oldWidget) {
    return focusSidebar != oldWidget.focusSidebar ||
        focusPrimaryContent != oldWidget.focusPrimaryContent ||
        isTvLayout != oldWidget.isTvLayout;
  }
}
