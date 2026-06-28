import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../l10n/app_localizations.dart';

class MediaRow extends StatefulWidget {
  final String title;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool isLoading;
  final bool isDimmed;
  final VoidCallback? onSeeMore;
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
    this.customHeight,
    this.customWidth,
  });

  @override
  MediaRowState createState() => MediaRowState();
}

class MediaRowState extends State<MediaRow> {
  final ScrollController _scrollController = ScrollController();

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
    final target = (index * itemExtent) - (viewport / 2) + (cardWidth / 2);

    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
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
    final isKurdish = settings.language.startsWith('ku');
    final isRTL = isKurdish || Directionality.of(context) == TextDirection.rtl;
    final horizontalPadding = isMobile ? AppTheme.spacingM : AppTheme.spacingXXL;

    final rowHeight = widget.customHeight ?? (isMobile ? 180.0 : 220.0);
    final cardWidth = widget.customWidth ?? (isMobile ? 130.0 : 145.0);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      opacity: widget.isDimmed ? 0.32 : 1.0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        scale: widget.isDimmed ? 0.96 : 1.0,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.title.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Row(
                  children: [
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
                    Text(
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
                    const Spacer(),
                    if (widget.onSeeMore != null && widget.itemCount > 5)
                      TextButton(
                        onPressed: widget.onSeeMore,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: isRTL
                                ? [
                                    const Icon(Icons.chevron_left, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      l10n.translate('see_all'),
                                      style: TextStyle(
                                        fontSize: isMobile ? 12 : 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ]
                                : [
                                    Text(
                                      l10n.translate('see_all'),
                                      style: TextStyle(
                                        fontSize: isMobile ? 12 : 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right, size: 16),
                                  ],
                          ),
                        ),
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
                      itemCount: widget.itemCount,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: AppTheme.spacingM),
                      itemBuilder: (context, index) => SizedBox(
                        width: cardWidth,
                        child: widget.itemBuilder(context, index),
                      ),
                    ),
            ),
            SizedBox(height: isMobile ? AppTheme.spacingL : AppTheme.spacingXL),
          ],
        ),
      ),
    );
  }
}
