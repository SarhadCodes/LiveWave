import '../models/wave_music_album.dart';
import '../models/wave_music_artist.dart';
import '../models/wave_music_playlist.dart';
import '../models/wave_music_track.dart';
import 'soundcloud_api.dart';
import 'wave_music_cache.dart';
import 'wave_music_catalog.dart';
import 'wave_music_http.dart';

/// Official SoundCloud catalog mapped onto WAVE MUSIC models.
class SoundCloudMusicCatalog implements WaveMusicCatalogService {
  SoundCloudMusicCatalog({
    SoundCloudApi? api,
    WaveMusicCache? cache,
  })  : _api = api ?? SoundCloudApi.instance,
        _cache = cache ?? WaveMusicCache.instance;

  static const provider = 'soundcloud';

  final SoundCloudApi _api;
  final WaveMusicCache _cache;
  final Map<String, WaveMusicTrack> _tracks = {};
  final Map<String, WaveMusicAlbum> _albums = {};
  final Map<String, WaveMusicArtist> _artists = {};
  final Map<String, WaveMusicPlaylist> _playlists = {};
  final Map<String, String> _nextHref = {};

  @override
  Future<WaveMusicHomeData> getHome() async {
    const key = 'sc_home';
    final cached = _cache.get<WaveMusicHomeData>(key);
    if (cached != null) return cached;
    if (!_api.isConfigured) {
      throw StateError('SoundCloud is not configured.');
    }

    final trending = await getTrending(limit: 16);
    final pop = await _searchTracks('Pop', limit: 12);
    final rock = await _searchTracks('Rock', limit: 12);
    final kurdish = await _searchTracks('Kurdish', limit: 12);
    final arabic = await _searchTracks('Arabic', limit: 12);
    final playlistHits = await _searchPlaylists('Pop', limit: 10);

    final albums = <WaveMusicAlbum>[];
    final playlists = <WaveMusicPlaylist>[];
    for (final item in playlistHits) {
      if (item.$1 != null) {
        albums.add(item.$1!);
      } else if (item.$2 != null) {
        playlists.add(item.$2!);
      }
    }

    final artists = _artistsFromTracks([...trending, ...pop, ...kurdish]).take(12).toList();
    final home = WaveMusicHomeData(
      trending: trending,
      popularSongs: pop.isNotEmpty ? pop : trending.take(12).toList(),
      quickPicks: trending.take(8).toList(),
      popularArtists: artists,
      albums: albums,
      newReleases: albums.take(8).toList(),
      playlists: playlists,
      recommended: rock.isNotEmpty
          ? rock
          : (arabic.isNotEmpty ? arabic : trending.skip(8).take(12).toList()),
    );
    _cache.set(key, home, ttl: const Duration(minutes: 20));
    return home;
  }

  @override
  Future<List<WaveMusicTrack>> getTrending({int limit = 40}) async {
    const key = 'sc_trending';
    final cached = _cache.get<List<WaveMusicTrack>>(key);
    if (cached != null) return cached.take(limit).toList();
    var tracks = await _listTracks('/tracks', {
      'access': 'playable',
      'limit': '${limit.clamp(1, 50)}',
      'linked_partitioning': 'true',
    });
    if (tracks.isEmpty) {
      tracks = await _searchTracks('music', limit: limit);
    }
    _cache.set(key, tracks, ttl: const Duration(minutes: 20));
    return tracks.take(limit).toList();
  }

  @override
  Future<List<WaveMusicTrack>> getRecommendations({String? seedArtist}) async {
    if (seedArtist != null && seedArtist.trim().isNotEmpty) {
      final result = await search(seedArtist, limit: 16);
      if (result.tracks.isNotEmpty) return result.tracks;
    }
    return getTrending(limit: 16);
  }

