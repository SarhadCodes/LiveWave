import 'wave_local.dart' as wave_local;

/// Public catalog settings. Do not put secrets in this file.
abstract final class WaveMusicConfig {
  static const String audiusAppName = 'WAVE';
  static const String audiusDiscoveryUrl = 'https://api.audius.co';
  static const String audiusApiKey = String.fromEnvironment('AUDIUS_API_KEY');
  static const bool useItunes = bool.fromEnvironment('WAVE_MUSIC_ITUNES', defaultValue: false);
  static const bool useAudiusCatalog = bool.fromEnvironment('WAVE_MUSIC_AUDIUS', defaultValue: false);
  static const bool useYoutubeCatalog = bool.fromEnvironment('WAVE_MUSIC_YOUTUBE', defaultValue: false);
  static const bool useSoundCloud = bool.fromEnvironment('WAVE_MUSIC_SOUNDCLOUD', defaultValue: false);
  static const bool audiusPlaybackFallback =
      bool.fromEnvironment('WAVE_MUSIC_AUDIUS_FALLBACK', defaultValue: false);
  static const String _soundCloudClientIdDefine = String.fromEnvironment('SOUNDCLOUD_CLIENT_ID');
  static const String _soundCloudClientSecretDefine = String.fromEnvironment('SOUNDCLOUD_CLIENT_SECRET');

  static String get soundCloudClientId {
    final env = _soundCloudClientIdDefine.trim();
    if (env.isNotEmpty) return env;
    return wave_local.kSoundCloudClientId.trim();
  }

  static String get soundCloudClientSecret {
    final env = _soundCloudClientSecretDefine.trim();
    if (env.isNotEmpty) return env;
    return wave_local.kSoundCloudClientSecret.trim();
  }

  static bool get hasSoundCloudCredentials =>
      soundCloudClientId.isNotEmpty && soundCloudClientSecret.isNotEmpty;
}
