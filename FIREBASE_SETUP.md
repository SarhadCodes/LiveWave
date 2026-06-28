# Firebase Configuration Instructions

## Setup Steps

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or select an existing project
3. Follow the setup wizard

### 2. Add Android App
1. In your Firebase project, click "Add app" and select Android
2. Register your app with the package name: `com.livewave.kurdlogs.live_wave`
3. Download the `google-services.json` file
4. Place the file in: `android/app/google-services.json`

### 3. Set Up Firestore Database
1. In Firebase Console, go to "Firestore Database"
2. Click "Create database"
3. Choose "Start in test mode" (for development) or "Start in production mode"
4. Select a location for your database

### 4. Create Channels Collection
Create a collection named `channels` with the following structure:

```json
{
  "name": "Channel Name",
  "logo": "https://example.com/logo.png",
  "stream": "https://example.com/stream.m3u8",
  "category": "News",
  "isLive": true,
  "isActive": true,
  "order": 1
}
```

### Sample Channel Data
Here's an example document you can add to test:

```json
{
  "name": "Demo Channel",
  "logo": "https://via.placeholder.com/300x200/1A2142/00D9FF?text=Demo+Channel",
  "stream": "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
  "category": "Entertainment",
  "isLive": true,
  "isActive": true,
  "order": 1
}
```

### 5. Firestore Security Rules (Development)
For testing, you can use these rules (update for production):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /channels/{channel} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

### 6. Verify Installation
After placing `google-services.json`, run:
```bash
flutter clean
flutter pub get
flutter run
```

## Important Notes
- The `google-services.json` file is required for Firebase to work
- Make sure the package name matches exactly: `com.livewave.kurdlogs.live_wave`
- Add at least one channel with `isActive: true` to see content in the app
- HLS streams (.m3u8) are required for video playback

## Testing HLS Streams
You can use these free test HLS streams:
- https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8
- https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8
