import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_theme.dart';
import 'providers/channels_provider.dart';
import 'providers/settings_provider.dart';
import 'widgets/app_navigation.dart';
import 'screens/tv_home_screen.dart';

import 'screens/splash_screen.dart';
import 'providers/movies_provider.dart';
import 'providers/tv_shows_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/activation_provider.dart';
import 'services/download_service.dart';
import 'utils/platform_detector.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'dart:io';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `Firebase.initializeApp()` before using other Firebase services.
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('--- LIVE WAVE STARTING ---');
  
  // Initialize Firebase with a timeout to prevent hanging on Desktop if config is missing
  try {
    debugPrint('Initializing Firebase...');
    await Firebase.initializeApp().timeout(const Duration(seconds: 5));
    debugPrint('Firebase initialized.');
    
    // Set the background messaging handler early on, as a named top-level function
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Request permission (mostly for iOS/Android 13+)
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // Get token for debugging/server-side use
    String? token = await messaging.getToken();
    debugPrint('FCM Token: $token');
    
  } catch (e) {
    debugPrint('Firebase initialization failed or timed out: $e');
    debugPrint('Continuing to launch app UI...');
  }

  // Load layout preference for orientation
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('SharedPreferences error: $e');
  }
  
  final layoutMode = prefs?.getString('layout_mode') ?? PlatformDetector.autoDetectLayout;
  
  if (layoutMode == 'mobile') {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  } else {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
  
  debugPrint('runApp starting...');
  runApp(const LiveWaveApp());
}

class LiveWaveApp extends StatelessWidget {
  const LiveWaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChannelsProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => MoviesProvider()),
        ChangeNotifierProvider(create: (_) => TvShowsProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => ActivationProvider()),
        ChangeNotifierProvider(create: (_) => DownloadService(), lazy: false),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          // Sync language and content source to ChannelsProvider
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final channels = Provider.of<ChannelsProvider>(context, listen: false);
            final movies = Provider.of<MoviesProvider>(context, listen: false);
            final tvShows = Provider.of<TvShowsProvider>(context, listen: false);
            channels.setContentSource(settings.contentSource);
            movies.setContentSource(settings.contentSource);
            tvShows.setContentSource(settings.contentSource);
            channels.updateLanguage(settings.language);
          });
          
          return MaterialApp(
            title: 'Live Wave',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            locale: Locale(settings.language),
            supportedLocales: const [
              Locale('en', ''),
              Locale('ku', ''),
            ],
            localizationsDelegates: [
              AppLocalizationsDelegate(),
              KurdishMaterialLocalizationsDelegate(),
              KurdishWidgetsLocalizationsDelegate(),
              KurdishCupertinoLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              final data = MediaQuery.of(context);
              // Apply a global scale factor for TV to make UI more compact and professional
              final isTV = data.size.width > 900; 
              return MediaQuery(
                data: data.copyWith(
                  textScaler: isTV ? const TextScaler.linear(0.85) : TextScaler.noScaling,
                ),
                child: child!,
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
