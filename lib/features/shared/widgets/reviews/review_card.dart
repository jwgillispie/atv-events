import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import '../../models/universal_review.dart';

/// Individual review display widget with photos, responses, and engagement
class ReviewCard extends StatefulWidget {
  final UniversalReview review;
  final VoidCallback? onHelpful;
  final VoidCallback? onRespond;
  final VoidCallback? onReport;
  final bool showResponse;
  final bool isHighlighted;
  final String? currentUserId;

  const ReviewCard({
    super.key,
    required this.review,
    this.onHelpful,
    this.onRespond,
    this.onReport,
    this.showResponse = true,
    this.isHighlighted = false,
    this.currentUserId,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isExpanded = false;
  bool _hasMarkedHelpful = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Check if current user has already marked as helpful
    if (widget.currentUserId != null) {
      _hasMarkedHelpful = widget.review.helpfulVoters.contains(widget.currentUserId);
    }

    if (widget.isHighlighted) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isHighlighted
            ? HiPopColors.primaryOpacity(0.05)
            : (isDark ? HiPopColors.darkSurface : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isHighlighted
              ? HiPopColors.primaryDeepSage
              : (isDark ? HiPopColors.darkBorder : HiPopColors.lightBorder),
          width: widget.isHighlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isHighlighted
                ? HiPopColors.primaryOpacity(0.2)
                : (isDark ? HiPopColors.darkShadow : HiPopColors.lightShadow),
            blurRadius: widget.isHighlighted ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, isDark),
              const SizedBox(height: 12),
              _buildRatingSection(isDark),
              if (widget.review.reviewText != null &&
                  widget.review.reviewText!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildReviewText(isDark),
              ],
              if (widget.review.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildTags(isDark),
              ],
              if (widget.review.photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildPhotos(),
              ],
              if (_isExpanded && widget.review.aspectRatings.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildAspectRatings(isDark),
              ],
              if (widget.showResponse && widget.review.responseText != null) ...[
                const SizedBox(height: 12),
                _buildResponse(context, isDark),
              ],
              const SizedBox(height: 12),
              _buildActions(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reviewer avatar
        CircleAvatar(
          radius: 20,
          backgroundColor: HiPopColors.primaryOpacity(0.1),
          backgroundImage: widget.review.reviewerPhotoUrl != null
              ? CachedNetworkImageProvider(widget.review.reviewerPhotoUrl!)
              : null,
          child: widget.review.reviewerPhotoUrl == null
              ? Icon(
                  _getReviewerIcon(),
                  size: 20,
                  color: HiPopColors.primaryDeepSage,
                )
              : null,
        ),
        const SizedBox(width: 12),

        // Reviewer info - full width
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name - full width on first line
              Text(
                widget.review.reviewerName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 6),

              // Badges and time on second line
              Row(
                children: [
                  _buildReviewerTypeBadge(isDark),
                  if (widget.review.isVerified) ...[
                    const SizedBox(width: 6),
                    _buildVerifiedBadge(isDark),
                  ],
                  const Spacer(),
                  Text(
                    widget.review.ageDisplay,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? HiPopColors.darkTextTertiary
                          : HiPopColors.lightTextTertiary,
                    ),
                  ),
                ],
              ),

              // Business name or edit indicator on third line if needed
              if (widget.review.reviewerBusinessName != null || widget.review.editCount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (widget.review.reviewerBusinessName != null) ...[
                      Expanded(
                        child: Text(
                          widget.review.reviewerBusinessName!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? HiPopColors.darkTextSecondary
                                : HiPopColors.lightTextSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (widget.review.editCount > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        'edited',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? HiPopColors.darkTextTertiary
                              : HiPopColors.lightTextTertiary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewerTypeBadge(bool isDark) {
    final color = _getReviewerTypeColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity( 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity( 0.3),
          width: 1,
        ),
      ),
      child: Text(
        widget.review.reviewerType.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildVerifiedBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: HiPopColors.successGreen.withOpacity( 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: HiPopColors.successGreen.withOpacity( 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified,
            size: 10,
            color: HiPopColors.successGreen,
          ),
          const SizedBox(width: 2),
          Text(
            'VERIFIED',
            style: TextStyle(
              fontSize: 10,
              color: HiPopColors.successGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection(bool isDark) {
    return Row(
      children: [
        // Overall rating stars
        Row(
          children: List.generate(5, (index) {
            final starValue = index + 1;
            if (starValue <= widget.review.overallRating.floor()) {
              return Icon(Icons.star, color: Colors.amber, size: 20);
            } else if (starValue - 0.5 <= widget.review.overallRating) {
              return Icon(Icons.star_half, color: Colors.amber, size: 20);
            } else {
              return Icon(Icons.star_border,
                  color: HiPopColors.lightTextTertiary, size: 20);
            }
          }),
        ),
        const SizedBox(width: 8),
        Text(
          widget.review.overallRating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: widget.review.ratingColor,
          ),
        ),
        if (widget.review.eventName != null) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: HiPopColors.infoBlueGray.withOpacity( 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on,
                  size: 12,
                  color: HiPopColors.infoBlueGray,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.review.eventName!,
                  style: TextStyle(
                    fontSize: 11,
                    color: HiPopColors.infoBlueGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewText(bool isDark) {
    final isLongText = widget.review.reviewText!.length > 150;
    final displayText = isLongText && !_isExpanded
        ? '${widget.review.reviewText!.substring(0, 150)}...'
        : widget.review.reviewText!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayText,
          style: TextStyle(
            fontSize: 14,
            color: isDark
                ? HiPopColors.darkTextPrimary
                : HiPopColors.lightTextPrimary,
            height: 1.5,
          ),
        ),
        if (isLongText) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Text(
              _isExpanded ? 'Show less' : 'Read more',
              style: TextStyle(
                fontSize: 13,
                color: HiPopColors.primaryDeepSage,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTags(bool isDark) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: widget.review.tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? HiPopColors.darkSurfaceVariant
                : HiPopColors.surfacePalePink,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            tag,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? HiPopColors.darkTextSecondary
                  : HiPopColors.lightTextSecondary,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPhotos() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.review.photos.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: index < widget.review.photos.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () {
                _showPhotoViewer(context, index);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: widget.review.photos[index],
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: HiPopColors.lightShimmer,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: HiPopColors.lightBorder,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAspectRatings(bool isDark) {
    final aspects = UniversalReview.getAspectDefinitions(
      widget.review.reviewerType,
      widget.review.reviewedType,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? HiPopColors.darkSurfaceVariant
            : HiPopColors.surfacePalePink.withOpacity( 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detailed Ratings',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? HiPopColors.darkTextPrimary
                  : HiPopColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.review.aspectRatings.entries.map((entry) {
            final label = aspects[entry.key] ?? entry.key;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? HiPopColors.darkTextSecondary
                            : HiPopColors.lightTextSecondary,
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < entry.value ? Icons.star : Icons.star_border,
                        size: 12,
                        color: index < entry.value
                            ? Colors.amber
                            : HiPopColors.lightTextTertiary,
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.value.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _getRatingColor(entry.value),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResponse(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HiPopColors.primaryOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HiPopColors.primaryOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.reply,
                size: 16,
                color: HiPopColors.primaryDeepSage,
              ),
              const SizedBox(width: 8),
              Text(
                'Response from ${widget.review.responderName ?? widget.review.reviewedName}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: HiPopColors.primaryDeepSage,
                ),
              ),
              if (widget.review.responseDate != null) ...[
                const Spacer(),
                Text(
                  _formatResponseTime(),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? HiPopColors.darkTextTertiary
                        : HiPopColors.lightTextTertiary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.review.responseText!,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? HiPopColors.darkTextPrimary
                  : HiPopColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, bool isDark) {
    return Row(
      children: [
        // Helpful button
        InkWell(
          onTap: _hasMarkedHelpful ? null : () {
            HapticFeedback.lightImpact();
            setState(() {
              _hasMarkedHelpful = true;
            });
            widget.onHelpful?.call();
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _hasMarkedHelpful
                  ? HiPopColors.successGreen.withOpacity( 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _hasMarkedHelpful
                    ? HiPopColors.successGreen.withOpacity( 0.3)
                    : (isDark ? HiPopColors.darkBorder : HiPopColors.lightBorder),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _hasMarkedHelpful ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 16,
                  color: _hasMarkedHelpful
                      ? HiPopColors.successGreen
                      : (isDark
                          ? HiPopColors.darkTextSecondary
                          : HiPopColors.lightTextSecondary),
                ),
                const SizedBox(width: 6),
                Text(
                  'Helpful${widget.review.helpfulCount > 0 ? ' (${widget.review.helpfulCount})' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: _hasMarkedHelpful
                        ? HiPopColors.successGreen
                        : (isDark
                            ? HiPopColors.darkTextSecondary
                            : HiPopColors.lightTextSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Respond button (if applicable)
        if (widget.onRespond != null && widget.review.responseText == null) ...[
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onRespond!();
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? HiPopColors.darkBorder : HiPopColors.lightBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.reply,
                    size: 16,
                    color: isDark
                        ? HiPopColors.darkTextSecondary
                        : HiPopColors.lightTextSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Respond',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? HiPopColors.darkTextSecondary
                          : HiPopColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const Spacer(),

        // Report button
        if (widget.onReport != null) ...[
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              widget.onReport!();
            },
            icon: Icon(
              Icons.flag_outlined,
              size: 18,
              color: isDark
                  ? HiPopColors.darkTextTertiary
                  : HiPopColors.lightTextTertiary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ],
    );
  }

  void _showPhotoViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _PhotoViewerScreen(
          photos: widget.review.photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  IconData _getReviewerIcon() {
    switch (widget.review.reviewerType) {
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

  Color _getReviewerTypeColor() {
    switch (widget.review.reviewerType) {
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

  Color _getRatingColor(double rating) {
    if (rating >= 4.5) return Colors.green;
    if (rating >= 4.0) return Colors.lightGreen;
    if (rating >= 3.0) return Colors.orange;
    if (rating >= 2.0) return Colors.deepOrange;
    return Colors.red;
  }

  String _formatResponseTime() {
    if (widget.review.responseDate == null) return '';
    final difference = widget.review.responseDate!.difference(widget.review.createdAt);
    if (difference.inDays > 0) {
      return 'Replied in ${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return 'Replied in ${difference.inHours}h';
    } else {
      return 'Replied in ${difference.inMinutes}m';
    }
  }
}

/// Simple photo viewer screen for review photos
class _PhotoViewerScreen extends StatelessWidget {
  final List<String> photos;
  final int initialIndex;

  const _PhotoViewerScreen({
    required this.photos,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: photos[index],
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}