import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../utils/category_row_focus_helper.dart';
import '../utils/tv_row_focus.dart';
import '../widgets/tv_navigation_scope.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../l10n/app_localizations.dart';

/// Max items shown per category row before "See all" is offered.
const int kCategoryPreviewLimit = 10;

/// Header / row "See all" control (mobile tap + TV focus).
class SeeAllHeaderButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final bool compact;
  final FocusNode? focusNode;

  const SeeAllHeaderButton({
    super.key,
    required this.onTap,
    required this.label,
    this.compact = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select)) {
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12,
                  vertical: compact ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: isFocused ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFocused ? Colors.white : AppTheme.primaryColor.withOpacity(0.6),
                    width: isFocused ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isFocused ? Colors.black : AppTheme.primaryColor,
                        fontSize: compact ? 12 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: compact ? 16 : 18,
                      color: isFocused ? Colors.black : AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MediaRow extends StatefulWidget {
  final String title;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool isLoading;
  final bool isDimmed;
  final VoidCallback? onSeeMore;
  final FocusNode? seeAllFocusNode;
  final FocusNode? seeAllFocusPrevious;
  final ValueChanged<bool>? onSeeAllFocusChange;
  final bool seeAllDimmed;
  final double? customHeight;
  final double? customWidth;

  const MediaRow({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.isLoading = false,
    this.isDimmed = false,
    this.onSeeMore,
    this.seeAllFocusNode,
    this.seeAllFocusPrevious,
    this.onSeeAllFocusChange,
    this.seeAllDimmed = false,
    this.customHeight,
    this.customWidth,
  });

  @override
  MediaRowState createState() => MediaRowState();
}

class MediaRowState extends State<MediaRow> {
  final ScrollController _scrollController = ScrollController();

  bool _showSeeAllInList(BuildContext context) {
    if (widget.onSeeMore == null) return false;
    final isMobile =
        Provider.of<SettingsProvider>(context, listen: false).layoutMode == 'mobile';
    return !isMobile;
  }

  int _listItemCount(BuildContext context) {
    return widget.itemCount + (_showSeeAllInList(context) ? 1 : 0);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Smoothly scrolls the row so [index] is near the center (camera-follow).
  void scrollToItem(int index) {
    if (!_scrollController.hasClients || widget.isLoading) return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final isMobile = settings.layoutMode == 'mobile';
    final cardWidth = widget.customWidth ?? (isMobile ? 130.0 : 145.0);
    const spacing = AppTheme.spacingM;
    final itemExtent = cardWidth + spacing;
    final viewport = _scrollController.position.viewportDimension;
    final maxIndex = _listItemCount(context) - 1;
    final safeIndex = index.clamp(0, maxIndex);
    final target = (safeIndex * itemExtent) - (viewport / 2) + (cardWidth / 2);
    final clampedTarget =
        target.clamp(0.0, _scrollController.position.maxScrollExtent);

    if ((_scrollController.offset - clampedTarget).abs() < 6) return;

    _scrollController.animateTo(
      clampedTarget,
      duration: kCategoryFocusScrollDuration,
      curve: kCategoryFocusCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading && widget.itemCount == 0) {
      return const SizedBox.shrink();
    }

    final settings = Provider.of<SettingsProvider>(context);
    final l10n = AppLocalizations.of(context);
    final isMobile = settings.layoutMode == 'mobile';
    final horizontalPadding = isMobile ? AppTheme.spacingM : AppTheme.spacingXXL;
    final showSeeAllInList = _showSeeAllInList(context);
    final listItemCount = _listItemCount(context);

    final rowHeight = widget.customHeight ?? (isMobile ? 180.0 : 220.0);
    final cardWidth = widget.customWidth ?? (isMobile ? 130.0 : 145.0);

    return RepaintBoundary(
      child: AnimatedOpacity(
        duration: kCategoryFocusDimDuration,
        curve: kCategoryFocusCurve,
        opacity: widget.isDimmed ? 0.38 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.title.isNotEmpty ||
                (widget.onSeeMore != null && isMobile))
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Row(
                  children: [
                    if (widget.title.isNotEmpty) ...[
                      Container(
                        width: 4,
                        height: isMobile ? 16 : 20,
                        decoration: BoxDecoration(
                          color: widget.isDimmed
                              ? AppTheme.accentRed.withOpacity(0.35)
                              : AppTheme.accentRed,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            color: widget.isDimmed
                                ? AppTheme.textPrimary.withOpacity(0.45)
                                : AppTheme.textPrimary,
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (widget.onSeeMore != null && isMobile)
                      SeeAllHeaderButton(
                        onTap: widget.onSeeMore!,
                        label: l10n.translate('see_all'),
                        compact: true,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppTheme.spacingM),
            SizedBox(
              height: rowHeight,
              child: widget.isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      padding:
                          EdgeInsets.symmetric(horizontal: horizontalPadding),
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      itemCount: listItemCount,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: AppTheme.spacingM),
                      itemBuilder: (context, index) {
                        if (showSeeAllInList && index == widget.itemCount) {
                          return SizedBox(
                            width: cardWidth,
                            child: _SeeAllTile(
                              label: l10n.translate('see_all'),
                              focusNode: widget.seeAllFocusNode,
                              focusPrevious: widget.seeAllFocusPrevious,
                              onFocusChange: widget.onSeeAllFocusChange,
                              onTap: widget.onSeeMore!,
                              dimmed: widget.isDimmed || widget.seeAllDimmed,
                            ),
                          );
                        }
                        return SizedBox(
                          width: cardWidth,
                          child: widget.itemBuilder(context, index),
                        );
                      },
                    ),
            ),
            SizedBox(height: isMobile ? AppTheme.spacingL : AppTheme.spacingXL),
          ],
        ),
      ),
    );
  }
}

class _SeeAllTile extends StatefulWidget {
  final String label;
  final FocusNode? focusNode;
  final FocusNode? focusPrevious;
  final ValueChanged<bool>? onFocusChange;
  final VoidCallback onTap;
  final bool dimmed;

  const _SeeAllTile({
    required this.label,
    this.focusNode,
    this.focusPrevious,
    this.onFocusChange,
    required this.onTap,
    this.dimmed = false,
  });

  @override
  State<_SeeAllTile> createState() => _SeeAllTileState();
}

class _SeeAllTileState extends State<_SeeAllTile> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode?.addListener(_syncFocusVisual);
  }

  @override
  void didUpdateWidget(covariant _SeeAllTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_syncFocusVisual);
      widget.focusNode?.addListener(_syncFocusVisual);
    }
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_syncFocusVisual);
    super.dispose();
  }

  void _syncFocusVisual() {
    final hasFocus = widget.focusNode?.hasFocus ?? false;
    if (_focused != hasFocus && mounted) {
      setState(() => _focused = hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        widget.onFocusChange?.call(focused);
      },
      onKeyEvent: (node, event) {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        final tvNav = TvNavigationScope.maybeOf(context);
        final rowNav = handleTvRowHorizontalKeys(
          event,
          focusPrevious: widget.focusPrevious,
          onMoveToSidebar: tvNav?.isTvLayout == true ? tvNav?.focusSidebar : null,
          isRtl: settings.isRtl,
        );
        if (rowNav == KeyEventResult.handled) return rowNav;

        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: kCategoryFocusDimDuration,
          curve: kCategoryFocusCurve,
          opacity: widget.dimmed && !_focused ? 0.45 : 1.0,
          child: SizedBox.expand(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                color: AppTheme.cardColor,
                border: Border.all(
                  color: _focused
                      ? AppTheme.focusColor
                      : AppTheme.textTertiary.withValues(alpha: 0.15),
                  width: _focused ? 3 : 1,
                ),
                boxShadow: _focused
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.25),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: _focused ? AppTheme.focusColor : Colors.white70,
                    size: 32,
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _focused ? Colors.white : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
