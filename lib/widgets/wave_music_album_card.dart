import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/wave_music_album.dart';
import '../models/wave_music_artist.dart';
import '../models/wave_music_playlist.dart';
import '../utils/tv_row_focus.dart';
import 'wave_music_format.dart';

class WaveMusicAlbumCard extends StatelessWidget {
  final WaveMusicAlbum album;
  final double width;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final FocusNode? focusPrevious;
  final FocusNode? focusNext;
  final VoidCallback? onMoveToSidebar;

  const WaveMusicAlbumCard({
    super.key,
    required this.album,
    required this.onTap,
    this.width = 132,
    this.focusNode,
    this.focusPrevious,
    this.focusNext,
    this.onMoveToSidebar,
  });

  @override
  Widget build(BuildContext context) {
    return _ArtCard(
      width: width,
      title: album.title,
      subtitle: album.artist,
      imageUrl: album.artworkUrl,
      onTap: onTap,
      focusNode: focusNode,
      focusPrevious: focusPrevious,
      focusNext: focusNext,
      onMoveToSidebar: onMoveToSidebar,
    );
  }
}

class WaveMusicArtistCard extends StatelessWidget {
  final WaveMusicArtist artist;
  final double width;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final FocusNode? focusPrevious;
  final FocusNode? focusNext;
  final VoidCallback? onMoveToSidebar;

  const WaveMusicArtistCard({
    super.key,
    required this.artist,
    required this.onTap,
    this.width = 132,
    this.focusNode,
    this.focusPrevious,
    this.focusNext,
    this.onMoveToSidebar,
  });

  @override
  Widget build(BuildContext context) {
    return _ArtCard(
      width: width,
      title: artist.name,
      subtitle: 'Artist',
      imageUrl: artist.artworkUrl,
      circular: true,
      onTap: onTap,
      focusNode: focusNode,
      focusPrevious: focusPrevious,
      focusNext: focusNext,
      onMoveToSidebar: onMoveToSidebar,
    );
  }
}

class WaveMusicPlaylistCard extends StatelessWidget {
  final WaveMusicPlaylist playlist;
  final double width;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final FocusNode? focusPrevious;
  final FocusNode? focusNext;
  final VoidCallback? onMoveToSidebar;

  const WaveMusicPlaylistCard({
    super.key,
    required this.playlist,
    required this.onTap,
    this.width = 132,
    this.focusNode,
    this.focusPrevious,
    this.focusNext,
    this.onMoveToSidebar,
  });

  @override
  Widget build(BuildContext context) {
    return _ArtCard(
      width: width,
      title: playlist.title,
      subtitle: '${playlist.trackIds.length} songs',
      imageUrl: playlist.artworkUrl,
      onTap: onTap,
      focusNode: focusNode,
      focusPrevious: focusPrevious,
      focusNext: focusNext,
      onMoveToSidebar: onMoveToSidebar,
    );
  }
}

class _ArtCard extends StatelessWidget {
  final double width;
  final String title;
  final String subtitle;
  final String imageUrl;
  final bool circular;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final FocusNode? focusPrevious;
  final FocusNode? focusNext;
  final VoidCallback? onMoveToSidebar;

  const _ArtCard({
    required this.width,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
    this.circular = false,
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
        final row = handleTvRowHorizontalKeys(
          event,
          focusPrevious: focusPrevious,
          focusNext: focusNext,
          onMoveToSidebar: onMoveToSidebar,
        );
        if (row != KeyEventResult.ignored) return row;
        return handleMusicSelect(event, onTap);
      },
      child: Builder(builder: (context) {
        final focused = Focus.of(context).hasFocus;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: width,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(circular ? 80 : 8),
                  child: SizedBox(
                    width: width - 8,
                    height: width - 8,
                    child: MusicArtwork(url: imageUrl, logicalSize: width),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
