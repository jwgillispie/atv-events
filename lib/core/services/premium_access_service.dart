import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/subscription/subscription_bloc.dart';
import '../../blocs/subscription/subscription_state.dart';
import '../../features/premium/models/user_subscription.dart';
import '../../features/premium/services/subscription_service.dart';
import '../services/error_handler_service.dart';

/// Centralized Premium Access Service for HiPop Markets
///
/// Single source of truth for premium subscription checking across the entire
/// application. Replaces 15+ scattered premium checking implementations with
/// a unified, cached, and performant solution that handles all user types.
///
/// This service provides:
/// - Unified premium status checking for vendors, organizers, and shoppers
/// - Feature-based access control with granular permissions
/// - Usage limit enforcement with real-time tracking
/// - Cached subscription status for optimal performance
/// - Automatic subscription expiration handling
/// - Seamless integration with the global SubscriptionBloc
class PremiumAccessService {
  // Prevent instantiation
  PremiumAccessService._();

  // Cache for subscription status to reduce Firestore reads
  static final Map<String, _CachedSubscription> _subscriptionCache = {};
  static const Duration _cacheExpiration = Duration(minutes: 5);

  // ======= Core Premium Check Methods =======

  /// Check if user has active premium subscription
  /// UPDATED: All users now have full access - no paywalls
  /// Premium features are free for everyone
  static Future<bool> hasPremiumAccess({
    required BuildContext context,
    required String userId,
    required String userType,
  }) async {
    // ALL USERS HAVE PREMIUM ACCESS - NO PAYWALLS
    return true;
  }

  /// Check if user has access to a specific feature
  /// UPDATED: All features are now free - no restrictions
  static Future<bool> hasFeatureAccess({
    required BuildContext context,
    required String userId,
    required String userType,
    required String featureName,
  }) async {
    // ALL FEATURES ARE FREE - NO PAYWALLS
    return true;
  }

  /// Require premium access with UI feedback
  /// UPDATED: Always returns true - no upgrade prompts
  static Future<bool> requirePremium({
    required BuildContext context,
    required String userId,
    required String userType,
    required String feature,
    bool showUpgradePrompt = true,
  }) async {
    // ALL USERS HAVE ACCESS - NO UPGRADE PROMPTS
    return true;
  }

  // ======= Usage Limit Methods =======

  /// Check if user has reached their usage limit for a feature
  /// UPDATED: No limits - everyone has unlimited access
  static Future<bool> isWithinUsageLimit({
    required String userId,
    required String userType,
    required String limitName,
    required int currentUsage,
  }) async {
    // NO USAGE LIMITS - UNLIMITED FOR EVERYONE
    return true;
  }

  /// Get remaining usage for a limit
  static Future<int> getRemainingUsage({
    required String userId,
    required String userType,
    required String limitName,
    required int currentUsage,
  }) async {
    try {
      final limits = await _getUsageLimits(userId, userType);
      final limit = limits[limitName] ?? _getDefaultLimit(limitName, userType);
      return (limit - currentUsage).clamp(0, limit);
    } catch (e) {
      debugPrint('[PremiumAccessService] Error getting remaining usage: $e');
      return 0;
    }
  }

  // ======= Subscription Details Methods =======

  /// Get detailed subscription information
  static Future<UserSubscription?> getSubscriptionDetails(String userId) async {
    try {
      // Check cache first
      final cached = _getCachedSubscription(userId);
      if (cached != null && !cached.isExpired && cached.subscription != null) {
        return cached.subscription;
      }

      // Fetch from service
      final subscription = await SubscriptionService.getUserSubscription(userId);
      if (subscription != null) {
        _cacheFullSubscription(userId, subscription);
      }
      return subscription;
    } catch (e) {
      debugPrint('[PremiumAccessService] Error getting subscription details: $e');
      return null;
    }
  }

  /// Get subscription tier name for display
  static Future<String> getSubscriptionTier({
    required String userId,
    required String userType,
  }) async {
    try {
      final subscription = await getSubscriptionDetails(userId);
      if (subscription == null || !subscription.isActive) {
        return 'Free';
      }

      // Map subscription IDs to display names
      return _getTierDisplayName(subscription.stripePriceId ?? '', userType);
    } catch (e) {
      return 'Free';
    }
  }

  /// Check if subscription is expiring soon (within 7 days)
  static Future<bool> isExpiringSoon(String userId) async {
    try {
      final subscription = await getSubscriptionDetails(userId);
      if (subscription == null || !subscription.isActive) {
        return false;
      }

      final endDate = subscription.subscriptionEndDate ?? subscription.nextPaymentDate;
      if (endDate == null) {
        return false;
      }

      final daysUntilExpiration = endDate
          .difference(DateTime.now())
          .inDays;

      return daysUntilExpiration <= 7 && daysUntilExpiration >= 0;
    } catch (e) {
      return false;
    }
  }

