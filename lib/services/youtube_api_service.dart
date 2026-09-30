import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/wave_config.dart';
import '../models/wave_creator.dart';
import '../models/wave_video.dart';
import 'wave_youtube_parser.dart';

enum WaveFeedKind {
  forYou,
  trending,
  live,
  music,
  gaming,
  technology,
  podcasts,
  documentaries,
  news,
}

class YouTubeApiService {
  YouTubeApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future<dynamic>> _inFlight = {};
  final Map<String, WaveCreator> _creatorCache = {};

  static const _timeout = Duration(seconds: 15);
  static const _videoParts =
      'snippet,contentDetails,statistics,status,liveStreamingDetails';
  static const _channelParts = 'snippet,statistics,contentDetails';

  void clearCache() {
    _cache.clear();
    _inFlight.clear();
    _creatorCache.clear();
  }

  Future<WavePage<WaveVideo>> trending({
    String? pageToken,
    String regionCode = WaveConfig.defaultRegionCode,
    bool forceRefresh = false,
  }) {
    return _pagedVideos(
      cacheKey: 'trending:$regionCode:${pageToken ?? ''}',
      ttl: WaveConfig.feedCacheTtl,
      forceRefresh: forceRefresh,
      request: () => _get('/videos', {
        'part': _videoParts,
        'chart': 'mostPopular',
        'maxResults': '${WaveConfig.shelfPageSize}',
        'regionCode': regionCode,
        if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
      }),
    );
  }

  Future<WavePage<WaveVideo>> categoryFeed(
    WaveFeedKind kind, {
    String? pageToken,
    bool forceRefresh = false,
  }) {
    switch (kind) {
      case WaveFeedKind.trending:
        return trending(pageToken: pageToken, forceRefresh: forceRefresh);
      case WaveFeedKind.live:
        return searchVideos(
          query: '',
          eventType: 'live',
          pageToken: pageToken,
          forceRefresh: forceRefresh,
        );
      case WaveFeedKind.music:
        return searchVideos(
          query: '',
          videoCategoryId: '10',
          pageToken: pageToken,
          forceRefresh: forceRefresh,
        );
      case WaveFeedKind.gaming:
        return searchVideos(
          query: '',
          videoCategoryId: '20',
          pageToken: pageToken,
          forceRefresh: forceRefresh,
        );
      case WaveFeedKind.news:
        return searchVideos(
          query: '',
          videoCategoryId: '25',
          pageToken: pageToken,
          forceRefresh: forceRefresh,
        );
      case WaveFeedKind.technology:
        return searchVideos(
          query: '',
          videoCategoryId: '28',
          pageToken: pageToken,
          forceRefresh: forceRefresh,
        );
      case WaveFeedKind.podcasts:
        return searchVideos(
          query: 'podcast',
          pageToken: pageToken,
          forceRefresh: forceRefresh,
        );
      case WaveFeedKind.documentaries:
        return searchVideos(
          query: 'documentary',
          videoDuration: 'long',
          pageToken: pageToken,
          forceRefresh: forceRefresh,
        );
      case WaveFeedKind.forYou:
        return trending(pageToken: pageToken, forceRefresh: forceRefresh);
    }
  }

