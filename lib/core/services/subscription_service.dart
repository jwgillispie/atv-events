/// Subscription Service - Stub Implementation
/// This is a placeholder service for subscription management
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore;

  SubscriptionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Check if user has a specific feature
  static Future<bool> hasFeature(String userId, String featureId) async {
    // Stub implementation - returns false
    return false;
  }

  /// Get user subscription
  static Future<Map<String, dynamic>?> getUserSubscription(String userId) async {
    // Stub implementation - returns null
    return null;
  }

  /// Check if user can create a market
  static Future<bool> canCreateMarket(String userId) async {
    // Stub implementation - returns true to allow market creation
    return true;
  }

  /// Increment market count for user
  static Future<void> incrementMarketCount(String userId) async {
    // Stub implementation - does nothing
  }

  /// Check if user has active subscription
  Future<bool> hasActiveSubscription(String userId) async {
    // Stub implementation - returns false
    return false;
  }

  /// Get subscription tier
  Future<String> getSubscriptionTier(String userId) async {
    // Stub implementation - returns free tier
    return 'free';
  }

  /// Get market usage summary
  Future<Map<String, dynamic>> getMarketUsageSummary(String userId) async {
    // Stub implementation - returns empty usage
    return {
      'marketsCreated': 0,
      'marketsLimit': 999,
      'canCreateMore': true,
    };
  }

  /// Get remaining monthly markets
  Future<int> getRemainingMonthlyMarkets(String userId) async {
    // Stub implementation - returns unlimited
    return 999;
  }

  /// Check if within limit
  Future<bool> isWithinLimit(String userId, String limitType) async {
    // Stub implementation - always within limit
    return true;
  }

  /// Get user limit
  Future<int> getUserLimit(String userId, String limitType) async {
    // Stub implementation - returns unlimited
    return 999;
  }
}
