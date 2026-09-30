import 'wave_video.dart';

/// Public livestream metadata. [state] is never guessed from title text.
class WaveLiveEvent {
  final WaveVideo video;
  final WaveLiveState state;

  const WaveLiveEvent({
    required this.video,
    required this.state,
  });

  bool get isLive => state == WaveLiveState.live;
}
