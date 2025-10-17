import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hipop/features/premium/services/subscription_service.dart';
import 'package:hipop/features/shared/models/usage_tracking.dart';

class UsageTrackingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _usageCollection = 
      _firestore.collection('usage_tracking');

  /// Track a usage event
  static Future<void> trackUsage({
    required String userId,
    required String userType,
    required UsageMetricType metricType,
    required String metricName,
    String? resourceId,
    int count = 1,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentMonth = UsageTracking.getCurrentMonthYear();
      
      // Check if usage record already exists for this month
      final existingUsage = await _getUsageRecord(
        userId, 
        metricName, 
        currentMonth,
      );

      if (existingUsage != null) {
        // Update existing record
        final updatedUsage = existingUsage.incrementCount(increment: count);
        await _usageCollection
            .doc(existingUsage.id)
            .update(updatedUsage.toFirestore());
        
      } else {
        // Create new usage record
        final newUsage = UsageTracking.create(
          userId: userId,
          userType: userType,
          metricType: metricType,
          metricName: metricName,
          resourceId: resourceId,
          count: count,
          metadata: metadata,
        );

        await _usageCollection.add(newUsage.toFirestore());
      }
    } catch (e) {
      // Don't throw - usage tracking shouldn't break app functionality
    }
  }

  /// Get usage record for specific month
  static Future<UsageTracking?> _getUsageRecord(
    String userId,
    String metricName,
    int monthYear,
  ) async {
    try {
      final snapshot = await _usageCollection
          .where('userId', isEqualTo: userId)
          .where('metricName', isEqualTo: metricName)
          .where('monthYear', isEqualTo: monthYear)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return UsageTracking.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get current month usage for a user
  static Future<UsageAggregate> getCurrentMonthUsage(String userId) async {
    try {
      final currentMonth = UsageTracking.getCurrentMonthYear();
      final snapshot = await _usageCollection
          .where('userId', isEqualTo: userId)
          .where('monthYear', isEqualTo: currentMonth)
          .get();

      final usageRecords = snapshot.docs
          .map((doc) => UsageTracking.fromFirestore(doc))
          .toList();

      final userType = usageRecords.isNotEmpty 
          ? usageRecords.first.userType 
          : 'shopper';

      return UsageAggregate.fromUsageRecords(
        userId, 
        userType, 
        currentMonth, 
        usageRecords,
      );
    } catch (e) {
      return UsageAggregate(
        userId: userId,
        userType: 'shopper',
        monthYear: UsageTracking.getCurrentMonthYear(),
        metrics: {},
        calculatedAt: DateTime.now(),
      );
    }
  }

  /// Get usage history for a user
  static Future<List<UsageAggregate>> getUserUsageHistory(
    String userId, {
    int monthsBack = 6,
  }) async {
    try {
      final now = DateTime.now();
      final monthsToFetch = <int>[];
      
      for (int i = 0; i < monthsBack; i++) {
        final date = DateTime(now.year, now.month - i, 1);
        monthsToFetch.add(UsageTracking.generateMonthYearKey(date));
      }

      final snapshot = await _usageCollection
          .where('userId', isEqualTo: userId)
          .where('monthYear', whereIn: monthsToFetch)
          .get();

      final allUsageRecords = snapshot.docs
          .map((doc) => UsageTracking.fromFirestore(doc))
          .toList();

      final userType = allUsageRecords.isNotEmpty 
          ? allUsageRecords.first.userType 
          : 'shopper';

      final aggregates = <UsageAggregate>[];
      
      for (final monthYear in monthsToFetch) {
        final monthRecords = allUsageRecords
            .where((record) => record.monthYear == monthYear)
            .toList();
        
        aggregates.add(UsageAggregate.fromUsageRecords(
          userId, 
          userType, 
          monthYear, 
          monthRecords,
        ));
      }

      return aggregates;
    } catch (e) {
      return [];
    }
  }

  /// Check if user can perform action (within limits)
  static Future<bool> canPerformAction(
    String userId,
    String limitName,
  ) async {
    try {
      final currentUsage = await getCurrentMonthUsage(userId);
      final usageCount = currentUsage.getMetric(limitName);
      
      return await SubscriptionService.isWithinLimit(userId, limitName, usageCount);
    } catch (e) {
      return false;
    }
  }

  /// Get remaining usage for a limit
  static Future<int> getRemainingUsage(
    String userId,
    String limitName,
  ) async {
    try {
      final currentUsage = await getCurrentMonthUsage(userId);
      final usageCount = currentUsage.getMetric(limitName);
      final limit = await SubscriptionService.getUserLimit(userId, limitName);
      
      if (limit == -1) return -1; // Unlimited
      
      final remaining = limit - usageCount;
      return remaining > 0 ? remaining : 0;
    } catch (e) {
      return 0;
    }
  }

  /// Track market participation for vendor
  static Future<bool> trackMarketParticipation(
    String vendorId,
    String marketId,
  ) async {
    try {
      // Check if vendor can participate in another market this month
      final canParticipate = await canPerformAction(vendorId, 'monthly_markets');
      
      if (!canParticipate) {
        return false;
      }

      // Track the usage
      await trackUsage(
        userId: vendorId,
        userType: 'vendor',
        metricType: UsageMetricType.marketParticipation,
        metricName: 'monthly_markets',
        resourceId: marketId,
        metadata: {
          'marketId': marketId,
          'participatedAt': DateTime.now().toIso8601String(),
        },
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Track event creation for market organizer
  static Future<bool> trackEventCreation(
    String organizerId,
    String eventId,
    String marketId,
  ) async {
    try {
      // Check if organizer can create another event this month
      final canCreate = await canPerformAction(organizerId, 'events_per_month');
      
      if (!canCreate) {
        return false;
      }

      // Track the usage
      await trackUsage(
        userId: organizerId,
        userType: 'market_organizer',
        metricType: UsageMetricType.eventCreation,
        metricName: 'events_per_month',
        resourceId: eventId,
        metadata: {
          'eventId': eventId,
          'marketId': marketId,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Track favorite market for shopper
  static Future<bool> trackFavoriteMarket(
    String shopperId,
    String marketId,
  ) async {
    try {
      // Check if shopper can save another favorite
      final canSave = await canPerformAction(shopperId, 'saved_favorites');
      
      if (!canSave) {
        return false;
      }

      // Track the usage
      await trackUsage(
        userId: shopperId,
        userType: 'shopper',
        metricType: UsageMetricType.favoriteMarket,
        metricName: 'saved_favorites',
        resourceId: marketId,
        metadata: {
          'marketId': marketId,
          'favoriteAt': DateTime.now().toIso8601String(),
        },
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get usage statistics for admin dashboard
  static Future<Map<String, dynamic>> getUsageStats({
    int monthsBack = 3,
  }) async {
    try {
      final now = DateTime.now();
      final monthsToFetch = <int>[];
      
      for (int i = 0; i < monthsBack; i++) {
        final date = DateTime(now.year, now.month - i, 1);
        monthsToFetch.add(UsageTracking.generateMonthYearKey(date));
      }

      final snapshot = await _usageCollection
          .where('monthYear', whereIn: monthsToFetch)
          .get();

      final allUsage = snapshot.docs
          .map((doc) => UsageTracking.fromFirestore(doc))
          .toList();

      final stats = <String, dynamic>{
        'total_users': <String>{},
        'by_metric': <String, int>{},
        'by_user_type': <String, int>{},
        'by_month': <String, int>{},
        'most_active_users': <String, int>{},
      };

      for (final usage in allUsage) {
        // Track unique users
        (stats['total_users'] as Set<String>).add(usage.userId);
        
        // Count by metric
        final byMetric = stats['by_metric'] as Map<String, int>;
        byMetric[usage.metricName] = (byMetric[usage.metricName] ?? 0) + usage.count;
        
        // Count by user type
        final byUserType = stats['by_user_type'] as Map<String, int>;
        byUserType[usage.userType] = (byUserType[usage.userType] ?? 0) + usage.count;
        
        // Count by month
        final byMonth = stats['by_month'] as Map<String, int>;
        final monthKey = usage.monthYearDisplay;
        byMonth[monthKey] = (byMonth[monthKey] ?? 0) + usage.count;
        
        // Track most active users
        final mostActive = stats['most_active_users'] as Map<String, int>;
        mostActive[usage.userId] = (mostActive[usage.userId] ?? 0) + usage.count;
      }

      // Convert total_users set to count
      stats['total_users'] = (stats['total_users'] as Set<String>).length;

      return stats;
    } catch (e) {
      throw Exception('Failed to get usage statistics: $e');
    }
  }

  /// Reset usage for testing (development only)
  static Future<void> resetUserUsage(String userId) async {
    if (!kDebugMode) {
      throw Exception('resetUserUsage is only available in debug mode');
    }
    
    try {
      final snapshot = await _usageCollection
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to reset usage: $e');
    }
  }
}