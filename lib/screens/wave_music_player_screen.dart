import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/wave_music_provider.dart';
import '../services/wave_music_player.dart';
import '../widgets/soundcloud_attribution.dart';
import '../widgets/wave_music_actions.dart';
import '../widgets/wave_music_format.dart';
import 'wave_music_lyrics_screen.dart';
import 'wave_music_queue_screen.dart';

class WaveMusicPlayerScreen extends StatefulWidget {
  const WaveMusicPlayerScreen({super.key});

  static Future<void> open(BuildContext context) {
    final music = context.read<WaveMusicProvider>();
    music.setFullPlayerOpen(true);
    return Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute(builder: (_) => const WaveMusicPlayerScreen()))
        .whenComplete(() => music.setFullPlayerOpen(false));
  }

  @override
  State<WaveMusicPlayerScreen> createState() => _WaveMusicPlayerScreenState();
}

class _WaveMusicPlayerScreenState extends State<WaveMusicPlayerScreen> {
  @override
  Widget build(BuildContext context) {
    final music = context.watch<WaveMusicProvider>();
    final track = music.currentTrack;
    final isTV = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 560;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: isTV ? 80 : 24, vertical: compact ? 4 : 12),
              child: track == null
                  ? const Center(child: Text('Nothing playing', style: TextStyle(color: Colors.white54)))
                  : Column(
                      children: [
                        Row(
                          children: [
                            _FocusIcon(
                              icon: Icons.keyboard_arrow_down_rounded,
                              compact: compact,
                              onTap: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            _FocusIcon(
                              icon: Icons.queue_music,
                              compact: compact,
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const WaveMusicQueueScreen()));
                              },
                            ),
                          ],
                        ),
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: MusicArtwork(
                                  url: track.artworkUrl,
                                  logicalSize: MediaQuery.sizeOf(context).shortestSide,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Text(
                          track.title,
                          textAlign: TextAlign.center,
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: isTV ? 28 : (compact ? 18 : 22),
                          ),
                        ),
                        SizedBox(height: compact ? 2 : 6),
                        Text(
                          track.artist,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: compact ? 13 : 15),
                        ),
                        SoundCloudAttribution(track: track, compact: true),
                        if (track.isPreview)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              track.unavailabilityMessage,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                            ),
                          ),
                        ValueListenableBuilder<String?>(
                          valueListenable: music.player.error,
                          builder: (context, error, _) {
                            if (error == null || error.isEmpty) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                error,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: compact ? 4 : 24),
                        ValueListenableBuilder<Duration>(
                          valueListenable: music.player.position,
                          builder: (context, pos, _) {
                            return ValueListenableBuilder<Duration>(
                              valueListenable: music.player.duration,
                              builder: (context, dur, _) {
                                final max = dur.inMilliseconds <= 0 ? 1.0 : dur.inMilliseconds.toDouble();
                                return SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2,
                                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: compact ? 5 : 8),
                                    overlayShape: RoundSliderOverlayShape(overlayRadius: compact ? 12 : 16),
                                  ),
                                  child: Column(
                                    children: [
                                      Slider(
                                        value: pos.inMilliseconds.clamp(0, max.toInt()).toDouble(),
                                        max: max,
                                        activeColor: Colors.white,
                                        inactiveColor: Colors.white24,
                                        onChanged: (v) => music.seek(Duration(milliseconds: v.round())),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: Row(
                                          children: [
                                            Text(formatMusicDuration(pos), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                            const Spacer(),
                                            Text(formatMusicDuration(dur), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        SizedBox(height: compact ? 0 : 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _FocusIcon(
                                icon: music.player.shuffle ? Icons.shuffle_on_rounded : Icons.shuffle_rounded,
                                compact: compact,
                                onTap: music.toggleShuffle,
                              ),
                              _FocusIcon(icon: Icons.skip_previous_rounded, size: compact ? 28 : 36, compact: compact, onTap: music.previous),
                              ValueListenableBuilder<bool>(
                                valueListenable: music.player.buffering,
                                builder: (context, buffering, _) {
                                  return ValueListenableBuilder<bool>(
                                    valueListenable: music.player.playing,
                                    builder: (context, playing, _) {
                                      if (buffering && !playing) {
                                        return Padding(
                                          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
                                          child: SizedBox(
                                            width: compact ? 36 : 48,
                                            height: compact ? 36 : 48,
                                            child: const CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                          ),
                                        );
                                      }
                                      return _FocusIcon(
                                        icon: playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                        size: compact ? 48 : 64,
                                        compact: compact,
                                        onTap: music.togglePlayPause,
                                      );
                                    },
                                  );
                                },
                              ),
                              _FocusIcon(icon: Icons.skip_next_rounded, size: compact ? 28 : 36, compact: compact, onTap: music.next),
                              _FocusIcon(
                                icon: switch (music.player.repeat) {
                                  WaveMusicRepeatMode.off => Icons.repeat,
                                  WaveMusicRepeatMode.all => Icons.repeat_on_rounded,
                                  WaveMusicRepeatMode.one => Icons.repeat_one_rounded,
                                },
                                compact: compact,
                                onTap: music.cycleRepeat,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: compact ? 0 : 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _FocusIcon(
                              icon: music.isLiked(track.id) ? Icons.favorite : Icons.favorite_border,
                              compact: compact,
                              onTap: () => music.toggleLike(track),
                            ),
                            _FocusIcon(
                              icon: Icons.playlist_add,
                              compact: compact,
                              onTap: () => showWaveMusicTrackActions(context, track),
                            ),
                            _FocusIcon(
                              icon: Icons.lyrics_outlined,
                              compact: compact,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WaveMusicLyricsScreen())),
                            ),
                          ],
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _FocusIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool compact;
  const _FocusIcon({required this.icon, required this.onTap, this.size = 26, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) => handleMusicSelect(event, onTap),
      child: Builder(builder: (context) {
        final focused = Focus.of(context).hasFocus;
        final pad = compact ? 2.0 : 8.0;
        return IconButton(
          onPressed: onTap,
          iconSize: size,
          padding: EdgeInsets.all(pad),
          icon: Icon(icon, color: focused ? Colors.black : Colors.white),
          style: IconButton.styleFrom(
            backgroundColor: focused ? Colors.white : Colors.transparent,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: Size.square(size + pad * 2),
            padding: EdgeInsets.all(pad),
          ),
        );
      }),
    );
  }
}
