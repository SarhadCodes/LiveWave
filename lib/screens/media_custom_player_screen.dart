import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:live_wave/config/app_theme.dart';
import 'package:live_wave/services/subtitle_service.dart';
import 'package:live_wave/services/firestore_service.dart';
import 'package:live_wave/utils/platform_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MediaCustomPlayerScreen extends StatefulWidget {
  final int? tmdbId;
  final bool isMovie;
  final String title;
  final String? seriesTitle;
  final int? season;
  final int? episode;
  final int? releaseYear;
  final String? customUrl;
  final String? customSubtitleUrl;

  const MediaCustomPlayerScreen({
    super.key,
    this.tmdbId,
    required this.isMovie,
    required this.title,
    this.seriesTitle,
    this.season,
    this.episode,
    this.releaseYear,
    this.customUrl,
    this.customSubtitleUrl,
  });

  @override
  State<MediaCustomPlayerScreen> createState() => _MediaCustomPlayerScreenState();
}

class _MediaCustomPlayerScreenState extends State<MediaCustomPlayerScreen> {
  // Native Bridge
  MethodChannel? _nativeChannel;
  static const _utilsChannel = MethodChannel('com.livewave.player/utils');
  int _viewId = 0;
  
  // State
  bool _isLoading = true;
  String _statusMessage = 'INITIALIZING...';
  bool _showControls = true;
  Timer? _hideTimer;
  
  // Playback State
  bool _isPlaying = true;
  int _positionMs = 0;
  int _durationMs = 0;
  String? _videoUrl;
  String? _subtitleUrl;

  // Subtitle Engine
  List<SubtitleLine> _allSubtitles = [];
  SubtitleLine? _currentSubtitle;
  String _nextSubCountdown = '';
  bool _subtitleEnabled = true;
  double _subtitleSize = 22.0;
  double _subtitleBgOpacity = 0.0; 
  String _decoderMode = 'hardware';
  String _surfaceType = 'surface';
  double _subtitleDelay = 0.0;
  bool _hardwareAcceleration = true;
  Timer? _positionTimer;
  bool _isExiting = false;
  
  // Settings UI State
  bool _showSettings = false;
  bool _showSyncSettings = false;
  int _selectedSettingIndex = 0;
  
  // Temporary staging variables
  double _tempDelay = 0.0;
  double _tempSize = 22.0;
  double _tempBg = 0.0;
  String _tempDecoder = 'hardware';
  String _tempSurface = 'surface';
  bool _tempHW = true;
  
  final List<String> _sizeLabels = ['Small', 'Normal', 'Large', 'Extra'];
  final List<double> _sizeValues = [16.0, 22.0, 28.0, 36.0];
  
  final List<String> _bgLabels = ['OFF', 'Low', 'Med', 'High'];
  final List<double> _bgValues = [0.0, 0.3, 0.6, 0.9];

  final List<String> _decoderLabels = ['Hardware', 'Software'];
  final List<String> _decoderValues = ['hardware', 'software'];

  final List<String> _surfaceLabels = ['Surface', 'Texture'];
  final List<String> _surfaceValues = ['surface', 'texture'];

  int _aspectRatioIndex = 0;
  int _tempAspectRatioIndex = 0;
  final List<String> _aspectLabels = ['Auto', '16:9', '4:3', 'Stretch', 'Zoom'];
  final List<String> _aspectValues = ['FIT', '16_9', '4_3', 'FILL', 'ZOOM'];

  // Extractor
  WebViewController? _extractorController;
  final FirestoreService _firestoreService = FirestoreService();
  
  // Smart Search State
  final List<String> _servers = [
    'https://www.vidking.net',
    'https://vidsrc.me',
    'https://vidsrc.to',
    'https://autoembed.co',
  ];
  int _currentServerIndex = 0;
  Timer? _serverTimeoutTimer;

  // Focus Management for TV
  final FocusNode _mainUIFocusNode = FocusNode(debugLabel: 'mainUI');
  final FocusScopeNode _settingsFocusNode = FocusScopeNode(debugLabel: 'settings');
  final FocusNode _playButtonFocusNode = FocusNode(debugLabel: 'playBtn');
  final FocusNode _sliderFocusNode = FocusNode(debugLabel: 'slider');
  final FocusNode _firstRowFocusNode = FocusNode(debugLabel: 'firstRow');
  final FocusNode _firstSyncRowFocusNode = FocusNode(debugLabel: 'firstSyncRow');

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _loadSavedSettings();
    