  // ======= User Type Specific Methods =======

  /// Check vendor-specific premium features
  static Future<bool> hasVendorPremiumFeature({
    required BuildContext context,
    required String userId,
    required VendorPremiumFeature feature,
  }) async {
    return hasFeatureAccess(
      context: context,
      userId: userId,
      userType: 'vendor',
      featureName: feature.name,
    );
  }

  /// Check organizer-specific premium features
  static Future<bool> hasOrganizerPremiumFeature({
    required BuildContext context,
    required String userId,
    required OrganizerPremiumFeature feature,
  }) async {
    return hasFeatureAccess(
      context: context,
      userId: userId,
      userType: 'market_organizer',
      featureName: feature.name,
    );
  }

  /// Check shopper-specific premium features
  static Future<bool> hasShopperPremiumFeature({
    required BuildContext context,
    required String userId,
    required ShopperPremiumFeature feature,
  }) async {
    return hasFeatureAccess(
      context: context,
      userId: userId,
      userType: 'shopper',
      featureName: feature.name,
    );
  }

  // ======= Cache Management =======

  /// Clear subscription cache for a user
  static void clearCache(String userId) {
    _subscriptionCache.remove(userId);
  }

  /// Clear entire subscription cache
  static void clearAllCache() {
    _subscriptionCache.clear();
  }

  // ======= Private Helper Methods =======

  static _CachedSubscription? _getCachedSubscription(String userId) {
    final cached = _subscriptionCache[userId];
    if (cached != null && !cached.isExpired) {
      return cached;
    }
    return null;
  }

  static void _cacheSubscriptionStatus(String userId, bool isPremium) {
    _subscriptionCache[userId] = _CachedSubscription(
      isPremium: isPremium,
      cachedAt: DateTime.now(),
    );
  }

  static void _cacheFullSubscription(String userId, UserSubscription subscription) {
    _subscriptionCache[userId] = _CachedSubscription(
      isPremium: subscription.isActive,
      subscription: subscription,
      cachedAt: DateTime.now(),
    );
  }

  static bool _isFeatureFree(String featureName, String userType) {
    // Define free tier features by user type
    // UPDATED: Most vendor-market relationship features are now FREE
    const freeFeatures = {
      'vendor': [
        'basic_profile',
        'market_discovery', // NOW FREE
        'basic_products',
        'basic_popups',
        'unlimited_popups', // NOW FREE - removed posting limits
        'unlimited_markets', // NOW FREE
        'market_applications', // NOW FREE
      ],
      'market_organizer': [
        'basic_market_management',
        'vendor_applications',
        'basic_messaging',
        'vendor_discovery', // NOW FREE
        'bulk_messaging', // NOW FREE
        'vendor_communication_suite', // NOW FREE
        'vendor_post_creation', // NOW FREE
        'unlimited_vendor_posts', // NOW FREE
      ],
      'shopper': [
        'browse_markets',
        'view_vendors',
        'basic_search',
        'favorites',
      ],
    };

    final userFeatures = freeFeatures[userType] ?? [];
    return userFeatures.contains(featureName);
  }

  static bool _hasFeaturePermission(String featureName, String userType) {
    // All premium features are available to premium users
    // Can add specific feature restrictions here if needed
    return true;
  }

  static Future<Map<String, int>> _getUsageLimits(String userId, String userType) async {
    try {
      final subscription = await getSubscriptionDetails(userId);
      if (subscription == null || !subscription.isActive) {
        return _getFreeTierLimits(userType);
      }
      return _getPremiumTierLimits(userType);
    } catch (e) {
      return _getFreeTierLimits(userType);
    }
  }

  static Map<String, int> _getFreeTierLimits(String userType) {
    switch (userType) {
      case 'vendor':
        return {
          'monthly_popups': 999, // NOW UNLIMITED for free tier
          'product_listings': 999, // NOW UNLIMITED for free tier
          'market_applications': 999, // NOW UNLIMITED for free tier
          'photo_uploads': 10, // Still limited
        };
      case 'market_organizer':
        return {
          'managed_markets': 10, // Increased for free tier
          'vendor_invites': 999, // NOW UNLIMITED for free tier
          'bulk_messages': 999, // NOW UNLIMITED for free tier
          'analytics_reports': 1, // Still limited - premium feature
        };
      case 'shopper':
        return {
          'saved_vendors': 20,
          'saved_markets': 10,
          'notifications': 5,
        };
      default:
        return {};
    }
  }

