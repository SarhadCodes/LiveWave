import 'package:shared_preferences/shared_preferences.dart';

import 'wave_local.dart' as wave_local;

/// Wave / YouTube Data API configuration.
///
/// Resolve order:
/// 1. Runtime value saved from the Wave setup field
/// 2. `--dart-define=YOUTUBE_API_KEY=...` compile-time value
/// 3. Local gitignored `wave_local.dart`
///
/// A key shipped inside the APK is not a perfect secret. Restrict it to the
/// YouTube Data API v3 and this Android package in Google Cloud Console.
class WaveConfig {
  static const String dartDefineKey = String.fromEnvironment('YOUTUBE_API_KEY');
  static const String telegramIngestDefine = String.fromEnvironment('TELEGRAM_INGEST_URL');
  static const String prefsKey = 'youtube_api_key';
  static const String youtubeDataBaseUrl = 'https://www.googleapis.com/youtube/v3';
  static const String watchUrlPrefix = 'https://www.youtube.com/watch?v=';
  static const String channelUrlPrefix = 'https://www.youtube.com/channel/';
  static const Duration feedCacheTtl = Duration(minutes: 30);
  static const Duration liveCacheTtl = Duration(minutes: 3);
  static const Duration searchCacheTtl = Duration(minutes: 10);
  static const Duration detailsCacheTtl = Duration(minutes: 45);
  static const Duration channelCacheTtl = Duration(hours: 2);
  static const Duration searchDebounce = Duration(milliseconds: 450);
  static const int searchPageSize = 16;
  static const int shelfPageSize = 12;
  static const String defaultRegionCode = 'US';
  static const String androidPackageName = 'com.livewave.kurdlogs.live_wave';

  /// Debug/release SHA-1 with no colons. Sent as X-Android-Cert so an
  /// Android-restricted YouTube key works with plain HTTPS calls.
  static const String androidSha1Cert = '43FE942D482F15EEF5889F5E4C357EC95EAEFCD6';

  static String? _cachedKey;
  static bool _loaded = false;

  static String get _bundledKey {
    final env = dartDefineKey.trim();
    if (env.isNotEmpty) return env;
    return wave_local.kYoutubeApiKey.trim();
  }

  static Future<String> resolveApiKey() async {
    if (_loaded && _cachedKey != null) return _cachedKey!;
    final prefs = await SharedPreferences.getInstance();
    final stored = (prefs.getString(prefsKey) ?? '').trim();
    final bundled = _bundledKey;
    _cachedKey = stored.isNotEmpty ? stored : bundled;
    if (stored.isEmpty && bundled.isNotEmpty) {
      await prefs.setString(prefsKey, bundled);
    }
    _loaded = true;
    return _cachedKey!;
  }

  static bool get hasCompileTimeKey => _bundledKey.isNotEmpty;

  static Future<bool> hasApiKey() async {
    final key = await resolveApiKey();
    return key.isNotEmpty;
  }

  static Future<void> saveApiKey(String key) async {
    final trimmed = key.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(prefsKey);
      _cachedKey = _bundledKey;
    } else {
      await prefs.setString(prefsKey, trimmed);
      _cachedKey = trimmed;
    }
    _loaded = true;
  }

  static String get telegramIngestBaseUrl {
    final env = telegramIngestDefine.trim();
    if (env.isNotEmpty) return env;
    return wave_local.kTelegramIngestBaseUrl.trim();
  }

  static void clearMemoryCache() {
    _cachedKey = null;
    _loaded = false;
  }
}

