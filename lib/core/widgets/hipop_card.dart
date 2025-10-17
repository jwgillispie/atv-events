import 'package:flutter/material.dart';
import '../theme/hipop_colors.dart';

/// Custom card widget with HiPop marketplace styling
/// Provides consistent elevation, borders, and interaction states
class HiPopCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final Gradient? gradient;
  final double? width;
  final double? height;
  final bool isPremium;
  final bool isSelected;
  final bool showBorder;
  final double borderRadius;
  final List<BoxShadow>? customShadows;
  
  const HiPopCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.gradient,
    this.width,
    this.height,
    this.isPremium = false,
    this.isSelected = false,
    this.showBorder = true,
    this.borderRadius = 16,
    this.customShadows,
  });

  @override
  State<HiPopCard> createState() => _HiPopCardState();
}

class _HiPopCardState extends State<HiPopCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
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

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null || widget.onLongPress != null) {
      setState(() => _isPressed = true);
      _animationController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Determine colors based on theme and state
    // Force dark surface for consistent shopper UI
    final backgroundColor = widget.backgroundColor ?? HiPopColors.darkSurface;
    
    final borderColor = widget.isSelected
      ? HiPopColors.primaryDeepSage
      : widget.isPremium
        ? HiPopColors.premiumGold
        : HiPopColors.darkBorder;
    
    final borderWidth = widget.isSelected ? 2.0 : widget.isPremium ? 1.5 : 1.0;
    
    // Build shadows
    final shadows = widget.customShadows ?? [
      BoxShadow(
        color: Colors.black.withOpacity( 0.3),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
      if (_isPressed)
        BoxShadow(
          color: (widget.isPremium ? HiPopColors.premiumGold : HiPopColors.primaryDeepSage)
            .withOpacity( 0.1),
          blurRadius: 12,
          spreadRadius: -2,
        ),
    ];
    
    Widget card = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            margin: widget.margin,
            decoration: BoxDecoration(
              color: widget.gradient == null ? backgroundColor : null,
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: widget.showBorder
                ? Border.all(
                    color: borderColor,
                    width: borderWidth,
                  )
                : null,
              boxShadow: shadows,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius - 1),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  onLongPress: widget.onLongPress,
                  onTapDown: _handleTapDown,
                  onTapUp: _handleTapUp,
                  onTapCancel: _handleTapCancel,
                  splashColor: (widget.isPremium 
                    ? HiPopColors.premiumGold 
                    : HiPopColors.primaryDeepSage).withOpacity( 0.1),
                  highlightColor: (widget.isPremium 
                    ? HiPopColors.premiumGold 
                    : HiPopColors.primaryDeepSage).withOpacity( 0.05),
                  child: Padding(
                    padding: widget.padding ?? const EdgeInsets.all(16),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    
    // Add premium badge if needed
    if (widget.isPremium) {
      card = Stack(
        children: [
          card,
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: HiPopColors.premiumGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: HiPopColors.premiumGold.withOpacity( 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'PREMIUM',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    
    return card;
  }
}

/// Specialized market card for displaying market information
class MarketCard extends StatelessWidget {
  final String marketName;
  final String? location;
  final String? schedule;
  final String? imageUrl;
  final VoidCallback? onTap;
  final bool isPremium;
  final int? vendorCount;
  final double? rating;
  
  const MarketCard({
    super.key,
    required this.marketName,
    this.location,
    this.schedule,
    this.imageUrl,
    this.onTap,
    this.isPremium = false,
    this.vendorCount,
    this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return HiPopCard(
      onTap: onTap,
      isPremium: isPremium,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section
          if (imageUrl != null)
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                color: HiPopColors.darkSurfaceVariant,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: HiPopColors.darkSurfaceVariant,
                          child: Icon(
                            Icons.store_rounded,
                            size: 48,
                            color: HiPopColors.darkTextTertiary,
                          ),
                        );
                      },
                    ),
                  ),
                  if (rating != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity( 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: HiPopColors.warningAmber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating!.toStringAsFixed(1),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          
          // Content section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  marketName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (location != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: HiPopColors.darkTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location!,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (schedule != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 16,
                        color: HiPopColors.darkTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          schedule!,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (vendorCount != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: HiPopColors.secondarySoftSage.withOpacity( 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 14,
                          color: HiPopColors.secondarySoftSage,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$vendorCount vendors',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: HiPopColors.secondarySoftSage,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}