import 'package:flutter/material.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

/// Button types for different use cases
enum HiPopButtonType {
  primary,    // Main CTAs
  secondary,  // Secondary actions
  accent,     // Accent/coral CTAs
  success,    // Positive actions
  danger,     // Destructive actions
  ghost,      // Minimal style
  premium,    // Premium/gold style
}

/// Button sizes
enum HiPopButtonSize {
  small,
  medium,
  large,
}

/// Custom button widget with HiPop marketplace styling
class HiPopButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final HiPopButtonType type;
  final HiPopButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final bool outlined;
  final EdgeInsetsGeometry? padding;
  
  const HiPopButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = HiPopButtonType.primary,
    this.size = HiPopButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.outlined = false,
    this.padding,
  });

  /// Factory constructor for primary action button
  factory HiPopButton.primary({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    bool fullWidth = false,
  }) {
    return HiPopButton(
      text: text,
      onPressed: onPressed,
      type: HiPopButtonType.primary,
      icon: icon,
      isLoading: isLoading,
      fullWidth: fullWidth,
    );
  }

  /// Factory constructor for accent/coral CTA button
  factory HiPopButton.accent({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    bool fullWidth = false,
  }) {
    return HiPopButton(
      text: text,
      onPressed: onPressed,
      type: HiPopButtonType.accent,
      icon: icon,
      isLoading: isLoading,
      fullWidth: fullWidth,
    );
  }

  /// Factory constructor for danger/destructive button
  factory HiPopButton.danger({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
  }) {
    return HiPopButton(
      text: text,
      onPressed: onPressed,
      type: HiPopButtonType.danger,
      icon: icon,
      isLoading: isLoading,
    );
  }

  /// Factory constructor for ghost/minimal button
  factory HiPopButton.ghost({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
  }) {
    return HiPopButton(
      text: text,
      onPressed: onPressed,
      type: HiPopButtonType.ghost,
      icon: icon,
    );
  }

  @override
  State<HiPopButton> createState() => _HiPopButtonState();
}

class _HiPopButtonState extends State<HiPopButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (widget.outlined || widget.type == HiPopButtonType.ghost) {
      return Colors.transparent;
    }
    
    switch (widget.type) {
      case HiPopButtonType.primary:
        return isDark ? HiPopColors.secondarySoftSage : HiPopColors.primaryDeepSage;
      case HiPopButtonType.secondary:
        return isDark ? HiPopColors.darkSurfaceVariant : HiPopColors.lightSurfaceVariant;
      case HiPopButtonType.accent:
        return HiPopColors.accentMauve;
      case HiPopButtonType.success:
        return HiPopColors.successGreen;
      case HiPopButtonType.danger:
        return HiPopColors.errorPlum;
      case HiPopButtonType.premium:
        return HiPopColors.premiumGold;
      case HiPopButtonType.ghost:
        return Colors.transparent;
    }
  }

  Color _getTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (widget.outlined || widget.type == HiPopButtonType.ghost) {
      switch (widget.type) {
        case HiPopButtonType.primary:
          return isDark ? HiPopColors.secondarySoftSage : HiPopColors.primaryDeepSage;
        case HiPopButtonType.secondary:
          return isDark ? HiPopColors.darkTextPrimary : HiPopColors.lightTextPrimary;
        case HiPopButtonType.accent:
          return HiPopColors.accentMauve;
        case HiPopButtonType.success:
          return HiPopColors.successGreen;
        case HiPopButtonType.danger:
          return HiPopColors.errorPlum;
        case HiPopButtonType.premium:
          return HiPopColors.premiumGold;
        case HiPopButtonType.ghost:
          return isDark ? HiPopColors.darkTextSecondary : HiPopColors.lightTextSecondary;
      }
    }
    
    return widget.type == HiPopButtonType.secondary
      ? (isDark ? HiPopColors.darkTextPrimary : HiPopColors.lightTextPrimary)
      : Colors.white;
  }

  EdgeInsetsGeometry _getPadding() {
    if (widget.padding != null) return widget.padding!;
    
    switch (widget.size) {
      case HiPopButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case HiPopButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
      case HiPopButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 18);
    }
  }

  double _getFontSize() {
    switch (widget.size) {
      case HiPopButtonSize.small:
        return 14;
      case HiPopButtonSize.medium:
        return 16;
      case HiPopButtonSize.large:
        return 18;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = _getBackgroundColor(context);
    final textColor = _getTextColor(context);
    final isDisabled = widget.onPressed == null || widget.isLoading;
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.fullWidth ? double.infinity : null,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: widget.type == HiPopButtonType.premium && !widget.outlined
                ? HiPopColors.premiumGradient
                : null,
              boxShadow: widget.type != HiPopButtonType.ghost && !widget.outlined && !isDisabled
                ? [
                    BoxShadow(
                      color: backgroundColor.withOpacity( 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
            ),
            child: Material(
              color: widget.type == HiPopButtonType.premium && !widget.outlined
                ? Colors.transparent
                : backgroundColor,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: isDisabled ? null : () {
                  _animationController.forward().then((_) {
                    _animationController.reverse();
                  });
                  widget.onPressed?.call();
                },
                borderRadius: BorderRadius.circular(12),
                splashColor: textColor.withOpacity( 0.1),
                highlightColor: textColor.withOpacity( 0.05),
                child: Container(
                  padding: _getPadding(),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: widget.outlined
                      ? Border.all(
                          color: isDisabled
                            ? textColor.withOpacity( 0.3)
                            : textColor,
                          width: 1.5,
                        )
                      : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.isLoading) ...[
                        SizedBox(
                          width: _getFontSize(),
                          height: _getFontSize(),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              textColor.withOpacity( isDisabled ? 0.5 : 1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          size: _getFontSize() + 2,
                          color: textColor.withOpacity( isDisabled ? 0.5 : 1),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: TextStyle(
                          fontSize: _getFontSize(),
                          fontWeight: FontWeight.w600,
                          color: textColor.withOpacity( isDisabled ? 0.5 : 1),
                          letterSpacing: 0.5,
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
    );
  }
}

/// Icon button with HiPop styling
class HiPopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final String? tooltip;
  final bool showBackground;
  
  const HiPopIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.size = 24,
    this.tooltip,
    this.showBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = color ?? (isDark ? HiPopColors.darkTextPrimary : HiPopColors.lightTextPrimary);
    
    Widget button = Material(
      color: showBackground
        ? (isDark ? HiPopColors.darkSurfaceVariant : HiPopColors.lightSurfaceVariant)
        : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(showBackground ? 12 : 8),
          child: Icon(
            icon,
            size: size,
            color: onPressed == null 
              ? iconColor.withOpacity( 0.5)
              : iconColor,
          ),
        ),
      ),
    );
    
    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }
    
    return button;
  }
}

/// Floating action button with HiPop styling
class HiPopFAB extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;
  final bool extended;
  final bool mini;
  final Color? backgroundColor;
  
  const HiPopFAB({
    super.key,
    required this.icon,
    this.onPressed,
    this.label,
    this.extended = false,
    this.mini = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? HiPopColors.primaryDeepSage;
    
    if (extended && label != null) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        icon: Icon(icon),
        label: Text(
          label!,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      );
    }
    
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: bgColor,
      foregroundColor: Colors.white,
      mini: mini,
      shape: mini
        ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
        : const CircleBorder(),
      child: Icon(icon, size: mini ? 20 : 24),
    );
  }
}