import 'package:cloud_firestore/cloud_firestore.dart';
import '../vendor_management/vendor_post_service.dart';

class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});

  factory DateRange.lastDays(int days) {
    final now = DateTime.now();
    return DateRange(
      start: now.subtract(Duration(days: days)),
      end: now,
    );
  }

  factory DateRange.thisMonth() {
    final now = DateTime.now();
    return DateRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
  }

  factory DateRange.lastMonth() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    return DateRange(
      start: lastMonth,
      end: DateTime(lastMonth.year, lastMonth.month + 1, 0, 23, 59, 59),
    );
  }
}

class MarketAnalytics {
  final String marketId;
  final String marketName;
  final int totalVendors;
  final int activeVendors;
  final int totalEvents;
  final double totalRevenue;
  final int vendorApplications;
  final double averageRating;
  final Map<String, int> categoryBreakdown;
  final DateTime lastUpdated;

  const MarketAnalytics({
    required this.marketId,
    required this.marketName,
    required this.totalVendors,
    required this.activeVendors,
    required this.totalEvents,
    required this.totalRevenue,
    required this.vendorApplications,
    required this.averageRating,
    required this.categoryBreakdown,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'marketId': marketId,
      'marketName': marketName,
      'totalVendors': totalVendors,
      'activeVendors': activeVendors,
      'totalEvents': totalEvents,
      'totalRevenue': totalRevenue,
      'vendorApplications': vendorApplications,
      'averageRating': averageRating,
      'categoryBreakdown': categoryBreakdown,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

class VendorDiscoveryAnalytics {
  final int totalPosts;
  final int activePosts;
  final int totalViews;
  final int totalResponses;
  final double responseRate;
  final Map<String, int> topCategories;
  final Map<String, int> responsesByMonth;
  final int averageResponseTime; // in hours
  final double conversionRate; // responses to actual hires

  const VendorDiscoveryAnalytics({
    required this.totalPosts,
    required this.activePosts,
    required this.totalViews,
    required this.totalResponses,
    required this.responseRate,
    required this.topCategories,
    required this.responsesByMonth,
    required this.averageResponseTime,
    required this.conversionRate,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalPosts': totalPosts,
      'activePosts': activePosts,
      'totalViews': totalViews,
      'totalResponses': totalResponses,
      'responseRate': responseRate,
      'topCategories': topCategories,
      'responsesByMonth': responsesByMonth,
      'averageResponseTime': averageResponseTime,
      'conversionRate': conversionRate,
    };
  }
}

class RevenueAnalytics {
  final double totalRevenue;
  final double monthlyRevenue;
  final double averageRevenuePerVendor;
  final Map<String, double> revenueByMarket;
  final Map<String, double> revenueByMonth;
  final double projectedRevenue;
  final int totalTransactions;

  const RevenueAnalytics({
    required this.totalRevenue,
    required this.monthlyRevenue,
    required this.averageRevenuePerVendor,
    required this.revenueByMarket,
    required this.revenueByMonth,
    required this.projectedRevenue,
    required this.totalTransactions,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalRevenue': totalRevenue,
      'monthlyRevenue': monthlyRevenue,
      'averageRevenuePerVendor': averageRevenuePerVendor,
      'revenueByMarket': revenueByMarket,
      'revenueByMonth': revenueByMonth,
      'projectedRevenue': projectedRevenue,
      'totalTransactions': totalTransactions,
    };
  }
}

class OrganizerAnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get comprehensive analytics for a specific market
  static Future<MarketAnalytics> getMarketAnalytics(String organizerId, String marketId) async {
    try {
      // Get market information
      final marketDoc = await _firestore.collection('markets').doc(marketId).get();
      final marketName = marketDoc.exists ? (marketDoc.data()?['name'] ?? 'Unknown Market') : 'Unknown Market';

      // Get vendor applications for this market
      final vendorAppsQuery = await _firestore
          .collection('vendor_applications')
          .where('marketId', isEqualTo: marketId)
          .get();

      final totalApplications = vendorAppsQuery.docs.length;
      final approvedVendors = vendorAppsQuery.docs
          .where((doc) => doc.data()['status'] == 'approved')
          .length;

      // Get events for this market
      final eventsQuery = await _firestore
          .collection('events')
          .where('marketId', isEqualTo: marketId)
          .get();

      final totalEvents = eventsQuery.docs.length;

      // Get category breakdown from vendor applications
      final categoryCount = <String, int>{};
      for (final doc in vendorAppsQuery.docs) {
        final vendorId = doc.data()['vendorId'] as String;
        final vendorProfile = await _firestore
            .collection('user_profiles')
            .doc(vendorId)
            .get();
        
        if (vendorProfile.exists) {
          final categories = List<String>.from(vendorProfile.data()?['categories'] ?? []);
          for (final category in categories) {
            categoryCount[category] = (categoryCount[category] ?? 0) + 1;
          }
        }
      }

      return MarketAnalytics(
        marketId: marketId,
        marketName: marketName,
        totalVendors: approvedVendors,
        activeVendors: approvedVendors, // Simplified for now
        totalEvents: totalEvents,
        totalRevenue: 0.0, // Revenue tracking not implemented yet
        vendorApplications: totalApplications,
        averageRating: 4.2, // Mock rating for now
        categoryBreakdown: categoryCount,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      return MarketAnalytics(
        marketId: marketId,
        marketName: 'Unknown Market',
        totalVendors: 0,
        activeVendors: 0,
        totalEvents: 0,
        totalRevenue: 0.0,
        vendorApplications: 0,
        averageRating: 0.0,
        categoryBreakdown: {},
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// Get analytics for all markets managed by organizer
  static Future<List<MarketAnalytics>> getAllMarketAnalytics(String organizerId) async {
    try {
      // Get all markets managed by organizer
      final marketsQuery = await _firestore
          .collection('markets')
          .where('organizerId', isEqualTo: organizerId)
          .get();

      final analytics = <MarketAnalytics>[];
      
      for (final marketDoc in marketsQuery.docs) {
        final marketAnalytics = await getMarketAnalytics(organizerId, marketDoc.id);
        analytics.add(marketAnalytics);
      }

      return analytics;
    } catch (e) {
      return [];
    }
  }

  /// Get vendor discovery analytics
  static Future<VendorDiscoveryAnalytics> getVendorDiscoveryAnalytics(String organizerId) async {
    try {
      final postAnalytics = await OrganizerVendorPostService.getOrganizerPostAnalytics(organizerId);
      
      // Get posts for category analysis
      final posts = await OrganizerVendorPostService.getOrganizerPosts(organizerId, limit: 1000);
      
      // Analyze categories
      final categoryCount = <String, int>{};
      for (final post in posts) {
        for (final category in post.categories) {
          categoryCount[category] = (categoryCount[category] ?? 0) + 1;
        }
      }

      // Get monthly response trends
      final responsesByMonth = await _getResponsesByMonth(organizerId);
      
      // Calculate response rate
      final totalViews = postAnalytics['totalViews'] ?? 0;
      final totalResponses = postAnalytics['totalResponses'] ?? 0;
      final responseRate = totalViews > 0 ? (totalResponses / totalViews) * 100 : 0.0;

      return VendorDiscoveryAnalytics(
        totalPosts: postAnalytics['totalPosts'] ?? 0,
        activePosts: postAnalytics['activePosts'] ?? 0,
        totalViews: totalViews,
        totalResponses: totalResponses,
        responseRate: responseRate,
        topCategories: categoryCount,
        responsesByMonth: responsesByMonth,
        averageResponseTime: 24, // Mock data - 24 hours average
        conversionRate: 15.0, // Mock data - 15% conversion rate
      );
    } catch (e) {
      return const VendorDiscoveryAnalytics(
        totalPosts: 0,
        activePosts: 0,
        totalViews: 0,
        totalResponses: 0,
        responseRate: 0.0,
        topCategories: {},
        responsesByMonth: {},
        averageResponseTime: 0,
        conversionRate: 0.0,
      );
    }
  }

  /// Track vendor post interaction for analytics
  static Future<void> trackVendorPostInteraction(
    String postId,
    String action,
    String? vendorId,
  ) async {
    try {
      await _firestore.collection('vendor_post_interactions').add({
        'postId': postId,
        'action': action, // 'view', 'response', 'application', 'contact'
        'vendorId': vendorId,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      });
      
    } catch (e) {
    }
  }

  /// Get revenue analytics for organizer
  static Future<RevenueAnalytics> getRevenueAnalytics(String organizerId, DateRange range) async {
    try {
      // Get all markets managed by organizer
      final markets = await _firestore
          .collection('markets')
          .where('organizerId', isEqualTo: organizerId)
          .get();

      double totalRevenue = 0.0;
      double monthlyRevenue = 0.0;
      final revenueByMarket = <String, double>{};
      final revenueByMonth = <String, double>{};
      int totalTransactions = 0;

      // In a real implementation, this would analyze actual transaction data
      // For now, we'll use mock data based on vendor counts
      for (final marketDoc in markets.docs) {
        final marketData = marketDoc.data();
        final marketName = marketData['name'] ?? 'Unknown Market';
        
        // Mock revenue calculation based on vendor count
        final vendorCount = await _getMarketVendorCount(marketDoc.id);
        final mockMonthlyRevenue = vendorCount * 50.0; // $50 per vendor per month
        
        revenueByMarket[marketName] = mockMonthlyRevenue;
        monthlyRevenue += mockMonthlyRevenue;
        totalTransactions += vendorCount;
      }

      // Mock historical revenue data
      final now = DateTime.now();
      for (int i = 0; i < 12; i++) {
        final month = DateTime(now.year, now.month - i);
        final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
        revenueByMonth[monthKey] = monthlyRevenue * (0.8 + (i * 0.1)); // Simulated growth
      }

      totalRevenue = monthlyRevenue * 12; // Annualized

      return RevenueAnalytics(
        totalRevenue: totalRevenue,
        monthlyRevenue: monthlyRevenue,
        averageRevenuePerVendor: totalTransactions > 0 ? monthlyRevenue / totalTransactions : 0.0,
        revenueByMarket: revenueByMarket,
        revenueByMonth: revenueByMonth,
        projectedRevenue: monthlyRevenue * 12 * 1.2, // 20% growth projection
        totalTransactions: totalTransactions,
      );
    } catch (e) {
      return const RevenueAnalytics(
        totalRevenue: 0.0,
        monthlyRevenue: 0.0,
        averageRevenuePerVendor: 0.0,
        revenueByMarket: {},
        revenueByMonth: {},
        projectedRevenue: 0.0,
        totalTransactions: 0,
      );
    }
  }

  /// Get comprehensive dashboard metrics for organizer
  static Future<Map<String, dynamic>> getDashboardMetrics(String organizerId) async {
    try {
      // Get basic market metrics
      final marketAnalytics = await getAllMarketAnalytics(organizerId);
      final vendorDiscoveryAnalytics = await getVendorDiscoveryAnalytics(organizerId);
      final revenueAnalytics = await getRevenueAnalytics(
        organizerId, 
        DateRange.thisMonth(),
      );

      // Aggregate market metrics
      final totalVendors = marketAnalytics.fold(0, (sum, m) => sum + m.totalVendors);
      final totalEvents = marketAnalytics.fold(0, (sum, m) => sum + m.totalEvents);
      final activeMarkets = marketAnalytics.length;

      // Growth calculations (comparing to last month)
      final lastMonthMetrics = await _getLastMonthMetrics(organizerId);
      final vendorGrowth = _calculateGrowthPercentage(
        totalVendors.toDouble(), 
        lastMonthMetrics['totalVendors'] ?? 0.0,
      );
      final revenueGrowth = _calculateGrowthPercentage(
        revenueAnalytics.monthlyRevenue, 
        lastMonthMetrics['monthlyRevenue'] ?? 0.0,
      );

      return {
        // Key metrics
        'totalVendors': totalVendors,
        'activeMarkets': activeMarkets,
        'totalEvents': totalEvents,
        'monthlyRevenue': revenueAnalytics.monthlyRevenue,
        
        // Vendor posts metrics
        'totalVendorPosts': vendorDiscoveryAnalytics.totalPosts,
        'activeVendorPosts': vendorDiscoveryAnalytics.activePosts,
        'postResponseRate': vendorDiscoveryAnalytics.responseRate,
        'totalPostViews': vendorDiscoveryAnalytics.totalViews,
        'totalPostResponses': vendorDiscoveryAnalytics.totalResponses,
        
        // Growth metrics
        'vendorGrowth': vendorGrowth,
        'revenueGrowth': revenueGrowth,
        
        // Category insights
        'topCategories': vendorDiscoveryAnalytics.topCategories,
        'marketCategoryBreakdown': _aggregateCategoryBreakdown(marketAnalytics),
        
        // Recent activity
        'recentPosts': await _getRecentPostsCount(organizerId, 7),
        'recentResponses': await _getRecentResponsesCount(organizerId, 7),
        
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'totalVendors': 0,
        'activeMarkets': 0,
        'totalEvents': 0,
        'monthlyRevenue': 0.0,
        'totalVendorPosts': 0,
        'activeVendorPosts': 0,
        'postResponseRate': 0.0,
        'totalPostViews': 0,
        'totalPostResponses': 0,
        'vendorGrowth': 0.0,
        'revenueGrowth': 0.0,
        'topCategories': {},
        'marketCategoryBreakdown': {},
        'recentPosts': 0,
        'recentResponses': 0,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Helper method to get responses by month for trending analysis
  static Future<Map<String, int>> _getResponsesByMonth(String organizerId) async {
    try {
      final responses = await _firestore
          .collection('organizer_vendor_post_responses')
          .where('organizerId', isEqualTo: organizerId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 365))
          ))
          .get();

      final responsesByMonth = <String, int>{};
      
      for (final doc in responses.docs) {
        final createdAt = (doc.data()['createdAt'] as Timestamp).toDate();
        final monthKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
        responsesByMonth[monthKey] = (responsesByMonth[monthKey] ?? 0) + 1;
      }

      return responsesByMonth;
    } catch (e) {
      return {};
    }
  }

  /// Helper method to get vendor count for a market
  static Future<int> _getMarketVendorCount(String marketId) async {
    try {
      final vendorApps = await _firestore
          .collection('vendor_applications')
          .where('marketId', isEqualTo: marketId)
          .where('status', isEqualTo: 'approved')
          .get();
      
      return vendorApps.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Helper method to get last month's metrics for growth calculation
  static Future<Map<String, double>> _getLastMonthMetrics(String organizerId) async {
    try {
      // In a real implementation, this would query historical analytics data
      // For now, return mock data with slight variations
      final currentMetrics = await getDashboardMetrics(organizerId);
      
      return {
        'totalVendors': (currentMetrics['totalVendors'] * 0.9).toDouble(),
        'monthlyRevenue': (currentMetrics['monthlyRevenue'] * 0.85).toDouble(),
      };
    } catch (e) {
      return {'totalVendors': 0.0, 'monthlyRevenue': 0.0};
    }
  }

  /// Calculate growth percentage between current and previous values
  static double _calculateGrowthPercentage(double current, double previous) {
    if (previous == 0) return current > 0 ? 100.0 : 0.0;
    return ((current - previous) / previous) * 100;
  }

  /// Aggregate category breakdown across all markets
  static Map<String, int> _aggregateCategoryBreakdown(List<MarketAnalytics> marketAnalytics) {
    final aggregated = <String, int>{};
    
    for (final market in marketAnalytics) {
      market.categoryBreakdown.forEach((category, count) {
        aggregated[category] = (aggregated[category] ?? 0) + count;
      });
    }
    
    return aggregated;
  }

  /// Get count of recent posts
  static Future<int> _getRecentPostsCount(String organizerId, int days) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      final recentPosts = await _firestore
          .collection('organizer_vendor_posts')
          .where('organizerId', isEqualTo: organizerId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .get();
      
      return recentPosts.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Get count of recent responses
  static Future<int> _getRecentResponsesCount(String organizerId, int days) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      final recentResponses = await _firestore
          .collection('organizer_vendor_post_responses')
          .where('organizerId', isEqualTo: organizerId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .get();
      
      return recentResponses.docs.length;
    } catch (e) {
      return 0;
    }
  }
}