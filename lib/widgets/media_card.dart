import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../config/app_theme.dart';
import '../providers/movies_provider.dart';
import '../providers/tv_shows_provider.dart';

class MediaCard extends StatefulWidget {
  final String id;
  final String title;
  final String posterUrl;
  final String rating;
  final String year;
  final bool isMovie;
  final bool forceKurdishBadge;
  final FocusNode? focusNode;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFocusChange;
  final bool dimmed;

  const MediaCard({
    super.key,
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.rating,
    required this.year,
    required this.isMovie,
    this.forceKurdishBadge = false,
    this.focusNode,
    this.onTap,
    this.onFocusChange,
    this.dimmed = false,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    widget.focusNode?.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_onFocusChange);
    _animationController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (widget.focusNode?.hasFocus ?? false) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: widget.onFocusChange,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            widget.onTap?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            opacity: widget.dimmed ? 0.45 : 1.0,
            child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Poster Image
                      widget.posterUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.posterUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 400,
                              placeholder: (context, url) => Container(
                                color: Colors.white.withOpacity(0.05),
                                child: const Center(
                                  child: Icon(Icons.movie_filter_rounded, color: Colors.white24),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppTheme.surfaceColor,
                                child: const Icon(Icons.broken_image_rounded, size: 40, color: Colors.white24),
                              ),
                            )
                          : Container(
                              color: AppTheme.surfaceColor,
                              child: const Icon(Icons.movie_filter_rounded, size: 40, color: Colors.white24),
                            ),
                      
                      // 2. Kurdish Badge (Modern Style)
                      _buildKurdishBadge(),

                      // 3. Info Overlay (Premium Gradient)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.0),
                                    Colors.black.withOpacity(0.6),
                                    Colors.black.withOpacity(0.9),
                                  ],
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      height: 1.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded, color: AppTheme.primaryColor, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.rating,
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      const Spacer(),
                                      Text(
                                        widget.year,
                                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                      ),

                      // 4. Focus Border
                      if (isFocused)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          );
        },
      ),
    );
  }

  Widget _buildKurdishBadge() {
    return Consumer2<MoviesProvider, TvShowsProvider>(
      builder: (context, moviesProv, tvProv, _) {
        bool hasSub = widget.forceKurdishBadge;
        if (!hasSub) {
          final idInt = int.tryParse(widget.id.replaceAll(RegExp(r'[^0-9]'), ''));
          if (idInt != null) {
            if (widget.isMovie) {
              hasSub = moviesProv.kurdishMovies.any((m) => m.id == idInt);
            } else {
              hasSub = tvProv.kurdishTvShows.any((t) => t.id == idInt);
            }
          }
        }

        if (hasSub) {
          return Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5), width: 1),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.asset('assets/flags/k.png', width: 20, height: 14, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    "KU",
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
