import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/wave_music_track.dart';

/// iOS catalog and audio-only stream lookup.
/// Android keeps NewPipe. This file is not used on Android.
class IosYoutubeMusic {
  IosYoutubeMusic._();

  static final YoutubeExplode _yt = YoutubeExplode();

  static Future<Map<String, dynamic>> invoke(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'musicSongs':
        final items = await _songs(
          args['query']?.toString() ?? '',
          (args['limit'] as num?)?.toInt() ?? 20,
        );
        return {'items': items, 'data': items};
      case 'searchMusic':
        return _search(
          args['query']?.toString() ?? '',
          (args['limit'] as num?)?.toInt() ?? 20,
        );
      case 'loadCollection':
        return _collection(
          url: args['url']?.toString() ?? '',
          kind: args['kind']?.toString() ?? 'playlist',
          name: args['name']?.toString() ?? '',
        );
      default:
        return const {};
    }
  }

  static Future<WaveMusicTrack> resolveTrack(WaveMusicTrack track) async {
    final source = track.permalinkUrl.trim().isNotEmpty ? track.permalinkUrl : track.providerId;
    final id = _videoId(source);
    if (id.isEmpty) return track.copyWith(audioUrl: '');
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(id);
      final chosen = _chooseAudio(manifest.audioOnly);
      if (chosen == null) {
        debugPrint('[WAVE_IOS] no mp4 audio id=$id');
        return track.copyWith(audioUrl: '');
      }
      final url = chosen.url.toString();
      if (!url.startsWith('http')) return track.copyWith(audioUrl: '');
      debugPrint(
        '[WAVE_IOS] audio id=$id container=${chosen.container.name} bitrate=${chosen.bitrate.bitsPerSecond}',
      );
      return track.copyWith(
        audioUrl: url,
        mimeType: chosen.container == StreamContainer.m3u8 ? 'audio/mpegurl' : 'audio/mp4',
        streamHeaders: const {'User-Agent': 'Mozilla/5.0'},
      );
    } catch (e) {
      debugPrint('[WAVE_IOS] resolve failed id=$id type=${e.runtimeType}');
      return track.copyWith(audioUrl: '');
    }
  }

  static AudioOnlyStreamInfo? _chooseAudio(List<AudioOnlyStreamInfo> streams) {
    final mp4 = streams.where((stream) => stream.container == StreamContainer.mp4).toList();
    final hls = streams.where((stream) => stream.container == StreamContainer.m3u8).toList();
    final pool = mp4.isNotEmpty ? mp4 : hls;
    if (pool.isEmpty) return null;
    pool.sort((a, b) {
      final da = (a.bitrate.bitsPerSecond - 128000).abs();
      final db = (b.bitrate.bitsPerSecond - 128000).abs();
      return da.compareTo(db);
    });
    return pool.first;
  }

  static Future<List<Map<String, dynamic>>> _songs(String query, int limit) async {
    final q = query.trim().isEmpty ? 'music' : query.trim();
    final results = await _yt.search.search(q);
    return results.where((video) => _keep(video.title, video.duration)).take(limit).map(_trackMap).toList();
  }

  static Future<Map<String, dynamic>> _search(String query, int limit) async {
    final tracks = await _songs(query, limit.clamp(1, 25));
    return {
      'tracks': tracks,
      'artists': const <Map<String, dynamic>>[],
      'albums': const <Map<String, dynamic>>[],
      'playlists': const <Map<String, dynamic>>[],
    };
  }

  static Future<Map<String, dynamic>> _collection({
    required String url,
    required String kind,
    required String name,
  }) async {
    final query = name.trim().isNotEmpty ? name.trim() : url;
    final tracks = await _songs(query, 20);
    return {
      'kind': kind,
      'title': name,
      'url': url,
      'artworkUrl': tracks.isEmpty ? '' : tracks.first['artworkUrl'],
      'trackCount': tracks.length,
      'tracks': tracks,
    };
  }

  static Map<String, dynamic> _trackMap(Video video) {
    final seconds = video.duration?.inSeconds ?? 0;
    return {
      'type': 'track',
      'id': video.id.value,
      'title': video.title,
      'artist': video.author,
      'artistUrl': video.channelId.value,
      'album': '',
      'durationMs': seconds > 0 ? seconds * 1000 : 0,
      'artworkUrl': video.thumbnails.mediumResUrl,
      'url': video.url,
    };
  }

  static bool _keep(String title, Duration? duration) {
    final text = title.toLowerCase();
    if (text.contains('full album') || text.contains('podcast') || text.contains('live stream')) {
      return false;
    }
    final seconds = duration?.inSeconds ?? 0;
    if (seconds > 0 && (seconds < 45 || seconds > 600)) return false;
    return true;
  }

  static String _videoId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    try {
      return VideoId(trimmed).value;
    } catch (_) {
      final match = RegExp(r'[\w-]{11}').firstMatch(trimmed);
      return match?.group(0) ?? '';
    }
  }
}
