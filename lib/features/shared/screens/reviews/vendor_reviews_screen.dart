import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/shared/services/universal_review_service.dart';
import 'package:hipop/features/shared/models/universal_review.dart';
import 'package:hipop/features/shared/widgets/reviews/review_card.dart';
import 'package:hipop/features/shared/widgets/reviews/review_stats_card.dart';
import 'package:hipop/features/shared/widgets/rating/quick_rating_bottom_sheet.dart';
import 'package:hipop/features/shared/widgets/reviews/no_reviews_prompt.dart';
import 'package:hipop/features/vendor/services/core/managed_vendor_service.dart';
import 'package:hipop/features/vendor/models/managed_vendor.dart';

class VendorReviewsScreen extends StatefulWidget {
  final String vendorId;
  final String? initialFilter;

  const VendorReviewsScreen({
    super.key,
    required this.vendorId,
    this.initialFilter,
  });

  @override
  State<VendorReviewsScreen> createState() => _VendorReviewsScreenState();
}

class _VendorReviewsScreenState extends State<VendorReviewsScreen> {
  final UniversalReviewService _reviewService = UniversalReviewService();
  final ScrollController _scrollController = ScrollController();

  ManagedVendor? _vendor;
  ReviewStats? _reviewStats;
  List<UniversalReview> _reviews = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _currentFilter = 'all';
  String? _currentUserId;
  bool _canReview = false;
  bool _hasReviewed = false;

  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter ?? 'all';
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreReviews();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      // Load vendor info
      _vendor = await ManagedVendorService.getVendor(widget.vendorId);

      // Load review stats
      _reviewStats = await _reviewService.getReviewStats(
        entityId: widget.vendorId,
        entityType: 'vendor',
      );

      // Check if user can review using enhanced eligibility rules
      if (_currentUserId != null) {
        _hasReviewed = await _reviewService.hasUserReviewed(
          reviewedId: widget.vendorId,
          reviewedType: 'vendor',
          reviewerId: _currentUserId!,
        );

        // Use the enhanced canUserReview method which checks ManagedVendor relationships
        // and event date requirements
        _canReview = await _reviewService.canUserReview(
          userId: _currentUserId!,
          entityId: widget.vendorId,
          entityType: 'vendor',
        );
      }

