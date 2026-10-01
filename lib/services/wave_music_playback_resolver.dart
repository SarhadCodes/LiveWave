import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/wave_music_track.dart';
import 'ios_youtube_music.dart';
import 'soundcloud_api.dart';
import 'wave_music_http.dart';

class WaveMusicResolvedStream {
  final String url;
  final String mimeType;
  const WaveMusicResolvedStream({required this.url, this.mimeType = ''});
}

/// Resolves a [WaveMusicTrack] to a temporary Media3-playable URL.
/// SoundCloud stream URLs expire and must not be persisted.
class WaveMusicPlaybackResolver {
  WaveMusicPlaybackResolver({SoundCloudApi? api}) : _api = api ?? SoundCloudApi.instance;

  static final WaveMusicPlaybackResolver instance = WaveMusicPlaybackResolver();

  final SoundCloudApi _api;
  final Map<String, _CachedStream> _streams = {};
    final Map<String, Future<WaveMusicTrack>> _inFlight = {};
    String? _nativeHandoffId;

    bool takeNativeHandoff(String id) {
      if (_nativeHandoffId != id) return false;
      _nativeHandoffId = null;
      return true;
    }

  Future<WaveMusicTrack> resolve(
    WaveMusicTrack track, {
    bool force = false,
    bool startPlayback = true,
  }) {
    if (track.provider == 'youtube') {
      debugPrintSynchronously('[WAVE_FUTURE] resolve() BEFORE youtube id=${track.id}');
      final future = _resolveYouTube(track, force: force, startPlayback: startPlayback);
      debugPrintSynchronously(
        '[WAVE_FUTURE] resolve() AFTER got future hash=${identityHashCode(future)} type=${future.runtimeType} id=${track.id}',
      );
      return future;
    }
    if (track.provider != 'soundcloud') {
      return Future.value(track);
    }
    if (!track.isPlayable) {
      return Future.value(track.copyWith(audioUrl: ''));
    }
    if (!force) {
      final cached = _streams[track.id];
      if (cached != null && cached.isFresh && cached.url.isNotEmpty) {
        return Future.value(track.copyWith(audioUrl: cached.url, mimeType: cached.mimeType));
      }
    } else {
      _streams.remove(track.id);
    }
    return _inFlight[track.id] ??= _resolveSoundCloud(track).whenComplete(() => _inFlight.remove(track.id));
  }

  Future<WaveMusicResolvedStream?> resolvePlaybackUrl(WaveMusicTrack track, {bool force = false}) async {
    final resolved = await resolve(track, force: force);
    final url = resolved.audioUrl.trim();
    if (url.isEmpty) return null;
    return WaveMusicResolvedStream(url: url, mimeType: resolved.mimeType);
  }

  Future<WaveMusicTrack> _resolveYouTube(
    WaveMusicTrack track, {
    required bool force,
    required bool startPlayback,
  }) {
    if (!force) {
      final cached = _streams[track.id];
      if (cached != null && cached.isFresh && cached.url.isNotEmpty) {
        return Future.value(
          track.copyWith(audioUrl: cached.url, mimeType: cached.mimeType, streamHeaders: cached.headers),
        );
      }
    } else {
      _streams.remove(track.id);
    }
    final existing = _inFlight[track.id];
    if (existing != null) {
      debugPrintSynchronously(
        '[WAVE_FUTURE] resolve reuse hash=${identityHashCode(existing)} id=${track.id}',
      );
      return existing;
    }
    debugPrintSynchronously('[WAVE_FUTURE] resolve BEFORE _fetchYouTube id=${track.id}');
    final fetchFuture = _fetchYouTube(track, startPlayback: startPlayback);
    debugPrintSynchronously(
      '[WAVE_FUTURE] resolve AFTER _fetchYouTube hash=${identityHashCode(fetchFuture)} type=${fetchFuture.runtimeType} id=${track.id}',
    );
    final wrapped = fetchFuture.whenComplete(() {
      _inFlight.remove(track.id);
      debugPrintSynchronously(
        '[WAVE_FUTURE] fetch AFTER whenComplete hash=${identityHashCode(fetchFuture)} id=${track.id}',
      );
    });
    wrapped.then((_) {
      debugPrintSynchronously(
        '[WAVE_FUTURE] resolve AFTER wrapped then hash=${identityHashCode(wrapped)} id=${track.id}',
      );
    });
    _inFlight[track.id] = wrapped;
    debugPrintSynchronously(
      '[WAVE_FUTURE] resolve wrapped hash=${identityHashCode(wrapped)} type=${wrapped.runtimeType} id=${track.id}',
    );
    return wrapped;
  }

