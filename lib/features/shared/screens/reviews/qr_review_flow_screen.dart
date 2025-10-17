import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/vendor/models/vendor_post.dart';
import 'package:atv_events/features/shared/models/user_profile.dart';
import 'package:atv_events/features/shared/services/universal_review_service.dart';
import 'package:atv_events/features/shared/widgets/common/loading_widget.dart';
import 'package:atv_events/features/shared/widgets/common/error_widget.dart';
import 'package:atv_events/features/market/models/market.dart';

/// Screen that handles the QR code review flow
/// Allows users to select which market they're at before leaving a review
class QRReviewFlowScreen extends StatefulWidget {
  final String vendorId;

  const QRReviewFlowScreen({
    super.key,
    required this.vendorId,
  });

  @override
  State<QRReviewFlowScreen> createState() => _QRReviewFlowScreenState();
}

class _QRReviewFlowScreenState extends State<QRReviewFlowScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserProfile? _vendorProfile;
  List<VendorPost> _activeVendorPosts = [];
  Map<String, Market> _markets = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      print('🔵 [QR REVIEW] ========== STARTING DATA LOAD ==========');
      print('🔵 [QR REVIEW] VendorId from QR: ${widget.vendorId}');

      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load vendor profile from user_profiles collection
      print('🔵 [QR REVIEW] Querying Firestore: collection=user_profiles, doc=${widget.vendorId}');
      final vendorDoc = await _firestore
          .collection('user_profiles')
          .doc(widget.vendorId)
          .get();

      print('🔵 [QR REVIEW] Vendor doc exists: ${vendorDoc.exists}');
      if (vendorDoc.exists) {
        print('🟢 [QR REVIEW] Vendor found in user_profiles!');
        print('🔵 [QR REVIEW] Vendor doc data: ${vendorDoc.data()}');
      } else {
        print('🔴 [QR REVIEW] VENDOR NOT FOUND IN FIRESTORE!');
        print('🔴 [QR REVIEW] Checked path: user_profiles/${widget.vendorId}');
      }

      if (!vendorDoc.exists) {
        setState(() {
          _error = 'Vendor profile not found. This vendor may need to complete their account setup.';
          _isLoading = false;
        });
        return;
      }

      _vendorProfile = UserProfile.fromFirestore(vendorDoc);

      // Load recent vendor posts for this vendor (past 90 days)
      final now = DateTime.now();
      final ninetyDaysAgo = now.subtract(const Duration(days: 90));

      print('🔵 [QR REVIEW] Querying vendor_posts for past 90 days...');
      print('🔵 [QR REVIEW] Date range: ${ninetyDaysAgo.toString()} to ${now.toString()}');

      final vendorPostsQuery = await _firestore
          .collection('vendor_posts')
          .where('vendorId', isEqualTo: widget.vendorId)
          .where('popUpStartDateTime', isGreaterThanOrEqualTo: ninetyDaysAgo)
          .get();

      print('🔵 [QR REVIEW] Found ${vendorPostsQuery.docs.length} vendor posts');

      _activeVendorPosts = vendorPostsQuery.docs
          .map((doc) => VendorPost.fromFirestore(doc))
          .where((post) {
            // Only show posts that have started (not future posts)
            // and are within 90 days
            if (post.popUpStartDateTime.isAfter(now)) {
              print('🔵 [QR REVIEW] Excluding future post: ${post.popUpStartDateTime}');
              return false;
            }
            return true;
          })
          .toList();

      // Sort by start time (most recent first)
      _activeVendorPosts.sort((a, b) => b.popUpStartDateTime.compareTo(a.popUpStartDateTime));

      // Load associated markets
      final marketIds = _activeVendorPosts
          .map((post) => post.marketId)
          .where((id) => id != null)
          .cast<String>()
          .toSet()
          .toList();

      if (marketIds.isNotEmpty) {
        final marketsQuery = await _firestore
            .collection('markets')
            .where(FieldPath.documentId, whereIn: marketIds)
            .get();

        for (var doc in marketsQuery.docs) {
          _markets[doc.id] = Market.fromFirestore(doc);
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load vendor information: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _selectMarket(VendorPost post) {
    final market = post.marketId != null ? _markets[post.marketId!] : null;
    _showReviewDialog(
      marketId: post.marketId,
      marketName: market?.name ?? post.vendorName,
    );
  }

  void _leaveGeneralReview() {
    _showReviewDialog();
  }

  void _showReviewDialog({String? marketId, String? marketName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReviewSubmissionSheet(
        vendorId: widget.vendorId,
        vendorName: _vendorProfile?.businessName ?? _vendorProfile?.displayName ?? 'Vendor',
        marketId: marketId,
        marketName: marketName,
        verificationMethod: 'qr',
        onSubmitted: () {
          // Show success and navigate back
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review submitted successfully!'),
              backgroundColor: HiPopColors.successGreen,
            ),
          );
          Navigator.of(context).pop();
          // Navigate to the vendor's reviews page
          context.go('/vendor/${widget.vendorId}/reviews');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text('Select Market'),
        backgroundColor: HiPopColors.darkSurface,
        foregroundColor: HiPopColors.darkTextPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading vendor information...')
          : _error != null
              ? ErrorDisplayWidget(
                  title: 'Error',
                  message: _error!,
                  onRetry: _loadData,
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_vendorProfile == null) {
      return const Center(
        child: Text(
          'Vendor information not available',
          style: TextStyle(color: HiPopColors.darkTextSecondary),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vendor Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HiPopColors.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: HiPopColors.darkBorder.withOpacity( 0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.store,
                  size: 48,
                  color: HiPopColors.vendorAccent,
                ),
                const SizedBox(height: 12),
                Text(
                  _vendorProfile?.businessName ??
                  _vendorProfile?.displayName ??
                  'Vendor',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.darkTextPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HiPopColors.shopperAccent.withOpacity( 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: HiPopColors.shopperAccent.withOpacity( 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: HiPopColors.shopperAccent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Select the market you\'re currently at to leave a review',
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

          // Recent Markets Section
          if (_activeVendorPosts.isNotEmpty) ...[
            const Text(
              'Recent Pop-ups (Past 90 Days)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ..._activeVendorPosts.map((post) {
              final market = post.marketId != null ? _markets[post.marketId!] : null;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: HiPopColors.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _selectMarket(post),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: HiPopColors.darkBorder.withOpacity( 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: HiPopColors.vendorAccent.withOpacity( 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: HiPopColors.vendorAccent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  market?.name ?? post.vendorName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: HiPopColors.darkTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  post.location,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: HiPopColors.darkTextSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDateTime(post.popUpStartDateTime, post.popUpEndDateTime),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: HiPopColors.darkTextTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: HiPopColors.darkTextTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ] else ...[
            // No Active Pop-ups
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HiPopColors.darkSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: HiPopColors.darkBorder.withOpacity( 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 48,
                    color: HiPopColors.darkTextTertiary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No Recent Pop-ups',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This vendor hasn\'t had any pop-ups in the past 90 days',
                    style: TextStyle(
                      fontSize: 14,
                      color: HiPopColors.darkTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // General Review Option
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HiPopColors.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: HiPopColors.primaryDeepSage.withOpacity( 0.3),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Or leave a general review',
                  style: TextStyle(
                    fontSize: 14,
                    color: HiPopColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _leaveGeneralReview,
                  icon: const Icon(Icons.rate_review),
                  label: const Text('Write General Review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HiPopColors.primaryDeepSage,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime start, DateTime? end) {
    final now = DateTime.now();
    final isToday = start.year == now.year &&
                    start.month == now.month &&
                    start.day == now.day;

    if (isToday) {
      final timeStr = _formatTime(start);
      if (end != null) {
        return 'Today, $timeStr - ${_formatTime(end)}';
      }
      return 'Today, $timeStr';
    }

    final dateStr = '${start.month}/${start.day}';
    final timeStr = _formatTime(start);
    if (end != null) {
      return '$dateStr, $timeStr - ${_formatTime(end)}';
    }
    return '$dateStr, $timeStr';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }
}

/// Review submission bottom sheet
class _ReviewSubmissionSheet extends StatefulWidget {
  final String vendorId;
  final String vendorName;
  final String? marketId;
  final String? marketName;
  final String verificationMethod;
  final VoidCallback onSubmitted;

  const _ReviewSubmissionSheet({
    required this.vendorId,
    required this.vendorName,
    this.marketId,
    this.marketName,
    required this.verificationMethod,
    required this.onSubmitted,
  });

  @override
  State<_ReviewSubmissionSheet> createState() => _ReviewSubmissionSheetState();
}

class _ReviewSubmissionSheetState extends State<_ReviewSubmissionSheet> {
  final UniversalReviewService _reviewService = UniversalReviewService();
  final TextEditingController _reviewController = TextEditingController();
  int _rating = 5;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
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
        reviewedId: widget.vendorId,
        reviewedName: widget.vendorName,
        reviewedType: 'vendor',
        overallRating: _rating.toDouble(),
        reviewText: _reviewController.text.trim(),
        verificationMethod: widget.verificationMethod,
        eventId: widget.marketId,
        eventName: widget.marketName,
      );

      if (mounted) {
        widget.onSubmitted();
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
    return Container(
      decoration: const BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HiPopColors.darkBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Review ${widget.vendorName}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),

              if (widget.marketName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'at ${widget.marketName}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: HiPopColors.darkTextSecondary,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Rating selector
              const Text(
                'Your Rating',
                style: TextStyle(
                  fontSize: 14,
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
                        size: 36,
                        color: Colors.amber,
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 20),

              // Review text field
              const Text(
                'Your Review',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reviewController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Share your experience...',
                  hintStyle: const TextStyle(color: HiPopColors.darkTextTertiary),
                  filled: true,
                  fillColor: HiPopColors.darkBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: HiPopColors.darkBorder.withOpacity( 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: HiPopColors.darkBorder.withOpacity( 0.3),
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

              const SizedBox(height: 8),

              // Verification badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: HiPopColors.successGreen.withOpacity( 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: HiPopColors.successGreen.withOpacity( 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code,
                      size: 14,
                      color: HiPopColors.successGreen,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'QR Verified Review',
                      style: TextStyle(
                        fontSize: 12,
                        color: HiPopColors.successGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HiPopColors.shopperAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
        ),
      ),
    );
  }
}