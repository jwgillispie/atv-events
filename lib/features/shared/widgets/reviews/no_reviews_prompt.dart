import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/hipop_colors.dart';

/// Engaging empty state widget for entities with no reviews
/// Encourages users to be the first reviewer with gamification elements
class NoReviewsPrompt extends StatelessWidget {
  final String entityType; // 'vendor', 'market', 'organizer'
  final String entityName;
  final bool isNewEntity; // Shows "New" badge if true
  final VoidCallback? onWriteReview;
  final bool canReview; // Whether current user can review this entity

  const NoReviewsPrompt({
    super.key,
    required this.entityType,
    required this.entityName,
    this.onWriteReview,
    this.isNewEntity = false,
    this.canReview = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  HiPopColors.darkSurface,
                  HiPopColors.darkSurfaceVariant,
                ]
              : [
                  HiPopColors.surfacePalePink,
                  HiPopColors.surfaceSoftPink,
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? HiPopColors.darkBorder : HiPopColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? HiPopColors.darkShadow : HiPopColors.lightShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Decorative background pattern
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HiPopColors.primaryOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HiPopColors.accentOpacity(0.05),
                ),
              ),
            ),

            // Main content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge and icon row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isNewEntity) ...[
                        _buildNewBadge(isDark),
                        const SizedBox(width: 12),
                      ],
                      _buildEntityIcon(),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Main message
                  Text(
                    _getMainMessage(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: isDark
                          ? HiPopColors.darkTextPrimary
                          : HiPopColors.lightTextPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    _getSubtitle(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? HiPopColors.darkTextSecondary
                          : HiPopColors.lightTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  if (canReview && onWriteReview != null) ...[
                    const SizedBox(height: 24),

                    // CTA Button
                    _buildCTAButton(context, isDark),
                  ] else ...[
                    const SizedBox(height: 24),
                    _buildIneligibleMessage(theme, isDark),
                  ],

                  const SizedBox(height: 16),

                  // Trust indicators
                  _buildTrustIndicators(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: HiPopColors.successGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: HiPopColors.successGreen.withOpacity( 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            _getNewBadgeText(),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntityIcon() {
    IconData icon;
    Color color;

    switch (entityType) {
      case 'vendor':
        icon = Icons.store;
        color = HiPopColors.vendorAccent;
        break;
      case 'market':
        icon = Icons.festival;
        color = HiPopColors.organizerAccent;
        break;
      case 'organizer':
        icon = Icons.groups;
        color = HiPopColors.organizerAccent;
        break;
      default:
        icon = Icons.star_outline;
        color = HiPopColors.primaryDeepSage;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity( 0.1),
        border: Border.all(
          color: color.withOpacity( 0.3),
          width: 2,
        ),
      ),
      child: Icon(
        icon,
        size: 48,
        color: color,
      ),
    );
  }

  Widget _buildCTAButton(BuildContext context, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onWriteReview?.call();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            gradient: HiPopColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: HiPopColors.primaryDeepSage.withOpacity( 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.rate_review,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _getCTAText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildIneligibleMessage(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.infoBlueGray.withOpacity( 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HiPopColors.infoBlueGray.withOpacity( 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            color: HiPopColors.infoBlueGray,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            _getIneligibleReason(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? HiPopColors.darkTextSecondary
                  : HiPopColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrustIndicators(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTrustItem(
          Icons.verified_user,
          'Verified Reviews',
          isDark,
        ),
        const SizedBox(width: 24),
        _buildTrustItem(
          Icons.visibility,
          'Public',
          isDark,
        ),
      ],
    );
  }

  Widget _buildTrustItem(IconData icon, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark
              ? HiPopColors.darkTextTertiary
              : HiPopColors.lightTextTertiary,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? HiPopColors.darkTextTertiary
                : HiPopColors.lightTextTertiary,
          ),
        ),
      ],
    );
  }

  String _getMainMessage() {
    if (isNewEntity) {
      switch (entityType) {
        case 'vendor':
          return 'New vendor alert!';
        case 'market':
          return 'Fresh market listing!';
        case 'organizer':
          return 'New organizer joined!';
        default:
          return 'Be the first to review!';
      }
    }
    return 'No reviews yet';
  }

  String _getSubtitle() {
    switch (entityType) {
      case 'vendor':
        return 'Help shoppers discover this vendor by sharing your experience';
      case 'market':
        return 'Share what makes this market special for the community';
      case 'organizer':
        return 'Your feedback helps vendors choose the best markets';
      default:
        return 'Be the first to share your experience';
    }
  }

  String _getNewBadgeText() {
    switch (entityType) {
      case 'vendor':
        return 'NEW VENDOR';
      case 'market':
        return 'RECENTLY LISTED';
      case 'organizer':
        return 'NEW ORGANIZER';
      default:
        return 'NEW';
    }
  }

  String _getCTAText() {
    switch (entityType) {
      case 'vendor':
        return 'Review This Vendor';
      case 'market':
        return 'Rate This Market';
      case 'organizer':
        return 'Share Your Experience';
      default:
        return 'Write a Review';
    }
  }

  String _getIneligibleReason() {
    switch (entityType) {
      case 'vendor':
        return 'Visit this vendor at a market to leave a review';
      case 'market':
        return 'Attend this market to share your experience';
      case 'organizer':
        return 'Participate in their events to leave feedback';
      default:
        return 'You need to interact with this entity first';
    }
  }
}