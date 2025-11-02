import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_event.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/auth/services/onboarding_service.dart';
import 'package:atv_events/features/shared/services/user/user_profile_service.dart';
import 'package:atv_events/features/shared/services/communication/welcome_notification_service.dart';
import 'package:atv_events/features/shared/widgets/welcome_notification_dialog.dart';
import 'package:atv_events/features/shared/widgets/debug_account_switcher.dart';
import 'package:atv_events/features/shared/widgets/debug_database_cleaner.dart';
import 'package:atv_events/features/shared/widgets/debug_premium_activator.dart';
import 'package:atv_events/core/widgets/hipop_app_bar.dart';
import 'package:atv_events/features/shared/services/universal_review_service.dart';
import 'package:atv_events/features/shared/models/universal_review.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:atv_events/features/market/models/market.dart';

class OrganizerDashboard extends StatefulWidget {
  const OrganizerDashboard({super.key});

  @override
  State<OrganizerDashboard> createState() => _OrganizerDashboardState();
}

class _OrganizerDashboardState extends State<OrganizerDashboard> {
  final WelcomeNotificationService _welcomeService = WelcomeNotificationService();
  bool _hasPremiumAccess = false;
  bool _isCheckingPremium = true;

  // Review system integration
  final UniversalReviewService _reviewService = UniversalReviewService();
  Map<String, ReviewStats> _marketReviewStats = {};
  int _totalMarketReviews = 0;
  int _pendingResponses = 0;
  double _averageMarketRating = 0.0;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    _checkPremiumAccess();
    _checkWelcomeNotification();
    _loadReviewStats();
  }

  Future<void> _loadReviewStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load all markets for this organizer
      // Since MarketService doesn't have getMarketsByOrganizer, we'll query Firestore directly
      final marketsSnapshot = await FirebaseFirestore.instance
          .collection('markets')
          .where('organizerId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      final markets = marketsSnapshot.docs
          .map((doc) => Market.fromFirestore(doc))
          .toList();

      int totalReviews = 0;
      int pendingCount = 0;
      double totalRating = 0.0;
      int ratedMarkets = 0;

      for (final market in markets) {
        // Load review stats for each market
        final stats = await _reviewService.getReviewStats(
          entityId: market.id,
          entityType: 'market',
        );

        if (stats != null) {
          _marketReviewStats[market.id] = stats;
          totalReviews += stats.totalReviews;

          if (stats.totalReviews > 0) {
            totalRating += stats.averageRating;
            ratedMarkets++;
          }

          // Check for reviews needing responses
          final reviews = await _reviewService.getReviews(
            reviewedId: market.id,
            reviewedType: 'market',
            limit: 100,
          );

          for (final review in reviews) {
            if (review.responseText == null) {
              pendingCount++;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalMarketReviews = totalReviews;
          _pendingResponses = pendingCount;
          _averageMarketRating = ratedMarkets > 0 ? totalRating / ratedMarkets : 0.0;
        });
      }
    } catch (e) {
      // Silent fail
    }
  }
  
  Future<void> _checkWelcomeNotification() async {
    // Delay slightly to let the dashboard render first
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!mounted) return;
    
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;
    
    try {
      final ceoNotes = await _welcomeService.checkAndGetWelcomeNotes(authState.user.uid);
      
      if (ceoNotes != null && mounted) {
        await WelcomeNotificationDialog.show(
          context: context,
          ceoNotes: ceoNotes,
          userType: 'market_organizer',
          onDismiss: () async {
            await _welcomeService.markWelcomeNotificationShown(authState.user.uid);
          },
        );
      }
    } catch (e) {
    }
  }

  Future<void> _checkOnboarding() async {
    try {
      final authState = context.read<AuthBloc>().state;
      
      // Only check onboarding for authenticated market organizers
      if (authState is! Authenticated || authState.userType != 'market_organizer') {
        return;
      }
      
      final isCompleted = await OnboardingService.isOrganizerOnboardingComplete();
      
      if (!isCompleted && mounted) {
        // Show onboarding after a short delay to let the dashboard load
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            context.pushNamed('organizerOnboarding');
          }
        });
      }
    } catch (e) {
    }
  }

  Future<void> _checkPremiumAccess() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      try {
        // Check user profile directly for premium status (same logic as vendor dashboard)
        final userProfileService = UserProfileService();
        final userProfile = await userProfileService.getUserProfile(authState.user.uid);
        
        final hasAccess = userProfile?.isPremium ?? false;
        
        if (mounted) {
          setState(() {
            _hasPremiumAccess = hasAccess;
            _isCheckingPremium = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _hasPremiumAccess = false;
            _isCheckingPremium = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isCheckingPremium = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! Authenticated) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

        return Scaffold(
          backgroundColor: HiPopColors.darkBackground,
          appBar: HiPopAppBar(
            title: 'Market Dashboard',
            userRole: 'organizer',
            centerTitle: true,
            actions: [
              if (_isCheckingPremium) ...[
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ] else if (_hasPremiumAccess) ...[
                IconButton(
                  icon: const Icon(Icons.diamond),
                  tooltip: 'Premium Dashboard',
                  onPressed: () {
                    final authState = context.read<AuthBloc>().state;
                    if (authState is Authenticated) {
                      context.go('/organizer/premium-dashboard');
                    }
                  },
                ),
              ],
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Sign Out',
                onPressed: () => context.read<AuthBloc>().add(LogoutEvent()),
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Debug Premium Activator
                      const DebugPremiumActivator(),
                      // Debug Account Switcher
                      const DebugAccountSwitcher(),
                      // Debug Database Cleaner
                      const DebugDatabaseCleaner(),
                      // No vendor debug tools in ATV Events
                      
                      // Welcome Card
                      Card(
                        color: HiPopColors.darkSurface,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: HiPopColors.organizerAccent.withOpacity( 0.3),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: HiPopColors.organizerAccent.withOpacity( 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.storefront,
                                      color: HiPopColors.organizerAccent,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome back!',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: HiPopColors.darkTextPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        state.user.displayName ?? state.user.email ?? 'Organizer',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: HiPopColors.darkTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Trust-Based System Info Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: HiPopColors.successGreen.withOpacity( 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: HiPopColors.successGreen.withOpacity( 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_user,
                              color: HiPopColors.successGreen,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Trust-Based System Active',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: HiPopColors.successGreen,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'All markets and vendor posts are automatically approved',
                                    style: TextStyle(
                                      color: HiPopColors.darkTextSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Reviews Section
                      if (_totalMarketReviews > 0 || _pendingResponses > 0)
                        _buildReviewSection(context, state),

                      Text(
                        'Dashboard',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Prominent Create Market button
                    _buildCreateMarketButton(context),
                    const SizedBox(height: 20),
                    // Shop as Customer card - organizers are shoppers too!
                    _buildShopAsCustomerCard(context),
                    const SizedBox(height: 12),
                    _buildDashboardOption(
                      context,
                      'My Markets',
                      'View and manage your markets',
                      Icons.storefront,
                      HiPopColors.organizerAccent,
                      () => context.pushNamed('marketManagement'),
                    ),
                    const SizedBox(height: 12),
                    _buildDashboardOption(
                      context,
                      'Analytics',
                      'View performance insights',
                      Icons.analytics,
                      Colors.deepPurple,
                      () => context.pushNamed('organizerPremiumDashboard'),
                      isPremium: true,
                    ),
                    const SizedBox(height: 12),
                    _buildDashboardOption(
                      context,
                      'Vendor Management',
                      'Manage vendors and their posts',
                      Icons.store_mall_directory,
                      HiPopColors.primaryDeepSage,
                      () => context.pushNamed('vendorManagement'),
                    ),
                    const SizedBox(height: 12),
                    // _buildDashboardOption(
                    //   context,
                    //   'Vendor Connections',
                    //   'Review and manage vendor connections',
                    //   Icons.people_alt,
                    //   HiPopColors.accentMauve,
                    //   () => context.pushNamed('vendorApplications'),
                    // ),
                    // const SizedBox(height: 12),
                    _buildDashboardOption(
                      context,
                      'Market Ratings',
                      'View and respond to vendor ratings',
                      Icons.star_rate,
                      HiPopColors.premiumGold,
                      () => context.pushNamed('organizerMarketRatings'),
                    ),
                    const SizedBox(height: 12),
                    _buildDashboardOption(
                      context,
                      'Event Management',
                      'Create and manage special events',
                      Icons.event,
                      HiPopColors.warningAmber,
                      () => context.pushNamed('eventManagement'),
                    ),
                    const SizedBox(height: 12),
                    _buildDashboardOption(
                      context,
                      'Market Calendar',
                      'View market schedules and events',
                      Icons.calendar_today,
                      HiPopColors.infoBlueGray,
                      () => context.pushNamed('organizerCalendar'),
                    ),
                    const SizedBox(height: 12),
                    _buildDashboardOption(
                      context,
                      'Profile',
                      'Edit your organizer profile',
                      Icons.person,
                      HiPopColors.successGreen,
                      () => context.pushNamed('organizerProfile'),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewSection(BuildContext context, Authenticated authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Market Reviews',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: HiPopColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: 16),

        // Market Review Summary Card
        Card(
          color: HiPopColors.darkSurface,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: HiPopColors.organizerAccent.withOpacity( 0.3),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: () => context.pushNamed('organizerMarketRatings'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.amber, Colors.orange],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Market Reviews',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HiPopColors.darkTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (_totalMarketReviews > 0) ...[                              Row(
                                children: [
                                  Icon(Icons.star, size: 16, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    _averageMarketRating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: HiPopColors.darkTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '($_totalMarketReviews total reviews)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: HiPopColors.darkTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[                              Text(
                                'No reviews yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: HiPopColors.darkTextSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_pendingResponses > 0) ...[                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: HiPopColors.errorPlum,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_pendingResponses',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Icon(
                        Icons.arrow_forward_ios,
                        color: HiPopColors.darkTextTertiary,
                        size: 16,
                      ),
                    ],
                  ),
                  if (_pendingResponses > 0) ...[                    const SizedBox(height: 12),
                    Container(
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
                            Icons.notification_important,
                            color: HiPopColors.warningAmber,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$_pendingResponses reviews need your response',
                              style: TextStyle(
                                fontSize: 13,
                                color: HiPopColors.darkTextPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.pushNamed('organizerMarketRatings'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              backgroundColor: HiPopColors.warningAmber,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text(
                              'Respond',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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

        const SizedBox(height: 12),

        // Review Insights Card
        Card(
          color: HiPopColors.darkSurface,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: HiPopColors.primaryDeepSage.withOpacity( 0.3),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: () => context.pushNamed('organizerAnalytics'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: HiPopColors.primaryDeepSage.withOpacity( 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.insights,
                      color: HiPopColors.primaryDeepSage,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review Insights',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: HiPopColors.darkTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Analyze trends and feedback',
                          style: TextStyle(
                            fontSize: 14,
                            color: HiPopColors.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: HiPopColors.premiumGold.withOpacity( 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.diamond,
                          size: 12,
                          color: HiPopColors.premiumGoldDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Premium',
                          style: TextStyle(
                            fontSize: 11,
                            color: HiPopColors.premiumGoldDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: HiPopColors.darkTextTertiary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildShopAsCustomerCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HiPopColors.shopperAccent.withOpacity( 0.9),
            HiPopColors.shopperAccent,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: HiPopColors.shopperAccent.withOpacity( 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/shopper'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity( 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shopping_bag,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pop Ups Near Me',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Browse & favorite markets you want to shop at',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity( 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.white.withOpacity( 0.8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateMarketButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HiPopColors.organizerAccent,
            HiPopColors.primaryDeepSage,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: HiPopColors.organizerAccent.withOpacity( 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.pushNamed('marketManagement'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity( 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.add_business,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create Market',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Post a new market!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity( 0.9),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.white.withOpacity( 0.8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardOption(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    VoidCallback onTap, {
    bool isPremium = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: HiPopColors.darkBorder.withOpacity( 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity( 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Icon container on the left
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity( 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Title and description in the middle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isPremium) ...[
                            Icon(
                              Icons.diamond,
                              size: 16,
                              color: HiPopColors.premiumGold,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HiPopColors.darkTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: HiPopColors.darkTextSecondary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Arrow indicator on the right
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: HiPopColors.darkTextSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

