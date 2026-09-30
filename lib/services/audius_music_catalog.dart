import 'dart:async';

import '../config/wave_music_config.dart';
import '../models/wave_music_album.dart';
import '../models/wave_music_artist.dart';
import '../models/wave_music_playlist.dart';
import '../models/wave_music_track.dart';
import 'wave_music_cache.dart';
import 'wave_music_catalog.dart';
import 'wave_music_http.dart';

/// Official Audius REST catalog. Full-length streams for streamable tracks.
class AudiusMusicCatalog implements WaveMusicCatalogService {
  AudiusMusicCatalog({WaveMusicHttp? http, WaveMusicCache? cache})
      : _http = http ?? WaveMusicHttp(minGap: const Duration(milliseconds: 120)),
        _cache = cache ?? WaveMusicCache.instance;

  static const provider = 'audius';

  final WaveMusicHttp _http;
  final WaveMusicCache _cache;
  final Map<String, WaveMusicTrack> _tracks = {};
  final Map<String, WaveMusicAlbum> _albums = {};
  final Map<String, WaveMusicArtist> _artists = {};
  final Map<String, WaveMusicPlaylist> _playlists = {};
  String _host = WaveMusicConfig.audiusDiscoveryUrl;
  Future<void>? _hostJob;

  static const _kurdishHints = [
    'kurdish',
    'kurd',
    'sorani',
    'kurmanji',
    'کورد',
    'kurdistan',
  ];
  static const _arabicHints = [
    'arabic',
    'arab',
    'عربي',
    'عربی',
    'oud',
    'orient',
  ];

  Future<void> _ensureHost() {
    return _hostJob ??= _discoverHost();
  }

