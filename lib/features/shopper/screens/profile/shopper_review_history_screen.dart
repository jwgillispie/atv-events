import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/shared/services/universal_review_service.dart';
import 'package:hipop/features/shared/models/universal_review.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
import 'package:hipop/features/shared/widgets/common/error_widget.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

/// Screen displaying all reviews written by the current shopper
class ShopperReviewHistoryScreen extends StatefulWidget {
  const ShopperReviewHistoryScreen({super.key});

  @override
  State<ShopperReviewHistoryScreen> createState() => _ShopperReviewHistoryScreenState();
}

class _ShopperReviewHistoryScreenState extends State<ShopperReviewHistoryScreen> {
  final UniversalReviewService _reviewService = UniversalReviewService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<UniversalReview> _reviews = [];
  Map<String, Map<String, dynamic>> _entityInfo = {};
  bool _isLoading = true;
  String? _error;
  String _filterType = 'all'; // all, vendor, market

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'You must be logged in to view your reviews';
          _isLoading = false;
        });
        return;
      }

      // Load reviews by this user
      final reviews = await _reviewService.getReviewsByUser(
        reviewerId: user.uid,
      );

      // Load entity information for each review
      for (var review in reviews) {
        if (review.reviewedType == 'vendor') {
          final vendorDoc = await _firestore
              .collection('users')
              .doc(review.reviewedId)
              .get();

          if (vendorDoc.exists) {
            final data = vendorDoc.data()!;
            _entityInfo[review.reviewedId] = {
              'name': data['businessName'] ?? data['displayName'] ?? 'Unknown Vendor',
              'type': 'vendor',
              'category': data['businessCategory'],
            };
          }
        } else if (review.reviewedType == 'market') {
          final marketDoc = await _firestore
              .collection('markets')
              .doc(review.reviewedId)
              .get();

          if (marketDoc.exists) {
            final data = marketDoc.data()!;
            _entityInfo[review.reviewedId] = {
              'name': data['name'] ?? 'Unknown Market',
              'type': 'market',
              'address': data['address'],
            };
          }
        }
      }

      setState(() {
        _reviews = reviews;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load reviews: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  List<UniversalReview> get _filteredReviews {
    if (_filterType == 'all') {
      return _reviews;
    }
    return _reviews.where((r) => r.reviewedType == _filterType).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text('My Reviews'),
        backgroundColor: HiPopColors.darkSurface,
        foregroundColor: HiPopColors.darkTextPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading your reviews...')
          : _error != null
              ? ErrorDisplayWidget(
                  title: 'Error',
                  message: _error!,
                  onRetry: _loadReviews,
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: HiPopColors.darkTextTertiary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Reviews Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Reviews you write will appear here',
              style: TextStyle(
                fontSize: 14,
                color: HiPopColors.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/shopper'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.shopperAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Explore Markets'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReviews,
      child: CustomScrollView(
        slivers: [
          // Filter Chips
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Vendors', 'vendor'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Markets', 'market'),
                  ],
                ),
              ),
            ),
          ),

          // Stats Card
          if (_reviews.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: HiPopColors.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: HiPopColors.darkBorder.withOpacity( 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(
                      'Total Reviews',
                      _filteredReviews.length.toString(),
                      Icons.rate_review,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: HiPopColors.darkBorder,
                    ),
                    _buildStatItem(
                      'Avg Rating',
                      _calculateAverageRating(),
                      Icons.star,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: HiPopColors.darkBorder,
                    ),
                    _buildStatItem(
                      'This Month',
                      _getMonthlyCount().toString(),
                      Icons.calendar_today,
                    ),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Reviews List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final review = _filteredReviews[index];
                  final entityInfo = _entityInfo[review.reviewedId];
                  return _buildReviewCard(review, entityInfo);
                },
                childCount: _filteredReviews.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String type) {
    final isSelected = _filterType == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = type;
        });
      },
      backgroundColor: HiPopColors.darkSurface,
      selectedColor: HiPopColors.shopperAccent.withOpacity( 0.2),
      checkmarkColor: HiPopColors.shopperAccent,
      labelStyle: TextStyle(
        color: isSelected ? HiPopColors.shopperAccent : HiPopColors.darkTextSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected
              ? HiPopColors.shopperAccent
              : HiPopColors.darkBorder.withOpacity( 0.3),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: HiPopColors.shopperAccent,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: HiPopColors.darkTextPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: HiPopColors.darkTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(UniversalReview review, Map<String, dynamic>? entityInfo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            // Navigate to the reviewed entity
            if (review.reviewedType == 'vendor') {
              context.push('/vendor/${review.reviewedId}/reviews');
            } else if (review.reviewedType == 'market') {
              context.push('/market/${review.reviewedId}/reviews');
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: HiPopColors.darkBorder.withOpacity( 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: review.reviewedType == 'vendor'
                            ? HiPopColors.vendorAccent.withOpacity( 0.1)
                            : HiPopColors.organizerAccent.withOpacity( 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        review.reviewedType == 'vendor' ? Icons.store : Icons.location_city,
                        color: review.reviewedType == 'vendor'
                            ? HiPopColors.vendorAccent
                            : HiPopColors.organizerAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entityInfo?['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: HiPopColors.darkTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (entityInfo?['category'] != null ||
                              entityInfo?['address'] != null)
                            Text(
                              entityInfo?['category'] ?? entityInfo?['address'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: HiPopColors.darkTextSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Rating
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        index < review.overallRating ? Icons.star : Icons.star_border,
                        size: 16,
                        color: Colors.amber,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, y').format(review.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: HiPopColors.darkTextTertiary,
                      ),
                    ),
                  ],
                ),

                if (review.reviewText != null && review.reviewText!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    review.reviewText!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: HiPopColors.darkTextSecondary,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Verification Method Badge
                if (review.verificationMethod != null) ...[
                  const SizedBox(height: 8),
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
                          review.verificationMethod == 'qr' ? Icons.qr_code : Icons.verified,
                          size: 12,
                          color: HiPopColors.successGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          review.verificationMethod == 'qr' ? 'QR Verified' : 'Verified',
                          style: const TextStyle(
                            fontSize: 11,
                            color: HiPopColors.successGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Response from business
                if (review.responseText != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: HiPopColors.darkBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.reply,
                              size: 14,
                              color: HiPopColors.darkTextTertiary,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Business Response',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: HiPopColors.darkTextTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          review.responseText!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: HiPopColors.darkTextSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _calculateAverageRating() {
    if (_filteredReviews.isEmpty) return 'N/A';
    final total = _filteredReviews.fold<double>(0, (acc, r) => acc + r.overallRating);
    return (total / _filteredReviews.length).toStringAsFixed(1);
  }

  int _getMonthlyCount() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    return _filteredReviews.where((r) => r.createdAt.isAfter(startOfMonth)).length;
  }
}