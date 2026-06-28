import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/platform_detector.dart';

class SettingsProvider with ChangeNotifier {
  static const String keyPreferredPlayer = 'preferred_player';
  static const String keyLayoutMode = 'layout_mode';
  static const String keyLanguage = 'language';
  static const String keyContentSource = 'content_source';
  static const String keyActivationManaged = 'activation_managed';

  /// 'firestore' = default Live Wave catalog, 'xtream' = Xtream Codes IPTV
  static const String contentSourceFirestore = 'firestore';
  static const String contentSourceXtream = 'xtream';
  
  // 'internal' (Default)
  String _preferredPlayer = 'internal';
  
  // Default to auto-detected mode initially
  String _layoutMode = PlatformDetector.autoDetectLayout;

  // 'en' (English), 'ku' (Kurdish)
  String _language = 'en';

  String _contentSource = contentSourceFirestore;
  bool _activationManaged = false;

  Future<void>? _initFuture;

  String get preferredPlayer => _preferredPlayer;
  String get layoutMode => _layoutMode;
  String get language => _language;
  String get contentSource => _contentSource;
  bool get activationManaged => _activationManaged;
  bool get isXtreamSource => _contentSource == contentSourceXtream;
  bool get isRtl => _language == 'ku';

  SettingsProvider() {
    _initFuture = _loadSettings();
  }

  Future<void> ensureLoaded() => _initFuture ?? Future.value();

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String? player = prefs.getString(keyPreferredPlayer);
    // Remove VLC option for security: Force internal if vlc was selected
    if (player == 'vlc') {
      player = 'internal';
      await prefs.setString(keyPreferredPlayer, 'internal');
    }
    _preferredPlayer = player ?? 'internal';
    _layoutMode = prefs.getString(keyLayoutMode) ?? PlatformDetector.autoDetectLayout;
    _language = prefs.getString(keyLanguage) ?? 'en';
    _contentSource = prefs.getString(keyContentSource) ?? contentSourceFirestore;
    _activationManaged = prefs.getBool(keyActivationManaged) ?? false;
    notifyListeners();
  }

  Future<void> setActivationManaged(bool value) async {
    _activationManaged = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyActivationManaged, value);
  }

  Future<void> setContentSource(String source) async {
    if (source != contentSourceFirestore && source != contentSourceXtream) {
      return;
    }
    _contentSource = source;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyContentSource, source);
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLanguage, lang);
  }

  Future<void> setPreferredPlayer(String player) async {
    _preferredPlayer = player;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyPreferredPlayer, player);
  }

  Future<void> setLayoutMode(String mode) async {
    _layoutMode = mode;
    
    // Update orientation immediately
    if (mode == 'mobile') {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLayoutMode, mode);
  }
}
