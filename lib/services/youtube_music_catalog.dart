import '../config/wave_config.dart';
import '../config/wave_music_config.dart';
import '../models/wave_music_album.dart';
import '../models/wave_music_artist.dart';
import '../models/wave_music_playlist.dart';
import '../models/wave_music_track.dart';
import 'audius_music_catalog.dart';
import 'wave_music_cache.dart';
import 'wave_music_catalog.dart';
import 'wave_music_http.dart';

/// YouTube Data API v3 catalog (search, channels, playlists, trending music).
/// Does not extract YouTube media streams or bypass DRM/BotGuard.
/// Stream URLs come from a legitimate Audius fallback when a matching
/// streamable track exists there.
class YouTubeMusicCatalog implements WaveMusicCatalogService {
  YouTubeMusicCatalog({
    WaveMusicHttp? http,
    WaveMusicCache? cache,
    AudiusMusicCatalog? fallback,
  })  : _http = http ?? WaveMusicHttp(minGap: const Duration(milliseconds: 120)),
        _cache = cache ?? WaveMusicCache.instance,
        _fallback = fallback ?? AudiusMusicCatalog();

  static const provider = 'youtube';

  final WaveMusicHttp _http;
  final WaveMusicCache _cache;
  final AudiusMusicCatalog _fallback;
  final Map<String, WaveMusicTrack> _tracks = {};
  final Map<String, WaveMusicAlbum> _albums = {};
  final Map<String, WaveMusicArtist> _artists = {};
  final Map<String, WaveMusicPlaylist> _playlists = {};
  final Map<String, String> _pageTokens = {};
  final Map<String, String> _audioCache = {};

  Future<Map<String, dynamic>> _yt(String path, [Map<String, String>? query]) async {
    final key = await WaveConfig.resolveApiKey();
    if (key.isEmpty) {
      throw StateError('YouTube Data API key missing');
    }
    final uri = Uri.parse('${WaveConfig.youtubeDataBaseUrl}/$path').replace(
      queryParameters: {
        'key': key,
        ...?query,
      },
    );
    return _http.getJson(
      uri,
      headers: {
        'X-Android-Package': WaveConfig.androidPackageName,
        'X-Android-Cert': WaveConfig.androidSha1Cert,
      },
    );
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) return const [];
    return items.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  @override
  Future<WaveMusicHomeData> getHome() async {
    const key = 'yt_home';
    final cached = _cache.get<WaveMusicHomeData>(key);
    if (cached != null) return cached;

    final trending = await getTrending(limit: 16);
    late final List<WaveMusicPlaylist> playlists;
    late final List<WaveMusicAlbum> albums;
    await Future.wait([
      getPlaylists().then((value) => playlists = value),
      getAlbums(limit: 8).then((value) => albums = value),
    ]);
    final artists = _artistsFromTracks(trending).take(12).toList();
    final home = WaveMusicHomeData(
      trending: trending,
      popularSongs: trending.take(12).toList(),
      quickPicks: trending.take(8).toList(),
      popularArtists: artists,
      albums: albums,
      newReleases: albums.take(8).toList(),
      playlists: playlists,
      recommended: trending.skip(8).take(12).toList(),
    );
    _cache.set(key, home, ttl: const Duration(minutes: 25));
    return home;
  }

