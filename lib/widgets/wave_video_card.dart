import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/wave_video.dart';
import '../providers/settings_provider.dart';
import '../services/wave_youtube_parser.dart';
import '../utils/tv_grid_focus.dart';
import '../utils/tv_row_focus.dart';
import 'tv_navigation_scope.dart';

class WaveVideoCard extends StatelessWidget {
  final WaveVideo video;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final FocusNode? focusPrevious;
  final FocusNode? focusNext;
  final int? gridIndex;
  final int? gridItemCount;
  final int? gridColumnCount;
  final FocusNode Function(int index)? focusNodeAtIndex;
  final TvGridFocusScheduler? gridFocusScheduler;
  final void Function(int targetIndex, {required bool vertical})? onPrepareGridTarget;
  final ValueChanged<bool>? onFocusChange;
  final bool compactMeta;

  const WaveVideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.focusNode,
    this.focusPrevious,
    this.focusNext,
    this.gridIndex,
    this.gridItemCount,
    this.gridColumnCount,
    this.focusNodeAtIndex,
    this.gridFocusScheduler,
    this.onPrepareGridTarget,
    this.onFocusChange,
    this.compactMeta = false,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: onFocusChange,
      onKeyEvent: (node, event) {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        final tvNav = TvNavigationScope.maybeOf(context);

        if (gridIndex != null &&
            gridItemCount != null &&
            gridColumnCount != null &&
            focusNodeAtIndex != null) {
          final gridNav = handleTvGridKeys(
            event,
            index: gridIndex!,
            itemCount: gridItemCount!,
            columnCount: gridColumnCount!,
            focusNodeAt: focusNodeAtIndex!,
            onMoveToSidebar: tvNav?.isTvLayout == true ? tvNav?.focusSidebar : null,
            isRtl: settings.isRtl,
            onPrepareTarget: onPrepareGridTarget,
            scheduler: gridFocusScheduler,
          );
          if (gridNav == KeyEventResult.handled) return gridNav;
        } else if (event is KeyDownEvent) {
          final rowNav = handleTvRowHorizontalKeys(
            event,
            focusPrevious: focusPrevious,
            focusNext: focusNext,
            onMoveToSidebar: tvNav?.isTvLayout == true ? tvNav?.focusSidebar : null,
            isRtl: settings.isRtl,
          );
          if (rowNav == KeyEventResult.handled) return rowNav;
        }

        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onTap,
            child: AnimatedScale(
              scale: focused ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: focused ? AppTheme.primaryColor : Colors.transparent,
                    width: focused ? 2 : 0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (video.thumbnailUrl.isNotEmpty)
                              CachedNetworkImage(
                                imageUrl: video.thumbnailUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 480,
                                memCacheHeight: 270,
                                fadeInDuration: const Duration(milliseconds: 180),
                                errorWidget: (_, error, stackTrace) => _placeholder(),
                                placeholder: (_, url) => _placeholder(),
                              )
                            else
                              _placeholder(),
                            if (video.isLive)
                              const Positioned(
                                left: 8,
                                top: 8,
                                child: _LiveBadge(),
                              ),
                            if (!video.isLive && video.duration != null)
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: _DurationBadge(
                                  label: WaveYoutubeParser.formatDuration(video.duration),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      video.channelTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    if (!compactMeta) ...[
                      const SizedBox(height: 2),
                      Text(
                        _metaLine(video),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.cardColor,
      alignment: Alignment.center,
      child: const Icon(Icons.play_circle_outline_rounded, color: AppTheme.textTertiary),
    );
  }

  String _metaLine(WaveVideo video) {
    final views = video.isLive && video.concurrentViewers != null
        ? '${WaveYoutubeParser.formatViewCount(video.concurrentViewers)} watching'
        : video.viewCount != null
            ? '${WaveYoutubeParser.formatViewCount(video.viewCount)} views'
            : '';
    final date = WaveYoutubeParser.relativePublishedLabel(video.publishedAt);
    if (views.isEmpty) return date;
    if (date.isEmpty) return views;
    return '$views • $date';
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.accentRed,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  final String label;
  const _DurationBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.78),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
