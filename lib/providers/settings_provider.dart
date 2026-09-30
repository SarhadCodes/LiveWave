import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/platform_detector.dart';
import '../utils/category_order_utils.dart';

class SettingsProvider with ChangeNotifier {
  static const String keyPreferredPlayer = 'preferred_player';
  static const String keyLayoutMode = 'layout_mode';
  static const String keyLanguage = 'language';
  static const String keyContentSource = 'content_source';
  static const String keyActivationManaged = 'activation_managed';
  static const String keyDeveloperMode = 'developer_mode_enabled';

  List<String> _categoryOrderLiveTv = [];
  List<String> _categoryOrderMovies = [];
  List<String> _categoryOrderTvShows = [];

  /// 'firestore' = default Live Wave catalog, 'xtream' = Xtream Codes IPTV
  static const String contentSourceFirestore = 'firestore';
  static const String contentSourceXtream = 'xtream';

  String _preferredPlayer = 'internal';
  String _layoutMode = PlatformDetector.autoDetectLayout;
  String _language = 'en';
  String _contentSource = contentSourceFirestore;
  bool _activationManaged = false;
  bool _developerModeEnabled = false;

  Future<void>? _initFuture;

  String get preferredPlayer => _preferredPlayer;
  String get layoutMode => _layoutMode;
  String get language => _language;
  String get contentSource => _contentSource;
  bool get activationManaged => _activationManaged;
  bool get isXtreamSource => _contentSource == contentSourceXtream;
  bool get isRtl => _language == 'ku';
  bool get developerModeEnabled => _developerModeEnabled;

  SettingsProvider() {
    _initFuture = _loadSettings();
  }

  Future<void> ensureLoaded() => _initFuture ?? Future.value();

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String? player = prefs.getString(keyPreferredPlayer);
    if (player == 'vlc') {
      player = 'internal';
      await prefs.setString(keyPreferredPlayer, 'internal');
    }
    _preferredPlayer = player ?? 'internal';
    _layoutMode = prefs.getString(keyLayoutMode) ?? PlatformDetector.autoDetectLayout;
    _language = prefs.getString(keyLanguage) ?? 'en';
    _contentSource = prefs.getString(keyContentSource) ?? contentSourceFirestore;
    _activationManaged = prefs.getBool(keyActivationManaged) ?? false;
    _developerModeEnabled = prefs.getBool(keyDeveloperMode) ?? false;
    _categoryOrderLiveTv = prefs.getStringList(CategoryOrderSection.liveTv.prefsKey) ?? [];
    _categoryOrderMovies = prefs.getStringList(CategoryOrderSection.movies.prefsKey) ?? [];
    _categoryOrderTvShows = prefs.getStringList(CategoryOrderSection.tvShows.prefsKey) ?? [];
    notifyListeners();
  }

  List<String> getCategoryOrder(CategoryOrderSection section) {
    switch (section) {
      case CategoryOrderSection.liveTv:
        return List<String>.from(_categoryOrderLiveTv);
      case CategoryOrderSection.movies:
        return List<String>.from(_categoryOrderMovies);
      case CategoryOrderSection.tvShows:
        return List<String>.from(_categoryOrderTvShows);
    }
  }

  List<String> orderedCategoryIds(
    CategoryOrderSection section,
    List<String> defaultOrder,
  ) {
    return applySavedCategoryOrder(defaultOrder, getCategoryOrder(section));
  }

  Future<void> setCategoryOrder(
    CategoryOrderSection section,
    List<String> order,
  ) async {
    switch (section) {
      case CategoryOrderSection.liveTv:
        _categoryOrderLiveTv = List<String>.from(order);
      case CategoryOrderSection.movies:
        _categoryOrderMovies = List<String>.from(order);
      case CategoryOrderSection.tvShows:
        _categoryOrderTvShows = List<String>.from(order);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(section.prefsKey, order);
  }

  Future<void> resetCategoryOrder(CategoryOrderSection section) async {
    await setCategoryOrder(section, const []);
  }

  Future<void> setDeveloperModeEnabled(bool value) async {
    _developerModeEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyDeveloperMode, value);
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
