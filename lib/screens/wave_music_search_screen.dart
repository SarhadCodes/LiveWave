import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/wave_music_provider.dart';
import '../widgets/wave_music_actions.dart';
import '../widgets/wave_music_format.dart';
import '../widgets/wave_music_album_card.dart';
import '../widgets/wave_music_track_tile.dart';
import 'wave_music_album_screen.dart';
import 'wave_music_artist_screen.dart';
import 'wave_music_playlist_screen.dart';

class WaveMusicSearchScreen extends StatefulWidget {
  final bool showField;
  final TextEditingController? controller;

  const WaveMusicSearchScreen({super.key, this.showField = true, this.controller});

  @override
  State<WaveMusicSearchScreen> createState() => _WaveMusicSearchScreenState();
}

class _WaveMusicSearchScreenState extends State<WaveMusicSearchScreen> {
  TextEditingController? _ownedController;
  final _focus = FocusNode(debugLabel: 'music_search');

  TextEditingController get _controller => widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _ownedController = TextEditingController();
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<WaveMusicProvider>();
    final result = music.searchResult;
    return Column(
      children: [
        if (widget.showField)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              focusNode: _focus,
              controller: _controller,
              onChanged: music.onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search songs, artists, albums',
                hintStyle: const TextStyle(color: AppTheme.textTertiary),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: AppTheme.surfaceColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
        Expanded(
          child: music.searchQuery.trim().isEmpty
              ? _RecentSearches(
                  queries: music.recentQueries,
                  onTap: (q) {
                    _controller.text = q;
                    music.onSearchChanged(q);
                  },
                )
              : music.searching && result.tracks.isEmpty && result.artists.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : music.searchError != null && result.tracks.isEmpty
                      ? Center(child: Text(music.searchError!, style: const TextStyle(color: Colors.white54)))
                      : ListView(
                  padding: EdgeInsets.fromLTRB(8, 0, 8, waveMusicListBottomPadding(context)),
                  children: [
                    if (result.artists.isNotEmpty) ...[
                      const _Head('Artists'),
                      SizedBox(
                        height: 210,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          scrollDirection: Axis.horizontal,
                          itemCount: result.artists.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, i) => WaveMusicArtistCard(
                            artist: result.artists[i],
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WaveMusicArtistScreen(artistId: result.artists[i].id))),
                          ),
                        ),
                      ),
                    ],
                    if (result.albums.isNotEmpty) ...[
                      const _Head('Albums'),
                      SizedBox(
                        height: 210,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          scrollDirection: Axis.horizontal,
                          itemCount: result.albums.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, i) => WaveMusicAlbumCard(
                            album: result.albums[i],
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WaveMusicAlbumScreen(albumId: result.albums[i].id))),
                          ),
                        ),
                      ),
                    ],
                    if (result.tracks.isNotEmpty) ...[
                      const _Head('Songs'),
                      ...result.tracks.map(
                        (t) => WaveMusicTrackTile(
                          track: t,
                          playing: music.currentTrack?.id == t.id,
                          onTap: () => music.playTrack(t, contextQueue: result.tracks),
                          onLike: () => music.toggleLike(t),
                          onMore: () => showWaveMusicTrackActions(context, t),
                        ),
                      ),
                    ],
                    if (result.playlists.isNotEmpty) ...[
                      const _Head('Playlists'),
                      SizedBox(
                        height: 210,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          scrollDirection: Axis.horizontal,
                          itemCount: result.playlists.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, i) => WaveMusicPlaylistCard(
                            playlist: result.playlists[i],
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WaveMusicPlaylistScreen(playlistId: result.playlists[i].id))),
                          ),
                        ),
                      ),
                    ],
                    if (result.tracks.isEmpty && result.artists.isEmpty && result.albums.isEmpty && result.playlists.isEmpty && !music.searching)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(child: Text('Nothing found', style: TextStyle(color: Colors.white38))),
                      ),
                    if (result.hasMore)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        child: OutlinedButton(
                          onPressed: music.searching ? null : music.loadMoreSearch,
                          child: Text(music.searching ? 'Loading…' : 'More songs'),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  final String text;
  const _Head(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text.toUpperCase(), style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 12)),
    );
  }
}

class _RecentSearches extends StatelessWidget {
  final List<String> queries;
  final void Function(String query) onTap;
  const _RecentSearches({required this.queries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (queries.isEmpty) {
      return const Center(child: Text('Search songs, artists, albums', style: TextStyle(color: Colors.white38)));
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, waveMusicListBottomPadding(context)),
      children: [
        const Text('RECENT', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 12)),
        const SizedBox(height: 8),
        ...queries.map(
          (q) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history, color: Colors.white38),
            title: Text(q, style: const TextStyle(color: Colors.white)),
            onTap: () => onTap(q),
          ),
        ),
      ],
    );
  }
}
