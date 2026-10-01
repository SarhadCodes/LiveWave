import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'live_stream_config.dart';

/// Surface used by the live channel screen.
/// Android keeps ExoPlayer. iOS uses AVPlayer through video_player.
abstract class LivePlayerHandle {
  void Function(String event, Map<String, dynamic> data)? get onEvent;
  set onEvent(void Function(String event, Map<String, dynamic> data)? value);

  bool get isDisposed;
  bool get shouldShowLoading;

  Future<void> ensureInitialized();
  Future<void> mountTextureAndAttachSurface();
  Future<void> waitForSurface({Duration timeout = const Duration(seconds: 10)});
  Future<void> setLiveChannel(String url, {Map<String, String>? headers});
  Future<void> retry();
  void applyAspectRatio({required int modeIndex});
  Future<void> dispose();
  Widget buildView();
}

/// iOS live playback. The controller instance is owned by the player route
/// and is not recreated when the phone rotates.
class IosLivePlayerController implements LivePlayerHandle {
  VideoPlayerController? _controller;
  List<String> _candidates = const [];
  int _candidateIndex = 0;
  Map<String, String>? _headers;
  int _aspectMode = 0;
  int _openGeneration = 0;
  bool _ready = false;
  bool _failed = false;
  bool _disposed = false;

  @override
  void Function(String event, Map<String, dynamic> data)? onEvent;

  @override
  bool get isDisposed => _disposed;

  @override
  bool get shouldShowLoading => !_ready && !_failed;

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<void> mountTextureAndAttachSurface() async {}

  @override
  Future<void> waitForSurface({Duration timeout = const Duration(seconds: 10)}) async {}

  @override
  Future<void> setLiveChannel(String url, {Map<String, String>? headers}) async {
    if (_disposed) return;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    _candidates = LiveStreamConfig.liveSourceCandidates(trimmed);
    _candidateIndex = 0;
    _headers = headers ?? LiveStreamConfig.headersFor(trimmed);
    _ready = false;
    _failed = false;
    await _openCurrent();
  }

  @override
  Future<void> retry() async {
    if (_disposed || _candidates.isEmpty) return;
    if (_candidateIndex + 1 < _candidates.length) {
      _candidateIndex++;
    } else {
      _candidateIndex = 0;
      final current = _candidates[_candidateIndex];
      _headers = LiveStreamConfig.nextHeadersFor(current);
    }
    _ready = false;
    _failed = false;
    await _openCurrent();
  }

  Future<void> _openCurrent() async {
    if (_disposed || _candidates.isEmpty) return;
    final generation = ++_openGeneration;
    final url = _candidates[_candidateIndex];
    final previous = _controller;
    _controller = null;
    previous?.removeListener(_onTick);
    await previous?.dispose();
    if (_disposed || generation != _openGeneration) return;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: _headers ?? LiveStreamConfig.headersFor(url),
    );
    _controller = controller;
    controller.addListener(_onTick);
    try {
      await controller.initialize();
      if (_disposed || generation != _openGeneration) return;
      await controller.play();
      if (_disposed || generation != _openGeneration) return;
      _ready = true;
      _failed = false;
      onEvent?.call('firstFrameRendered', const {});
      onEvent?.call('playing', const {});
    } catch (e) {
      if (_disposed || generation != _openGeneration) return;
      if (_candidateIndex + 1 < _candidates.length) {
        _candidateIndex++;
        await _openCurrent();
        return;
      }
      _failed = true;
      _ready = false;
      onEvent?.call('exception', {'error': e.toString()});
    }
  }

  void _onTick() {
    final value = _controller?.value;
    if (value == null || !value.hasError || _failed) return;
    _failed = true;
    _ready = false;
    onEvent?.call('exception', {'error': value.errorDescription ?? 'playback failed'});
  }

  @override
  void applyAspectRatio({required int modeIndex}) {
    _aspectMode = modeIndex;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _openGeneration++;
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onTick);
    await controller?.dispose();
  }

  @override
  Widget buildView() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    final size = controller.value.size;
    final width = size.width <= 0 ? 16.0 : size.width;
    final height = size.height <= 0 ? 9.0 : size.height;
    Widget video = SizedBox(
      width: width,
      height: height,
      child: VideoPlayer(controller),
    );
    switch (_aspectMode) {
      case 3:
        return SizedBox.expand(child: FittedBox(fit: BoxFit.fill, child: video));
      case 4:
        return SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: video));
      default:
        return Center(child: FittedBox(fit: BoxFit.contain, child: video));
    }
  }
}
