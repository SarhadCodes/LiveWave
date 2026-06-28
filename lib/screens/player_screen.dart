import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import '../config/app_theme.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/channels_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/security_utils.dart';
import '../widgets/channel_logo.dart';
import '../screens/security_block_screen.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;
  final List<Channel>? allChannels;
  final int? initialChannelIndex;

  const PlayerScreen({
    super.key,
    required this.channel,
    this.allChannels,
    this.initialChannelIndex,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // BetterPlayer Controller
  BetterPlayerController? _betterPlayerController;
  Timer? _securityTimer;
  
  bool _hasError = false; 
  bool _showChannelSelector = false;
  bool _showChannelInfo = false;
  Timer? _hideChannelSelectorTimer;
  Timer? _hideChannelInfoTimer;
  
  // Channel switching
  late Channel _currentChannel;
  late int _currentChannelIndex;
  late int _focusedChannelIndex;
  
  List<Channel> _channels = [];
  final ScrollController _channelScrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  String _initialLayoutMode = 'tv';
  
  // Category management
  List<String> _categories = [];
  String _selectedCategory = 'ALL';
  int _focusedCategoryIndex = 0;
  bool _isCategoryFocused = false;

  // Aspect ratio (tap to cycle — no menu)
  static const _aspectLabels = ['Auto', '16:9', '4:3', 'Stretch', 'Zoom'];
  int _aspectRatioIndex = 0;
  bool _showAspectHint = false;
  Timer? _aspectHintTimer;

  // Auto-reconnect when stream freezes or stops (silent — no UI)
  Timer? _streamWatchdogTimer;
  Timer? _reconnectDebounceTimer;
  DateTime? _lastPlaybackActivity;
  bool _reconnectRunning = false;
  int _reconnectAttempt = 0;
  int _reconnectBackoffMs = 2000;
  static const _maxReconnectAttempts = 8;
  static const _maxReconnectBackoffMs = 15000;
  void Function(BetterPlayerEvent)? _playerEventsListener;

  @override
  void initState() {
    super.initState();
    _startSecurityMonitoring();
    WakelockPlus.enable(); 
    
    // Get initial layout mode to restore it later
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _initialLayoutMode = settings.layoutMode;
    
    // Initialize data
    final channelsProvider = Provider.of<ChannelsProvider>(context, listen: false);
    _categories = ['ALL', ...channelsProvider.categories];
    _currentChannel = widget.channel;
    _selectedCategory = widget.channel.category.toUpperCase();
    
    // Initial channel list should be the one from the current channel's category
    _channels = widget.allChannels ?? [widget.channel];
    
    _currentChannelIndex = widget.initialChannelIndex ?? 0;
    _focusedChannelIndex = _currentChannelIndex;
    
    // Find initial category index
    final catIndex = _categories.indexOf(_selectedCategory);
    if (catIndex != -1) {
      _focusedCategoryIndex = catIndex;
    }
    
    // Start playback
    _loadAspectRatioPreference();
    _setupPlayer();
    _startStreamWatchdog();
    
    // Show info initially
    _showChannelInfoOverlay();
    
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _startSecurityMonitoring() {
    _securityTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final isSecurityAlert = await SecurityUtils.isVpnOrProxyActive();
      if (isSecurityAlert && mounted) {
        _securityTimer?.cancel();
        _betterPlayerController?.pause();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SecurityBlockScreen()),
          (route) => false,
        );
      }
    });
  }

  Future<void> _loadAspectRatioPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('live_tv_aspect_ratio') ?? 0;
      if (saved >= 0 && saved < _aspectLabels.length) {
        _aspectRatioIndex = saved;
      }
    } catch (e) {
      debugPrint('Failed to load aspect ratio preference: $e');
    }
  }

  Future<void> _saveAspectRatioPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('live_tv_aspect_ratio', _aspectRatioIndex);
    } catch (e) {
      debugPrint('Failed to save aspect ratio preference: $e');
    }
  }

  void _cycleAspectRatio() {
    setState(() {
      _aspectRatioIndex = (_aspectRatioIndex + 1) % _aspectLabels.length;
    });
    _applyAspectRatio();
    _saveAspectRatioPreference();
    _showAspectRatioHint();
  }

  void _showAspectRatioHint() {
    setState(() => _showAspectHint = true);
    _aspectHintTimer?.cancel();
    _aspectHintTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showAspectHint = false);
    });
  }

  void _applyAspectRatio() {
    final controller = _betterPlayerController;
    if (controller == null) return;

    switch (_aspectRatioIndex) {
      case 0: // Auto
        final natural = controller.videoPlayerController?.value.aspectRatio;
        if (natural != null && natural > 0) {
          controller.setOverriddenAspectRatio(natural);
        }
        controller.setOverriddenFit(BoxFit.contain);
        break;
      case 1: // 16:9
        controller.setOverriddenAspectRatio(16 / 9);
        controller.setOverriddenFit(BoxFit.contain);
        break;
      case 2: // 4:3
        controller.setOverriddenAspectRatio(4 / 3);
        controller.setOverriddenFit(BoxFit.contain);
        break;
      case 3: // Stretch
        controller.setOverriddenFit(BoxFit.fill);
        break;
      case 4: // Zoom
        controller.setOverriddenFit(BoxFit.cover);
        break;
    }
  }

  void _markPlaybackActivity() {
    _lastPlaybackActivity = DateTime.now();
    _reconnectAttempt = 0;
    _reconnectBackoffMs = 2000;
  }

  bool _isBackKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.backspace;
  }

  bool get _showPlayerChrome =>
      _hasError || _showChannelSelector || _showChannelInfo;

  void _startStreamWatchdog() {
    _streamWatchdogTimer?.cancel();
    _streamWatchdogTimer = Timer.periodic(const Duration(seconds: 8), (_) => _checkStreamHealth());
  }

  void _checkStreamHealth() {
    if (!mounted || _hasError || _reconnectRunning) return;

    final videoController = _betterPlayerController?.videoPlayerController;
    if (videoController == null || !videoController.value.initialized) return;

    final value = videoController.value;
    if (value.hasError) {
      _scheduleReconnect('error');
      return;
    }

    final lastActivity = _lastPlaybackActivity;
    if (lastActivity == null) return;

    final stalledSeconds = DateTime.now().difference(lastActivity).inSeconds;
    if (value.isBuffering && stalledSeconds >= 30) {
      _scheduleReconnect('buffering');
    }
  }

  void _scheduleReconnect(String reason) {
    if (_reconnectRunning || _hasError || (_reconnectDebounceTimer?.isActive ?? false)) return;
    debugPrint('Live TV reconnect scheduled ($reason) in ${_reconnectBackoffMs}ms');
    _reconnectDebounceTimer = Timer(Duration(milliseconds: _reconnectBackoffMs), _reconnectStream);
  }

  Future<void> _reconnectStream() async {
    if (!mounted || _hasError || _reconnectRunning) return;

    final controller = _betterPlayerController;
    if (controller?.betterPlayerDataSource == null) return;

    _reconnectRunning = true;
    try {
      await controller!.retryDataSource();
      await controller.play();
      _markPlaybackActivity();
      _applyAspectRatio();
    } catch (e) {
      debugPrint('Reconnect failed: $e');
      _reconnectAttempt++;
      _reconnectBackoffMs =
          (_reconnectBackoffMs * 1.5).round().clamp(2000, _maxReconnectBackoffMs);
      if (_reconnectAttempt < _maxReconnectAttempts) {
        _scheduleReconnect('retry_failed');
      } else if (mounted) {
        setState(() => _hasError = true);
      }
    } finally {
      _reconnectRunning = false;
    }
  }

  void _attachPlayerEventsListener() {
    final controller = _betterPlayerController;
    if (controller == null) return;

    if (_playerEventsListener != null) {
      controller.removeEventsListener(_playerEventsListener!);
    }

    _playerEventsListener = (event) {
      switch (event.betterPlayerEventType) {
        case BetterPlayerEventType.initialized:
        case BetterPlayerEventType.play:
        case BetterPlayerEventType.progress:
        case BetterPlayerEventType.bufferingEnd:
          _markPlaybackActivity();
          if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
            _applyAspectRatio();
          }
          break;
        case BetterPlayerEventType.exception:
          debugPrint('BetterPlayer Exception: ${event.parameters}');
          _scheduleReconnect('exception');
          break;
        default:
          break;
      }
    };

    controller.addEventsListener(_playerEventsListener!);
  }

  /// Detect IPTV stream container — many URLs have no extension (audio-only if wrong).
  BetterPlayerVideoFormat _detectLiveStreamFormat(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8') || lower.contains('m3u8')) {
      return BetterPlayerVideoFormat.hls;
    }
    if (lower.contains('.mpd')) {
      return BetterPlayerVideoFormat.dash;
    }
    // .ts, /live/, Xtream-style paths → MPEG-TS progressive
    return BetterPlayerVideoFormat.other;
  }

  Future<void> _setupPlayer() async {
    bool isPiracyToolActive = false;
    try {
      // 1. Check for System Proxy (HttpCanary/Charles)
      final proxy = HttpClient.findProxyFromEnvironment(Uri.parse("https://www.google.com"));
      if (proxy.contains("PROXY") || proxy.contains("HTTP")) {
        isPiracyToolActive = true;
      }

      // 2. Check for VPN Interfaces (HttpCanary VPN Mode)
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('tun') || name.contains('ppp') || name.contains('tap') || name.contains('vpn')) {
          isPiracyToolActive = true;
          break;
        }
      }
    } catch (e) {
      // Ignore errors in check, but log it
      debugPrint("Security check error: $e");
    }

    if (isPiracyToolActive) {
      setState(() => _hasError = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.accentRed,
            content: Text('Security Alert: Please disable VPN or Proxy to watch.', 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      }
      return;
    }

    final streamUrl = _currentChannel.stream.trim();

    if (streamUrl.isEmpty) {
      setState(() => _hasError = true);
      return;
    }

    // Dispose previous controller
    if (_playerEventsListener != null && _betterPlayerController != null) {
      _betterPlayerController!.removeEventsListener(_playerEventsListener!);
      _playerEventsListener = null;
    }
    _betterPlayerController?.dispose();
    _betterPlayerController = null;

    setState(() => _hasError = false);

    try {
      // 1. Configure for Performance (Compatible with v1.0.8)
      BetterPlayerConfiguration betterPlayerConfiguration = BetterPlayerConfiguration(
        autoPlay: true,
        fit: BoxFit.contain,
        allowedScreenSleep: false,
        handleLifecycle: true,
        // PERFORMANCE: Disable overhead
        subtitlesConfiguration: const BetterPlayerSubtitlesConfiguration(fontSize: 0),
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false,
          enableFullscreen: false,
        ),
      );

      // 2. Configure Data Source
      BetterPlayerDataSource dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        streamUrl,
        liveStream: true,
        videoFormat: _detectLiveStreamFormat(streamUrl),
        
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        notificationConfiguration: const BetterPlayerNotificationConfiguration(
          showNotification: false,
        ),
        useAsmsSubtitles: false,
        useAsmsTracks: true,
        useAsmsAudioTracks: true,
        bufferingConfiguration: const BetterPlayerBufferingConfiguration(
          minBufferMs: 20000,
          maxBufferMs: 50000,
          bufferForPlaybackMs: 2500,
          bufferForPlaybackAfterRebufferMs: 5000,
        ),
      );
      
      _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
      await _betterPlayerController!.setupDataSource(dataSource);
      _attachPlayerEventsListener();
      _applyAspectRatio();
      _markPlaybackActivity();

    } catch (e) {
      debugPrint('Error setting up player: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _securityTimer?.cancel();
    _streamWatchdogTimer?.cancel();
    _reconnectDebounceTimer?.cancel();
    _aspectHintTimer?.cancel();
    WakelockPlus.disable();
    _hideChannelSelectorTimer?.cancel();
    _hideChannelInfoTimer?.cancel();
    _channelScrollController.dispose();
    _categoryScrollController.dispose();
    
    if (_playerEventsListener != null && _betterPlayerController != null) {
      _betterPlayerController!.removeEventsListener(_playerEventsListener!);
    }
    _betterPlayerController?.dispose();

    // Restore orientation based on layout mode
    if (_initialLayoutMode == 'tv') {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  // --- Channel & UI Logic ---

  Future<void> _activateFocusedChannel() async {
    final focusedChannel = _channels[_focusedChannelIndex];
    
    // Check by unique ID, not index
    if (focusedChannel.id == _currentChannel.id) {
      _closeChannelSelector(showInfo: true);
      return;
    }
    
    setState(() {
      _currentChannelIndex = _focusedChannelIndex;
      _currentChannel = _channels[_currentChannelIndex];
    });
    
    await _setupPlayer();
    _closeChannelSelector(showInfo: true);
    _showChannelInfoOverlay();
  }

  void _switchToNextChannel() {
    if (_channels.length <= 1) return;
    final nextIndex = (_currentChannelIndex + 1) % _channels.length;
    _forceSwitchChannel(nextIndex);
  }

  void _switchToPreviousChannel() {
    if (_channels.length <= 1) return;
    final prevIndex = (_currentChannelIndex - 1 + _channels.length) % _channels.length;
    _forceSwitchChannel(prevIndex);
  }

  Future<void> _forceSwitchChannel(int index) async {
     setState(() {
      _currentChannelIndex = index;
      _currentChannel = _channels[index];
      _focusedChannelIndex = index; 
    });
    await _setupPlayer();
    _showChannelInfoOverlay();
  }

  void _changeCategory(String category) {
    final channelsProvider = Provider.of<ChannelsProvider>(context, listen: false);
    setState(() {
      _selectedCategory = category;
      _channels = channelsProvider.filterByCategory(category);
      _focusedChannelIndex = 0;
      _isCategoryFocused = false;
    });
    _scrollToFocusedChannel();
    _startHideChannelSelectorTimer();
  }

  void _moveCategoryFocus(int newIndex) {
    if (newIndex < 0 || newIndex >= _categories.length) return;
    setState(() => _focusedCategoryIndex = newIndex);
    _scrollToFocusedCategory();
    _startHideChannelSelectorTimer();
  }

  void _scrollToFocusedCategory() {
    if (!_categoryScrollController.hasClients) return;
    const itemHeight = 52.0;
    final viewportHeight = _categoryScrollController.position.viewportDimension;
    final scrollPosition =
        (_focusedCategoryIndex * itemHeight) - (viewportHeight / 2) + (itemHeight / 2);

    _categoryScrollController.animateTo(
      scrollPosition.clamp(0.0, _categoryScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showChannelInfoOverlay() {
    if (!mounted) return;
    setState(() {
      _showChannelInfo = true;
      _showChannelSelector = false;
    });
    _startHideChannelInfoTimer();
  }

  void _startHideChannelInfoTimer() {
    _hideChannelInfoTimer?.cancel();
    _hideChannelInfoTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && !_showChannelSelector) {
        setState(() => _showChannelInfo = false);
      }
    });
  }

  void _hideChannelInfo() {
    setState(() => _showChannelInfo = false);
    _hideChannelInfoTimer?.cancel();
  }

  void _onPlayerTap() {
    if (_showChannelSelector) return;
    _showChannelInfoOverlay();
  }

  void _dismissChannelSelectorFromVideoArea() {
    if (!_showChannelSelector) return;
    _closeChannelSelector(showInfo: false);
  }

  void _handleOkPress() {
    if (_showChannelSelector) return;
    if (!_showChannelInfo) {
      _showChannelInfoOverlay();
    } else {
      _openChannelSelector();
    }
  }

  void _openChannelSelector() {
    setState(() {
      _showChannelSelector = true;
      _showChannelInfo = false;
      _isCategoryFocused = false;
      _focusedChannelIndex = _currentChannelIndex;

      final catIndex = _categories.indexOf(_selectedCategory);
      if (catIndex != -1) {
        _focusedCategoryIndex = catIndex;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToFocusedChannel();
      _scrollToFocusedCategory();
    });

    _hideChannelInfoTimer?.cancel();
    _startHideChannelSelectorTimer();
  }

  void _closeChannelSelector({bool showInfo = false}) {
    setState(() {
      _showChannelSelector = false;
      if (showInfo) _showChannelInfo = true;
    });
    _hideChannelSelectorTimer?.cancel();
    if (showInfo) _startHideChannelInfoTimer();
  }

  DateTime? _lastBackHandledAt;

  void _handleBackAction() {
    final now = DateTime.now();
    if (_lastBackHandledAt != null &&
        now.difference(_lastBackHandledAt!) <
            const Duration(milliseconds: 300)) {
      return;
    }
    _lastBackHandledAt = now;

    if (_showChannelSelector) {
      _closeChannelSelector(showInfo: true);
    } else if (_showChannelInfo) {
      _hideChannelInfo();
    } else if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Widget _buildTopBackButton() {
    final left = _showChannelSelector ? _channelListWidth + 8.0 : 8.0;
    return Positioned(
      top: 0,
      left: left,
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleBackAction,
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }

  void _startHideChannelSelectorTimer() {
    _hideChannelSelectorTimer?.cancel();
    _hideChannelSelectorTimer = Timer(const Duration(seconds: 8), () { // Increased for better browsing
      if (mounted) setState(() => _showChannelSelector = false);
    });
  }

  void _moveFocus(int newIndex) {
    if (newIndex < 0 || newIndex >= _channels.length) return;
    setState(() => _focusedChannelIndex = newIndex);
    _scrollToFocusedChannel();
    _startHideChannelSelectorTimer();
  }

  void _scrollToFocusedChannel() {
    if (!_channelScrollController.hasClients) return;
    const itemHeight = 72.0;
    final viewportHeight = _channelScrollController.position.viewportDimension;
    final scrollPosition =
        (_focusedChannelIndex * itemHeight) - (viewportHeight / 2) + (itemHeight / 2);

    _channelScrollController.animateTo(
      scrollPosition.clamp(0.0, _channelScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleBackAction();
      },
      child: Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (_showChannelSelector) {
            if (_isCategoryFocused) {
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                _moveCategoryFocus((_focusedCategoryIndex - 1 + _categories.length) % _categories.length);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                _moveCategoryFocus((_focusedCategoryIndex + 1) % _categories.length);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                setState(() => _isCategoryFocused = false);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter) {
                _changeCategory(_categories[_focusedCategoryIndex]);
                return KeyEventResult.handled;
              }
            } else {
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                _moveFocus((_focusedChannelIndex - 1 + _channels.length) % _channels.length);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                _moveFocus((_focusedChannelIndex + 1) % _channels.length);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                setState(() => _isCategoryFocused = true);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter) {
                _activateFocusedChannel();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _closeChannelSelector(showInfo: true);
                return KeyEventResult.handled;
              }
            }
          } else if (_showChannelInfo) {
            if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter) {
              _handleOkPress();
              return KeyEventResult.handled;
            }
          } else {
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _switchToPreviousChannel();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _switchToNextChannel();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter) {
              _handleOkPress();
              return KeyEventResult.handled;
            }
          }

          if (_isBackKey(event.logicalKey)) {
            _handleBackAction();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _onPlayerTap,
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    children: [
                      Center(
                        child: _hasError
                            ? _buildErrorScreen()
                            : (_betterPlayerController != null)
                                ? RepaintBoundary(
                                    child: BetterPlayer(controller: _betterPlayerController!),
                                  )
                                : const Center(
                                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                                  ),
                      ),
                      if (_showAspectHint) _buildAspectRatioHint(),
                    ],
                  ),
                ),
              ),
              if (_showChannelSelector) ...[
                _buildChannelSelector(),
                _buildChannelListDismissArea(),
              ],
              if (!_hasError && _showChannelInfo && !_showChannelSelector)
                _buildPlayerControlsBar(),
              if (_showPlayerChrome) _buildTopBackButton(),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildErrorScreen() {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          // Background Artistic Glows
          Positioned(
            top: -150,
            right: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.03),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.03),
              ),
            ),
          ),
          Center(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Minimalist Logo Presentation
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                      ),
                      padding: const EdgeInsets.all(25),
                      child: Opacity(
                        opacity: 0.9,
                        child: Image.asset('assets/icon.png'),
                      ),
                    ),
                    const SizedBox(height: 60),
                    // Sharp Modern Typography
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        l10n.translate('error_channel').toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: l10n.locale.languageCode == 'ku' ? FontWeight.bold : FontWeight.w200,
                          letterSpacing: l10n.locale.languageCode == 'ku' ? 0 : 8.0,
                          fontFamily: 'K24Kurdish',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        l10n.translate('error_try_again'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          letterSpacing: l10n.locale.languageCode == 'ku' ? 0 : 1.5,
                          fontFamily: 'K24Kurdish',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 80),
                    // Premium Minimal Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                          ),
                          child: Text(
                            l10n.translate('home').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40), // Bottom padding for scroll
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerControlsBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      bottom: _showChannelInfo ? 0 : -160,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.92)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: SafeArea(
          top: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_currentChannel.logo.isNotEmpty)
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ChannelLogo(
                      logo: _currentChannel.logo,
                      width: 64,
                      height: 64,
                      fit: BoxFit.contain,
                      fallback: const Icon(Icons.tv, color: Colors.white54, size: 28),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentChannel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _currentChannel.category.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildControlActionButton(
                        icon: Icons.aspect_ratio,
                        label: _aspectLabels[_aspectRatioIndex],
                        onTap: () {
                          _cycleAspectRatio();
                          _startHideChannelInfoTimer();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildControlActionButton(
                        icon: Icons.list,
                        label: 'Channels',
                        onTap: _openChannelSelector,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isFocused
                    ? AppTheme.primaryColor.withOpacity(0.9)
                    : Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFocused ? Colors.white : Colors.white24,
                  width: isFocused ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAspectRatioHint() {
    return Center(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _showAspectHint ? 1.0 : 0.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryColor),
          ),
          child: Text(
            _aspectLabels[_aspectRatioIndex],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  static const double _channelListWidth = 420;

  Widget _buildChannelListDismissArea() {
    return Positioned(
      left: _channelListWidth,
      top: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: _dismissChannelSelectorFromVideoArea,
        behavior: HitTestBehavior.opaque,
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildChannelSelector() {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: _channelListWidth,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.black.withOpacity(0.97),
              Colors.black.withOpacity(0.92),
              Colors.black.withOpacity(0.55),
              Colors.transparent,
            ],
            stops: const [0.0, 0.65, 0.88, 1.0],
          ),
        ),
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 8, 10),
                      child: Text(
                        'CATEGORIES',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _categoryScrollController,
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final isFocused = _isCategoryFocused && index == _focusedCategoryIndex;
                          final isSelected = category == _selectedCategory;
                          return _buildCategoryItem(category, isFocused, isSelected, index);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, color: Colors.white12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _selectedCategory,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _channelScrollController,
                        padding: const EdgeInsets.fromLTRB(8, 0, 12, 12),
                        itemCount: _channels.length,
                        itemBuilder: (context, index) {
                          final channel = _channels[index];
                          final isFocused = !_isCategoryFocused && index == _focusedChannelIndex;
                          final isPlaying = channel.id == _currentChannel.id;

                          return GestureDetector(
                            onTap: () {
                              if (_isCategoryFocused) {
                                setState(() => _isCategoryFocused = false);
                              }
                              _moveFocus(index);
                              _activateFocusedChannel();
                            },
                            child: _buildChannelItem(channel, isFocused, isPlaying),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(String category, bool isFocused, bool isSelected, int index) {
    return GestureDetector(
      onTap: () {
        _moveCategoryFocus(index);
        _changeCategory(category);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isFocused
              ? AppTheme.primaryColor
              : (isSelected ? AppTheme.primaryColor.withOpacity(0.35) : Colors.white10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFocused ? Colors.white : (isSelected ? AppTheme.primaryColor : Colors.transparent),
            width: isFocused ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: isFocused || isSelected ? Colors.redAccent : Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isFocused || isSelected ? FontWeight.w900 : FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelItem(Channel channel, bool isFocused, bool isPlaying) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 66,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isFocused ? Colors.white.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFocused
              ? AppTheme.primaryColor
              : (isPlaying ? AppTheme.primaryColor.withOpacity(0.35) : Colors.white10),
          width: isFocused ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ChannelLogo(
                logo: channel.logo,
                width: 48,
                height: 48,
                fit: BoxFit.contain,
                fallback: const Icon(Icons.tv, color: Colors.grey, size: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isFocused ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: isFocused ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                if (isPlaying) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'NOW PLAYING',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
