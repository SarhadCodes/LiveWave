import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/channel_logo.dart';
import '../models/channel.dart';
import '../config/app_theme.dart';
import 'category_badge.dart';

class ChannelCard extends StatefulWidget {
  final Channel channel;
  final VoidCallback onTap;
  final bool isTVMode;
  final FocusNode? focusNode;
  final bool isFavorite;

  const ChannelCard({
    super.key,
    required this.channel,
    required this.onTap,
    this.isTVMode = false,
    this.focusNode,
    this.isFavorite = false,
  });

  @override
  State<ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<ChannelCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: AppTheme.tvFocusScale,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
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
      if (mounted) {
        setState(() => _isFocused = true);
        _animationController.forward();
      }
    } else {
      if (mounted) {
        setState(() => _isFocused = false);
        _animationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _buildCard();

    if (widget.isTVMode && widget.focusNode != null) {
      return Focus(
        focusNode: widget.focusNode,
        onKeyEvent: (node, event) {
          // Handle Enter/Select key press for TV remote
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter) {
              widget.onTap();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
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
            child: card,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: card,
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        boxShadow: _isFocused && widget.isTVMode
            ? [
                BoxShadow(
                  color: AppTheme.focusGlow,
                  blurRadius: 24,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full Background Logo/Image
            Container(
              color: AppTheme.cardColor,
              child: ChannelLogo(
                logo: widget.channel.logo,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                memCacheWidth: 200,
                fallback: Container(
                  color: AppTheme.surfaceColor,
                  child: Icon(
                    Icons.tv_rounded,
                    size: 32,
                    color: AppTheme.textTertiary.withOpacity(0.3),
                  ),
                ),
              ),
            ),
            
            // Bottom Gradient Overlay for Text Readability
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 80, // Height of the gradient area
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),
            
            // Focus Border
            if (_isFocused && widget.isTVMode)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: AppTheme.focusColor,
                    width: 3,
                  ),
                ),
              ),
            
            // Channel Name at Bottom Left
            Positioned(
              bottom: 6,
              left: 6,
              right: 6,
              child: Text(
                widget.channel.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Favorite Icon Overlay (Top Right)
            if (widget.isFavorite)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppTheme.accentRed,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
