# WAVE MUSIC

WAVE MUSIC is the music tab in Live Wave.

## Catalog

Production uses **NewPipe Extractor v0.26.5** (GPL-3.0-or-later) on Android for
YouTube / YouTube Music search, metadata, and audio-only stream extraction.
No YouTube Data API key is required for that path. Playback stays in the
existing Media3 engine. Stream URLs are temporary and are not stored.

The UI never talks to SoundCloud response objects directly. It consumes
`WaveMusicTrack` / album / artist / playlist models via `WaveMusicService`.

Playback uses the existing native **Media3 / ExoPlayer** music engine (separate
from IPTV). Flutter resolves a temporary SoundCloud stream immediately before
play:

```
SoundCloud API
  → WaveMusicCatalog / WaveMusicTrack
  → WaveMusicPlaybackResolver
  → WaveMusicPlayer
  → WaveMusicEngine (Media3)
```

Only tracks SoundCloud marks as `access=playable` are treated as playable.
Preview-only and blocked tracks are not streamed and are not presented as
full tracks. WAVE does **not** extract YouTube media, use YouTube as a music
source, scrape audio, or bypass DRM, BotGuard, geo, or paywall restrictions.

Stream URLs expire. They are resolved just-in-time, kept only in a short
in-memory cache, and never written to disk. If Media3 fails because a URL
expired, WAVE resolves a fresh stream once and retries playback once.

Preferred stream format (official SoundCloud transcodings):
1. `hls_aac_160_url` (HLS AAC 160 kbps)
2. `hls_aac_96_url` (HLS AAC 96 kbps fallback)

## SoundCloud API credentials

Register an application at [SoundCloud You Apps](https://soundcloud.com/you/apps)
(Artist Pro is required by SoundCloud for API keys). WAVE uses the official
**Client Credentials** flow for public search and playback. That flow requires
both a Client ID and a Client Secret. Do not commit either value.

Resolve order:
1. `--dart-define=SOUNDCLOUD_CLIENT_ID=...`
2. `--dart-define=SOUNDCLOUD_CLIENT_SECRET=...`
3. gitignored `lib/config/wave_local.dart` (`kSoundCloudClientId`, `kSoundCloudClientSecret`)

Copy `lib/config/wave_local.example.dart` to `lib/config/wave_local.dart` and
fill in the SoundCloud fields, **or** pass dart-defines at build time:

```
flutter run --dart-define=SOUNDCLOUD_CLIENT_ID=your_id --dart-define=SOUNDCLOUD_CLIENT_SECRET=your_secret
flutter build apk --release --dart-define=SOUNDCLOUD_CLIENT_ID=your_id --dart-define=SOUNDCLOUD_CLIENT_SECRET=your_secret
```

Client credentials tokens are limited (50 tokens / 12 hours per app). WAVE
reuses and refreshes the token; do not request a new token on every play.

Never put the Client Secret in source control, logs, or error messages.

## Attribution

Custom SoundCloud playback requires attribution per the official API Terms of
Use and Buttons & Logos guide:

1. Credit the uploader as the creator of the track
2. Credit SoundCloud as the source
3. Link to the SoundCloud `permalink_url`

WAVE MUSIC shows this on the full player and credits SoundCloud on the music
home screen and app info screen.

## Optional catalogs (not the default)

These are not used unless you opt in:

- `--dart-define=WAVE_MUSIC_AUDIUS=true` — Audius as the primary catalog
- `--dart-define=WAVE_MUSIC_ITUNES=true` — iTunes 30-second previews
- `--dart-define=WAVE_MUSIC_YOUTUBE=true` — YouTube Data API v3 metadata only (no YouTube playback)

Lyrics come from the public **LRCLIB** API. If none exist, the app shows “Lyrics unavailable”.

Telegram ingest still uses `kTelegramIngestBaseUrl` in gitignored `lib/config/wave_local.dart`.
