import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../iptv_exo_player.dart';
import '../models/channel.dart';
import '../providers/channels_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/security_block_screen.dart';
import '../utils/security_utils.dart';
import '../widgets/channel_logo.dart';

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

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  LiveExoPlayerController? _player;

  Timer? _securityTimer;
  Timer? _retryTimer;
  Timer? _hideChannelInfoTimer;
  Timer? _aspectHintTimer;

  bool _hasError = false;
  bool _showChannelSelector = false;
  bool _showChannelInfo = false;

  late Channel _currentChannel;
  late int _currentChannelIndex;
  late int _focusedChannelIndex;

  List<Channel> _channels = [];
  final ScrollController _channelScrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  String _initialLayoutMode = 'tv';

  List<String> _categories = [];
  String _selectedCategory = 'ALL';
  int _focusedCategoryIndex = 0;
  bool _isCategoryFocused = false;
  bool _categoryPanelVisible = false;
  String? _lastOkActivatedChannelId;

  static const _aspectLabels = ['Auto', '16:9', '4:3', 'Stretch', 'Zoom'];
  int _aspectRatioIndex = 0;
  bool _showAspectHint = false;

  int _retryAttempt = 0;
  int _playbackGeneration = 0;
  static const _maxRetryAttempts = 6;
  static const _retryBackoffMs = 1500;

  final FocusNode _backButtonFocusNode = FocusNode(debugLabel: 'playerBack');
  final FocusNode _favoriteFocusNode = FocusNode(debugLabel: 'playerFavorite');
  final FocusNode _aspectRatioFocusNode = FocusNode(debugLabel: 'playerAspect');
  final FocusNode _channelsFocusNode = FocusNode(debugLabel: 'playerChannels');
  static const MethodChannel _backChannel =
      MethodChannel('com.livewave.player/back');

  bool _exitInProgress = false;

  LiveExoPlayerController get _livePlayer {
    if (_player?.isDisposed == true) {
      _player = null;
    }
    return _player ??= LiveExoPlayerController()..onEvent = _onPlayerEvent;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSecurityMonitoring();
    WakelockPlus.enable();

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _initialLayoutMode = settings.layoutMode;

    final channelsProvider =
        Provider.of<ChannelsProvider>(context, listen: false);
    _categories = ['ALL', ...channelsProvider.categories];
    _currentChannel = widget.channel;
    _selectedCategory = widget.channel.category.toUpperCase();
    _channels = widget.allChannels ?? [widget.channel];
    _currentChannelIndex = widget.initialChannelIndex ?? 0;
    _focusedChannelIndex = _currentChannelIndex;

    final catIndex = _categories.indexOf(_selectedCategory);
    if (catIndex != -1) {
      _focusedCategoryIndex = catIndex;
    }

    _loadAspectRatioPreference();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_livePlayer.ensureInitialized());
      unawaited(_startLivePlayback());
    });
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    if (Platform.isAndroid) {
      _backChannel.setMethodCallHandler(_onAndroidBackChannel);
      _backChannel.invokeMethod('setBackInterceptorEnabled', {'enabled': true});
    }

    _showChannelInfoOverlay();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _lockToLandscape();
  }

  bool get _isMobileLayout => _initialLayoutMode == 'mobile';

  void _lockToLandscape() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _restoreOrientationAfterPlayer() async {
    if (_isMobileLayout) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_exitInProgress) {
      _lockToLandscape();
    }
  }

  @override
  void didChangeMetrics() {
    if (!mounted || _exitInProgress) return;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final view = views.first;
    if (view.physicalSize.height > view.physicalSize.width) {
      _lockToLandscape();
    }
  }

  void _startSecurityMonitoring() {
    _securityTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final isSecurityAlert = await SecurityUtils.isVpnOrProxyActive();
      if (isSecurityAlert && mounted) {
        _securityTimer?.cancel();
        unawaited(_releasePlayback());
        unawaited(_restoreOrientationAfterPlayer());
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
    _livePlayer.applyAspectRatio(modeIndex: _aspectRatioIndex);
  }

  void _onPlayerEvent(String event, Map<String, dynamic> data) {
    if (!mounted) return;
    switch (event) {
      case 'firstFrameRendered':
        _showChannelInfoOverlay();
        _retryAttempt = 0;
        if (mounted) setState(() => _hasError = false);
        break;
      case 'initialized':
      case 'playing':
      case 'videoSize':
        _retryAttempt = 0;
        if (mounted) setState(() => _hasError = false);
        break;
      case 'exception':
        _scheduleRetryOrError();
        break;
    }
    setState(() {});
  }

  Future<void> _startLivePlayback() async {
    try {
      debugPrint('[Player] Starting live playback for ${_currentChannel.name}');
      await _playCurrentChannel();
    } catch (e, st) {
      debugPrint('[Player] Live playback start failed: $e\n$st');
      if (mounted) setState(() => _hasError = true);
    }
  }

  Future<void> _playCurrentChannel() async {
    final url = _currentChannel.stream.trim();
    if (url.isEmpty) {
      debugPrint('[Player] Empty stream URL for ${_currentChannel.name}');
      if (mounted) setState(() => _hasError = true);
      return;
    }
    final generation = _playbackGeneration;
    try {
      debugPrint('[Player] Playing channel=${_currentChannel.name}');
      await _livePlayer.ensureInitialized();
      if (!mounted || generation != _playbackGeneration) return;
      setState(() {});
      await WidgetsBinding.instance.endOfFrame;
      await _livePlayer.mountTextureAndAttachSurface();
      await _livePlayer.waitForSurface();
      if (!mounted || generation != _playbackGeneration) return;
      await _livePlayer.setLiveChannel(url);
      if (!mounted || generation != _playbackGeneration) return;
      _applyAspectRatio();
      setState(() => _hasError = false);
    } catch (e, st) {
      if (!mounted || generation != _playbackGeneration) return;
      debugPrint('[Player] Playback failed: $e\n$st');
      _scheduleRetryOrError();
    }
  }

  void _scheduleRetryOrError() {
    if (!mounted || _hasError) return;
    if (_retryAttempt >= _maxRetryAttempts) {
      setState(() => _hasError = true);
      return;
    }
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(milliseconds: _retryBackoffMs), () async {
      if (!mounted || _hasError) return;
      _retryAttempt++;
      try {
        await _livePlayer.retry();
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('Retry failed: $e');
        if (_retryAttempt >= _maxRetryAttempts && mounted) {
          setState(() => _hasError = true);
        } else if (mounted) {
          _scheduleRetryOrError();
        }
      }
    });
  }

  Future<void> _retryCurrentChannel() async {
    _retryTimer?.cancel();
    _retryAttempt = 0;
    setState(() => _hasError = false);
    await _playCurrentChannel();
  }

  Future<void> _switchToChannel(Channel channel) async {
    _retryTimer?.cancel();
    _retryAttempt = 0;
    setState(() {
      _currentChannel = channel;
      _hasError = false;
    });
    await _playCurrentChannel();
  }

  DateTime? _lastChannelZapAt;

  bool _isChannelZapKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.channelUp ||
        key == LogicalKeyboardKey.channelDown;
  }

  bool _handleChannelZapKey(LogicalKeyboardKey key) {
    if (_channels.length <= 1 || !_isChannelZapKey(key)) return false;

    final now = DateTime.now();
    if (_lastChannelZapAt != null &&
        now.difference(_lastChannelZapAt!) <
            const Duration(milliseconds: 400)) {
      return true;
    }

    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.channelDown) {
      _switchToPreviousChannel();
    } else {
      _switchToNextChannel();
    }
    _lastChannelZapAt = now;
    return true;
  }

  Future<dynamic> _onAndroidBackChannel(MethodCall call) async {
    if (call.method == 'onBackPressed') {
      _handleBackAction();
    }
    return null;
  }

  bool _isBackKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.backspace;
  }

  bool _isActivateKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  bool get _isTvMode => _initialLayoutMode == 'tv';

  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    if (_isActivateKey(event.logicalKey)) {
      if (_showChannelSelector) return false;
      if (_showChannelInfo && _hasBottomChromeFocus) return false;
      _handleOkPress();
      return true;
    }

    if (!_showChannelSelector && _handleChannelZapKey(event.logicalKey)) {
      return true;
    }

    if (!_isBackKey(event.logicalKey)) return false;
    _handleBackAction();
    return true;
  }

  bool get _showPlayerChrome =>
      _hasError || _showChannelSelector || _showChannelInfo;

  void _exitPlayer() {
    if (!mounted || _exitInProgress) return;
    _exitInProgress = true;
    if (Platform.isAndroid) {
      unawaited(
        _backChannel.invokeMethod('setBackInterceptorEnabled', {'enabled': false}),
      );
    }
    unawaited(() async {
      await _restoreOrientationAfterPlayer();
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop();
      });
    }());
  }

  Future<void> _releasePlayback() async {
    _retryTimer?.cancel();
    final player = _player;
    _player = null;
    try {
      await player?.dispose();
    } catch (e) {
      debugPrint('Playback release failed: $e');
    }
  }

  @override
  void dispose() {
    _playbackGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _securityTimer?.cancel();
    _retryTimer?.cancel();
    _aspectHintTimer?.cancel();
    WakelockPlus.disable();
    _hideChannelInfoTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    if (Platform.isAndroid) {
      _backChannel.invokeMethod('setBackInterceptorEnabled', {'enabled': false});
      _backChannel.setMethodCallHandler(null);
    }
    _backButtonFocusNode.dispose();
    _favoriteFocusNode.dispose();
    _aspectRatioFocusNode.dispose();
    _channelsFocusNode.dispose();
    _channelScrollController.dispose();
    _categoryScrollController.dispose();

    unawaited(_releasePlayback());

    if (!_exitInProgress) {
      unawaited(_restoreOrientationAfterPlayer());
    }

    super.dispose();
  }

  Future<void> _activateFocusedChannel() async {
    final focusedChannel = _channels[_focusedChannelIndex];

    if (focusedChannel.id == _currentChannel.id) {
      if (!_showChannelSelector) return;
      if (_lastOkActivatedChannelId == focusedChannel.id) {
        _closeChannelSelector(showInfo: true);
      } else {
        setState(() => _lastOkActivatedChannelId = focusedChannel.id);
      }
      return;
    }

    setState(() {
      _currentChannelIndex = _focusedChannelIndex;
      _lastOkActivatedChannelId = focusedChannel.id;
    });

    await _switchToChannel(focusedChannel);
  }

  void _switchToNextChannel() {
    if (_channels.length <= 1) return;
    final nextIndex = (_currentChannelIndex + 1) % _channels.length;
    _forceSwitchChannel(nextIndex);
  }

  void _switchToPreviousChannel() {
    if (_channels.length <= 1) return;
    final prevIndex =
        (_currentChannelIndex - 1 + _channels.length) % _channels.length;
    _forceSwitchChannel(prevIndex);
  }

  Future<void> _forceSwitchChannel(int index) async {
    setState(() {
      _currentChannelIndex = index;
      _focusedChannelIndex = index;
    });
    await _switchToChannel(_channels[index]);
    _showChannelInfoOverlay();
  }

  void _changeCategory(String category) {
    final channelsProvider =
        Provider.of<ChannelsProvider>(context, listen: false);
    final isTv =
        Provider.of<SettingsProvider>(context, listen: false).layoutMode == 'tv';
    setState(() {
      _selectedCategory = category;
      _channels = channelsProvider.filterByCategory(category);
      _focusedChannelIndex = 0;
      _isCategoryFocused = false;
      _lastOkActivatedChannelId = null;
      if (isTv) _categoryPanelVisible = false;
    });
    _scrollToFocusedChannel();
  }

  void _revealCategoryPanel() {
    setState(() {
      _categoryPanelVisible = true;
      _isCategoryFocused = true;
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToFocusedCategory());
  }

  bool _isTvLayout(BuildContext context) {
    return Provider.of<SettingsProvider>(context, listen: false).layoutMode ==
        'tv';
  }

  double _channelSelectorWidth(BuildContext context) {
    if (!_isTvLayout(context) || _categoryPanelVisible) {
      return _channelListWidthFull;
    }
    return _channelListWidthCompact;
  }

  void _moveCategoryFocus(int newIndex) {
    if (newIndex < 0 || newIndex >= _categories.length) return;
    setState(() => _focusedCategoryIndex = newIndex);
    _scrollToFocusedCategory();
  }

  void _scrollToFocusedCategory() {
    if (!_categoryScrollController.hasClients) return;
    const itemHeight = 52.0;
    final viewportHeight = _categoryScrollController.position.viewportDimension;
    final scrollPosition = (_focusedCategoryIndex * itemHeight) -
        (viewportHeight / 2) +
        (itemHeight / 2);

    _categoryScrollController.animateTo(
      scrollPosition
          .clamp(0.0, _categoryScrollController.position.maxScrollExtent),
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
    _focusDefaultBottomChromeControl();
  }

  List<FocusNode> get _bottomChromeFocusOrder => [
        _favoriteFocusNode,
        _aspectRatioFocusNode,
        _channelsFocusNode,
      ];

  bool get _hasBottomChromeFocus =>
      _bottomChromeFocusOrder.any((node) => node.hasFocus);

  void _focusDefaultBottomChromeControl() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showChannelInfo || _showChannelSelector) return;
      _channelsFocusNode.requestFocus();
    });
  }

  void _focusAdjacentBottomChromeControl({required bool forward}) {
    final order = _bottomChromeFocusOrder;
    var index = order.indexWhere((node) => node.hasFocus);
    if (index < 0) {
      _channelsFocusNode.requestFocus();
      return;
    }
    final nextIndex = forward
        ? (index + 1) % order.length
        : (index - 1 + order.length) % order.length;
    order[nextIndex].requestFocus();
  }

  bool _handleChromeHorizontalNav(LogicalKeyboardKey key) {
    if (!_showChannelInfo || _showChannelSelector) return false;

    final isRtl =
        Provider.of<SettingsProvider>(context, listen: false).isRtl;
    if (key == LogicalKeyboardKey.arrowRight) {
      _focusAdjacentBottomChromeControl(forward: !isRtl);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _focusAdjacentBottomChromeControl(forward: isRtl);
      return true;
    }
    return false;
  }

  bool _handleChromeVerticalNav(LogicalKeyboardKey key) {
    if (!_showChannelInfo || _showChannelSelector || _isTvLayout(context)) {
      return false;
    }

    if (key == LogicalKeyboardKey.arrowUp && _hasBottomChromeFocus) {
      _backButtonFocusNode.requestFocus();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowDown && _backButtonFocusNode.hasFocus) {
      _focusDefaultBottomChromeControl();
      return true;
    }
    return false;
  }

  void _startHideChannelInfoTimer() {
    _hideChannelInfoTimer?.cancel();
    _hideChannelInfoTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_showChannelSelector) {
        setState(() => _showChannelInfo = false);
      }
    });
  }

  Future<void> _toggleChannelFavorite(ChannelsProvider provider) async {
    final l10n = AppLocalizations.of(context);
    final wasFavorite = provider.isFavorite(_currentChannel.id);
    await provider.toggleFavorite(_currentChannel.id);
    _startHideChannelInfoTimer();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasFavorite
              ? '${_currentChannel.name} ${l10n.translate('removed_from_fav')}'
              : '${_currentChannel.name} ${l10n.translate('added_to_fav')}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor:
            wasFavorite ? AppTheme.textSecondary : AppTheme.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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
    final isTv = _isTvMode;
    setState(() {
      _showChannelSelector = true;
      _showChannelInfo = false;
      _isCategoryFocused = false;
      _categoryPanelVisible = !isTv;
      _lastOkActivatedChannelId = null;
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
  }

  void _closeChannelSelector({bool showInfo = false}) {
    setState(() {
      _showChannelSelector = false;
      _categoryPanelVisible = false;
      _lastOkActivatedChannelId = null;
      if (showInfo) _showChannelInfo = true;
    });
    _hideChannelInfoTimer?.cancel();
    if (showInfo) {
      _startHideChannelInfoTimer();
      _focusDefaultBottomChromeControl();
    }
  }

  void _handleBackAction() {
    if (_exitInProgress) return;
    if (_showChannelSelector) {
      if (_isTvMode && _categoryPanelVisible) {
        setState(() {
          _categoryPanelVisible = false;
          _isCategoryFocused = false;
        });
        return;
      }
      _closeChannelSelector(showInfo: false);
      return;
    }
    _exitPlayer();
  }

  Widget _buildTopBackButton() {
    if (_isTvLayout(context)) {
      return const SizedBox.shrink();
    }

    final left =
        _showChannelSelector ? _channelSelectorWidth(context) + 8.0 : 8.0;

    return Positioned(
      top: 0,
      left: left,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _showPlayerChrome ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_showPlayerChrome,
          child: SafeArea(
            child: Focus(
              focusNode: _backButtonFocusNode,
              canRequestFocus: true,
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) {
                  return KeyEventResult.ignored;
                }
                if (_handleChromeVerticalNav(event.logicalKey)) {
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  _focusDefaultBottomChromeControl();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  _focusDefaultBottomChromeControl();
                  return KeyEventResult.handled;
                }
                if (_isBackKey(event.logicalKey) ||
                    event.logicalKey == LogicalKeyboardKey.select ||
                    event.logicalKey == LogicalKeyboardKey.enter) {
                  _handleBackAction();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Builder(
                builder: (context) {
                  final isFocused = Focus.of(context).hasFocus;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _handleBackAction,
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isFocused
                            ? Colors.white
                            : Colors.black.withOpacity(0.55),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isFocused ? Colors.white : Colors.white24,
                          width: isFocused ? 2.5 : 1,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: isFocused ? Colors.black : Colors.white,
                        size: 26,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _moveFocus(int newIndex) {
    if (newIndex < 0 || newIndex >= _channels.length) return;
    if (newIndex == _focusedChannelIndex) return;
    setState(() {
      _focusedChannelIndex = newIndex;
      _lastOkActivatedChannelId = null;
    });
    _scrollToFocusedChannel();
  }

  void _scrollToFocusedChannel() {
    if (!_channelScrollController.hasClients) return;
    const itemHeight = 72.0;
    final viewportHeight = _channelScrollController.position.viewportDimension;
    final scrollPosition = (_focusedChannelIndex * itemHeight) -
        (viewportHeight / 2) +
        (itemHeight / 2);

    _channelScrollController.animateTo(
      scrollPosition
          .clamp(0.0, _channelScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = _livePlayer;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _exitInProgress) return;
        _handleBackAction();
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): _handleBackAction,
          const SingleActivator(LogicalKeyboardKey.goBack): _handleBackAction,
          const SingleActivator(LogicalKeyboardKey.browserBack):
              _handleBackAction,
          const SingleActivator(LogicalKeyboardKey.backspace): _handleBackAction,
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (_showChannelSelector) {
                if (_isCategoryFocused) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    _moveCategoryFocus(
                      (_focusedCategoryIndex - 1 + _categories.length) %
                          _categories.length,
                    );
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    _moveCategoryFocus(
                      (_focusedCategoryIndex + 1) % _categories.length,
                    );
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    setState(() {
                      _isCategoryFocused = false;
                      if (_isTvLayout(context)) {
                        _categoryPanelVisible = false;
                      }
                    });
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                    _changeCategory(_categories[_focusedCategoryIndex]);
                    return KeyEventResult.handled;
                  }
                } else {
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    _moveFocus(
                      (_focusedChannelIndex - 1 + _channels.length) %
                          _channels.length,
                    );
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    _moveFocus(
                      (_focusedChannelIndex + 1) % _channels.length,
                    );
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    if (_isTvLayout(context) && !_categoryPanelVisible) {
                      _revealCategoryPanel();
                    } else {
                      setState(() => _isCategoryFocused = true);
                    }
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                    _activateFocusedChannel();
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    _closeChannelSelector(showInfo: true);
                    return KeyEventResult.handled;
                  }
                }
              } else if (_showChannelInfo) {
                if (_isActivateKey(event.logicalKey)) {
                  _handleOkPress();
                  return KeyEventResult.handled;
                }
                if (_handleChromeVerticalNav(event.logicalKey)) {
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                    event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  if (_hasBottomChromeFocus) {
                    return KeyEventResult.ignored;
                  }
                  _focusDefaultBottomChromeControl();
                  return KeyEventResult.handled;
                }
              } else {
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  unawaited(_switchToChannelByOffset(-1));
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  unawaited(_switchToChannelByOffset(1));
                  return KeyEventResult.handled;
                }
                if (_isActivateKey(event.logicalKey)) {
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
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: _hasError
                        ? _buildErrorScreen()
                        : IgnorePointer(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                SizedBox.expand(child: player.buildView()),
                                if (player.shouldShowLoading)
                                  const Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                  if (!_hasError &&
                      !_showChannelInfo &&
                      !_showChannelSelector)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _onPlayerTap,
                        behavior: HitTestBehavior.translucent,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  Positioned.fill(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (_showAspectHint) _buildAspectRatioHint(),
                        if (_showChannelSelector) ...[
                          _buildChannelSelector(),
                          _buildChannelListDismissArea(),
                        ],
                        if (!_hasError &&
                            _showChannelInfo &&
                            !_showChannelSelector)
                          _buildPlayerControlsBar(),
                        if (_showPlayerChrome) _buildTopBackButton(),
                      ],
                    ),
                  ),
                ],
              ),
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
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(25),
                      child: Opacity(
                        opacity: 0.9,
                        child: Image.asset('assets/icon.png'),
                      ),
                    ),
                    const SizedBox(height: 60),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        l10n.translate('error_channel').toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: l10n.locale.languageCode == 'ku'
                              ? FontWeight.bold
                              : FontWeight.w200,
                          letterSpacing:
                              l10n.locale.languageCode == 'ku' ? 0 : 8.0,
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
                          letterSpacing:
                              l10n.locale.languageCode == 'ku' ? 0 : 1.5,
                          fontFamily: 'K24Kurdish',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Focus(
                      autofocus: true,
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            (event.logicalKey == LogicalKeyboardKey.select ||
                                event.logicalKey == LogicalKeyboardKey.enter)) {
                          unawaited(_retryCurrentChannel());
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Builder(
                        builder: (context) {
                          final isFocused = Focus.of(context).hasFocus;
                          return GestureDetector(
                            onTap: () => unawaited(_retryCurrentChannel()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                color: isFocused
                                    ? AppTheme.primaryColor
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isFocused
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.15),
                                  width: isFocused ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                l10n.translate('error_try_again').toUpperCase(),
                                style: TextStyle(
                                  color: isFocused ? Colors.black : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 3.0,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _exitPlayer,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                              width: 1,
                            ),
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
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _switchToChannelByOffset(int delta) async {
    if (_channels.length <= 1) return;
    final nextIndex =
        (_currentChannelIndex + delta + _channels.length) % _channels.length;
    await _switchToChannel(_channels[nextIndex]);
    _showChannelInfoOverlay();
  }

  Widget _buildPlayerControlsBar() {
    final categoryLabel = _currentChannel.category.trim();
    final categoryColor = categoryLabel.isNotEmpty
        ? AppTheme.getCategoryColor(categoryLabel)
        : AppTheme.textSecondary;
    final channelPosition = _channels.length > 1
        ? '${_currentChannelIndex + 1} / ${_channels.length}'
        : null;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      bottom: _showChannelInfo ? 0 : -160,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        elevation: 12,
        child: IgnorePointer(
          ignoring: !_showChannelInfo,
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                return Consumer<ChannelsProvider>(
                  builder: (context, channelsProvider, _) {
                    final isFavorite =
                        channelsProvider.isFavorite(_currentChannel.id);
                    final l10n = AppLocalizations.of(context);
                    return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.cardColor),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 4,
                          color: categoryColor,
                        ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  compact ? 14 : 18,
                                  compact ? 14 : 16,
                                  compact ? 12 : 16,
                                  compact ? 14 : 16,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _buildChannelInfoLogo(compact),
                                    SizedBox(width: compact ? 12 : 16),
                                    Expanded(
                                      child: _buildChannelInfoText(
                                        compact: compact,
                                        categoryLabel: categoryLabel,
                                        categoryColor: categoryColor,
                                        channelPosition: channelPosition,
                                      ),
                                    ),
                                    SizedBox(width: compact ? 8 : 12),
                                    _buildControlActionButton(
                                      icon: isFavorite
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      label: l10n.translate('favorites'),
                                      compact: compact,
                                      focusNode: _favoriteFocusNode,
                                      idleIconColor: isFavorite
                                          ? AppTheme.accentRed
                                          : null,
                                      idleBackgroundColor: isFavorite
                                          ? AppTheme.accentRed
                                              .withValues(alpha: 0.14)
                                          : null,
                                      onTap: () => _toggleChannelFavorite(
                                        channelsProvider,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildControlActionButton(
                                      icon: Icons.aspect_ratio_rounded,
                                      label: _aspectLabels[_aspectRatioIndex],
                                      compact: compact,
                                      focusNode: _aspectRatioFocusNode,
                                      onTap: () {
                                        _cycleAspectRatio();
                                        _startHideChannelInfoTimer();
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    _buildControlActionButton(
                                      icon: Icons.grid_view_rounded,
                                      label: 'Channels',
                                      compact: compact,
                                      focusNode: _channelsFocusNode,
                                      onTap: _openChannelSelector,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelInfoLogo(bool compact) {
    final size = compact ? 54.0 : 72.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.textTertiary.withValues(alpha: 0.35)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _currentChannel.logo.isNotEmpty
            ? ChannelLogo(
                logo: _currentChannel.logo,
                width: size,
                height: size,
                fit: BoxFit.cover,
                memCacheWidth: 220,
                fallback: Icon(Icons.live_tv_rounded, color: Colors.white54, size: size * 0.42),
              )
            : Center(
                child: Icon(Icons.live_tv_rounded, color: Colors.white54, size: size * 0.42),
              ),
      ),
    );
  }

  Widget _buildChannelInfoText({
    required bool compact,
    required String categoryLabel,
    required Color categoryColor,
    required String? channelPosition,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _buildLiveBadge(),
            if (channelPosition != null) ...[
              const SizedBox(width: 8),
              _buildMetaChip(
                icon: Icons.swap_vert_rounded,
                label: channelPosition,
                color: AppTheme.textSecondary,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _currentChannel.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 19 : 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            height: 1.1,
          ),
        ),
        if (categoryLabel.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildMetaChip(
            icon: Icons.category_rounded,
            label: categoryLabel.toUpperCase(),
            color: categoryColor,
          ),
        ],
      ],
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.accentRed.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppTheme.accentRed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentRed.withValues(alpha: 0.75),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withValues(alpha: 0.95)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool compact = false,
    FocusNode? focusNode,
    Color? idleIconColor,
    Color? idleBackgroundColor,
  }) {
    return Focus(
      focusNode: focusNode,
      canRequestFocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter ||
            event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA) {
          onTap();
          return KeyEventResult.handled;
        }
        if (_handleChromeVerticalNav(event.logicalKey)) {
          return KeyEventResult.handled;
        }
        if (_handleChromeHorizontalNav(event.logicalKey)) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          final contentColor =
              isFocused ? Colors.black : (idleIconColor ?? Colors.white);
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 14,
                vertical: compact ? 10 : 12,
              ),
              decoration: BoxDecoration(
                color: isFocused
                    ? Colors.white
                    : (idleBackgroundColor ?? AppTheme.cardColor),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isFocused ? Colors.white : AppTheme.textTertiary,
                  width: isFocused ? 2.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: contentColor, size: compact ? 17 : 18),
                  if (!compact) ...[
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: contentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
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

  static const double _channelListWidthFull = 420;
  static const double _channelListWidthCompact = 300;
  static const Color _channelListBackground = Color(0xFF141414);

  Widget _buildChannelListDismissArea() {
    return Positioned(
      left: _channelSelectorWidth(context),
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
    final isTv = _isTvLayout(context);
    final showCategories = !isTv || _categoryPanelVisible;
    final showCategoryHint = isTv && !_categoryPanelVisible;
    final l10n = AppLocalizations.of(context);

    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: _channelSelectorWidth(context),
        child: Container(
          color: _channelListBackground,
          child: SafeArea(
            left: false,
            right: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showCategoryHint) _buildCategoryRevealHint(l10n),
                if (showCategories) ...[
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 12, 6, 10),
                          child: Text(
                            l10n.translate('categories').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: _categoryScrollController,
                            padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                            itemCount: _categories.length,
                            itemBuilder: (context, index) {
                              final category = _categories[index];
                              final isFocused = _isCategoryFocused &&
                                  index == _focusedCategoryIndex;
                              final isSelected = category == _selectedCategory;
                              return _buildCategoryItem(
                                category,
                                isFocused,
                                isSelected,
                                index,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, color: Colors.white24),
                ],
                Expanded(
                  flex: showCategories ? 3 : 1,
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
                            final isFocused = !_isCategoryFocused &&
                                index == _focusedChannelIndex;

                            return GestureDetector(
                              onTap: () {
                                if (_isCategoryFocused) {
                                  setState(() => _isCategoryFocused = false);
                                }
                                _moveFocus(index);
                                _activateFocusedChannel();
                              },
                              child: _buildChannelItem(channel, isFocused),
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
      ),
    );
  }

  Widget _buildCategoryRevealHint(AppLocalizations l10n) {
    return Container(
      width: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: const Border(
          right: BorderSide(color: Colors.white24),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chevron_left_rounded,
            color: Colors.white.withOpacity(0.55),
            size: 22,
          ),
          const SizedBox(height: 10),
          RotatedBox(
            quarterTurns: 3,
            child: Text(
              l10n.translate('categories').toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(
    String category,
    bool isFocused,
    bool isSelected,
    int index,
  ) {
    final highlighted = isFocused || isSelected;
    return GestureDetector(
      onTap: () {
        _moveCategoryFocus(index);
        _changeCategory(category);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        height: 48,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isFocused ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFocused
                ? Colors.white
                : (isSelected ? Colors.white54 : Colors.white24),
            width: isFocused ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: highlighted
                    ? (isFocused ? Colors.black87 : Colors.white)
                    : Colors.white38,
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
                  color: isFocused ? Colors.black : Colors.white,
                  fontWeight: highlighted ? FontWeight.w900 : FontWeight.w600,
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

  Widget _buildChannelItem(Channel channel, bool isFocused) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 66,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isFocused ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFocused ? Colors.white : Colors.white24,
          width: isFocused ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isFocused ? Colors.grey.shade100 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isFocused ? Colors.black12 : Colors.transparent,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ChannelLogo(
                logo: channel.logo,
                width: 48,
                height: 48,
                fit: BoxFit.contain,
                fallback: Icon(
                  Icons.tv,
                  color: isFocused ? Colors.black45 : Colors.grey,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              channel.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isFocused ? Colors.black : Colors.white,
                fontSize: 14,
                fontWeight: isFocused ? FontWeight.w800 : FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

