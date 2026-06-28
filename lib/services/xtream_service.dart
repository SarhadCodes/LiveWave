import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/xtream_config.dart';
import '../models/channel.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';

class _M3uEntry {
  final String name;
  final String url;
  final String logo;
  final String group;
  final String streamType;

  const _M3uEntry({
    required this.name,
    required this.url,
    required this.logo,
    required this.group,
    required this.streamType,
  });
}

class XtreamService {
  static const _userAgents = [
    'IPTV Smarters Pro',
    'XP Player',
    'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Dalvik/2.1.0 (Linux; U; Android 13)',
  ];

  static const _baseHeaders = {
    'Accept': '*/*',
    'Connection': 'Keep-Alive',
  };

  static const _apiPath = '/player_api.php';

  XtreamCredentials _credentials = const XtreamCredentials(
    serverUrl: XtreamConfig.defaultServerUrl,
    username: XtreamConfig.defaultUsername,
    password: XtreamConfig.defaultPassword,
  );

  String? _resolvedApiBase;

  Future<void> _ensureCredentials() async {
    _credentials = await XtreamConfig.load();
    _resolvedApiBase = null;
    debugPrint('Xtream credentials loaded for: ${_credentials.baseUrl} (user: ${_credentials.username})');
    debugPrint('Xtream M3U URL: ${_credentials.builtM3uUri}');
    await _bootstrapServerInfo(_credentials);
  }

  Map<String, String> _headersForAttempt(int attempt) => {
        ..._baseHeaders,
        'User-Agent': _userAgents[attempt % _userAgents.length],
      };

  /// Like XP Player / Smarters: login first, follow server_info redirect if present.
  Future<void> _bootstrapServerInfo(XtreamCredentials creds) async {
    for (final base in _apiBasesToTry()) {
      final baseCreds = creds.withBaseUrl(base);
      for (var attempt = 0; attempt < _userAgents.length; attempt++) {
        try {
          final uri = Uri.parse('${baseCreds.baseUrl}$_apiPath').replace(
            queryParameters: {
              'username': baseCreds.username,
              'password': baseCreds.password,
            },
          );
          final response = await http
              .get(uri, headers: _headersForAttempt(attempt))
              .timeout(const Duration(seconds: 20));

          if (response.statusCode != 200) continue;

          final decoded = _decodeJson(response.body);
          if (decoded is! Map) continue;

          final map = Map<String, dynamic>.from(decoded);
          final serverInfo = map['server_info'];
          if (serverInfo is Map) {
            final discovered = _apiBaseFromServerInfo(Map<String, dynamic>.from(serverInfo));
            if (discovered != null) {
              _resolvedApiBase = discovered;
              _credentials = baseCreds.withBaseUrl(discovered);
              debugPrint('Xtream server_info redirect → $discovered');
            }
          }

          final userInfo = map['user_info'];
          if (userInfo is Map) {
            final auth = userInfo['auth'];
            if (auth == 1 || auth == '1' || auth == true) {
              _resolvedApiBase ??= base;
              _credentials = baseCreds;
              debugPrint('Xtream login OK on $base');
              return;
            }
          }
        } catch (e) {
          debugPrint('Xtream bootstrap failed on $base: $e');
        }
      }
    }
  }

  String? _apiBaseFromServerInfo(Map<String, dynamic> info) {
    final rawUrl = info['url']?.toString().trim() ??
        info['server_url']?.toString().trim() ??
        info['domain']?.toString().trim();
    if (rawUrl == null || rawUrl.isEmpty) return null;

    var protocol = info['server_protocol']?.toString().trim().toLowerCase();
    if (protocol != 'http' && protocol != 'https') {
      protocol = rawUrl.startsWith('https') ? 'https' : 'http';
    }

    var host = rawUrl;
    if (host.startsWith('http://') || host.startsWith('https://')) {
      final uri = Uri.tryParse(host);
      if (uri != null && uri.host.isNotEmpty) {
        protocol = uri.scheme;
        host = uri.host;
      }
    }

    final port = info['port']?.toString().trim() ??
        info['https_port']?.toString().trim();
    final portSuffix = (port != null && port.isNotEmpty && port != '80' && port != '443')
        ? ':$port'
        : '';

    return '$protocol://$host$portSuffix';
  }

