import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

/// Mini rating badge component for displaying ratings in compact spaces
/// Used in product cards, vendor cards, and throughout the app
class MiniRatingBadge extends StatelessWidget {
  final double rating;
  final int? reviewCount;
  final bool showCount;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? starColor;
  final Color? textColor;
  final VoidCallback? onTap;
  final bool isAnimated;
  final bool isPulsing;
  final bool isNew;

  const MiniRatingBadge({
    super.key,
    required this.rating,
    this.reviewCount,
    this.showCount = true,
    this.iconSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    this.backgroundColor,
    this.starColor,
    this.textColor,
    this.onTap,
    this.isAnimated = true,
    this.isPulsing = false,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Default colors based on theme
    final bgColor = backgroundColor ??
      (isDarkMode
        ? Colors.black.withOpacity( 0.4)
        : Colors.white.withOpacity( 0.9));

    final starIconColor = starColor ?? HiPopColors.premiumGold;
    final labelColor = textColor ??
      (isDarkMode ? Colors.white : HiPopColors.darkTextPrimary);

    // Determine badge content
    Widget badgeContent = _buildBadgeContent(starIconColor, labelColor);

    // Wrap with animation if needed
    if (isPulsing && isNew) {
      badgeContent = _PulsingAnimation(
        child: badgeContent,
      );
    }

    // Main badge container
    Widget badge = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null ? () {
          HapticFeedback.lightImpact();
          onTap?.call();
        } : null,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: isAnimated
            ? const Duration(milliseconds: 300)
            : Duration.zero,
          padding: padding,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: starIconColor.withOpacity( 0.3),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity( 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: badgeContent,
        ),
      ),
    );

    // Add "NEW" indicator if needed
    if (isNew) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          badge,
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: HiPopColors.successGreen,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: HiPopColors.successGreen.withOpacity( 0.4),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return badge;
  }

  Widget _buildBadgeContent(Color starIconColor, Color labelColor) {
    // Handle no rating case
    if (reviewCount == 0 || rating == 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_border,
            size: iconSize,
            color: labelColor.withOpacity( 0.5),
          ),
          const SizedBox(width: 3),
          Text(
            'New',
            style: TextStyle(
              color: labelColor.withOpacity( 0.7),
              fontSize: iconSize * 0.9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Star icon with gradient effect
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              starIconColor,
              starIconColor.withOpacity( 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Icon(
            _getStarIcon(rating),
            size: iconSize,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 3),

        // Rating value
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            color: labelColor,
            fontSize: iconSize * 0.9,
            fontWeight: FontWeight.w600,
          ),
        ),

        // Review count (optional)
        if (showCount && reviewCount != null) ...[
          const SizedBox(width: 2),
          Text(
            '(${_formatCount(reviewCount!)})',
            style: TextStyle(
              color: labelColor.withOpacity( 0.7),
              fontSize: iconSize * 0.75,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }

  IconData _getStarIcon(double rating) {
    if (rating >= 4.8) return Icons.star;
    if (rating >= 4.0) return Icons.star;
    if (rating >= 3.0) return Icons.star_half;
    return Icons.star_border;
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 10000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '${(count / 1000).round()}k';
  }
}

/// Pulsing animation for new ratings
class _PulsingAnimation extends StatefulWidget {
  final Widget child;

  const _PulsingAnimation({required this.child});

  @override
  State<_PulsingAnimation> createState() => _PulsingAnimationState();
}

class _PulsingAnimationState extends State<_PulsingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: widget.child,
        );
      },
    );
  }
}

/// Extended rating badge with more details
class ExtendedRatingBadge extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final VoidCallback? onTap;
  final bool showStars;
  final bool showBreakdown;
  final Map<int, int>? starBreakdown;

  const ExtendedRatingBadge({
    super.key,
    required this.rating,
    required this.reviewCount,
    this.onTap,
    this.showStars = true,
    this.showBreakdown = false,
    this.starBreakdown,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: HiPopColors.darkSurface.withOpacity( 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: HiPopColors.premiumGold.withOpacity( 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showStars) ...[
                    ...List.generate(5, (index) {
                      final starValue = index + 1;
                      return Icon(
                        starValue <= rating.round()
                          ? Icons.star
                          : starValue - 0.5 <= rating
                            ? Icons.star_half
                            : Icons.star_border,
                        size: 16,
                        color: HiPopColors.premiumGold,
                      );
                    }),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '($reviewCount)',
                    style: TextStyle(
                      fontSize: 14,
                      color: HiPopColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
              if (showBreakdown && starBreakdown != null) ...[
                const SizedBox(height: 8),
                _buildStarBreakdown(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStarBreakdown() {
    final total = starBreakdown!.values.fold<int>(0, (sum, count) => sum + count);

    return Column(
      children: List.generate(5, (index) {
        final stars = 5 - index;
        final count = starBreakdown![stars] ?? 0;
        final percentage = total > 0 ? (count / total) : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$stars',
                style: const TextStyle(
                  fontSize: 10,
                  color: HiPopColors.darkTextSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.star,
                size: 10,
                color: HiPopColors.premiumGold.withOpacity( 0.7),
              ),
              const SizedBox(width: 4),
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: HiPopColors.darkSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: percentage,
                  child: Container(
                    decoration: BoxDecoration(
                      color: HiPopColors.premiumGold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: HiPopColors.darkTextTertiary,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}