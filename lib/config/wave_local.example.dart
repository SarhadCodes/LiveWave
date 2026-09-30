/// Copy this file to `wave_local.dart` and paste local secrets.
/// `wave_local.dart` is gitignored and must not be committed.
const String kYoutubeApiKey = '';

/// Public URL of the Wave Telegram ingest API, e.g. https://ingest.example.com
/// Leave empty to configure it later from the admin Telegram Imports tab.
const String kTelegramIngestBaseUrl = '';

/// Official SoundCloud API credentials for WAVE MUSIC.
/// Register an app at https://soundcloud.com/you/apps
/// Prefer `--dart-define=SOUNDCLOUD_CLIENT_ID=...` and
/// `--dart-define=SOUNDCLOUD_CLIENT_SECRET=...` at build time.
const String kSoundCloudClientId = '';
const String kSoundCloudClientSecret = '';
