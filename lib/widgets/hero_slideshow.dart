import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_theme.dart';
import '../services/tmdb_service.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';
import '../l10n/app_localizations.dart';

class HeroSlideshow extends StatefulWidget {
  final List<dynamic> items;
  final bool isMobile;
  final Function(dynamic) onTap;

  const HeroSlideshow({
    super.key,
    required this.items,
    required this.isMobile,
    required this.onTap,
  });

  @override
  State<HeroSlideshow> createState() => _HeroSlideshowState();
}

class _HeroSlideshowState extends State<HeroSlideshow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (_pageController.hasClients && widget.items.isNotEmpty) {
        final nextPage = (_currentPage + 1) % widget.items.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final horizontalPadding = widget.isMobile ? AppTheme.spacingM : AppTheme.spacingXXL;

    return Container(
      height: widget.isMobile ? 280 : 240, // Further reduced TV height from 320 to 240
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final title = item is Movie ? item.title : (item is TvShow ? item.name : '');
              final backdrop = item is Movie ? item.backdropPath : (item is TvShow ? item.backdropPath : '');
              final rating = item is Movie ? item.ratingFormatted : (item is TvShow ? item.ratingFormatted : '');
              final year = item is Movie ? item.year : (item is TvShow ? item.year : '');

              return _HeroSlide(
                title: title,
                backdropPath: backdrop,
                rating: rating,
                year: year,
                isMobile: widget.isMobile,
                horizontalPadding: horizontalPadding,
                onTap: () => widget.onTap(item),
                pageController: _pageController,
              );
            },
          ),
          
          // Page Indicators
          Positioned(
            bottom: 20,
            right: horizontalPadding,
            child: Row(
              children: List.generate(
                widget.items.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(left: 6),
                  width: _currentPage == index ? 24 : 8,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _currentPage == index 
                        ? AppTheme.primaryColor 
                        : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSlide extends StatelessWidget {
  final String title;
  final String backdropPath;
  final String rating;
  final String year;
  final bool isMobile;
  final double horizontalPadding;
  final VoidCallback onTap;
  final PageController? pageController;

  const _HeroSlide({
    required this.title,
    required this.backdropPath,
    required this.rating,
    required this.year,
    required this.isMobile,
    required this.horizontalPadding,
    required this.onTap,
    this.pageController,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            onTap();
            return KeyEventResult.handled;
          }
          // D-pad left/right: swipe between slides
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (pageController != null && pageController!.hasClients) {
              final currentPage = pageController!.page?.round() ?? 0;
              final isLeft = event.logicalKey == LogicalKeyboardKey.arrowLeft;
              final nextPage = isLeft ? currentPage - 1 : currentPage + 1;
              if (nextPage >= 0) {
                pageController!.animateToPage(
                  nextPage,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              }
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (TmdbService.getBackdropUrl(backdropPath).isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: TmdbService.getBackdropUrl(backdropPath),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    memCacheHeight: 600,
                  )
                else
                  Container(color: AppTheme.surfaceColor),
                Container(
                  decoration: BoxDecoration(
                    border: isFocused ? Border.all(color: AppTheme.primaryColor, width: 4) : null,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.4),
                        AppTheme.backgroundColor,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: horizontalPadding,
                  right: horizontalPadding,
                  bottom: isMobile ? 40 : 20, // Further reduced from 30
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentRed,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          AppLocalizations.of(context).translate('featured_badge'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10), // Reduced from 12
                      Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: isMobile ? 28 : 24, // Further reduced from 32
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          letterSpacing: -1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: AppTheme.accentGold, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            rating,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 14 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            year,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: isMobile ? 14 : 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
