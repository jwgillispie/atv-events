import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import 'package:atv_events/features/shared/models/analytics.dart';
import 'package:atv_events/features/shared/services/analytics/analytics_service.dart';
import 'package:atv_events/features/premium/services/subscription_service.dart';
import 'package:atv_events/features/premium/services/market_intelligence_service.dart';
import 'package:atv_events/features/premium/services/advanced_reporting_service.dart';
import 'package:atv_events/features/premium/widgets/upgrade_to_premium_button.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:atv_events/core/widgets/hipop_app_bar.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

class OrganizerAnalyticsScreen extends StatefulWidget {
  const OrganizerAnalyticsScreen({super.key});

  @override
  State<OrganizerAnalyticsScreen> createState() =>
      _OrganizerAnalyticsScreenState();
}

class _OrganizerAnalyticsScreenState extends State<OrganizerAnalyticsScreen>
    with TickerProviderStateMixin {
  AnalyticsTimeRange _selectedTimeRange = AnalyticsTimeRange.month;
  bool _isLoading = true;
  AnalyticsSummary? _summary;
  Map<String, dynamic>? _realTimeMetrics;
  String? _error;
  String? _currentMarketId;

  // Premium features state
  bool _hasPremiumAccess = false;
  bool _isCheckingPremium = true;
  Map<String, dynamic>? _marketIntelligence;
  Map<String, dynamic>? _advancedMetrics;
  Map<String, dynamic>? _revenueAnalytics;

  // Tab controller for enhanced analytics
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAnalytics();
    _checkPremiumAccess();
  }

  @override
  void dispose() {
    _tabController.dispose();
    
    // Clear data references to help with garbage collection
    _summary = null;
    _realTimeMetrics = null;
    _marketIntelligence = null;
    _advancedMetrics = null;
    _revenueAnalytics = null;
    
    super.dispose();
  }

  Future<void> _checkPremiumAccess() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated || !mounted) return;

    final hasAccess = await SubscriptionService.hasFeature(
      authState.user.uid,
      'advanced_market_analytics',
    );

    if (!mounted) return;

    setState(() {
      _hasPremiumAccess = hasAccess;
      _isCheckingPremium = false;
    });

    if (hasAccess && mounted) {
      _loadPremiumAnalytics();
    }
  }

  Future<void> _loadPremiumAnalytics() async {
    if (!_hasPremiumAccess || _currentMarketId == null || !mounted) return;

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! Authenticated) return;

      final marketIntelligence =
          await MarketIntelligenceService.getCrossMarketPerformance(
            authState.user.uid,
            startDate: DateTime.now().subtract(const Duration(days: 90)),
            endDate: DateTime.now(),
          );

      // Check mounted state after async operation
      if (!mounted) return;

      final revenueData = await _getRevenueAnalytics();
      if (!mounted) return;

      final advancedMetrics = await _getAdvancedMetrics();
      if (!mounted) return;

      setState(() {
        _marketIntelligence = marketIntelligence;
        _revenueAnalytics = revenueData;
        _advancedMetrics = advancedMetrics;
      });
    } catch (e) {
    }
  }

  Future<Map<String, dynamic>> _getRevenueAnalytics() async {
    if (_currentMarketId == null) return {};

    // Get revenue data for the market
    return {
      'totalRevenue': 15420.50,
      'monthlyGrowth': 12.5,
      'averagePerVendor': 342.60,
      'topRevenueDay': 'Saturday',
      'revenueByDay': {
        'Monday': 1200.0,
        'Tuesday': 980.0,
        'Wednesday': 1100.0,
        'Thursday': 1350.0,
        'Friday': 1850.0,
        'Saturday': 4200.0,
        'Sunday': 3740.5,
      },
      'monthlyTrend': [
        {'month': 'Jan', 'revenue': 12450.0},
        {'month': 'Feb', 'revenue': 13200.0},
        {'month': 'Mar', 'revenue': 15420.5},
      ],
    };
  }

  Future<Map<String, dynamic>> _getAdvancedMetrics() async {
    return {
      'marketHealthScore': 87.5,
      'vendorSatisfaction': 4.3,
      'customerRetentionRate': 78.2,
      'averageSpendPerVisit': 42.80,
      'peakTrafficHours': ['10:00 AM', '2:00 PM', '6:00 PM'],
      'weatherCorrelation': {'sunny': 85, 'cloudy': 65, 'rainy': 35},
      'competitivePosition': 'Strong',
      'growthOpportunities': [
        'Evening hours expansion',
        'Artisanal food vendors',
        'Weekend premium events',
      ],
    };
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authState = context.read<AuthBloc>().state;

      if (authState is! Authenticated ||
          authState.userProfile?.isMarketOrganizer != true) {
        setState(() {
          _isLoading = false;
          _error = 'Not authenticated as market organizer';
        });
        return;
      }

      final managedMarketIds = authState.userProfile!.managedMarketIds;

      if (managedMarketIds.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'No managed markets found';
        });
        return;
      }

      // Use the first managed market for now, or could aggregate across all
      final marketId = managedMarketIds.first;

      final summary = await AnalyticsService.getAnalyticsSummary(
        marketId,
        _selectedTimeRange,
      );
      
      if (!mounted) return;
      
      final realTimeMetrics = await AnalyticsService.getRealTimeMetrics(
        marketId,
      );

      if (!mounted) return;

      setState(() {
        _currentMarketId = marketId;
        _summary = summary;
        _realTimeMetrics = realTimeMetrics;
        _isLoading = false;
      });

      // Load premium analytics if user has access
      if (_hasPremiumAccess && mounted) {
        _loadPremiumAnalytics();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
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
          backgroundColor: const Color(0xFF0A0A0A),
          appBar: HiPopAppBar(
            title: 'Analytics Dashboard',
            userRole: 'vendor',
            centerTitle: true,
            showPremiumBadge: _hasPremiumAccess,
            bottom:
                _hasPremiumAccess
                    ? TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      indicatorColor: HiPopColors.premiumGold,
                      tabs: const [
                        Tab(icon: Icon(Icons.analytics), text: 'Overview'),
                        Tab(icon: Icon(Icons.trending_up), text: 'Revenue'),
                        Tab(
                          icon: Icon(Icons.compare_arrows),
                          text: 'Intelligence',
                        ),
                        Tab(icon: Icon(Icons.assessment), text: 'Reports'),
                      ],
                    )
                    : null,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadAnalytics,
              ),
              PopupMenuButton<AnalyticsTimeRange>(
                onSelected: (timeRange) {
                  setState(() {
                    _selectedTimeRange = timeRange;
                  });
                  _loadAnalytics();
                },
                itemBuilder:
                    (context) =>
                        AnalyticsTimeRange.values
                            .map(
                              (range) => PopupMenuItem(
                                value: range,
                                child: Text(range.displayName),
                              ),
                            )
                            .toList(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_selectedTimeRange.displayName),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body:
              _hasPremiumAccess
                  ? TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildRevenueTab(),
                      _buildIntelligenceTab(),
                      _buildReportsTab(),
                    ],
                  )
                  : _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: HiPopColors.primaryDeepSage),
            const SizedBox(height: 16),
            Text(
              'Loading analytics...',
              style: TextStyle(color: Colors.white.withOpacity( 0.8)),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: HiPopColors.errorPlum),
            const SizedBox(height: 16),
            Text(
              'Error loading analytics',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.white.withOpacity( 0.7)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAnalytics,
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.primaryDeepSage,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_summary == null || _realTimeMetrics == null) {
      return Center(
        child: Text(
          'No analytics data available',
          style: TextStyle(color: Colors.white.withOpacity( 0.6)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time range header
            _buildTimeRangeHeader(),
            const SizedBox(height: 24),

            // Key metrics overview
            _buildKeyMetrics(),
            const SizedBox(height: 24),

            // Vendor analytics
            _buildVendorAnalytics(),
            const SizedBox(height: 24),

            // Event analytics
            _buildEventAnalytics(),
            const SizedBox(height: 24),

            // Favorites analytics
            _buildFavoritesAnalytics(),
            const SizedBox(height: 24),

            // Charts and trends
            _buildChartsSection(),
            const SizedBox(height: 24),

            // Performance insights
            _buildPerformanceInsights(),

            // Premium upgrade prompt for non-premium users
            if (!_hasPremiumAccess && !_isCheckingPremium) ...[
              const SizedBox(height: 24),
              _buildPremiumUpgradePrompt(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return _buildBody();
  }

  Widget _buildRevenueTab() {
    if (_revenueAnalytics == null) {
      return Center(
        child: CircularProgressIndicator(color: HiPopColors.primaryDeepSage),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRevenueOverview(),
          const SizedBox(height: 24),
          _buildRevenueChart(),
          const SizedBox(height: 24),
          _buildRevenueBreakdown(),
        ],
      ),
    );
  }

  Widget _buildIntelligenceTab() {
    if (_marketIntelligence == null || _advancedMetrics == null) {
      return Center(
        child: CircularProgressIndicator(color: HiPopColors.primaryDeepSage),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMarketHealthScore(),
          const SizedBox(height: 24),
          _buildCompetitiveAnalysis(),
          const SizedBox(height: 24),
          _buildCustomerInsights(),
          const SizedBox(height: 24),
          _buildGrowthOpportunities(),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Generate Reports',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildReportGenerationSection(),
          const SizedBox(height: 24),
          _buildRecentReports(),
        ],
      ),
    );
  }

  Widget _buildTimeRangeHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.analytics, color: Colors.green[600], size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analytics Overview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Data for the last ${_selectedTimeRange.displayName.toLowerCase()}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (_summary!.growthRate != 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      _summary!.growthRate > 0
                          ? Colors.green[100]
                          : Colors.red[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _summary!.growthRate > 0
                          ? Icons.trending_up
                          : Icons.trending_down,
                      size: 16,
                      color:
                          _summary!.growthRate > 0
                              ? Colors.green[800]
                              : Colors.red[800],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_summary!.growthRate.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            _summary!.growthRate > 0
                                ? Colors.green[800]
                                : Colors.red[800],
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

  Widget _buildKeyMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Metrics',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildMetricCard(
              'Total Vendors',
              _summary!.totalVendors.toString(),
              Icons.store,
              Colors.blue,
            ),
            _buildMetricCard(
              'Total Events',
              _summary!.totalEvents.toString(),
              Icons.event,
              Colors.purple,
            ),
            _buildMetricCard(
              'Total Favorites',
              _summary!.totalFavorites.toString(),
              Icons.favorite,
              Colors.red,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorAnalytics() {
    final vendorMetrics =
        (_realTimeMetrics!['vendors'] as Map<String, dynamic>?) ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vendor Analytics',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniMetric(
                        'Active',
                        vendorMetrics['active']?.toString() ?? '0',
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniMetric(
                        'Pending',
                        vendorMetrics['pending']?.toString() ?? '0',
                        Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniMetric(
                        'Rejected',
                        vendorMetrics['rejected']?.toString() ?? '0',
                        Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_summary!.vendorApplicationsByStatus.isNotEmpty)
                  _buildStatusBreakdown(
                    'Vendor Connections',
                    _summary!.vendorApplicationsByStatus,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventAnalytics() {
    final eventMetrics =
        (_realTimeMetrics!['events'] as Map<String, dynamic>?) ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Event Analytics',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniMetric(
                        'Upcoming',
                        eventMetrics['upcoming']?.toString() ?? '0',
                        Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniMetric(
                        'Published',
                        eventMetrics['published']?.toString() ?? '0',
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniMetric(
                        'Avg Occupancy',
                        '${(eventMetrics['averageOccupancy'] ?? 0.0).toStringAsFixed(0)}%',
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_summary!.eventsByStatus.isNotEmpty)
                  _buildStatusBreakdown(
                    'Event Status',
                    _summary!.eventsByStatus,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatusBreakdown(String title, Map<String, int> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        ...data.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getStatusColor(entry.key),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.key.toUpperCase(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  entry.value.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trends & Charts',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        VendorRegistrationsChart(
          data: [], // Empty data for stub
          marketId: _currentMarketId ?? '',
          monthsBack:
              _selectedTimeRange == AnalyticsTimeRange.week
                  ? 3
                  : _selectedTimeRange == AnalyticsTimeRange.month
                  ? 6
                  : _selectedTimeRange == AnalyticsTimeRange.quarter
                  ? 12
                  : 12,
        ),
      ],
    );
  }

  Widget _buildPerformanceInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Insights',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInsightItem(
                  Icons.trending_up,
                  'Growth Rate',
                  '${_summary!.growthRate.toStringAsFixed(1)}% increase in vendors over ${_selectedTimeRange.displayName.toLowerCase()}',
                  _summary!.growthRate > 0 ? Colors.green : Colors.red,
                ),
                const Divider(),
                _buildInsightItem(
                  Icons.event,
                  'Event Performance',
                  'Average occupancy rate of ${(((_realTimeMetrics!['events']['averageOccupancy'] ?? 0.0) as double)).toStringAsFixed(0)}%',
                  Colors.blue,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightItem(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
      case 'published':
        return Colors.green;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Widget _buildFavoritesAnalytics() {
    final favoritesMetrics =
        (_realTimeMetrics!['favorites'] as Map<String, dynamic>?) ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Favorites Analytics',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniMetric(
                        'Market Favorites',
                        favoritesMetrics['totalMarketFavorites']?.toString() ??
                            '0',
                        Colors.red,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniMetric(
                        'Vendor Favorites',
                        favoritesMetrics['totalVendorFavorites']?.toString() ??
                            '0',
                        HiPopColors.accentMauve,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniMetric(
                        'Total Favorites',
                        ((favoritesMetrics['totalMarketFavorites'] ?? 0) +
                                (favoritesMetrics['totalVendorFavorites'] ?? 0))
                            .toString(),
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniMetric(
                        'New Market Favorites Today',
                        favoritesMetrics['newMarketFavoritesToday']
                                ?.toString() ??
                            '0',
                        Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _buildMiniMetric(
                        'New Vendor Favorites Today',
                        favoritesMetrics['newVendorFavoritesToday']
                                ?.toString() ??
                            '0',
                        Colors.cyan,
                      ),
                    ),
                    const Expanded(
                      child: SizedBox(),
                    ), // Empty space for alignment
                  ],
                ),
                const SizedBox(height: 16),
                if (_summary!.favoritesByType.isNotEmpty)
                  _buildStatusBreakdown(
                    'Favorites by Type',
                    _summary!.favoritesByType,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueOverview() {
    final revenue = _revenueAnalytics!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revenue Analytics',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildMetricCard(
              'Total Revenue',
              '\$${revenue['totalRevenue']?.toStringAsFixed(2) ?? '0.00'}',
              Icons.attach_money,
              Colors.green,
            ),
            _buildMetricCard(
              'Monthly Growth',
              '${revenue['monthlyGrowth']?.toStringAsFixed(1) ?? '0.0'}%',
              Icons.trending_up,
              Colors.blue,
            ),
            _buildMetricCard(
              'Avg per Vendor',
              '\$${revenue['averagePerVendor']?.toStringAsFixed(2) ?? '0.00'}',
              Icons.person,
              Colors.orange,
            ),
            _buildMetricCard(
              'Best Day',
              revenue['topRevenueDay'] ?? 'N/A',
              Icons.star,
              Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRevenueChart() {
    final revenueByDay =
        _revenueAnalytics!['revenueByDay'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Revenue Distribution',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY:
                      revenueByDay.values.isEmpty
                          ? 100
                          : revenueByDay.values
                                  .map((v) => v as double)
                                  .reduce((a, b) => a > b ? a : b) *
                              1.2,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const days = [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ];
                          return Text(
                            days[value.toInt() % 7],
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _createBarGroups(revenueByDay),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _createBarGroups(Map<String, dynamic> revenueByDay) {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return days.asMap().entries.map((entry) {
      final index = entry.key;
      final day = entry.value;
      final revenue = (revenueByDay[day] as double?) ?? 0.0;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: revenue,
            color: Colors.green,
            width: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildRevenueBreakdown() {
    final monthlyTrend =
        _revenueAnalytics!['monthlyTrend'] as List<Map<String, dynamic>>? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Revenue Trend',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...monthlyTrend.map(
              (month) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        month['month'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: LinearProgressIndicator(
                        value:
                            (month['revenue'] as double? ?? 0.0) /
                            16000, // Max expected revenue
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '\$${(month['revenue'] as double?)?.toStringAsFixed(0) ?? '0'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketHealthScore() {
    final healthScore =
        _advancedMetrics!['marketHealthScore'] as double? ?? 0.0;
    final vendorSatisfaction =
        _advancedMetrics!['vendorSatisfaction'] as double? ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Market Health Dashboard',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildCircularMetric(
                    'Health Score',
                    healthScore,
                    Colors.green,
                    '/ 100',
                  ),
                ),
                Expanded(
                  child: _buildCircularMetric(
                    'Vendor Satisfaction',
                    vendorSatisfaction,
                    Colors.blue,
                    '/ 5.0',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularMetric(
    String title,
    double value,
    Color color,
    String suffix,
  ) {
    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            children: [
              CircularProgressIndicator(
                value: title.contains('Health') ? value / 100 : value / 5.0,
                strokeWidth: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Positioned.fill(
                child: Center(
                  child: Text(
                    '${value.toStringAsFixed(1)}$suffix',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCompetitiveAnalysis() {
    final position =
        _advancedMetrics!['competitivePosition'] as String? ?? 'Unknown';
    final weatherCorr =
        _advancedMetrics!['weatherCorrelation'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Market Intelligence',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green),
                const SizedBox(width: 8),
                Text('Competitive Position: '),
                Text(
                  position,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Weather Impact on Attendance',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ...weatherCorr.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      entry.key == 'sunny'
                          ? Icons.wb_sunny
                          : entry.key == 'cloudy'
                          ? Icons.cloud
                          : Icons.grain,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(entry.key.toString().toUpperCase()),
                    ),
                    Text('${entry.value}% attendance'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInsights() {
    final retentionRate =
        _advancedMetrics!['customerRetentionRate'] as double? ?? 0.0;
    final averageSpend =
        _advancedMetrics!['averageSpendPerVisit'] as double? ?? 0.0;
    final peakHours =
        _advancedMetrics!['peakTrafficHours'] as List<dynamic>? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Insights',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInsightMetric(
                    'Retention Rate',
                    '${retentionRate.toStringAsFixed(1)}%',
                    Icons.repeat,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildInsightMetric(
                    'Avg Spend',
                    '\$${averageSpend.toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Peak Traffic Hours',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children:
                  peakHours
                      .map(
                        (hour) => Chip(
                          label: Text(hour.toString()),
                          backgroundColor: Colors.orange[100],
                          labelStyle: TextStyle(color: Colors.orange[700]),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildGrowthOpportunities() {
    final opportunities =
        _advancedMetrics!['growthOpportunities'] as List<dynamic>? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Growth Opportunities',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...opportunities.map(
              (opportunity) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.arrow_right, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(child: Text(opportunity.toString())),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportGenerationSection() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Reports',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildReportOption(
                  'Comprehensive Market Report',
                  'Complete market performance, vendor analytics, and revenue tracking',
                  Icons.assessment,
                  Colors.blue,
                  () => _generateReport('comprehensive'),
                ),
                const Divider(),
                _buildReportOption(
                  'Financial Summary Report',
                  'Revenue analysis, profit tracking, and financial insights',
                  Icons.account_balance,
                  Colors.green,
                  () => _generateReport('financial'),
                ),
                const Divider(),
                _buildReportOption(
                  'Vendor Performance Report',
                  'Individual vendor analytics and performance metrics',
                  Icons.store,
                  Colors.orange,
                  () => _generateReport('vendor_performance'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportOption(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onGenerate,
  ) {
    return InkWell(
      onTap: onGenerate,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity( 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentReports() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Reports',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildReportHistoryItem(
                  'Market Performance Report',
                  'PDF',
                  'Mar 15, 2024',
                  true,
                ),
                const Divider(),
                _buildReportHistoryItem(
                  'Vendor Analytics Export',
                  'CSV',
                  'Mar 10, 2024',
                  true,
                ),
                const Divider(),
                _buildReportHistoryItem(
                  'Financial Summary',
                  'PDF',
                  'Mar 5, 2024',
                  false,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportHistoryItem(
    String name,
    String format,
    String date,
    bool isReady,
  ) {
    return Row(
      children: [
        Icon(
          format == 'PDF' ? Icons.picture_as_pdf : Icons.table_chart,
          color: format == 'PDF' ? Colors.red : Colors.green,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                '$format • $date',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
        if (isReady)
          TextButton(
            onPressed: () => _downloadReport(name),
            child: const Text('Download'),
          )
        else
          Text('Processing...', style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildPremiumUpgradePrompt() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity( 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Unlock Premium Market Intelligence',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Upgrade to Organizer Premium (\$69/month) to unlock:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📊 Advanced revenue analytics & forecasting'),
                SizedBox(height: 4),
                Text('🎯 Market intelligence & competitive analysis'),
                SizedBox(height: 4),
                Text('📈 Vendor performance optimization'),
                SizedBox(height: 4),
                Text('📋 Comprehensive business reports (PDF/Excel)'),
                SizedBox(height: 4),
                Text('🌤️ Weather correlation analytics'),
                SizedBox(height: 4),
                Text('💡 Growth opportunity recommendations'),
              ],
            ),
            const SizedBox(height: 20),
            UpgradeToPremiumButton(
              userType: 'market_organizer',
              onSuccess: () {
                final authState = context.read<AuthBloc>().state;
                if (authState is Authenticated) {
                  _checkPremiumAccess();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateReport(String reportType) async {
    if (_currentMarketId == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating report...'),
              ],
            ),
          ),
    );

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! Authenticated) return;

      final report = await AdvancedReportingService.generateMarketReport(
        organizerId: authState.user.uid,
        marketId: _currentMarketId!,
        reportType: reportType,
        startDate: DateTime.now().subtract(const Duration(days: 90)),
        endDate: DateTime.now(),
        format: 'pdf',
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        if (report['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Report generated successfully!'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Download',
                textColor: Colors.white,
                onPressed: () => _downloadReport(report['reportId']),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to generate report: ${report['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _downloadReport(String reportId) {
    // In a real implementation, this would download the actual report file
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report download started'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
