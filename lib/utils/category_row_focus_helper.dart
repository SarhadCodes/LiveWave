import 'package:flutter/material.dart';
import '../widgets/media_row.dart';

/// Shared timing for vertical scroll, horizontal row scroll, and dim transitions.
const Duration kCategoryFocusScrollDuration = Duration(milliseconds: 300);
const Duration kCategoryFocusDimDuration = Duration(milliseconds: 260);
const Curve kCategoryFocusCurve = Curves.easeOutCubic;

/// Per-row focus view — avoids rebuilding unrelated rows on TV navigation.
class CategoryRowFocusView {
  final bool isRowActive;
  final int? focusedItemInRow;

  const CategoryRowFocusView({
    required this.isRowActive,
    this.focusedItemInRow,
  });

  bool get isRowDimmed => !isRowActive;

  bool isItemDimmed(int itemIndex) =>
      focusedItemInRow != null && focusedItemInRow != itemIndex;
}

/// Tracks focused category row + item for TV camera-follow scrolling and dimming.
class CategoryRowFocusHelper extends ChangeNotifier {
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

  CategoryRowFocusView viewForRow(int rowIndex) {
    final isRowActive = focusedRowIndex == null || focusedRowIndex == rowIndex;
    final focusedItemInRow =
        focusedRowIndex == rowIndex ? focusedItemIndexInRow : null;
    return CategoryRowFocusView(
      isRowActive: isRowActive,
      focusedItemInRow: focusedItemInRow,
    );
  }

  bool isRowActive(int rowIndex) => viewForRow(rowIndex).isRowActive;

  bool isItemDimmed(int rowIndex, int itemIndex) =>
      viewForRow(rowIndex).isItemDimmed(itemIndex);

  void onItemFocused({
    required int rowIndex,
    required int itemIndex,
    required String rowId,
  }) {
    if (focusedRowIndex == rowIndex && focusedItemIndexInRow == itemIndex) {
      _rowMediaKeys[rowId]?.currentState?.scrollToItem(itemIndex);
      return;
    }

    final rowChanged = focusedRowIndex != rowIndex;
    focusedRowIndex = rowIndex;
    focusedItemIndexInRow = itemIndex;
    notifyListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchorContext = _rowAnchorKeys[rowIndex]?.currentContext;
      if (anchorContext != null) {
        Scrollable.ensureVisible(
          anchorContext,
          duration: kCategoryFocusScrollDuration,
          curve: kCategoryFocusCurve,
          alignment: 0.30,
        );
      }

      if (rowChanged) {
        // Let the vertical scroll start before the horizontal camera-follow.
        Future<void>.delayed(const Duration(milliseconds: 48), () {
          _rowMediaKeys[rowId]?.currentState?.scrollToItem(itemIndex);
        });
      } else {
        _rowMediaKeys[rowId]?.currentState?.scrollToItem(itemIndex);
      }
    });
  }

  void reset() {
    if (focusedRowIndex == null && focusedItemIndexInRow == null) return;
    focusedRowIndex = null;
    focusedItemIndexInRow = null;
    notifyListeners();
  }
}

/// Rebuilds only when this row's active/dim state actually changes.
class CategoryRowFocusScope extends StatefulWidget {
  final CategoryRowFocusHelper helper;
  final int rowIndex;
  final Widget Function(CategoryRowFocusView focus) builder;

  const CategoryRowFocusScope({
    super.key,
    required this.helper,
    required this.rowIndex,
    required this.builder,
  });

  @override
  State<CategoryRowFocusScope> createState() => _CategoryRowFocusScopeState();
}

class _CategoryRowFocusScopeState extends State<CategoryRowFocusScope> {
  late CategoryRowFocusView _view;

  @override
  void initState() {
    super.initState();
    _view = widget.helper.viewForRow(widget.rowIndex);
    widget.helper.addListener(_onHelperChanged);
  }

  @override
  void didUpdateWidget(covariant CategoryRowFocusScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.helper != widget.helper ||
        oldWidget.rowIndex != widget.rowIndex) {
      oldWidget.helper.removeListener(_onHelperChanged);
      widget.helper.addListener(_onHelperChanged);
      _view = widget.helper.viewForRow(widget.rowIndex);
    }
  }

  @override
  void dispose() {
    widget.helper.removeListener(_onHelperChanged);
    super.dispose();
  }

  void _onHelperChanged() {
    final next = widget.helper.viewForRow(widget.rowIndex);
    if (next.isRowActive == _view.isRowActive &&
        next.focusedItemInRow == _view.focusedItemInRow) {
      return;
    }
    setState(() => _view = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(_view);
}
