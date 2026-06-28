# Live Wave - Premium Flutter Live TV Application

A premium Flutter Live TV application that supports both Android TV (Android 14) and Android mobile platforms, powered by Firebase Firestore.

## Features

- 📺 **Live TV Streaming** - HLS (.m3u8) stream support with adaptive bitrate
- 🎨 **Premium Dark Theme** - Modern, clean, minimal UI design
- 📱 **Multi-Platform** - Android TV and Android Mobile support
- 🎮 **TV-Remote Friendly** - D-pad navigation with focus animations
- 🔥 **Firebase Backend** - Cloud Firestore for channel management
- ⚡ **Auto-Reconnect** - Automatic stream reconnection on failure
- 🎯 **Category Filtering** - Filter channels by category
- 🔄 **Real-time Updates** - Live channel updates from Firestore

## Screenshots

### Android TV
- Large grid layout (4 columns)
- Focus-based navigation with glow effects
- D-pad support for seamless TV experience

### Android Mobile
- Compact grid layout (2 columns)
- Touch-friendly interface
- Pull-to-refresh support

## Tech Stack

- **Framework**: Flutter 3.10.3+
- **Backend**: Firebase Firestore
- **Video Player**: video_player + chewie
- **State Management**: Provider
- **Image Caching**: cached_network_image

## Prerequisites

- Flutter SDK 3.10.3 or higher
- Android Studio / VS Code
- Firebase account
- Android device or emulator (API 21+)

## Setup Instructions

### 1. Clone the Repository
```bash
git clone <repository-url>
cd live_wave
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Firebase
Follow the instructions in [FIREBASE_SETUP.md](FIREBASE_SETUP.md) to:
- Create a Firebase project
- Add Android app configuration
- Download and place `google-services.json`
- Set up Firestore database
- Add channel data

### 4. Run the Application

**For Mobile:**
```bash
flutter run
```

**For Android TV:**
1. Create an Android TV emulator (API 34 recommended)
2. Start the emulator
3. Run: `flutter run`

## Firestore Database Structure

### Collection: `channels`

| Field | Type | Description |
|-------|------|-------------|
| name | String | Channel name |
| logo | String | Network image URL for channel logo |
| stream | String | HLS stream URL (.m3u8) |
| category | String | Channel category (News, Sports, etc.) |
| isLive | bool | Whether channel is currently live |
| isActive | bool | Whether channel should be displayed |
| order | number | Display order (ascending) |

**Note**: Only channels with `isActive: true` will be fetched and displayed.

## Project Structure

```
lib/
├── config/
│   └── app_theme.dart          # Dark theme configuration
├── models/
│   └── channel.dart            # Channel data model
├── providers/
│   └── channels_provider.dart  # State management
├── screens/
│   ├── home_screen.dart        # Channels grid screen
│   └── player_screen.dart      # Video player screen
├── services/
│   └── firestore_service.dart  # Firestore integration
├── utils/
│   └── platform_detector.dart  # Platform detection utility
├── widgets/
│   ├── category_badge.dart     # Category badge widget
│   ├── channel_card.dart       # Channel card with focus animation
│   └── loading_indicator.dart  # Loading indicator widget
└── main.dart                   # Application entry point
```

## Features in Detail

### TV Navigation
- **D-pad Support**: Navigate through channels using TV remote
- **Focus Animations**: Scale and glow effects on focused items
- **Optimized Layout**: Larger cards for better TV viewing

### Video Player
- **HLS Streaming**: Supports .m3u8 streams
- **Adaptive Bitrate**: Automatic quality adjustment
- **Auto-Reconnect**: Reconnects automatically on stream failure
- **Custom Overlay**: Channel info, live badge, and current time
- **Auto-Hide Controls**: Controls hide after 3 seconds

### Mobile Features
- **Touch Optimized**: Responsive grid layout
- **Pull-to-Refresh**: Refresh channel list
- **Portrait Mode**: Optimized for mobile viewing

## Building for Release

### Android Mobile
```bash
flutter build apk --release
```

### Android TV
```bash
flutter build apk --release --target-platform android-arm64
```

## Troubleshooting

### Firebase Connection Issues
- Ensure `google-services.json` is in `android/app/`
- Verify package name matches: `com.livewave.kurdlogs.live_wave`
- Check Firebase project configuration

### Video Playback Issues
- Verify HLS stream URL is valid and accessible
- Check internet connection
- Ensure stream format is .m3u8

### TV Navigation Not Working
- Verify you're running on Android TV emulator or device
- Check screen size detection in platform_detector.dart

## License

This project is licensed under the MIT License.

## Support

For issues and questions, please create an issue in the repository.
