import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:atv_events/features/shared/models/analytics.dart';

class AnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _analyticsCollection =
      _firestore.collection('market_analytics');

  /// Generate and store daily analytics for a market
  static Future<void> generateDailyAnalytics(
    String marketId,
    String organizerId,
  ) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      // Get vendor metrics
      final vendorMetrics = await _getVendorMetrics(marketId);
      
      
      // Get favorites metrics
      final favoritesMetrics = await _getFavoritesMetrics(marketId);
      
      // Create analytics record
      final analytics = MarketAnalytics(
        marketId: marketId,
        organizerId: organizerId,
        date: startOfDay,
        totalVendors: vendorMetrics['total'] ?? 0,
        activeVendors: vendorMetrics['active'] ?? 0,
        newVendorApplications: vendorMetrics['newApplications'] ?? 0,
        approvedApplications: vendorMetrics['approved'] ?? 0,
        rejectedApplications: vendorMetrics['rejected'] ?? 0,
        totalEvents: 0,
        publishedEvents: 0,
        completedEvents: 0,
        upcomingEvents: 0,
        averageEventOccupancy: 0.0,
        totalMarketFavorites: favoritesMetrics['totalMarketFavorites'] ?? 0,
        totalVendorFavorites: favoritesMetrics['totalVendorFavorites'] ?? 0,
        newMarketFavoritesToday: favoritesMetrics['newMarketFavoritesToday'] ?? 0,
        newVendorFavoritesToday: favoritesMetrics['newVendorFavoritesToday'] ?? 0,
      );
      
      // Store or update analytics
      final docId = '${marketId}_${startOfDay.millisecondsSinceEpoch}';
      await _analyticsCollection.doc(docId).set(analytics.toFirestore());
      
    } catch (e) {
      throw Exception('Failed to generate analytics: $e');
    }
  }

  /// Get analytics summary for a market over a time range
  static Future<AnalyticsSummary> getAnalyticsSummary(
    String marketId,
    AnalyticsTimeRange timeRange,
  ) async {
    try {
      
      // Get real-time metrics instead of stored analytics for now
      final realTimeMetrics = await getRealTimeMetrics(marketId);
      
      final vendorMetrics = (realTimeMetrics['vendors'] as Map<String, dynamic>?) ?? {};
      final favoritesMetrics = (realTimeMetrics['favorites'] as Map<String, dynamic>?) ?? {};
      
      // Get current breakdowns
      final vendorApplicationsByStatus = await _getVendorApplicationBreakdown(marketId);
      
      return AnalyticsSummary(
        totalVendors: vendorMetrics['total'] ?? 0,
        totalEvents: 0,
        totalViews: 0, // No view tracking yet
        growthRate: 0.0, // Calculate when we have historical data
        vendorApplicationsByStatus: vendorApplicationsByStatus,
        eventsByStatus: <String, int>{},
        totalFavorites: (favoritesMetrics['totalMarketFavorites'] ?? 0) + (favoritesMetrics['totalVendorFavorites'] ?? 0),
        favoritesByType: {
          'market': favoritesMetrics['totalMarketFavorites'] ?? 0,
          'vendor': favoritesMetrics['totalVendorFavorites'] ?? 0,
        },
        dailyData: [], // No historical data yet
      );
    } catch (e) {
      // Return empty summary instead of throwing
      return const AnalyticsSummary();
    }
  }

  /// Get real-time metrics for dashboard
  static Future<Map<String, dynamic>> getRealTimeMetrics(String marketId) async {
    try {
      
      final vendorMetrics = await _getVendorMetrics(marketId);
      final favoritesMetrics = await _getFavoritesMetrics(marketId);
      
      
      return {
        'vendors': vendorMetrics,
        'favorites': favoritesMetrics,
        'events': {
          'total': 0,
          'upcoming': 0,
          'published': 0,
          'averageOccupancy': 0.0,
        },
        'lastUpdated': DateTime.now(),
      };
    } catch (e) {
      // Return default metrics instead of throwing
      return {
        'vendors': {'total': 0, 'active': 0, 'pending': 0, 'approved': 0, 'rejected': 0},
        'favorites': {'totalMarketFavorites': 0, 'totalVendorFavorites': 0, 'newMarketFavoritesToday': 0, 'newVendorFavoritesToday': 0},
        'events': {
          'total': 0,
          'upcoming': 0,
          'published': 0,
          'averageOccupancy': 0.0,
        },
        'lastUpdated': DateTime.now(),
      };
    }
  }

  /// Private helper methods
  static Future<Map<String, dynamic>> _getVendorMetrics(String marketId) async {
    // No vendors in ATV Events - return zero metrics
    return {'total': 0, 'active': 0, 'newApplications': 0, 'approved': 0, 'rejected': 0, 'pending': 0};
  }



  static Future<Map<String, int>> _getVendorApplicationBreakdown(String marketId) async {
    // No vendors in ATV Events - return empty metrics
    return {'pending': 0, 'approved': 0, 'rejected': 0};
  }



  static Future<Map<String, dynamic>> _getFavoritesMetrics(String marketId) async {
    try {
      
      // Get all market favorites for this market
      final marketFavoritesSnapshot = await _firestore
          .collection('user_favorites')
          .where('itemId', isEqualTo: marketId)
          .where('type', isEqualTo: 'market')
          .get();
      
      final totalMarketFavorites = marketFavoritesSnapshot.docs.length;
      
      // Get vendor favorites for vendors in this market
      // First, get all vendors for this market from managed_vendors
      final managedVendorsSnapshot = await _firestore
          .collection('managed_vendors')
          .where('marketId', isEqualTo: marketId)
          .where('isActive', isEqualTo: true)
          .get();
      
      final vendorIds = managedVendorsSnapshot.docs
          .map((doc) => doc.id)
          .toList();
      
      int totalVendorFavorites = 0;
      if (vendorIds.isNotEmpty) {
        // Firestore "in" queries can only handle up to 10 items
        // If more than 10 vendors, we need to batch the queries
        for (int i = 0; i < vendorIds.length; i += 10) {
          final batch = vendorIds.skip(i).take(10).toList();
          final vendorFavoritesSnapshot = await _firestore
              .collection('user_favorites')
              .where('itemId', whereIn: batch)
              .where('type', isEqualTo: 'vendor')
              .get();
          totalVendorFavorites += vendorFavoritesSnapshot.docs.length;
        }
      }
      
      // Get new favorites today
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final newMarketFavoritesToday = marketFavoritesSnapshot.docs
          .where((doc) {
            final data = doc.data();
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            return createdAt != null && createdAt.isAfter(startOfDay);
          })
          .length;
      
      // Get new vendor favorites today (simplified - just count all vendor favorites created today)
      final newVendorFavoritesTodaySnapshot = await _firestore
          .collection('user_favorites')
          .where('type', isEqualTo: 'vendor')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      
      // Filter to only include vendors from this market
      final newVendorFavoritesToday = newVendorFavoritesTodaySnapshot.docs
          .where((doc) {
            final data = doc.data();
            final itemId = data['itemId'] as String?;
            return itemId != null && vendorIds.contains(itemId);
          })
          .length;
      
      final metrics = {
        'totalMarketFavorites': totalMarketFavorites,
        'totalVendorFavorites': totalVendorFavorites,
        'newMarketFavoritesToday': newMarketFavoritesToday,
        'newVendorFavoritesToday': newVendorFavoritesToday,
      };
      
      return metrics;
    } catch (e) {
      // For now, ignore permission errors and return empty metrics
      // This is common when market organizers don't have explicit permission
      // to read user favorites data
      return {
        'totalMarketFavorites': 0,
        'totalVendorFavorites': 0,
        'newMarketFavoritesToday': 0,
        'newVendorFavoritesToday': 0,
      };
    }
  }


  /// Export analytics data
  static Future<List<MarketAnalytics>> exportAnalyticsData(
    String marketId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _analyticsCollection
          .where('marketId', isEqualTo: marketId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: false)
          .get();
      
      return snapshot.docs
          .map((doc) => MarketAnalytics.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to export analytics data: $e');
    }
  }

  /// Get vendor registrations by month for chart data
  static Future<List<Map<String, dynamic>>> getVendorRegistrationsByMonth(
    String marketId,
    int monthsBack
  ) async {
    // No vendors in ATV Events - return empty trend data
    final now = DateTime.now();
    final monthlyData = <Map<String, dynamic>>[];

    // Return empty months with zero values
    for (int i = 0; i < monthsBack; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      monthlyData.add({
        'month': monthKey,
        'monthName': _getMonthName(monthKey),
        'total': 0,
        'approved': 0,
        'pending': 0,
        'rejected': 0,
      });
    }

    return monthlyData;
  }

  /// Helper method to get month name from YYYY-MM format
  static String _getMonthName(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    
    final year = int.tryParse(parts[0]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 1;
    
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    if (month < 1 || month > 12) return monthKey;
    
    return '${months[month - 1]} ${year.toString().substring(2)}'; // e.g., "Jan 24"
  }

}