    // Request initial focus for TV navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mainUIFocusNode.requestFocus();
    });

    _startPlaybackSequence();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _subtitleSize = prefs.getDouble('player_subtitleSize') ?? 22.0;
      _subtitleBgOpacity = prefs.getDouble('player_subtitleBg') ?? 0.0;
      _decoderMode = prefs.getString('player_decoder') ?? 'hardware';
      _surfaceType = prefs.getString('player_surface') ?? 'surface';
      _aspectRatioIndex = prefs.getInt('player_aspectRatio') ?? 0;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('player_subtitleSize', _subtitleSize);
    prefs.setDouble('player_subtitleBg', _subtitleBgOpacity);
    prefs.setString('player_decoder', _decoderMode);
    prefs.setString('player_surface', _surfaceType);
    prefs.setInt('player_aspectRatio', _aspectRatioIndex);
  }

  Future<void> _startPlaybackSequence() async {
    if (widget.customUrl != null && widget.customUrl!.isNotEmpty) {
      _videoUrl = widget.customUrl;
      _subtitleUrl = widget.customSubtitleUrl;
      _onMediaFound();
      return;
    }

    if (widget.tmdbId == null) return;

    setState(() => _statusMessage = 'PROBING FAST SERVERS...');
    final baseServers = [
      '154.48.204.98/Flussonic251',
      '130.193.165.194/Flussonic247',
      '130.193.166.197/nasstore',
      '130.193.166.118/sss'
    ];

    final rawTitle = (widget.isMovie ? widget.title : (widget.seriesTitle ?? widget.title));
    final variations = <String>{
      rawTitle.trim(),
      rawTitle.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()
    };
    
    final cleanAlpha = variations.last;
    if (cleanAlpha.isNotEmpty) {
      variations.add(cleanAlpha.replaceAll(' ', ''));
      variations.add(cleanAlpha.replaceAll(' ', '.'));
      variations.add(cleanAlpha.replaceAll(' ', '-'));
      variations.add(cleanAlpha.replaceAll(' ', '_'));
      variations.add(cleanAlpha.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1).toLowerCase() : '').join(''));
      
      if (widget.releaseYear != null) {
        variations.add('$cleanAlpha ${widget.releaseYear}');
        variations.add('$cleanAlpha.${widget.releaseYear}');
        variations.add('${cleanAlpha.replaceAll(' ', '.')}.${widget.releaseYear}');
      }
    }
    
    // Most common case is exact match or dots. Order variations intelligently.
    final uniqueVariations = variations.expand((v) => [v, v.toLowerCase(), v.toUpperCase()]).toSet().toList();

    // 1. Build all possible URLs ordered by priority
    List<String> videoUrlsToTry = [];
    for (var host in baseServers) {
      for (var titleVar in uniqueVariations) {
        if (widget.isMovie) {
          final year = widget.releaseYear ?? 2025;
          for (var y in [year, year - 1, year + 1]) {
            videoUrlsToTry.add('http://$host/EnglishMovies1/$y/$titleVar-NoSub.mp4');
            videoUrlsToTry.add('http://$host/EnglishMovies/$y/$titleVar-NoSub.mp4');
          }
          // From servers.md: Some movies are in "OTHER" folder
          videoUrlsToTry.add('http://$host/EnglishMovies1/OTHER/$titleVar-NoSub.mp4');
          videoUrlsToTry.add('http://$host/EnglishMovies/OTHER/$titleVar-NoSub.mp4');
        } else {
          final s = widget.season.toString().padLeft(2, '0');
          final e = widget.episode.toString().padLeft(2, '0');
          videoUrlsToTry.add('http://$host/EnglishTvSeries1/$titleVar-S${s}E$e.mp4');
          videoUrlsToTry.add('http://$host/EnglishTvSeries/$titleVar-S${s}E$e.mp4');
          videoUrlsToTry.add('http://$host/EnglishTvSeries1/$titleVar.S${s}E$e.mp4');
          videoUrlsToTry.add('http://$host/EnglishTvSeries/$titleVar.S${s}E$e.mp4');
        }
      }
    }

    // 2. Fast Batch Probing (Abort instantly when found)
    String? foundVideoUrl;
    const batchSize = 25; // Try 25 URLs at a time to prevent socket exhaustion
    
    for (int i = 0; i < videoUrlsToTry.length; i += batchSize) {
      if (foundVideoUrl != null) break;
      
      final chunk = videoUrlsToTry.sublist(i, (i + batchSize > videoUrlsToTry.length) ? videoUrlsToTry.length : i + batchSize);
      
      final chunkResults = await Future.wait(chunk.map((url) async {
        try {
          final res = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 2));
          if (res.statusCode == 200) return url;
        } catch (_) {}
        return null;
      }));
      
      foundVideoUrl = chunkResults.firstWhere((r) => r != null, orElse: () => null);
    }

    // 3. If video is found, find the matching subtitle in the same folder
    if (foundVideoUrl != null) {
      String? foundSubtitleUrl;
      final uri = Uri.parse(foundVideoUrl);
      
      // CRITICAL FIX: We need to preserve the host AND the base path (e.g., /Flussonic247)
      // The video paths always contain "English", so we split there to get the prefix.
      final String fullBaseUrl = "${uri.scheme}://${uri.host}${uri.path.split('/English')[0]}";
      
      final pathSegments = uri.pathSegments;
      final vName = pathSegments.last.replaceAll('.mp4', '');
      
      // Check the exact same folder first
      final String currentFolderUrl = foundVideoUrl.substring(0, foundVideoUrl.lastIndexOf('/') + 1);
      
      List<String> subUrlsToTry = [
        '${currentFolderUrl}${vName}.srt',
        '${currentFolderUrl}${vName}.mp4.srt'
      ];
      
      // Fallback subtitle paths
      if (widget.isMovie) {
        final titleVar = vName.replaceAll('-NoSub', '');
        final year = widget.releaseYear ?? 2025;
        subUrlsToTry.addAll([
          '$fullBaseUrl/EnglishMovies-Subtitle/Ku/$year/$titleVar-Ku.srt',
          '$fullBaseUrl/EnglishMovies-Subtitle/Ku/$year/$titleVar.srt',
          '$fullBaseUrl/EnglishMovies-Subtitle/Ku/OTHER/$titleVar-Ku.srt',
          '$fullBaseUrl/EnglishMovies1/$year/$titleVar.srt',
          '$fullBaseUrl/EnglishMovies1/OTHER/$titleVar.srt',
        ]);
      } else {
        final s = widget.season.toString().padLeft(2, '0');
        final e = widget.episode.toString().padLeft(2, '0');
        // Use uniqueVariations (defined earlier) to try all possible series name variations
        for (var tVar in uniqueVariations) {
          subUrlsToTry.addAll([
            '$fullBaseUrl/EnglishTvSeries-Subtitle/Ku/$tVar-Ku-S${s}E$e.srt',
            '$fullBaseUrl/EnglishTvSeries-Subtitle/Ku/$tVar-S${s}E$e.srt',
            '$fullBaseUrl/EnglishTvSeries1/$tVar-S${s}E$e.srt',
            '$fullBaseUrl/EnglishTvSeries1/$tVar.S${s}E$e.srt',
            '$fullBaseUrl/EnglishTvSeries/$tVar.S${s}E$e.srt',
            '$fullBaseUrl/EnglishTvSeries/$tVar-S${s}E$e.srt',
          ]);
        }
      }

      for (var subUrl in subUrlsToTry) {
        try {
          final res = await http.get(Uri.parse('$subUrl?t=${DateTime.now().millisecondsSinceEpoch}'), headers: {'Range': 'bytes=0-1024'}).timeout(const Duration(seconds: 3));
          if (res.statusCode == 200 || res.statusCode == 206) {
            foundSubtitleUrl = subUrl;
            break;
          }
        } catch (_) {}
      }

      _videoUrl = foundVideoUrl;
      _subtitleUrl = foundSubtitleUrl ?? '';
      _onMediaFound();
      return;
    }

    setState(() => _statusMessage = 'CHECKING OVERRIDES...');
    final override = await _firestoreService.getMediaOverride(widget.tmdbId!, isMovie: widget.isMovie);
    if (override != null) {
      if (widget.isMovie) {
        _videoUrl = override['url'];
        _subtitleUrl = override['srtUrl'];
      } else {
        final seasonKey = 's${widget.season}';
        final episodeKey = 'e${widget.episode}';
        final seasonData = override[seasonKey];
        if (seasonData != null && seasonData[episodeKey] != null) {
          _videoUrl = seasonData[episodeKey]['url'];
          _subtitleUrl = seasonData[episodeKey]['srtUrl'];
        }
      }
      if (_videoUrl != null) {
        _onMediaFound();
        return;
      }
    }

    _startSmartServerSearch();
  }

  void _startSmartServerSearch() {
    _serverTimeoutTimer?.cancel();
    
    if (_currentServerIndex >= _servers.length) {
      if (mounted) setState(() => _statusMessage = 'NO STREAMS FOUND. TRY LATER.');
      return;
    }

    final baseUrl = _servers[_currentServerIndex];
    final url = widget.isMovie
        ? '$baseUrl/embed/movie/${widget.tmdbId}?autoPlay=true'
        : '$baseUrl/embed/tv/${widget.tmdbId}/${widget.season}/${widget.episode}?autoPlay=true';

    setState(() => _statusMessage = 'SEARCHING SERVER ${_currentServerIndex + 1}/${_servers.length}...');

    _extractorController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('Extractor', onMessageReceived: (msg) {
        try {
          final data = jsonDecode(msg.message);
          if (data['url'] != null && _videoUrl == null) {
            _serverTimeoutTimer?.cancel();
            setState(() { _videoUrl = data['url']; _isLoading = false; });
            _onMediaFound();
          }
        } catch (_) {}
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          _extractorController?.runJavaScript('''
            setInterval(() => {
              try {
                // 1. Network Sniffer: Check browser network logs for m3u8 streams
                const resources = performance.getEntriesByType('resource');
                for(let r of resources) {
                  if(r.name.includes('.m3u8') || (r.name.includes('.mp4') && !r.name.includes('blank.mp4'))) {
                     Extractor.postMessage(JSON.stringify({url: r.name}));
                     return;
                  }
                }
                
                // 2. DOM Sniffer: Check HTML5 video elements and sources
                const vids = document.querySelectorAll('video');
                for(let v of vids) {
                  if(v.src && (v.src.includes('.m3u8') || v.src.includes('.mp4')) && !v.src.includes('blob:')) {
                    Extractor.postMessage(JSON.stringify({url: v.src}));
                    return;
                  }
                  const sources = v.querySelectorAll('source');
                  for(let s of sources) {
                    if(s.src && (s.src.includes('.m3u8') || s.src.includes('.mp4')) && !s.src.includes('blob:')) {
                      Extractor.postMessage(JSON.stringify({url: s.src}));
                      return;
                    }
                  }
                }
              } catch(e) {}
            }, 1000);
          ''');
        }
      ))
      ..loadRequest(Uri.parse(url));

    // Fallback to next server if this one fails after 12 seconds
    _serverTimeoutTimer = Timer(const Duration(seconds: 12), () {
      if (_videoUrl == null && mounted) {
        _currentServerIndex++;
        _startSmartServerSearch();
      }
    });
  }

  void _onMediaFound() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _statusMessage = 'READY';
    });
    _startHideTimer();
    _startPositionTimer();
    _loadSubtitleFile();
  }

  Future<void> _loadSubtitleFile() async {
    if (_subtitleUrl != null && _subtitleUrl!.isNotEmpty) {
      setState(() => _statusMessage = 'DOWNLOADING KURDISH SUBS...');
      try {
        final track = SubtitleTrack(language: 'Kurdish', languageId: 'ku', fileName: 'primary.srt', downloadUrl: _subtitleUrl!, format: 'srt');
        final filePath = await SubtitleService.downloadAndExtractSubtitle(track);
        if (filePath != null) {
          final lines = await SubtitleService.parseSrt(filePath);
          if (lines.isNotEmpty) {
            setState(() { 
              _allSubtitles = lines; 
              _statusMessage = 'SUBS LOADED: ${lines.length} LINES';
            });
            return;
          }
        }
      } catch (e) {
        setState(() => _statusMessage = 'SUB DOWNLOAD ERROR');
      }
    }

    try {
      final results = widget.isMovie
          ? await SubtitleService.getMovieSubtitles(widget.tmdbId!, widget.title, releaseYear: widget.releaseYear)
          : await SubtitleService.getTvShowSubtitles(widget.tmdbId!, widget.seriesTitle ?? widget.title, season: widget.season, episode: widget.episode);
      final foundKurdish = results.where((t) => t.language.toLowerCase().contains('kurd')).toList();
      if (foundKurdish.isNotEmpty) {
        final filePath = await SubtitleService.downloadAndExtractSubtitle(foundKurdish.first);
        if (filePath != null) {
          final lines = await SubtitleService.parseSrt(filePath);
          setState(() => _allSubtitles = lines);
        }
      }
    } catch (_) {}
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted || _allSubtitles.isEmpty) return;
      
      // Use _positionMs which is already updated by native onPlayerStatus callback
      final int currentMs = _positionMs + (_subtitleDelay * 1000).toInt();
      
      SubtitleLine? active;
      for (int i = 0; i < _allSubtitles.length; i++) {
        final s = _allSubtitles[i].start.inMilliseconds;
        final e = _allSubtitles[i].end.inMilliseconds;
        if (currentMs >= s - 500 && currentMs <= e + 300) {
          active = _allSubtitles[i];
          break;
        }
      }
      
      if (_currentSubtitle != active) {
        setState(() => _currentSubtitle = active);
      }
    });
  }

  void _onPlatformViewCreated(int id) {
    _viewId = id;
    _nativeChannel = MethodChannel('com.livewave.player/exoplayer_$id');
    _nativeChannel!.setMethodCallHandler(_handleNativeCallback);
    if (_videoUrl != null) {
      _nativeChannel!.invokeMethod('play', {
        'url': _videoUrl,
        'subtitleUrl': null,
        'headers': {'User-Agent': 'Mozilla/5.0'},
      });
      _nativeChannel!.invokeMethod('setAspectRatio', {
        'ratio': _aspectValues[_aspectRatioIndex],
      });
    }
    // Safe focus trigger
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mainUIFocusNode.requestFocus();
    });
  }

  Future<void> _handleNativeCallback(MethodCall call) async {
    if (call.method == 'onPlayerStatus') {
      final args = Map<String, dynamic>.from(call.arguments);
      if (mounted) {
        setState(() {
          _positionMs = args['position'] ?? 0;
          _durationMs = args['duration'] ?? 0;
          _statusMessage = args['status'] ?? 'ready';
          _isPlaying = (_statusMessage != 'buffering' && _statusMessage != 'ended');
        });
      }
    }
  }

  void _togglePlay() {
    if (_isPlaying) {
      _nativeChannel?.invokeMethod('pause');
    } else {
      _nativeChannel?.invokeMethod('resume');
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  void _seek(double value) {
    _nativeChannel?.invokeMethod('seekTo', {'position': value.toInt()});
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _hideTimer?.cancel();
    _positionTimer?.cancel();
    _serverTimeoutTimer?.cancel();
    _nativeChannel?.invokeMethod('dispose');
    
    _mainUIFocusNode.dispose();
    _settingsFocusNode.dispose();
    _playButtonFocusNode.dispose();
    _sliderFocusNode.dispose();
    
    if (PlatformDetector.isTV) {
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
    super.dispose();
  }

  Future<void> _confirmExit() async {
    if (_isExiting) return;
    setState(() => _isExiting = true);
    
    final wasPlaying = _isPlaying;
    if (_isPlaying) _nativeChannel?.invokeMethod('pause');

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return FocusScope(
          autofocus: true,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Exit Player', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: const Text('Are you sure you want to stop watching?', style: TextStyle(color: Colors.white70)),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(child: _buildActionButton('No', Colors.white12, Colors.white, () => Navigator.pop(context, false), onBack: () => Navigator.pop(context, false))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildActionButton('Yes', AppTheme.primaryColor, Colors.black, () => Navigator.pop(context, true), onBack: () => Navigator.pop(context, false))),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      if (mounted) Navigator.pop(context);
    } else {
      if (wasPlaying) _nativeChannel?.invokeMethod('resume');
      // CRITICAL: Restore focus to player UI if user stayed
      _mainUIFocusNode.requestFocus();
    }
    if (mounted) setState(() => _isExiting = false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_showSettings) {
          _closeSettings();
        } else {
          _confirmExit();
        }
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (!_isLoading && _videoUrl != null)
            _buildOverriddenPlayer(),
          if (_isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primaryColor),
                  const SizedBox(height: 24),
                  Text(_statusMessage.toUpperCase(), style: const TextStyle(color: Colors.white70, letterSpacing: 2)),
                ],
              ),
            ),
          if (!_isLoading) _buildFlutterUI(),
          
          if (_showSettings) _buildPremiumSettings(),
          
          // SUBTITLE OVERLAY - hidden when settings are open
          if (!_isLoading && _subtitleEnabled && _currentSubtitle != null && !_showSettings)
            Positioned(
              bottom: _showControls || _showSettings ? 150 : 60, left: 0, right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(_subtitleBgOpacity),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _currentSubtitle!.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _subtitleSize,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'K24Kurdish',
                        height: 1.4,
                        shadows: const [
                          Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black),
                          Shadow(offset: Offset(-1, -1), blurRadius: 3, color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}



  void _openSettings() {
    _nativeChannel?.invokeMethod('pause');
    setState(() {
      _tempSize = _subtitleSize;
      _tempBg = _subtitleBgOpacity;
      _tempDecoder = _decoderMode;
      _tempSurface = _surfaceType;
      _showSettings = true;
      _showControls = true;
      _isPlaying = false;
    });
    _hideTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firstRowFocusNode.requestFocus();
    });
  }

  void _closeSettings() {
    _nativeChannel?.invokeMethod('resume');
    setState(() {
      _showSettings = false;
      _isPlaying = true;
    });
    _mainUIFocusNode.requestFocus();
    _startHideTimer();
  }

  void _applySettings() {
    final oldDecoder = _decoderMode;
    final oldSurface = _surfaceType;
    setState(() {
      _subtitleSize = _tempSize;
      _subtitleBgOpacity = _tempBg;
      _decoderMode = _tempDecoder;
      _surfaceType = _tempSurface;
      _showSettings = false;
      _isPlaying = true;
    });
    _saveSettings();
    if (oldDecoder != _decoderMode || oldSurface != _surfaceType) {
      _startPlaybackSequence();
    } else {
      _nativeChannel?.invokeMethod('resume');
    }
    _mainUIFocusNode.requestFocus();
    _startHideTimer();
  }

  void _openSyncSettings() {
    _nativeChannel?.invokeMethod('pause');
    setState(() {
      _tempDelay = _subtitleDelay;
      _tempAspectRatioIndex = _aspectRatioIndex;
      _showSyncSettings = true;
      _showControls = true;
      _isPlaying = false;
    });
    _hideTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firstSyncRowFocusNode.requestFocus();
    });
  }

  void _closeSyncSettings() {
    _nativeChannel?.invokeMethod('resume');
    setState(() {
      _showSyncSettings = false;
      _isPlaying = true;
    });
    _mainUIFocusNode.requestFocus();
    _startHideTimer();
  }

  void _applySyncSettings() {
    _nativeChannel?.invokeMethod('resume');
    _nativeChannel?.invokeMethod('setAspectRatio', {
      'ratio': _aspectValues[_tempAspectRatioIndex],
    });
    setState(() {
      _subtitleDelay = _tempDelay;
      _aspectRatioIndex = _tempAspectRatioIndex;
      _showSyncSettings = false;
      _isPlaying = true;
    });
    _mainUIFocusNode.requestFocus();
    _startHideTimer();
  }

  Widget _buildSyncSettings() {
    return Positioned.fill(
      child: FocusScope(
        node: _settingsFocusNode,
        autofocus: true,
        child: GestureDetector(
          onTap: _closeSyncSettings,
          child: Container(
            color: Colors.black.withValues(alpha: 0.7),
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 340,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.subtitles_rounded, color: Colors.white70, size: 22),
                            SizedBox(width: 12),
                            Text('Subtitle Sync', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      _buildSettingRow(
                        icon: Icons.timer_rounded,
                        label: 'Sync Delay',
                        value: '${_tempDelay >= 0 ? '+' : ''}${_tempDelay.toStringAsFixed(1)}s',
                        onLeft: () { if (_tempDelay > -10.0) setState(() => _tempDelay -= 0.5); },
                        onRight: () { if (_tempDelay < 10.0) setState(() => _tempDelay += 0.5); },
                        focusNode: _firstSyncRowFocusNode,
                        onBack: _closeSyncSettings,
                      ),
                      _buildClickableRow(
                        icon: Icons.refresh_rounded,
                        label: 'Reset Delay Now',
                        onTap: () => setState(() => _tempDelay = 0.0),
                        onBack: _closeSyncSettings,
                      ),
                      _buildSettingRow(
                        icon: Icons.aspect_ratio_rounded,
                        label: 'Aspect Ratio',
                        value: _aspectLabels[_tempAspectRatioIndex],
                        onLeft: () { if (_tempAspectRatioIndex > 0) setState(() => _tempAspectRatioIndex--); },
                        onRight: () { if (_tempAspectRatioIndex < _aspectLabels.length - 1) setState(() => _tempAspectRatioIndex++); },
                        onBack: _closeSyncSettings,
                      ),
                      Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 20), color: Colors.white.withValues(alpha: 0.06)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Row(
                          children: [
                            Expanded(child: _buildActionButton('Apply', const Color(0xFF2A2A2A), Colors.white70, _applySyncSettings, onBack: _closeSyncSettings)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildActionButton('Cancel', const Color(0xFF2A2A2A), Colors.white70, _closeSyncSettings, onBack: _closeSyncSettings)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumSettings() {
    return Positioned.fill(
      child: FocusScope(
        node: _settingsFocusNode,
        autofocus: true,
        child: GestureDetector(
          onTap: _closeSettings,
          child: Container(
            color: Colors.black.withValues(alpha: 0.7),
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 340,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.tune, color: Colors.white70, size: 22),
                            SizedBox(width: 12),
                            Text('Settings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      _buildSettingRow(
                        icon: Icons.text_fields,
                        label: 'Text Size',
                        value: _sizeLabels[_sizeValues.indexOf(_tempSize).clamp(0, 3)],
                        onLeft: () { int i = _sizeValues.indexOf(_tempSize); if (i > 0) setState(() => _tempSize = _sizeValues[i - 1]); },
                        onRight: () { int i = _sizeValues.indexOf(_tempSize); if (i < _sizeValues.length - 1) setState(() => _tempSize = _sizeValues[i + 1]); },
                        focusNode: _firstRowFocusNode,
                        onBack: _closeSettings,
                      ),
                      _buildSettingRow(
                        icon: Icons.format_color_fill,
                        label: 'Background',
                        value: _bgLabels[_bgValues.indexOf(_tempBg).clamp(0, 3)],
                        onLeft: () { int i = _bgValues.indexOf(_tempBg); if (i > 0) setState(() => _tempBg = _bgValues[i - 1]); },
                        onRight: () { int i = _bgValues.indexOf(_tempBg); if (i < _bgValues.length - 1) setState(() => _tempBg = _bgValues[i + 1]); },
                        onBack: _closeSettings,
                      ),
                      _buildSettingRow(
                        icon: Icons.memory,
                        label: 'Decoder',
                        value: _decoderLabels[_decoderValues.indexOf(_tempDecoder).clamp(0, 1)],
                        onLeft: () { int i = _decoderValues.indexOf(_tempDecoder); if (i > 0) setState(() => _tempDecoder = _decoderValues[i - 1]); },
                        onRight: () { int i = _decoderValues.indexOf(_tempDecoder); if (i < _decoderValues.length - 1) setState(() => _tempDecoder = _decoderValues[i + 1]); },
                        onBack: _closeSettings,
                      ),
                      _buildSettingRow(
                        icon: Icons.layers,
                        label: 'Surface',
                        value: _surfaceLabels[_surfaceValues.indexOf(_tempSurface).clamp(0, 1)],
                        onLeft: () { int i = _surfaceValues.indexOf(_tempSurface); if (i > 0) setState(() => _tempSurface = _surfaceValues[i - 1]); },
                        onRight: () { int i = _surfaceValues.indexOf(_tempSurface); if (i < _surfaceValues.length - 1) setState(() => _tempSurface = _surfaceValues[i + 1]); },
                        onBack: _closeSettings,
                      ),
                      Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 20), color: Colors.white.withValues(alpha: 0.06)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Row(
                          children: [
                            Expanded(child: _buildActionButton('Apply', const Color(0xFF2A2A2A), Colors.white70, _applySettings, onBack: _closeSettings)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildActionButton('Cancel', const Color(0xFF2A2A2A), Colors.white70, _closeSettings, onBack: _closeSettings)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onLeft,
    required VoidCallback onRight,
    required VoidCallback onBack,
    FocusNode? focusNode,
  }) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) { onLeft(); return KeyEventResult.handled; }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) { onRight(); return KeyEventResult.handled; }
          if (event.logicalKey == LogicalKeyboardKey.escape || event.logicalKey == LogicalKeyboardKey.goBack || event.logicalKey == LogicalKeyboardKey.backspace) {
            onBack();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: GestureDetector(
              onTap: () => Focus.of(context).requestFocus(),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: hasFocus ? AppTheme.primaryColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasFocus ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.05),
                    width: hasFocus ? 3.5 : 1.5, // Even thicker for absolute clarity
                  ),
                  boxShadow: hasFocus ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 3,
                    )
                  ] : null,
                ),
                child: Row(
                children: [
                  Icon(icon, color: hasFocus ? AppTheme.primaryColor : Colors.white38, size: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(label, style: TextStyle(
                      color: hasFocus ? Colors.white : Colors.white70,
                      fontSize: 15,
                      fontWeight: hasFocus ? FontWeight.w600 : FontWeight.w400,
                    )),
                  ),
                  // Touch-friendly controls
                  GestureDetector(
                    onTap: onLeft,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.chevron_left, color: hasFocus ? Colors.white70 : Colors.white24, size: 20),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onRight,
                    child: Text(value, style: TextStyle(
                      color: hasFocus ? AppTheme.primaryColor : Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    )),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onRight,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.chevron_right, color: hasFocus ? Colors.white70 : Colors.white24, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        },
      ),
    );
  }

  Widget _buildClickableRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required VoidCallback onBack,
    bool autofocus = false,
  }) {
    return Focus(
      autofocus: autofocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter) {
            onTap();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape || event.logicalKey == LogicalKeyboardKey.goBack || event.logicalKey == LogicalKeyboardKey.backspace) {
            onBack();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: GestureDetector(
              onTap: () {
                Focus.of(context).requestFocus();
                onTap();
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: hasFocus ? AppTheme.primaryColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasFocus ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.05),
                    width: hasFocus ? 3.5 : 1.5,
                  ),
                  boxShadow: hasFocus ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ] : null,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: hasFocus ? AppTheme.primaryColor : Colors.white38, size: 20),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(label, style: TextStyle(
                        color: hasFocus ? Colors.white : Colors.white70,
                        fontSize: 15,
                        fontWeight: hasFocus ? FontWeight.w700 : FontWeight.w500,
                      )),
                    ),
                    if (hasFocus)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('OK', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton(String text, Color bgColor, Color textColor, VoidCallback onPressed, {required VoidCallback onBack}) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
          onPressed();
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.escape || event.logicalKey == LogicalKeyboardKey.goBack || event.logicalKey == LogicalKeyboardKey.backspace)) {
          onBack();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: hasFocus ? AppTheme.primaryColor : bgColor,
                borderRadius: BorderRadius.circular(12),
                border: hasFocus ? Border.all(color: Colors.white, width: 1.5) : Border.all(color: Colors.white12),
              ),
              child: Center(
                child: Text(text, style: TextStyle(
                  color: hasFocus ? Colors.black : textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                )),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverriddenPlayer() {
    final Widget player = AndroidView(
      key: ValueKey('player_${_decoderMode}_${_surfaceType}_${_aspectRatioIndex}'),
      viewType: 'exoplayer-view',
      creationParams: {
        "url": _videoUrl,
        "subtitleUrl": null,
        "decoderMode": _decoderMode,
        "surfaceType": _surfaceType,
        "aspectRatio": _aspectValues[_aspectRatioIndex],
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    );

    switch (_aspectRatioIndex) {
      case 1: // 16:9
        return Positioned.fill(child: Center(child: AspectRatio(aspectRatio: 16/9, child: player)));
      case 2: // 4:3
        return Positioned.fill(child: Center(child: AspectRatio(aspectRatio: 4/3, child: player)));
      case 3: // Stretch/Fill
        // To force stretch when native is FIT, we sometimes need to slightly overflow
        return Positioned.fill(child: player); 
      case 4: // Zoom
        return Positioned.fill(
          child: Transform.scale(
            scale: 1.2, // Zoom in to fill black bars
            child: player,
          ),
        );
      default: // Auto/Fit
        return Positioned.fill(child: player);
    }
  }

  Widget _buildFlutterUI() {
    return Focus(
      focusNode: _mainUIFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (_showSettings || _showSyncSettings) return KeyEventResult.ignored;

          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (_showControls) {
              if (_sliderFocusNode.hasFocus) {
                setState(() => _showControls = false);
                _mainUIFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
            }
          }

          if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter) {
            if (!_showControls) {
              setState(() => _showControls = true);
              _playButtonFocusNode.requestFocus();
              _startHideTimer();
            }
            return KeyEventResult.handled;
          }
          
          if (!_showControls) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _seek(_positionMs - 10000.0);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _seek(_positionMs + 10000.0);
              return KeyEventResult.handled;
            }
          }

          if (event.logicalKey == LogicalKeyboardKey.space) {
            _togglePlay();
            return KeyEventResult.handled;
          }

          if (event.logicalKey == LogicalKeyboardKey.escape || event.logicalKey == LogicalKeyboardKey.goBack || event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_showSettings) {
              _closeSettings();
              return KeyEventResult.handled;
            }
            if (_showSyncSettings) {
              _closeSyncSettings();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              _confirmExit();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () { 
          setState(() => _showControls = !_showControls); 
          if (_showControls) _startHideTimer(); 
        },
        child: Stack(
          children: [
            // Center area for gestures (Transparent)
            Positioned.fill(
              child: Row(
                children: [
                  // Left seek zone
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: () => _seek(_positionMs - 10000.0),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  // Center tap zone (already handled by outer GestureDetector)
                  const SizedBox(width: 100),
                  // Right seek zone
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: () => _seek(_positionMs + 10000.0),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ],
              ),
            ),
            
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300), 
                opacity: _showControls ? 1.0 : 0.0,
                child: Column(
                  children: [
                    _buildTopBar(), 
                    const Spacer(), 
                    _buildBottomBar()
                  ]
                ),
              ),
            ),

            if (_showSettings) _buildPremiumSettings(),
            if (_showSyncSettings) _buildSyncSettings(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return FocusTraversalGroup(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, 
            end: Alignment.bottomCenter, 
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.black.withValues(alpha: 0.3),
              Colors.transparent
            ]
          )
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFocusableButton(Icons.arrow_back_rounded, _confirmExit, size: 24),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title, 
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5), 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis
                  ),
                  if (widget.seriesTitle != null) 
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'S${widget.season} E${widget.episode} • ${widget.seriesTitle}', 
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14, fontWeight: FontWeight.w500)
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Text(
              "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return FocusTraversalGroup(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter, 
            end: Alignment.topCenter, 
            colors: [
              Colors.black.withValues(alpha: 0.9),
              Colors.black.withValues(alpha: 0.4),
              Colors.transparent
            ]
          )
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Text(
                    _formatTime(_positionMs), 
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Focus(
                      focusNode: _sliderFocusNode,
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent) {
                          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) { _seek((_positionMs - 10000).toDouble()); return KeyEventResult.handled; }
                          if (event.logicalKey == LogicalKeyboardKey.arrowRight) { _seek((_positionMs + 10000).toDouble()); return KeyEventResult.handled; }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Builder(
                        builder: (context) {
                          final hasFocus = Focus.of(context).hasFocus;
                          return SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              thumbColor: Colors.white,
                              activeTrackColor: AppTheme.primaryColor,
                              inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                              overlayColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                              trackHeight: hasFocus ? 8 : 6, // Slightly taller for touch
                              thumbShape: RoundSliderThumbShape(enabledThumbRadius: hasFocus ? 12 : 6),
                              trackShape: const RoundedRectSliderTrackShape(),
                            ),
                            child: Slider(
                              value: _positionMs.toDouble().clamp(0, _durationMs <= 0 ? 0 : _durationMs.toDouble()), 
                              max: _durationMs <= 0 ? 1.0 : _durationMs.toDouble(), 
                              onChanged: _seek
                            ),
                          );
                        }
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatTime(_durationMs), 
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  _buildFocusableButton(Icons.settings_outlined, _openSettings, size: 22, label: 'Settings'),
                  const Spacer(),
                  _buildFocusableButton(Icons.replay_10_rounded, () => _seek(_positionMs - 10000.0), size: 26),
                  const SizedBox(width: 20),
                  _buildFocusableButton(
                    _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded, 
                    _togglePlay, 
                    focusNode: _playButtonFocusNode, 
                    size: 48,
                  ),
                  const SizedBox(width: 20),
                  _buildFocusableButton(Icons.forward_10_rounded, () => _seek(_positionMs + 10000.0), size: 26),
                  const Spacer(),
                  _buildFocusableButton(
                    Icons.sync_rounded, 
                    _openSyncSettings, 
                    size: 22, 
                    label: 'Sync'
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusableButton(IconData icon, VoidCallback onPressed, {FocusNode? focusNode, double size = 24, String? label}) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
          onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onPressed,
            child: AnimatedScale(
              scale: hasFocus ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasFocus ? AppTheme.primaryColor.withValues(alpha: 0.15) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasFocus ? AppTheme.primaryColor : Colors.transparent,
                    width: 2.0,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon, 
                      color: hasFocus ? Colors.white : Colors.white.withValues(alpha: 0.7), 
                      size: size
                    ),
                    if (label != null && hasFocus) 
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          label.toUpperCase(), 
                          style: TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _startHideTimer() { 
    _hideTimer?.cancel(); 
    if (!_isPlaying) return;
    _hideTimer = Timer(const Duration(seconds: 5), () { 
      if (mounted && !_showSettings && !_showSyncSettings && _isPlaying) {
        setState(() => _showControls = false); 
        _mainUIFocusNode.requestFocus();
      } 
    }); 
  }

  String _formatTime(int ms) {
    if (ms <= 0) return '00:00';
    final d = Duration(milliseconds: ms);
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    if (hours > 0) return '$hours:${two(minutes)}:${two(seconds)}';
    return '${two(minutes)}:${two(seconds)}';
  }
}