  @override
  Future<List<WaveMusicTrack>> getSongs({int offset = 0, int limit = 40}) async {
    final all = await getTrending(limit: 50);
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
    final numeric = _bareId(id);
    if (numeric == null) {
      return const WaveMusicArtistDetails(artist: WaveMusicArtist(id: '', name: '', artworkUrl: ''));
    }
    final cacheKey = 'sc_artist:$numeric';
    final cached = _cache.get<WaveMusicArtistDetails>(cacheKey);
    if (cached != null) return cached;

    Map<String, dynamic> userJson;
    try {
      userJson = await _api.getJson('/users/$numeric');
    } on HttpException catch (e) {
      if (e.statusCode == 404) {
        return const WaveMusicArtistDetails(artist: WaveMusicArtist(id: '', name: '', artworkUrl: ''));
      }
      rethrow;
    }
    final artist = _mapUser(userJson);
    if (artist == null) {
      return const WaveMusicArtistDetails(artist: WaveMusicArtist(id: '', name: '', artworkUrl: ''));
    }

    final tracks = await _listTracks('/users/$numeric/tracks', {
      'access': 'playable',
      'limit': '30',
      'linked_partitioning': 'true',
    });
    final playlistRows = await _listMaps('/users/$numeric/playlists', {
      'limit': '16',
      'linked_partitioning': 'true',
    });
    final albums = <WaveMusicAlbum>[];
    final playlists = <WaveMusicPlaylist>[];
    for (final row in playlistRows) {
      final mapped = _mapPlaylistOrAlbum(row);
      if (mapped.$1 != null) albums.add(mapped.$1!);
      if (mapped.$2 != null) playlists.add(mapped.$2!);
    }

    List<WaveMusicArtist> related = const [];
    try {
      final followings = await _listMaps('/users/$numeric/followings', {
        'limit': '8',
        'linked_partitioning': 'true',
      });
      related = followings.map(_mapUser).whereType<WaveMusicArtist>().toList();
    } catch (_) {}

    final details = WaveMusicArtistDetails(
      artist: artist.copyWith(
        popularTrackIds: tracks.map((t) => t.id).toList(),
        albumIds: albums.map((a) => a.id).toList(),
        relatedArtistIds: related.map((a) => a.id).toList(),
      ),
      popular: tracks,
      albums: albums,
      playlists: playlists,
      related: related,
    );
    _cache.set(cacheKey, details, ttl: const Duration(minutes: 30));
    return details;
  }

  @override
  Future<List<WaveMusicAlbum>> getAlbums({int limit = 30}) async {
    final home = _cache.get<WaveMusicHomeData>('sc_home');
    if (home != null && home.albums.isNotEmpty) return home.albums.take(limit).toList();
    final rows = await _searchPlaylists('album', limit: limit);
    return rows.map((e) => e.$1).whereType<WaveMusicAlbum>().take(limit).toList();
  }

  @override
  Future<WaveMusicAlbum?> getAlbum(String id) async {
    final numeric = _bareId(id);
    if (numeric == null) return _albums[id];
    if (_albums.containsKey('sc_pl_$numeric')) {
      final existing = _albums['sc_pl_$numeric']!;
      if (existing.trackIds.isNotEmpty) return existing;
    }
    final json = await _safeGet('/playlists/$numeric', {'access': 'playable'});
    if (json.isEmpty) return _albums[id];
    final mapped = _mapPlaylistOrAlbum(json);
    return mapped.$1 ?? _albums[id];
  }

  @override
  Future<List<WaveMusicPlaylist>> getPlaylists() async {
    final home = _cache.get<WaveMusicHomeData>('sc_home');
    if (home != null && home.playlists.isNotEmpty) return home.playlists;
    final rows = await _searchPlaylists('playlist', limit: 16);
    return rows.map((e) => e.$2).whereType<WaveMusicPlaylist>().toList();
  }

  @override
  Future<WaveMusicPlaylist?> getPlaylist(String id) async {
    final numeric = _bareId(id);
    if (numeric == null) return _playlists[id];
    final cached = _playlists['sc_pl_$numeric'];
    if (cached != null && cached.trackIds.isNotEmpty) return cached;
    final json = await _safeGet('/playlists/$numeric', {'access': 'playable'});
    if (json.isEmpty) return cached;
    final mapped = _mapPlaylistOrAlbum(json);
    if (mapped.$2 != null) return mapped.$2;
    final album = mapped.$1;
    if (album == null) return cached;
    return WaveMusicPlaylist(
      id: album.id,
      title: album.title,
      artworkUrl: album.artworkUrl,
      trackIds: album.trackIds,
      provider: provider,
      providerId: numeric,
      description: 'SoundCloud album',
    );
  }

  @override
  Future<WaveMusicTrack?> getTrack(String id) async {
    if (_tracks.containsKey(id)) return _tracks[id];
    final numeric = _bareId(id);
    if (numeric == null) return null;
    final json = await _safeGet('/tracks/$numeric');
    return _mapTrack(json);
  }

