import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/wave_music_lyrics.dart';
import '../models/wave_music_track.dart';
import '../providers/wave_music_provider.dart';
import '../services/wave_music_lyrics_service.dart';

class WaveMusicLyricsScreen extends StatelessWidget {
  const WaveMusicLyricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final track = context.watch<WaveMusicProvider>().currentTrack;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text('Lyrics')),
      body: track == null
          ? const Center(child: Text('Nothing playing', style: TextStyle(color: Colors.white54)))
          : FutureBuilder<WaveMusicLyrics>(
              future: WaveMusicLyricsService.instance.getLyrics(track),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                final lyrics = snapshot.data;
                if (lyrics == null || lyrics.isEmpty) {
                  return const Center(child: Text('Lyrics unavailable', style: TextStyle(color: Colors.white54)));
                }
                if (lyrics.isSynced) {
                  return _SyncedLyrics(track: track, lines: lyrics.synced);
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
                  children: [
                    Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                    Text(track.artist, style: const TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 24),
                    Text(lyrics.plain!, style: const TextStyle(color: Colors.white70, height: 1.6, fontSize: 16)),
                  ],
                );
              },
            ),
    );
  }
}

class _SyncedLyrics extends StatelessWidget {
  final WaveMusicTrack track;
  final List<WaveMusicLyricLine> lines;
  const _SyncedLyrics({required this.track, required this.lines});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<WaveMusicProvider>();
    return ValueListenableBuilder<Duration>(
      valueListenable: music.player.position,
      builder: (context, pos, _) {
        var active = 0;
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].at <= pos) active = i;
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
          itemCount: lines.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                    Text(track.artist, style: const TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              );
            }
            final line = lines[i - 1];
            final current = i - 1 == active;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                line.text,
                style: TextStyle(
                  color: current ? Colors.white : Colors.white38,
                  fontSize: current ? 18 : 16,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                  height: 1.4,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
