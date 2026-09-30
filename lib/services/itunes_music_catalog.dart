import '../models/wave_music_album.dart';
import '../models/wave_music_artist.dart';
import '../models/wave_music_playlist.dart';
import '../models/wave_music_track.dart';
import 'wave_music_cache.dart';
import 'wave_music_catalog.dart';
import 'wave_music_http.dart';

/// Apple iTunes Search API + Apple Music RSS charts.
/// Public, documented, no API key.
/// Playback uses official `previewUrl` AAC clips only — full tracks are not
/// available from this public API (Apple Music DRM would be required).
class ITunesMusicCatalog implements WaveMusicCatalogService {
  ITunesMusicCatalog({WaveMusicHttp? http, WaveMusicCache? cache})
      : _http = http ?? WaveMusicHttp(),
        _cache = cache ?? WaveMusicCache.instance;

  static const provider = 'itunes';
  static const _searchHost = 'itunes.apple.com';
  static const _chartsHost = 'rss.applemarketingtools.com';

  final WaveMusicHttp _http;
  final WaveMusicCache _cache;
  final Map<String, WaveMusicTrack> _tracks = {};
  final Map<String, WaveMusicAlbum> _albums = {};
  final Map<String, WaveMusicArtist> _artists = {};
  final Map<String, WaveMusicPlaylist> _playlists = {};

  static const _genrePlaylists = <(String, String, String)>[
    ('top', 'Top Songs', ''),
    ('14', 'Pop Hits', '14'),
    ('18', 'Hip-Hop Hits', '18'),
    ('15', 'R&B Hits', '15'),
    ('21', 'Rock Hits', '21'),
    ('6', 'Country Hits', '6'),
  ];

  @override
  Future<WaveMusicHomeData> getHome() async {
    const key = 'home';
    final cached = _cache.get<WaveMusicHomeData>(key);
    if (cached != null) return cached;

    final trending = await getTrending(limit: 30);
    final albums = await getAlbums(limit: 20);
    final artists = _artistsFromTracks(trending).take(16).toList();
    final playlists = await getPlaylists();
    final newest = [...albums]..sort((a, b) => b.year.compareTo(a.year));
    final recommended = trending.length > 8 ? trending.sublist(8) : trending;
    final home = WaveMusicHomeData(
      trending: trending,
      popularSongs: trending.take(12).toList(),
      quickPicks: trending.take(8).toList(),
      popularArtists: artists,
      albums: albums,
      newReleases: newest.take(12).toList(),
      playlists: playlists,
      recommended: recommended.take(12).toList(),
    );
    _cache.set(key, home, ttl: const Duration(minutes: 25));
    return home;
  }

  @override
  Future<List<WaveMusicTrack>> getTrending({int limit = 40}) async {
    const key = 'trending';
    final cached = _cache.get<List<WaveMusicTrack>>(key);
    if (cached != null) return cached.take(limit).toList();

    final ids = await _chartSongIds();
    final tracks = await tracksForIds(ids.take(limit).toList());
    _cache.set(key, tracks, ttl: const Duration(minutes: 25));
    return tracks;
  }

