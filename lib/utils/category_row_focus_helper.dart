import 'package:flutter/material.dart';
import '../widgets/media_row.dart';

/// Tracks focused category row + item for TV camera-follow scrolling and dimming.
class CategoryRowFocusHelper {
  final Map<String, GlobalKey<MediaRowState>> _rowMediaKeys = {};
  final Map<int, GlobalKey> _rowAnchorKeys = {};
  int? focusedRowIndex;
  int? focusedItemIndexInRow;

  GlobalKey<MediaRowState> mediaKeyFor(String rowId) {
    return _rowMediaKeys.putIfAbsent(rowId, GlobalKey<MediaRowState>.new);
  }

  GlobalKey anchorKeyFor(int rowIndex) {
    return _rowAnchorKeys.putIfAbsent(rowIndex, GlobalKey.new);
  }

  bool isRowActive(int rowIndex) {
    return focusedRowIndex == null || focusedRowIndex == rowIndex;
  }

  bool isItemDimmed(int rowIndex, int itemIndex) {
    if (focusedRowIndex != rowIndex) return false;
    return focusedItemIndexInRow != null && focusedItemIndexInRow != itemIndex;
  }

  void onItemFocused({
    required VoidCallback scheduleRebuild,
    required int rowIndex,
    required int itemIndex,
    required String rowId,
  }) {
    if (focusedRowIndex == rowIndex && focusedItemIndexInRow == itemIndex) {
      _rowMediaKeys[rowId]?.currentState?.scrollToItem(itemIndex);
      return;
    }

    focusedRowIndex = rowIndex;
    focusedItemIndexInRow = itemIndex;
    scheduleRebuild();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchorContext = _rowAnchorKeys[rowIndex]?.currentContext;
      if (anchorContext != null) {
        Scrollable.ensureVisible(
          anchorContext,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: 0.28,
        );
      }
      _rowMediaKeys[rowId]?.currentState?.scrollToItem(itemIndex);
    });
  }

  void reset() {
    focusedRowIndex = null;
    focusedItemIndexInRow = null;
  }
}
