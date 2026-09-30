import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Column count matching [SliverGridDelegateWithMaxCrossAxisExtent].
int tvGridColumnCount({
  required double availableWidth,
  required double maxCrossAxisExtent,
  required double crossAxisSpacing,
}) {
  if (availableWidth <= 0) return 1;
  final count =
      (availableWidth / (maxCrossAxisExtent + crossAxisSpacing)).ceil();
  return count.clamp(1, 1000000);
}

/// Main-axis stride (row height + gap) for [SliverGridDelegateWithMaxCrossAxisExtent].
double tvGridMainAxisStride({
  required double availableWidth,
  required double maxCrossAxisExtent,
  required double crossAxisSpacing,
  required double mainAxisSpacing,
  double childAspectRatio = 1.0,
}) {
  final columns = tvGridColumnCount(
    availableWidth: availableWidth,
    maxCrossAxisExtent: maxCrossAxisExtent,
    crossAxisSpacing: crossAxisSpacing,
  );
  final usableCrossAxisExtent =
      (availableWidth - crossAxisSpacing * (columns - 1)).clamp(0.0, double.infinity);
  final childCrossAxisExtent = usableCrossAxisExtent / columns;
  final childMainAxisExtent = childCrossAxisExtent / childAspectRatio;
  return childMainAxisExtent + mainAxisSpacing;
}

/// Cancels stale delayed focus requests when the user presses D-pad quickly.
class TvGridFocusScheduler {
  Timer? _timer;
  int _generation = 0;

  void scheduleFocus({
    required VoidCallback onPrepare,
    required VoidCallback onFocus,
  }) {
    _timer?.cancel();
    final gen = ++_generation;
    onPrepare();
    _timer = Timer(const Duration(milliseconds: 32), () {
      if (gen != _generation) return;
      onFocus();
    });
  }

  void cancel() {
    _timer?.cancel();
    _generation++;
  }

  void dispose() {
    cancel();
  }
}

/// D-pad navigation inside a TV grid (left/right/up/down between items).
KeyEventResult handleTvGridKeys(
  KeyEvent event, {
  required int index,
  required int itemCount,
  required int columnCount,
  required FocusNode? Function(int index) focusNodeAt,
  VoidCallback? onMoveToSidebar,
  bool isRtl = false,
  void Function(int targetIndex, {required bool vertical})? onPrepareTarget,
  TvGridFocusScheduler? scheduler,
}) {
  if (event is KeyRepeatEvent) {
    return KeyEventResult.handled;
  }
  if (event is! KeyDownEvent) return KeyEventResult.ignored;
  if (columnCount <= 0 || itemCount <= 0) return KeyEventResult.ignored;

  final col = index % columnCount;
  int? target;

  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
    if (isRtl) {
      if (col > 0) {
        target = index - 1;
      } else {
        return KeyEventResult.handled;
      }
    } else if (col < columnCount - 1 && index + 1 < itemCount) {
      target = index + 1;
    } else {
      return KeyEventResult.handled;
    }
  } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
    if (isRtl) {
      if (col < columnCount - 1 && index + 1 < itemCount) {
        target = index + 1;
      } else {
        return KeyEventResult.handled;
      }
    } else if (col > 0) {
      target = index - 1;
    } else if (onMoveToSidebar != null) {
      onMoveToSidebar();
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.handled;
    }
  } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
    final next = index + columnCount;
    if (next < itemCount) {
      target = next;
    } else {
      return KeyEventResult.handled;
    }
  } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
    if (index >= columnCount) {
      target = index - columnCount;
    } else {
      return KeyEventResult.handled;
    }
  } else {
    return KeyEventResult.ignored;
  }

  final resolvedTarget = target!;
  final vertical = event.logicalKey == LogicalKeyboardKey.arrowDown ||
      event.logicalKey == LogicalKeyboardKey.arrowUp;

  void requestTargetFocus() {
    focusNodeAt(resolvedTarget)?.requestFocus();
  }

  if (vertical && onPrepareTarget != null) {
    if (scheduler != null) {
      scheduler.scheduleFocus(
        onPrepare: () => onPrepareTarget(resolvedTarget, vertical: true),
        onFocus: requestTargetFocus,
      );
    } else {
      onPrepareTarget(resolvedTarget, vertical: true);
      requestTargetFocus();
    }
    return KeyEventResult.handled;
  }

  requestTargetFocus();
  return KeyEventResult.handled;
}

/// Scrolls a category grid so [index]'s row sits in view (for lazy sliver grids).
void scrollCategoryGridToIndex(
  ScrollController controller, {
  required int index,
  required int columnCount,
  required double rowExtent,
  required double headerExtent,
  double alignment = 0.28,
}) {
  if (!controller.hasClients || columnCount <= 0) return;
  final row = index ~/ columnCount;
  final viewport = controller.position.viewportDimension;
  final target = headerExtent + row * rowExtent - (viewport * alignment);
  controller.jumpTo(
    target.clamp(0.0, controller.position.maxScrollExtent),
  );
}
