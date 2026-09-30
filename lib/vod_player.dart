import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Playback surface used by the movie and series player.
/// Android keeps ExoPlayer. iOS uses AVPlayer through video_player.
abstract class VodPlayerHandle {
  void Function(String event, Map<String, dynamic> data)? get onEvent;
  set onEvent(void Function(String event, Map<String, dynamic> data)? value);

  Future<void> ensureInitialized();
  Future<void> mountTextureAndAttachSurface();
  Future<void> setVodSource(
    String url, {
    Map<String, String>? headers,
    String? subtitleUrl,
  });
  void applyAspectRatio({required int modeIndex});
  Future<Map<String, dynamic>> getPosition();
  Future<void> seekTo(int positionMs);
  Future<void> pause();
  Future<void> resume();
  Future<void> dispose();
  Widget buildView();
}

class IosVodPlayerController implements VodPlayerHandle {
  VideoPlayerController? _controller;
  int _aspectMode = 0;
  bool _disposed = false;
  bool _reportedError = false;

  @override
  void Function(String event, Map<String, dynamic> data)? onEvent;

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<void> mountTextureAndAttachSurface() async {}

  @override
  Future<void> setVodSource(
    String url, {
    Map<String, String>? headers,
    String? subtitleUrl,
  }) async {
    if (_disposed) return;
    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: headers ?? const {'User-Agent': 'Mozilla/5.0'},
    );
    _controller = controller;
    controller.addListener(_onTick);
    await controller.initialize();
    if (_disposed) return;
    await controller.play();
    onEvent?.call('firstFrameRendered', const {});
    onEvent?.call('playing', const {});
  }

  void _onTick() {
    final value = _controller?.value;
    if (value == null || !value.hasError || _reportedError) return;
    _reportedError = true;
    onEvent?.call('exception', {'error': value.errorDescription ?? 'playback failed'});
  }

  @override
  void applyAspectRatio({required int modeIndex}) {
    _aspectMode = modeIndex;
  }

  @override
  Future<Map<String, dynamic>> getPosition() async {
    final value = _controller?.value;
    return {
      'position': value?.position.inMilliseconds ?? 0,
      'duration': value?.duration.inMilliseconds ?? 0,
      'isPlaying': value?.isPlaying ?? false,
    };
  }

  @override
  Future<void> seekTo(int positionMs) async {
    await _controller?.seekTo(Duration(milliseconds: positionMs));
  }

  @override
  Future<void> pause() async {
    await _controller?.pause();
  }

  @override
  Future<void> resume() async {
    await _controller?.play();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
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
        return Transform.scale(scale: 1.2, child: Center(child: FittedBox(fit: BoxFit.contain, child: video)));
      default:
        return Center(child: FittedBox(fit: BoxFit.contain, child: video));
    }
  }
}
