import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/wave_creator.dart';
import '../models/wave_video.dart';
import '../providers/settings_provider.dart';
import '../providers/wave_library_provider.dart';
import '../providers/wave_provider.dart';
import '../services/wave_pip.dart';
import '../services/wave_youtube_parser.dart';
import '../widgets/media_row.dart';
import '../widgets/wave_skeleton.dart';
import '../widgets/wave_video_card.dart';
import 'wave_creator_screen.dart';

class WaveWatchScreen extends StatefulWidget {
  final WaveVideo video;

  const WaveWatchScreen({super.key, required this.video});

  @override
  State<WaveWatchScreen> createState() => _WaveWatchScreenState();
}

class _WaveWatchScreenState extends State<WaveWatchScreen>
    with WidgetsBindingObserver {
  YoutubePlayerController? _controller;
  WaveVideo? _video;
  WaveCreator? _creator;
  List<WaveVideo> _moreFromCreator = [];
  List<WaveVideo> _related = [];
  String? _error;
  bool _loadingExtras = true;
  bool _descriptionExpanded = false;
  bool _inPip = false;
  bool _inFullscreen = false;
  bool _isMobileLayout = true;
  Timer? _progressTimer;
  Timer? _pipResumeTimer;
  Timer? _orientationUnlockTimer;
  Timer? _playKickTimer;
  StreamSubscription<YoutubePlayerValue>? _playerSub;
  PlayerState _playerState = PlayerState.unknown;
  final _playerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _video = widget.video;
    WidgetsBinding.instance.addObserver(this);
    WavePip.bind();
    WavePip.onChanged = _onPipChanged;
    WidgetsBinding.instance.addPostFrameCallback((_) => _setup());
  }

  Future<void> _setup() async {
    final wave = context.read<WaveProvider>();
    final library = context.read<WaveLibraryProvider>();
    try {
      final hydrated = await wave.hydrateVideo(widget.video);
      if (!mounted) return;
      if (hydrated == null) {
        setState(() => _error = AppLocalizations.of(context).translate('wave_video_unavailable'));
        return;
      }
      if (!hydrated.embeddable) {
        setState(() => _error = AppLocalizations.of(context).translate('wave_embedding_disabled'));
        return;
      }
      _video = hydrated;
      await library.recordWatch(video: hydrated);
      _createPlayer(hydrated, library.progressFor(hydrated.videoId)?.positionSeconds);
      setState(() {});
      _isMobileLayout =
          context.read<SettingsProvider>().layoutMode == 'mobile';
      if (_isMobileLayout) {
        await WavePip.setEnabled(true);
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
      await WakelockPlus.enable();
      _loadExtras(wave, hydrated);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context).translate('wave_video_unavailable'));
    }
  }

  void _createPlayer(WaveVideo video, int? startSeconds) {
    const origin = 'https://www.youtube-nocookie.com';
    final params = const YoutubePlayerParams(
      mute: false,
      showControls: true,
      showFullscreenButton: false,
      playsInline: true,
      privacyEnhancedMode: true,
      strictRelatedVideos: false,
      origin: origin,
    );
    final start = startSeconds != null && startSeconds >= 8 ? startSeconds : 0;
    _controller = YoutubePlayerController.fromVideoId(
      videoId: video.videoId,
      autoPlay: true,
      params: params,
      startSeconds: start.toDouble(),
    );
    _playerSub = _controller!.stream.listen((value) {
      if (!mounted) return;
      if (value.playerState != _playerState) {
        setState(() => _playerState = value.playerState);
      }
      if (value.playerState == PlayerState.playing ||
          value.playerState == PlayerState.buffering) {
        _playKickTimer?.cancel();
      }
      if (!value.hasError || value.error == YoutubeError.none) return;
      // Layout / WebView glitches are not embed blocks. Keep the player up.
      if (value.error == YoutubeError.html5Error ||
          value.error == YoutubeError.unknown) {
        _controller?.playVideo();
        return;
      }
      _playKickTimer?.cancel();
      final embeddingBlocked = value.error == YoutubeError.notEmbeddable ||
          value.error == YoutubeError.sameAsNotEmbeddable ||
          value.error == YoutubeError.sameAsNotEmbeddable2;
      setState(() {
        _error = embeddingBlocked
            ? AppLocalizations.of(context).translate('wave_embedding_disabled')
            : AppLocalizations.of(context).translate('wave_video_unavailable');
      });
      WavePip.setEnabled(false);
      WakelockPlus.disable();
    });
    _progressTimer = Timer.periodic(const Duration(seconds: 8), (_) => _saveProgress());
    _kickPlayback();
  }

  void _kickPlayback() {
    _playKickTimer?.cancel();
    _playKickTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted || _controller == null || timer.tick > 12) {
        timer.cancel();
        return;
      }
      final state = _controller!.value.playerState;
      if (state == PlayerState.playing || state == PlayerState.buffering) {
        timer.cancel();
        return;
      }
      _controller!.playVideo();
    });
  }

  bool get _isPlaying =>
      _playerState == PlayerState.playing || _playerState == PlayerState.buffering;

  void _togglePlay() {
    if (_controller == null) return;
    if (_isPlaying) {
      _controller!.pauseVideo();
    } else {
      _controller!.playVideo();
    }
  }

  void _setFullscreen(bool enabled) {
    _orientationUnlockTimer?.cancel();
    if (!mounted || _inPip || _inFullscreen == enabled) return;
    setState(() => _inFullscreen = enabled);

    if (!_isMobileLayout) {
      SystemChrome.setEnabledSystemUIMode(
        enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
      _controller?.playVideo();
      return;
    }

    if (enabled) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _orientationUnlockTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted || _inFullscreen || _inPip) return;
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      });
    }
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _controller?.playVideo();
    });
  }

  @override
  void didChangeMetrics() {
    if (!mounted || !_isMobileLayout || _inPip) return;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final size = views.first.physicalSize / views.first.devicePixelRatio;
    final landscape = size.width > size.height + 24;
    if (landscape && !_inFullscreen) {
      _setFullscreen(true);
    } else if (!landscape && _inFullscreen) {
      _setFullscreen(false);
    }
  }

  void _restoreChrome() {
    if (_isMobileLayout) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _onPipChanged(bool inPip) {
    if (!mounted) return;
    _pipResumeTimer?.cancel();
    setState(() {
      _inPip = inPip;
      if (inPip) _inFullscreen = false;
    });
    if (inPip) {
      if (_controller?.value.fullScreenOption.enabled == true) {
        _controller?.exitFullScreen();
      }
      _keepPlayingInPip();
    }
  }

  void _keepPlayingInPip() {
    _controller?.playVideo();
    _pipResumeTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted || !_inPip || timer.tick > 6) {
        timer.cancel();
        return;
      }
      _controller?.playVideo();
    });
  }

  Future<void> _loadExtras(WaveProvider wave, WaveVideo video) async {
    try {
      final creator = await wave.loadCreator(video.channelId);
      final more = await wave.moreFromCreator(video.channelId, excludeVideoId: video.videoId);
      List<WaveVideo> related = const [];
      try {
        related = await wave.relatedVideos(video);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _creator = creator;
        _moreFromCreator = more;
        _related = related;
        _loadingExtras = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingExtras = false);
    }
  }

  Future<void> _saveProgress() async {
    final controller = _controller;
    final video = _video;
    if (controller == null || video == null || !mounted || video.isLive) return;
    try {
      final position = await controller.currentTime;
      final duration = await controller.duration;
      if (!mounted) return;
      await context.read<WaveLibraryProvider>().recordProgress(
            video: video,
            positionSeconds: position.round(),
            durationSeconds: duration.round(),
          );
    } catch (_) {
      // IFrame position is optional; history still records the watch.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (identical(WavePip.onChanged, _onPipChanged)) {
      WavePip.onChanged = null;
    }
    WavePip.setEnabled(false);
    _orientationUnlockTimer?.cancel();
    _playKickTimer?.cancel();
    _pipResumeTimer?.cancel();
    _progressTimer?.cancel();
    _playerSub?.cancel();
    _controller?.close();
    WakelockPlus.disable();
    _restoreChrome();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isMobile =
        Provider.of<SettingsProvider>(context).layoutMode == 'mobile';
    final video = _video ?? widget.video;
    final library = context.watch<WaveLibraryProvider>();
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final fillPlayer = _inPip || _inFullscreen || (isMobile && isLandscape);

    if (isMobile && isLandscape && !_inFullscreen && !_inPip) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_inPip) _setFullscreen(true);
      });
    }

    return PopScope(
      canPop: !_inFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _inFullscreen) _setFullscreen(false);
      },
      child: Scaffold(
        backgroundColor: fillPlayer ? Colors.black : AppTheme.backgroundColor,
        appBar: fillPlayer
            ? null
            : AppBar(
                backgroundColor: AppTheme.backgroundColor,
                title: Text(
                  l10n.translate('wave'),
                  style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
                ),
              ),
        body: _error != null
            ? WaveErrorBody(
                message: _error!,
                onRetry: () {
                  _playKickTimer?.cancel();
                  _playerSub?.cancel();
                  _controller?.close();
                  _controller = null;
                  setState(() => _error = null);
                  _setup();
                },
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: [
                      _playerPane(
                        l10n,
                        fill: fillPlayer,
                        maxWidth: constraints.maxWidth,
                        maxHeight: constraints.maxHeight,
                      ),
                      if (!fillPlayer)
                        Expanded(
                        child: ListView(
                          padding: EdgeInsets.only(bottom: isMobile ? 32 : 48),
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                isMobile ? 16 : 32,
                                16,
                                isMobile ? 16 : 32,
                                8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    video.title,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _creatorRow(l10n, library, video),
                                  const SizedBox(height: 8),
                                  Text(
                                    [
                                      if (video.viewCount != null)
                                        '${WaveYoutubeParser.formatViewCount(video.viewCount)} views',
                                      WaveYoutubeParser.relativePublishedLabel(video.publishedAt),
                                    ].where((part) => part.isNotEmpty).join('  •  '),
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _actions(l10n, library, video),
                                  if ((video.description ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    Text(
                                      l10n.translate('overview'),
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () => setState(
                                        () => _descriptionExpanded = !_descriptionExpanded,
                                      ),
                                      child: Text(
                                        video.description!.trim(),
                                        maxLines: _descriptionExpanded ? 40 : 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (_loadingExtras)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: WaveSkeletonBox(height: 160),
                              )
                            else ...[
                              if (_moreFromCreator.isNotEmpty)
                                MediaRow(
                                  title: l10n.translate('wave_more_from_creator').toUpperCase(),
                                  itemCount: _moreFromCreator.length,
                                  customWidth: isMobile ? 220 : 260,
                                  customHeight: isMobile ? 228 : 258,
                                  itemBuilder: (context, index) {
                                    final item = _moreFromCreator[index];
                                    return WaveVideoCard(
                                      video: item,
                                      onTap: () => Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => WaveWatchScreen(video: item),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              if (_related.isNotEmpty)
                                MediaRow(
                                  title: l10n.translate('wave_more_to_watch').toUpperCase(),
                                  itemCount: _related.length,
                                  customWidth: isMobile ? 220 : 260,
                                  customHeight: isMobile ? 228 : 258,
                                  itemBuilder: (context, index) {
                                    final item = _related[index];
                                    return WaveVideoCard(
                                      video: item,
                                      onTap: () => Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => WaveWatchScreen(video: item),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _playerPane(
    AppLocalizations l10n, {
    required bool fill,
    required double maxWidth,
    required double maxHeight,
  }) {
    if (maxWidth <= 0 || maxHeight <= 0) {
      return const ColoredBox(color: Colors.black);
    }
    var videoW = maxWidth;
    var videoH = maxWidth * 9 / 16;
    if (fill && videoH > maxHeight && maxHeight > 0) {
      videoH = maxHeight;
      videoW = maxHeight * 16 / 9;
    }
    if (!fill) {
      videoW = maxWidth;
      videoH = maxWidth * 9 / 16;
    }

    final paneHeight = fill ? maxHeight : videoH + 48;
    final videoLeft = fill ? (maxWidth - videoW) / 2 : 0.0;
    final videoTop = fill ? (maxHeight - videoH) / 2 : 0.0;

    return SizedBox(
      width: maxWidth,
      height: paneHeight,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned(
              left: videoLeft,
              top: videoTop,
              width: videoW,
              height: videoH,
              child: _buildPlayer(),
            ),
            if (!fill)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 48,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: _isPlaying ? 'Pause' : 'Play',
                      onPressed: _togglePlay,
                      icon: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: l10n.translate('wave_fullscreen'),
                      onPressed: () => _setFullscreen(true),
                      icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
            if (fill && !_inPip)
              SafeArea(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l10n.translate('wave_exit_fullscreen'),
                        onPressed: () => _setFullscreen(false),
                        icon: const Icon(
                          Icons.fullscreen_exit_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      IconButton(
                        tooltip: _isPlaying ? 'Pause' : 'Play',
                        onPressed: _togglePlay,
                        icon: Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    if (_controller == null) {
      return const ColoredBox(color: AppTheme.cardColor);
    }
    return YoutubePlayer(
      key: _playerKey,
      controller: _controller!,
      aspectRatio: 16 / 9,
      keepAlive: true,
      backgroundColor: Colors.black,
      autoFullScreen: false,
      enableFullScreenOnVerticalDrag: false,
    );
  }

  Widget _creatorRow(
    AppLocalizations l10n,
    WaveLibraryProvider library,
    WaveVideo video,
  ) {
    final followed = library.isFollowed(video.channelId);
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WaveCreatorScreen(
                  channelId: video.channelId,
                  creator: _creator,
                ),
              ),
            );
          },
          child: CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.cardColor,
            backgroundImage: (video.channelThumbnailUrl ?? _creator?.thumbnailUrl) == null
                ? null
                : CachedNetworkImageProvider(
                    video.channelThumbnailUrl ?? _creator!.thumbnailUrl,
                  ),
            child: (video.channelThumbnailUrl ?? _creator?.thumbnailUrl) == null
                ? const Icon(Icons.person_rounded, size: 18)
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WaveCreatorScreen(
                    channelId: video.channelId,
                    creator: _creator,
                  ),
                ),
              );
            },
            child: Text(
              video.channelTitle,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            final creator = _creator ??
                WaveCreator(
                  youtubeChannelId: video.channelId,
                  title: video.channelTitle,
                  thumbnailUrl: video.channelThumbnailUrl ?? '',
                );
            library.toggleFollow(creator);
          },
          child: Text(
            followed ? l10n.translate('wave_following') : l10n.translate('wave_follow'),
            style: TextStyle(
              color: followed ? AppTheme.textSecondary : AppTheme.primaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actions(
    AppLocalizations l10n,
    WaveLibraryProvider library,
    WaveVideo video,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionChip(
          icon: library.isSaved(video.videoId)
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          label: l10n.translate('wave_save'),
          onTap: () => library.toggleSaved(video),
        ),
        _ActionChip(
          icon: library.isWatchLater(video.videoId)
              ? Icons.watch_later_rounded
              : Icons.watch_later_outlined,
          label: l10n.translate('wave_watch_later'),
          onTap: () => library.toggleWatchLater(video),
        ),
        _ActionChip(
          icon: Icons.ios_share_rounded,
          label: l10n.translate('wave_share'),
          onTap: () async {
            final uri = Uri.parse(video.watchUrl);
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppTheme.textPrimary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