  @override
  Future<List<WaveMusicTrack>> getRecommendations({String? seedArtist}) async {
    if (seedArtist != null && seedArtist.trim().isNotEmpty) {
      final result = await search(seedArtist, limit: 20);
      if (result.tracks.isNotEmpty) return result.tracks;
    }
    return getTrending(limit: 20);
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
    if (numeric == null) return const WaveMusicArtistDetails(artist: WaveMusicArtist(id: '', name: '', artworkUrl: ''));
    final cacheKey = 'artist:$numeric';
    final cached = _cache.get<WaveMusicArtistDetails>(cacheKey);
    if (cached != null) return cached;

    final songsJson = await _lookup(numeric, entity: 'song', limit: 25);
    final albumsJson = await _lookup(numeric, entity: 'album', limit: 30);
    final songRows = _results(songsJson);
    final albumRows = _results(albumsJson);

    WaveMusicArtist artist = _artists[_artistId(numeric)] ??
        WaveMusicArtist(
          id: _artistId(numeric),
          name: '',
          artworkUrl: '',
          provider: provider,
          providerId: numeric,
        );
    Map<String, dynamic>? artistRow;
    for (final row in songRows) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      if (map['wrapperType'] == 'artist') {
        artistRow = map;
        break;
      }
    }
    artistRow ??= () {
      for (final row in songRows) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        if ((map['artistName']?.toString() ?? '').isNotEmpty) return map;
      }
      return null;
    }();
    if (artistRow != null) {
      artist = _mapArtist(artistRow, fallbackId: numeric);
    }

    final popular = <WaveMusicTrack>[];
    for (final row in songRows) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      if (map['wrapperType'] != 'track' && map['kind'] != 'song') continue;
      popular.add(_rememberTrack(_mapSong(map)));
    }

    final albums = <WaveMusicAlbum>[];
    final singles = <WaveMusicAlbum>[];
    for (final row in albumRows) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      if (map['wrapperType'] != 'collection' && map['collectionType'] == null) continue;
      if (map['collectionId'] == null) continue;
      final album = _rememberAlbum(_mapAlbum(map));
      if (album.isSingle) {
        singles.add(album);
      } else {
        albums.add(album);
      }
    }

    if (artist.artworkUrl.isEmpty) {
      final art = popular.isNotEmpty
          ? popular.first.artworkUrl
          : (albums.isNotEmpty ? albums.first.artworkUrl : '');
      artist = WaveMusicArtist(
        id: artist.id,
        name: artist.name,
        artworkUrl: art,
        bio: artist.bio,
        albumIds: albums.map((a) => a.id).toList(),
        popularTrackIds: popular.map((t) => t.id).toList(),
        genre: artist.genre,
        provider: provider,
        providerId: numeric,
      );
    } else {
      artist = WaveMusicArtist(
        id: artist.id,
        name: artist.name,
        artworkUrl: artist.artworkUrl,
        bio: artist.bio,
        albumIds: albums.map((a) => a.id).toList(),
        popularTrackIds: popular.map((t) => t.id).toList(),
        genre: artist.genre.isNotEmpty ? artist.genre : (popular.isNotEmpty ? popular.first.genre : ''),
        provider: provider,
        providerId: numeric,
      );
    }
    _artists[artist.id] = artist;

    final related = await _relatedArtists(artist);
    final playlist = popular.isEmpty
        ? null
        : _rememberPlaylist(
            WaveMusicPlaylist(
              id: 'itunes:playlist:artist:$numeric',
              title: '${artist.name} Top Songs',
              description: 'Popular tracks from the iTunes catalog.',
              artworkUrl: artist.artworkUrl,
              trackIds: popular.map((t) => t.id).toList(),
              provider: provider,
              providerId: numeric,
            ),
          );

    final details = WaveMusicArtistDetails(
      artist: artist,
      popular: popular,
      albums: albums,
      singles: singles,
      related: related,
      playlists: playlist == null ? const [] : [playlist],
    );
    _cache.set(cacheKey, details, ttl: const Duration(minutes: 45));
    return details;
  }

  @override
  Future<List<WaveMusicAlbum>> getAlbums({int limit = 30}) async {
    const key = 'albums';
    final cached = _cache.get<List<WaveMusicAlbum>>(key);
    if (cached != null) return cached.take(limit).toList();

    final json = await _http.getJson(
      Uri.https(_chartsHost, '/api/v2/us/music/most-played/25/albums.json'),
    );
    final results = (json['feed'] is Map) ? (json['feed']['results'] as List?) ?? const [] : const [];
    final ids = <String>[];
    for (final row in results) {
      if (row is! Map) continue;
      final id = row['id']?.toString();
      if (id != null) ids.add(_albumId(id));
    }
    final albums = <WaveMusicAlbum>[];
    for (final id in ids.take(limit)) {
      final album = await getAlbum(id);
      if (album != null) albums.add(album);
    }
    _cache.set(key, albums, ttl: const Duration(minutes: 25));
    return albums;
  }

  @override
  Future<WaveMusicAlbum?> getAlbum(String id) async {
    if (_albums[id] != null && _albums[id]!.trackIds.isNotEmpty) return _albums[id];
    final numeric = _numeric(id);
    if (numeric == null) return _albums[id];
    final json = await _lookup(numeric, entity: 'song', limit: 80);
    final rows = _results(json);
    WaveMusicAlbum? album;
    final tracks = <WaveMusicTrack>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      if (map['wrapperType'] == 'collection' ||
          (map['collectionType'] != null && map['kind'] != 'song')) {
        album = _rememberAlbum(_mapAlbum(map));
      } else if (map['kind'] == 'song' || map['wrapperType'] == 'track') {
        tracks.add(_rememberTrack(_mapSong(map)));
      }
    }
    if (album == null && tracks.isNotEmpty) {
      final t = tracks.first;
      album = _rememberAlbum(
        WaveMusicAlbum(
          id: t.albumId,
          title: t.album,
          artist: t.artist,
          artistId: t.artistId,
          artworkUrl: t.artworkUrl,
          year: t.year,
          trackIds: tracks.map((e) => e.id).toList(),
          trackCount: tracks.length,
          provider: provider,
          providerId: numeric,
        ),
      );
    } else if (album != null && tracks.isNotEmpty) {
      album = _rememberAlbum(
        WaveMusicAlbum(
          id: album.id,
          title: album.title,
          artist: album.artist,
          artistId: album.artistId,
          artworkUrl: album.artworkUrl,
          year: album.year,
          trackIds: tracks.map((e) => e.id).toList(),
          trackCount: tracks.length,
          isSingle: album.isSingle,
          provider: provider,
          providerId: album.providerId,
        ),
      );
    }
    return album;
  }

  @override
  Future<List<WaveMusicPlaylist>> getPlaylists() async {
    const key = 'playlists';
    final cached = _cache.get<List<WaveMusicPlaylist>>(key);
    if (cached != null) return cached;

    final out = <WaveMusicPlaylist>[];
    for (final item in _genrePlaylists) {
      try {
        final tracks = item.$3.isEmpty
            ? await getTrending(limit: 20)
            : await _genreChart(item.$3);
        if (tracks.isEmpty) continue;
        out.add(
          _rememberPlaylist(
            WaveMusicPlaylist(
              id: 'itunes:playlist:${item.$1}',
              title: item.$2,
              description: 'Apple iTunes chart',
              artworkUrl: tracks.first.artworkUrl,
              trackIds: tracks.map((t) => t.id).toList(),
              provider: provider,
              providerId: item.$1,
            ),
          ),
        );
      } catch (_) {}
    }
    _cache.set(key, out, ttl: const Duration(minutes: 25));
    return out;
  }

  @override
  Future<WaveMusicPlaylist?> getPlaylist(String id) async {
    if (_playlists[id] != null) return _playlists[id];
    final all = await getPlaylists();
    for (final p in all) {
      if (p.id == id) return p;
    }
    return _playlists[id];
  }

  @override
  Future<WaveMusicTrack?> getTrack(String id) async {
    if (_tracks[id] != null) return _tracks[id];
    final numeric = _numeric(id);
    if (numeric == null) return null;
    final found = await tracksForIds([_trackId(numeric)]);
    return found.isEmpty ? null : found.first;
  }

  @override
  Future<List<WaveMusicTrack>> tracksForIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final out = <WaveMusicTrack>[];
    final missing = <String>[];
    for (final id in ids) {
      final cached = _tracks[id];
      if (cached != null) {
        out.add(cached);
      } else {
        final n = _numeric(id);
        if (n != null) missing.add(n);
      }
    }
    for (var i = 0; i < missing.length; i += 20) {
      final chunk = missing.skip(i).take(20).join(',');
      final json = await _lookup(chunk, entity: 'song', limit: 20);
      for (final row in _results(json)) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        if (map['kind'] != 'song' && map['wrapperType'] != 'track') continue;
        out.add(_rememberTrack(_mapSong(map)));
      }
    }
    final byId = {for (final t in out) t.id: t};
    return ids.map((id) => byId[id] ?? _tracks[id]).whereType<WaveMusicTrack>().toList();
  }

  @override
  Future<List<WaveMusicTrack>> getRelatedTracks(WaveMusicTrack track) async {
    final query = track.artist.isNotEmpty ? track.artist : track.title;
    final result = await search(query, limit: 20);
    return result.tracks.where((t) => t.id != track.id).take(12).toList();
  }

  @override
  Future<WaveMusicSearchResult> search(String query, {int offset = 0, int limit = 25}) async {
    final q = query.trim();
    if (q.isEmpty) return const WaveMusicSearchResult();
    final key = 'search:${q.toLowerCase()}:$offset';
    final cached = _cache.get<WaveMusicSearchResult>(key);
    if (cached != null) return cached;

    final songF = _search(q, entity: 'song', offset: offset, limit: limit);
    final albumF = _search(q, entity: 'album', offset: offset, limit: 15);
    final artistF = _search(q, entity: 'musicArtist', offset: offset, limit: 10);
    final rows = await Future.wait([songF, albumF, artistF]);

    final tracks = <WaveMusicTrack>[];
    for (final row in _results(rows[0])) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      if (map['kind'] != 'song') continue;
      tracks.add(_rememberTrack(_mapSong(map)));
    }
    final albums = <WaveMusicAlbum>[];
    for (final row in _results(rows[1])) {
      if (row is! Map) continue;
      albums.add(_rememberAlbum(_mapAlbum(Map<String, dynamic>.from(row))));
    }
    final artists = <WaveMusicArtist>[];
    for (final row in _results(rows[2])) {
      if (row is! Map) continue;
      artists.add(_rememberArtist(_mapArtist(Map<String, dynamic>.from(row))));
    }

    final playlists = <WaveMusicPlaylist>[];
    if (offset == 0 && artists.isNotEmpty) {
      playlists.add(
        WaveMusicPlaylist(
          id: 'itunes:playlist:search:${artists.first.providerId}',
          title: '${artists.first.name} Top Songs',
          description: 'From iTunes search',
          artworkUrl: artists.first.artworkUrl.isNotEmpty ? artists.first.artworkUrl : (tracks.isNotEmpty ? tracks.first.artworkUrl : ''),
          trackIds: tracks.take(15).map((t) => t.id).toList(),
          provider: provider,
          providerId: artists.first.providerId,
        ),
      );
    }
    final charts = await getPlaylists();
    playlists.addAll(
      charts.where((p) => p.title.toLowerCase().contains(q.toLowerCase()) || q.toLowerCase().contains(p.title.toLowerCase().split(' ').first.toLowerCase())),
    );

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

  Future<List<String>> _chartSongIds() async {
    try {
      final json = await _http.getJson(
        Uri.https(_chartsHost, '/api/v2/us/music/most-played/40/songs.json'),
      );
      final results = (json['feed'] is Map) ? (json['feed']['results'] as List?) ?? const [] : const [];
      final ids = <String>[];
      for (final row in results) {
        if (row is! Map) continue;
        final id = row['id']?.toString();
        if (id != null && id.isNotEmpty) ids.add(_trackId(id));
      }
      if (ids.isNotEmpty) return ids;
    } catch (_) {}
    return _legacyChartIds();
  }

  Future<List<String>> _legacyChartIds({String genre = ''}) async {
    final path = genre.isEmpty
        ? '/us/rss/topsongs/limit=25/json'
        : '/us/rss/topsongs/limit=20/genre=$genre/json';
    final json = await _http.getJson(Uri.https(_searchHost, path));
    final entries = (json['feed'] is Map) ? (json['feed']['entry'] as List?) ?? const [] : const [];
    final ids = <String>[];
    for (final row in entries) {
      if (row is! Map) continue;
      final idNode = row['id'];
      String? id;
      if (idNode is Map) {
        id = (idNode['attributes'] is Map) ? idNode['attributes']['im:id']?.toString() : null;
      }
      if (id != null) ids.add(_trackId(id));
    }
    return ids;
  }

  Future<List<WaveMusicTrack>> _genreChart(String genreId) async {
    final ids = await _legacyChartIds(genre: genreId);
    return tracksForIds(ids);
  }

  Future<List<WaveMusicArtist>> _relatedArtists(WaveMusicArtist artist) async {
    final term = artist.genre.isNotEmpty ? artist.genre : artist.name;
    if (term.isEmpty) return const [];
    final json = await _search(term, entity: 'musicArtist', limit: 8);
    final out = <WaveMusicArtist>[];
    for (final row in _results(json)) {
      if (row is! Map) continue;
      final related = _rememberArtist(_mapArtist(Map<String, dynamic>.from(row)));
      if (related.id == artist.id) continue;
      out.add(related);
    }
    return out.take(8).toList();
  }

  Future<Map<String, dynamic>> _search(String term, {required String entity, int offset = 0, int limit = 25}) {
    return _http.getJson(
      Uri.https(_searchHost, '/search', {
        'term': term,
        'media': 'music',
        'entity': entity,
        'limit': '$limit',
        'offset': '$offset',
        'country': 'us',
      }),
    );
  }

  Future<Map<String, dynamic>> _lookup(String id, {String? entity, int limit = 20}) {
    return _http.getJson(
      Uri.https(_searchHost, '/lookup', {
        'id': id,
        'entity': ?entity,
        'limit': '$limit',
        'country': 'us',
      }),
    );
  }

  List<dynamic> _results(Map<String, dynamic> json) {
    final results = json['results'];
    return results is List ? results : const [];
  }

  WaveMusicTrack _mapSong(Map<String, dynamic> row) {
    final trackId = row['trackId']?.toString() ?? '';
    final artistId = row['artistId']?.toString() ?? '';
    final albumId = row['collectionId']?.toString() ?? '';
    final release = row['releaseDate']?.toString() ?? '';
    return WaveMusicTrack(
      id: _trackId(trackId),
      title: row['trackName']?.toString() ?? '',
      artist: row['artistName']?.toString() ?? '',
      artistId: _artistId(artistId),
      album: row['collectionName']?.toString() ?? '',
      albumId: _albumId(albumId),
      artworkUrl: _art(row['artworkUrl100']?.toString() ?? ''),
      audioUrl: row['previewUrl']?.toString() ?? '',
      durationMs: (row['trackTimeMillis'] as num?)?.toInt() ?? 0,
      explicit: row['trackExplicitness'] == 'explicit',
      trackNumber: (row['trackNumber'] as num?)?.toInt() ?? 0,
      year: int.tryParse(release.length >= 4 ? release.substring(0, 4) : '') ?? 0,
      provider: provider,
      providerId: trackId,
      isPreview: true,
      genre: row['primaryGenreName']?.toString() ?? '',
    );
  }

  WaveMusicAlbum _mapAlbum(Map<String, dynamic> row) {
    final albumId = row['collectionId']?.toString() ?? row['trackId']?.toString() ?? '';
    final artistId = row['artistId']?.toString() ?? '';
    final release = row['releaseDate']?.toString() ?? '';
    final count = (row['trackCount'] as num?)?.toInt() ?? 0;
    final type = row['collectionType']?.toString() ?? '';
    final name = row['collectionName']?.toString() ?? row['trackName']?.toString() ?? '';
    final single = type.toLowerCase() == 'single' || name.toLowerCase().contains(' - single') || (count > 0 && count <= 3);
    return WaveMusicAlbum(
      id: _albumId(albumId),
      title: name,
      artist: row['artistName']?.toString() ?? '',
      artistId: _artistId(artistId),
      artworkUrl: _art(row['artworkUrl100']?.toString() ?? ''),
      year: int.tryParse(release.length >= 4 ? release.substring(0, 4) : '') ?? 0,
      trackCount: count,
      isSingle: single,
      provider: provider,
      providerId: albumId,
    );
  }

  WaveMusicArtist _mapArtist(Map<String, dynamic> row, {String? fallbackId}) {
    final artistId = row['artistId']?.toString() ?? fallbackId ?? '';
    return WaveMusicArtist(
      id: _artistId(artistId),
      name: row['artistName']?.toString() ?? '',
      artworkUrl: _art(row['artworkUrl100']?.toString() ?? ''),
      genre: row['primaryGenreName']?.toString() ?? '',
      provider: provider,
      providerId: artistId,
    );
  }

  List<WaveMusicArtist> _artistsFromTracks(List<WaveMusicTrack> tracks) {
    final seen = <String>{};
    final out = <WaveMusicArtist>[];
    for (final t in tracks) {
      if (t.artistId.isEmpty || seen.contains(t.artistId)) continue;
      seen.add(t.artistId);
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
    _playlists[playlist.id] = playlist;
    return playlist;
  }

  String _art(String url) {
    if (url.isEmpty) return url;
    return url.replaceAll('100x100bb', '600x600bb').replaceAll('/100x100', '/600x600');
  }

  String _trackId(String n) => 'itunes:track:$n';
  String _albumId(String n) => 'itunes:album:$n';
  String _artistId(String n) => 'itunes:artist:$n';

  String? _numeric(String id) {
    if (id.isEmpty) return null;
    if (RegExp(r'^\d+$').hasMatch(id)) return id;
    final parts = id.split(':');
    return parts.isNotEmpty && RegExp(r'^\d+$').hasMatch(parts.last) ? parts.last : null;
  }
}