  Future<void> _discoverHost() async {
    try {
      final json = await _http.getJson(Uri.parse(WaveMusicConfig.audiusDiscoveryUrl));
      final data = json['data'];
      if (data is List) {
        for (final item in data) {
          final host = item.toString().trim().replaceAll(RegExp(r'/$'), '');
          if (host.startsWith('http')) {
            _host = host;
            break;
          }
        }
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) async {
    if (_host.isEmpty) await _ensureHost();
    final params = <String, String>{
      'app_name': WaveMusicConfig.audiusAppName,
      if (WaveMusicConfig.audiusApiKey.trim().isNotEmpty) 'api_key': WaveMusicConfig.audiusApiKey.trim(),
      ...?query,
    };
    final uri = Uri.parse('$_host$path').replace(queryParameters: params);
    return _http.getJson(uri);
  }

  List<dynamic> _data(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is List) return data;
    if (data is Map) return [data];
    return const [];
  }

  @override
  Future<WaveMusicHomeData> getHome() async {
    const key = 'audius_home';
    final cached = _cache.get<WaveMusicHomeData>(key);
    if (cached != null) return cached;

    final disk = await _cache.readDisk(key);
    if (disk != null) {
      final fromDisk = _homeFromJson(disk);
      if (fromDisk.trending.isNotEmpty) {
        _cache.set(key, fromDisk, ttl: const Duration(minutes: 25));
        unawaited(_refreshHome(key));
        return fromDisk;
      }
    }

    final home = await _loadHome();
    _cache.set(key, home, ttl: const Duration(minutes: 25));
    unawaited(_cache.writeDisk(key, _homeToJson(home), ttl: const Duration(minutes: 25)));
    unawaited(_warmDiscoveryPlaylists());
    return home;
  }

  Future<void> _refreshHome(String key) async {
    try {
      final home = await _loadHome();
      _cache.set(key, home, ttl: const Duration(minutes: 25));
      await _cache.writeDisk(key, _homeToJson(home), ttl: const Duration(minutes: 25));
    } catch (_) {}
  }

  Future<WaveMusicHomeData> _loadHome() async {
    await _ensureHost();
    final week = await _trending(time: 'week', limit: 16);
    late final List<WaveMusicTrack> month;
    late final List<WaveMusicPlaylist> playlists;
    late final List<WaveMusicAlbum> albums;
    await Future.wait([
      _trending(time: 'month', limit: 12).then((value) => month = value),
      _trendingPlaylists(limit: 8).then((value) => playlists = value),
      getAlbums(limit: 8).then((value) => albums = value),
    ]);
    final artists = _artistsFromTracks([...week, ...month]).take(12).toList();
    final recommended = month.where((t) => week.every((w) => w.id != t.id)).take(12).toList();
    return WaveMusicHomeData(
      trending: week,
      popularSongs: month.isNotEmpty ? month : week,
      quickPicks: week.take(8).toList(),
      popularArtists: artists,
      albums: albums,
      newReleases: albums.take(12).toList(),
      playlists: playlists,
      recommended: recommended.isNotEmpty ? recommended : week.skip(8).take(12).toList(),
    );
  }

  @override
  Future<List<WaveMusicTrack>> getTrending({int limit = 40}) async {
    const key = 'audius_trending';
    final cached = _cache.get<List<WaveMusicTrack>>(key);
    if (cached != null) return cached.take(limit).toList();
    await _ensureHost();
    final tracks = await _trending(limit: limit);
    _cache.set(key, tracks, ttl: const Duration(minutes: 20));
    return tracks.take(limit).toList();
  }

  @override
  Future<List<WaveMusicTrack>> getRecommendations({String? seedArtist}) async {
    if (seedArtist != null && seedArtist.trim().isNotEmpty) {
      final result = await search(seedArtist, limit: 20);
      if (result.tracks.isNotEmpty) return result.tracks;
    }
    return _trending(time: 'month', limit: 20);
  }

  @override
  Future<List<WaveMusicTrack>> getSongs({int offset = 0, int limit = 40}) async {
    final all = await getTrending(limit: 50);
    if (offset >= all.length) return const [];
    return all.skip(offset).take(limit).toList();
  }

  @override
  Future<List<WaveMusicArtist>> getArtists({int limit = 30}) async {
    final songs = await getTrending(limit: 40);
    return _artistsFromTracks(songs).take(limit).toList();
  }

  @override
  Future<WaveMusicArtist?> getArtist(String id) async {
    final details = await getArtistDetails(id);
    return details.artist.name.isEmpty ? null : details.artist;
  }

  @override
  Future<WaveMusicArtistDetails> getArtistDetails(String id) async {
    final numeric = _numeric(id);
    if (numeric == null) {
      return const WaveMusicArtistDetails(artist: WaveMusicArtist(id: '', name: '', artworkUrl: ''));
    }
    final cacheKey = 'audius_artist:$numeric';
    final cached = _cache.get<WaveMusicArtistDetails>(cacheKey);
    if (cached != null) return cached;
    await _ensureHost();

    final userJson = await _get('/v1/users/$numeric');
    final userRow = _firstMap(_data(userJson));
    var artist = userRow == null ? WaveMusicArtist(id: _userId(numeric), name: '', artworkUrl: '') : _mapArtist(userRow);

    final tracksJson = await _get('/v1/users/$numeric/tracks', {'limit': '25'});
    final popular = <WaveMusicTrack>[];
    for (final row in _data(tracksJson)) {
      if (row is! Map) continue;
      final track = _mapTrack(Map<String, dynamic>.from(row));
      if (track.title.isEmpty) continue;
      popular.add(_rememberTrack(track));
    }
    if (artist.artworkUrl.isEmpty && popular.isNotEmpty) {
      artist = WaveMusicArtist(
        id: artist.id,
        name: artist.name,
        artworkUrl: popular.first.artworkUrl,
        bio: artist.bio,
        popularTrackIds: popular.map((t) => t.id).toList(),
        genre: artist.genre.isNotEmpty ? artist.genre : (popular.isNotEmpty ? popular.first.genre : ''),
        provider: provider,
        providerId: numeric,
      );
    } else {
      artist = WaveMusicArtist(
        id: artist.id,
        name: artist.name,
        artworkUrl: artist.artworkUrl,
        bio: artist.bio,
        popularTrackIds: popular.map((t) => t.id).toList(),
        genre: artist.genre,
        provider: provider,
        providerId: numeric,
      );
    }
    _artists[artist.id] = artist;

    final related = await _relatedArtists(artist, popular);
    final playlist = popular.isEmpty
        ? null
        : _rememberPlaylist(
            WaveMusicPlaylist(
              id: 'audius:playlist:user:$numeric',
              title: '${artist.name} tracks',
              description: 'Tracks from this Audius artist',
              artworkUrl: artist.artworkUrl,
              trackIds: popular.map((t) => t.id).toList(),
              provider: provider,
              providerId: numeric,
            ),
          );

    final details = WaveMusicArtistDetails(
      artist: artist,
      popular: popular,
      albums: const [],
      singles: const [],
      related: related,
      playlists: playlist == null ? const [] : [playlist],
    );
    _cache.set(cacheKey, details, ttl: const Duration(minutes: 40));
    return details;
  }

  @override
  Future<List<WaveMusicAlbum>> getAlbums({int limit = 30}) async {
    const key = 'audius_albums';
    final cached = _cache.get<List<WaveMusicAlbum>>(key);
    if (cached != null) return cached.take(limit).toList();
    await _ensureHost();
    final json = await _get('/v1/playlists/search', {'query': 'album', 'limit': '$limit'});
    final albums = <WaveMusicAlbum>[];
    for (final row in _data(json)) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      if (map['is_album'] != true) continue;
      albums.add(_rememberAlbum(_mapAlbum(map)));
    }
    _cache.set(key, albums, ttl: const Duration(minutes: 25));
    return albums.take(limit).toList();
  }

