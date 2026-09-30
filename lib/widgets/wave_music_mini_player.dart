import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/wave_music_provider.dart';
import '../screens/wave_music_player_screen.dart';
import 'wave_music_format.dart';

class WaveMusicMiniPlayer extends StatelessWidget {
  /// Lifts the bar above the floating bottom navigation. TV has no bottom bar.
  final bool aboveNavigationBar;

  const WaveMusicMiniPlayer({super.key, this.aboveNavigationBar = false});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<WaveMusicProvider>();
    final track = music.currentTrack;
    if (track == null || music.fullPlayerOpen) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(
        bottom: aboveNavigationBar ? waveMusicListBottomPadding(context) : 0,
      ),
      child: Material(
      color: const Color(0xFF161616),
      child: InkWell(
        onTap: () => WaveMusicPlayerScreen.open(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<Duration>(
              valueListenable: music.player.position,
              builder: (context, pos, _) {
                return ValueListenableBuilder<Duration>(
                  valueListenable: music.player.duration,
                  builder: (context, dur, _) {
                    final max = dur.inMilliseconds <= 0 ? 1.0 : dur.inMilliseconds.toDouble();
                    return LinearProgressIndicator(
                      value: (pos.inMilliseconds / max).clamp(0.0, 1.0),
                      minHeight: 2,
                      backgroundColor: Colors.white10,
                      color: Colors.white,
                    );
                  },
                );
              },
            ),
            SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: MusicArtwork(url: track.artworkUrl, logicalSize: 44),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    _MiniBtn(icon: Icons.skip_previous_rounded, onTap: music.previous),
                    ValueListenableBuilder<bool>(
                      valueListenable: music.player.playing,
                      builder: (context, playing, _) {
                        return _MiniBtn(
                          icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          onTap: music.togglePlayPause,
                        );
                      },
                    ),
                    _MiniBtn(icon: Icons.skip_next_rounded, onTap: music.next),
                    _MiniBtn(icon: Icons.close_rounded, onTap: music.clearQueue),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MiniBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) => handleMusicSelect(event, onTap),
      child: Builder(builder: (context) {
        final focused = Focus.of(context).hasFocus;
        return IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: focused ? Colors.black : Colors.white, size: 26),
          style: IconButton.styleFrom(
            backgroundColor: focused ? Colors.white : Colors.transparent,
          ),
        );
      }),
    );
  }
}
