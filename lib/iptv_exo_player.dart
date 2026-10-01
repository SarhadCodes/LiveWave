import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ios_live_player.dart';
import 'live_stream_config.dart';
import 'vod_player.dart';

/// FastTV-style native ExoPlayer → Flutter Texture bridge.
/// One texture, one ExoPlayer — reused across channel switches.
class IptvExoPlayerController implements VodPlayerHandle, LivePlayerHandle {
  IptvExoPlayerController();

  static const _channel = MethodChannel('iptv_exo_player');

  final ValueNotifier<int> _layoutTick = ValueNotifier(0);

  int? _textureId;
  StreamSubscription<dynamic>? _events;
  Completer<void>? _initCompleter;
  Completer<void>? _surfaceCompleter;

  List<String> _candidates = const [];
  int _candidateIndex = 0;
  Map<String, String>? _headers;

  int _aspectMode = 0;
  int _videoW = 0;
  int _videoH = 0;

  bool _hasSource = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _hasError = false;
  bool _hasFrame = false;
  bool _surfaceAttached = false;
  bool _disposed = false;

  Timer? _stallTimer;

  @override
  bool get isDisposed => _disposed;

  bool get hasActiveSource => _hasSource;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get hasError => _hasError;
  bool get hasVideoFrame => _hasFrame;
  bool get surfaceAttached => _surfaceAttached;
  @override
  bool get shouldShowLoading =>
      _textureId == null || (_hasSource && !_hasFrame && !_hasError);

  @override
  void Function(String event, Map<String, dynamic> data)? onEvent;