  Future<http.Response> _requestApi(Uri uri, {String? action}) async {
    Object? lastError;
    for (var attempt = 0; attempt < _userAgents.length; attempt++) {
      final headers = _headersForAttempt(attempt);
      try {
        final getResponse = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 30));
        if (getResponse.statusCode == 200) return getResponse;
        lastError = Exception('HTTP ${getResponse.statusCode}');
      } catch (e) {
        lastError = e;
      }

      if (action != null) {
        try {
          final postResponse = await http
              .post(
                Uri.parse('${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}${uri.path}'),
                headers: {
                  ...headers,
                  'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: {
                  'username': uri.queryParameters['username'] ?? '',
                  'password': uri.queryParameters['password'] ?? '',
                  'action': action,
                },
              )
              .timeout(const Duration(seconds: 30));
          if (postResponse.statusCode == 200) return postResponse;
          lastError = Exception('HTTP ${postResponse.statusCode}');
        } catch (e) {
          lastError = e;
        }
      }
    }
    throw lastError ?? Exception('Network request failed');
  }

  Uri _apiUri(String action, XtreamCredentials creds, {String path = '/player_api.php'}) {
    return Uri.parse('${creds.baseUrl}$path').replace(
      queryParameters: {
        'username': creds.username,
        'password': creds.password,
        'action': action,
      },
    );
  }

  Future<List<Channel>> getLiveChannels() async {
    await _ensureCredentials();
    if (!_credentials.isComplete) {
      throw Exception('Xtream credentials incomplete — open Settings and enter server, username, and password');
    }

    if (_credentials.hasM3uUrl && !_credentials.hasApiCredentials) {
      return await _getLiveChannelsFromM3u();
    }

    try {
      return await _getLiveChannelsFromApi();
    } catch (apiError) {
      debugPrint('Xtream API live failed: $apiError — trying built-in M3U');
      try {
        final m3uChannels = await _getLiveChannelsFromM3u();
        return await _enrichLiveChannelsFromApi(m3uChannels, apiError);
      } catch (m3uError) {
        throw Exception(
          'Could not connect like XP Player.\n'
          'Copy the exact Server URL from XP Player → Account Info (not the M3U link).\n'
          'API: $apiError\n'
          'Playlist: $m3uError',
        );
      }
    }
  }

  Future<List<Channel>> _enrichLiveChannelsFromApi(
    List<Channel> m3uChannels,
    Object priorApiError,
  ) async {
    try {
      final bases = _apiBasesToTry(streamUrls: m3uChannels.map((c) => c.stream).toList());
      for (final base in bases) {
        try {
          final creds = _credentials.withBaseUrl(base);
          final categories = await _fetchCategoryMap('get_live_categories', creds: creds);
          final streams = await _fetchList('get_live_streams', creds: creds);
          if (streams.isEmpty) continue;
          debugPrint('Xtream API enrichment succeeded on $base');
          return _mergeLiveChannels(m3uChannels, streams, categories, creds);
        } catch (e) {
          debugPrint('Xtream enrichment failed on $base: $e');
        }
      }
    } catch (e) {
      debugPrint('Xtream enrichment skipped: $e');
    }
    debugPrint('Using M3U channels without API logos ($priorApiError)');
    return m3uChannels;
  }

  Future<List<Channel>> _getLiveChannelsFromApi() async {
    final creds = _credentials;
    final streams = await _fetchList('get_live_streams', creds: creds);

    Map<String, String> categories = {};
    try {
      categories = await _fetchCategoryMap('get_live_categories', creds: creds);
    } catch (e) {
      debugPrint('Xtream live categories unavailable: $e');
    }

    debugPrint('Xtream API live streams: ${streams.length}');
    return _mapLiveStreams(streams, categories, creds);
  }

  List<Channel> _mapLiveStreams(
    List<Map<String, dynamic>> streams,
    Map<String, String> categories,
    XtreamCredentials creds,
  ) {
    final channels = <Channel>[];
    for (var i = 0; i < streams.length; i++) {
      final stream = streams[i];
      final streamId = _parseInt(stream['stream_id']);
      if (streamId == null) continue;

      final categoryId = stream['category_id']?.toString() ?? '';
      final categoryName = categories[categoryId] ?? 'Live TV';
      final streamUrl = _liveStreamUrl(stream, streamId, creds);

      channels.add(
        Channel.fromXtream(
          streamId: streamId,
          name: stream['name']?.toString() ?? 'Channel $streamId',
          logo: _resolveMediaUrl(stream['stream_icon']?.toString() ?? '', streamUrl),
          streamUrl: streamUrl,
          category: categoryName,
          order: _parseInt(stream['num']) ?? i,
        ),
      );
    }

    if (channels.isEmpty) {
      throw Exception('Xtream API returned 0 live channels');
    }

    channels.sort((a, b) => a.order.compareTo(b.order));
    return channels;
  }

  List<Channel> _mergeLiveChannels(
    List<Channel> m3uChannels,
    List<Map<String, dynamic>> apiStreams,
    Map<String, String> categories,
    XtreamCredentials creds,
  ) {
    if (apiStreams.length >= m3uChannels.length * 0.8) {
      return _mapLiveStreams(apiStreams, categories, creds);
    }

    final byId = <int, Map<String, dynamic>>{};
    final byName = <String, Map<String, dynamic>>{};
    for (final stream in apiStreams) {
      final id = _parseInt(stream['stream_id']);
      if (id != null) byId[id] = stream;
      final name = stream['name']?.toString().trim().toLowerCase();
      if (name != null && name.isNotEmpty) byName[name] = stream;
    }

    return m3uChannels.asMap().entries.map((entry) {
      final i = entry.key;
      final ch = entry.value;
      final id = int.tryParse(ch.id.replaceFirst('xtream_', ''));
      Map<String, dynamic>? api = id != null ? byId[id] : null;
      api ??= byName[ch.name.trim().toLowerCase()];

      if (api == null) return ch;

      final streamId = _parseInt(api['stream_id']) ?? id ?? i;
      final categoryId = api['category_id']?.toString() ?? '';
      final streamUrl = _liveStreamUrl(api, streamId, creds);

      return ch.copyWith(
        name: api['name']?.toString() ?? ch.name,
        logo: _resolveMediaUrl(api['stream_icon']?.toString() ?? '', streamUrl),
        category: categories[categoryId]?.isNotEmpty == true ? categories[categoryId]! : ch.category,
        stream: streamUrl,
        order: _parseInt(api['num']) ?? ch.order,
      );
    }).toList();
  }

  Future<List<Channel>> _getLiveChannelsFromM3u() async {
    final entries = await _fetchM3uEntries(_credentials);
    final liveEntries = entries.where((e) => e.streamType == 'live').toList();

    debugPrint('Xtream M3U live entries: ${liveEntries.length}');

    if (liveEntries.isEmpty) {
      throw Exception('M3U playlist has no live channels');
    }

    return liveEntries.asMap().entries.map((entry) {
      final i = entry.key;
      final item = entry.value;
      final streamId = _extractIdFromUrl(item.url) ?? (100000 + i);
      return Channel.fromXtream(
        streamId: streamId,
        name: item.name,
        logo: item.logo,
        streamUrl: item.url,
        category: item.group.isNotEmpty ? item.group : 'Uncategorized',
        order: i,
      );
    }).toList();
  }

  Future<List<Movie>> getVodMovies() async {
    await _ensureCredentials();
    if (!_credentials.isComplete) {
      throw Exception('Xtream credentials incomplete');
    }

    try {
      return await _getVodFromApi();
    } catch (apiError) {
      debugPrint('Xtream API VOD failed: $apiError — trying built-in M3U');
      try {
        final m3uMovies = await _getVodFromM3u();
        return await _enrichMoviesFromApi(m3uMovies);
      } catch (m3uError) {
        throw Exception('$apiError\nM3U fallback also failed: $m3uError');
      }
    }
  }

  Future<List<Movie>> _enrichMoviesFromApi(List<Movie> m3uMovies) async {
    try {
      for (final base in _apiBasesToTry(streamUrls: m3uMovies.map((m) => m.streamUrl ?? '').toList())) {
        try {
          final creds = _credentials.withBaseUrl(base);
          final categories = await _fetchCategoryMap('get_vod_categories', creds: creds);
          final streams = await _fetchList('get_vod_streams', creds: creds);
          if (streams.isEmpty) continue;
          return _mapVodStreams(streams, categories, creds);
        } catch (_) {}
      }
    } catch (_) {}
    return m3uMovies;
  }

  Future<List<TvShow>> _enrichSeriesFromApi(List<TvShow> m3uShows) async {
    try {
      for (final base in _apiBasesToTry()) {
        try {
          final creds = _credentials.withBaseUrl(base);
          final categories = await _fetchCategoryMap('get_series_categories', creds: creds);
          final streams = await _fetchList('get_series', creds: creds);
          if (streams.isEmpty) continue;
          return _mapSeriesStreams(streams, categories, creds);
        } catch (_) {}
      }
    } catch (_) {}
    return m3uShows;
  }

  List<Movie> _mapVodStreams(
    List<Map<String, dynamic>> streams,
    Map<String, String> categories,
    XtreamCredentials creds,
  ) {
    final movies = <Movie>[];
    for (var i = 0; i < streams.length; i++) {
      final item = streams[i];
      final streamId = _parseInt(item['stream_id']);
      if (streamId == null) continue;

      final categoryId = item['category_id']?.toString() ?? '';
      final categoryName = categories[categoryId] ?? 'Movies';
      final streamUrl = _vodStreamUrl(item, streamId, creds);
      final poster = _resolveMediaUrl(item['stream_icon']?.toString() ?? '', streamUrl);

      movies.add(
        Movie.fromXtream(
          streamId: streamId,
          title: item['name']?.toString() ?? 'Movie $streamId',
          overview: item['plot']?.toString() ?? '',
          posterPath: poster,
          backdropPath: poster,
          releaseDate: item['releasedate']?.toString() ?? '',
          rating: _parseDouble(item['rating']),
          streamUrl: streamUrl,
          categoryName: categoryName,
          order: i,
        ),
      );
    }
    if (movies.isEmpty) throw Exception('Xtream API returned 0 movies');
    return movies;
  }

  List<TvShow> _mapSeriesStreams(
    List<Map<String, dynamic>> streams,
    Map<String, String> categories,
    XtreamCredentials creds,
  ) {
    final shows = <TvShow>[];
    for (var i = 0; i < streams.length; i++) {
      final item = streams[i];
      final seriesId = _parseInt(item['series_id']);
      if (seriesId == null) continue;

      final categoryId = item['category_id']?.toString() ?? '';
      final categoryName = categories[categoryId] ?? 'Series';
      final posterBase = '${creds.baseUrl}/series/${creds.username}/${creds.password}/$seriesId.jpg';
      final poster = _resolveMediaUrl(item['cover']?.toString() ?? '', posterBase);

      shows.add(
        TvShow.fromXtream(
          seriesId: seriesId,
          name: item['name']?.toString() ?? 'Series $seriesId',
          overview: item['plot']?.toString() ?? '',
          posterPath: poster,
          backdropPath: poster,
          firstAirDate: item['releaseDate']?.toString() ?? '',
          rating: _parseDouble(item['rating']),
          categoryName: categoryName,
          order: i,
        ),
      );
    }
    if (shows.isEmpty) throw Exception('Xtream API returned 0 series');
    return shows;
  }

  Future<List<Movie>> _getVodFromApi() async {
    final creds = _credentials;
    final categories = await _fetchCategoryMap('get_vod_categories', creds: creds);
    final streams = await _fetchList('get_vod_streams', creds: creds);
    return _mapVodStreams(streams, categories, creds);
  }

  Future<List<Movie>> _getVodFromM3u() async {
    final entries = await _fetchM3uEntries(_credentials);
    final vodEntries = entries.where((e) => e.streamType == 'movie').toList();

    if (vodEntries.isEmpty) throw Exception('M3U playlist has no movies');

    return vodEntries.asMap().entries.map((entry) {
      final i = entry.key;
      final item = entry.value;
      final streamId = _extractIdFromUrl(item.url) ?? (200000 + i);
      return Movie.fromXtream(
        streamId: streamId,
        title: item.name,
        overview: item.group,
        posterPath: item.logo,
        backdropPath: item.logo,
        releaseDate: '',
        rating: 0,
        streamUrl: item.url,
        categoryName: item.group.isNotEmpty ? item.group : 'Movies',
        order: i,
      );
    }).toList();
  }

  Future<List<TvShow>> getSeries() async {
    await _ensureCredentials();
    if (!_credentials.isComplete) {
      throw Exception('Xtream credentials incomplete');
    }

    try {
      return await _getSeriesFromApi();
    } catch (apiError) {
      debugPrint('Xtream API series failed: $apiError — trying built-in M3U');
      try {
        final m3uShows = await _getSeriesFromM3u();
        return await _enrichSeriesFromApi(m3uShows);
      } catch (m3uError) {
        throw Exception('$apiError\nM3U fallback also failed: $m3uError');
      }
    }
  }

  Future<List<TvShow>> _getSeriesFromApi() async {
    final creds = _credentials;
    final categories = await _fetchCategoryMap('get_series_categories', creds: creds);
    final streams = await _fetchList('get_series', creds: creds);
    return _mapSeriesStreams(streams, categories, creds);
  }

  Future<List<TvShow>> _getSeriesFromM3u() async {
    final entries = await _fetchM3uEntries(_credentials);
    final seriesEntries = entries.where((e) => e.streamType == 'series').toList();

    if (seriesEntries.isEmpty) throw Exception('M3U playlist has no series');

    return seriesEntries.asMap().entries.map((entry) {
      final i = entry.key;
      final item = entry.value;
      final seriesId = _extractIdFromUrl(item.url) ?? (300000 + i);
      return TvShow.fromXtream(
        seriesId: seriesId,
        name: item.name,
        overview: item.group,
        posterPath: item.logo,
        backdropPath: item.logo,
        firstAirDate: '',
        rating: 0,
        categoryName: item.group.isNotEmpty ? item.group : 'Series',
        order: i,
      );
    }).toList();
  }

  Future<Map<int, Map<int, String>>> getSeriesEpisodes(int seriesId) async {
    await _ensureCredentials();

    Object? lastError;
    for (final base in _apiBasesToTry()) {
      try {
        final creds = _credentials.withBaseUrl(base);
        final uri = Uri.parse('${creds.baseUrl}/player_api.php').replace(
          queryParameters: {
            'username': creds.username,
            'password': creds.password,
            'action': 'get_series_info',
            'series_id': seriesId.toString(),
          },
        );

        final response = await http.get(uri, headers: _headersForAttempt(0)).timeout(
          const Duration(seconds: 20),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to load series info (HTTP ${response.statusCode})');
        }

        final decoded = _decodeJson(response.body);
        if (decoded is! Map) throw Exception('Invalid series info response');

        final map = Map<String, dynamic>.from(decoded);
        final episodes = map['episodes'];
        if (episodes is! Map) {
          _throwIfAuthFailed(map, creds);
          return {};
        }

        final result = <int, Map<int, String>>{};
        episodes.forEach((seasonKey, seasonValue) {
          final season = int.tryParse(seasonKey.toString());
          if (season == null || seasonValue is! Map) return;

          final seasonEpisodes = <int, String>{};
          seasonValue.forEach((episodeKey, episodeValue) {
            if (episodeValue is! Map) return;
            final episode = int.tryParse(episodeKey.toString());
            final episodeId = _parseInt(episodeValue['id']);
            if (episode == null || episodeId == null) return;
            seasonEpisodes[episode] =
                _seriesStreamUrl(Map<String, dynamic>.from(episodeValue), episodeId, creds);
          });

          if (seasonEpisodes.isNotEmpty) result[season] = seasonEpisodes;
        });

        return result;
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Failed to load series episodes: $lastError');
  }

  List<String> _apiBasesToTry({List<String> streamUrls = const []}) {
    final bases = <String>[];

    void add(String? base) {
      if (base == null || base.isEmpty) return;
      final cleaned = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
      if (!bases.contains(cleaned)) bases.add(cleaned);
    }

    add(_resolvedApiBase);
    add(_credentials.baseUrl);

    final configured = Uri.tryParse(_credentials.baseUrl);
    if (configured != null && configured.hasPort) {
      add('${configured.scheme}://${configured.host}');
    }

    if (_credentials.hasM3uUrl) {
      final m3uUri = Uri.tryParse(_credentials.m3uUrl.trim());
      if (m3uUri != null && m3uUri.hasScheme && m3uUri.host.isNotEmpty) {
        add(XtreamConfig.normalize(_credentials).baseUrl);
        add('${m3uUri.scheme}://${m3uUri.host}${m3uUri.hasPort ? ':${m3uUri.port}' : ''}');
      }
    }

    for (final url in streamUrls) {
      add(_streamOrigin(url));
    }

    return bases;
  }

  String? _streamOrigin(String streamUrl) {
    if (streamUrl.isEmpty) return null;
    final uri = Uri.tryParse(streamUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (!streamUrl.contains('/live/') &&
        !streamUrl.contains('/movie/') &&
        !streamUrl.contains('/series/')) {
      return null;
    }
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  Future<List<_M3uEntry>> _fetchM3uEntries(XtreamCredentials creds) async {
    final errors = <String>[];
    for (final uri in _m3uUrlsToTry(creds)) {
      try {
        debugPrint('Xtream M3U try: $uri');
        return await _fetchM3uFromUri(uri, creds);
      } catch (e) {
        errors.add('${uri.path} → $e');
        debugPrint('Xtream M3U failed: $uri — $e');
      }
    }

    throw Exception(
      'Could not download playlist from server. Check server URL, username, and password.\n${errors.join('\n')}',
    );
  }

  List<Uri> _m3uUrlsToTry(XtreamCredentials creds) {
    final urls = <Uri>[];

    if (creds.hasApiCredentials) {
      urls.add(creds.builtM3uUri);
    }

    if (creds.hasM3uUrl) {
      final custom = Uri.parse(creds.m3uUrl.trim());
      if (!urls.any((u) => u.toString() == custom.toString())) {
        urls.add(custom);
      }
    }

    if (!creds.hasApiCredentials) return urls;

    final base = creds.baseUrl;
    final params = <List<String>>[
      ['type', 'm3u_plus', 'output', 'ts'],
      ['type', 'm3u_plus', 'output', 'mpegts'],
      ['type', 'm3u'],
      [],
    ];

    for (final extra in params) {
      final query = <String, String>{
        'username': creds.username,
        'password': creds.password,
      };
      for (var i = 0; i < extra.length; i += 2) {
        query[extra[i]] = extra[i + 1];
      }
      urls.add(Uri.parse('$base/get.php').replace(queryParameters: query));
    }

    urls.add(Uri.parse('$base/playlist/${creds.username}/${creds.password}/m3u'));
    return urls;
  }

  Future<List<_M3uEntry>> _fetchM3uFromUri(Uri uri, XtreamCredentials creds) async {
    final response = await http.get(uri, headers: _headersForAttempt(0)).timeout(
      const Duration(seconds: 45),
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final body = _decodePlaylistBody(response);
    if (body.isEmpty) throw Exception('empty playlist');
    if (body.startsWith('{')) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          _throwIfAuthFailed(Map<String, dynamic>.from(decoded), creds);
        }
      } catch (_) {}
      throw Exception('JSON error instead of playlist');
    }

    if (!body.contains('#EXTM3U') && !body.contains('#EXTINF:')) {
      throw Exception('not a valid M3U file');
    }

    final entries = _parseM3u(body);
    if (entries.isEmpty) throw Exception('playlist has no channels');
    return entries;
  }

  String _decodePlaylistBody(http.Response response) {
    final bytes = response.bodyBytes;
    if (bytes.isEmpty) return '';

    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3)).trim();
    }

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (contentType.contains('charset=iso-8859-1') || contentType.contains('charset=latin1')) {
      return latin1.decode(bytes).trim();
    }

    final utf8Body = utf8.decode(bytes, allowMalformed: true);
    if (!utf8Body.contains('\uFFFD')) {
      return utf8Body.trim();
    }
    return latin1.decode(bytes).trim();
  }

  List<_M3uEntry> _parseM3u(String content) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    final entries = <_M3uEntry>[];

    String? pendingName;
    String pendingLogo = '';
    String pendingGroup = '';
    String currentExtgrp = '';

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTGRP:')) {
        final grp = line.substring(8).trim();
        if (pendingName != null) {
          pendingGroup = grp;
        } else {
          currentExtgrp = grp;
        }
        continue;
      }

      if (line.startsWith('#EXTINF:')) {
        final attrs = _parseExtinfAttributes(line);
        pendingName = attrs['tvg-name']?.trim().isNotEmpty == true
            ? attrs['tvg-name']!.trim()
            : _extractDisplayName(line);
        pendingLogo = _pickLogo(attrs);
        pendingGroup = _pickGroup(attrs, currentExtgrp);
        continue;
      }

      if (line.startsWith('#')) continue;

      if (pendingName != null) {
        entries.add(_buildM3uEntry(
          rawName: pendingName,
          streamUrl: line,
          logo: pendingLogo,
          group: pendingGroup,
        ));
        pendingName = null;
        pendingLogo = '';
        pendingGroup = '';
      }
    }

    return entries;
  }

  _M3uEntry _buildM3uEntry({
    required String rawName,
    required String streamUrl,
    required String logo,
    required String group,
  }) {
    var name = rawName.trim();
    var category = group.trim();
    final resolvedLogo = _resolveMediaUrl(logo, streamUrl);

    if (category.isEmpty) {
      final split = _splitCategoryFromName(name);
      category = split.category;
      if (split.title.isNotEmpty) name = split.title;
    }

    return _M3uEntry(
      name: name,
      url: streamUrl,
      logo: resolvedLogo,
      group: category,
      streamType: _detectStreamType(streamUrl, category, name),
    );
  }

  ({String category, String title}) _splitCategoryFromName(String raw) {
    final name = raw.trim();

    final colon = RegExp(r'^([A-Za-z0-9\u0600-\u06FF\u0750-\u077F]{1,12})\s*:\s*(.+)$');
    final colonMatch = colon.firstMatch(name);
    if (colonMatch != null) {
      return (category: colonMatch.group(1)!.trim(), title: colonMatch.group(2)!.trim());
    }

    final dash = RegExp(r'^([^\-]{2,24})\s+-\s+(.+)$');
    final dashMatch = dash.firstMatch(name);
    if (dashMatch != null) {
      final cat = dashMatch.group(1)!.trim();
      if (cat.length <= 20) {
        return (category: cat, title: dashMatch.group(2)!.trim());
      }
    }

    final pipe = RegExp(r'^([^|]{2,30})\s*\|\s*(.+)$');
    final pipeMatch = pipe.firstMatch(name);
    if (pipeMatch != null) {
      return (category: pipeMatch.group(1)!.trim(), title: pipeMatch.group(2)!.trim());
    }

    return (category: '', title: name);
  }

  String _resolveMediaUrl(String url, String streamUrl) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('data:')) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    if (trimmed.startsWith('//')) return 'https:$trimmed';
    try {
      return Uri.parse(streamUrl).resolve(trimmed).toString();
    } catch (_) {
      return '';
    }
  }

  Map<String, String> _parseExtinfAttributes(String extinf) {
    final comma = extinf.lastIndexOf(',');
    final header = comma >= 0 ? extinf.substring(0, comma) : extinf;
    final attrs = <String, String>{};

    for (final match in RegExp(
      r'''([\w-]+)=("([^"]*)"|'([^']*)')''',
      caseSensitive: false,
    ).allMatches(header)) {
      attrs[match.group(1)!.toLowerCase()] = (match.group(3) ?? match.group(4) ?? '').trim();
    }

    final keyMatches = RegExp(r'([\w-]+)=', caseSensitive: false).allMatches(header).toList();
    for (var i = 0; i < keyMatches.length; i++) {
      final key = keyMatches[i].group(1)!.toLowerCase();
      if (attrs.containsKey(key)) continue;

      final valueStart = keyMatches[i].end;
      final valueEnd = i + 1 < keyMatches.length ? keyMatches[i + 1].start : header.length;
      var value = header.substring(valueStart, valueEnd).trim();
      if (value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      } else if (value.startsWith("'") && value.endsWith("'")) {
        value = value.substring(1, value.length - 1);
      }
      if (value.isNotEmpty) attrs[key] = value;
    }

    return attrs;
  }

  String _pickLogo(Map<String, String> attrs) {
    const keys = [
      'tvg-logo',
      'tvg-logo-small',
      'logo',
      'stream-icon',
      'icon',
      'tvg_logo',
      'image',
    ];
    for (final key in keys) {
      final value = attrs[key];
      if (value != null && value.isNotEmpty) {
        return _normalizeLogoUrl(value);
      }
    }
    return '';
  }

  String _pickGroup(Map<String, String> attrs, String extgrp) {
    const keys = [
      'group-title',
      'group_title',
      'x-tvg-group',
      'tvg-group',
      'group',
    ];
    for (final key in keys) {
      final value = attrs[key];
      if (value != null && value.isNotEmpty) {
        return value.trim();
      }
    }
    return extgrp.trim();
  }

  String _normalizeLogoUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('//')) return 'https:$trimmed';
    return trimmed;
  }

  String _detectStreamType(String url, String group, [String name = '']) {
    final urlLower = url.toLowerCase();
    final metaLower = '${group.toLowerCase()} ${name.toLowerCase()}';

    if (urlLower.contains('/movie/') || urlLower.contains('/vod/')) {
      return 'movie';
    }
    if (urlLower.contains('/series/') || urlLower.contains('/episode/')) {
      return 'series';
    }
    if (metaLower.contains('vod') && !urlLower.contains('/live/')) {
      return 'movie';
    }
    if (!urlLower.contains('/live/') &&
        RegExp(r'\bs\d{1,2}\b').hasMatch(name.toLowerCase())) {
      return 'series';
    }
    return 'live';
  }

  String _extractDisplayName(String extinf) {
    final comma = extinf.lastIndexOf(',');
    if (comma != -1 && comma < extinf.length - 1) {
      return extinf.substring(comma + 1).trim();
    }
    return 'Unknown';
  }

  String _extractAttribute(String extinf, String key) {
    return _parseExtinfAttributes(extinf)[key.toLowerCase()] ?? '';
  }

  int? _extractIdFromUrl(String url) {
    final match = RegExp(r'/(\d+)\.[a-z0-9]+\$?', caseSensitive: false).firstMatch(url);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  String _liveStreamUrl(Map<String, dynamic> item, int streamId, XtreamCredentials creds) {
    final direct = item['direct_source']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    return _buildUrl('live', streamId, item['container_extension']?.toString(), creds);
  }

  String _vodStreamUrl(Map<String, dynamic> item, int streamId, XtreamCredentials creds) {
    final direct = item['direct_source']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    return _buildUrl('movie', streamId, item['container_extension']?.toString(), creds);
  }

  String _seriesStreamUrl(Map<String, dynamic> item, int episodeId, XtreamCredentials creds) {
    final direct = item['direct_source']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    return _buildUrl('series', episodeId, item['container_extension']?.toString(), creds);
  }

  String _buildUrl(String type, int id, String? extension, XtreamCredentials creds) {
    final ext = (extension != null && extension.isNotEmpty) ? extension : 'm3u8';
    return '${creds.baseUrl}/$type/${creds.username}/${creds.password}/$id.$ext';
  }

  Future<Map<String, String>> _fetchCategoryMap(String action, {required XtreamCredentials creds}) async {
    final items = await _fetchList(action, creds: creds);
    final map = <String, String>{};
    for (final item in items) {
      final id = item['category_id']?.toString();
      final name = item['category_name']?.toString();
      if (id != null && name != null) map[id] = name;
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> _fetchList(String action, {XtreamCredentials? creds}) async {
    creds ??= _credentials;
    Object? authError;
    Object? lastError;

    for (final base in _apiBasesToTry()) {
      final baseCreds = creds.baseUrl == base ? creds : creds.withBaseUrl(base);
      try {
        final response = await _requestApi(
          _apiUri(action, baseCreds, path: _apiPath),
          action: action,
        );

        final list = _extractList(_decodeJson(response.body), action, baseCreds);
        if (list.isEmpty && !action.contains('categories')) {
          throw Exception('Xtream $action returned no items');
        }

        _resolvedApiBase = base;
        _credentials = baseCreds;
        debugPrint('Xtream API connected: $base$_apiPath ($action → ${list.length} items)');
        return list;
      } catch (e) {
        if (_isAuthError(e)) {
          authError ??= e;
          debugPrint('Xtream auth failed on $base: $e');
          continue;
        }
        lastError = e;
        debugPrint('Xtream API try failed: $base$_apiPath $action — $e');
      }
    }

    if (authError != null) throw authError!;
    throw lastError ?? Exception('Xtream $action failed — server unreachable or login rejected');
  }

  bool _isAuthError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('login failed') ||
        message.contains('invalid username') ||
        message.contains('auth:0') ||
        message.contains('auth":0');
  }

  /// Quick login check — returns null when API accepts credentials.
  Future<String?> testLogin() async {
    await _ensureCredentials();
    if (!_credentials.isComplete) {
      return 'Server URL, username, and password are required';
    }

    try {
      await _fetchList('get_live_streams');
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  dynamic _decodeJson(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) throw Exception('Xtream returned empty response');
    if (trimmed.startsWith('<')) {
      throw Exception('Xtream returned HTML instead of JSON — check server URL');
    }
    return jsonDecode(trimmed);
  }

  void _throwIfAuthFailed(Map decoded, XtreamCredentials creds) {
    final userInfo = decoded['user_info'];
    if (userInfo is! Map) return;

    final auth = userInfo['auth'];
    final status = userInfo['status']?.toString().toLowerCase();
    final message = userInfo['message']?.toString();

    if (auth == 1 || auth == '1' || auth == true) return;
    if (status == 'active') return;

    if (auth == 0 || auth == '0' || auth == false) {
      throw Exception(
        'Xtream login failed: ${message ?? 'Invalid username or password'} '
        '(server: ${creds.baseUrl}, user: ${creds.username})',
      );
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic decoded, String action, XtreamCredentials creds) {
    if (decoded is List) {
      return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);

      for (final key in [action, 'data', 'channels', 'movies', 'series', 'episodes']) {
        final value = map[key];
        if (value is List) {
          return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }

      _throwIfAuthFailed(map, creds);
    }

    throw Exception('Unexpected Xtream response for $action');
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