  Future<WavePage<WaveVideo>> searchVideos({
    required String query,
    String? pageToken,
    String? eventType,
    String? videoCategoryId,
    String? channelId,
    String? videoDuration,
    String order = 'relevance',
    int maxResults = WaveConfig.searchPageSize,
    bool forceRefresh = false,
  }) {
    final cacheKey =
        'search:$query:$eventType:$videoCategoryId:$channelId:$videoDuration:$order:$pageToken:$maxResults';
    return _dedupe(cacheKey, () async {
      final cached = _read<WavePage<WaveVideo>>(
        cacheKey,
        eventType == 'live' ? WaveConfig.liveCacheTtl : WaveConfig.searchCacheTtl,
        forceRefresh,
      );
      if (cached != null) return cached;

      final body = await _get('/search', {
        'part': 'snippet',
        'type': 'video',
        'videoEmbeddable': 'true',
        'videoSyndicated': 'true',
        'maxResults': '$maxResults',
        'safeSearch': 'moderate',
        'order': order,
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (eventType != null) 'eventType': eventType,
        if (videoCategoryId != null) 'videoCategoryId': videoCategoryId,
        if (channelId != null) 'channelId': channelId,
        if (videoDuration != null) 'videoDuration': videoDuration,
        if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
      });

      final ids = _videoIdsFromSearch(body);
      final videos = await videosByIds(ids);
      final liveOnly = eventType == 'live'
          ? videos.where((video) => video.liveState == WaveLiveState.live).toList()
          : videos;
      final page = WavePage<WaveVideo>(
        items: liveOnly,
        nextPageToken: body['nextPageToken'] as String?,
      );
      _write(cacheKey, page);
      return page;
    });
  }

  Future<WavePage<WaveCreator>> searchCreators({
    required String query,
    String? pageToken,
    bool forceRefresh = false,
  }) {
    final cacheKey = 'creators:${query.trim()}:$pageToken';
    return _dedupe(cacheKey, () async {
      final cached = _read<WavePage<WaveCreator>>(
        cacheKey,
        WaveConfig.searchCacheTtl,
        forceRefresh,
      );
      if (cached != null) return cached;

      final body = await _get('/search', {
        'part': 'snippet',
        'type': 'channel',
        'maxResults': '${WaveConfig.searchPageSize}',
        'q': query.trim(),
        'safeSearch': 'moderate',
        if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
      });

      final ids = <String>[];
      final items = body['items'] as List? ?? const [];
      for (final item in items) {
        if (item is! Map) continue;
        final id = item['id'];
        if (id is Map && id['channelId'] is String) {
          ids.add(id['channelId'] as String);
        } else if (id is String) {
          ids.add(id);
        }
      }
      final creators = await channelsByIds(ids);
      final page = WavePage<WaveCreator>(
        items: creators,
        nextPageToken: body['nextPageToken'] as String?,
      );
      _write(cacheKey, page);
      return page;
    });
  }