  @override
  Future<List<WaveMusicTrack>> getTrending({int limit = 40}) async {
    const key = 'yt_trending';
    final cached = _cache.get<List<WaveMusicTrack>>(key);
    if (cached != null) return cached.take(limit).toList();
    final json = await _yt('videos', {
      'part': 'snippet,contentDetails',
      'chart': 'mostPopular',
      'videoCategoryId': '10',
      'maxResults': '${limit.clamp(1, 50)}',
      'regionCode': WaveConfig.defaultRegionCode,
    });
    final tracks = _mapVideoItems(_items(json));
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
    final cacheKey = 'yt_artist:$numeric';
    final cached = _cache.get<WaveMusicArtistDetails>(cacheKey);
    if (cached != null) return cached;

    final channelJson = await _yt('channels', {
      'part': 'snippet,statistics',
      'id': numeric,
    });
    final channel = _items(channelJson).isEmpty ? null : _items(channelJson).first;
    var artist = channel == null
        ? WaveMusicArtist(id: _channelId(numeric), name: '', artworkUrl: '')
        : _mapChannel(channel);

    var videosJson = await _yt('search', {
      'part': 'snippet',
      'channelId': numeric,
      'type': 'video',
      'videoCategoryId': '10',
      'maxResults': '15',
      'order': 'date',
    });
    if (_items(videosJson).isEmpty) {
      videosJson = await _yt('search', {
        'part': 'snippet',
        'channelId': numeric,
        'type': 'video',
        'maxResults': '15',
        'order': 'date',
      });
    }
    final videoIds = <String>[];
    for (final row in _items(videosJson)) {
      final vid = _videoIdFrom(row);
      if (vid.isNotEmpty) videoIds.add(vid);
    }
    final popular = await tracksForIds(videoIds.map(_trackId).toList());
    artist = WaveMusicArtist(
      id: artist.id,
      name: artist.name,
      artworkUrl: artist.artworkUrl.isNotEmpty
          ? artist.artworkUrl
          : (popular.isNotEmpty ? popular.first.artworkUrl : ''),
      bio: artist.bio,
      popularTrackIds: popular.map((t) => t.id).toList(),
      genre: artist.genre,
      provider: provider,
      providerId: numeric,
    );
    _artists[artist.id] = artist;
    final details = WaveMusicArtistDetails(
      artist: artist,
      popular: popular,
      albums: const [],
      related: _artistsFromTracks(popular).where((a) => a.id != artist.id).take(8).toList(),
    );
    _cache.set(cacheKey, details, ttl: const Duration(minutes: 40));
    return details;
  }

  @override
  Future<List<WaveMusicAlbum>> getAlbums({int limit = 30}) async {
    const key = 'yt_albums';
    final cached = _cache.get<List<WaveMusicAlbum>>(key);
    if (cached != null) return cached.take(limit).toList();
    final json = await _yt('search', {
      'part': 'snippet',
      'type': 'playlist',
      'q': 'official full album',
      'maxResults': '${limit.clamp(1, 25)}',
    });
    final albums = <WaveMusicAlbum>[];
    for (final row in _items(json)) {
      final playlist = _mapPlaylistSearch(row);
      if (playlist == null) continue;
      if (!_looksLikeAlbum(playlist.title)) continue;
      albums.add(_rememberAlbum(_albumFromPlaylist(playlist)));
    }
    _cache.set(key, albums, ttl: const Duration(minutes: 25));
    return albums.take(limit).toList();
  }

  @override
  Future<WaveMusicAlbum?> getAlbum(String id) async {
    if (_albums[id]?.trackIds.isNotEmpty == true) return _albums[id];
    final playlist = await getPlaylist(id.replaceFirst('yt:album:', 'yt:playlist:'));
    if (playlist == null) return _albums[id];
    return _rememberAlbum(_albumFromPlaylist(playlist));
  }

