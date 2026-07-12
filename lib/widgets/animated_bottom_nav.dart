import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class BottomNavItem {
  final IconData icon;
  final String label;
  final Color activeColor;

  const BottomNavItem({
    required this.icon,
    required this.label,
    required this.activeColor,
  });
}

class AnimatedBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Animation<double> animation;
  final List<BottomNavItem> items;

  const AnimatedBottomNav({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.animation,
    required this.items,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.04, // Responsive horizontal margin
          vertical: AppTheme.spacingSM,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9, // Max width constraint
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(AppTheme.radiusXXL),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusXXL),
          child: BackdropFilter(
            filter: ColorFilter.mode(
              Colors.white.withOpacity(0.05),
              BlendMode.srcOver,
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.02, // Responsive padding
                vertical: AppTheme.spacingXS,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  items.length,
                  (index) => Expanded(
                    child: _buildNavItem(context, index),
                  ),
                ),
              ),
            ),
          ),
        ),
      ).animate()
       .fadeIn(duration: 600.ms, delay: 200.ms)
       .slideY(begin: 1.0, end: 0.0, duration: 600.ms, delay: 200.ms, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildNavItem(BuildContext context, int index) {
    final item = items[index];
    final isSelected = index == currentIndex;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? AppTheme.spacingMD : AppTheme.spacingSM,
          vertical: AppTheme.spacingSM,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        constraints: const BoxConstraints(minWidth: 60), // Minimum width constraint
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    item.activeColor,
                    item.activeColor.withOpacity(0.8),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              size: isSelected ? 22 : 18,
            ).animate(target: isSelected ? 1 : 0)
             .scaleXY(end: 1.1, duration: 200.ms),

            if (isSelected) ...[
              const SizedBox(height: 2),
              Text(
                item.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ).animate()
               .fadeIn(duration: 200.ms)
               .slideY(begin: 0.5, end: 0.0, duration: 200.ms),
            ],
          ],
        ),
      ),
    );
  }
}