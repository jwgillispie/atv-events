import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/vendor/models/vendor_post.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
import 'package:hipop/core/widgets/hipop_app_bar.dart';

class OrganizerPremiumDashboard extends StatefulWidget {
  const OrganizerPremiumDashboard({super.key});

  @override
  State<OrganizerPremiumDashboard> createState() => _OrganizerPremiumDashboardState();
}

class _OrganizerPremiumDashboardState extends State<OrganizerPremiumDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Stream<List<VendorPost>>? _marketPostsStream;
  Stream<Map<String, int>>? _marketAnalyticsStream;
  StreamSubscription? _postsSubscription;
  StreamSubscription? _analyticsSubscription;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _userId = authState.user.uid;
      _marketPostsStream = _getMarketPosts(_userId!);
      _marketAnalyticsStream = _getMarketAnalytics(_userId!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Cancel stream subscriptions to prevent memory leaks
    _postsSubscription?.cancel();
    _analyticsSubscription?.cancel();
    
    // Clear stream references
    _marketPostsStream = null;
    _marketAnalyticsStream = null;
    
    super.dispose();
  }

  Stream<List<VendorPost>> _getMarketPosts(String organizerId) {
    return Stream.fromFuture(
      _getOrganizerMarketIds(organizerId).then((marketIds) async {
        if (marketIds.isEmpty) {
          return <VendorPost>[];
        }
        
        final snapshot = await FirebaseFirestore.instance
          .collection('vendor_posts')
          .where('marketId', whereIn: marketIds)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get()
          .timeout(const Duration(seconds: 10));
          
        return snapshot.docs
            .map((doc) => VendorPost.fromFirestore(doc))
            .toList();
      }).catchError((error) {
        return <VendorPost>[];
      }),
    ).asBroadcastStream();
  }

  Future<List<String>> _getOrganizerMarketIds(String organizerId) async {
    try {
      // Get the user profile to access managedMarketIds directly
      // This is more efficient than querying markets by organizerId
      final authState = context.read<AuthBloc>().state;
      if (authState is Authenticated && authState.userProfile != null) {
        final marketIds = authState.userProfile!.managedMarketIds;
        return marketIds;
      }
      
      // Fallback to querying if profile not available
      final marketsQuery = await FirebaseFirestore.instance
        .collection('markets')
        .where('organizerId', isEqualTo: organizerId)
        .get();
      
      final marketIds = marketsQuery.docs.map((doc) => doc.id).toList();
      return marketIds;
    } catch (e) {
      return [];
    }
  }

  Stream<Map<String, int>> _getMarketAnalytics(String organizerId) {
    return Stream.fromFuture(
      _generateRealAnalytics(organizerId).then((analytics) {
        return analytics;
      }).catchError((error) {
        return <String, int>{
          'totalVendors': 0,
          'activeMarkets': 0,
          'totalEvents': 0,
            'totalRevenue': 0,
          };
        }),
    ).asBroadcastStream();
  }

  Future<Map<String, int>> _generateRealAnalytics(String organizerId) async {
    try {
      // Get organizer's markets
      final marketIds = await _getOrganizerMarketIds(organizerId);
      
      // Count active markets
      final activeMarkets = marketIds.length;
      
      // Count vendor applications across all markets
      int totalVendors = 0;
      if (marketIds.isNotEmpty) {
        final vendorAppsQuery = await FirebaseFirestore.instance
          .collection('vendor_applications')
          .where('marketId', whereIn: marketIds)
          .where('status', isEqualTo: 'approved')
          .get();
        totalVendors = vendorAppsQuery.docs.length;
      }
      
      // Count events across all markets  
      int totalEvents = 0;
      if (marketIds.isNotEmpty) {
        final eventsQuery = await FirebaseFirestore.instance
          .collection('events')
          .where('marketId', whereIn: marketIds)
          .get();
        totalEvents = eventsQuery.docs.length;
      }
      
      return {
        'totalVendors': totalVendors,
        'activeMarkets': activeMarkets,
        'totalEvents': totalEvents,
        'totalRevenue': 0, // Revenue tracking not implemented yet
      };
    } catch (e) {
      return {
        'totalVendors': 0,
        'activeMarkets': 0,
        'totalEvents': 0,
        'totalRevenue': 0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading user profile...'),
                ],
              ),
            ),
          );
        }

        // 🔒 SECURITY: Check premium access via user profile
        final userProfile = state.userProfile;
        final hasPremiumAccess = userProfile?.isPremium ?? false;
        
        // Debug logging
        if (hasPremiumAccess) {
        } else {
        }
        
        return Scaffold(
          appBar: HiPopAppBar(
            title: 'Premium Dashboard',
            userRole: 'market_organizer',
            centerTitle: true,
            bottom: hasPremiumAccess ? TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
                Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
                Tab(text: 'Vendor Posts', icon: Icon(Icons.campaign)),
              ],
            ) : null,
          ),
          body: hasPremiumAccess 
            ? TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildAnalyticsTab(),
                  _buildVendorPostsTab(),
                ],
              )
            : _buildUpgradeScreen(),
        );
      },
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to Organizer Premium! 🎉',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'You now have access to:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildMarketOverviewCards(),
        ],
      ),
    );
  }

  Widget _buildFeatureList() {
    final features = [
      'Unlimited "Looking for Vendors" Posts - Create targeted posts that appear in vendor market discovery',
      'Vendor Response Management - View and manage vendor inquiries and applications',
      'Post Performance Analytics - Track views, responses, and conversion rates for your posts',
      'Smart Vendor Matching - Your posts are automatically matched to relevant vendors',
      'Integrated Discovery - Seamless integration with vendor premium discovery features',
      'Basic Market Analytics - Track vendor count and market stats',
    ];

    return Column(
      children: features.map((feature) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: HiPopColors.successGreen.withOpacity( 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                size: 14,
                color: HiPopColors.successGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                feature,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity( 0.8),
                ),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildMarketOverviewCards() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Active Vendors',
            '0',
            Icons.people,
            Colors.blue,
            isLocked: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Post Views',
            '0',
            Icons.visibility,
            Colors.blue,
            isLocked: false,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsTab() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const LoadingWidget(message: 'Loading analytics...');
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Analytics Card (Always Available)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity( 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.bar_chart, color: Colors.blue, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Basic Analytics',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Text(
                              'Free',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'View basic market metrics and vendor post statistics.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Post Analytics Card - Available to all premium users
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity( 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.analytics, color: Colors.deepPurple, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Post Analytics Dashboard',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Text(
                              'Included',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Track your vendor post performance, view counts, and response metrics.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to vendor posts management
                            context.go('/organizer/vendor-posts');
                          },
                          icon: const Icon(Icons.launch),
                          label: const Text('View Post Analytics'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Analytics Preview - now with fixed height instead of Expanded
              SizedBox(
                height: 300,
                child: _buildAnalyticsPreview(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVendorPostsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity( 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.campaign, color: Colors.deepPurple, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '"Looking for Vendors" Posts',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Text(
                          'Premium',
                          style: TextStyle(
                            color: Colors.amber.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Create targeted posts to attract qualified vendors. Your posts appear directly in vendor market discovery feeds.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            context.go('/organizer/vendor-recruitment/create');
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Post'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            context.go('/organizer/vendor-posts');
                          },
                          icon: const Icon(Icons.list),
                          label: const Text('Manage Posts'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.deepPurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Vendor Posts Features Preview
          const Text(
            'Vendor Post Features',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              _buildFeatureListItem(
                'Smart Targeting',
                'Your posts are automatically matched to relevant vendors based on their interests and location',
                Icons.gps_fixed,
                Colors.purple,
              ),
              const SizedBox(height: 8),
              _buildFeatureListItem(
                'Response Management',
                'View and manage all vendor inquiries and applications in one centralized location',
                Icons.inbox,
                Colors.blue,
              ),
              const SizedBox(height: 8),
              _buildFeatureListItem(
                'Performance Analytics',
                'Track views, responses, and conversion rates for your vendor recruitment posts',
                Icons.analytics,
                Colors.green,
              ),
              const SizedBox(height: 8),
              _buildFeatureListItem(
                'Integration Benefits',
                'Seamless integration with vendor premium discovery features for maximum visibility',
                Icons.integration_instructions,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureListItem(String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity( 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity( 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity( 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsPreview() {
    if (_marketAnalyticsStream == null || _marketPostsStream == null) {
      return const LoadingWidget(message: 'Loading analytics preview...');
    }

    return StreamBuilder<Map<String, int>>(
      stream: _marketAnalyticsStream!,
      builder: (context, analyticsSnapshot) {
        // Check if widget is still mounted to prevent memory leaks
        if (!mounted) {
          return const SizedBox.shrink();
        }

        if (analyticsSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget(message: 'Loading analytics...');
        }

        if (analyticsSnapshot.hasError) {
          return const Center(
            child: Text('Analytics temporarily unavailable'),
          );
        }

        return StreamBuilder<List<VendorPost>>(
          stream: _marketPostsStream!,
          builder: (context, postsSnapshot) {
            // Check if widget is still mounted
            if (!mounted) {
              return const SizedBox.shrink();
            }

            if (postsSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingWidget(message: 'Loading posts...');
            }

            if (postsSnapshot.hasError) {
              return const Center(
                child: Text('Posts data temporarily unavailable'),
              );
            }

            final posts = postsSnapshot.data ?? [];
            final analytics = analyticsSnapshot.data ?? {};
            final totalVendors = analytics['totalVendors'] ?? 0;
            final activeMarkets = analytics['activeMarkets'] ?? 0;

            return GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                // Free metrics - always visible
                _buildMetricCard(
                  'Total Vendors',
                  '$totalVendors',
                  Icons.people,
                  Colors.blue,
                  isLocked: false,
                ),
                _buildMetricCard(
                  'Active Markets',
                  '$activeMarkets',
                  Icons.store,
                  Colors.green,
                  isLocked: false,
                ),
                
                // Basic premium metrics - available to all premium users
                _buildMetricCard(
                  'Vendor Posts',
                  '${posts.length}',
                  Icons.campaign,
                  Colors.orange,
                  isLocked: false,
                ),
                _buildMetricCard(
                  'Post Views',
                  '0', // Will be populated with real data
                  Icons.visibility,
                  Colors.purple,
                  isLocked: false,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard(
    String title, 
    String value, 
    IconData icon, 
    Color color, {
    bool isLocked = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLocked ? Colors.white.withOpacity( 0.1) : color.withOpacity( 0.3),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon, 
                    size: 32, 
                    color: isLocked ? Colors.white.withOpacity( 0.3) : color,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isLocked ? Colors.white.withOpacity( 0.3) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: isLocked ? Colors.white.withOpacity( 0.3) : Colors.white.withOpacity( 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (isLocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity( 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock,
                      size: 24,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Hero section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  HiPopColors.premiumGold.withOpacity( 0.3),
                  HiPopColors.premiumGoldDark.withOpacity( 0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: HiPopColors.premiumGold.withOpacity( 0.5),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.diamond,
                  size: 64,
                  color: HiPopColors.premiumGold,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unlock Organizer Premium',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Transform your market management with powerful premium tools',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity( 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: HiPopColors.premiumGold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '\$69/month',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A0A0A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Benefits section
          const Text(
            'What You\'ll Get with Organizer Premium',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Premium features list
          Column(
            children: [
              _buildUpgradeFeatureListItem(
                '🎯 Unlimited Vendor Posts',
                'Create targeted "Looking for Vendors" posts that appear in vendor discovery feeds',
                Icons.campaign,
                Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildUpgradeFeatureListItem(
                '📊 Advanced Analytics',
                'Track vendor responses, conversion rates, and market performance metrics',
                Icons.analytics,
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildUpgradeFeatureListItem(
                '💼 Vendor Response Management',
                'View and manage all vendor inquiries and applications in one place',
                Icons.inbox,
                Colors.green,
              ),
              const SizedBox(height: 12),
              _buildUpgradeFeatureListItem(
                '🔍 Smart Vendor Matching',
                'Your posts are automatically matched to relevant qualified vendors',
                Icons.gps_fixed,
                Colors.purple,
              ),
            ],
          ),
          
          const SizedBox(height: 32),

          // ROI section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.trending_up,
                  size: 48,
                  color: Colors.green,
                ),
                SizedBox(height: 16),
                Text(
                  'Pay for Itself Quickly',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Find just 1-2 quality vendors per month and Premium pays for itself.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Upgrade button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                final authState = context.read<AuthBloc>().state;
                if (authState is Authenticated) {
                  context.go('/premium/upgrade?tier=marketOrganizerPremium&userId=${authState.user.uid}');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.premiumGold,
                foregroundColor: const Color(0xFF0A0A0A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.diamond, size: 24, color: const Color(0xFF0A0A0A)),
                  const SizedBox(width: 12),
                  const Text(
                    'Upgrade',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Back button
          TextButton(
            onPressed: () => context.go('/organizer'),
            child: Text(
              'Maybe Later - Back to Dashboard',
              style: TextStyle(
                color: Colors.white.withOpacity( 0.6),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeFeatureListItem(String title, String description, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity( 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity( 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity( 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
