import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/hipop_colors.dart';
import '../../models/universal_review.dart';

/// Quick one-tap rating button for lists and cards
/// Provides immediate feedback without leaving the current screen
class QuickRatingButton extends StatefulWidget {
  final String entityId;
  final String entityType;
  final String entityName;
  final ReviewStats? currentStats;
  final Function(double rating)? onQuickRate;
  final VoidCallback? onTapForDetails;
  final bool showCount;
  final bool compact;

  const QuickRatingButton({
    super.key,
    required this.entityId,
    required this.entityType,
    required this.entityName,
    this.currentStats,
    this.onQuickRate,
    this.onTapForDetails,
    this.showCount = true,
    this.compact = false,
  });

  @override
  State<QuickRatingButton> createState() => _QuickRatingButtonState();
}

class _QuickRatingButtonState extends State<QuickRatingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isExpanded = false;
  double? _tempRating;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.currentStats == null || widget.currentStats!.totalReviews == 0) {
      return _buildNoReviewsButton(isDark);
    }

    return widget.compact
        ? _buildCompactButton(isDark)
        : _buildFullButton(isDark);
  }

  Widget _buildNoReviewsButton(bool isDark) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        if (widget.onQuickRate != null) {
          setState(() {
            _isExpanded = true;
          });
          _animationController.forward();
        } else if (widget.onTapForDetails != null) {
          widget.onTapForDetails!();
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 8 : 12,
          vertical: widget.compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              HiPopColors.primaryOpacity(0.1),
              HiPopColors.accentOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: HiPopColors.primaryOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_outline,
              size: widget.compact ? 14 : 16,
              color: HiPopColors.primaryDeepSage,
            ),
            const SizedBox(width: 4),
            Text(
              'Be first!',
              style: TextStyle(
                fontSize: widget.compact ? 11 : 12,
                fontWeight: FontWeight.bold,
                color: HiPopColors.primaryDeepSage,
              ),
            ),
            if (!widget.compact) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: HiPopColors.premiumGold.withOpacity( 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+50',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.premiumGoldDark,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactButton(bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTapForDetails?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? HiPopColors.darkSurfaceVariant
              : HiPopColors.surfacePalePink.withOpacity( 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star,
              size: 14,
              color: Colors.amber,
            ),
            const SizedBox(width: 4),
            Text(
              widget.currentStats!.formattedRating,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _getRatingColor(widget.currentStats!.averageRating),
              ),
            ),
            if (widget.showCount) ...[
              const SizedBox(width: 4),
              Text(
                '(${widget.currentStats!.totalReviews})',
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
      ),
    );
  }

  Widget _buildFullButton(bool isDark) {
    if (_isExpanded) {
      return _buildExpandedRating(isDark);
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          if (widget.onQuickRate != null) {
            setState(() {
              _isExpanded = true;
            });
            _animationController.forward();
          } else if (widget.onTapForDetails != null) {
            widget.onTapForDetails!();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? HiPopColors.darkSurface
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? HiPopColors.darkBorder : HiPopColors.lightBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? HiPopColors.darkShadow.withOpacity( 0.3)
                    : HiPopColors.lightShadow.withOpacity( 0.5),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rating display
              _buildMiniStars(widget.currentStats!.averageRating),
              const SizedBox(width: 8),
              Text(
                widget.currentStats!.formattedRating,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _getRatingColor(widget.currentStats!.averageRating),
                ),
              ),
              if (widget.showCount) ...[
                const SizedBox(width: 4),
                Text(
                  '(${_formatCount(widget.currentStats!.totalReviews)})',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? HiPopColors.darkTextSecondary
                        : HiPopColors.lightTextSecondary,
                  ),
                ),
              ],
              if (widget.onQuickRate != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.add,
                  size: 16,
                  color: HiPopColors.primaryDeepSage,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedRating(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? HiPopColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: HiPopColors.primaryDeepSage,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: HiPopColors.primaryOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Quick Rate',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: HiPopColors.primaryDeepSage,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              final isSelected = _tempRating != null && starValue <= _tempRating!;

              return GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _tempRating = starValue.toDouble();
                  });

                  // Animate and submit
                  await Future.delayed(const Duration(milliseconds: 500));

                  if (widget.onQuickRate != null) {
                    widget.onQuickRate!(_tempRating!);
                  }

                  // Show success animation
                  _showSuccessAnimation();

                  // Reset after delay
                  await Future.delayed(const Duration(seconds: 2));
                  setState(() {
                    _isExpanded = false;
                    _tempRating = null;
                  });
                  _animationController.reverse();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isSelected ? Icons.star : Icons.star_border,
                    size: 32,
                    color: isSelected
                        ? Colors.amber
                        : (isDark ? HiPopColors.darkBorder : HiPopColors.lightBorder),
                  ),
                ),
              );
            }),
          ),
          if (_tempRating != null) ...[
            const SizedBox(height: 4),
            Text(
              _getRatingText(_tempRating!),
              style: TextStyle(
                fontSize: 11,
                color: _getRatingColor(_tempRating!),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        if (starValue <= rating.floor()) {
          return Icon(Icons.star, size: 14, color: Colors.amber);
        } else if (starValue - 0.5 <= rating) {
          return Icon(Icons.star_half, size: 14, color: Colors.amber);
        } else {
          return Icon(Icons.star_border, size: 14, color: HiPopColors.lightTextTertiary);
        }
      }),
    );
  }

  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) {
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.of(context).pop();
        });

        return Center(
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 600),
            tween: Tween(begin: 0, end: 1),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: HiPopColors.successGreen.withOpacity( 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check,
                    size: 40,
                    color: HiPopColors.successGreen,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.5) return Colors.green;
    if (rating >= 4.0) return Colors.lightGreen;
    if (rating >= 3.0) return Colors.orange;
    if (rating >= 2.0) return Colors.deepOrange;
    return Colors.red;
  }

  String _getRatingText(double rating) {
    if (rating >= 4.5) return 'Excellent!';
    if (rating >= 4.0) return 'Very Good';
    if (rating >= 3.0) return 'Good';
    if (rating >= 2.0) return 'Fair';
    return 'Poor';
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}