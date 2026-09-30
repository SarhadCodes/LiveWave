import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/watch_history_item.dart';
import '../providers/watch_history_provider.dart';
import '../services/tmdb_service.dart';
import 'media_row.dart';

class ContinueWatchingRow extends StatelessWidget {
  final List<WatchHistoryItem> items;

  const ContinueWatchingRow({
    super.key,
    required this.items,
    bool isMobile = true,
  });

  static String remainingLabel(WatchHistoryItem item, AppLocalizations l10n) {
    final minutes = (item.remainingMs / 60000).ceil();
    if (minutes <= 0) return l10n.translate('resume');
    return l10n.translate('min_left').replaceAll('{m}', '$minutes');
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return MediaRow(
      title: l10n.translate('continue_watching').toUpperCase(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _ContinueWatchingCard(
          item: item,
          remaining: remainingLabel(item, l10n),
        );
      },
    );
  }
}

class _ContinueWatchingCard extends StatefulWidget {
  final WatchHistoryItem item;
  final String remaining;

  const _ContinueWatchingCard({
    required this.item,
    required this.remaining,
  });

  @override
  State<_ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<_ContinueWatchingCard> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'history_${widget.item.key}');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _play() {
    WatchHistoryProvider.play(context, widget.item);
  }

  Future<void> _remove() async {
    await context.read<WatchHistoryProvider>().remove(widget.item.key);
  }

  @override
  Widget build(BuildContext context) {
    final posterUrl = TmdbService.getPosterUrl(widget.item.posterPath);
    final episode = widget.item.episodeLabel;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.select) {
          _play();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: _play,
            onLongPress: _remove,
            child: AnimatedScale(
              scale: focused ? 1.06 : 1.0,
              duration: const Duration(milliseconds: 160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          posterUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: posterUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 400,
                                  errorWidget: (context, url, error) =>
                                      Container(color: AppTheme.surfaceColor),
                                )
                              : Container(color: AppTheme.surfaceColor),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: _remove,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: widget.item.progress,
                              minHeight: 4,
                              backgroundColor: Colors.white24,
                              color: AppTheme.accentRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.item.seriesTitle?.isNotEmpty == true
                        ? widget.item.seriesTitle!
                        : widget.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (episode.isNotEmpty) episode,
                      widget.remaining,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
