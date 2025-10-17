import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/hipop_colors.dart';
import '../../models/universal_review.dart';

/// Displays aggregate review statistics with breakdown by reviewer type
/// Used on vendor and market detail screens
class ReviewStatsCard extends StatelessWidget {
  final ReviewStats stats;
  final VoidCallback? onSeeAllReviews;
  final VoidCallback? onWriteReview;
  final bool expandable;
  final bool showReviewerBreakdown;

  const ReviewStatsCard({
    super.key,
    required this.stats,
    this.onSeeAllReviews,
    this.onWriteReview,
    this.expandable = false,
    this.showReviewerBreakdown = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (stats.totalReviews == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? HiPopColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? HiPopColors.darkBorder : HiPopColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? HiPopColors.darkShadow : HiPopColors.lightShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: expandable
          ? Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 20),
                childrenPadding: const EdgeInsets.only(bottom: 16),
                title: _buildHeader(context, isDark),
                children: [
                  _buildExpandedContent(context, isDark),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildHeader(context, isDark),
                  const SizedBox(height: 20),
                  _buildExpandedContent(context, isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Average rating display
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  stats.formattedRating,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: _getRatingColor(stats.averageRating),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStarDisplay(stats.averageRating),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              stats.reviewCountDisplay,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? HiPopColors.darkTextSecondary
                    : HiPopColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        const Spacer(),

        // Trust indicators
        _buildTrustBadges(isDark),
      ],
    );
  }

  Widget _buildExpandedContent(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Rating distribution bars
          _buildRatingDistribution(context, isDark),

          if (showReviewerBreakdown && stats.reviewerTypeBreakdown.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildReviewerTypeBreakdown(context, isDark),
          ],

          if (stats.aspectAverages.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildAspectRatings(context, isDark),
          ],

          if (stats.topTags.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildTopTags(context, isDark),
          ],

          if (onSeeAllReviews != null || onWriteReview != null) ...[
            const SizedBox(height: 20),
            _buildActionButtons(context, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildStarDisplay(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        if (starValue <= rating.floor()) {
          return Icon(
            Icons.star,
            color: Colors.amber,
            size: 20,
          );
        } else if (starValue - 0.5 <= rating) {
          return Icon(
            Icons.star_half,
            color: Colors.amber,
            size: 20,
          );
        } else {
          return Icon(
            Icons.star_border,
            color: HiPopColors.lightTextTertiary,
            size: 20,
          );
        }
      }),
    );
  }

  Widget _buildTrustBadges(bool isDark) {
    final badges = <Widget>[];

    if (stats.verifiedCount > 0) {
      final verifiedPercentage = (stats.verifiedCount / stats.totalReviews * 100).round();
      badges.add(_buildBadge(
        Icons.verified,
        '$verifiedPercentage% verified',
        HiPopColors.successGreen,
        isDark,
      ));
    }

    if (stats.photoCount > 0) {
      badges.add(_buildBadge(
        Icons.photo_camera,
        '${stats.photoCount}',
        HiPopColors.infoBlueGray,
        isDark,
      ));
    }

    if (stats.responseRate > 0.5) {
      final responsePercentage = (stats.responseRate * 100).round();
      badges.add(_buildBadge(
        Icons.reply,
        '$responsePercentage% replied',
        HiPopColors.primaryDeepSage,
        isDark,
      ));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: badges
          .map((badge) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: badge,
              ))
          .toList(),
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity( 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity( 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingDistribution(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rating Breakdown',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ...List.generate(5, (index) {
          final stars = 5 - index;
          final count = stats.ratingDistribution[stars] ?? 0;
          final percentage = stats.getRatingPercentage(stars);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '$stars',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? HiPopColors.darkTextSecondary
                          : HiPopColors.lightTextSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.star,
                  size: 14,
                  color: Colors.amber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: isDark
                              ? HiPopColors.darkBorder.withOpacity( 0.3)
                              : HiPopColors.lightBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percentage / 100,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getRatingColor(stars.toDouble()),
                                _getRatingColor(stars.toDouble())
                                    .withOpacity( 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? HiPopColors.darkTextSecondary
                          : HiPopColors.lightTextSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReviewerTypeBreakdown(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reviews by Type',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stats.reviewerTypeBreakdown.entries.map((entry) {
            final color = _getReviewerTypeColor(entry.key);
            final percentage = (entry.value / stats.totalReviews * 100).round();

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity( 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withOpacity( 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getReviewerTypeIcon(entry.key),
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_getReviewerTypeLabel(entry.key)}: ${entry.value} ($percentage%)',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAspectRatings(BuildContext context, bool isDark) {
    final sortedAspects = stats.aspectAverages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category Ratings',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ...sortedAspects.take(5).map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatAspectName(entry.key),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? HiPopColors.darkTextSecondary
                          : HiPopColors.lightTextSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildMiniStarRating(entry.value),
                const SizedBox(width: 8),
                Text(
                  entry.value.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getRatingColor(entry.value),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMiniStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        return Icon(
          starValue <= rating.round() ? Icons.star : Icons.star_border,
          size: 12,
          color: starValue <= rating.round()
              ? Colors.amber
              : HiPopColors.lightTextTertiary,
        );
      }),
    );
  }

  Widget _buildTopTags(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Common Mentions',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stats.topTags.map((tag) {
            return Chip(
              label: Text(
                tag,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? HiPopColors.darkTextPrimary
                      : HiPopColors.lightTextPrimary,
                ),
              ),
              backgroundColor: isDark
                  ? HiPopColors.darkSurfaceVariant
                  : HiPopColors.surfacePalePink,
              side: BorderSide(
                color: isDark ? HiPopColors.darkBorder : HiPopColors.lightBorder,
                width: 1,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isDark) {
    return Row(
      children: [
        if (onSeeAllReviews != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                onSeeAllReviews!();
              },
              icon: const Icon(Icons.visibility, size: 18),
              label: const Text('See All Reviews'),
              style: OutlinedButton.styleFrom(
                foregroundColor: HiPopColors.primaryDeepSage,
                side: BorderSide(color: HiPopColors.primaryDeepSage),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        if (onSeeAllReviews != null && onWriteReview != null)
          const SizedBox(width: 12),
        if (onWriteReview != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                onWriteReview!();
              },
              icon: const Icon(Icons.rate_review, size: 18),
              label: const Text('Write Review'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.primaryDeepSage,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 2,
              ),
            ),
          ),
      ],
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.5) return Colors.green;
    if (rating >= 4.0) return Colors.lightGreen;
    if (rating >= 3.0) return Colors.orange;
    if (rating >= 2.0) return Colors.deepOrange;
    return Colors.red;
  }

  Color _getReviewerTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'shopper':
        return HiPopColors.shopperAccent;
      case 'vendor':
        return HiPopColors.vendorAccent;
      case 'organizer':
        return HiPopColors.organizerAccent;
      default:
        return HiPopColors.primaryDeepSage;
    }
  }

  IconData _getReviewerTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'shopper':
        return Icons.shopping_bag;
      case 'vendor':
        return Icons.store;
      case 'organizer':
        return Icons.groups;
      default:
        return Icons.person;
    }
  }

  String _getReviewerTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'shopper':
        return 'Shoppers';
      case 'vendor':
        return 'Vendors';
      case 'organizer':
        return 'Organizers';
      default:
        return type;
    }
  }

  String _formatAspectName(String aspect) {
    // Convert from camelCase to Title Case
    final words = aspect.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => ' ${match.group(0)}',
    );
    return words[0].toUpperCase() + words.substring(1);
  }
}