  static Map<String, int> _getPremiumTierLimits(String userType) {
    switch (userType) {
      case 'vendor':
        return {
          'monthly_popups': 999,
          'product_listings': 999,
          'market_applications': 999,
          'photo_uploads': 50,
        };
      case 'market_organizer':
        return {
          'managed_markets': 10,
          'vendor_invites': 999,
          'bulk_messages': 999,
          'analytics_reports': 999,
        };
      case 'shopper':
        return {
          'saved_vendors': 999,
          'saved_markets': 999,
          'notifications': 999,
        };
      default:
        return {};
    }
  }

  static int _getDefaultLimit(String limitName, String userType) {
    final limits = _getFreeTierLimits(userType);
    return limits[limitName] ?? 0;
  }

  static String _getTierDisplayName(String priceId, String userType) {
    // Map Stripe price IDs to display names
    final tierMappings = {
      'price_vendor_monthly': 'Vendor Premium',
      'price_vendor_yearly': 'Vendor Premium (Annual)',
      'price_organizer_monthly': 'Organizer Premium',
      'price_organizer_yearly': 'Organizer Premium (Annual)',
      'price_shopper_monthly': 'Shopper Plus',
      'price_shopper_yearly': 'Shopper Plus (Annual)',
    };

    return tierMappings[priceId] ?? 'Premium';
  }

  static void _navigateToUpgrade(BuildContext context, String userType) {
    // Navigate to appropriate upgrade screen based on user type
    Navigator.pushNamed(
      context,
      '/premium/upgrade',
      arguments: {'userType': userType},
    );
  }

  /// Validate if userType matches subscription userType
  /// Accounts for naming variations (market_organizer vs organizer)
  static bool _isUserTypeMatch(String requestedType, String subscriptionType) {
    // Normalize user types
    final normalizedRequested = _normalizeUserType(requestedType);
    final normalizedSubscription = _normalizeUserType(subscriptionType);

    return normalizedRequested == normalizedSubscription;
  }

  /// Normalize user type strings for comparison
  static String _normalizeUserType(String userType) {
    switch (userType.toLowerCase()) {
      case 'vendor':
        return 'vendor';
      case 'market_organizer':
      case 'organizer':
        return 'market_organizer';
      case 'shopper':
        return 'shopper';
      default:
        return userType.toLowerCase();
    }
  }
}

/// Premium feature enums for type safety
enum VendorPremiumFeature {
  // NOW FREE FEATURES (removed from premium)
  // unlimitedPopups - NOW FREE
  // multiMarketManagement - NOW FREE

  // STILL PREMIUM FEATURES (revenue/analytics only)
  advancedAnalytics('advanced_analytics'),
  salesTracking('sales_tracking'), // REMAINS PREMIUM
  revenueTracking('revenue_tracking'), // REMAINS PREMIUM
  customerInsights('customer_insights'),
  priorityPlacement('priority_placement'),
  customBranding('custom_branding'),
  bulkProductUpload('bulk_product_upload');

  final String name;
  const VendorPremiumFeature(this.name);
}

enum OrganizerPremiumFeature {
  // NOW FREE FEATURES (removed from premium)
  // vendorDiscovery - NOW FREE
  // bulkMessaging - NOW FREE
  // unlimitedVendors - NOW FREE

  // STILL PREMIUM FEATURES
  advancedAnalytics('advanced_analytics'),
  revenueTracking('revenue_tracking'), // REMAINS PREMIUM
  customApplicationForms('custom_application_forms'),
  eventPromotion('event_promotion'),
  vendorRatings('vendor_ratings');

  final String name;
  const OrganizerPremiumFeature(this.name);
}

enum ShopperPremiumFeature {
  priorityNotifications('priority_notifications'),
  advancedSearch('advanced_search'),
  exclusiveDeals('exclusive_deals'),
  vendorInsights('vendor_insights'),
  eventReminders('event_reminders'),
  customAlerts('custom_alerts');

  final String name;
  const ShopperPremiumFeature(this.name);
}

/// Cache wrapper for subscription data
class _CachedSubscription {
  final bool isPremium;
  final UserSubscription? subscription;
  final DateTime cachedAt;

  _CachedSubscription({
    required this.isPremium,
    this.subscription,
    required this.cachedAt,
  });

  bool get isExpired {
    return DateTime.now().difference(cachedAt) > PremiumAccessService._cacheExpiration;
  }
}