  /// Step 1–2: create native texture (SurfaceTextureEntry).
  @override
  Future<void> ensureInitialized() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_disposed) {
      throw StateError('IptvExoPlayerController was disposed');
    }
    if (_textureId != null) return;

    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    _surfaceCompleter = Completer<void>();

    try {
      final raw = await _channel.invokeMethod('create');
      final map = raw is Map ? Map<String, dynamic>.from(raw) : null;
      _textureId = ((map?['textureId'] ?? raw) as num).toInt();
      _surfaceAttached = false;

      debugPrint('[IptvExo] textureCreated id=$_textureId');

      _events = EventChannel('iptv_exo_player/events$_textureId')
          .receiveBroadcastStream()
          .listen(_onNativeEvent, onError: _onEventError);

      _initCompleter!.complete();
      _notifyLayout();
    } catch (e, st) {
      debugPrint('[IptvExo] init failed: $e\n$st');
      _initCompleter!.completeError(e, st);
      _initCompleter = null;
      rethrow;
    }
  }

  /// Ensure Flutter Texture is in the widget tree before playback starts.
  @override
  Future<void> mountTextureAndAttachSurface() async {
    if (kIsWeb || !Platform.isAndroid || _disposed) return;
    if (_surfaceAttached) return;

    _notifyLayout();
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    if (_disposed || _surfaceAttached) return;

    final raw = await _channel.invokeMethod('attachSurface');
    if (_disposed) return;
    if (raw is Map && raw['surfaceAttached'] == true) {
      _surfaceAttached = true;
      if (_surfaceCompleter != null && !_surfaceCompleter!.isCompleted) {
        _surfaceCompleter!.complete();
      }
      debugPrint('[IptvExo] attachSurface ok textureId=$_textureId');
    } else {
      debugPrint('[IptvExo] attachSurface failed textureId=$_textureId');
    }
  }

  /// Wait until native surface is attached to ExoPlayer.
  @override
  Future<void> waitForSurface({Duration timeout = const Duration(seconds: 10)}) {
    if (kIsWeb || !Platform.isAndroid || _surfaceAttached) return Future.value();
    _surfaceCompleter ??= Completer<void>();
    if (_surfaceCompleter!.isCompleted) return Future.value();
    return _surfaceCompleter!.future.timeout(timeout, onTimeout: () {
      debugPrint('[IptvExo] surface attach timeout');
    });
  }

  /// Live IPTV — HLS first, reuses ExoPlayer (no recreate).
  @override
  Future<void> setLiveChannel(String url, {Map<String, String>? headers}) async {
    if (kIsWeb || !Platform.isAndroid || _disposed) return;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    await ensureInitialized();
    if (_disposed) return;

    final isChannelSwitch = _hasSource && _surfaceAttached;
    if (!isChannelSwitch) {
      await mountTextureAndAttachSurface();
      if (_disposed) return;
    }

    _candidates = LiveStreamConfig.liveSourceCandidates(trimmed);
    _candidateIndex = 0;
    _headers = headers ?? LiveStreamConfig.headersFor(trimmed);
    _hasSource = true;
    _hasError = false;
    _hasFrame = false;
    _isPlaying = false;
    _isBuffering = true;
    _notifyLayout();

    await _playLiveCandidate();
  }

  Future<void> _playLiveCandidate() async {
    if (_textureId == null || _candidates.isEmpty) return;

    final url = _candidates[_candidateIndex];
    _headers ??= LiveStreamConfig.headersFor(url);

    debugPrint(
      '[IptvExo] setLiveSource candidate=${_candidateIndex + 1}/${_candidates.length} '
      'url=${_short(url)}',
    );

    await _channel.invokeMethod('setLiveSource', {
      'url': url,
      'headers': _headers,
    });
  }

  /// VOD — same ExoPlayer, different MediaSource factory on native side.
  @override
  Future<void> setVodSource(
    String url, {
    Map<String, String>? headers,
    String? subtitleUrl,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    await ensureInitialized();

    _hasSource = true;
    _hasError = false;
    _hasFrame = false;
    _notifyLayout();

    await _channel.invokeMethod('setVodSource', {
      'url': url,
      'headers': headers ?? LiveStreamConfig.headersFor(url),
      'subtitleUrl': subtitleUrl,
    });
  }

  @override
  Future<void> pause() async {
    await _channel.invokeMethod('pause');
  }

  @override
  Future<void> resume() async {
    await _channel.invokeMethod('resume');
  }

  @override
  Future<void> seekTo(int positionMs) async {
    await _channel.invokeMethod('seekTo', {'position': positionMs});
  }

  @override
  Future<Map<String, dynamic>> getPosition() async {
    final raw = await _channel.invokeMethod('getPosition');
    return Map<String, dynamic>.from(raw as Map);
  }

  /// Retry MediaSource / HTTP only — never recreates ExoPlayer.
  @override
  Future<void> retry() async {
    _hasError = false;
    _hasFrame = false;

    if (_candidateIndex + 1 < _candidates.length) {
      _candidateIndex++;
      debugPrint('[IptvExo] retry next candidate');
      await _playLiveCandidate();
      return;
    }

    _candidateIndex = 0;
    if (_candidates.isNotEmpty) {
      _headers = LiveStreamConfig.nextHeadersFor(_candidates.first);
    }
    debugPrint('[IptvExo] retry rotate user-agent');
    await _channel.invokeMethod('retry');
  }

  Future<void> recover() async {
    debugPrint('[IptvExo] recover media source');
    await _channel.invokeMethod('recover');
  }

  Future<void> recoverSurface() async {
    debugPrint('[IptvExo] recover surface');
    _surfaceAttached = false;
    _hasFrame = false;
    await _channel.invokeMethod('recoverSurface');
  }

  Future<void> _retryOrRecover() async {
    if (_candidateIndex + 1 < _candidates.length) {
      await retry();
      return;
    }
    await recover();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancelStallTimer();
    await _events?.cancel();
    _events = null;
    if (_textureId != null) {
      try {
        await _channel.invokeMethod('dispose');
      } catch (e) {
        debugPrint('[IptvExo] dispose error: $e');
      }
    }
    _textureId = null;
    _initCompleter = null;
    _surfaceCompleter = null;
    _surfaceAttached = false;
    _hasSource = false;
    _layoutTick.dispose();
  }

  @override
  void applyAspectRatio({required int modeIndex}) {
    if (_disposed) return;
    _aspectMode = modeIndex;
    _notifyLayout();
  }

  void _notifyLayout() {
    if (_disposed) return;
    _layoutTick.value++;
  }

  void _onEventError(Object error) {
    debugPrint('[IptvExo] event error: $error');
    _hasError = true;
    onEvent?.call('exception', {'error': error.toString()});
    _notifyLayout();
  }

  void _onNativeEvent(dynamic raw) {
    if (raw is! Map || _disposed) return;
    final data = Map<String, dynamic>.from(raw);
    final event = data['event']?.toString() ?? '';
    debugPrint('[IptvExo] $event');

    switch (event) {
      case 'textureCreated':
        break;
      case 'surfaceAttached':
        _surfaceAttached = true;
        if (_surfaceCompleter != null && !_surfaceCompleter!.isCompleted) {
          _surfaceCompleter!.complete();
        }
        break;
      case 'surfaceDestroyed':
        _surfaceAttached = false;
        break;
      case 'firstFrameRendered':
        _hasFrame = true;
        _hasError = false;
        _cancelStallTimer();
        break;
      case 'playing':
        _isPlaying = true;
        _isBuffering = false;
        _cancelStallTimer();
        break;
      case 'bufferingStart':
        _isBuffering = true;
        _armStallTimer();
        break;
      case 'stateChanged':
        final state = data['state']?.toString() ?? '';
        if (state == 'BUFFERING') _armStallTimer();
        if (state == 'READY' || state == 'ENDED') _cancelStallTimer();
        break;
      case 'stallDetected':
        unawaited(_retryOrRecover());
        break;
      case 'readyWithoutFrame':
        unawaited(recoverSurface());
        break;
      case 'videoSize':
        final w = data['width'];
        final h = data['height'];
        if (w is num && h is num && w > 0 && h > 0) {
          _videoW = w.round();
          _videoH = h.round();
          _hasFrame = true;
        }
        break;
      case 'exception':
        _hasError = true;
        _isBuffering = false;
        break;
    }

    onEvent?.call(event, data);
    _notifyLayout();
  }

  void _armStallTimer() {
    _stallTimer?.cancel();
    _stallTimer = Timer(const Duration(seconds: 30), () {
      debugPrint('[IptvExo] stall watchdog — recover');
      unawaited(recover());
    });
  }

  void _cancelStallTimer() {
    _stallTimer?.cancel();
    _stallTimer = null;
  }

  /// Texture widget — stable key, never replaced during playback.
  @override
  Widget buildView() {
    if (kIsWeb || !Platform.isAndroid) {
      return const ColoredBox(color: Colors.black);
    }

    return ValueListenableBuilder<int>(
      valueListenable: _layoutTick,
      builder: (context, _, __) {
        final id = _textureId;
        if (id == null) {
          return const ColoredBox(color: Colors.black);
        }
        return ColoredBox(
          color: Colors.black,
          child: _wrapAspect(
            Texture(
              key: ValueKey<int>(id),
              textureId: id,
              filterQuality: FilterQuality.medium,
            ),
          ),
        );
      },
    );
  }

  /// Texture has no intrinsic size — always derive finite frame dimensions
  /// before any FittedBox or expand layout.
  Size _videoFrameSize(double maxW, double maxH) {
    if (_videoW > 0 && _videoH > 0) {
      return Size(_videoW.toDouble(), _videoH.toDouble());
    }
    const fallbackAspect = 16 / 9;
    if (maxW.isFinite && maxH.isFinite && maxW > 0 && maxH > 0) {
      if (maxW / maxH > fallbackAspect) {
        return Size(maxH * fallbackAspect, maxH);
      }
      return Size(maxW, maxW / fallbackAspect);
    }
    return const Size(1920, 1080);
  }

  double _targetAspect() {
    switch (_aspectMode) {
      case 1:
        return 16 / 9;
      case 2:
        return 4 / 3;
      default:
        if (_videoW > 0 && _videoH > 0) {
          return _videoW / _videoH;
        }
        return 16 / 9;
    }
  }

  Widget _wrapAspect(Widget video) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        if (!maxW.isFinite || !maxH.isFinite || maxW <= 0 || maxH <= 0) {
          final frame = _videoFrameSize(1920, 1080);
          return Center(
            child: SizedBox(
              width: frame.width,
              height: frame.height,
              child: video,
            ),
          );
        }

        // Stretch — fill the view; Texture expands to parent bounds.
        if (_aspectMode == 3) {
          return SizedBox(width: maxW, height: maxH, child: video);
        }

        // Zoom — cover crop; FittedBox child must have finite dimensions.
        if (_aspectMode == 4) {
          final frame = _videoFrameSize(maxW, maxH);
          return SizedBox(
            width: maxW,
            height: maxH,
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: frame.width,
                  height: frame.height,
                  child: video,
                ),
              ),
            ),
          );
        }

        final aspect = _targetAspect();
        final boxW = maxW / maxH > aspect ? maxH * aspect : maxW;
        final boxH = maxW / maxH > aspect ? maxH : maxW / aspect;

        return Center(
          child: SizedBox(width: boxW, height: boxH, child: video),
        );
      },
    );
  }

  static String _short(String url) =>
      url.length <= 80 ? url : '${url.substring(0, 40)}...';
}

/// Alias for live player screen compatibility.
typedef LiveExoPlayerController = IptvExoPlayerController;
