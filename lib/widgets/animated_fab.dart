import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum FABSize { small, medium, large }

class AnimatedFAB extends StatefulWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final FABSize size;
  final bool showShadow;

  const AnimatedFAB({
    super.key,
    this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.size = FABSize.medium,
    this.showShadow = true,
  });

  @override
  State<AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<AnimatedFAB>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  void _handleTap() {
    if (widget.onPressed != null) {
      _bounceController.forward(from: 0.0);
      widget.onPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double iconSize = _getIconSize();
    final EdgeInsets padding = _getPadding();
    final bool isEnabled = widget.onPressed != null;

    return GestureDetector(
      onTapDown: isEnabled ? _handleTapDown : null,
      onTapUp: isEnabled ? _handleTapUp : null,
      onTapCancel: isEnabled ? _handleTapCancel : null,
      onTap: isEnabled ? _handleTap : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _bounceAnimation]),
        builder: (context, child) {
          final double scale = _scaleAnimation.value * _bounceAnimation.value;

          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: isEnabled ? 1.0 : 0.5,
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.backgroundColor,
                      widget.backgroundColor.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  boxShadow: widget.showShadow
                      ? [
                          BoxShadow(
                            color: widget.backgroundColor.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      color: widget.foregroundColor,
                      size: iconSize,
                    )
                        .animate()
                        .scaleXY(
                            begin: 0.8, end: 1.0, duration: 300.ms, delay: 100.ms)
                        .then()
                        .shimmer(delay: 400.ms, duration: 600.ms),
                    const SizedBox(width: AppTheme.spacingSM),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.label,
                          style: GoogleFonts.montserrat(
                            color: widget.foregroundColor,
                            fontSize: _getFontSize(),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 300.ms, delay: 200.ms)
                        .slideX(
                            begin: -0.3,
                            end: 0.0,
                            duration: 300.ms,
                            delay: 200.ms),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _getIconSize() {
    switch (widget.size) {
      case FABSize.small:
        return 16.0;
      case FABSize.medium:
        return 20.0;
      case FABSize.large:
        return 24.0;
    }
  }

  double _getFontSize() {
    switch (widget.size) {
      case FABSize.small:
        return 12.0;
      case FABSize.medium:
        return 14.0;
      case FABSize.large:
        return 16.0;
    }
  }

  EdgeInsets _getPadding() {
    switch (widget.size) {
      case FABSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMD,
          vertical: AppTheme.spacingXS,
        );
      case FABSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLG,
          vertical: AppTheme.spacingSM,
        );
      case FABSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLG, // Reduced from XL (32) to LG (24)
          vertical: AppTheme.spacingMD,
        );
    }
  }
}
