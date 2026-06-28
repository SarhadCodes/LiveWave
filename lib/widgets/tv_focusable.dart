import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';

class TVFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;
  final bool showGlow;
  final bool showBorder;
  final BorderRadius? borderRadius;
  final FocusNode? focusNode;
  final bool autoFocus;

  const TVFocusable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 1.05,
    this.showGlow = true,
    this.showBorder = true,
    this.borderRadius,
    this.focusNode,
    this.autoFocus = false,
  });

  @override
  State<TVFocusable> createState() => _TVFocusableState();
}

class _TVFocusableState extends State<TVFocusable> with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  bool _isFocused = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() => _isFocused = _focusNode.hasFocus);
      if (_isFocused) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    else _focusNode.removeListener(_handleFocusChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autoFocus,
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
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
                  boxShadow: _isFocused && widget.showGlow
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    child!,
                    if (_isFocused && widget.showBorder)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryColor,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
