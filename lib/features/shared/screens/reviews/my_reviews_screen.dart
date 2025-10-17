import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/shared/services/universal_review_service.dart';
import 'package:atv_events/features/shared/models/universal_review.dart';
import 'package:atv_events/features/shared/widgets/reviews/review_card.dart';
import 'package:atv_events/features/shared/widgets/reviews/no_reviews_prompt.dart';

class MyReviewsScreen extends StatefulWidget {
  final String? filterType;

  const MyReviewsScreen({
    super.key,
    this.filterType,
  });

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen>
    with SingleTickerProviderStateMixin {
  final UniversalReviewService _reviewService = UniversalReviewService();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  List<UniversalReview> _allReviews = [];
  List<UniversalReview> _marketReviews = [];
  List<UniversalReview> _vendorReviews = [];
  List<UniversalReview> _eventReviews = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _currentUserId;

  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: _getInitialTabIndex(),
    );
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  int _getInitialTabIndex() {
    switch (widget.filterType) {
      case 'market':
        return 1;
      case 'vendor':
        return 2;
      case 'event':
        return 3;
      default:
        return 0;
    }
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
    if (_currentUserId == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Load all reviews by this user
      final reviews = await _reviewService.getReviewsByUser(
        reviewerId: _currentUserId!,
        limit: _pageSize,
      );

      setState(() {
        _allReviews = reviews;
        _marketReviews = reviews.where((r) => r.reviewedType == 'market').toList();
        _vendorReviews = reviews.where((r) => r.reviewedType == 'vendor').toList();
        _eventReviews = reviews.where((r) => r.reviewedType == 'event').toList();
        _hasMore = reviews.length >= _pageSize;
      });
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreReviews() async {
    if (_isLoadingMore || !_hasMore || _currentUserId == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final lastReview = _allReviews.isNotEmpty ? _allReviews.last : null;

      final moreReviews = await _reviewService.getReviewsByUser(
        reviewerId: _currentUserId!,
        limit: _pageSize,
        startAfter: lastReview?.createdAt,
      );

      setState(() {
        _allReviews.addAll(moreReviews);
        _marketReviews.addAll(
          moreReviews.where((r) => r.reviewedType == 'market'),
        );
        _vendorReviews.addAll(
          moreReviews.where((r) => r.reviewedType == 'vendor'),
        );
        _eventReviews.addAll(
          moreReviews.where((r) => r.reviewedType == 'event'),
        );
        _hasMore = moreReviews.length >= _pageSize;
      });
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _deleteReview(UniversalReview review) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        title: const Text(
          'Delete Review',
          style: TextStyle(color: HiPopColors.darkTextPrimary),
        ),
        content: const Text(
          'Are you sure you want to delete this review? This action cannot be undone.',
          style: TextStyle(color: HiPopColors.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: HiPopColors.errorPlum,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _reviewService.deleteReview(review.id);
        _loadInitialData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review deleted successfully'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete review: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  Widget _buildReviewList(List<UniversalReview> reviews, String type) {
    if (reviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: NoReviewsPrompt(
            entityType: type == 'all' ? 'vendor' : type,
            entityName: 'Explore',
            onWriteReview: () => context.go('/shopper'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Entity header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        review.reviewedType == 'market'
                            ? Icons.storefront
                            : review.reviewedType == 'vendor'
                                ? Icons.store
                                : Icons.event,
                        size: 16,
                        color: HiPopColors.darkTextTertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          review.reviewedName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: HiPopColors.darkTextPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          if (review.reviewedType == 'market') {
                            context.push('/market/${review.reviewedId}/reviews');
                          } else if (review.reviewedType == 'vendor') {
                            context.push('/vendor/${review.reviewedId}/reviews');
                          }
                        },
                        child: const Text(
                          'View All',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                // Review card
                ReviewCard(
                  review: review,
                  currentUserId: _currentUserId,
                  onHelpful: null,
                  onRespond: null,
                  onReport: () => _deleteReview(review),
                ),
              ],
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
        title: const Text('My Reviews'),
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
          isScrollable: true,
          tabs: [
            Tab(
              child: Text(
                'All (${_allReviews.length})',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Tab(
              child: Text(
                'Markets (${_marketReviews.length})',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Tab(
              child: Text(
                'Vendors (${_vendorReviews.length})',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Tab(
              child: Text(
                'Events (${_eventReviews.length})',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
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
                  child: _buildReviewList(_marketReviews, 'market'),
                ),
                RefreshIndicator(
                  onRefresh: _loadInitialData,
                  color: HiPopColors.primaryDeepSage,
                  child: _buildReviewList(_vendorReviews, 'vendor'),
                ),
                RefreshIndicator(
                  onRefresh: _loadInitialData,
                  color: HiPopColors.primaryDeepSage,
                  child: _buildReviewList(_eventReviews, 'event'),
                ),
              ],
            ),
    );
  }
}