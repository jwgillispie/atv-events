import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:atv_events/features/shared/services/utilities/url_launcher_service.dart';
import 'package:atv_events/features/shared/widgets/common/favorite_button.dart';
import 'package:atv_events/features/shared/models/user_profile.dart';
import 'package:atv_events/features/shared/services/user/user_profile_service.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/shared/models/universal_review.dart';
import 'package:atv_events/features/shared/services/universal_review_service.dart';
import 'package:atv_events/features/shared/widgets/reviews/review_stats_card.dart';
import 'package:atv_events/features/shared/widgets/reviews/review_card.dart';
import 'package:atv_events/features/shared/widgets/rating/quick_rating_bottom_sheet.dart';
import 'package:atv_events/features/market/models/market.dart';
import 'package:intl/intl.dart';

class OrganizerDetailScreen extends StatefulWidget {
  final String organizerId;

  const OrganizerDetailScreen({
    super.key,
    required this.organizerId,
  });

  @override
  State<OrganizerDetailScreen> createState() => _OrganizerDetailScreenState();
}

class _OrganizerDetailScreenState extends State<OrganizerDetailScreen> {
  UserProfile? _organizer;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _marketsKey = GlobalKey();

  // Review-related state
  final UniversalReviewService _reviewService = UniversalReviewService();
  ReviewStats? _reviewStats;
  List<UniversalReview> _reviews = [];
  bool _loadingReviews = true;
  bool _canReview = false;
  bool _hasReviewed = false;

  // Organizer markets state
  List<Market> _activeMarkets = [];
  List<Market> _upcomingMarkets = [];
  bool _loadingMarkets = false;

