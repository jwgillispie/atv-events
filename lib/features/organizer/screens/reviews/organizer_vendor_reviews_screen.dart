import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/shared/models/universal_review.dart';
import 'package:hipop/features/shared/services/universal_review_service.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
import 'package:hipop/features/shared/widgets/rating/star_rating_widget.dart';
import 'package:hipop/features/shared/widgets/rating/quick_rating_bottom_sheet.dart';
import 'package:hipop/features/vendor/models/managed_vendor.dart';
import 'package:hipop/features/shared/models/user_profile.dart';
import 'package:intl/intl.dart';

/// Combined organizer vendor reviews screen
/// Allows organizers to:
/// 1. Rate vendors they've worked with
/// 2. View reviews from other organizers about vendors
class OrganizerVendorReviewsScreen extends StatefulWidget {
  const OrganizerVendorReviewsScreen({super.key});

  @override
  State<OrganizerVendorReviewsScreen> createState() => _OrganizerVendorReviewsScreenState();
}

class _OrganizerVendorReviewsScreenState extends State<OrganizerVendorReviewsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UniversalReviewService _reviewService = UniversalReviewService();
  final String? _organizerId = FirebaseAuth.instance.currentUser?.uid;

  // Reviews data
  List<UniversalReview> _myReviews = [];
  bool _isLoadingMy = true;

  // Vendors the organizer has worked with (for rating)
  List<UserProfile> _workedWithVendors = [];
  bool _isLoadingVendors = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyReviews();
    _loadWorkedWithVendors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyReviews() async {
    setState(() => _isLoadingMy = true);

    try {
      // Load reviews written by this organizer about vendors
      final reviews = await _reviewService.getReviewsByUser(
        reviewerId: _organizerId!,
      );

      // Filter to only vendor reviews
      final vendorReviews = reviews.where((r) =>
        r.reviewedType == 'vendor'
      ).toList();

      setState(() {
        _myReviews = vendorReviews;
        _isLoadingMy = false;
      });
    } catch (e) {
      // Error loading my reviews: $e
      setState(() => _isLoadingMy = false);
    }
  }

  Future<void> _loadWorkedWithVendors() async {
    if (_organizerId == null) return;

    setState(() => _isLoadingVendors = true);

    try {
      // Get all managed vendors for this organizer
      final managedVendorsQuery = await FirebaseFirestore.instance
          .collection('managed_vendors')
          .where('organizerId', isEqualTo: _organizerId)
          .get();

      // Extract unique vendor user IDs
      final vendorIds = managedVendorsQuery.docs
          .map((doc) => ManagedVendor.fromFirestore(doc).userProfileId)
          .where((id) => id != null)
          .toSet()
          .cast<String>()
          .toList();

      // Fetch vendor profiles
      final vendors = <UserProfile>[];
      for (final vendorId in vendorIds) {
        final vendorDoc = await FirebaseFirestore.instance
            .collection('user_profiles')
            .doc(vendorId)
            .get();

        if (vendorDoc.exists) {
          vendors.add(UserProfile.fromFirestore(vendorDoc));
        }
      }

      setState(() {
        _workedWithVendors = vendors;
        _isLoadingVendors = false;
      });
    } catch (e) {
      // Error loading vendors: $e
      setState(() => _isLoadingVendors = false);
    }
  }

  void _openReviewFlow(UserProfile vendor) {
    QuickRatingBottomSheet.show(
      context: context,
      entityId: vendor.userId,
      entityType: 'vendor',
      entityName: vendor.businessName ?? vendor.displayName ?? 'Unknown Vendor',
      entityImage: null,
      onSubmit: (rating, comment) {
        _loadMyReviews(); // Reload reviews after submission
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Thank you for your review!'),
              backgroundColor: HiPopColors.successGreen,
          ),
        );
      },
    );
  }

  void _rateVendor(UserProfile vendor) {
    _openReviewFlow(vendor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.lightBackground,
      appBar: AppBar(
        backgroundColor: HiPopColors.organizerAccent,
        elevation: 0,
        title: const Text(
          'Vendor Reviews',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          tabs: const [
            Tab(text: 'My Reviews'),
            Tab(text: 'Pending'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyReviewsTab(),
          _buildPendingReviewsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
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

  Widget _buildMyReviewsTab() {
    if (_isLoadingMy) {
      return const LoadingWidget(message: 'Loading your reviews...');
    }

    if (_myReviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review,
              size: 80,
              color: HiPopColors.darkTextTertiary.withValues(alpha: 0.5),
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
              'Rate vendors you\'ve worked with',
              style: TextStyle(
                fontSize: 14,
                color: HiPopColors.darkTextTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myReviews.length,
      itemBuilder: (context, index) {
        final review = _myReviews[index];
        return _buildReviewCard(review);
      },
    );
  }

  Widget _buildPendingReviewsTab() {
    if (_isLoadingVendors) {
      return const LoadingWidget();
    }

    // Filter vendors that haven't been reviewed yet
    final pendingVendors = _workedWithVendors.where((vendor) {
      // Check if we've already reviewed this vendor
      return !_myReviews.any((review) => review.reviewedId == vendor.userId) &&
             vendor.userType == 'vendor'; // Only show vendor type users
    }).toList();

    if (pendingVendors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: HiPopColors.successGreen.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'All Caught Up!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: HiPopColors.darkTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'You\'ve reviewed all your vendors.\nNew vendors will appear here after working with them.',
                style: TextStyle(
                  fontSize: 16,
                  color: HiPopColors.darkTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingVendors.length,
      itemBuilder: (context, index) {
        final vendor = pendingVendors[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: HiPopColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.rate_review,
                  color: Colors.orange,
                  size: 28,
                ),
              ),
            title: Text(
              vendor.businessName ?? vendor.displayName ?? 'Vendor',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  vendor.categories.join(', '),
                  style: TextStyle(
                    fontSize: 14,
                    color: HiPopColors.darkTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to leave a review',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: HiPopColors.darkTextTertiary,
            ),
            onTap: () => _rateVendor(vendor),
          ),
        );
      },
    );
  }

  Widget _buildReviewCard(UniversalReview review) {
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.reviewedName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                ),
                StarRatingWidget(
                  rating: review.overallRating.round(),
                  onRatingChanged: (_) {},
                  title: '',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (review.reviewText != null && review.reviewText!.isNotEmpty) ...[
              Text(
                review.reviewText!,
                style: TextStyle(
                  fontSize: 14,
                  color: HiPopColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
            ],
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
    );
  }

  void _showVendorSelectionForRating() {
    if (_workedWithVendors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No vendors to review. Work with vendors at your markets first!'),
          backgroundColor: HiPopColors.warningAmber,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: HiPopColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Vendor to Review',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose from vendors you\'ve worked with',
              style: TextStyle(
                fontSize: 14,
                color: HiPopColors.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingVendors)
              const Center(
                child: CircularProgressIndicator(
                  color: HiPopColors.organizerAccent,
                ),
              )
            else
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: ListView.builder(
                  itemCount: _workedWithVendors.length,
                  itemBuilder: (context, index) {
                    final vendor = _workedWithVendors[index];
                    final hasReviewed = _myReviews.any((r) => r.reviewedId == vendor.userId);

                    return ListTile(
                      leading: const Icon(
                        Icons.store,
                        color: HiPopColors.darkTextTertiary,
                      ),
                      title: Text(
                        vendor.businessName ?? vendor.displayName ?? 'Vendor',
                        style: const TextStyle(
                          color: HiPopColors.darkTextPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        vendor.categories.join(', '),
                        style: TextStyle(
                          color: HiPopColors.darkTextSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: hasReviewed
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: HiPopColors.successGreen.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Reviewed',
                                style: TextStyle(
                                  color: HiPopColors.successGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: HiPopColors.darkTextTertiary,
                            ),
                      onTap: hasReviewed
                          ? null
                          : () {
                              Navigator.pop(context);
                              _openReviewFlow(vendor);
                            },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
