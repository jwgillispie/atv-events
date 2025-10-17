import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/shared/models/universal_review.dart';
import 'package:atv_events/features/shared/services/universal_review_service.dart';
import 'package:atv_events/features/shared/widgets/common/loading_widget.dart';
import 'package:atv_events/features/shared/widgets/rating/star_rating_widget.dart';
import 'package:intl/intl.dart';

/// Ratings Tab - Bidirectional rating system for organizers
/// View ratings received from shoppers/vendors AND rate vendors who attended markets
class OrganizerRatingsTab extends StatefulWidget {
  const OrganizerRatingsTab({super.key});

  @override
  State<OrganizerRatingsTab> createState() => _OrganizerRatingsTabState();
}

class _OrganizerRatingsTabState extends State<OrganizerRatingsTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final UniversalReviewService _reviewService = UniversalReviewService();
  final String? _organizerId = FirebaseAuth.instance.currentUser?.uid;

  List<UniversalReview> _receivedReviews = [];
  List<UniversalReview> _givenReviews = [];
  bool _isLoadingReceived = true;
  bool _isLoadingGiven = false;

  // Average ratings
  double _averageRating = 0.0;
  int _totalReviews = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _givenReviews.isEmpty && !_isLoadingGiven) {
        _loadGivenReviews();
      }
    });
    _loadReceivedReviews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReceivedReviews() async {
    setState(() => _isLoadingReceived = true);

    try {
      // Load reviews where this organizer is the target
      final reviews = await _reviewService.getReviewsForEntity(
        entityId: _organizerId!,
        entityType: 'organizer',
      );

      // Calculate average rating
      if (reviews.isNotEmpty) {
        double totalRating = 0;
        for (var review in reviews) {
          totalRating += review.overallRating;
        }
        _averageRating = totalRating / reviews.length;
        _totalReviews = reviews.length;
      }

      setState(() {
        _receivedReviews = reviews;
        _isLoadingReceived = false;
      });
    } catch (e) {
      print('Error loading received reviews: $e');
      setState(() => _isLoadingReceived = false);
    }
  }

  Future<void> _loadGivenReviews() async {
    setState(() => _isLoadingGiven = true);

    try {
      // Load reviews created by this organizer
      final reviews = await _reviewService.getReviewsByUser(
        reviewerId: _organizerId!,
      );

      // Filter to only vendor reviews
      final vendorReviews = reviews.where((r) => r.reviewedType == 'vendor').toList();

      setState(() {
        _givenReviews = vendorReviews;
        _isLoadingGiven = false;
      });
    } catch (e) {
      print('Error loading given reviews: $e');
      setState(() => _isLoadingGiven = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text(
          'Ratings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: HiPopColors.darkSurface,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Received'),
            Tab(text: 'Given'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReceivedReviewsTab(),
          _buildGivenReviewsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _showVendorSelectionForRating,
              backgroundColor: HiPopColors.organizerAccent,
              icon: const Icon(Icons.rate_review, color: Colors.white),
              label: const Text(
                'Rate Vendor',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildReceivedReviewsTab() {
    if (_isLoadingReceived) {
      return const LoadingWidget(message: 'Loading reviews...');
    }

    if (_receivedReviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star_border,
              size: 80,
              color: HiPopColors.darkTextTertiary.withOpacity( 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No reviews yet',
              style: TextStyle(
                fontSize: 18,
                color: HiPopColors.darkTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reviews from shoppers and vendors will appear here',
              style: TextStyle(
                fontSize: 14,
                color: HiPopColors.darkTextTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Rating summary header
        if (_totalReviews > 0)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HiPopColors.darkSurface,
              border: Border(
                bottom: BorderSide(
                  color: HiPopColors.darkBorder,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _averageRating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.organizerAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StarRatingWidget(
                      rating: _averageRating.round(),
                      onRatingChanged: (_) {},
                      title: '',
                      showDescription: false,
                      starSize: 20,
                    ),
                    Text(
                      '$_totalReviews reviews',
                      style: TextStyle(
                        fontSize: 12,
                        color: HiPopColors.darkTextTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        // Reviews list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _receivedReviews.length,
            itemBuilder: (context, index) {
              final review = _receivedReviews[index];
              return _buildReviewCard(review, isReceived: true);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGivenReviewsTab() {
    if (_isLoadingGiven) {
      return const LoadingWidget(message: 'Loading reviews...');
    }

    if (_givenReviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review,
              size: 80,
              color: HiPopColors.darkTextTertiary.withOpacity( 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No vendor ratings yet',
              style: TextStyle(
                fontSize: 18,
                color: HiPopColors.darkTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Rate vendors who attended your markets',
              style: TextStyle(
                fontSize: 14,
                color: HiPopColors.darkTextTertiary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showVendorSelectionForRating,
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.organizerAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.rate_review),
              label: const Text('Rate a Vendor'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _givenReviews.length,
      itemBuilder: (context, index) {
        final review = _givenReviews[index];
        return _buildReviewCard(review, isReceived: false);
      },
    );
  }

  Widget _buildReviewCard(UniversalReview review, {required bool isReceived}) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: HiPopColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with reviewer info and rating
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isReceived
                      ? HiPopColors.shopperAccent.withOpacity( 0.2)
                      : HiPopColors.vendorAccent.withOpacity( 0.2),
                  child: Text(
                    (review.reviewerName ?? 'Anonymous')[0].toUpperCase(),
                    style: TextStyle(
                      color: isReceived
                          ? HiPopColors.shopperAccent
                          : HiPopColors.vendorAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name and date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isReceived
                            ? review.reviewerName ?? 'Anonymous'
                            : review.reviewedName ?? 'Unknown Vendor',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      Text(
                        dateFormat.format(review.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: HiPopColors.darkTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Rating
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StarRatingWidget(
                      rating: review.overallRating.round(),
                      onRatingChanged: (_) {},
                      title: '',
                      showDescription: false,
                      starSize: 16,
                    ),
                    Text(
                      review.overallRating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.organizerAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Review text
            if (review.reviewText != null && review.reviewText!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                review.reviewText!,
                style: TextStyle(
                  fontSize: 14,
                  color: HiPopColors.darkTextSecondary,
                  height: 1.4,
                ),
              ),
            ],
            // Market/Event context if available
            if (review.eventId != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: HiPopColors.darkSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.store,
                      size: 14,
                      color: HiPopColors.darkTextTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      review.eventName ?? 'Market',
                      style: TextStyle(
                        fontSize: 12,
                        color: HiPopColors.darkTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showVendorSelectionForRating() {
    // Navigate to the dedicated vendor reviews screen
    context.push('/organizer/vendor-reviews');
  }
}