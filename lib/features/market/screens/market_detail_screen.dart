import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:atv_events/blocs/favorites/favorites_bloc.dart';
import 'package:atv_events/features/shared/services/utilities/url_launcher_service.dart';
import 'package:atv_events/features/shared/services/analytics/real_time_analytics_service.dart';
import 'package:atv_events/features/shared/widgets/common/error_widget.dart';
import 'package:atv_events/features/shared/widgets/common/favorite_button.dart';
import 'package:atv_events/features/shared/widgets/common/loading_widget.dart';
import 'package:atv_events/features/shared/widgets/share_button.dart';
import '../../market/models/market.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import '../../shared/models/universal_review.dart';
import '../../shared/services/universal_review_service.dart';
import '../../shared/widgets/reviews/review_stats_card.dart';
import '../../shared/widgets/reviews/no_reviews_prompt.dart';
import '../../shared/widgets/reviews/review_card.dart';
import '../../shared/widgets/reviews/quick_rating_button.dart';
import '../../shared/services/user/user_profile_service.dart';
import '../../shared/widgets/reviews/review_indicator.dart';
import '../../shared/widgets/rating/quick_rating_bottom_sheet.dart';
import '../../organizer/screens/applications/organizer_applications_tab.dart';
import '../../shared/blocs/application/application_bloc.dart';
import '../../shared/services/applications/vendor_application_service.dart';
import '../../shared/services/applications/application_payment_service.dart';


class MarketDetailScreen extends StatefulWidget {
  final Market market;

  const MarketDetailScreen({
    super.key,
    required this.market,
  });

  @override
  State<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends State<MarketDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Review-related state
  final UniversalReviewService _reviewService = UniversalReviewService();
  ReviewStats? _reviewStats;
  List<UniversalReview> _allReviews = [];
  List<UniversalReview> _shopperReviews = [];
  List<UniversalReview> _vendorReviews = [];
  bool _loadingReviews = true;
  bool _canReview = false;
  bool _hasReviewed = false;
  String? _currentUserId;
  String? _currentUserType;

  bool _isOrganizer = false;

  @override
  void initState() {
    super.initState();
    _checkIfOrganizer();
    _trackMarketView();
    _loadReviews();
    _checkReviewEligibility();
  }

  void _checkIfOrganizer() {
    final user = FirebaseAuth.instance.currentUser;
    _isOrganizer = user != null && user.uid == widget.market.organizerId;

    // Initialize tab controller with correct number of tabs
    final tabCount = _isOrganizer ? 4 : 3; // Add Applications tab for organizers
    _tabController = TabController(length: tabCount, vsync: this);
  }
  
  Future<void> _trackMarketView() async {
    try {
      // Track market event view
      await RealTimeAnalyticsService.trackMarketEngagement(
        MarketActions.marketView,
        widget.market.id,
        FirebaseAuth.instance.currentUser?.uid,
        metadata: {
          'marketName': widget.market.name,
          'eventDate': widget.market.eventDate.toIso8601String(),
          'isRecruitmentOnly': widget.market.isRecruitmentOnly,
          'isLookingForVendors': widget.market.isLookingForVendors,
          'source': 'market_detail_screen',
        },
      );
    } catch (e) {
      // Don't disrupt UI if analytics fails
    }
  }

  Future<void> _loadReviews() async {
    try {
      setState(() => _loadingReviews = true);

      // Load review stats
      _reviewStats = await _reviewService.getReviewStats(
        entityId: widget.market.id,
        entityType: 'market',
      );

      // Load all reviews
      _allReviews = await _reviewService.getReviews(
        reviewedId: widget.market.id,
        reviewedType: 'market',
        limit: 50,
      );

      // Separate reviews by type
      _shopperReviews = _allReviews.where((r) => r.reviewerType == 'shopper').toList();
      _vendorReviews = _allReviews.where((r) => r.reviewerType == 'vendor').toList();

      if (mounted) {
        setState(() => _loadingReviews = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingReviews = false);
      }
    }
  }

  Future<void> _checkReviewEligibility() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _currentUserId = user.uid;

      // Get user profile to determine type
      final userProfileService = UserProfileService();
      final profile = await userProfileService.getUserProfile(user.uid);
      _currentUserType = profile?.userType;

      // Check if user has already reviewed
      _hasReviewed = await _reviewService.hasUserReviewed(
        reviewedId: widget.market.id,
        reviewedType: 'market',
        reviewerId: user.uid,
      );

