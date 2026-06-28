import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import '../config/app_theme.dart';

class NativePlayerScreen extends StatefulWidget {
  final String url;
  final String title;

  const NativePlayerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<NativePlayerScreen> createState() => _NativePlayerScreenState();
}

class _NativePlayerScreenState extends State<NativePlayerScreen> {
  late BetterPlayerController _betterPlayerController;

  bool _showControls = true;
  Timer? _hideTimer;
  bool _isPlaying = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final bool isHls = widget.url.contains('.m3u8');

    final configuration = BetterPlayerConfiguration(
      autoPlay: true,
      fit: BoxFit.contain,
      controlsConfiguration: const BetterPlayerControlsConfiguration(
        showControls: false,
      ),
      autoDetectFullscreenDeviceOrientation: true,
      handleLifecycle: true,
      autoDetectFullscreenAspectRatio: true,
    );

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      widget.url,
      videoFormat: isHls ? BetterPlayerVideoFormat.hls : BetterPlayerVideoFormat.other,
      liveStream: true,
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 3000,
        maxBufferMs: 15000,
        bufferForPlaybackMs: 1500,
        bufferForPlaybackAfterRebufferMs: 3000,
      ),
    );

    _betterPlayerController = BetterPlayerController(configuration);
    _betterPlayerController.setupDataSource(dataSource);
    
    _betterPlayerController.addEventsListener((event) {
      if (!mounted) return;
      
      if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
        final videoDuration = _betterPlayerController.videoPlayerController?.value.duration;
        if (videoDuration != null) {
          setState(() => _duration = videoDuration);
        }
        setState(() => _isPlaying = true);
      }
      
      if (event.betterPlayerEventType == BetterPlayerEventType.play) {
        setState(() => _isPlaying = true);
      }
      if (event.betterPlayerEventType == BetterPlayerEventType.pause) {
        setState(() => _isPlaying = false);
      }
      if (event.betterPlayerEventType == BetterPlayerEventType.progress) {
        final pos = event.parameters?['progress'] as Duration?;
        final dur = event.parameters?['duration'] as Duration?;
        if (pos != null) setState(() => _position = pos);
        if (dur != null && dur > Duration.zero) setState(() => _duration = dur);
      }
    });

    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _hideTimer?.cancel();
    _betterPlayerController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        // Show overlay on any key press
        if (!_showControls) {
          _toggleControls();
          return KeyEventResult.handled;
        }
        _startHideTimer();

        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          _isPlaying ? _betterPlayerController.pause() : _betterPlayerController.play();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          final newPos = _position - const Duration(seconds: 10);
          _betterPlayerController.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _betterPlayerController.seekTo(_position + const Duration(seconds: 10));
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.escape ||
                   event.logicalKey == LogicalKeyboardKey.backspace) {
          Navigator.pop(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: BetterPlayer(controller: _betterPlayerController),
              ),
            ),
            GestureDetector(
              onTap: _toggleControls,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
            _buildControlsOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _showControls ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !_showControls,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
              stops: const [0.0, 0.2, 0.8, 1.0],
            ),
          ),
          child: Column(
            children: [
              _buildTopBar(),
              const Spacer(),
              _buildCenterControls(),
              const Spacer(),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          _buildFocusableGlassButton(
            icon: Icons.arrow_back,
            size: 32,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildFocusablePlayerButton(
          icon: Icons.replay_10,
          size: 64,
          onTap: () {
            final newPos = _position - const Duration(seconds: 10);
            _betterPlayerController.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
          },
        ),
        const SizedBox(width: 48),
        _buildPlayPauseButton(),
        const SizedBox(width: 48),
        _buildFocusablePlayerButton(
          icon: Icons.forward_10,
          size: 64,
          onTap: () => _betterPlayerController.seekTo(_position + const Duration(seconds: 10)),
        ),
      ],
    );
  }

  Widget _buildPlayPauseButton() {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select)) {
          _isPlaying ? _betterPlayerController.pause() : _betterPlayerController.play();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: () => _isPlaying ? _betterPlayerController.pause() : _betterPlayerController.play(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isFocused ? 96 : 84,
              height: isFocused ? 96 : 84,
              decoration: BoxDecoration(
                color: isFocused ? AppTheme.primaryColor.withOpacity(0.2) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isFocused ? Colors.white : Colors.transparent,
                  width: 3,
                ),
                boxShadow: isFocused
                    ? [BoxShadow(color: Colors.white.withOpacity(0.15), blurRadius: 20, spreadRadius: 4)]
                    : [],
              ),
              child: Icon(
                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: Colors.white,
                size: isFocused ? 90 : 84,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: AppTheme.primaryColor,
              inactiveTrackColor: Colors.white24,
              thumbColor: AppTheme.primaryColor,
            ),
            child: Slider(
              value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble().clamp(0.1, double.infinity)),
              max: _duration.inSeconds.toDouble().clamp(0.1, double.infinity),
              onChanged: (val) => _betterPlayerController.seekTo(Duration(seconds: val.toInt())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${_formatDuration(_position)} / ${_formatDuration(_duration)}",
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const Icon(Icons.settings, color: Colors.white70, size: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Focusable glass icon button (back button, etc.)
  Widget _buildFocusableGlassButton({required IconData icon, required double size, required VoidCallback onTap}) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select)) {
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isFocused ? Colors.white.withOpacity(0.2) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isFocused ? Colors.white : Colors.transparent,
                  width: 2,
                ),
                boxShadow: isFocused
                    ? [BoxShadow(color: Colors.white.withOpacity(0.15), blurRadius: 12, spreadRadius: 2)]
                    : [],
              ),
              child: Icon(icon, color: Colors.white, size: isFocused ? size + 4 : size),
            ),
          );
        },
      ),
    );
  }

  /// Focusable player control button (seek forward/back)
  Widget _buildFocusablePlayerButton({required IconData icon, required double size, required VoidCallback onTap}) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select)) {
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(isFocused ? 8 : 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFocused ? Colors.white.withOpacity(0.15) : Colors.transparent,
                border: Border.all(
                  color: isFocused ? Colors.white.withOpacity(0.5) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: isFocused ? size + 8 : size,
              ),
            ),
          );
        },
      ),
    );
  }
}
