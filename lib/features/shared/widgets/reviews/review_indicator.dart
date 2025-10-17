import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

/// Variant types for the review indicator
enum ReviewIndicatorVariant {
  /// Compact variant for cards - shows star + rating + count
  compact,
  /// Full variant with more detail - shows stars + rating text
  full,
  /// Mini variant for tight spaces - just star + rating
  mini,
  /// Extended variant with "Be first to rate" prompt
  extended,
}

/// Entity type for routing purposes
enum ReviewEntityType {
  vendor,
  market,
  post,
}

/// Review indicator widget that shows rating/review info on all cards
/// Shows rating badge if reviews exist, "Be first to rate" if no reviews
/// Tappable to view reviews or add rating
class ReviewIndicator extends StatelessWidget {
  final double? rating;
  final int reviewCount;
  final ReviewIndicatorVariant variant;
  final ReviewEntityType entityType;
  final String entityId;
  final String? entityName;
  final VoidCallback? onTap;
  final bool showInteractivePrompt;
  final bool isAnimated;
  final Color? customStarColor;
  final Color? customBackgroundColor;
  final TextStyle? customTextStyle;
  final EdgeInsetsGeometry? padding;
  final double? iconSize;

  const ReviewIndicator({
    super.key,
    this.rating,
    required this.reviewCount,
    this.variant = ReviewIndicatorVariant.compact,
    required this.entityType,
    required this.entityId,
    this.entityName,
    this.onTap,
    this.showInteractivePrompt = true,
    this.isAnimated = true,
    this.customStarColor,
    this.customBackgroundColor,
    this.customTextStyle,
    this.padding,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    // Determine what to show based on review status
    final hasReviews = reviewCount > 0 && rating != null && rating! > 0;

    // Build appropriate widget based on variant
    switch (variant) {
      case ReviewIndicatorVariant.compact:
        return _buildCompactIndicator(context, hasReviews);
      case ReviewIndicatorVariant.full:
        return _buildFullIndicator(context, hasReviews);
      case ReviewIndicatorVariant.mini:
        return _buildMiniIndicator(context, hasReviews);
      case ReviewIndicatorVariant.extended:
        return _buildExtendedIndicator(context, hasReviews);
    }
  }

  Widget _buildCompactIndicator(BuildContext context, bool hasReviews) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final effectivePadding = padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    final effectiveIconSize = iconSize ?? 14.0;
    final starColor = customStarColor ?? HiPopColors.premiumGold;
    final backgroundColor = customBackgroundColor ??
        (isDarkMode ? Colors.black.withOpacity( 0.3) : Colors.white.withOpacity( 0.9));

    Widget content;
    if (hasReviews) {
      // Show rating with star
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: effectiveIconSize,
            color: starColor,
          ),
          const SizedBox(width: 3),
          Text(
            rating!.toStringAsFixed(1),
            style: customTextStyle ?? TextStyle(
              fontSize: effectiveIconSize * 0.9,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : HiPopColors.darkTextPrimary,
            ),
          ),
          if (reviewCount > 0) ...[
            const SizedBox(width: 3),
            Text(
              '(${_formatCount(reviewCount)})',
              style: TextStyle(
                fontSize: effectiveIconSize * 0.8,
                color: (isDarkMode ? Colors.white : HiPopColors.darkTextSecondary)
                    .withOpacity( 0.7),
              ),
            ),
          ],
        ],
      );
    } else {
      // Show "Be first to rate" prompt
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_border_rounded,
            size: effectiveIconSize,
            color: HiPopColors.shopperAccent,
          ),
          const SizedBox(width: 3),
          Text(
            'Rate',
            style: TextStyle(
              fontSize: effectiveIconSize * 0.9,
              fontWeight: FontWeight.w500,
              color: HiPopColors.shopperAccent,
            ),
          ),
        ],
      );
    }

    // Wrap with interactive container
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleTap(context),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: isAnimated ? const Duration(milliseconds: 300) : Duration.zero,
          padding: effectivePadding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasReviews
                  ? starColor.withOpacity( 0.2)
                  : HiPopColors.shopperAccent.withOpacity( 0.3),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity( 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _buildFullIndicator(BuildContext context, bool hasReviews) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final effectivePadding = padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    final effectiveIconSize = iconSize ?? 16.0;
    final starColor = customStarColor ?? HiPopColors.premiumGold;

    Widget content;
    if (hasReviews) {
      // Show full rating display with multiple stars
      final fullStars = rating!.floor();
      final hasHalfStar = (rating! - fullStars) >= 0.5;

      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Star display
          ...List.generate(5, (index) {
            IconData icon;
            Color color;
            if (index < fullStars) {
              icon = Icons.star_rounded;
              color = starColor;
            } else if (index == fullStars && hasHalfStar) {
              icon = Icons.star_half_rounded;
              color = starColor;
            } else {
              icon = Icons.star_outline_rounded;
              color = starColor.withOpacity( 0.3);
            }
            return Icon(icon, size: effectiveIconSize, color: color);
          }),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rating!.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: effectiveIconSize * 0.9,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : HiPopColors.darkTextPrimary,
                ),
              ),
              Text(
                '$reviewCount ${reviewCount == 1 ? 'review' : 'reviews'}',
                style: TextStyle(
                  fontSize: effectiveIconSize * 0.7,
                  color: (isDarkMode ? Colors.white : HiPopColors.darkTextSecondary)
                      .withOpacity( 0.7),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // Show prominent "Be first to rate" call-to-action
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_reaction_outlined,
            size: effectiveIconSize * 1.2,
            color: HiPopColors.shopperAccent,
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Be first to rate',
                style: TextStyle(
                  fontSize: effectiveIconSize * 0.9,
                  fontWeight: FontWeight.w600,
                  color: HiPopColors.shopperAccent,
                ),
              ),
              if (entityName != null)
                Text(
                  'Share your experience',
                  style: TextStyle(
                    fontSize: effectiveIconSize * 0.7,
                    color: HiPopColors.shopperAccent.withOpacity( 0.7),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleTap(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: effectivePadding,
          decoration: BoxDecoration(
            gradient: hasReviews ? null : LinearGradient(
              colors: [
                HiPopColors.shopperAccent.withOpacity( 0.1),
                HiPopColors.shopperAccent.withOpacity( 0.05),
              ],
            ),
            color: hasReviews
                ? (isDarkMode ? HiPopColors.darkSurface : HiPopColors.lightSurface)
                : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasReviews
                  ? Colors.transparent
                  : HiPopColors.shopperAccent.withOpacity( 0.3),
            ),
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _buildMiniIndicator(BuildContext context, bool hasReviews) {
    final effectiveIconSize = iconSize ?? 12.0;
    final starColor = customStarColor ?? HiPopColors.premiumGold;

    if (hasReviews) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: effectiveIconSize,
            color: starColor,
          ),
          const SizedBox(width: 2),
          Text(
            rating!.toStringAsFixed(1),
            style: TextStyle(
              fontSize: effectiveIconSize * 0.9,
              fontWeight: FontWeight.w600,
              color: HiPopColors.darkTextPrimary,
            ),
          ),
        ],
      );
    } else {
      return GestureDetector(
        onTap: _handleTap(context),
        child: Icon(
          Icons.star_border_rounded,
          size: effectiveIconSize,
          color: HiPopColors.shopperAccent,
        ),
      );
    }
  }

  Widget _buildExtendedIndicator(BuildContext context, bool hasReviews) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconSize = iconSize ?? 18.0;
    final starColor = customStarColor ??
        (rating != null && rating! >= 4.5 ? HiPopColors.successGreen : HiPopColors.premiumGold);

    Widget content;
    if (hasReviews) {
      // Enhanced rating display with visual emphasis
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              starColor.withOpacity( 0.1),
              starColor.withOpacity( 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: starColor.withOpacity( 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: starColor.withOpacity( 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_rounded,
                size: effectiveIconSize * 1.2,
                color: starColor,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      rating!.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: effectiveIconSize,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : HiPopColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getRatingLabel(rating!),
                      style: TextStyle(
                        fontSize: effectiveIconSize * 0.8,
                        fontWeight: FontWeight.w500,
                        color: starColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Based on $reviewCount ${reviewCount == 1 ? 'review' : 'reviews'}',
                  style: TextStyle(
                    fontSize: effectiveIconSize * 0.7,
                    color: (isDarkMode ? Colors.white : HiPopColors.darkTextSecondary)
                        .withOpacity( 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.chevron_right,
              size: effectiveIconSize,
              color: HiPopColors.lightTextTertiary,
            ),
          ],
        ),
      );
    } else {
      // Prominent call-to-action for first review
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              HiPopColors.shopperAccent.withOpacity(0.15),
              HiPopColors.shopperAccent.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: HiPopColors.shopperAccent.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: HiPopColors.shopperAccent.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.rate_review,
                    size: effectiveIconSize,
                    color: HiPopColors.shopperAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Be the first to rate!',
                        style: TextStyle(
                          fontSize: effectiveIconSize * 0.9,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.shopperAccent,
                        ),
                      ),
                      if (entityName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Help others discover $entityName',
                          style: TextStyle(
                            fontSize: effectiveIconSize * 0.7,
                            color: HiPopColors.shopperAccent.withOpacity(0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: HiPopColors.shopperAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Rate Now',
                style: TextStyle(
                  fontSize: effectiveIconSize * 0.85,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleTap(context),
        borderRadius: BorderRadius.circular(16),
        child: content,
      ),
    );
  }

  VoidCallback? _handleTap(BuildContext context) {
    if (onTap != null) {
      return () {
        HapticFeedback.lightImpact();
        onTap!();
      };
    }

    // Default navigation based on entity type
    return () {
      HapticFeedback.lightImpact();
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        // Prompt login if not authenticated
        context.go('/login');
        return;
      }

      // Navigate to appropriate detail screen with review section
      switch (entityType) {
        case ReviewEntityType.vendor:
          context.go('/vendor/detail/$entityId?showReviews=true');
          break;
        case ReviewEntityType.market:
          context.go('/market/$entityId?showReviews=true');
          break;
        case ReviewEntityType.post:
          context.go('/vendor/post/$entityId?showReviews=true');
          break;
      }
    };
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 10000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '${(count / 1000).round()}k';
  }

  String _getRatingLabel(double rating) {
    if (rating >= 4.8) return 'Excellent';
    if (rating >= 4.5) return 'Great';
    if (rating >= 4.0) return 'Very Good';
    if (rating >= 3.5) return 'Good';
    if (rating >= 3.0) return 'Average';
    return 'Below Average';
  }
}

/// Quick rate button widget for headers and prominent CTAs
class QuickRateButton extends StatelessWidget {
  final ReviewEntityType entityType;
  final String entityId;
  final String? entityName;
  final VoidCallback? onRateComplete;
  final bool isPrimary;
  final bool showIcon;
  final String? customLabel;
  final EdgeInsetsGeometry? padding;

  const QuickRateButton({
    super.key,
    required this.entityType,
    required this.entityId,
    this.entityName,
    this.onRateComplete,
    this.isPrimary = true,
    this.showIcon = true,
    this.customLabel,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final label = customLabel ?? 'Rate';
    final effectivePadding = padding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: () => _handleRate(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: HiPopColors.shopperAccent,
          foregroundColor: Colors.white,
          padding: effectivePadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 2,
        ),
        icon: showIcon ? const Icon(Icons.star_rounded, size: 18) : const SizedBox.shrink(),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    } else {
      return OutlinedButton.icon(
        onPressed: () => _handleRate(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: HiPopColors.shopperAccent,
          side: BorderSide(
            color: HiPopColors.shopperAccent,
            width: 1.5,
          ),
          padding: effectivePadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        icon: showIcon ? const Icon(Icons.star_outline_rounded, size: 18) : const SizedBox.shrink(),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    }
  }

  void _handleRate(BuildContext context) {
    HapticFeedback.lightImpact();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Prompt login if not authenticated
      context.go('/login');
      return;
    }

    // Navigate to appropriate rating screen
    switch (entityType) {
      case ReviewEntityType.vendor:
        context.push('/vendor/$entityId/rate').then((_) {
          if (onRateComplete != null) onRateComplete!();
        });
        break;
      case ReviewEntityType.market:
        context.push('/market/$entityId/rate').then((_) {
          if (onRateComplete != null) onRateComplete!();
        });
        break;
      case ReviewEntityType.post:
        // For posts, redirect to vendor rating
        context.push('/vendor/$entityId/rate').then((_) {
          if (onRateComplete != null) onRateComplete!();
        });
        break;
    }
  }
}