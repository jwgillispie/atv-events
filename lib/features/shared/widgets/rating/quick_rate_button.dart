import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hipop/core/theme/hipop_colors.dart';

/// Quick rate button for one-tap reviews
/// Provides instant feedback without leaving the current screen
class QuickRateButton extends StatefulWidget {
  final String entityId;
  final String entityType; // 'product', 'vendor', 'market'
  final VoidCallback? onRated;
  final bool showLabel;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool isFloating;
  final EdgeInsetsGeometry? padding;

  const QuickRateButton({
    super.key,
    required this.entityId,
    required this.entityType,
    this.onRated,
    this.showLabel = true,
    this.size = 48,
    this.backgroundColor,
    this.iconColor,
    this.isFloating = false,
    this.padding,
  });

  @override
  State<QuickRateButton> createState() => _QuickRateButtonState();
}

class _QuickRateButtonState extends State<QuickRateButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _hasRated = false;
  bool _isExpanded = false;
  int? _selectedRating;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
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

  void _handleTap() {
    HapticFeedback.mediumImpact();

    if (_hasRated) {
      // Show already rated message
      _showRatedMessage();
      return;
    }

    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _handleRating(int rating) {
    HapticFeedback.heavyImpact();

    setState(() {
      _selectedRating = rating;
      _hasRated = true;
      _isExpanded = false;
    });

    _animationController.reverse();

    // Trigger success animation
    _showSuccessAnimation();

    // Callback
    widget.onRated?.call();
  }

  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => _SuccessDialog(rating: _selectedRating!),
    );

    // Auto dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _showRatedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'You rated this $_selectedRating stars',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: HiPopColors.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = widget.backgroundColor ??
      (_hasRated
        ? HiPopColors.successGreen.withOpacity( 0.2)
        : (isDarkMode
          ? HiPopColors.darkSurfaceVariant
          : HiPopColors.lightSurface));

    final iconColor = widget.iconColor ??
      (_hasRated
        ? HiPopColors.successGreen
        : HiPopColors.shopperAccent);

    if (widget.isFloating) {
      return _buildFloatingButton(bgColor, iconColor);
    }

    return _buildInlineButton(bgColor, iconColor);
  }

  Widget _buildFloatingButton(Color bgColor, Color iconColor) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Main button
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withOpacity( 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _handleTap,
                      customBorder: const CircleBorder(),
                      child: Icon(
                        _hasRated ? Icons.star : Icons.star_border,
                        color: iconColor,
                        size: widget.size * 0.5,
                      ),
                    ),
                  ),
                ),

                // Expanded rating options
                if (_isExpanded) _buildExpandedRatings(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInlineButton(Color bgColor, Color iconColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isExpanded ? 280 : (widget.showLabel ? 120 : widget.size),
      height: widget.size,
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(widget.size / 2),
        border: Border.all(
          color: iconColor.withOpacity( 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity( 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isExpanded ? null : _handleTap,
          borderRadius: BorderRadius.circular(widget.size / 2),
          child: _isExpanded
            ? _buildInlineRatingStars()
            : _buildCollapsedContent(iconColor),
        ),
      ),
    );
  }

  Widget _buildCollapsedContent(Color iconColor) {
    if (!widget.showLabel) {
      return Icon(
        _hasRated ? Icons.star : Icons.star_border,
        color: iconColor,
        size: widget.size * 0.5,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _hasRated ? Icons.star : Icons.star_border,
          color: iconColor,
          size: 20,
        ),
        const SizedBox(width: 6),
        Text(
          _hasRated ? 'Rated' : 'Rate',
          style: TextStyle(
            color: iconColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildInlineRatingStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (index) {
        final rating = index + 1;
        return GestureDetector(
          onTap: () => _handleRating(rating),
          child: AnimatedScale(
            scale: _selectedRating == rating ? 1.3 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.star,
              color: _selectedRating != null && rating <= _selectedRating!
                ? HiPopColors.premiumGold
                : HiPopColors.darkTextTertiary.withOpacity( 0.3),
              size: 32,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildExpandedRatings() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          final rating = index + 1;
          final angle = (index - 2) * 0.3; // Fan out effect

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _isExpanded ? 1 : 0),
            duration: Duration(milliseconds: 200 + (index * 50)),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(
                  (index - 2) * 50 * value,
                  -80 * value,
                ),
                child: Transform.rotate(
                  angle: angle * value,
                  child: Opacity(
                    opacity: value,
                    child: GestureDetector(
                      onTap: () => _handleRating(rating),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: HiPopColors.darkSurface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: HiPopColors.premiumGold.withOpacity( 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                color: HiPopColors.premiumGold,
                                size: 20,
                              ),
                              Text(
                                rating.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// Success dialog for rating confirmation
class _SuccessDialog extends StatelessWidget {
  final int rating;

  const _SuccessDialog({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HiPopColors.darkSurface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: HiPopColors.successGreen.withOpacity( 0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: HiPopColors.successGreen.withOpacity( 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: HiPopColors.successGreen,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Thanks for rating!',
                    style: TextStyle(
                      color: HiPopColors.darkTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: HiPopColors.premiumGold,
                        size: 20,
                      );
                    }),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Compact rate button for lists and grids
class CompactRateButton extends StatelessWidget {
  final String entityId;
  final String entityType;
  final VoidCallback? onTap;
  final bool hasRated;
  final int? rating;

  const CompactRateButton({
    super.key,
    required this.entityId,
    required this.entityType,
    this.onTap,
    this.hasRated = false,
    this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: hasRated
            ? HiPopColors.successGreen.withOpacity( 0.1)
            : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasRated
              ? HiPopColors.successGreen
              : HiPopColors.darkTextTertiary.withOpacity( 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasRated ? Icons.star : Icons.star_border,
              size: 14,
              color: hasRated
                ? HiPopColors.premiumGold
                : HiPopColors.darkTextTertiary,
            ),
            if (hasRated && rating != null) ...[
              const SizedBox(width: 4),
              Text(
                rating.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: HiPopColors.darkTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}