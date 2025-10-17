import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import 'package:intl/intl.dart';
import '../services/ceo_metrics_service.dart';

class CEOMetricsDashboard extends StatefulWidget {
  const CEOMetricsDashboard({super.key});

  @override
  State<CEOMetricsDashboard> createState() => _CEOMetricsDashboardState();
}

class _CEOMetricsDashboardState extends State<CEOMetricsDashboard> {
  Map<String, dynamic> _metrics = {};
  bool _isLoading = true;
  Timer? _refreshTimer;
  String _lastUpdated = '';

  @override
  void initState() {
    super.initState();
    _loadMetrics();

    // Auto-refresh every 60 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _loadMetrics();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    if (!mounted) return;

    final metrics = await CEOMetricsService.getPlatformMetrics();
    final trends = await CEOMetricsService.getGrowthTrends();

    if (mounted) {
      setState(() {
        _metrics = {...metrics, 'trends': trends};
        _isLoading = false;
        _lastUpdated = DateFormat('h:mm a').format(DateTime.now());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check CEO access
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return Scaffold(
            backgroundColor: HiPopColors.darkBackground,
            appBar: AppBar(
              title: const Text('CEO Dashboard'),
              backgroundColor: HiPopColors.darkSurface,
            ),
            body: const Center(child: Text('Please sign in to access this dashboard')),
          );
        }

        final userProfile = state.userProfile;
        if (userProfile == null || userProfile.email != 'jordangillispie@outlook.com') {
          return Scaffold(
            backgroundColor: HiPopColors.darkBackground,
            appBar: AppBar(
              title: const Text('CEO Dashboard'),
              backgroundColor: HiPopColors.darkSurface,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security, size: 64, color: HiPopColors.darkTextTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'Access Denied',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'CEO access only',
                    style: TextStyle(
                      fontSize: 16,
                      color: HiPopColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: HiPopColors.darkBackground,
          appBar: AppBar(
            title: const Text('CEO Dashboard'),
            backgroundColor: HiPopColors.darkSurface,
            actions: [
              if (_lastUpdated.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(
                      'Updated $_lastUpdated',
                      style: TextStyle(
                        fontSize: 12,
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadMetrics();
                },
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadMetrics,
                  color: HiPopColors.shopperAccent,
                  backgroundColor: HiPopColors.darkSurface,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Core Metrics
                        _buildSectionTitle('Core Metrics'),
                        const SizedBox(height: 12),
                        _buildCoreMetrics(),

                        const SizedBox(height: 32),

                        // Growth Chart
                        _buildSectionTitle('30-Day Growth'),
                        const SizedBox(height: 12),
                        _buildGrowthChart(),

                        const SizedBox(height: 32),

                        // Activity Metrics
                        _buildSectionTitle('Activity'),
                        const SizedBox(height: 12),
                        _buildActivityMetrics(),

                        const SizedBox(height: 32),

                        // Health Indicators
                        _buildSectionTitle('Platform Health'),
                        const SizedBox(height: 12),
                        _buildHealthMetrics(),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: HiPopColors.darkTextPrimary,
      ),
    );
  }

  Widget _buildCoreMetrics() {
    final users = _metrics['users'] ?? {};
    final kpis = _metrics['kpis'] ?? {};

    final totalUsers = users['total'] ?? 0;
    final activeToday = users['activeUsers']?['today'] ?? 0;
    final activeMonth = users['activeUsers']?['month'] ?? 0;

    // Calculate retention (returning users / total active)
    final returningUsers = kpis['returningUsers']?['thisWeek'] ?? 0;
    final totalActive = users['activeUsers']?['week'] ?? 1;
    final retention = totalActive > 0 ? (returningUsers / totalActive * 100) : 0;

    // Calculate churn (estimate: users who were active last week but not this week)
    final lastWeekReturning = kpis['returningUsers']?['lastWeek'] ?? 0;
    final thisWeekReturning = kpis['returningUsers']?['thisWeek'] ?? 1;
    final churn = lastWeekReturning > 0
        ? ((lastWeekReturning - thisWeekReturning) / lastWeekReturning * 100).clamp(0, 100)
        : 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Users',
          totalUsers.toString(),
          Icons.people,
          HiPopColors.shopperAccent,
          change: kpis['newSignups']?['weeklyChange'] ?? 0,
        ),
        _buildMetricCard(
          'Daily Active',
          activeToday.toString(),
          Icons.trending_up,
          HiPopColors.successGreen,
          subtitle: 'DAU',
        ),
        _buildMetricCard(
          'Monthly Active',
          activeMonth.toString(),
          Icons.calendar_month,
          HiPopColors.vendorAccent,
          subtitle: 'MAU',
        ),
        _buildMetricCard(
          'Retention',
          '${retention.toStringAsFixed(1)}%',
          Icons.repeat,
          HiPopColors.organizerAccent,
          subtitle: '7-day',
        ),
        _buildMetricCard(
          'Churn Rate',
          '${churn.toStringAsFixed(1)}%',
          Icons.trending_down,
          churn > 10 ? HiPopColors.errorPlum : HiPopColors.darkTextSecondary,
          subtitle: 'Weekly',
        ),
        _buildMetricCard(
          'New Today',
          (users['newUsers']?['today'] ?? 0).toString(),
          Icons.person_add,
          HiPopColors.successGreen,
          subtitle: 'Signups',
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
    double? change,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HiPopColors.darkBorder.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: HiPopColors.darkTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: HiPopColors.darkTextTertiary,
              ),
            ),
          if (change != null)
            Row(
              children: [
                Icon(
                  change >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: change >= 0 ? HiPopColors.successGreen : HiPopColors.errorPlum,
                ),
                const SizedBox(width: 4),
                Text(
                  '${change.abs().toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: change >= 0 ? HiPopColors.successGreen : HiPopColors.errorPlum,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGrowthChart() {
    final trends = _metrics['trends'] ?? {};
    final dailyUsers = trends['dailyNewUsers'] as Map<String, dynamic>? ?? {};

    if (dailyUsers.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: HiPopColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No growth data available',
            style: TextStyle(color: HiPopColors.darkTextSecondary),
          ),
        ),
      );
    }

    // Sort by date
    final sortedEntries = dailyUsers.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final spots = <FlSpot>[];
    for (var i = 0; i < sortedEntries.length; i++) {
      spots.add(FlSpot(i.toDouble(), (sortedEntries[i].value as num).toDouble()));
    }

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HiPopColors.darkBorder.withValues(alpha: 0.3),
        ),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine: (value) => FlLine(
              color: HiPopColors.darkBorder.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (spots.length / 6).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < sortedEntries.length) {
                    final date = sortedEntries[value.toInt()].key;
                    final parts = date.split('-');
                    if (parts.length == 3) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${parts[1]}/${parts[2]}',
                          style: TextStyle(
                            color: HiPopColors.darkTextTertiary,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: maxY / 5,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: HiPopColors.darkTextTertiary,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: spots.length.toDouble() - 1,
          minY: 0,
          maxY: maxY * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: HiPopColors.shopperAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: HiPopColors.shopperAccent.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityMetrics() {
    final kpis = _metrics['kpis'] ?? {};

    final postsToday = kpis['postsCreated']?['today'] ?? 0;
    final postsWeek = kpis['postsCreated']?['thisWeek'] ?? 0;
    final postsChange = kpis['postsCreated']?['weeklyChange'] ?? 0;

    final ordersToday = kpis['itemPreorders']?['today'] ?? 0;
    final ordersWeek = kpis['itemPreorders']?['thisWeek'] ?? 0;
    final ordersChange = kpis['itemPreorders']?['weeklyChange'] ?? 0;

    final ticketsToday = kpis['ticketsPurchased']?['today'] ?? 0;
    final ticketsWeek = kpis['ticketsPurchased']?['thisWeek'] ?? 0;
    final ticketsChange = kpis['ticketsPurchased']?['weeklyChange'] ?? 0;

    final productsToday = kpis['productsListed']?['today'] ?? 0;
    final productsWeek = kpis['productsListed']?['thisWeek'] ?? 0;
    final productsChange = kpis['productsListed']?['weeklyChange'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildActivityCard(
          'Posts Created',
          postsToday,
          postsWeek,
          postsChange,
          Icons.feed,
          HiPopColors.vendorAccent,
        ),
        _buildActivityCard(
          'Items Reserved',
          ordersToday,
          ordersWeek,
          ordersChange,
          Icons.shopping_cart,
          HiPopColors.shopperAccent,
        ),
        _buildActivityCard(
          'Tickets Sold',
          ticketsToday,
          ticketsWeek,
          ticketsChange,
          Icons.confirmation_number,
          HiPopColors.organizerAccent,
        ),
        _buildActivityCard(
          'Products Listed',
          productsToday,
          productsWeek,
          productsChange,
          Icons.inventory,
          HiPopColors.successGreen,
        ),
      ],
    );
  }

  Widget _buildActivityCard(
    String label,
    int today,
    int week,
    double change,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HiPopColors.darkBorder.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: HiPopColors.darkTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                today.toString(),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'today',
                style: TextStyle(
                  fontSize: 11,
                  color: HiPopColors.darkTextTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '$week this week',
                style: TextStyle(
                  fontSize: 11,
                  color: HiPopColors.darkTextSecondary,
                ),
              ),
              const SizedBox(width: 8),
              if (change != 0)
                Row(
                  children: [
                    Icon(
                      change >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 10,
                      color: change >= 0 ? HiPopColors.successGreen : HiPopColors.errorPlum,
                    ),
                    Text(
                      '${change.abs().toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: change >= 0 ? HiPopColors.successGreen : HiPopColors.errorPlum,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetrics() {
    final users = _metrics['users'] ?? {};
    final vendors = _metrics['vendors'] ?? {};
    final markets = _metrics['markets'] ?? {};
    final revenue = _metrics['revenue'] ?? {};

    final userTypes = users['byType'] ?? {};
    final vendorCount = userTypes['vendors'] ?? 0;
    final organizerCount = userTypes['organizers'] ?? 0;
    final shopperCount = userTypes['shoppers'] ?? 0;

    final activeVendors = vendors['active'] ?? 0;
    final activeMarkets = markets['active'] ?? 0;
    final upcomingMarkets = markets['upcoming'] ?? 0;

    final totalRevenue = revenue['totalRevenue'] ?? 0.0;
    final monthRevenue = revenue['monthRevenue'] ?? 0.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildHealthCard(
                'Vendors',
                '$vendorCount total',
                '$activeVendors active',
                Icons.store,
                HiPopColors.vendorAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildHealthCard(
                'Organizers',
                '$organizerCount total',
                '$upcomingMarkets events',
                Icons.event,
                HiPopColors.organizerAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildHealthCard(
                'Shoppers',
                '$shopperCount total',
                '${users['activeUsers']?['week'] ?? 0} active',
                Icons.shopping_bag,
                HiPopColors.shopperAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildHealthCard(
                'Revenue',
                '\$${totalRevenue.toStringAsFixed(0)}',
                '\$${monthRevenue.toStringAsFixed(0)} MTD',
                Icons.attach_money,
                HiPopColors.successGreen,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHealthCard(
    String label,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HiPopColors.darkBorder.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: HiPopColors.darkTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: HiPopColors.darkTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
