import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/wave_music_track.dart';
import '../providers/wave_music_provider.dart';
import '../screens/wave_music_album_screen.dart';
import '../screens/wave_music_artist_screen.dart';
import '../screens/wave_music_playlist_screen.dart';

Future<void> showWaveMusicTrackActions(BuildContext context, WaveMusicTrack track) async {
  final music = context.read<WaveMusicProvider>();
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.cardColor,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_play, color: Colors.white),
              title: const Text('Play next', style: TextStyle(color: Colors.white)),
              onTap: () {
                music.playNext(track);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music, color: Colors.white),
              title: const Text('Add to queue', style: TextStyle(color: Colors.white)),
              onTap: () {
                music.addToQueue(track);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(music.isLiked(track.id) ? Icons.favorite : Icons.favorite_border, color: Colors.white),
              title: Text(music.isLiked(track.id) ? 'Unlike' : 'Like', style: const TextStyle(color: Colors.white)),
              onTap: () {
                music.toggleLike(track);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: Colors.white),
              title: const Text('Add to playlist', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await _pickPlaylist(context, music, track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.album_outlined, color: Colors.white),
              title: const Text('Go to album', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => WaveMusicAlbumScreen(albumId: track.albumId)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline, color: Colors.white),
              title: const Text('Go to artist', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => WaveMusicArtistScreen(artistId: track.artistId)));
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _pickPlaylist(BuildContext context, WaveMusicProvider music, WaveMusicTrack track) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.cardColor,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add, color: Colors.white),
              title: const Text('New playlist', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final created = await music.createPlaylist('${track.artist} mix');
                await music.addTrackToPlaylist(created.id, track);
              },
            ),
            ...music.userPlaylists.map(
              (p) => ListTile(
                title: Text(p.title, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  music.addTrackToPlaylist(p.id, track);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> promptCreatePlaylist(BuildContext context) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.cardColor,
      title: const Text('New playlist', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(hintText: 'Playlist name', hintStyle: TextStyle(color: AppTheme.textTertiary)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Create')),
      ],
    ),
  );
  if (name == null || name.trim().isEmpty) return;
  if (!context.mounted) return;
  final playlist = await context.read<WaveMusicProvider>().createPlaylist(name);
  if (!context.mounted) return;
  Navigator.push(context, MaterialPageRoute(builder: (_) => WaveMusicPlaylistScreen(playlistId: playlist.id)));
}