  @override
  Future<List<WaveMusicTrack>> tracksForIds(List<String> ids) async {
    final out = <WaveMusicTrack>[];
    for (final id in ids) {
      final track = _tracks[id] ?? await getTrack(id);
      if (track != null) out.add(track);
    }
    return out;
  }

  @override
  Future<List<WaveMusicTrack>> getRelatedTracks(WaveMusicTrack track) async {
    final numeric = _bareId(track.id);
    if (numeric == null) return getTrending(limit: 12);
    final related = await _listTracks('/tracks/$numeric/related', {
      'access': 'playable',
      'limit': '12',
      'linked_partitioning': 'true',
    });
    if (related.isNotEmpty) return related;
    return getTrending(limit: 12);
  }

  @override
  Future<WaveMusicSearchResult> search(String query, {int offset = 0, int limit = 25}) async {
    final q = query.trim();
    if (q.isEmpty) return const WaveMusicSearchResult();
    final cacheKey = 'sc_search:${q.toLowerCase()}:$offset';
    final cached = _cache.get<WaveMusicSearchResult>(cacheKey);
    if (cached != null) return cached;

    if (offset > 0) {
      final href = _nextHref['tracks:$q'];
      if (href != null && href.isNotEmpty) {
        final json = await _api.getUri(Uri.parse(href));
        final tracks = _mapTrackList(_collection(json));
        _rememberNext('tracks:$q', json);
        final result = WaveMusicSearchResult(
          tracks: tracks,
          hasMore: (_nextHref['tracks:$q'] ?? '').isNotEmpty,
          nextOffset: offset + tracks.length,
        );
        _cache.set(cacheKey, result, ttl: const Duration(minutes: 8));
        return result;
      }
    }

    late final List<WaveMusicTrack> tracks;
    late final List<WaveMusicArtist> artists;
    final albums = <WaveMusicAlbum>[];
    final playlists = <WaveMusicPlaylist>[];
    await Future.wait([
      _searchTracks(q, limit: limit).then((value) => tracks = value),
      _searchUsers(q, limit: 8).then((value) => artists = value),
      _searchPlaylists(q, limit: 10).then((rows) {
        for (final row in rows) {
          if (row.$1 != null) albums.add(row.$1!);
          if (row.$2 != null) playlists.add(row.$2!);
        }
      }),
    ]);

    final result = WaveMusicSearchResult(
      tracks: tracks,
      artists: artists,
      albums: albums,
      playlists: playlists,
      hasMore: (_nextHref['tracks:$q'] ?? '').isNotEmpty,
      nextOffset: offset + tracks.length,
    );
    _cache.set(cacheKey, result, ttl: const Duration(minutes: 8));
    return result;
  }

  Future<List<WaveMusicTrack>> _searchTracks(String q, {int limit = 20}) {
    return _listTracks('/tracks', {
      'q': q,
      'access': 'playable',
      'limit': '${limit.clamp(1, 50)}',
      'linked_partitioning': 'true',
    }, nextKey: 'tracks:$q');
  }

  Future<List<WaveMusicArtist>> _searchUsers(String q, {int limit = 8}) async {
    final rows = await _listMaps('/users', {
      'q': q,
      'limit': '$limit',
      'linked_partitioning': 'true',
    });
    return rows.map(_mapUser).whereType<WaveMusicArtist>().toList();
  }

  Future<List<(WaveMusicAlbum?, WaveMusicPlaylist?)>> _searchPlaylists(String q, {int limit = 10}) async {
    final rows = await _listMaps('/playlists', {
      'q': q,
      'limit': '$limit',
      'linked_partitioning': 'true',
    });
    return rows.map(_mapPlaylistOrAlbum).toList();
  }

