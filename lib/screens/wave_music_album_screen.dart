import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/wave_music_track.dart';
import '../providers/wave_music_provider.dart';
import '../services/wave_music_service.dart';
import '../widgets/wave_music_actions.dart';
import '../widgets/wave_music_format.dart';
import '../widgets/wave_music_track_tile.dart';

class WaveMusicAlbumScreen extends StatefulWidget {
  final String albumId;
  const WaveMusicAlbumScreen({super.key, required this.albumId});

  @override
  State<WaveMusicAlbumScreen> createState() => _WaveMusicAlbumScreenState();
}

class _WaveMusicAlbumScreenState extends State<WaveMusicAlbumScreen> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: WaveMusicService.instance.getAlbum(widget.albumId),
      builder: (context, snapshot) {
        final album = snapshot.data;
        if (album == null) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
          }
          return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text('Album unavailable', style: TextStyle(color: Colors.white54))));
        }
        return FutureBuilder(
          future: WaveMusicService.instance.tracksForIds(album.trackIds),
          builder: (context, trackSnap) {
            final tracks = List<WaveMusicTrack>.from(trackSnap.data ?? const <WaveMusicTrack>[]);
            final music = context.watch<WaveMusicProvider>();
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(backgroundColor: Colors.black, title: Text(album.title)),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 180,
                        height: 180,
                        child: MusicArtwork(url: album.artworkUrl, logicalSize: 180),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(album.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  Text('${album.artist} · ${album.year}${album.trackCount > 0 ? ' · ${album.trackCount} tracks' : ''}', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: tracks.isEmpty ? null : () => music.playAlbum(album),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Play'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: tracks.isEmpty ? null : () => music.playAlbum(album, shuffle: true),
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Shuffle'),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: tracks.isEmpty
                            ? null
                            : () {
                                for (final track in tracks) {
                                  if (!music.isLiked(track.id)) music.toggleLike(track);
                                }
                              },
                        icon: const Icon(Icons.favorite_border, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: tracks.isEmpty ? null : () => showWaveMusicTrackActions(context, tracks.first),
                        icon: const Icon(Icons.playlist_add, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
