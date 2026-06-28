import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/channels_provider.dart';
import '../providers/movies_provider.dart';
import '../providers/tv_shows_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/activation_provider.dart';
import '../widgets/app_navigation.dart';
import '../config/app_theme.dart';

import '../utils/security_utils.dart';
import '../screens/security_block_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final channelsProvider = Provider.of<ChannelsProvider>(context, listen: false);
      final moviesProvider = Provider.of<MoviesProvider>(context, listen: false);
      final tvShowsProvider = Provider.of<TvShowsProvider>(context, listen: false);
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      await settings.ensureLoaded();

      final activation = Provider.of<ActivationProvider>(context, listen: false);
      await activation.resolve(settings);

      channelsProvider.setContentSource(settings.contentSource);
      moviesProvider.setContentSource(settings.contentSource);
      tvShowsProvider.setContentSource(settings.contentSource);
      
      final startTime = DateTime.now();
      
      // --- SECURITY CHECK: Detect VPN / Proxy ---
      final isSecurityAlert = await SecurityUtils.isVpnOrProxyActive();
      
      if (isSecurityAlert) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const SecurityBlockScreen()),
          );
        }
        return;
      }
      
      try {
        // Load channels only at startup — movies/shows load when user opens those tabs
        await channelsProvider.fetchChannels().timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('Initialization error or timeout: $e');
      }
      
      // Premium splash duration (3 seconds minimum)
      final diff = DateTime.now().difference(startTime);
      if (diff.inMilliseconds < 3000) {
        await Future.delayed(Duration(milliseconds: 3000 - diff.inMilliseconds));
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AppNavigation(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Cinematic Background
          Image.network(
            'https://images.unsplash.com/photo-1626814026160-2237a95fc5a0?q=80&w=2070&auto=format&fit=crop',
            fit: BoxFit.cover,
          ),
          
          // 2. Liquid Glass Blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.5),
                    AppTheme.backgroundColor.withOpacity(0.8),
                    AppTheme.backgroundColor,
                  ],
                ),
              ),
            ),
          ),
          
          // 3. Central Branding Content
          Center(
            child: Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo with White Background and Glow
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Image.asset(
                          'assets/icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // App Name
                    Text(
                      'LIVE WAVE',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4.0,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'PREMIUM EXPERIENCE',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.5,
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Minimalist Loading Line
                    Container(
                      width: 220,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1.5),
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'INITIALIZING SECURE STREAMS',
                      style: TextStyle(
                        color: Colors.white30,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Bottom tag
          const Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Text(
                    'POWERED BY KURDLOGS TECHNOLOGY',
                    style: TextStyle(
                      color: Colors.white12,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3.0,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'VERSION 1.0.0',
                    style: TextStyle(
                      color: Colors.white10,
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
