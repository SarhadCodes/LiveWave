import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/wave_music_album.dart';
import '../models/wave_music_artist.dart';
import '../models/wave_music_playlist.dart';
import '../models/wave_music_track.dart';
import 'wave_music_cache.dart';
import 'wave_music_catalog.dart';

/// YouTube / YouTube Music catalog through the Android NewPipe Extractor.
/// Flutter never imports NewPipe types.
class NewPipeMusicCatalog implements WaveMusicCatalogService {
  NewPipeMusicCatalog({WaveMusicCache? cache}) : _cache = cache ?? WaveMusicCache.instance;

  static const provider = 'youtube';
  static const _channel = MethodChannel('wave_music_player');

  final WaveMusicCache _cache;
  final Map<String, WaveMusicTrack> _tracks = {};
  final Map<String, WaveMusicAlbum> _albums = {};
  final Map<String, WaveMusicArtist> _artists = {};
  final Map<String, WaveMusicPlaylist> _playlists = {};

  bool get _supported => !kIsWeb && Platform.isAndroid;

  @override
  Future<WaveMusicHomeData> getHome() async {
    const key = 'np_home';
    final cached = _cache.get<WaveMusicHomeData>(key);
    if (cached != null) return cached;
    final trending = await getTrending(limit: 16);
    final playlists = await getPlaylists();
    final albums = await getAlbums(limit: 8);
    final home = WaveMusicHomeData(
      trending: trending,
      popularSongs: trending.take(12).toList(),
      quickPicks: trending.take(8).toList(),
      popularArtists: _artistsFromTracks(trending).take(12).toList(),
      albums: albums,
      newReleases: albums.take(8).toList(),
      playlists: playlists,
      recommended: trending.skip(8).take(12).toList(),
    );
    _cache.set(key, home, ttl: const Duration(minutes: 15));
    return home;
  }

  @override
  Future<List<WaveMusicTrack>> getTrending({int limit = 40}) async {
    final rows = await _songs('music', limit: limit);
    return rows.take(limit).toList();
  }

  @override
  Future<List<WaveMusicTrack>> getRecommendations({String? seedArtist}) async {
    if (seedArtist != null && seedArtist.trim().isNotEmpty) {
      final tracks = await _songs(seedArtist, limit: 16);
      if (tracks.isNotEmpty) return tracks;
    }
    return getTrending(limit: 16);
  }

  @override
  Future<List<WaveMusicTrack>> getSongs({int offset = 0, int limit = 40}) async {
    final all = await getTrending(limit: 40);
    if (offset >= all.length) return const [];
    return all.skip(offset).take(limit).toList();
  }

  @override
  Future<List<WaveMusicArtist>> getArtists({int limit = 30}) async {
    final songs = await getTrending(limit: 24);
    return _artistsFromTracks(songs).take(limit).toList();
  }

  @override
  Future<WaveMusicArtist?> getArtist(String id) async {
    final details = await getArtistDetails(id);
    return details.artist.name.isEmpty ? null : details.artist;
  }

  @override
  Future<WaveMusicArtistDetails> getArtistDetails(String id) async {
    final known = _artists[id];
    final name = known?.name ?? '';
    final url = known?.providerId.isNotEmpty == true ? known!.providerId : id;
    final raw = await _invoke('loadCollection', {
      'url': url,
      'kind': 'artist',
      'name': name,
    });
    final tracks = _trackList(raw['tracks']);
    final artist = (known ??
            WaveMusicArtist(
              id: id,
              name: raw['title']?.toString() ?? name,
              artworkUrl: raw['artworkUrl']?.toString() ?? '',
              provider: provider,
              providerId: url,
            ))
        .copyWith(popularTrackIds: tracks.map((track) => track.id).toList());
    _artists[artist.id] = artist;
    return WaveMusicArtistDetails(artist: artist, popular: tracks);
  }

  @override
  Future<List<WaveMusicAlbum>> getAlbums({int limit = 30}) async {
    final raw = await _invoke('searchMusic', {'query': 'album', 'limit': limit});
    return _albumList(raw['albums']).take(limit).toList();
  }

