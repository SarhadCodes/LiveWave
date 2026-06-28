import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'dart:ui';

class SecurityBlockScreen extends StatelessWidget {
  const SecurityBlockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isKurdish = l10n.locale.languageCode == 'ku';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Artistic blurred background
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentRed.withOpacity(0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Premium Shield Icon
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accentRed.withOpacity(0.2), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentRed.withOpacity(0.1),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.security_rounded,
                      size: 80,
                      color: AppTheme.accentRed,
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // localized Header
                  Text(
                    isKurdish ? 'پاراستنی ئەمنی' : 'SECURITY ALERT',
                    style: TextStyle(
                      color: AppTheme.accentRed,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: isKurdish ? 0 : 4.0,
                      fontFamily: 'K24Kurdish',
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // The main message
                  Text(
                    l10n.translate('security_alert'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: isKurdish ? FontWeight.bold : FontWeight.w200,
                      height: 1.5,
                      fontFamily: 'K24Kurdish',
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Artistic instruction detail
                  Text(
                    isKurdish 
                      ? 'بۆ پاراستنی پەخشی کەناڵەکان، تکایە دڵنیابە هیچ بەرنامەیەکی VPN یان Proxy چالاک نییە'
                      : 'To protect our content streams, please ensure no VPN or proxy tools are running on your device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.6,
                      fontFamily: 'K24Kurdish',
                    ),
                  ),
                  
                  const SizedBox(height: 80),
                  
                  // Exit Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => SystemNavigator.pop(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          l10n.translate('exit').toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: isKurdish ? 0 : 2.0,
                            fontFamily: 'K24Kurdish',
                          ),
                        ),
                      ),
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
