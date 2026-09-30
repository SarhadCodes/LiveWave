import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/wave_music_track.dart';
import '../providers/wave_music_provider.dart';
import 'wave_music_format.dart';

class WaveMusicTrackTile extends StatelessWidget {
  final WaveMusicTrack track;
  final int? index;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback? onLike;
  final VoidCallback? onMore;
  final FocusNode? focusNode;
  final FocusNode? focusPrevious;
  final FocusNode? focusNext;
  final VoidCallback? onMoveToSidebar;

  const WaveMusicTrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.index,
    this.playing = false,
    this.onLike,
    this.onMore,
    this.focusNode,
    this.focusPrevious,
    this.focusNext,
    this.onMoveToSidebar,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          if (focusPrevious != null) {
            focusPrevious!.requestFocus();
            return KeyEventResult.handled;
          }
          onMoveToSidebar?.call();
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowRight && focusNext != null) {
          focusNext!.requestFocus();
          return KeyEventResult.handled;
        }
        return handleMusicSelect(event, onTap);
      },
      child: Builder(builder: (context) {
        final focused = Focus.of(context).hasFocus;
        return Material(
          color: focused
              ? Colors.white.withValues(alpha: 0.08)
              : playing
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onMore,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  if (index != null)
                    SizedBox(
                      width: 28,
                      child: Text(
                        playing ? '▶' : '$index',
                        style: TextStyle(
                          color: playing ? Colors.white : AppTheme.textTertiary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: MusicArtwork(url: track.artworkUrl, logicalSize: 48),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: playing ? Colors.white : AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (track.durationMs > 0)
                    Text(
                      formatMusicDuration(track.duration),
                      style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                    ),
                  if (onLike != null)
                    Consumer<WaveMusicProvider>(
                      builder: (context, music, _) {
                        final liked = music.isLiked(track.id);
                        return IconButton(
                          icon: Icon(
                            liked ? Icons.favorite : Icons.favorite_border,
                            color: liked ? Colors.white : AppTheme.textSecondary,
                            size: 20,
                          ),
                          onPressed: onLike,
                        );
                      },
                    ),
                  if (onMore != null)
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
                      onPressed: onMore,
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