  @override
  Future<List<WaveMusicPlaylist>> getPlaylists() async {
    const key = 'yt_playlists';
    final cached = _cache.get<List<WaveMusicPlaylist>>(key);
    if (cached != null) return cached;
    final json = await _yt('search', {
      'part': 'snippet',
      'type': 'playlist',
      'q': 'music playlist',
      'maxResults': '12',
    });
    final out = <WaveMusicPlaylist>[];
    for (final row in _items(json)) {
      final playlist = _mapPlaylistSearch(row);
      if (playlist != null) out.add(_rememberPlaylist(playlist));
    }
    for (final spec in const [
      ('Kurdish', 'Kurdish music'),
      ('Arabic', 'Arabic music'),
    ]) {
      final result = await search(spec.$2, limit: 12);
      if (result.tracks.isEmpty) continue;
      out.add(
        _rememberPlaylist(
          WaveMusicPlaylist(
            id: 'yt:playlist:discover:${spec.$1.toLowerCase()}',
            title: spec.$1,
            description: 'YouTube search results for ${spec.$2}',
            artworkUrl: result.tracks.first.artworkUrl,
            trackIds: result.tracks.map((t) => t.id).toList(),
            provider: provider,
            providerId: spec.$1,
          ),
        ),
      );
    }
    _cache.set(key, out, ttl: const Duration(minutes: 25));
    return out;
  }

  @override
  Future<WaveMusicPlaylist?> getPlaylist(String id) async {
    if (_playlists[id]?.trackIds.isNotEmpty == true) return _playlists[id];
    if (id.contains(':discover:')) {
      final all = await getPlaylists();
      for (final p in all) {
        if (p.id == id) return p;
      }
      return _playlists[id];
    }
    final numeric = _bareId(id);
    if (numeric == null) return _playlists[id];
    final meta = await _yt('playlists', {
      'part': 'snippet,contentDetails',
      'id': numeric,
    });
    final row = _items(meta).isEmpty ? null : _items(meta).first;
    if (row == null) return _playlists[id];
    final playlist = _mapPlaylist(row);
    final items = await _yt('playlistItems', {
      'part': 'snippet,contentDetails',
      'playlistId': numeric,
      'maxResults': '50',
    });
    final ids = <String>[];
    for (final item in _items(items)) {
      final videoId = item['contentDetails'] is Map
          ? (item['contentDetails'] as Map)['videoId']?.toString() ?? ''
          : '';
      if (videoId.isEmpty) continue;
      ids.add(_trackId(videoId));
    }
    await tracksForIds(ids);
    return _rememberPlaylist(
      WaveMusicPlaylist(
        id: playlist.id,
        title: playlist.title,
        description: playlist.description,
        artworkUrl: playlist.artworkUrl,
        trackIds: ids,
        provider: provider,
        providerId: playlist.providerId,
      ),
    );
  }

  @override
  Future<WaveMusicTrack?> getTrack(String id) async {
    if (_tracks[id] != null) return _tracks[id];
    final numeric = _bareId(id);
    if (numeric == null) return null;
    final tracks = await tracksForIds([_trackId(numeric)]);
    return tracks.isEmpty ? null : tracks.first;
  }