  Future<List<WaveVideo>> videosByIds(List<String> ids) async {
    final unique = ids.where((id) => id.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return const [];

    final result = <WaveVideo>[];
    final missing = <String>[];
    for (final id in unique) {
      final cached = _read<WaveVideo>('video:$id', WaveConfig.detailsCacheTtl, false);
      if (cached != null) {
        result.add(cached);
      } else {
        missing.add(id);
      }
    }

    for (var i = 0; i < missing.length; i += 50) {
      final chunk = missing.sublist(i, i + 50 > missing.length ? missing.length : i + 50);
      final body = await _get('/videos', {
        'part': _videoParts,
        'id': chunk.join(','),
        'maxResults': '${chunk.length}',
      });
      final items = body['items'] as List? ?? const [];
      for (final item in items) {
        if (item is! Map) continue;
        final video = WaveYoutubeParser.videoFromResource(
          Map<String, dynamic>.from(item),
        );
        if (video == null || !video.embeddable) continue;
        _write('video:${video.videoId}', video);
        result.add(video);
      }
    }

    final byId = {for (final video in result) video.videoId: video};
    return unique.map((id) => byId[id]).whereType<WaveVideo>().toList();
  }

  Future<List<WaveCreator>> channelsByIds(List<String> ids) async {
    final unique = ids.where((id) => id.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return const [];

    final result = <WaveCreator>[];
    final missing = <String>[];
    for (final id in unique) {
      final memory = _creatorCache[id];
      if (memory != null) {
        result.add(memory);
        continue;
      }
      final cached = _read<WaveCreator>('channel:$id', WaveConfig.channelCacheTtl, false);
      if (cached != null) {
        _creatorCache[id] = cached;
        result.add(cached);
      } else {
        missing.add(id);
      }
    }

    for (var i = 0; i < missing.length; i += 50) {
      final chunk = missing.sublist(i, i + 50 > missing.length ? missing.length : i + 50);
      final body = await _get('/channels', {
        'part': _channelParts,
        'id': chunk.join(','),
        'maxResults': '${chunk.length}',
      });
      final items = body['items'] as List? ?? const [];
      for (final item in items) {
        if (item is! Map) continue;
        final creator = WaveYoutubeParser.creatorFromResource(
          Map<String, dynamic>.from(item),
        );
        if (creator == null) continue;
        _creatorCache[creator.youtubeChannelId] = creator;
        _write('channel:${creator.youtubeChannelId}', creator);
        result.add(creator);
      }
    }

    final byId = {for (final creator in result) creator.youtubeChannelId: creator};
    return unique.map((id) => byId[id]).whereType<WaveCreator>().toList();
  }

  Future<WaveCreator?> channelById(String channelId) async {
    final list = await channelsByIds([channelId]);
    return list.isEmpty ? null : list.first;
  }

  Future<WavePage<WaveVideo>> channelUploads({
    required String uploadsPlaylistId,
    String? pageToken,
    int maxResults = WaveConfig.shelfPageSize,
    bool forceRefresh = false,
  }) {
    final cacheKey = 'uploads:$uploadsPlaylistId:$pageToken:$maxResults';
    return _dedupe(cacheKey, () async {
      final cached = _read<WavePage<WaveVideo>>(
        cacheKey,
        WaveConfig.feedCacheTtl,
        forceRefresh,
      );
      if (cached != null) return cached;

      final body = await _get('/playlistItems', {
        'part': 'snippet,contentDetails',
        'playlistId': uploadsPlaylistId,
        'maxResults': '$maxResults',
        if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
      });
      final ids = <String>[];
      final items = body['items'] as List? ?? const [];
      for (final item in items) {
        if (item is! Map) continue;
        final content = item['contentDetails'];
        if (content is Map && content['videoId'] is String) {
          ids.add(content['videoId'] as String);
        }
      }
      final videos = await videosByIds(ids);
      final page = WavePage<WaveVideo>(
        items: videos,
        nextPageToken: body['nextPageToken'] as String?,
      );
      _write(cacheKey, page);
      return page;
    });
  }

  Future<List<WaveVideo>> recentFromChannels(List<String> channelIds) async {
    if (channelIds.isEmpty) return const [];
    final creators = await channelsByIds(channelIds.take(8).toList());
    final collected = <WaveVideo>[];
    for (final creator in creators) {
      final playlistId = creator.uploadsPlaylistId;
      if (playlistId == null || playlistId.isEmpty) continue;
      try {
        final page = await channelUploads(
          uploadsPlaylistId: playlistId,
          maxResults: 5,
        );
        collected.addAll(page.items);
      } on WaveApiException {
        continue;
      }
    }
    collected.sort((a, b) {
      final aDate = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return collected.take(24).toList();
  }

  Future<WavePage<WaveVideo>> _pagedVideos({
    required String cacheKey,
    required Duration ttl,
    required bool forceRefresh,
    required Future<Map<String, dynamic>> Function() request,
  }) {
    return _dedupe(cacheKey, () async {
      final cached = _read<WavePage<WaveVideo>>(cacheKey, ttl, forceRefresh);
      if (cached != null) return cached;
      final body = await request();
      final items = body['items'] as List? ?? const [];
      final videos = <WaveVideo>[];
      for (final item in items) {
        if (item is! Map) continue;
        final video = WaveYoutubeParser.videoFromResource(
          Map<String, dynamic>.from(item),
        );
        if (video == null || !video.embeddable) continue;
        _write('video:${video.videoId}', video);
        videos.add(video);
      }
      final page = WavePage<WaveVideo>(
        items: videos,
        nextPageToken: body['nextPageToken'] as String?,
      );
      _write(cacheKey, page);
      return page;
    });
  }

  List<String> _videoIdsFromSearch(Map<String, dynamic> body) {
    final ids = <String>[];
    final items = body['items'] as List? ?? const [];
    for (final item in items) {
      if (item is! Map) continue;
      final id = item['id'];
      if (id is Map && id['videoId'] is String) {
        ids.add(id['videoId'] as String);
      } else if (id is String) {
        ids.add(id);
      }
    }
    return ids;
  }

  Future<T> _dedupe<T>(String key, Future<T> Function() run) {
    final existing = _inFlight[key];
    if (existing != null) return existing as Future<T>;
    final future = run();
    _inFlight[key] = future;
    return future.whenComplete(() => _inFlight.remove(key));
  }

  T? _read<T>(String key, Duration ttl, bool forceRefresh) {
    if (forceRefresh) return null;
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > ttl) {
      _cache.remove(key);
      return null;
    }
    return entry.data is T ? entry.data as T : null;
  }

  void _write(String key, Object data) {
    _cache[key] = _CacheEntry(data, DateTime.now());
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    final apiKey = await WaveConfig.resolveApiKey();
    if (apiKey.isEmpty) {
      throw const WaveApiException(
        WaveApiErrorKind.missingApiKey,
        'Wave needs a YouTube Data API key.',
      );
    }

    final uri = Uri.parse('${WaveConfig.youtubeDataBaseUrl}$path').replace(
      queryParameters: {
        ...query,
        'key': apiKey,
      },
    );

    try {
      final response = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'X-Android-Package': WaveConfig.androidPackageName,
              'X-Android-Cert': WaveConfig.androidSha1Cert,
            },
          )
          .timeout(_timeout);
      Map<String, dynamic> body = const {};
      if (response.body.isNotEmpty) {
        final decoded = json.decode(response.body);
        if (decoded is Map) {
          body = Map<String, dynamic>.from(decoded);
        } else {
          throw const WaveApiException(
            WaveApiErrorKind.malformed,
            'Wave received an unexpected response.',
          );
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body;
      }

      final googleError = WaveYoutubeParser.parseGoogleError(body);
      debugPrint(
        'YouTube API ${response.statusCode} ${googleError?.reason ?? ''} ${googleError?.status ?? ''}',
      );

      if (googleError?.isQuota == true) {
        throw const WaveApiException(
          WaveApiErrorKind.quotaExceeded,
          'Wave has reached today\'s discovery limit. Try again later.',
        );
      }
      if (googleError?.isNotEnabled == true) {
        throw const WaveApiException(
          WaveApiErrorKind.notEnabled,
          'Enable YouTube Data API v3 for this key in Google Cloud Console.',
        );
      }
      if (googleError?.isInvalidKey == true) {
        throw const WaveApiException(
          WaveApiErrorKind.missingApiKey,
          'This YouTube API key is not valid for Wave.',
        );
      }
      if (googleError?.isRestricted == true || response.statusCode == 403) {
        throw const WaveApiException(
          WaveApiErrorKind.restricted,
          'This YouTube API key is blocked by its Google Cloud restrictions.',
        );
      }
      throw const WaveApiException(
        WaveApiErrorKind.unavailable,
        'Wave couldn\'t load this content.',
      );
    } on WaveApiException {
      rethrow;
    } on TimeoutException {
      throw const WaveApiException(
        WaveApiErrorKind.timeout,
        'Wave took too long to respond. Try again.',
      );
    } on SocketException {
      throw const WaveApiException(
        WaveApiErrorKind.noInternet,
        'Wave couldn\'t connect. Try again.',
      );
    } on http.ClientException {
      throw const WaveApiException(
        WaveApiErrorKind.noInternet,
        'Wave couldn\'t connect. Try again.',
      );
    } on FormatException {
      throw const WaveApiException(
        WaveApiErrorKind.malformed,
        'Wave received an unexpected response.',
      );
    } catch (error) {
      debugPrint('YouTube API error: $error');
      throw const WaveApiException(
        WaveApiErrorKind.unknown,
        'Wave couldn\'t load this content.',
      );
    }
  }
}

class _CacheEntry {
  final Object data;
  final DateTime at;
  _CacheEntry(this.data, this.at);
}
