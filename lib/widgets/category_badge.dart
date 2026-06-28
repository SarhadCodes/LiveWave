import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class CategoryBadge extends StatelessWidget {
  final String category;
  final bool isCompact;

  const CategoryBadge({
    super.key,
    required this.category,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getCategoryColor(category);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        category.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: isCompact ? 10 : 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
