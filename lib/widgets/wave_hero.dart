import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/wave_video.dart';
import '../services/wave_youtube_parser.dart';

class WaveHero extends StatelessWidget {
  final WaveVideo video;
  final bool isMobile;
  final VoidCallback onWatch;
  final FocusNode? focusNode;

  const WaveHero({
    super.key,
    required this.video,
    required this.isMobile,
    required this.onWatch,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isMobile ? AppTheme.spacingM : AppTheme.spacingXXL;
    final l10n = AppLocalizations.of(context);

    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          onWatch();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onWatch,
            child: Container(
              height: isMobile ? 280 : 240,
              width: double.infinity,
              decoration: BoxDecoration(
                border: focused
                    ? Border.all(color: AppTheme.primaryColor, width: 3)
                    : null,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (video.thumbnailUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      memCacheHeight: 600,
                      errorWidget: (_, error, stackTrace) =>
                          Container(color: AppTheme.surfaceColor),
                    )
                  else
                    Container(color: AppTheme.surfaceColor),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.45),
                          AppTheme.backgroundColor,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: horizontalPadding,
                    right: horizontalPadding,
                    bottom: isMobile ? 28 : 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (video.isLive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
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
                                letterSpacing: 1.2,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l10n.translate('wave_featured'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: isMobile ? 26 : 22,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          [
                            video.channelTitle,
                            if (video.viewCount != null)
                              '${WaveYoutubeParser.formatViewCount(video.viewCount)} views',
                          ].where((part) => part.isNotEmpty).join('  •  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Text(
                                l10n.translate('watch_now'),
                                style: const TextStyle(
                                  color: AppTheme.backgroundColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
