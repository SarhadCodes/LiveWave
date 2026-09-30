import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps D-pad Left/Right inside a category row; Up/Down pass through for row changes.
/// At the row edge, [onMoveToSidebar] returns focus to the TV side navigation.
KeyEventResult handleTvRowHorizontalKeys(
  KeyEvent event, {
  FocusNode? focusPrevious,
  FocusNode? focusNext,
  VoidCallback? onMoveToSidebar,
  bool isRtl = false,
}) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;

  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
    if (focusNext != null) {
      focusNext.requestFocus();
      return KeyEventResult.handled;
    }
    if (isRtl && onMoveToSidebar != null) {
      onMoveToSidebar();
      return KeyEventResult.handled;
    }
    // End of row — keep focus here instead of jumping to another category.
    return KeyEventResult.handled;
  }
  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
    if (focusPrevious != null) {
      focusPrevious.requestFocus();
      return KeyEventResult.handled;
    }
    if (!isRtl && onMoveToSidebar != null) {
      onMoveToSidebar();
      return KeyEventResult.handled;
    }
    // Start of row — keep focus inside the row.
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}