      // Use the enhanced canUserReview method which checks ManagedVendor relationships
      // and event date requirements
      _canReview = await _reviewService.canUserReview(
        userId: user.uid,
        entityId: widget.market.id,
        entityType: 'market',
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Silent fail
    }
  }

  void _openReviewFlow() {
    QuickRatingBottomSheet.show(
      context: context,
      entityId: widget.market.id,
      entityType: 'market',
      entityName: widget.market.name,
      entityImage: widget.market.imageUrl,
      onSubmit: (rating, comment) {
        _loadReviews();
        _checkReviewEligibility();
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _applyAsVendor(BuildContext context) {
    // Navigate to vendor application form
    context.push('/apply/${widget.market.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.market.name),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: HiPopColors.primaryGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          BlocBuilder<FavoritesBloc, FavoritesState>(
            builder: (context, favoritesState) {
              final totalFavorites = favoritesState.totalFavorites;
              return Stack(
                children: [
                  IconButton(
                    onPressed: () => context.pushNamed('favorites'),
                    icon: const Icon(Icons.favorite_border),
                    tooltip: 'My Favorites',
                  ),
                  if (totalFavorites > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: HiPopColors.errorPlum,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$totalFavorites',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          FavoriteButton(
            itemId: widget.market.id,
            type: FavoriteType.market,
            favoriteColor: Colors.white,
            unfavoriteColor: Colors.white70,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            const Tab(text: 'Overview'),
            const Tab(text: 'Vendors'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Reviews'),
                  if (_reviewStats != null && _reviewStats!.totalReviews > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_reviewStats!.totalReviews}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_isOrganizer) const Tab(text: 'Applications'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildVendorsTab(),
          _buildReviewsTab(),
          if (_isOrganizer) _buildApplicationsTab(),
        ],
      ),
      // TEMPORARILY HIDDEN: Apply as Vendor button (only showing permissions for now)
      // floatingActionButton: BlocBuilder<AuthBloc, AuthState>(
      //   builder: (context, state) {
      //     // Only show the Apply as Vendor button for authenticated vendors
      //     if (state is Authenticated && state.userType == 'vendor') {
      //       return FloatingActionButton.extended(
      //         onPressed: () => _applyAsVendor(context),
      //         backgroundColor: Colors.green,
      //         foregroundColor: Colors.white,
      //         icon: const Icon(Icons.store),
      //         label: const Text('Apply as Vendor'),
      //       );
      //     }
      //     return const SizedBox.shrink(); // Hide button for non-vendors
      //   },
      // ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Market Header Card
          Card(
            color: HiPopColors.darkSurface,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: HiPopColors.primaryDeepSage.withOpacity( 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.storefront,
                          color: HiPopColors.primaryDeepSage,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.market.name,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: HiPopColors.darkTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: HiPopColors.darkTextTertiary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _launchMaps(widget.market.address),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Text(
                                        widget.market.address,
                                        style: const TextStyle(
                                          color: HiPopColors.primaryDeepSage,
                                          fontSize: 14,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.market.description != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      widget.market.description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                  ],

                  // Organizer Info Section (if available)
                  if (widget.market.organizerId != null && widget.market.organizerName != null) ...[
                    const SizedBox(height: 16),
                    const Divider(color: HiPopColors.darkDivider),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: HiPopColors.primaryDeepSage.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.person,
                            size: 20,
                            color: HiPopColors.primaryDeepSage,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Organized by',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: HiPopColors.darkTextTertiary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              InkWell(
                                onTap: () {
                                  // Navigate to organizer profile
                                  context.push('/shopper/organizer-detail/${widget.market.organizerId}');
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.market.organizerName!,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: HiPopColors.primaryDeepSage,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 16,
                                        color: HiPopColors.primaryDeepSage,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(color: HiPopColors.darkDivider),
                  const SizedBox(height: 16),
                  // Review Indicator - Full Width
                  ReviewIndicator(
                    rating: _reviewStats?.averageRating,
                    reviewCount: _reviewStats?.totalReviews ?? 0,
                    variant: ReviewIndicatorVariant.extended,
                    entityType: ReviewEntityType.market,
                    entityId: widget.market.id,
                    entityName: widget.market.name,
                    onTap: () {
                      // Switch to reviews tab
                      _tabController.animateTo(2);
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Stats Cards
          Text(
            'Market Stats',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatsCards(),
          
          const SizedBox(height: 24),
          
          // Event Schedule
          Text(
            'Event Schedule',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: HiPopColors.darkSurface,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: HiPopColors.darkTextTertiary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Event Date:',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.market.eventDate.month}/${widget.market.eventDate.day}/${widget.market.eventDate.year}',
                        style: const TextStyle(
                          color: HiPopColors.darkTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: HiPopColors.darkTextTertiary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Time:',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.market.timeRange,
                        style: const TextStyle(
                          color: HiPopColors.darkTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        widget.market.isHappeningToday ? Icons.check_circle : 
                        widget.market.isFutureEvent ? Icons.schedule : Icons.history,
                        size: 16,
                        color: widget.market.isHappeningToday ? HiPopColors.successGreen : 
                               widget.market.isFutureEvent ? HiPopColors.warningAmber : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Status:',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.market.isHappeningToday ? 'Happening Today' : 
                        widget.market.isFutureEvent ? 'Upcoming' : 'Past Event',
                        style: TextStyle(
                          color: widget.market.isHappeningToday ? HiPopColors.successGreen : 
                                 widget.market.isFutureEvent ? HiPopColors.warningAmber : Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Event Links Section
          if (_hasEventLinks()) ...[
            const SizedBox(height: 24),
            Text(
              'Event Links',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildEventLinksSection(),
          ],
        ],
      ),
    );
  }
  
  bool _hasEventLinks() {
    // Event links are now on individual events, not markets
    // Only check for market-level Instagram handle
    return widget.market.instagramHandle != null;
  }
  
  Widget _buildEventLinksSection() {
    return Card(
      color: HiPopColors.darkSurface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.market.instagramHandle != null) ...[
              _buildLinkTile(
                icon: Icons.camera_alt,
                label: 'Instagram',
                url: 'https://instagram.com/${widget.market.instagramHandle}',
                color: HiPopColors.vendorAccent,
                displayText: widget.market.instagramHandle!.startsWith('@')
                  ? widget.market.instagramHandle!
                  : '@${widget.market.instagramHandle}',
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  
  Widget _buildLinkTile({
    required IconData icon,
    required String label,
    required String url,
    required Color color,
    String? displayText,
  }) {
    return InkWell(
      onTap: () => _launchURL(url),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity( 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: HiPopColors.darkTextTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayText ?? url,
                    style: TextStyle(
                      fontSize: 14,
                      color: color,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new,
              size: 16,
              color: HiPopColors.darkTextTertiary,
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _launchURL(String url) async {
    try {
      await UrlLauncherService.launchWebsite(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<List<ManagedVendor>>(
            stream: ManagedVendorService.getVendorsForMarket(widget.market.id),
            builder: (context, snapshot) {
              final vendorCount = snapshot.hasData ? snapshot.data!.length : 0;
              return _buildStatCard(
                'Total Vendors',
                '$vendorCount',
                Icons.store,
                HiPopColors.successGreen,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<List<ManagedVendor>>(
            stream: ManagedVendorService.getActiveVendorsForMarket(widget.market.id),
            builder: (context, snapshot) {
              final activeCount = snapshot.hasData ? snapshot.data!.length : 0;
              return _buildStatCard(
                'Active Vendors',
                '$activeCount',
                Icons.check_circle,
                HiPopColors.infoBlueGray,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      color: HiPopColors.darkSurface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: HiPopColors.darkTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorsTab() {
    return StreamBuilder<List<ManagedVendor>>(
      stream: ManagedVendorService.getVendorsForMarket(widget.market.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget(message: 'Loading vendors...');
        }

        if (snapshot.hasError) {
          return ErrorDisplayWidget.network(
            onRetry: () => setState(() {}),
          );
        }

        final vendors = snapshot.data ?? [];

        if (vendors.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.store_mall_directory,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No vendors yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This market hasn\'t added any vendors yet. Check back soon for vendors to discover!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // VENDOR ITEMS SERVICE DISABLED FOR WEB BUILD
        // return FutureBuilder<Map<String, List<String>>>(
        //   future: VendorMarketItemsService.getMarketVendorItems(widget.market.id),
        //   builder: (context, itemsSnapshot) {
        //     final vendorItemsMap = itemsSnapshot.data ?? <String, List<String>>{};

        //     return ListView.builder(
        //       padding: const EdgeInsets.all(16.0),
        //       itemCount: vendors.length,
        //       itemBuilder: (context, index) {
        //         final vendor = vendors[index];
        //         // Get market-specific items for this vendor
        //         final vendorItems = vendorItemsMap[vendor.id] ?? <String>[];
        //         return _buildVendorCard(vendor, vendorItems);
        //       },
        //     );
        //   },
        // );

        // For web build, just show vendors without market-specific items
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: vendors.length,
          itemBuilder: (context, index) {
            final vendor = vendors[index];
            return _buildVendorCard(vendor, <String>[]);
          },
        );
      },
    );
  }

  Widget _buildVendorCard(ManagedVendor vendor, List<String> marketItems) {
    return Card(
      color: HiPopColors.darkSurface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: HiPopColors.vendorAccent.withOpacity( 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.store,
                    color: HiPopColors.vendorAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendor.businessName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vendor.categoriesDisplay,
                        style: const TextStyle(
                          fontSize: 14,
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    ShareButton(
                      onGetShareContent: () async {
                        return _buildVendorShareContent(vendor);
                      },
                      style: ShareButtonStyle.icon,
                      size: ShareButtonSize.small,
                    ),
                    const SizedBox(width: 8),
                    FavoriteButton(
                      itemId: vendor.id,
                      type: FavoriteType.vendor,
                      size: 20,
                    ),
                  ],
                ),
                if (vendor.isFeatured)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: HiPopColors.premiumGold.withOpacity( 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          size: 12,
                          color: HiPopColors.premiumGoldDark,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'FEATURED',
                          style: TextStyle(
                            fontSize: 10,
                            color: HiPopColors.premiumGoldDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            
            if (vendor.description?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Text(
                vendor.description!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: HiPopColors.darkTextSecondary,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Show market-specific items if available, otherwise show general products
            if (marketItems.isNotEmpty || (vendor.products?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (marketItems.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.local_grocery_store,
                          size: 14,
                          color: HiPopColors.primaryDeepSage,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Available at this market:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: HiPopColors.primaryDeepSage,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    VendorItemsWidget.full(items: marketItems),
                  ] else if (vendor.products?.isNotEmpty ?? false) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.inventory_2,
                          size: 14,
                          color: HiPopColors.darkTextTertiary,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'General products:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: HiPopColors.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    VendorItemsWidget.full(items: vendor.products?.cast<String>() ?? []),
                  ],
                ],
              ),
            ],
            
            // Contact Information Section
            if (vendor.email != null || vendor.website != null || vendor.instagramHandle != null) ...[
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Email
                  if (vendor.email != null) ...[
                    InkWell(
                      onTap: () => _launchEmail(vendor.email!),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.email, size: 14, color: HiPopColors.darkTextTertiary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                vendor.email!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: HiPopColors.primaryDeepSage,
                                  decoration: TextDecoration.underline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  // Instagram
                  if (vendor.instagramHandle != null) ...[
                    if (vendor.email != null) const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _launchInstagram(vendor.instagramHandle!),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.camera_alt, size: 14, color: HiPopColors.darkTextTertiary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                vendor.instagramHandle!.startsWith('@')
                                  ? vendor.instagramHandle!
                                  : '@${vendor.instagramHandle!}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: HiPopColors.primaryDeepSage,
                                  decoration: TextDecoration.underline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  // Website
                  if (vendor.website != null) ...[
                    if (vendor.email != null || vendor.instagramHandle != null) const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _launchWebsite(vendor.website!),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.language, size: 14, color: HiPopColors.darkTextTertiary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _formatWebsiteDisplay(vendor.website!),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: HiPopColors.primaryDeepSage,
                                  decoration: TextDecoration.underline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Future<void> _launchMaps(String address) async {
    try {
      await UrlLauncherService.launchMaps(address, context: context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open maps: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }
  
  Future<void> _launchEmail(String email) async {
    try {
      await UrlLauncherService.launchEmail(email);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send email: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }
  
  Future<void> _launchInstagram(String handle) async {
    try {
      await UrlLauncherService.launchInstagram(handle);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Instagram: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }
  
  Future<void> _launchWebsite(String url) async {
    try {
      await UrlLauncherService.launchWebsite(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open website: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }
  
  String _formatWebsiteDisplay(String url) {
    // Remove http:// or https:// and www. for cleaner display
    return url
        .replaceAll(RegExp(r'https?://'), '')
        .replaceAll('www.', '')
        .replaceAll(RegExp(r'/$'), ''); // Also remove trailing slash
  }


  String _buildVendorShareContent(ManagedVendor vendor) {
    final buffer = StringBuffer();
    
    buffer.writeln('Check out ${vendor.businessName}!');
    buffer.writeln();
    
    if (vendor.description?.isNotEmpty ?? false) {
      buffer.writeln(vendor.description);
      buffer.writeln();
    }

    buffer.writeln('Categories: ${vendor.categoriesDisplay}');

    if (vendor.products?.isNotEmpty ?? false) {
      buffer.writeln('Products: ${(vendor.products ?? []).take(5).join(", ")}${(vendor.products?.length ?? 0) > 5 ? "..." : ""}');
    }
    
    if (vendor.email != null) {
      buffer.writeln('Email: ${vendor.email}');
    }
    
    if (vendor.website != null) {
      buffer.writeln('Website: ${vendor.website}');
    }
    
    if (vendor.instagramHandle != null) {
      buffer.writeln('Instagram: ${vendor.instagramHandle!.startsWith('@') ? vendor.instagramHandle : '@${vendor.instagramHandle}'}');
    }
    
    buffer.writeln();
    buffer.writeln('Find them at ${widget.market.name}!');
    buffer.writeln('Download ATV Events: https://apps.apple.com/us/app/atv-events/id6749876075');

    return buffer.toString();
  }


  Widget _buildReviewsTab() {
    if (_loadingReviews) {
      return const Center(child: LoadingWidget());
    }

    final hasReviews = _reviewStats != null && _reviewStats!.totalReviews > 0;

    return RefreshIndicator(
      onRefresh: _loadReviews,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show no reviews prompt or stats card
            if (!hasReviews)
              NoReviewsPrompt(
                entityType: 'market',
                entityName: widget.market.name,
                isNewEntity: widget.market.createdAt.difference(DateTime.now()).inDays.abs() < 30,
                onWriteReview: null,  // QR-only reviews for markets
              )
            else ...[
              // Review stats card
              ReviewStatsCard(
                stats: _reviewStats!,
                expandable: true,
                onSeeAllReviews: () {
                  context.push('/market/${widget.market.id}/reviews');
                },
              ),
              const SizedBox(height: 16),

              // Review filters (tabs for All/Shoppers/Vendors)
              DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: HiPopColors.darkSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TabBar(
                        indicatorColor: HiPopColors.primaryDeepSage,
                        labelColor: HiPopColors.primaryDeepSage,
                        unselectedLabelColor: HiPopColors.darkTextSecondary,
                        tabs: [
                          Tab(text: 'All (${_allReviews.length})'),
                          Tab(text: 'Shoppers (${_shopperReviews.length})'),
                          Tab(text: 'Vendors (${_vendorReviews.length})'),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: _allReviews.isEmpty ? 200 : (_allReviews.length * 150.0).clamp(150.0, 750.0),
                      child: TabBarView(
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildReviewList(_allReviews),
                          _buildReviewList(_shopperReviews),
                          _buildReviewList(_vendorReviews),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Show all reviews link
              if (_allReviews.length > 5) ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      context.push('/market/${widget.market.id}/reviews');
                    },
                    child: Text(
                      'Show all ${_allReviews.length} reviews',
                      style: TextStyle(color: HiPopColors.primaryDeepSage),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewList(List<UniversalReview> reviews) {
    if (reviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.rate_review,
                size: 48,
                color: HiPopColors.darkTextTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'No reviews yet',
                style: TextStyle(
                  color: HiPopColors.darkTextSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: reviews.take(5).map((review) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ReviewCard(
            review: review,
            onHelpful: () async {
              await _reviewService.markReviewHelpful(
                reviewId: review.id,
                userId: _currentUserId!,
              );
              _loadReviews();
            },
            onReport: () async {
              // Show report dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Review reported')),
              );
            },
            onRespond: _currentUserId == widget.market.organizerId
                ? () async {
                    // Show response dialog for organizer
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Response feature coming soon')),
                    );
                  }
                : null,
          ),
        );
      }).toList(),
    );
  }

  /// Build Applications tab (for organizers only)
  Widget _buildApplicationsTab() {
    return BlocProvider(
      create: (context) => ApplicationBloc(
        applicationService: VendorApplicationService(),
        paymentService: ApplicationPaymentService(),
      ),
      child: OrganizerApplicationsTab(
        marketId: widget.market.id,
        marketName: widget.market.name,
      ),
    );
  }

}