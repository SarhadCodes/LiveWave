import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class StatusCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final FocusNode? focusNode;

  const StatusCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: isFocused ? Matrix4.identity().scaled(1.05) : Matrix4.identity(),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // Reduced padding
            decoration: BoxDecoration(
              color: isFocused ? AppTheme.cardColor.withOpacity(0.9) : AppTheme.cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusS), // Slightly smaller radius
              border: Border.all(
                color: isFocused 
                    ? AppTheme.primaryColor 
                    : AppTheme.textTertiary.withOpacity(0.1),
                width: isFocused ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isFocused 
                      ? AppTheme.primaryColor.withOpacity(0.3) 
                      : Colors.black.withOpacity(0.3),
                  blurRadius: isFocused ? 15 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Ensure it takes min space
              children: [
                Container(
                  padding: const EdgeInsets.all(8), // Reduced padding
                  decoration: BoxDecoration(
                    color: (iconColor ?? AppTheme.primaryColor).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? AppTheme.primaryColor,
                    size: 20, // Reduced icon size
                  ),
                ),
                const SizedBox(height: 8), // Reduced spacing
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: isFocused ? AppTheme.textPrimary : AppTheme.textTertiary,
                    fontSize: 9, // Reduced font size
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1, // Limit lines
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2), // Reduced spacing
                Text(
                  value,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12, // Reduced font size
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1, // Limit lines
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}
