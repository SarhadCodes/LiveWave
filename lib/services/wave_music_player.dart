import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/wave_music_track.dart';

enum WaveMusicRepeatMode { off, all, one }

/// Native Media3 music engine bridge. Position updates use [position] / [duration]
/// ValueNotifiers so the rest of the tree does not rebuild every tick.
class WaveMusicPlayer {
  WaveMusicPlayer._();
  static final WaveMusicPlayer instance = WaveMusicPlayer._();

  static const _channel = MethodChannel('wave_music_player');
  static const _events = EventChannel('wave_music_player/events');

  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> playing = ValueNotifier(false);
  final ValueNotifier<bool> buffering = ValueNotifier(false);
  final ValueNotifier<int> queueIndex = ValueNotifier(0);
  final ValueNotifier<String?> error = ValueNotifier(null);

  StreamSubscription<dynamic>? _sub;
  bool _bound = false;
  bool shuffle = false;
  WaveMusicRepeatMode repeat = WaveMusicRepeatMode.off;
  VoidCallback? onTrackEnded;
  VoidCallback? onSkipToNext;
  VoidCallback? onSkipToPrevious;
  void Function(int index)? onMediaIndex;
  void Function(String message)? onPlaybackError;
  String? currentMediaId;

  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isIos => !kIsWeb && Platform.isIOS;
  bool get _hasEngine => isAndroid || isIos;

  Future<void> bind() async {
    if (_bound) return;
    _bound = true;
    if (!_hasEngine) return;
    _sub = _events.receiveBroadcastStream().listen(_onEvent, onError: (_) {});
    try {
      await _channel.invokeMethod('warmUp');
    } catch (_) {}
  }

  Future<void> setQueue(List<WaveMusicTrack> tracks, {int startIndex = 0, bool play = true}) async {
    error.value = null;
    if (!_hasEngine) {
      error.value = 'Music playback is not available on this device.';
      return;
    }
    if (tracks.isEmpty) return;
    final safeIndex = startIndex.clamp(0, tracks.length - 1);
    queueIndex.value = safeIndex;
    final source = tracks[safeIndex];
    final host = Uri.tryParse(source.audioUrl)?.host ?? '';
    debugPrint(
      '[WAVE_PLAYER] set source called id=${source.id} title=${source.title} mime=${source.mimeType} '
      'streamHost=$host urlEmpty=${source.audioUrl.trim().isEmpty} count=${tracks.length}',
    );
    try {
      await _channel.invokeMethod('setQueue', {
        'items': tracks.map((t) => t.toNativeMap()).toList(),
        'startIndex': safeIndex,
        'play': play,
        'shuffle': shuffle,
        'repeat': repeat.name,
      });
      if (isIos) {
        debugPrint('[WAVE_IOS_MUSIC] setQueue accepted id=${source.id} title=${source.title}');
      }
    } catch (e) {
      if (isIos && e is PlatformException && e.code == 'replaced') {
        return;
      }
      if (isIos) {
        debugPrint('[WAVE_IOS_MUSIC] setQueue rejected id=${source.id} title=${source.title} error=$e');
      }
      error.value = e.toString();
      onPlaybackError?.call(e.toString());
    }
  }

  Future<void> play() async {
    if (!_hasEngine) return;
    await _channel.invokeMethod('play');
  }

  Future<void> pause() async {
    if (!_hasEngine) return;
    await _channel.invokeMethod('pause');
  }

  Future<void> toggle() async {
    if (playing.value) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> next() async {
    if (!_hasEngine) return;
    await _channel.invokeMethod('next');
  }

  Future<void> previous() async {
    if (!_hasEngine) return;
    await _channel.invokeMethod('previous');
  }

  Future<void> seek(Duration to) async {
    if (!_hasEngine) return;
    await _channel.invokeMethod('seek', {'positionMs': to.inMilliseconds});
  }

  Future<void> setShuffle(bool enabled) async {
    shuffle = enabled;
    if (!_hasEngine) return;
    await _channel.invokeMethod('setShuffle', {'enabled': enabled});
  }

  Future<void> setRepeat(WaveMusicRepeatMode mode) async {
    repeat = mode;
    if (!_hasEngine) return;
    await _channel.invokeMethod('setRepeat', {'mode': mode.name});
  }

  Future<void> setVolume(double volume) async {
    if (!_hasEngine) return;
    await _channel.invokeMethod('setVolume', {'volume': volume.clamp(0.0, 1.0)});
  }

  Future<void> stop() async {
    if (!_hasEngine) return;
    await _channel.invokeMethod('stop');
    playing.value = false;
    position.value = Duration.zero;
  }

  void _onEvent(dynamic raw) {
    if (raw is! Map) return;
    final map = Map<String, dynamic>.from(raw);
    final type = map['type']?.toString() ?? '';
    switch (type) {
      case 'position':
        position.value = Duration(milliseconds: (map['positionMs'] as num?)?.toInt() ?? 0);
        duration.value = Duration(milliseconds: (map['durationMs'] as num?)?.toInt() ?? 0);
        break;
      case 'playing':
        playing.value = map['playing'] == true;
        buffering.value = false;
        break;
      case 'buffering':
        buffering.value = true;
        break;
      case 'paused':
        playing.value = false;
        buffering.value = false;
        break;
      case 'index':
        final index = (map['index'] as num?)?.toInt() ?? 0;
        queueIndex.value = index;
        currentMediaId = map['id']?.toString();
        onMediaIndex?.call(index);
        break;
      case 'ended':
        playing.value = false;
        onTrackEnded?.call();
        break;
      case 'skipNext':
        debugPrintSynchronously('[WAVE_PLAY] skipNext event');
        onSkipToNext?.call();
        break;
      case 'skipPrevious':
        onSkipToPrevious?.call();
        break;
      case 'error':
        buffering.value = false;
        playing.value = false;
        final message = map['message']?.toString() ?? 'Playback failed';
        error.value = message;
        onPlaybackError?.call(message);
        break;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _bound = false;
  }
}