      // Load initial reviews
      await _loadReviews();
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadReviews() async {
    try {
      List<UniversalReview> reviews;

      if (_currentFilter == 'needs-response' && _currentUserId == widget.vendorId) {
        // Load reviews without responses for vendor owner
        reviews = await _reviewService.getReviews(
          reviewedId: widget.vendorId,
          reviewedType: 'vendor',
          limit: _pageSize,
        );
        reviews = reviews.where((r) => r.responseText == null).toList();
      } else {
        // Load all reviews
        reviews = await _reviewService.getReviews(
          reviewedId: widget.vendorId,
          reviewedType: 'vendor',
          limit: _pageSize,
        );
      }

      setState(() {
        _reviews = reviews;
        _hasMore = reviews.length >= _pageSize;
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _loadMoreReviews() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final lastReview = _reviews.isNotEmpty ? _reviews.last : null;

      List<UniversalReview> moreReviews = await _reviewService.getReviews(
        reviewedId: widget.vendorId,
        reviewedType: 'vendor',
        limit: _pageSize,
        startAfter: lastReview?.createdAt,
      );

      if (_currentFilter == 'needs-response' && _currentUserId == widget.vendorId) {
        moreReviews = moreReviews.where((r) => r.responseText == null).toList();
      }

      setState(() {
        _reviews.addAll(moreReviews);
        _hasMore = moreReviews.length >= _pageSize;
      });
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  void _openReviewFlow() async {
    if (_vendor == null) return;

    QuickRatingBottomSheet.show(
      context: context,
      entityId: widget.vendorId,
      entityType: 'vendor',
      entityName: _vendor!.businessName,
      entityImage: _vendor!.imageUrl,
      onSubmit: (rating, comment) async {
        try {
          // Submit review to Firestore
          await _reviewService.submitReview(
            reviewedId: widget.vendorId,
            reviewedName: _vendor!.businessName,
            reviewedType: 'vendor',
            reviewedBusinessName: _vendor!.businessName,
            overallRating: rating.toDouble(),
            reviewText: comment,
          );

          // Reload reviews
          await _loadInitialData();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Thank you for your review!'),
                backgroundColor: HiPopColors.successGreen,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to submit review: $e'),
                backgroundColor: HiPopColors.errorPlum,
              ),
            );
          }
        }
      },
    );
  }

  Widget _buildVendorOwnEmptyState(BuildContext context) {
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
          clipBehavior: Clip.hardEdge,
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
                  color: HiPopColors.vendorAccent.withOpacity( 0.05),
                ),
              ),
            ),

            // Main content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HiPopColors.vendorAccent.withOpacity( 0.1),
                      border: Border.all(
                        color: HiPopColors.vendorAccent.withOpacity( 0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.qr_code_2,
                      size: 48,
                      color: HiPopColors.vendorAccent,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Main message
                  Text(
                    'No customer reviews yet',
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
                    'Show customers your QR code so they can leave a review',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? HiPopColors.darkTextSecondary
                          : HiPopColors.lightTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // CTA Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.push('/vendor/qr-code');
                      },
                      icon: const Icon(
                        Icons.qr_code,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Show QR Code',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HiPopColors.vendorAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: HiPopColors.vendorAccent.withOpacity( 0.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Trust indicators
                  Row(
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: Text(_vendor?.businessName ?? 'Reviews'),
        backgroundColor: HiPopColors.darkSurface,
        foregroundColor: HiPopColors.darkTextPrimary,
        elevation: 0,
        actions: [
          if (_currentUserId == widget.vendorId)
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              onSelected: (value) {
                setState(() {
                  _currentFilter = value;
                  _reviews.clear();
                  _loadReviews();
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'all',
                  child: Text('All Reviews'),
                ),
                const PopupMenuItem(
                  value: 'needs-response',
                  child: Text('Needs Response'),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              color: HiPopColors.primaryDeepSage,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Stats header
                  if (_reviewStats != null)
                    SliverToBoxAdapter(
                      child: Container(
                        color: HiPopColors.darkSurface,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            ReviewStatsCard(
                              stats: _reviewStats!,
                            ),
                            if (_canReview) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _openReviewFlow,
                                  icon: const Icon(Icons.rate_review),
                                  label: const Text('Write a Review'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: HiPopColors.primaryDeepSage,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  // Filter indicator
                  if (_currentFilter == 'needs-response')
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: HiPopColors.warningAmber.withOpacity( 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: HiPopColors.warningAmber.withOpacity( 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.filter_list,
                              color: HiPopColors.warningAmber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Showing reviews that need responses',
                              style: TextStyle(
                                color: HiPopColors.darkTextPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Reviews list
                  if (_reviews.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: _currentUserId == widget.vendorId
                              ? _buildVendorOwnEmptyState(context)
                              : NoReviewsPrompt(
                                  entityType: 'vendor',
                                  entityName: _vendor?.businessName ?? 'Vendor',
                                  onWriteReview: _canReview ? _openReviewFlow : null,
                                ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index < _reviews.length) {
                              final review = _reviews[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ReviewCard(
                                  review: review,
                                  onHelpful: () async {
                                    await _reviewService.markReviewHelpful(
                                      reviewId: review.id,
                                      userId: _currentUserId ?? '',
                                    );
                                    _loadInitialData();
                                  },
                                  currentUserId: _currentUserId,
                                  onRespond: _currentUserId == widget.vendorId
                                      ? () async {
                                        // Show response dialog
                                        final responseText = await showDialog<String>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Respond to Review'),
                                            content: TextField(
                                              maxLines: 3,
                                              decoration: const InputDecoration(
                                                hintText: 'Enter your response...',
                                              ),
                                              onChanged: (value) {},
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(context, 'response'),
                                                child: const Text('Submit'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (responseText != null) {
                                          await _reviewService.respondToReview(
                                            reviewId: review.id,
                                            responseText: responseText,
                                            responderName: _vendor?.businessName ?? 'Vendor',
                                          );
                                          _loadInitialData();
                                        }
                                      }
                                      : null,
                                ),
                              );
                            } else if (_isLoadingMore) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return null;
                          },
                          childCount: _reviews.length + (_isLoadingMore ? 1 : 0),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}