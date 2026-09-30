import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/wave_music_album.dart';
import '../models/wave_music_track.dart';
import '../providers/wave_music_provider.dart';
import '../services/wave_music_service.dart';
import '../widgets/wave_music_actions.dart';
import '../widgets/wave_music_album_card.dart';
import '../widgets/wave_music_format.dart';
import '../widgets/wave_music_track_tile.dart';
import 'wave_music_album_screen.dart';
import 'wave_music_playlist_screen.dart';

class WaveMusicArtistScreen extends StatelessWidget {
  final String artistId;
  const WaveMusicArtistScreen({super.key, required this.artistId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: WaveMusicService.instance.getArtistDetails(artistId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
        }
        final details = snapshot.data;
        final artist = details?.artist;
        if (details == null || artist == null || artist.name.isEmpty) {
          return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text('Artist unavailable', style: TextStyle(color: Colors.white54))));
        }
        final music = context.watch<WaveMusicProvider>();
        final popular = details.popular;
        final albums = details.albums;
        final singles = details.singles;
        final related = details.related;
        final playlists = details.playlists;
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, title: Text(artist.name)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              Center(
                child: ClipOval(
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: MusicArtwork(url: artist.artworkUrl, logicalSize: 140),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(artist.name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
              if (artist.trackCount > 0)
                Text('${artist.trackCount} tracks', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
              if (artist.genre.isNotEmpty && !artist.genre.endsWith('tracks'))
                Text(artist.genre, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(onPressed: popular.isEmpty ? null : () => music.playArtist(artist), icon: const Icon(Icons.play_arrow), label: const Text('Play')),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(onPressed: popular.isEmpty ? null : () => music.playArtist(artist, shuffle: true), icon: const Icon(Icons.shuffle), label: const Text('Shuffle')),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => music.toggleFollow(artist.id, artist: artist),
                    child: Text(music.isFollowed(artist.id) ? 'Following' : 'Follow'),
                  ),
                ],
              ),
              if (popular.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Popular', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                ...List.generate(popular.length.clamp(0, 10), (i) {
                  final track = popular[i];
                  return WaveMusicTrackTile(
                    track: track,
                    index: i + 1,
                    playing: music.currentTrack?.id == track.id,
                    onTap: () => music.playTracks(List<WaveMusicTrack>.from(popular), startIndex: i),
                    onLike: () => music.toggleLike(track),
                    onMore: () => showWaveMusicTrackActions(context, track),
                  );
                }),
              ],
              if (albums.isNotEmpty) _albumRow('Albums', albums, context),
              if (singles.isNotEmpty) _albumRow('Singles', singles, context),
              if (playlists.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Playlists', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: playlists.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => WaveMusicPlaylistCard(
                      playlist: playlists[i],
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WaveMusicPlaylistScreen(playlistId: playlists[i].id))),
                    ),
                  ),
                ),
              ],
              if (related.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Related artists', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: related.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => WaveMusicArtistCard(
                      artist: related[i],
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WaveMusicArtistScreen(artistId: related[i].id))),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _albumRow(String title, List<WaveMusicAlbum> albums, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: albums.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => WaveMusicAlbumCard(
              album: albums[i],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WaveMusicAlbumScreen(albumId: albums[i].id))),
            ),
          ),
        ),
      ],
    );
  }
}
