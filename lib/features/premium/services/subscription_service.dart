// TODO: Removed for ATV Events demo - Premium/subscription features disabled
// This is a stub to maintain compilation

import '../models/user_subscription.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  Future<void> initialize() async {
    // Do nothing - premium features disabled
  }

  // Make getUserSubscription static for compatibility
  static Future<UserSubscription?> getUserSubscription(String userId) async {
    // Return null - premium features disabled
    return null;
  }

  Stream<UserSubscription?> getUserSubscriptionStream(String userId) {
    // Return empty stream - premium features disabled
    return Stream.value(null);
  }

  Future<bool> hasActiveSubscription(String userId) async {
    // Return false - premium features disabled
    return false;
  }

  Future<void> subscribe(String userId, String planId) async {
    // Do nothing - premium features disabled
  }

  Future<void> cancelSubscription(String userId) async {
    // Do nothing - premium features disabled
  }

  // Additional stub methods for compatibility
  static Future<bool> hasFeature(String userId, String feature) async {
    // Return false - premium features disabled
    return false;
  }

  static Future<bool> canCreateMarket(String userId) async {
    // Return true - no limits for MVP
    return true;
  }

  static Future<void> incrementMarketCount(String userId) async {
    // Do nothing - no tracking for MVP
  }

  /// Get market usage summary for a user
  static Future<Map<String, dynamic>> getMarketUsageSummary(String userId) async {
    // Return default values - no limits for MVP
    return {
      'currentMonthCount': 0,
      'totalCount': 0,
      'limit': 999,
      'remaining': 999,
    };
  }

  /// Get user's market creation limit
  static Future<int> getUserLimit(String userId, String limitType) async {
    // Return unlimited - no limits for MVP
    return 999;
  }

  /// Check if user is within their limit
  static Future<bool> isWithinLimit(String userId, String limitType, int current) async {
    // Always return true - no limits for MVP
    return true;
  }

  /// Get remaining monthly markets for a user
  static Future<int> getRemainingMonthlyMarkets(String userId) async {
    // Return unlimited - no limits for MVP
    return 999;
  }
}
