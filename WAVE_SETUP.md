# Wave setup — YouTube Data API v3

Wave uses the **YouTube Data API v3** for discovery and the **official YouTube IFrame Player** for playback.

Live Wave does **not** download, proxy, restream, or extract YouTube media URLs.

## 1. Create an API key

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Create or select a project.
3. Enable **YouTube Data API v3**.
4. Create an **API key**.
5. Restrict the key:
   - API restriction: **YouTube Data API v3** only
   - Application restriction: **Android apps**
     - Package: `com.livewave.kurdlogs.live_wave`
     - SHA-1: `43:FE:94:2D:48:2F:15:EE:F5:88:9F:5E:4C:35:7E:C9:5E:AE:FC:D6`

Wave sends `X-Android-Package` and `X-Android-Cert` on Data API requests so an Android-restricted key can be used from Flutter HTTP.

If Wave says the key is blocked:
1. Confirm **YouTube Data API v3** is enabled on that same Google Cloud project.
2. Do **not** restrict this key to HTTP referrers.
3. Temporarily set Application restriction to **None**. If Wave then loads, add the Android package + SHA-1 again.

A key shipped inside the client app is **not a perfect secret**. Restrictions reduce abuse. Do not enable unrelated Google APIs on this key. Do not reuse the Firebase Android key for Wave.

## 2. Give the key to Live Wave

**Option A — compile time (recommended for release builds)**

```
flutter run --dart-define=YOUTUBE_API_KEY=YOUR_KEY
flutter build apk --dart-define=YOUTUBE_API_KEY=YOUR_KEY
```

**Option B — local file (gitignored)**

Copy `lib/config/wave_local.example.dart` to `lib/config/wave_local.dart` and paste the key. That file is gitignored and must not be committed.

**Option C — in the app**

Open the **Wave** tab and paste the key into the setup field. It is stored locally in SharedPreferences (`youtube_api_key`) on this device only.

## 3. Playback

Playback uses the official IFrame Player (`youtube_player_iframe`). YouTube controls, branding, ads, and restrictions stay intact.

## 4. Quota

Default quota is typically 10,000 units/day.

- `search.list` is expensive (100 units)
- `videos.list`, `channels.list`, and `playlistItems.list` are cheap (1 unit)

Wave caches feeds, debounces search, hydrates video IDs in batches, and loads category shelves on demand.

## 5. Follow / Watch Later / History

These are **Live Wave** features stored on the device. They are not YouTube subscriptions, playlists, or account history.
