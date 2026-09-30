import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/channel_logo.dart';
import '../models/channel.dart';
import '../config/app_theme.dart';

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

class _ChannelCardState extends State<ChannelCard> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode?.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    setState(() => _isFocused = widget.focusNode?.hasFocus ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final card = _buildCard();

    if (widget.isTVMode && widget.focusNode != null) {
      return Focus(
        focusNode: widget.focusNode,
        onKeyEvent: (node, event) {
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
          child: card,
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: card,
    );
  }

  Widget _buildCard() {
    final focused = _isFocused && widget.isTVMode;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: focused
              ? AppTheme.focusColor
              : AppTheme.textTertiary.withValues(alpha: 0.15),
          width: focused ? 3 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.25),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusM - 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ChannelLogo(
              logo: widget.channel.logo,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              memCacheWidth: 400,
              fallback: Container(
                color: AppTheme.surfaceColor,
                child: Icon(
                  Icons.tv_rounded,
                  size: 36,
                  color: AppTheme.textTertiary.withValues(alpha: 0.35),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.92),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
                  child: Text(
                    widget.channel.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            if (widget.isFavorite)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppTheme.accentRed,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