  Future<List<WaveMusicTrack>> _listTracks(
    String path,
    Map<String, String> query, {
    String? nextKey,
  }) async {
    try {
      final json = await _api.getJson(path, query: query);
      if (nextKey != null) _rememberNext(nextKey, json);
      return _mapTrackList(_collection(json));
    } on HttpException catch (e) {
      if (e.statusCode == 400 || e.statusCode == 404) return const [];
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _listMaps(String path, Map<String, String> query) async {
    try {
      final json = await _api.getJson(path, query: query);
      return _collection(json);
    } on HttpException catch (e) {
      if (e.statusCode == 400 || e.statusCode == 404) return const [];
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _safeGet(String path, [Map<String, String>? query]) async {
    try {
      return await _api.getJson(path, query: query);
    } on HttpException catch (e) {
      if (e.statusCode == 400 || e.statusCode == 403 || e.statusCode == 404) return const {};
      rethrow;
    }
  }

  void _rememberNext(String key, Map<String, dynamic> json) {
    final href = json['next_href']?.toString() ?? '';
    if (href.isNotEmpty) {
      _nextHref[key] = href;
    } else {
      _nextHref.remove(key);
    }
  }

  List<Map<String, dynamic>> _collection(Map<String, dynamic> json) {
    final collection = json['collection'];
    if (collection is List) {
      return collection.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    final data = json['data'];
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (json['id'] != null) return [json];
    return const [];
  }

  List<WaveMusicTrack> _mapTrackList(List<Map<String, dynamic>> rows) {
    final out = <WaveMusicTrack>[];
    for (final row in rows) {
      final track = _mapTrack(row);
      if (track != null) out.add(track);
    }
    return out;
  }

  WaveMusicTrack? _mapTrack(Map<String, dynamic> row) {
    if (row.isEmpty) return null;
    final rawId = row['id']?.toString() ?? '';
    if (rawId.isEmpty) return null;
    final access = (row['access']?.toString() ?? '').toLowerCase();
    final title = (row['title']?.toString() ?? '').trim();
    if (title.isEmpty) return null;
    final user = _asMap(row['user']);
    final meta = _asMap(row['publisher_metadata']);
    final artist = (row['metadata_artist']?.toString() ?? '').trim().isNotEmpty
        ? row['metadata_artist'].toString().trim()
        : (meta['artist']?.toString() ?? '').trim().isNotEmpty
            ? meta['artist'].toString().trim()
            : (user['username']?.toString() ?? user['full_name']?.toString() ?? '').trim();
    final artistId = user['id']?.toString() ?? '';
    final duration = (row['duration'] as num?)?.toInt() ?? 0;
    final artwork = _upgradeArtwork(
      row['artwork_url']?.toString() ?? '',
      fallback: user['avatar_url']?.toString() ?? '',
    );
    final isPreview = access == 'preview';
    final albumTitle = (meta['album_title']?.toString() ?? '').trim();
    final track = WaveMusicTrack(
      id: 'sc_$rawId',
      title: title,
      artist: artist.isEmpty ? 'Unknown artist' : artist,
      artistId: artistId.isEmpty ? '' : 'sc_user_$artistId',
      album: albumTitle,
      albumId: '',
      artworkUrl: artwork,
      audioUrl: '',
      durationMs: duration < 0 ? 0 : duration,
      explicit: (row['tag_list']?.toString() ?? '').toLowerCase().contains('explicit'),
      genre: row['genre']?.toString() ?? '',
      provider: provider,
      providerId: rawId,
      isPreview: isPreview,
      access: access.isEmpty ? 'playable' : access,
      permalinkUrl: row['permalink_url']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
    );
    // Default empty access from older objects is treated as playable only when the
    // API listed the track under access=playable. Explicit preview/blocked stay out.
    if (!track.isPlayable) return null;
    _tracks[track.id] = track;
    final mappedArtist = _mapUser(user);
    if (mappedArtist != null) _artists[mappedArtist.id] = mappedArtist;
    return track;
  }

  WaveMusicArtist? _mapUser(Map<String, dynamic> row) {
    if (row.isEmpty) return null;
    final rawId = row['id']?.toString() ?? '';
    if (rawId.isEmpty) return null;
    final name = (row['username']?.toString() ?? row['full_name']?.toString() ?? '').trim();
    if (name.isEmpty) return null;
    final trackCount = (row['track_count'] as num?)?.toInt() ?? 0;
    final artist = WaveMusicArtist(
      id: 'sc_user_$rawId',
      name: name,
      artworkUrl: _upgradeArtwork(row['avatar_url']?.toString() ?? ''),
      bio: row['description']?.toString() ?? '',
      genre: trackCount > 0 ? '$trackCount tracks' : (row['city']?.toString() ?? ''),
      provider: provider,
      providerId: rawId,
      trackCount: trackCount,
    );
    _artists[artist.id] = artist;
    return artist;
  }

  (WaveMusicAlbum?, WaveMusicPlaylist?) _mapPlaylistOrAlbum(Map<String, dynamic> row) {
    final rawId = row['id']?.toString() ?? '';
    if (rawId.isEmpty) return (null, null);
    final title = (row['title']?.toString() ?? '').trim();
    if (title.isEmpty) return (null, null);
    final user = _asMap(row['user']);
    final artist = (user['username']?.toString() ?? '').trim();
    final artistId = user['id']?.toString() ?? '';
    final artwork = _upgradeArtwork(
      row['artwork_url']?.toString() ?? '',
      fallback: user['avatar_url']?.toString() ?? '',
    );
    final tracks = _playlistTrackIds(row);
    final isAlbum = _isAlbumSet(row);
    final year = _yearFrom(row['created_at']?.toString() ?? row['release_date']?.toString() ?? '');
    if (isAlbum) {
      final album = WaveMusicAlbum(
        id: 'sc_pl_$rawId',
        title: title,
        artist: artist.isEmpty ? 'Unknown artist' : artist,
        artistId: artistId.isEmpty ? '' : 'sc_user_$artistId',
        artworkUrl: artwork,
        year: year,
        trackIds: tracks,
        trackCount: (row['track_count'] as num?)?.toInt() ?? tracks.length,
        provider: provider,
        providerId: rawId,
      );
      _albums[album.id] = album;
      return (album, null);
    }
    final playlist = WaveMusicPlaylist(
      id: 'sc_pl_$rawId',
      title: title,
      description: row['description']?.toString() ?? '',
      artworkUrl: artwork,
      trackIds: tracks,
      provider: provider,
      providerId: rawId,
    );
    _playlists[playlist.id] = playlist;
    return (null, playlist);
  }

  List<String> _playlistTrackIds(Map<String, dynamic> row) {
    final tracks = row['tracks'];
    if (tracks is! List) return const [];
    final ids = <String>[];
    for (final item in tracks) {
      if (item is Map) {
        final mapped = _mapTrack(Map<String, dynamic>.from(item));
        if (mapped != null) {
          ids.add(mapped.id);
        } else {
          final id = item['id']?.toString();
          if (id != null && id.isNotEmpty) ids.add('sc_$id');
        }
      }
    }
    return ids;
  }

  bool _isAlbumSet(Map<String, dynamic> row) {
    if (row['is_album'] == true) return true;
    final setType = (row['set_type']?.toString() ?? '').toLowerCase();
    return setType == 'album' || setType == 'ep' || setType == 'single' || setType == 'compilation';
  }

  List<WaveMusicArtist> _artistsFromTracks(List<WaveMusicTrack> tracks) {
    final seen = <String>{};
    final out = <WaveMusicArtist>[];
    for (final track in tracks) {
      if (track.artistId.isEmpty || !seen.add(track.artistId)) continue;
      final existing = _artists[track.artistId];
      out.add(
        existing ??
            WaveMusicArtist(
              id: track.artistId,
              name: track.artist,
              artworkUrl: track.artworkUrl,
              provider: provider,
              providerId: _bareId(track.artistId) ?? '',
            ),
      );
    }
    return out;
  }

  String _upgradeArtwork(String url, {String fallback = ''}) {
    var value = url.trim();
    if (value.isEmpty) value = fallback.trim();
    if (value.isEmpty) return '';
    return value
        .replaceAll('-large.', '-t500x500.')
        .replaceAll('-badge.', '-t500x500.')
        .replaceAll('-small.', '-t500x500.')
        .replaceAll('-tiny.', '-t500x500.')
        .replaceAll('-mini.', '-t500x500.');
  }

  int _yearFrom(String raw) {
    if (raw.length >= 4) return int.tryParse(raw.substring(0, 4)) ?? 0;
    return 0;
  }

  String? _bareId(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return null;
    final stripped = trimmed
        .replaceFirst('sc_user_', '')
        .replaceFirst('sc_pl_', '')
        .replaceFirst('sc_', '')
        .replaceFirst('soundcloud:tracks:', '')
        .replaceFirst('soundcloud:users:', '')
        .replaceFirst('soundcloud:playlists:', '');
    return stripped.isEmpty ? null : stripped;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }
}