  @override
  Future<WaveMusicAlbum?> getAlbum(String id) async {
    final known = _albums[id];
    final url = known?.providerId.isNotEmpty == true ? known!.providerId : id;
    final loaded = await _loadPlaylistLike(url, album: true, fallbackTitle: known?.title ?? '');
    return loaded.$1 ?? known;
  }

  @override
  Future<List<WaveMusicPlaylist>> getPlaylists() async {
    final raw = await _invoke('searchMusic', {'query': 'music', 'limit': 12});
    return _playlistList(raw['playlists']);
  }

  @override
  Future<WaveMusicPlaylist?> getPlaylist(String id) async {
    final known = _playlists[id];
    final url = known?.providerId.isNotEmpty == true ? known!.providerId : id;
    final loaded = await _loadPlaylistLike(url, album: false, fallbackTitle: known?.title ?? '');
    return loaded.$2 ?? known;
  }

  @override
  Future<WaveMusicTrack?> getTrack(String id) async => _tracks[id];

  @override
  Future<List<WaveMusicTrack>> tracksForIds(List<String> ids) async {
    return [for (final id in ids) if (_tracks[id] != null) _tracks[id]!];
  }

  @override
  Future<List<WaveMusicTrack>> getRelatedTracks(WaveMusicTrack track) {
    return _songs('${track.artist} ${track.title}', limit: 12);
  }

  @override
  Future<WaveMusicSearchResult> search(String query, {int offset = 0, int limit = 25}) async {
    final q = query.trim();
    if (q.isEmpty) return const WaveMusicSearchResult();
    final cacheKey = 'np_search:${q.toLowerCase()}';
    if (offset == 0) {
      final cached = _cache.get<WaveMusicSearchResult>(cacheKey);
      if (cached != null) return cached;
    }
    final raw = await _invoke('searchMusic', {'query': q, 'limit': limit});
    final result = WaveMusicSearchResult(
      tracks: _trackList(raw['tracks']),
      artists: _artistList(raw['artists']),
      albums: _albumList(raw['albums']),
      playlists: _playlistList(raw['playlists']),
    );
    if (offset == 0) {
      _cache.set(cacheKey, result, ttl: const Duration(minutes: 8));
    }
    for (final track in result.tracks) {
      debugPrint('[WAVE_SEARCH] title=${track.title} artist=${track.artist} type=track id=${track.providerId}');
    }
    return result;
  }

  Future<List<WaveMusicTrack>> _songs(String query, {required int limit}) async {
    final raw = await _invoke('musicSongs', {'query': query, 'limit': limit});
    if (raw['items'] is List) return _trackList(raw['items']);
    return _trackList(raw['data']);
  }

  Future<(WaveMusicAlbum?, WaveMusicPlaylist?)> _loadPlaylistLike(
    String url, {
    required bool album,
    required String fallbackTitle,
  }) async {
    final raw = await _invoke('loadCollection', {
      'url': url,
      'kind': album ? 'album' : 'playlist',
      'name': fallbackTitle,
    });
    final tracks = _trackList(raw['tracks']);
    final title = (raw['title']?.toString() ?? fallbackTitle).trim();
    final artwork = raw['artworkUrl']?.toString() ?? '';
    final artist = raw['uploader']?.toString() ?? '';
    if (album) {
      final item = WaveMusicAlbum(
        id: url,
        title: title,
        artist: artist.isEmpty ? 'Unknown artist' : artist,
        artistId: '',
        artworkUrl: artwork,
        year: 0,
        trackIds: tracks.map((track) => track.id).toList(),
        trackCount: tracks.length,
        provider: provider,
        providerId: url,
      );
      _albums[item.id] = item;
      return (item, null);
    }
    final item = WaveMusicPlaylist(
      id: url,
      title: title,
      artworkUrl: artwork,
      trackIds: tracks.map((track) => track.id).toList(),
      provider: provider,
      providerId: url,
    );
    _playlists[item.id] = item;
    return (null, item);
  }