  @override
  Future<List<WaveMusicTrack>> tracksForIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final missing = <String>[];
    final out = <WaveMusicTrack>[];
    for (final id in ids) {
      final cached = _tracks[id];
      if (cached != null) {
        out.add(cached);
      } else {
        final bare = _bareId(id);
        if (bare != null) missing.add(bare);
      }
    }
    for (var i = 0; i < missing.length; i += 50) {
      final chunk = missing.skip(i).take(50).join(',');
      final json = await _yt('videos', {
        'part': 'snippet,contentDetails',
        'id': chunk,
      });
      out.addAll(_mapVideoItems(_items(json)));
    }
    final byId = {for (final t in out) t.id: t};
    return ids.map((id) => byId[id]).whereType<WaveMusicTrack>().toList();
  }

  @override
  Future<List<WaveMusicTrack>> getRelatedTracks(WaveMusicTrack track) async {
    final query = track.artist.isNotEmpty ? track.artist : track.title;
    if (query.isEmpty) return const [];
    final result = await search(query, limit: 16);
    return result.tracks.where((t) => t.id != track.id).take(12).toList();
  }

  @override
  Future<WaveMusicSearchResult> search(String query, {int offset = 0, int limit = 25}) async {
    final q = query.trim();
    if (q.isEmpty) return const WaveMusicSearchResult();
    final key = 'yt_search:${q.toLowerCase()}:$offset';
    final cached = _cache.get<WaveMusicSearchResult>(key);
    if (cached != null) return cached;

    final tokenKey = '${q.toLowerCase()}:$offset';
    final pageToken = offset == 0 ? null : _pageTokens[tokenKey];
    if (offset > 0 && (pageToken == null || pageToken.isEmpty)) {
      return const WaveMusicSearchResult();
    }

    final videoF = _yt('search', {
      'part': 'snippet',
      'q': q,
      'type': 'video',
      'videoCategoryId': '10',
      'maxResults': '${limit.clamp(1, 25)}',
      if (pageToken != null) 'pageToken': pageToken,
    });
    final extraF = offset == 0
        ? Future.wait([
            _yt('search', {'part': 'snippet', 'q': q, 'type': 'channel', 'maxResults': '8'}),
            _yt('search', {'part': 'snippet', 'q': q, 'type': 'playlist', 'maxResults': '8'}),
          ])
        : Future.value(const <Map<String, dynamic>>[]);

    final videoJson = await videoF;
    final extras = await extraF;
    final videoIds = <String>[];
    for (final row in _items(videoJson)) {
      final id = _videoIdFrom(row);
      if (id.isNotEmpty) videoIds.add(id);
    }
    final tracks = await tracksForIds(videoIds.map(_trackId).toList());

    final artists = <WaveMusicArtist>[];
    final playlists = <WaveMusicPlaylist>[];
    final albums = <WaveMusicAlbum>[];
    if (extras.length == 2) {
      for (final row in _items(extras[0])) {
        final artist = _mapChannelSearch(row);
        if (artist != null) artists.add(_rememberArtist(artist));
      }
      for (final row in _items(extras[1])) {
        final playlist = _mapPlaylistSearch(row);
        if (playlist == null) continue;
        if (_looksLikeAlbum(playlist.title)) {
          albums.add(_rememberAlbum(_albumFromPlaylist(playlist)));
        } else {
          playlists.add(_rememberPlaylist(playlist));
        }
      }
    }

    final nextToken = videoJson['nextPageToken']?.toString() ?? '';
    final nextOffset = offset + tracks.length;
    if (nextToken.isNotEmpty) {
      _pageTokens['${q.toLowerCase()}:$nextOffset'] = nextToken;
    }
    final result = WaveMusicSearchResult(
      tracks: tracks,
      artists: artists,
      albums: albums,
      playlists: playlists,
      hasMore: nextToken.isNotEmpty,
      nextOffset: nextOffset,
    );
    _cache.set(key, result, ttl: const Duration(minutes: 10));
    return result;
  }

  Future<WaveMusicTrack> resolveAudio(WaveMusicTrack track) async {
    if (track.isPlayable) return track;
    final cachedUrl = _audioCache[track.id];
    if (cachedUrl != null) {
      return cachedUrl.isEmpty ? track : track.copyWith(audioUrl: cachedUrl);
    }
    if (!WaveMusicConfig.audiusPlaybackFallback) {
      _audioCache[track.id] = '';
      return track;
    }
    try {
      final query = '${_cleanTitle(track.title)} ${track.artist}'.trim();
      if (query.isEmpty) {
        _audioCache[track.id] = '';
        return track;
      }
      final result = await _fallback.search(query, limit: 8);
      for (final candidate in result.tracks) {
        if (!candidate.isPlayable) continue;
        if (!_sameWork(track, candidate)) continue;
        _audioCache[track.id] = candidate.audioUrl;
        return track.copyWith(audioUrl: candidate.audioUrl);
      }
    } catch (_) {}
    _audioCache[track.id] = '';
    return track;
  }

  List<WaveMusicTrack> _mapVideoItems(List<Map<String, dynamic>> rows) {
    final out = <WaveMusicTrack>[];
    for (final row in rows) {
      final track = _mapVideo(row);
      if (track.title.isEmpty) continue;
      out.add(_rememberTrack(track));
    }
    return out;
  }

  WaveMusicTrack _mapVideo(Map<String, dynamic> row) {
    final snippet = row['snippet'] is Map ? Map<String, dynamic>.from(row['snippet'] as Map) : <String, dynamic>{};
    final details = row['contentDetails'] is Map ? Map<String, dynamic>.from(row['contentDetails'] as Map) : <String, dynamic>{};
    final id = row['id'] is Map
        ? (row['id'] as Map)['videoId']?.toString() ?? ''
        : row['id']?.toString() ?? '';
    final published = snippet['publishedAt']?.toString() ?? '';
    return WaveMusicTrack(
      id: _trackId(id),
      title: _cleanTitle(snippet['title']?.toString() ?? ''),
      artist: snippet['channelTitle']?.toString() ?? '',
      artistId: _channelId(snippet['channelId']?.toString() ?? ''),
      album: '',
      albumId: '',
      artworkUrl: _thumbnail(snippet['thumbnails']),
      audioUrl: '',
      durationMs: _isoDurationMs(details['duration']?.toString() ?? ''),
      provider: provider,
      providerId: id,
      isPreview: false,
      year: int.tryParse(published.length >= 4 ? published.substring(0, 4) : '') ?? 0,
    );
  }

  WaveMusicArtist _mapChannel(Map<String, dynamic> row) {
    final snippet = row['snippet'] is Map ? Map<String, dynamic>.from(row['snippet'] as Map) : <String, dynamic>{};
    final stats = row['statistics'] is Map ? Map<String, dynamic>.from(row['statistics'] as Map) : <String, dynamic>{};
    final id = row['id']?.toString() ?? '';
    final extras = <String>[];
    final subs = stats['subscriberCount']?.toString();
    if (subs != null && subs.isNotEmpty) extras.add('$subs subscribers');
    final videos = stats['videoCount']?.toString();
    if (videos != null && videos.isNotEmpty) extras.add('$videos videos');
    final bio = snippet['description']?.toString().trim() ?? '';
    return WaveMusicArtist(
      id: _channelId(id),
      name: snippet['title']?.toString() ?? '',
      artworkUrl: _thumbnail(snippet['thumbnails']),
      bio: extras.isEmpty ? bio : (bio.isEmpty ? extras.join(' · ') : '$bio\n${extras.join(' · ')}'),
      provider: provider,
      providerId: id,
    );
  }

  WaveMusicArtist? _mapChannelSearch(Map<String, dynamic> row) {
    final snippet = row['snippet'] is Map ? Map<String, dynamic>.from(row['snippet'] as Map) : <String, dynamic>{};
    final id = row['id'] is Map ? (row['id'] as Map)['channelId']?.toString() ?? '' : '';
    if (id.isEmpty) return null;
    return WaveMusicArtist(
      id: _channelId(id),
      name: snippet['title']?.toString() ?? snippet['channelTitle']?.toString() ?? '',
      artworkUrl: _thumbnail(snippet['thumbnails']),
      provider: provider,
      providerId: id,
    );
  }

  WaveMusicPlaylist? _mapPlaylistSearch(Map<String, dynamic> row) {
    final snippet = row['snippet'] is Map ? Map<String, dynamic>.from(row['snippet'] as Map) : <String, dynamic>{};
    final id = row['id'] is Map ? (row['id'] as Map)['playlistId']?.toString() ?? '' : '';
    if (id.isEmpty) return null;
    return WaveMusicPlaylist(
      id: _playlistId(id),
      title: snippet['title']?.toString() ?? '',
      description: snippet['channelTitle']?.toString() ?? '',
      artworkUrl: _thumbnail(snippet['thumbnails']),
      provider: provider,
      providerId: id,
    );
  }

  WaveMusicPlaylist _mapPlaylist(Map<String, dynamic> row) {
    final snippet = row['snippet'] is Map ? Map<String, dynamic>.from(row['snippet'] as Map) : <String, dynamic>{};
    final id = row['id']?.toString() ?? '';
    return WaveMusicPlaylist(
      id: _playlistId(id),
      title: snippet['title']?.toString() ?? '',
      description: snippet['description']?.toString() ?? snippet['channelTitle']?.toString() ?? '',
      artworkUrl: _thumbnail(snippet['thumbnails']),
      provider: provider,
      providerId: id,
    );
  }

  WaveMusicAlbum _albumFromPlaylist(WaveMusicPlaylist playlist) {
    return WaveMusicAlbum(
      id: playlist.id.replaceFirst('yt:playlist:', 'yt:album:'),
      title: playlist.title,
      artist: playlist.description,
      artistId: '',
      artworkUrl: playlist.artworkUrl,
      year: 0,
      trackIds: playlist.trackIds,
      trackCount: playlist.trackIds.length,
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
            provider: provider,
            providerId: _bareId(t.artistId) ?? '',
            popularTrackIds: [t.id],
          ),
        ),
      );
    }
    return out;
  }

  String _thumbnail(dynamic node) {
    if (node is! Map) return '';
    final map = Map<String, dynamic>.from(node);
    for (final size in ['maxres', 'standard', 'high', 'medium', 'default']) {
      final item = map[size];
      if (item is Map) {
        final url = item['url']?.toString() ?? '';
        if (url.startsWith('http')) return url;
      }
    }
    return '';
  }

  String _videoIdFrom(Map<String, dynamic> row) {
    final id = row['id'];
    if (id is Map) return id['videoId']?.toString() ?? '';
    return id?.toString() ?? '';
  }

  String _cleanTitle(String title) {
    return title
        .replaceAll(
          RegExp(
            r'\s*[\(\[]\s*(official\s*)?(music\s*)?(video|audio|lyric[s]?|visualizer|hd|4k|remaster(ed)?)\s*[\)\]]',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  bool _looksLikeAlbum(String title) {
    final lower = title.toLowerCase();
    return lower.contains('album') && !lower.contains('albums you') && !lower.contains('album mix');
  }

  bool _sameWork(WaveMusicTrack youtube, WaveMusicTrack audius) {
    final ytTitle = _norm(youtube.title);
    final auTitle = _norm(audius.title);
    if (ytTitle.isEmpty || auTitle.isEmpty) return false;
    final titleHit = ytTitle == auTitle || ytTitle.contains(auTitle) || auTitle.contains(ytTitle);
    if (!titleHit) return false;
    final ytArtist = _norm(youtube.artist);
    final auArtist = _norm(audius.artist);
    if (ytArtist.isEmpty || auArtist.isEmpty) return titleHit;
    return ytArtist.contains(auArtist) || auArtist.contains(ytArtist);
  }

  String _norm(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff\u0750-\u077f]+'), ' ').trim();
  }

  int _isoDurationMs(String iso) {
    final match = RegExp(r'^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$').firstMatch(iso);
    if (match == null) return 0;
    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '') ?? 0;
    return (((hours * 60) + minutes) * 60 + seconds) * 1000;
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
    if (artist.id.isNotEmpty) _artists[artist.id] = artist;
    return artist;
  }

  WaveMusicPlaylist _rememberPlaylist(WaveMusicPlaylist playlist) {
    if (playlist.id.isNotEmpty) _playlists[playlist.id] = playlist;
    return playlist;
  }

  String _trackId(String n) => n.isEmpty ? '' : 'yt:video:$n';
  String _channelId(String n) => n.isEmpty ? '' : 'yt:channel:$n';
  String _playlistId(String n) => n.isEmpty ? '' : 'yt:playlist:$n';

  String? _bareId(String id) {
    if (id.isEmpty) return null;
    if (id.contains(':discover:')) return null;
    if (!id.contains(':')) return id;
    return id.split(':').last;
  }
}
