import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';

class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  const CategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip = Builder(
      builder: (context) {
        final isFocused = focusNode != null && Focus.of(context).hasFocus;
        
        return GestureDetector(
          onTap: onTap,
          child: AnimatedScale(
            scale: isFocused ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: isFocused
                    ? Border.all(
                        color: AppTheme.primaryColor,
                        width: 2,
                      )
                    : Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.textTertiary.withOpacity(0.2),
                        width: 1,
                      ),
                boxShadow: isSelected || isFocused
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.backgroundColor
                      : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        );
      },
    );

    if (focusNode != null) {
      return Focus(
        focusNode: focusNode,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter) {
              onTap();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: chip,
      );
    }

    return chip;
  }
}
