import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/wave_music_album.dart';
import '../models/wave_music_artist.dart';
import '../models/wave_music_playlist.dart';
import '../models/wave_music_track.dart';
import '../providers/settings_provider.dart';
import '../providers/wave_music_provider.dart';
import '../widgets/tv_navigation_scope.dart';
import '../widgets/wave_music_actions.dart';
import '../widgets/wave_music_format.dart';
import '../widgets/wave_music_album_card.dart';
import '../widgets/wave_music_track_tile.dart';
import 'wave_music_album_screen.dart';
import 'wave_music_artist_screen.dart';
import 'wave_music_playlist_screen.dart';
import 'wave_music_search_screen.dart';

class WaveHomeScreen extends StatefulWidget {
  const WaveHomeScreen({super.key});

  @override
  State<WaveHomeScreen> createState() => WaveHomeScreenState();
}

class WaveHomeScreenState extends State<WaveHomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'music_search_header');
  WaveMusicTab _section = WaveMusicTab.home;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void focusPrimary() {
    if (!mounted) return;
    _searchFocus.requestFocus();
  }

  void _openSection(WaveMusicProvider music, WaveMusicTab tab) {
    _section = tab;
    _searchController.clear();
    music.onSearchChanged('');
    music.setTab(tab);
  }

  void _onSearchChanged(WaveMusicProvider music, String value) {
    music.onSearchChanged(value);
    if (value.trim().isEmpty) {
      if (music.tab == WaveMusicTab.search) music.setTab(_section);
      return;
    }
    if (music.tab == WaveMusicTab.home ||
        music.tab == WaveMusicTab.playlists ||
        music.tab == WaveMusicTab.liked) {
      _section = music.tab;
    }
    if (music.tab != WaveMusicTab.search) music.setTab(WaveMusicTab.search);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final music = context.watch<WaveMusicProvider>();
    final isMobile = context.watch<SettingsProvider>().layoutMode == 'mobile';
    final tvNav = TvNavigationScope.maybeOf(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, isMobile ? 12 : 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _openSection(music, WaveMusicTab.home),
                  child: Text(
                    l10n.translate('wave'),
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: isMobile ? 26 : 22, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        focusNode: _searchFocus,
                        controller: _searchController,
                        onChanged: (value) => _onSearchChanged(music, value),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: l10n.translate('music_search'),
                          hintStyle: const TextStyle(color: AppTheme.textTertiary),
                          prefixIcon: const Icon(Icons.search, color: Colors.white54),
                          isDense: true,
                          filled: true,
                          fillColor: AppTheme.surfaceColor,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _HeaderIcon(
                      icon: Icons.queue_music_rounded,
                      selected: music.tab == WaveMusicTab.playlists,
                      tooltip: l10n.translate('music_playlists'),
                      onTap: () => _openSection(music, WaveMusicTab.playlists),
                    ),
                    const SizedBox(width: 4),
                    _HeaderIcon(
                      icon: music.tab == WaveMusicTab.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      selected: music.tab == WaveMusicTab.liked,
                      tooltip: l10n.translate('music_liked'),
                      onTap: () => _openSection(music, WaveMusicTab.liked),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: music.loading
                ? const _MusicSkeleton()
                : music.loadError != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(music.loadError!, style: const TextStyle(color: Colors.white54)),
                            const SizedBox(height: 16),
                            FilledButton(onPressed: music.retryLoad, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : music.searchQuery.trim().isNotEmpty
                    ? WaveMusicSearchScreen(controller: _searchController, showField: false)
                    : switch (music.tab) {
                        WaveMusicTab.playlists => _PlaylistBody(
                            onCreate: () => promptCreatePlaylist(context),
                            onBack: () => _openSection(music, WaveMusicTab.home),
                          ),
                        WaveMusicTab.liked => _TrackList(
                            tracks: music.likedTracks,
                            empty: 'No liked songs yet',
                            header: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _BackHomeButton(onPressed: () => _openSection(music, WaveMusicTab.home)),
                                if (music.likedTracks.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                    child: FilledButton.icon(
                                      onPressed: () => music.playLiked(),
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Play liked songs'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        _ => _HomeBody(onSidebar: tvNav?.focusSidebar),
                      },
          ),
        ],
      ),
    );
  }
}

class _MusicSkeleton extends StatefulWidget {
  const _MusicSkeleton();

  @override
  State<_MusicSkeleton> createState() => _MusicSkeletonState();
}

class _MusicSkeletonState extends State<_MusicSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 0.85).animate(_pulse),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Align(alignment: Alignment.centerLeft, child: _block(width: 128, height: 14)),
          const SizedBox(height: 14),
          for (var i = 0; i < 5; i++) ...[
            _songRow(),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: _block(width: 110, height: 14)),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(child: _SkeletonCover()),
              SizedBox(width: 12),
              Expanded(child: _SkeletonCover()),
              SizedBox(width: 12),
              Expanded(child: _SkeletonCover()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _songRow() {
    return Row(
      children: [
        _block(width: 48, height: 48, radius: 6),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(widthFactor: 0.72, child: _block(width: double.infinity, height: 12)),
              const SizedBox(height: 8),
              FractionallySizedBox(widthFactor: 0.4, child: _block(width: double.infinity, height: 10)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _block({required double width, required double height, double radius = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _SkeletonCover extends StatelessWidget {
  const _SkeletonCover();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIcon({
    required this.icon,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: selected ? Colors.black : Colors.white),
      style: IconButton.styleFrom(
        backgroundColor: selected ? Colors.white : AppTheme.surfaceColor,
        fixedSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _BackHomeButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _BackHomeButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  final VoidCallback? onSidebar;
  const _HomeBody({this.onSidebar});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<WaveMusicProvider>();
    final home = music.home;
    if (home == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: EdgeInsets.only(bottom: waveMusicListBottomPadding(context)),
      children: [
        if (music.recents.isNotEmpty)
          _TrackRow(
            title: l10n.translate('music_recent'),
            tracks: music.recents.map((e) => e.track).take(10).toList(),
            onSidebar: onSidebar,
          ),
        _TrackRow(title: l10n.translate('music_quick_picks'), tracks: home.quickPicks, onSidebar: onSidebar),
        _TrackRow(title: l10n.translate('music_trending'), tracks: home.trending, onSidebar: onSidebar),
        _TrackRow(title: l10n.translate('music_popular_songs'), tracks: home.popularSongs, onSidebar: onSidebar),
        _ArtistRow(title: l10n.translate('music_popular_artists'), artists: home.popularArtists, onSidebar: onSidebar),
        _AlbumRow(title: l10n.translate('music_new_releases'), albums: home.newReleases, onSidebar: onSidebar),
        _AlbumRow(title: l10n.translate('music_albums'), albums: home.albums, onSidebar: onSidebar),
        _PlaylistRow(title: l10n.translate('music_playlists'), playlists: home.playlists, onSidebar: onSidebar),
        _TrackRow(title: l10n.translate('music_recommended'), tracks: home.recommended, onSidebar: onSidebar),
      ],
    );
  }
}

class _TrackRow extends StatelessWidget {
  final String title;
  final List<WaveMusicTrack> tracks;
  final VoidCallback? onSidebar;
  const _TrackRow({required this.title, required this.tracks, this.onSidebar});

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const SizedBox.shrink();
    final music = context.watch<WaveMusicProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        ...tracks.take(5).map(
              (t) => WaveMusicTrackTile(
                track: t,
                playing: music.currentTrack?.id == t.id,
                onTap: () => music.playTrack(t, contextQueue: tracks),
                onLike: () => music.toggleLike(t),
                onMore: () => showWaveMusicTrackActions(context, t),
                onMoveToSidebar: onSidebar,
              ),
            ),
      ],
    );
  }
}

class _AlbumRow extends StatelessWidget {
  final String title;
  final List<WaveMusicAlbum> albums;
  final VoidCallback? onSidebar;
  const _AlbumRow({required this.title, required this.albums, this.onSidebar});

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        SizedBox(
          height: 210,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: albums.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => WaveMusicAlbumCard(
              album: albums[i],
              onMoveToSidebar: onSidebar,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WaveMusicAlbumScreen(albumId: albums[i].id))),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArtistRow extends StatelessWidget {
  final String title;
  final List<WaveMusicArtist> artists;
  final VoidCallback? onSidebar;
  const _ArtistRow({required this.title, required this.artists, this.onSidebar});

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        SizedBox(
          height: 210,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: artists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => WaveMusicArtistCard(
              artist: artists[i],
              onMoveToSidebar: onSidebar,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WaveMusicArtistScreen(artistId: artists[i].id))),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  final String title;
  final List<WaveMusicPlaylist> playlists;
  final VoidCallback? onSidebar;
  const _PlaylistRow({required this.title, required this.playlists, this.onSidebar});

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        SizedBox(
          height: 210,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: playlists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => WaveMusicPlaylistCard(
              playlist: playlists[i],
              onMoveToSidebar: onSidebar,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WaveMusicPlaylistScreen(playlistId: playlists[i].id))),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackList extends StatelessWidget {
  final List<WaveMusicTrack> tracks;
  final String empty;
  final Widget? header;
  const _TrackList({required this.tracks, required this.empty, this.header});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<WaveMusicProvider>();
    if (tracks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) header!,
          Expanded(child: Center(child: Text(empty, style: const TextStyle(color: Colors.white38)))),
        ],
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(bottom: waveMusicListBottomPadding(context)),
      itemCount: tracks.length + (header != null ? 1 : 0),
      itemBuilder: (context, i) {
        if (header != null && i == 0) return header!;
        final index = header != null ? i - 1 : i;
        final track = tracks[index];
        return WaveMusicTrackTile(
          track: track,
          index: index + 1,
          playing: music.currentTrack?.id == track.id,
          onTap: () => music.playTracks(tracks, startIndex: index),
          onLike: () => music.toggleLike(track),
          onMore: () => showWaveMusicTrackActions(context, track),
        );
      },
    );
  }
}

class _PlaylistBody extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onBack;
  const _PlaylistBody({required this.onCreate, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<WaveMusicProvider>();
    final all = [...music.userPlaylists, ...music.catalogPlaylists];
    return ListView(
      padding: EdgeInsets.fromLTRB(8, 0, 16, waveMusicListBottomPadding(context)),
      children: [
        Row(
          children: [
            _BackHomeButton(onPressed: onBack),
            const Spacer(),
            OutlinedButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('New playlist')),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: all
              .map(
                (p) => WaveMusicPlaylistCard(
                  playlist: p,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WaveMusicPlaylistScreen(playlistId: p.id))),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(text.toUpperCase(), style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 12)),
    );
  }
}