  @override
  Future<WaveMusicAlbum?> getAlbum(String id) async {
    if (_albums[id]?.trackIds.isNotEmpty == true) return _albums[id];
    final numeric = _numeric(id);
    if (numeric == null) return _albums[id];
    await _ensureHost();
    final json = await _get('/v1/playlists/$numeric');
    final row = _firstMap(_data(json));
    if (row == null) return _albums[id];
    final album = _rememberAlbum(_mapAlbum(row));
    final tracks = _playlistTracks(row);
    if (tracks.isEmpty) return album;
    return _rememberAlbum(
      WaveMusicAlbum(
        id: album.id,
        title: album.title,
        artist: album.artist,
        artistId: album.artistId,
        artworkUrl: album.artworkUrl,
        year: album.year,
        trackIds: tracks.map((t) => t.id).toList(),
        trackCount: tracks.length,
        isSingle: album.isSingle,
        provider: provider,
        providerId: album.providerId,
      ),
    );
  }

  @override
  Future<List<WaveMusicPlaylist>> getPlaylists() async {
    const key = 'audius_playlists';
    final cached = _cache.get<List<WaveMusicPlaylist>>(key);
    if (cached != null) return cached;
    await _ensureHost();
    final out = [...await _trendingPlaylists(limit: 12)];
    final discovery = await _discoveryPlaylists();
    out.addAll(discovery);
    _cache.set(key, out, ttl: const Duration(minutes: 25));
    return out;
  }

  Future<List<WaveMusicPlaylist>> _trendingPlaylists({int limit = 8}) async {
    const key = 'audius_playlists_core';
    final cached = _cache.get<List<WaveMusicPlaylist>>(key);
    if (cached != null) return cached.take(limit).toList();
    await _ensureHost();
    final json = await _get('/v1/playlists/trending', {'limit': '$limit'});
    final out = <WaveMusicPlaylist>[];
    for (final row in _data(json)) {
      if (row is! Map) continue;
      out.add(_rememberPlaylist(_mapPlaylist(Map<String, dynamic>.from(row))));
    }
    _cache.set(key, out, ttl: const Duration(minutes: 20));
    return out;
  }

