import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hipop/core/theme/hipop_colors.dart';

/// Quick rating bottom sheet for simplified 2-step review process
class QuickRatingBottomSheet extends StatefulWidget {
  final String entityId;
  final String entityType;
  final String entityName;
  final String? entityImage;
  final Function(int rating, String? comment)? onSubmit;

  const QuickRatingBottomSheet({
    super.key,
    required this.entityId,
    required this.entityType,
    required this.entityName,
    this.entityImage,
    this.onSubmit,
  });

  static Future<void> show({
    required BuildContext context,
    required String entityId,
    required String entityType,
    required String entityName,
    String? entityImage,
    Function(int rating, String? comment)? onSubmit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickRatingBottomSheet(
        entityId: entityId,
        entityType: entityType,
        entityName: entityName,
        entityImage: entityImage,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<QuickRatingBottomSheet> createState() => _QuickRatingBottomSheetState();
}

class _QuickRatingBottomSheetState extends State<QuickRatingBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  int? _selectedRating;
  String _comment = '';
  bool _showCommentField = false;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();

  // Quick comment suggestions
  final List<String> _quickComments = [
    'Great experience!',
    'Loved it!',
    'Will come back',
    'Amazing products',
    'Friendly vendor',
    'Good prices',
    'Nice selection',
    'Quick service',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _handleRatingSelect(int rating) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedRating = rating;
      if (rating >= 4) {
        // High rating - submit immediately or show optional comment
        _showCommentField = true;
      } else {
        // Low rating - encourage feedback
        _showCommentField = true;
        Future.delayed(const Duration(milliseconds: 300), () {
          _commentFocus.requestFocus();
        });
      }
    });
  }

  void _handleQuickComment(String comment) {
    HapticFeedback.lightImpact();
    setState(() {
      _commentController.text = comment;
      _comment = comment;
    });
  }

  void _submitRating() {
    if (_selectedRating == null) return;

    HapticFeedback.heavyImpact();

    // Call the callback
    widget.onSubmit?.call(_selectedRating!, _comment.isEmpty ? null : _comment);

    // Show success animation
    _showSuccessAndClose();
  }

  void _showSuccessAndClose() {
    setState(() {
      _showCommentField = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _SuccessAnimation(rating: _selectedRating!),
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pop(); // Close success dialog
        Navigator.of(context).pop(); // Close bottom sheet
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 100),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              padding: EdgeInsets.only(bottom: keyboardHeight),
              decoration: const BoxDecoration(
                color: HiPopColors.darkSurface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  _buildHandleBar(),

                  // Header
                  _buildHeader(),

                  // Rating stars
                  _buildRatingStars(),

                  // Comment section (conditional)
                  if (_showCommentField) _buildCommentSection(),

                  // Submit button
                  if (_selectedRating != null) _buildSubmitButton(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHandleBar() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: HiPopColors.darkTextTertiary.withOpacity( 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (widget.entityImage != null)
            CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage(widget.entityImage!),
              backgroundColor: HiPopColors.darkSurfaceVariant,
            ),
          const SizedBox(height: 12),
          Text(
            'Rate ${widget.entityName}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: HiPopColors.darkTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a star to rate',
            style: TextStyle(
              fontSize: 14,
              color: HiPopColors.darkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingStars() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          final rating = index + 1;
          final isSelected = _selectedRating != null && rating <= _selectedRating!;

          return GestureDetector(
            onTap: () => _handleRatingSelect(rating),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                isSelected ? Icons.star : Icons.star_border,
                size: 48,
                color: isSelected
                  ? HiPopColors.premiumGold
                  : HiPopColors.darkTextTertiary.withOpacity( 0.5),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCommentSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick comment chips
          if (_selectedRating != null && _selectedRating! >= 4) ...[
            const Text(
              'Quick feedback (optional):',
              style: TextStyle(
                fontSize: 14,
                color: HiPopColors.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickComments.map((comment) {
                final isSelected = _commentController.text == comment;
                return GestureDetector(
                  onTap: () => _handleQuickComment(comment),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                        ? HiPopColors.shopperAccent.withOpacity( 0.2)
                        : HiPopColors.darkSurfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                          ? HiPopColors.shopperAccent
                          : HiPopColors.darkBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      comment,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                          ? HiPopColors.shopperAccent
                          : HiPopColors.darkTextPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Comment text field
          TextField(
            controller: _commentController,
            focusNode: _commentFocus,
            maxLines: 3,
            maxLength: 200,
            style: const TextStyle(
              color: HiPopColors.darkTextPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: _selectedRating != null && _selectedRating! < 4
                ? 'Please tell us what could be improved...'
                : 'Add a comment (optional)',
              hintStyle: TextStyle(
                color: HiPopColors.darkTextTertiary,
                fontSize: 14,
              ),
              filled: true,
              fillColor: HiPopColors.darkSurfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: HiPopColors.darkBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: HiPopColors.darkBorder.withOpacity( 0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: HiPopColors.shopperAccent,
                  width: 1.5,
                ),
              ),
              counterStyle: TextStyle(
                color: HiPopColors.darkTextTertiary,
                fontSize: 12,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _comment = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = _selectedRating != null &&
      (_selectedRating! >= 4 || _comment.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: canSubmit ? _submitRating : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: HiPopColors.shopperAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check, size: 20),
              const SizedBox(width: 8),
              Text(
                _showCommentField && _selectedRating! < 4 && _comment.isEmpty
                  ? 'Add feedback to submit'
                  : 'Submit Rating',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Success animation widget
class _SuccessAnimation extends StatefulWidget {
  final int rating;

  const _SuccessAnimation({required this.rating});

  @override
  State<_SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<_SuccessAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: HiPopColors.darkSurface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: HiPopColors.successGreen.withOpacity( 0.4),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 64,
                      color: HiPopColors.successGreen,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Thanks!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        return Icon(
                          index < widget.rating ? Icons.star : Icons.star_border,
                          color: HiPopColors.premiumGold,
                          size: 24,
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}