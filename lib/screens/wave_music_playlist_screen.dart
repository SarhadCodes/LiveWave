import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/wave_music_track.dart';
import '../providers/wave_music_provider.dart';
import '../services/wave_music_service.dart';
import '../widgets/wave_music_actions.dart';
import '../widgets/wave_music_format.dart';
import '../widgets/wave_music_track_tile.dart';

class WaveMusicPlaylistScreen extends StatelessWidget {
  final String playlistId;
  const WaveMusicPlaylistScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<WaveMusicProvider>();
    final local = music.playlistById(playlistId);
    return FutureBuilder(
      future: local != null ? Future.value(local) : WaveMusicService.instance.getPlaylist(playlistId),
      builder: (context, snapshot) {
        final playlist = snapshot.data;
        if (playlist == null) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
          }
          return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text('Playlist unavailable', style: TextStyle(color: Colors.white54))));
        }
        return FutureBuilder(
          future: WaveMusicService.instance.tracksForIds(playlist.trackIds),
          builder: (context, trackSnap) {
            final tracks = List<WaveMusicTrack>.from(trackSnap.data ?? const <WaveMusicTrack>[]);
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                title: Text(playlist.title),
                actions: [
                  if (playlist.userCreated)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await music.deletePlaylist(playlist.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  if (playlist.artworkUrl.isNotEmpty)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 160,
                          height: 160,
                          child: MusicArtwork(url: playlist.artworkUrl, logicalSize: 160),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(playlist.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  if (playlist.description.isNotEmpty)
                    Text(playlist.description, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(onPressed: tracks.isEmpty ? null : () => music.playPlaylist(playlist), icon: const Icon(Icons.play_arrow), label: const Text('Play')),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(onPressed: tracks.isEmpty ? null : () => music.playPlaylist(playlist, shuffle: true), icon: const Icon(Icons.shuffle), label: const Text('Shuffle')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (playlist.userCreated)
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tracks.length,
                      onReorder: (from, to) {
                        music.reorderPlaylistTracks(playlist.id, from, to > from ? to - 1 : to);
                      },
                      itemBuilder: (context, i) {
                        final track = tracks[i];
                        return WaveMusicTrackTile(
                          key: ValueKey(track.id),
                          track: track,
                          index: i + 1,
                          playing: music.currentTrack?.id == track.id,
                          onTap: () => music.playTracks(tracks, startIndex: i),
                          onLike: () => music.toggleLike(track),
                          onMore: () => music.removeTrackFromPlaylist(playlist.id, track.id),
                        );
                      },
                    )
                  else
                    ...List.generate(tracks.length, (i) {
                      final track = tracks[i];
                      return WaveMusicTrackTile(
                        track: track,
                        index: i + 1,
                        playing: music.currentTrack?.id == track.id,
                        onTap: () => music.playTracks(tracks, startIndex: i),
                        onLike: () => music.toggleLike(track),
                        onMore: () => showWaveMusicTrackActions(context, track),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