  Future<WaveMusicTrack> _fetchYouTube(WaveMusicTrack track, {required bool startPlayback}) async {
    if (!kIsWeb && Platform.isIOS) {
      final resolved = await IosYoutubeMusic.resolveTrack(track);
      if (resolved.audioUrl.startsWith('http')) {
        _streams[track.id] = _CachedStream(resolved.audioUrl, resolved.mimeType, resolved.streamHeaders);
      }
      return resolved;
    }
    debugPrint('[WAVE_RESOLVER] resolve started id=${track.id} title=${track.title}');
    final url = track.permalinkUrl.trim();
    if (url.isEmpty) {
      debugPrint('[WAVE_RESOLVER] discarded empty permalink id=${track.id}');
      return track.copyWith(audioUrl: '');
    }
    const channel = MethodChannel('wave_music_player');
    final raw = await channel.invokeMethod<dynamic>('resolveAudioStream', {
      'url': url,
      'play': startPlayback,
    });
    debugPrintSynchronously(
      '[WAVE_RESOLVER] invoke continuation id=${track.id} raw=${raw == null ? 'null' : raw.runtimeType}',
    );
    debugPrintSynchronously('[WAVE_RESOLVER] before isMap id=${track.id}');
    if (raw is! Map) {
      debugPrintSynchronously('[WAVE_RESOLVER] raw not map id=${track.id}');
      return track.copyWith(audioUrl: '');
    }
    debugPrintSynchronously('[WAVE_RESOLVER] after isMap id=${track.id} keys=${raw.length}');
    debugPrintSynchronously('[WAVE_RESOLVER] before Map.from id=${track.id}');
    final map = Map<String, dynamic>.from(raw);
    debugPrintSynchronously('[WAVE_RESOLVER] after Map.from id=${track.id} keys=${map.length}');
    debugPrintSynchronously('[WAVE_RESOLVER] before streamUrl id=${track.id}');
    final streamUrl = map['streamUrl']?.toString() ?? '';
    debugPrintSynchronously(
      '[WAVE_RESOLVER] after streamUrl id=${track.id} len=${streamUrl.length} http=${streamUrl.startsWith('http')}',
    );
    debugPrintSynchronously('[WAVE_RESOLVER] before mime id=${track.id}');
    final mime = map['mimeType']?.toString() ?? '';
    debugPrintSynchronously('[WAVE_RESOLVER] after mime id=${track.id} mime=$mime');
    debugPrintSynchronously(
      '[WAVE_RESOLVER] before audioOnly id=${track.id} valueType=${map['isAudioOnly']?.runtimeType}',
    );
    final audioOnly = map['isAudioOnly'] == true;
    debugPrintSynchronously('[WAVE_RESOLVER] after audioOnly id=${track.id} audioOnly=$audioOnly');
    if (!streamUrl.startsWith('http') || !audioOnly) {
      debugPrintSynchronously('[WAVE_RESOLVER] rejected stream id=${track.id}');
      return track.copyWith(audioUrl: '');
    }
    debugPrintSynchronously('[WAVE_RESOLVER] before handoffId id=${track.id}');
    if (startPlayback && map['handedOff'] == true) {
      _nativeHandoffId = track.id;
    }
    debugPrintSynchronously('[WAVE_RESOLVER] after handoffId id=${track.id}');
    debugPrintSynchronously('[WAVE_RESOLVER] before headers id=${track.id}');
    final headers = <String, String>{};
    final rawHeaders = map['headers'];
    debugPrintSynchronously('[WAVE_RESOLVER] headers type id=${track.id} type=${rawHeaders?.runtimeType}');
    if (rawHeaders is Map) {
      rawHeaders.forEach((key, value) {
        headers[key.toString()] = value.toString();
      });
    }
    debugPrintSynchronously('[WAVE_RESOLVER] after headers id=${track.id} count=${headers.length}');
    debugPrintSynchronously('[WAVE_RESOLVER] before cache id=${track.id}');
    _streams[track.id] = _CachedStream(streamUrl, mime, headers);
    debugPrintSynchronously('[WAVE_RESOLVER] after cache id=${track.id} cacheSize=${_streams.length}');
    debugPrintSynchronously('[WAVE_RESOLVER] before copyWith id=${track.id}');
    final resolved = track.copyWith(audioUrl: streamUrl, mimeType: mime, streamHeaders: headers);
    debugPrintSynchronously('[WAVE_RESOLVER] after copyWith id=${track.id}');
    debugPrintSynchronously('[WAVE_FUTURE] fetch BEFORE return id=${track.id}');
    return resolved;
  }

  Future<WaveMusicTrack> _resolveSoundCloud(WaveMusicTrack track) async {
    try {
      final id = track.soundCloudId;
      if (id.isEmpty) return track.copyWith(audioUrl: '');
      final streams = await _api.trackStreams(id);
      final picked = _pickStream(streams);
      if (picked == null) {
        return track.copyWith(audioUrl: '');
      }
      final cdn = await _api.resolveCdnUrl(picked.url);
      _streams[track.id] = _CachedStream(cdn, picked.mimeType);
      if (_streams.length > 40) {
        final stale = _streams.keys.take(_streams.length - 24).toList();
        for (final key in stale) {
          _streams.remove(key);
        }
      }
      return track.copyWith(audioUrl: cdn, mimeType: picked.mimeType);
    } on HttpException catch (e) {
      if (e.statusCode == 403 || e.statusCode == 404) {
        return track.copyWith(audioUrl: '');
      }
      rethrow;
    }
  }

  _PickedStream? _pickStream(Map<String, dynamic> streams) {
    const preferred = [
      'hls_aac_160_url',
      'hls_aac_96_url',
    ];
    for (final key in preferred) {
      final url = streams[key]?.toString() ?? '';
      if (url.startsWith('http')) {
        return _PickedStream(url, 'application/x-mpegURL');
      }
    }
    for (final entry in streams.entries) {
      final key = entry.key.toString().toLowerCase();
      if (key.contains('preview')) continue;
      final url = entry.value?.toString() ?? '';
      if (!url.startsWith('http')) continue;
      final mime = url.contains('.m3u8') || key.contains('hls') ? 'application/x-mpegURL' : '';
      return _PickedStream(url, mime);
    }
    return null;
  }
}

class _CachedStream {
  final String url;
  final String mimeType;
  final Map<String, String> headers;
  final DateTime at;
  _CachedStream(this.url, this.mimeType, [this.headers = const {}]) : at = DateTime.now();
  bool get isFresh => DateTime.now().difference(at) < const Duration(minutes: 15);
}

class _PickedStream {
  final String url;
  final String mimeType;
  const _PickedStream(this.url, this.mimeType);
}