  List<WaveMusicTrack> _trackList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <WaveMusicTrack>[];
    for (final row in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(row);
      final id = map['id']?.toString() ?? '';
      final title = map['title']?.toString() ?? '';
      if (id.isEmpty || title.isEmpty) continue;
      final artistUrl = map['artistUrl']?.toString() ?? '';
      final track = WaveMusicTrack(
        id: 'yt_$id',
        title: title,
        artist: (map['artist']?.toString() ?? '').trim().isEmpty ? 'Unknown artist' : map['artist'].toString(),
        artistId: artistUrl,
        album: map['album']?.toString() ?? '',
        albumId: '',
        artworkUrl: map['artworkUrl']?.toString() ?? '',
        audioUrl: '',
        durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
        provider: provider,
        providerId: id,
        access: 'playable',
        permalinkUrl: map['url']?.toString() ?? '',
      );
      _tracks[track.id] = track;
      if (artistUrl.isNotEmpty) {
        _artists.putIfAbsent(
          artistUrl,
          () => WaveMusicArtist(
            id: artistUrl,
            name: track.artist,
            artworkUrl: track.artworkUrl,
            provider: provider,
            providerId: artistUrl,
          ),
        );
      }
      out.add(track);
    }
    return out;
  }

  List<WaveMusicArtist> _artistList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <WaveMusicArtist>[];
    for (final row in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(row);
      final url = map['url']?.toString() ?? '';
      final name = map['title']?.toString() ?? '';
      if (url.isEmpty || name.isEmpty) continue;
      final subs = (map['subscriberCount'] as num?)?.toInt() ?? 0;
      final artist = WaveMusicArtist(
        id: url,
        name: name,
        artworkUrl: map['artworkUrl']?.toString() ?? '',
        bio: map['description']?.toString() ?? '',
        provider: provider,
        providerId: url,
        trackCount: subs,
      );
      _artists[artist.id] = artist;
      out.add(artist);
    }
    return out;
  }

  List<WaveMusicAlbum> _albumList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <WaveMusicAlbum>[];
    for (final row in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(row);
      final url = map['url']?.toString() ?? '';
      final title = map['title']?.toString() ?? '';
      if (url.isEmpty || title.isEmpty) continue;
      final album = WaveMusicAlbum(
        id: url,
        title: title,
        artist: (map['artist']?.toString() ?? '').trim().isEmpty ? 'Unknown artist' : map['artist'].toString(),
        artistId: '',
        artworkUrl: map['artworkUrl']?.toString() ?? '',
        year: 0,
        trackCount: (map['trackCount'] as num?)?.toInt() ?? 0,
        provider: provider,
        providerId: url,
      );
      _albums[album.id] = album;
      out.add(album);
    }
    return out;
  }

  List<WaveMusicPlaylist> _playlistList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <WaveMusicPlaylist>[];
    for (final row in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(row);
      final url = map['url']?.toString() ?? '';
      final title = map['title']?.toString() ?? '';
      if (url.isEmpty || title.isEmpty) continue;
      final playlist = WaveMusicPlaylist(
        id: url,
        title: title,
        description: map['artist']?.toString() ?? '',
        artworkUrl: map['artworkUrl']?.toString() ?? '',
        provider: provider,
        providerId: url,
      );
      _playlists[playlist.id] = playlist;
      out.add(playlist);
    }
    return out;
  }

  List<WaveMusicArtist> _artistsFromTracks(List<WaveMusicTrack> tracks) {
    final seen = <String>{};
    final out = <WaveMusicArtist>[];
    for (final track in tracks) {
      if (track.artistId.isEmpty || !seen.add(track.artistId)) continue;
      out.add(
        _artists[track.artistId] ??
            WaveMusicArtist(
              id: track.artistId,
              name: track.artist,
              artworkUrl: track.artworkUrl,
              provider: provider,
              providerId: track.artistId,
            ),
      );
    }
    return out;
  }

  Future<Map<String, dynamic>> _invoke(String method, Map<String, dynamic> args) async {
    if (!_supported) {
      throw StateError('YouTube Music search is available on Android.');
    }
    final raw = await _channel.invokeMethod<dynamic>(method, args);
    if (raw is List) return {'data': raw, 'items': raw};
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }
}