  @override
  void initState() {
    super.initState();
    _loadOrganizer();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganizer() async {
    try {
      final userProfileService = UserProfileService();
      final organizer = await userProfileService.getUserProfile(widget.organizerId);

      if (organizer != null && organizer.userType == 'market_organizer') {
        setState(() {
          _organizer = organizer;
          _isLoading = false;
        });

        // Track organizer profile view - disabled for now
        // await RealTimeAnalyticsService.trackOrganizerInteraction(
        //   OrganizerActions.profileView,
        //   widget.organizerId,
        //   FirebaseAuth.instance.currentUser?.uid,
        //   metadata: {
        //     'organizerName': organizer.organizationName ?? organizer.displayName ?? '',
        //     'source': 'organizer_detail_screen',
        //   },
        // );

        // Load reviews and markets after organizer is loaded
        _loadReviews();
        _loadOrganizerMarkets();
      } else {
        setState(() {
          _organizer = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading organizer: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReviews() async {
    if (_organizer == null) return;

    setState(() {
      _loadingReviews = true;
    });

    try {
      // Load review stats
      final stats = await _reviewService.getReviewStats(
        entityId: widget.organizerId,
        entityType: 'organizer',
      );

      // Load recent reviews
      final reviews = await _reviewService.getReviewsForEntity(
        entityId: widget.organizerId,
        entityType: 'organizer',
        sortBy: ReviewSortOption.newest,
        limit: 5,
      );

      // Check if current user can review
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _canReview = await _reviewService.canUserReview(
          userId: user.uid,
          entityId: widget.organizerId,
          entityType: 'organizer',
        );

        // Check if user has already reviewed
        _hasReviewed = reviews.any((r) => r.reviewerId == user.uid);
      }

      setState(() {
        _reviewStats = stats;
        _reviews = reviews;
        _loadingReviews = false;
      });
    } catch (e) {
      debugPrint('Error loading reviews: $e');
      setState(() {
        _loadingReviews = false;
      });
    }
  }

  Future<void> _loadOrganizerMarkets() async {
    if (_organizer == null) return;

    setState(() {
      _loadingMarkets = true;
    });

    try {
      final now = DateTime.now();

      // Query active/upcoming markets for this organizer
      final snapshot = await FirebaseFirestore.instance
          .collection('markets')
          .where('organizerId', isEqualTo: widget.organizerId)
          .where('isActive', isEqualTo: true)
          .orderBy('eventDate')
          .limit(10)
          .get();

      final markets = snapshot.docs.map((doc) => Market.fromFirestore(doc)).toList();

      // Separate active (today) and upcoming markets
      final activeMarkets = <Market>[];
      final upcomingMarkets = <Market>[];

      for (final market in markets) {
        if (market.eventDate.year == now.year &&
            market.eventDate.month == now.month &&
            market.eventDate.day == now.day) {
          activeMarkets.add(market);
        } else if (market.eventDate.isAfter(now)) {
          upcomingMarkets.add(market);
        }
      }

      setState(() {
        _activeMarkets = activeMarkets;
        _upcomingMarkets = upcomingMarkets;
        _loadingMarkets = false;
      });
    } catch (e) {
      debugPrint('Error loading organizer markets: $e');
      setState(() {
        _loadingMarkets = false;
      });
    }
  }

  void _scrollToReviews() {
    // Find the reviews section and scroll to it
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent * 0.8,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToMarkets() {
    // Scroll to the markets section using the GlobalKey
    if (_marketsKey.currentContext != null) {
      Scrollable.ensureVisible(
        _marketsKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _openDirections(Market market) {
    // Use the market's coordinates to open directions
    final url = 'https://maps.apple.com/?daddr=${market.latitude},${market.longitude}&dirflg=d';
    _launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: HiPopColors.darkBackground,
        appBar: AppBar(
          backgroundColor: HiPopColors.darkSurface,
          foregroundColor: HiPopColors.darkTextPrimary,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: HiPopColors.primaryDeepSage,
          ),
        ),
      );
    }

    if (_organizer == null) {
      return Scaffold(
        backgroundColor: HiPopColors.darkBackground,
        appBar: AppBar(
          backgroundColor: HiPopColors.darkSurface,
          foregroundColor: HiPopColors.darkTextPrimary,
          elevation: 0,
        ),
        body: _buildErrorView(),
      );
    }

    final organizerName = _organizer!.organizationName ?? _organizer!.displayName ?? 'Organizer';

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        backgroundColor: HiPopColors.darkSurface,
        foregroundColor: HiPopColors.darkTextPrimary,
        elevation: 0,
        title: Text(
          organizerName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          FavoriteButton(
            itemId: widget.organizerId,
            type: FavoriteType.vendor, // Using vendor as organizer type not yet supported
            size: 24,
            favoriteColor: HiPopColors.primaryDeepSage,
            unfavoriteColor: HiPopColors.darkTextSecondary,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareOrganizer,
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        children: [
          // Hero Section
          _buildHeroSection(),

          // Quick Actions Bar
          _buildQuickActionsBar(),

          // Markets Section
          _buildMarketsSection(),

          // Business Details Section
          _buildBusinessDetailsSection(),

          // Reviews Section
          _buildReviewsSection(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    final organizerName = _organizer!.organizationName ?? _organizer!.displayName ?? 'Organizer';
    final shortBio = _organizer!.bio != null && _organizer!.bio!.isNotEmpty
        ? (_organizer!.bio!.length > 120
            ? '${_organizer!.bio!.substring(0, 120)}...'
            : _organizer!.bio!)
        : null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HiPopColors.primaryDeepSage.withValues(alpha: 0.8),
            HiPopColors.accentMauve.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Column(
        children: [
          // Photo carousel placeholder
          SizedBox(
            height: 200,
            child: Center(
              child: Icon(
                Icons.event_note,
                size: 80,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),

          // Organizer info overlay
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  HiPopColors.darkBackground.withValues(alpha: 0.8),
                  HiPopColors.darkBackground,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Organizer name with premium badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        organizerName,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                    ),
                    if (_organizer!.isPremium)
                      Container(
                        margin: const EdgeInsets.only(left: 12, top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: HiPopColors.premiumGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            const Text(
                              'Premium',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // Single rating line - tappable to scroll to reviews
                if (_reviewStats != null)
                  InkWell(
                    onTap: _scrollToReviews,
                    child: Row(
                      children: [
                        Text(
                          _reviewStats!.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: HiPopColors.darkTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.star,
                          size: 18,
                          color: Colors.amber[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${_reviewStats!.totalReviews} ${_reviewStats!.totalReviews == 1 ? 'review' : 'reviews'})',
                          style: TextStyle(
                            fontSize: 14,
                            color: HiPopColors.darkTextSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: HiPopColors.darkTextTertiary,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // Specialties/categories chips (using categories instead of marketTypes)
                if (_organizer!.categories.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _organizer!.categories.take(5).map((type) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: HiPopColors.darkSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: HiPopColors.primaryDeepSage.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            type,
                            style: const TextStyle(
                              fontSize: 12,
                              color: HiPopColors.primaryDeepSage,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                // Short bio
                if (shortBio != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    shortBio,
                    style: TextStyle(
                      fontSize: 14,
                      color: HiPopColors.darkTextSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsBar() {
    final hasEmail = _organizer!.email.isNotEmpty;
    final hasWebsite = _organizer!.website != null && _organizer!.website!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (hasEmail)
            _buildActionButton(
              icon: Icons.email,
              label: 'Email',
              color: HiPopColors.primaryDeepSage,
              onTap: () => _launchUrl('mailto:${_organizer!.email}'),
            ),
          if (hasWebsite)
            _buildActionButton(
              icon: Icons.language,
              label: 'Website',
              color: HiPopColors.accentMauve,
              onTap: () => _launchUrl(_organizer!.website!),
            ),
          _buildActionButton(
            icon: Icons.event,
            label: 'View Markets',
            color: HiPopColors.primaryDeepSage,
            onTap: _scrollToMarkets,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketsSection() {
    return Container(
      key: _marketsKey,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.storefront,
                size: 24,
                color: HiPopColors.primaryDeepSage,
              ),
              const SizedBox(width: 8),
              const Text(
                'Markets & Events',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_loadingMarkets)
            const Center(
              child: CircularProgressIndicator(
                color: HiPopColors.primaryDeepSage,
              ),
            )
          else if (_activeMarkets.isEmpty && _upcomingMarkets.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HiPopColors.darkSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: HiPopColors.darkBorder,
                  width: 1,
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
                  Text(
                    'No upcoming markets',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check back later for new events',
                    style: TextStyle(
                      fontSize: 14,
                      color: HiPopColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Active markets (today)
                if (_activeMarkets.isNotEmpty) ...[
                  Text(
                    'HAPPENING TODAY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.successGreen,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._activeMarkets.map((market) => _buildMarketCard(market, isActive: true)),
                  const SizedBox(height: 20),
                ],

                // Upcoming markets
                if (_upcomingMarkets.isNotEmpty) ...[
                  Text(
                    'UPCOMING',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.infoBlueGray,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._upcomingMarkets.map((market) => _buildMarketCard(market)),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMarketCard(Market market, {bool isActive = false}) {
    final dateFormat = DateFormat('MMM d');
    final dayFormat = DateFormat('EEEE');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? HiPopColors.successGreen.withValues(alpha: 0.5)
              : HiPopColors.darkBorder,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Open directions to the market
            _openDirections(market);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status and date row
                Row(
                  children: [
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: HiPopColors.successGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: HiPopColors.successGreen.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: HiPopColors.successGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'LIVE NOW',
                              style: TextStyle(
                                fontSize: 11,
                                color: HiPopColors.successGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!isActive) ...[
                      Text(
                        dayFormat.format(market.eventDate),
                        style: TextStyle(
                          fontSize: 13,
                          color: HiPopColors.primaryDeepSage,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${dateFormat.format(market.eventDate)} • ${market.startTime} - ${market.endTime}',
                        style: TextStyle(
                          fontSize: 13,
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (market.vendorSpotsAvailable != null && market.vendorSpotsTotal != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: HiPopColors.vendorAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${market.vendorSpotsAvailable}/${market.vendorSpotsTotal} spots',
                          style: TextStyle(
                            fontSize: 11,
                            color: HiPopColors.vendorAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Market name
                Text(
                  market.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                // Location
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: HiPopColors.darkTextTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${market.city}, ${market.state}',
                        style: TextStyle(
                          fontSize: 14,
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.directions,
                      size: 16,
                      color: HiPopColors.primaryDeepSage,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Directions',
                      style: TextStyle(
                        fontSize: 12,
                        color: HiPopColors.primaryDeepSage,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: HiPopColors.darkTextTertiary,
                    ),
                  ],
                ),

                // Looking for vendors badge
                if (market.isLookingForVendors) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: HiPopColors.vendorAccent.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: HiPopColors.vendorAccent.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.campaign,
                          size: 14,
                          color: HiPopColors.vendorAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Looking for Vendors',
                          style: TextStyle(
                            fontSize: 12,
                            color: HiPopColors.vendorAccent,
                            fontWeight: FontWeight.w600,
                          ),
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

  Widget _buildBusinessDetailsSection() {
    final hasFullBio = _organizer!.bio != null && _organizer!.bio!.length > 120;
    final memberSince = DateFormat('MMMM yyyy').format(_organizer!.createdAt);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface.withValues(alpha: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Organization Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: HiPopColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Verified badge if verified
          if (_organizer!.verificationStatus == VerificationStatus.approved)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HiPopColors.successGreen.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: HiPopColors.successGreen.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified,
                    color: HiPopColors.successGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Verified Organizer',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: HiPopColors.successGreen,
                    ),
                  ),
                ],
              ),
            ),

          // Member since
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: HiPopColors.darkTextTertiary,
              ),
              const SizedBox(width: 8),
              Text(
                'Member since $memberSince',
                style: TextStyle(
                  fontSize: 14,
                  color: HiPopColors.darkTextSecondary,
                ),
              ),
            ],
          ),

          // Markets hosted count
          if (_activeMarkets.isNotEmpty || _upcomingMarkets.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.event_available,
                  size: 16,
                  color: HiPopColors.darkTextTertiary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_activeMarkets.length + _upcomingMarkets.length} active markets',
                  style: TextStyle(
                    fontSize: 14,
                    color: HiPopColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ],

          // Full bio if longer than hero bio
          if (hasFullBio) ...[
            const SizedBox(height: 16),
            Text(
              'About',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _organizer!.bio!,
              style: TextStyle(
                fontSize: 14,
                color: HiPopColors.darkTextSecondary,
                height: 1.5,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Contact details
          if (_organizer!.email.isNotEmpty)
            _buildContactDetail(
              icon: Icons.email,
              label: 'Email',
              value: _organizer!.email,
              onTap: () => _launchUrl('mailto:${_organizer!.email}'),
            ),

          if (_organizer!.website != null && _organizer!.website!.isNotEmpty)
            _buildContactDetail(
              icon: Icons.language,
              label: 'Website',
              value: _organizer!.website!,
              onTap: () => _launchUrl(_organizer!.website!),
            ),
        ],
      ),
    );
  }

  Widget _buildContactDetail({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: HiPopColors.darkTextTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: HiPopColors.darkTextTertiary,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: HiPopColors.infoBlueGray,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Reviews',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
              if (_reviewStats != null && _reviewStats!.totalReviews > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: HiPopColors.primaryDeepSage.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _reviewStats!.averageRating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: HiPopColors.primaryDeepSage,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.star,
                        size: 16,
                        color: Colors.amber[700],
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          if (_loadingReviews)
            const Center(
              child: CircularProgressIndicator(
                color: HiPopColors.primaryDeepSage,
              ),
            )
          else if (_reviewStats == null || _reviewStats!.totalReviews == 0)
            // No reviews yet
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HiPopColors.darkSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: HiPopColors.darkBorder,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review,
                    size: 48,
                    color: HiPopColors.darkTextTertiary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No reviews yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Be the first to review this organizer!',
                    style: TextStyle(
                      fontSize: 14,
                      color: HiPopColors.darkTextSecondary,
                    ),
                  ),
                  if (_canReview && !_hasReviewed) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _openReviewFlow,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Write Review'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HiPopColors.primaryDeepSage,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            Column(
              children: [
                // Review summary stats
                if (_reviewStats != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ReviewStatsCard(
                      stats: _reviewStats!,
                      onSeeAllReviews: _reviewStats!.totalReviews > 5 ? _showAllReviews : null,
                      expandable: false,
                      showReviewerBreakdown: false,
                    ),
                  ),

                // ONE Write Review button (only if user hasn't reviewed)
                if (_canReview && !_hasReviewed)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ElevatedButton.icon(
                      onPressed: _openReviewFlow,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Write Review'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HiPopColors.primaryDeepSage,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                // Review cards
                ..._reviews.map((review) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ReviewCard(
                    review: review,
                    onHelpful: () => _markReviewHelpful(review.id),
                    onReport: () => _reportReview(review.id),
                    onRespond: _organizer!.userId == FirebaseAuth.instance.currentUser?.uid
                        ? () => _respondToReview(review)
                        : null,
                  ),
                )),

                // Load more button if > 5 reviews
                if (_reviewStats!.totalReviews > 5)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    child: OutlinedButton(
                      onPressed: _showAllReviews,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HiPopColors.primaryDeepSage,
                        side: BorderSide(color: HiPopColors.primaryDeepSage),
                      ),
                      child: Text('Load more (${_reviewStats!.totalReviews - 5} more reviews)'),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 64,
            color: HiPopColors.darkTextTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'Organizer not found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: HiPopColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The organizer you\'re looking for doesn\'t exist.',
            style: TextStyle(
              color: HiPopColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.primaryDeepSage,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      if (url.startsWith('tel:')) {
        await UrlLauncherService.launchPhone(url.substring(4));
      } else if (url.startsWith('mailto:')) {
        await UrlLauncherService.launchEmail(url.substring(7));
      } else {
        await UrlLauncherService.launchWebsite(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareOrganizer() async {
    if (_organizer == null) return;

    try {
      final organizerName = _organizer!.organizationName ?? _organizer!.displayName ?? 'Organizer';
      final buffer = StringBuffer();

      buffer.writeln('Check out $organizerName on HiPop!');
      buffer.writeln();

      if (_organizer!.bio != null && _organizer!.bio!.isNotEmpty) {
        buffer.writeln(_organizer!.bio!);
        buffer.writeln();
      }

      final totalMarkets = _activeMarkets.length + _upcomingMarkets.length;
      if (totalMarkets > 0) {
        buffer.writeln('Currently hosting $totalMarkets markets');
      }

      buffer.writeln();
      buffer.writeln('Discover local markets on HiPop Markets!');
      buffer.writeln('#SupportLocal #HiPop');

      await Share.share(
        buffer.toString(),
        subject: 'Check out $organizerName on HiPop!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share organizer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openReviewFlow({double? initialRating}) {
    if (_organizer == null) return;

    final organizerName = _organizer!.organizationName ?? _organizer!.displayName ?? 'Organizer';

    QuickRatingBottomSheet.show(
      context: context,
      entityId: widget.organizerId,
      entityType: 'organizer',
      entityName: organizerName,
      entityImage: null,
      onSubmit: (rating, comment) async {
        // Add a small delay to allow Firestore to update
        await Future.delayed(const Duration(seconds: 1));

        // Reload reviews after submission
        _loadReviews();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text('Review submitted successfully!'),
                ],
              ),
              backgroundColor: HiPopColors.successGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      },
    );
  }

  void _showAllReviews() {
    // Navigate to full reviews screen
    context.push('/organizer/${widget.organizerId}/reviews');
  }

  Future<void> _markReviewHelpful(String reviewId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _reviewService.markReviewHelpful(
        reviewId: reviewId,
        userId: user.uid,
      );

      // Reload reviews to show updated helpful count
      _loadReviews();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _reportReview(String reviewId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Review'),
        content: const Text(
          'Are you sure you want to report this review as inappropriate?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              try {
                await _reviewService.flagReview(
                  reviewId: reviewId,
                  reason: 'Inappropriate content',
                  reporterId: user.uid,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Review reported. Thank you for your feedback.'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  void _respondToReview(UniversalReview review) {
    final responseController = TextEditingController();
    final organizerName = _organizer!.organizationName ?? _organizer!.displayName ?? 'Organizer';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Respond to Review'),
        content: TextField(
          controller: responseController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write your response...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (responseController.text.trim().isEmpty) return;

              Navigator.pop(context);

              try {
                await _reviewService.respondToReview(
                  reviewId: review.id,
                  responseText: responseController.text.trim(),
                  responderId: _organizer!.userId,
                  responderName: organizerName,
                );

                // Reload reviews to show response
                _loadReviews();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Response posted successfully!'),
                      backgroundColor: HiPopColors.successGreen,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.primaryDeepSage,
            ),
            child: const Text('Send Response'),
          ),
        ],
      ),
    );
  }
}