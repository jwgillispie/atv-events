import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/shared/services/universal_review_service.dart';
import 'package:atv_events/features/shared/models/universal_review.dart';
import 'package:atv_events/features/shared/widgets/reviews/review_card.dart';
import 'package:atv_events/features/shared/widgets/reviews/review_stats_card.dart';
import 'package:atv_events/features/shared/widgets/rating/quick_rating_bottom_sheet.dart';
import 'package:atv_events/features/shared/widgets/reviews/no_reviews_prompt.dart';
import 'package:atv_events/features/market/services/market_service.dart';
import 'package:atv_events/features/market/models/market.dart';

class MarketReviewsScreen extends StatefulWidget {
  final String marketId;
  final String? initialFilter;

  const MarketReviewsScreen({
    super.key,
    required this.marketId,
    this.initialFilter,
  });

  @override
  State<MarketReviewsScreen> createState() => _MarketReviewsScreenState();
}

class _MarketReviewsScreenState extends State<MarketReviewsScreen>
    with SingleTickerProviderStateMixin {
  final UniversalReviewService _reviewService = UniversalReviewService();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  Market? _market;
  ReviewStats? _reviewStats;
  List<UniversalReview> _allReviews = [];
  List<UniversalReview> _shopperReviews = [];
  List<UniversalReview> _vendorReviews = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _currentUserId;
  bool _canReview = false;
  bool _hasReviewed = false;
  bool _isOrganizer = false;

  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      // Load market info
      final markets = await MarketService.getAllActiveMarketsStream().first;
      _market = markets.firstWhere((m) => m.id == widget.marketId);

      // Check if current user is the organizer
      _isOrganizer = _currentUserId == _market?.organizerId;

      // Load review stats
      _reviewStats = await _reviewService.getReviewStats(
        entityId: widget.marketId,
        entityType: 'market',
      );

      // Check if user can review
      if (_currentUserId != null && !_isOrganizer) {
        _hasReviewed = await _reviewService.hasUserReviewed(
          reviewedId: widget.marketId,
          reviewedType: 'market',
          reviewerId: _currentUserId!,
        );
        _canReview = !_hasReviewed;
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
      final reviews = await _reviewService.getReviews(
        reviewedId: widget.marketId,
        reviewedType: 'market',
        limit: _pageSize,
      );

      setState(() {
        _allReviews = reviews;
        _shopperReviews = reviews.where((r) => r.reviewerType == 'shopper').toList();
        _vendorReviews = reviews.where((r) => r.reviewerType == 'vendor').toList();
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
      final lastReview = _allReviews.isNotEmpty ? _allReviews.last : null;

      final moreReviews = await _reviewService.getReviews(
        reviewedId: widget.marketId,
        reviewedType: 'market',
        limit: _pageSize,
        startAfter: lastReview?.createdAt,
      );

      setState(() {
        _allReviews.addAll(moreReviews);
        _shopperReviews.addAll(
          moreReviews.where((r) => r.reviewerType == 'shopper'),
        );
        _vendorReviews.addAll(
          moreReviews.where((r) => r.reviewerType == 'vendor'),
        );
        _hasMore = moreReviews.length >= _pageSize;
      });
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  void _openReviewFlow() async {
    if (_market == null) return;

    QuickRatingBottomSheet.show(
      context: context,
      entityId: widget.marketId,
      entityType: 'market',
      entityName: _market!.name,
      entityImage: _market!.imageUrl,
      onSubmit: (rating, comment) async {
        try {
          // Submit review to Firestore
          await _reviewService.submitReview(
            reviewedId: widget.marketId,
            reviewedName: _market!.name,
            reviewedType: 'market',
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

  Widget _buildReviewList(List<UniversalReview> reviews, String type) {
    if (reviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: NoReviewsPrompt(
            entityType: 'market',
            entityName: _market?.name ?? 'Market',
            onWriteReview: _canReview && type == 'all' ? _openReviewFlow : null,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: type == 'all' ? _scrollController : null,
      padding: const EdgeInsets.all(16),
      itemCount: reviews.length + (_isLoadingMore && type == 'all' ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < reviews.length) {
          final review = reviews[index];
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
              onRespond: _isOrganizer
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
                        responderName: _market?.name ?? 'Market Organizer',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: Text(_market?.name ?? 'Market Reviews'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: HiPopColors.primaryGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              child: Text(
                'All (${_allReviews.length})',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Tab(
              child: Text(
                'Shoppers (${_shopperReviews.length})',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Tab(
              child: Text(
                'Vendors (${_vendorReviews.length})',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats header
                if (_reviewStats != null)
                  Container(
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

                // Tab views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      RefreshIndicator(
                        onRefresh: _loadInitialData,
                        color: HiPopColors.primaryDeepSage,
                        child: _buildReviewList(_allReviews, 'all'),
                      ),
                      RefreshIndicator(
                        onRefresh: _loadInitialData,
                        color: HiPopColors.primaryDeepSage,
                        child: _buildReviewList(_shopperReviews, 'shopper'),
                      ),
                      RefreshIndicator(
                        onRefresh: _loadInitialData,
                        color: HiPopColors.primaryDeepSage,
                        child: _buildReviewList(_vendorReviews, 'vendor'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}