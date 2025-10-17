import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/market/models/market.dart';
import 'package:hipop/features/shared/services/universal_review_service.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
import 'package:hipop/features/shared/widgets/common/error_widget.dart';

/// Screen that handles the QR code market review flow
/// Allows shoppers to leave a review for a market after scanning QR code
class MarketQRReviewFlowScreen extends StatefulWidget {
  final String marketId;

  const MarketQRReviewFlowScreen({
    super.key,
    required this.marketId,
  });

  @override
  State<MarketQRReviewFlowScreen> createState() => _MarketQRReviewFlowScreenState();
}

class _MarketQRReviewFlowScreenState extends State<MarketQRReviewFlowScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UniversalReviewService _reviewService = UniversalReviewService();
  final TextEditingController _reviewController = TextEditingController();

  Market? _market;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  int _rating = 5;

  @override
  void initState() {
    super.initState();
    _loadMarket();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadMarket() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load market data
      final marketDoc = await _firestore
          .collection('markets')
          .doc(widget.marketId)
          .get();

      if (!marketDoc.exists) {
        setState(() {
          _error = 'Market not found';
          _isLoading = false;
        });
        return;
      }

      _market = Market.fromFirestore(marketDoc);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load market information: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitReview() async {
    if (_reviewController.text.trim().isEmpty) {
      setState(() {
        _error = 'Please write a review';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _reviewService.submitReview(
        reviewedId: widget.marketId,
        reviewedName: _market?.name ?? 'Market',
        reviewedType: 'market',
        overallRating: _rating.toDouble(),
        reviewText: _reviewController.text.trim(),
        verificationMethod: 'qr',  // QR verified review
      );

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully!'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );

        // Navigate to market reviews page
        context.go('/market/${widget.marketId}/reviews');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to submit review: ${e.toString()}';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text('Review Market'),
        backgroundColor: HiPopColors.darkSurface,
        foregroundColor: HiPopColors.darkTextPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading market information...')
          : _error != null && _market == null
              ? ErrorDisplayWidget(
                  title: 'Error',
                  message: _error!,
                  onRetry: _loadMarket,
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_market == null) {
      return const Center(
        child: Text(
          'Market information not available',
          style: TextStyle(color: HiPopColors.darkTextSecondary),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Market Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HiPopColors.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: HiPopColors.darkBorder.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.event,
                  size: 48,
                  color: HiPopColors.organizerAccent,
                ),
                const SizedBox(height: 12),
                Text(
                  _market!.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.darkTextPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${_market!.city}, ${_market!.state}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: HiPopColors.darkTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // QR Verified Badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HiPopColors.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: HiPopColors.successGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  color: HiPopColors.successGreen,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'This will be a QR-verified review, showing you attended this market',
                    style: TextStyle(
                      fontSize: 14,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Rating selector
          const Text(
            'Your Rating',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: HiPopColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final filled = index < _rating;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _rating = index + 1;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    filled ? Icons.star : Icons.star_border,
                    size: 40,
                    color: Colors.amber,
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 24),

          // Review text field
          const Text(
            'Your Review',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: HiPopColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reviewController,
            maxLines: 6,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Share your experience at this market...',
              hintStyle: const TextStyle(color: HiPopColors.darkTextTertiary),
              filled: true,
              fillColor: HiPopColors.darkSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: HiPopColors.shopperAccent,
                ),
              ),
              errorText: _error,
            ),
            style: const TextStyle(color: HiPopColors.darkTextPrimary),
          ),

          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.shopperAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Submit Review',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
