import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ad.dart';
import '../config/app_theme.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class AdSlideshow extends StatefulWidget {
  final List<Ad> ads;
  final Duration autoPlayDuration;

  const AdSlideshow({
    super.key,
    required this.ads,
    this.autoPlayDuration = const Duration(seconds: 5),
  });

  @override
  State<AdSlideshow> createState() => _AdSlideshowState();
}

class _AdSlideshowState extends State<AdSlideshow> {
  int _currentIndex = 0;
  Timer? _timer;
  final PageController _pageController = PageController();
  int _focusedIndex = -1;

  @override
  void initState() {
    super.initState();
    if (widget.ads.length > 1) {
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(widget.autoPlayDuration, (timer) {
      if (mounted && widget.ads.isNotEmpty && _focusedIndex == -1) {
        final nextIndex = (_currentIndex + 1) % widget.ads.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _handleAdClick(Ad ad) async {
    if (ad.actionUrl == null || ad.actionUrl!.isEmpty) return;
    
    final Uri url = Uri.parse(ad.actionUrl!);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch ${ad.actionUrl}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ads.isEmpty) {
      return _buildEmptyState();
    }

    final settings = Provider.of<SettingsProvider>(context);
    final isMobile = settings.layoutMode == 'mobile';
    final height = isMobile ? 220.0 : 280.0;

    final isKurdish = settings.language == 'ku';

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.ads.length,
            itemBuilder: (context, index) {
              return _buildAdSlide(widget.ads[index], isMobile, index, isKurdish, settings.language);
            },
          ),
          
          if (widget.ads.length > 1)
            Positioned(
              bottom: isMobile ? AppTheme.spacingM : AppTheme.spacingXL,
              left: isKurdish ? (isMobile ? AppTheme.spacingL : AppTheme.spacingXXL * 2) : null,
              right: !isKurdish ? (isMobile ? AppTheme.spacingL : AppTheme.spacingXXL * 2) : null,
              child: _buildIndicators(),
            ),
        ],
      ),
    );
  }

  Widget _buildAdSlide(Ad ad, bool isMobile, int index, bool isKurdish, String language) {
    final bool isFocused = _focusedIndex == index;
    final bool hasAction = ad.actionUrl != null && ad.actionUrl!.isNotEmpty;

    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {
          _focusedIndex = hasFocus ? index : -1;
        });
        if (hasFocus) {
          _timer?.cancel(); // Pause autoplay when focused
        } else if (widget.ads.length > 1) {
          _startAutoPlay();
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter || 
              event.logicalKey == LogicalKeyboardKey.select) {
            _handleAdClick(ad);
            return KeyEventResult.handled;
          }
          // D-pad left/right: swipe between ad slides
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.arrowRight) {
            final isLeft = event.logicalKey == LogicalKeyboardKey.arrowLeft;
            final nextPage = isLeft ? _currentIndex - 1 : _currentIndex + 1;
            if (nextPage >= 0 && nextPage < widget.ads.length) {
              _pageController.animateToPage(
                nextPage,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              );
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => _handleAdClick(ad),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.all(isFocused ? 4 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isFocused ? 16 : 0),
            border: Border.all(
              color: isFocused ? AppTheme.primaryColor : Colors.transparent,
              width: 3,
            ),
            boxShadow: isFocused ? [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ] : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isFocused ? 12 : 0),
            child: Stack(
              children: [
                // Background image
                if (ad.imageUrl.isNotEmpty)
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: ad.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppTheme.surfaceColor,
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.surfaceColor,
                              AppTheme.cardColor,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                
                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.85),
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
                
                // Content overlay - Dynamic Side
                Positioned.fill(
                  child: Container(
                    padding: EdgeInsets.only(
                      left: !isKurdish ? (isMobile ? AppTheme.spacingL : AppTheme.spacingXXL) : AppTheme.spacingL,
                      right: isKurdish ? (isMobile ? AppTheme.spacingL : AppTheme.spacingXXL) : AppTheme.spacingL,
                      bottom: isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                    ),
                    alignment: isKurdish ? Alignment.bottomRight : Alignment.bottomLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badges
                        if (ad.badges.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            alignment: WrapAlignment.start,
                            children: ad.badges.map((badge) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentRed.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  badge.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        
                        const SizedBox(height: 8),
                        
                        // Title
                        SizedBox(
                          width: isMobile ? double.infinity : 500,
                          child: Text(
                            ad.getDisplayTitle(language),
                            textAlign: isKurdish ? TextAlign.right : TextAlign.left,
                            style: TextStyle(
                              color: isFocused ? AppTheme.primaryColor : AppTheme.textPrimary,
                              fontSize: isMobile ? 22 : 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Description
                        if (!isMobile || ad.getDisplayDescription(language).length < 100)
                          SizedBox(
                            width: isMobile ? double.infinity : 400,
                            child: Text(
                              ad.getDisplayDescription(language),
                              textAlign: isKurdish ? TextAlign.right : TextAlign.left,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: isMobile ? 11 : 14,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                              maxLines: isMobile ? 2 : 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        
                        if (hasAction && isFocused)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.open_in_new_rounded, color: AppTheme.primaryColor, size: 16),
                                const SizedBox(width: 8),
                                const Text(
                                  'CLICK TO OPEN',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndicators() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.ads.length, (index) {
        final isActive = index == _currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 32 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive 
                ? AppTheme.primaryColor 
                : AppTheme.textTertiary.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.surfaceColor,
            AppTheme.backgroundColor,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.ad_units_rounded,
              size: 64,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'No featured content available',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