  Future<void> _warmDiscoveryPlaylists() async {
    try {
      await _discoveryPlaylists();
    } catch (_) {}
  }

  Future<List<WaveMusicPlaylist>> _discoveryPlaylists() async {
    const key = 'audius_playlists_discovery';
    final cached = _cache.get<List<WaveMusicPlaylist>>(key);
    if (cached != null) return cached;
    final out = <WaveMusicPlaylist>[];
    final specs = const [
      ('Electronic', 'Electronic'),
      ('Hip-Hop', 'Hip-Hop/Rap'),
      ('Pop', 'Pop'),
      ('Rock', 'Rock'),
      ('R&B', 'R&B/Soul'),
      ('Lo-Fi', 'Lo-Fi'),
      ('House', 'House'),
      ('Techno', 'Techno'),
      ('Ambient', 'Ambient'),
    ];
    final results = await Future.wait([
      ...specs.map((spec) async {
        final tracks = await _genreTracks(spec.$2, spec.$1);
        if (tracks.isEmpty) return null;
        return _rememberPlaylist(
          WaveMusicPlaylist(
            id: 'audius:playlist:genre:${spec.$1.toLowerCase()}',
            title: spec.$1,
            description: 'Audius ${spec.$1} discovery',
            artworkUrl: tracks.first.artworkUrl,
            trackIds: tracks.map((t) => t.id).toList(),
            provider: provider,
            providerId: spec.$1,
          ),
        );
      }),
      _localePlaylist('Kurdish', _kurdishHints, 'audius:playlist:locale:kurdish', 'kurdish'),
      _localePlaylist('Arabic', _arabicHints, 'audius:playlist:locale:arabic', 'arabic'),
    ]);
    for (final playlist in results) {
      if (playlist != null) out.add(playlist);
    }
    _cache.set(key, out, ttl: const Duration(minutes: 25));
    return out;
  }

  Future<WaveMusicPlaylist?> _localePlaylist(
    String query,
    List<String> hints,
    String id,
    String providerId,
  ) async {
    final tracks = await _localeTracks(query, hints);
    if (tracks.isEmpty) return null;
    return _rememberPlaylist(
      WaveMusicPlaylist(
        id: id,
        title: query,
        description: 'Tracks tagged or titled as $query on Audius',
        artworkUrl: tracks.first.artworkUrl,
        trackIds: tracks.map((t) => t.id).toList(),
        provider: provider,
        providerId: providerId,
      ),
    );
  }

  @override
  Future<WaveMusicPlaylist?> getPlaylist(String id) async {
    if (_playlists[id]?.trackIds.isNotEmpty == true) {
      return _playlists[id];
    }
    final numeric = _numeric(id);
    if (numeric == null) {
      final all = await getPlaylists();
      for (final p in all) {
        if (p.id == id) return p;
      }
      return _playlists[id];
    }
    await _ensureHost();
    final json = await _get('/v1/playlists/$numeric');
    final row = _firstMap(_data(json));
    if (row == null) return _playlists[id];
    final tracks = _playlistTracks(row);
    final playlist = _mapPlaylist(row);
    return _rememberPlaylist(
      WaveMusicPlaylist(
        id: playlist.id,
        title: playlist.title,
        description: playlist.description,
        artworkUrl: playlist.artworkUrl,
        trackIds: tracks.map((t) => t.id).toList(),
        provider: provider,
        providerId: playlist.providerId,
      ),
    );
  }

  @override
  Future<WaveMusicTrack?> getTrack(String id) async {
    if (_tracks[id] != null) return _tracks[id];
    final numeric = _numeric(id);
    if (numeric == null) return null;
    await _ensureHost();
    final json = await _get('/v1/tracks/$numeric');
    final row = _firstMap(_data(json));
    if (row == null) return null;
    return _rememberTrack(_mapTrack(row));
  }

