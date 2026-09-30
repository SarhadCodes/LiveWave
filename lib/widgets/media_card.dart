import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/movies_provider.dart';
import '../providers/tv_shows_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/tv_row_focus.dart';
import '../utils/tv_grid_focus.dart';
import '../utils/category_row_focus_helper.dart';
import '../widgets/tv_navigation_scope.dart';

class MediaCard extends StatefulWidget {
  final String id;
  final String title;
  final String posterUrl;
  final String rating;
  final String year;
  final bool isMovie;
  final bool forceKurdishBadge;
  final FocusNode? focusNode;
  final FocusNode? focusPrevious;
  final FocusNode? focusNext;
  final int? gridIndex;
  final int? gridItemCount;
  final int? gridColumnCount;
  final FocusNode Function(int index)? focusNodeAtIndex;
  final TvGridFocusScheduler? gridFocusScheduler;
  final void Function(int targetIndex, {required bool vertical})? onPrepareGridTarget;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFocusChange;
  final bool dimmed;

  const MediaCard({
    super.key,
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.rating,
    required this.year,
    required this.isMovie,
    this.forceKurdishBadge = false,
    this.focusNode,
    this.focusPrevious,
    this.focusNext,
    this.gridIndex,
    this.gridItemCount,
    this.gridColumnCount,
    this.focusNodeAtIndex,
    this.gridFocusScheduler,
    this.onPrepareGridTarget,
    this.onTap,
    this.onFocusChange,
    this.dimmed = false,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: widget.onFocusChange,
      onKeyEvent: (node, event) {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        final tvNav = TvNavigationScope.maybeOf(context);

        if (widget.gridIndex != null &&
            widget.gridItemCount != null &&
            widget.gridColumnCount != null &&
            widget.focusNodeAtIndex != null) {
          final gridNav = handleTvGridKeys(
            event,
            index: widget.gridIndex!,
            itemCount: widget.gridItemCount!,
            columnCount: widget.gridColumnCount!,
            focusNodeAt: widget.focusNodeAtIndex!,
            onMoveToSidebar: tvNav?.isTvLayout == true ? tvNav?.focusSidebar : null,
            isRtl: settings.isRtl,
            onPrepareTarget: widget.onPrepareGridTarget,
            scheduler: widget.gridFocusScheduler,
          );
          if (gridNav == KeyEventResult.handled) return gridNav;
        } else if (event is KeyDownEvent) {
          final rowNav = handleTvRowHorizontalKeys(
            event,
            focusPrevious: widget.focusPrevious,
            focusNext: widget.focusNext,
            onMoveToSidebar: tvNav?.isTvLayout == true ? tvNav?.focusSidebar : null,
            isRtl: settings.isRtl,
          );
          if (rowNav == KeyEventResult.handled) return rowNav;
        }

        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return AnimatedOpacity(
            duration: kCategoryFocusDimDuration,
            curve: kCategoryFocusCurve,
            opacity: widget.dimmed ? 0.45 : 1.0,
            child: GestureDetector(
              onTap: widget.onTap,
              child: SizedBox.expand(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isFocused
                          ? AppTheme.focusColor
                          : AppTheme.textTertiary.withValues(alpha: 0.15),
                      width: isFocused ? 3 : 1,
                    ),
                    boxShadow: isFocused
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.posterUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.posterUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 400,
                                placeholder: (context, url) => Container(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  child: const Center(
                                    child: Icon(Icons.movie_filter_rounded, color: Colors.white24),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: AppTheme.surfaceColor,
                                  child: const Icon(Icons.broken_image_rounded, size: 40, color: Colors.white24),
                                ),
                              )
                            : Container(
                                color: AppTheme.surfaceColor,
                                child: const Icon(Icons.movie_filter_rounded, size: 40, color: Colors.white24),
                              ),
                        _buildKurdishBadge(),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.0),
                                  Colors.black.withValues(alpha: 0.6),
                                  Colors.black.withValues(alpha: 0.9),
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, color: AppTheme.primaryColor, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.rating,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      widget.year,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
        },
      ),
    );
  }

  Widget _buildKurdishBadge() {
    return Consumer2<MoviesProvider, TvShowsProvider>(
      builder: (context, moviesProv, tvProv, _) {
        bool hasSub = widget.forceKurdishBadge;
        if (!hasSub) {
          final idInt = int.tryParse(widget.id.replaceAll(RegExp(r'[^0-9]'), ''));
          if (idInt != null) {
            if (widget.isMovie) {
              hasSub = moviesProv.kurdishMovies.any((m) => m.id == idInt);
            } else {
              hasSub = tvProv.kurdishTvShows.any((t) => t.id == idInt);
            }
          }
        }

        if (hasSub) {
          return Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5), width: 1),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.asset('assets/flags/k.png', width: 20, height: 14, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'KU',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