  @override
  Future<List<WaveMusicTrack>> tracksForIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final out = <WaveMusicTrack>[];
    for (final id in ids) {
      final cached = _tracks[id];
      if (cached != null) {
        out.add(cached);
        continue;
      }
      final track = await getTrack(id);
      if (track != null) out.add(track);
    }
    final byId = {for (final t in out) t.id: t};
    return ids.map((id) => byId[id]).whereType<WaveMusicTrack>().toList();
  }

  @override
  Future<List<WaveMusicTrack>> getRelatedTracks(WaveMusicTrack track) async {
    final numeric = _numeric(track.id);
    if (numeric != null) {
      try {
        await _ensureHost();
        final json = await _get('/v1/tracks/$numeric/related', {'limit': '12'});
        final related = _mapTracks(_data(json));
        if (related.isNotEmpty) return related;
      } catch (_) {}
    }
    final query = track.genre.isNotEmpty ? track.genre : track.artist;
    if (query.isEmpty) return const [];
    final result = await search(query, limit: 16);
    return result.tracks.where((t) => t.id != track.id).take(12).toList();
  }

  @override
  Future<WaveMusicSearchResult> search(String query, {int offset = 0, int limit = 25}) async {
    final q = query.trim();
    if (q.isEmpty) return const WaveMusicSearchResult();
    final key = 'audius_search:${q.toLowerCase()}:$offset';
    final cached = _cache.get<WaveMusicSearchResult>(key);
    if (cached != null) return cached;
    await _ensureHost();

    final trackF = _get('/v1/tracks/search', {'query': q, 'limit': '$limit', 'offset': '$offset'});
    final userF = offset == 0 ? _get('/v1/users/search', {'query': q, 'limit': '10'}) : Future.value(const <String, dynamic>{});
    final playlistF = offset == 0 ? _get('/v1/playlists/search', {'query': q, 'limit': '10'}) : Future.value(const <String, dynamic>{});
    final rows = await Future.wait([trackF, userF, playlistF]);

    final tracks = _mapTracks(_data(rows[0]));
    final artists = <WaveMusicArtist>[];
    for (final row in _data(rows[1])) {
      if (row is! Map) continue;
      artists.add(_rememberArtist(_mapArtist(Map<String, dynamic>.from(row))));
    }
    final playlists = <WaveMusicPlaylist>[];
    final albums = <WaveMusicAlbum>[];
    for (final row in _data(rows[2])) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      if (map['is_album'] == true) {
        albums.add(_rememberAlbum(_mapAlbum(map)));
      } else {
        playlists.add(_rememberPlaylist(_mapPlaylist(map)));
      }
    }

    final result = WaveMusicSearchResult(
      tracks: tracks,
      artists: artists,
      albums: albums,
      playlists: playlists,
      hasMore: tracks.length >= limit,
      nextOffset: offset + limit,
    );
    _cache.set(key, result, ttl: const Duration(minutes: 10));
    return result;
  }

  Future<List<WaveMusicTrack>> _trending({String? time, String? genre, int limit = 30}) async {
    await _ensureHost();
    final query = <String, String>{
      'limit': '$limit',
      if (time != null) 'time': time,
      if (genre != null && genre.isNotEmpty) 'genre': genre,
    };
    final json = await _get('/v1/tracks/trending', query);
    return _mapTracks(_data(json));
  }

  Future<List<WaveMusicTrack>> _genreTracks(String genre, String query) async {
    try {
      final trending = await _trending(genre: genre, limit: 12);
      if (trending.isNotEmpty) return trending;
    } catch (_) {}
    return const [];
  }

  Future<List<WaveMusicTrack>> _localeTracks(String query, List<String> hints) async {
    try {
      await _ensureHost();
      final json = await _get('/v1/tracks/search', {'query': query, 'limit': '20'});
      final out = <WaveMusicTrack>[];
      for (final row in _data(json)) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        if (!_rowMatchesHints(map, hints)) continue;
        final track = _mapTrack(map);
        if (track.title.isEmpty || !track.isPlayable) continue;
        out.add(_rememberTrack(track));
      }
      return out.take(16).toList();
    } catch (_) {
      return const [];
    }
  }

  bool _rowMatchesHints(Map<String, dynamic> row, List<String> hints) {
    final user = row['user'] is Map ? Map<String, dynamic>.from(row['user'] as Map) : const <String, dynamic>{};
    final hay = [
      row['title'],
      row['genre'],
      row['tags'],
      row['description'],
      row['mood'],
      user['name'],
      user['handle'],
      user['bio'],
    ].map((e) => e?.toString().toLowerCase() ?? '').join(' ');
    return hints.any((h) => hay.contains(h.toLowerCase()));
  }

  Future<List<WaveMusicArtist>> _relatedArtists(WaveMusicArtist artist, List<WaveMusicTrack> popular) async {
    final seed = artist.genre.isNotEmpty
        ? artist.genre
        : (popular.isNotEmpty ? popular.first.genre : artist.name);
    if (seed.isEmpty) return const [];
    final result = await search(seed, limit: 12);
    final seen = {artist.id};
    final out = <WaveMusicArtist>[];
    for (final related in result.artists) {
      if (!seen.add(related.id)) continue;
      out.add(related);
    }
    return out.take(8).toList();
  }

  List<WaveMusicTrack> _mapTracks(List<dynamic> rows) {
    final out = <WaveMusicTrack>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final track = _mapTrack(Map<String, dynamic>.from(row));
      if (track.title.isEmpty) continue;
      out.add(_rememberTrack(track));
    }
    return out;
  }

  List<WaveMusicTrack> _playlistTracks(Map<String, dynamic> row) {
    final tracks = row['tracks'];
    if (tracks is! List) return const [];
    return _mapTracks(tracks);
  }

  WaveMusicTrack _mapTrack(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final user = row['user'] is Map ? Map<String, dynamic>.from(row['user'] as Map) : <String, dynamic>{};
    final artwork = _artwork(row['artwork'], prefer: '1000x1000');
    final fallback = _artwork(user['profile_picture'], prefer: '480x480');
    final streamable =
        (row['is_streamable'] == true || row['streamable'] == true) && row['is_delete'] != true;
    final durationSec = (row['duration'] as num?)?.toInt() ?? 0;
    final release = row['release_date']?.toString() ?? row['created_at']?.toString() ?? '';
    return WaveMusicTrack(
      id: _trackId(id),
      title: row['title']?.toString() ?? '',
      artist: user['name']?.toString() ?? user['handle']?.toString() ?? '',
      artistId: _userId(user['id']?.toString() ?? ''),
      album: '',
      albumId: '',
      artworkUrl: artwork.isNotEmpty ? artwork : fallback,
      audioUrl: streamable && id.isNotEmpty ? _streamUrl(id) : '',
      durationMs: durationSec * 1000,
      explicit: row['is_explicit'] == true,
      provider: provider,
      providerId: id,
      isPreview: false,
      genre: row['genre']?.toString() ?? '',
      year: int.tryParse(release.length >= 4 ? release.substring(0, 4) : '') ?? 0,
    );
  }

  WaveMusicArtist _mapArtist(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final pic = _artwork(row['profile_picture'], prefer: '480x480');
    final cover = _artwork(row['cover_photo'], prefer: '480x480');
    return WaveMusicArtist(
      id: _userId(id),
      name: row['name']?.toString() ?? row['handle']?.toString() ?? '',
      artworkUrl: pic.isNotEmpty ? pic : cover,
      bio: _artistBio(row),
      genre: '',
      provider: provider,
      providerId: id,
    );
  }

  WaveMusicPlaylist _mapPlaylist(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? row['playlist_id']?.toString() ?? '';
    final user = row['user'] is Map ? Map<String, dynamic>.from(row['user'] as Map) : <String, dynamic>{};
    final artwork = _artwork(row['artwork'], prefer: '480x480');
    final tracks = _playlistTracks(row);
    return WaveMusicPlaylist(
      id: _playlistId(id),
      title: row['playlist_name']?.toString() ?? row['name']?.toString() ?? '',
      description: row['description']?.toString() ?? user['name']?.toString() ?? '',
      artworkUrl: artwork.isNotEmpty ? artwork : (tracks.isNotEmpty ? tracks.first.artworkUrl : ''),
      trackIds: tracks.map((t) => t.id).toList(),
      provider: provider,
      providerId: id,
    );
  }

  WaveMusicAlbum _mapAlbum(Map<String, dynamic> row) {
    final playlist = _mapPlaylist(row);
    final user = row['user'] is Map ? Map<String, dynamic>.from(row['user'] as Map) : <String, dynamic>{};
    final release = row['release_date']?.toString() ?? '';
    final tracks = _playlistTracks(row);
    return WaveMusicAlbum(
      id: _albumId(playlist.providerId),
      title: playlist.title,
      artist: user['name']?.toString() ?? '',
      artistId: _userId(user['id']?.toString() ?? ''),
      artworkUrl: playlist.artworkUrl,
      year: int.tryParse(release.length >= 4 ? release.substring(0, 4) : '') ?? 0,
      trackIds: tracks.map((t) => t.id).toList(),
      trackCount: tracks.length,
      isSingle: tracks.length <= 3 && tracks.isNotEmpty,
      provider: provider,
      providerId: playlist.providerId,
    );
  }

  List<WaveMusicArtist> _artistsFromTracks(List<WaveMusicTrack> tracks) {
    final seen = <String>{};
    final out = <WaveMusicArtist>[];
    for (final t in tracks) {
      if (t.artistId.isEmpty || !seen.add(t.artistId)) continue;
      out.add(
        _rememberArtist(
          WaveMusicArtist(
            id: t.artistId,
            name: t.artist,
            artworkUrl: t.artworkUrl,
            genre: t.genre,
            provider: provider,
            providerId: _numeric(t.artistId) ?? '',
            popularTrackIds: [t.id],
          ),
        ),
      );
    }
    return out;
  }

  String _artistBio(Map<String, dynamic> row) {
    final bio = row['bio']?.toString().trim() ?? '';
    final handle = row['handle']?.toString().trim() ?? '';
    final extras = <String>[];
    if (handle.isNotEmpty) extras.add('@$handle');
    final followers = row['follower_count'];
    final tracks = row['track_count'];
    if (followers is num && followers > 0) extras.add('${followers.toInt()} followers');
    if (tracks is num && tracks > 0) extras.add('${tracks.toInt()} tracks');
    final suffix = extras.join(' · ');
    if (bio.isEmpty) return suffix;
    if (suffix.isEmpty) return bio;
    return '$bio\n$suffix';
  }

  String _artwork(dynamic node, {String prefer = '1000x1000'}) {
    if (node is! Map) return '';
    final map = Map<String, dynamic>.from(node);
    for (final size in [prefer, '1000x1000', '480x480', '150x150']) {
      final value = map[size]?.toString() ?? '';
      if (value.startsWith('http')) return value;
    }
    return '';
  }

  String _streamUrl(String id) {
    final params = <String, String>{
      'app_name': WaveMusicConfig.audiusAppName,
      if (WaveMusicConfig.audiusApiKey.trim().isNotEmpty) 'api_key': WaveMusicConfig.audiusApiKey.trim(),
    };
    return Uri.parse('$_host/v1/tracks/$id/stream').replace(queryParameters: params).toString();
  }

  WaveMusicTrack _rememberTrack(WaveMusicTrack track) {
    if (track.id.isNotEmpty) _tracks[track.id] = track;
    return track;
  }

  WaveMusicAlbum _rememberAlbum(WaveMusicAlbum album) {
    if (album.id.isNotEmpty) _albums[album.id] = album;
    return album;
  }

  WaveMusicArtist _rememberArtist(WaveMusicArtist artist) {
    if (artist.id.isNotEmpty) {
      final prev = _artists[artist.id];
      if (prev != null && prev.artworkUrl.isNotEmpty && artist.artworkUrl.isEmpty) {
        return prev;
      }
      _artists[artist.id] = artist;
    }
    return artist;
  }

  WaveMusicPlaylist _rememberPlaylist(WaveMusicPlaylist playlist) {
    if (playlist.id.isNotEmpty) _playlists[playlist.id] = playlist;
    return playlist;
  }

  Map<String, dynamic>? _firstMap(List<dynamic> rows) {
    for (final row in rows) {
      if (row is Map) return Map<String, dynamic>.from(row);
    }
    return null;
  }

  String _trackId(String n) => n.isEmpty ? '' : 'audius:track:$n';
  String _userId(String n) => n.isEmpty ? '' : 'audius:user:$n';
  String _playlistId(String n) => n.isEmpty ? '' : 'audius:playlist:$n';
  String _albumId(String n) => n.isEmpty ? '' : 'audius:album:$n';

  Map<String, dynamic> _homeToJson(WaveMusicHomeData home) => {
        'trending': home.trending.map((t) => t.toJson()).toList(),
        'popularSongs': home.popularSongs.map((t) => t.toJson()).toList(),
        'quickPicks': home.quickPicks.map((t) => t.toJson()).toList(),
        'recommended': home.recommended.map((t) => t.toJson()).toList(),
        'popularArtists': home.popularArtists.map((a) => a.toJson()).toList(),
        'albums': home.albums.map((a) => a.toJson()).toList(),
        'newReleases': home.newReleases.map((a) => a.toJson()).toList(),
        'playlists': home.playlists.map((p) => p.toJson()).toList(),
      };

  WaveMusicHomeData _homeFromJson(Map<String, dynamic> json) {
    List<T> mapList<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = json[key];
      if (raw is! List) return <T>[];
      return raw
          .whereType<Map>()
          .map((row) => parse(Map<String, dynamic>.from(row)))
          .toList();
    }

    final tracks = mapList('trending', WaveMusicTrack.fromJson);
    for (final track in tracks) {
      _rememberTrack(track);
    }
    final popular = mapList('popularSongs', WaveMusicTrack.fromJson);
    for (final track in popular) {
      _rememberTrack(track);
    }
    final artists = mapList('popularArtists', WaveMusicArtist.fromJson);
    for (final artist in artists) {
      _rememberArtist(artist);
    }
    final albums = mapList('albums', WaveMusicAlbum.fromJson);
    for (final album in albums) {
      _rememberAlbum(album);
    }
    final playlists = mapList('playlists', WaveMusicPlaylist.fromJson);
    for (final playlist in playlists) {
      _rememberPlaylist(playlist);
    }
    return WaveMusicHomeData(
      trending: tracks,
      popularSongs: popular.isNotEmpty ? popular : tracks,
      quickPicks: mapList('quickPicks', WaveMusicTrack.fromJson),
      recommended: mapList('recommended', WaveMusicTrack.fromJson),
      popularArtists: artists,
      albums: albums,
      newReleases: mapList('newReleases', WaveMusicAlbum.fromJson),
      playlists: playlists,
    );
  }

  String? _numeric(String id) {
    if (id.isEmpty) return null;
    if (id.contains(':genre:') || id.contains(':locale:') || id.contains(':playlist:user:')) {
      return null;
    }
    if (!id.contains(':')) return id;
    final parts = id.split(':');
    return parts.isNotEmpty && parts.last.isNotEmpty ? parts.last : null;
  }
}
