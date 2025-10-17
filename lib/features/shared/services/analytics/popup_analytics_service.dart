import 'package:flutter/foundation.dart';
import 'real_time_analytics_service.dart';

/// Handles all analytics tracking for popup creation
/// Centralizes tracking logic that was scattered in the create_popup_screen
class PopupAnalyticsService {
  static final PopupAnalyticsService _instance = PopupAnalyticsService._internal();
  factory PopupAnalyticsService() => _instance;
  PopupAnalyticsService._internal();

  /// Track when user starts creating a popup
  Future<void> trackPostCreationStart({
    required String userId,
    required String userType,
    bool isEdit = false,
    String? source,
  }) async {
    try {
      await RealTimeAnalyticsService.trackEvent('post_creation_started', {
        'userId': userId,
        'userType': userType,
        'isEdit': isEdit,
        'source': source ?? 'unknown',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Track popup type selection
  Future<void> trackPostTypeSelection({
    required String userId,
    required String? postType,
  }) async {
    if (postType == null) return;

    try {
      await RealTimeAnalyticsService.trackEvent('post_type_selected', {
        'userId': userId,
        'postType': postType,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Track successful post creation
  Future<void> trackPostCreationSuccess({
    required String userId,
    required String userType,
    required String postId,
    required String postType,
    required bool hasPhotos,
    required bool hasProductLists,
    required int remainingPosts,
    required Duration completionTime,
  }) async {
    try {
      await RealTimeAnalyticsService.trackEvent('post_creation_completed', {
        'userId': userId,
        'userType': userType,
        'postId': postId,
        'postType': postType,
        'hasPhotos': hasPhotos,
        'hasProductLists': hasProductLists,
        'remainingPosts': remainingPosts,
        'completionTimeSeconds': completionTime.inSeconds,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Track when user encounters monthly limit
  Future<void> trackMonthlyLimitEncounter({
    required String userId,
    required String userType,
    required int currentCount,
    required int monthlyLimit,
  }) async {
    try {
      await RealTimeAnalyticsService.trackEvent('monthly_limit_reached', {
        'userId': userId,
        'userType': userType,
        'currentCount': currentCount,
        'monthlyLimit': monthlyLimit,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Track upgrade dialog viewed from limit
  Future<void> trackUpgradeDialogViewed({
    required String userId,
    required String userType,
    required String source,
    required int remainingPosts,
  }) async {
    try {
      await RealTimeAnalyticsService.trackEvent('upgrade_dialog_viewed', {
        'userId': userId,
        'userType': userType,
        'source': source,
        'remainingPosts': remainingPosts,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Track upgrade button click from limit dialog
  Future<void> trackUpgradeFromLimitDialog({
    required String userId,
    required String userType,
    required String clickSource,
    required int remainingPosts,
  }) async {
    try {
      await RealTimeAnalyticsService.trackEvent('upgrade_clicked', {
        'userId': userId,
        'userType': userType,
        'clickSource': clickSource,
        'remainingPosts': remainingPosts,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Track post creation abandonment
  Future<void> trackPostCreationAbandonment({
    required String userId,
    required String userType,
    required String screenContext,
    required bool hasPhotos,
    required bool hasProductLists,
    required int remainingPosts,
    required bool canCreatePost,
    required bool isNearLimit,
  }) async {
    try {
      await RealTimeAnalyticsService.trackEvent('post_creation_abandoned', {
        'userId': userId,
        'userType': userType,
        'screenContext': screenContext,
        'hasPhotos': hasPhotos,
        'hasProductLists': hasProductLists,
        'remainingPosts': remainingPosts,
        'canCreatePost': canCreatePost,
        'isNearLimit': isNearLimit,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Track form field interactions
  Future<void> trackFormFieldInteraction({
    required String userId,
    required String fieldName,
    required bool hasValue,
    required String postType,
    required int remainingPosts,
  }) async {
    try {
      await RealTimeAnalyticsService.trackEvent('form_field_interaction', {
        'userId': userId,
        'fieldName': fieldName,
        'hasValue': hasValue,
        'postType': postType,
        'remainingPosts': remainingPosts,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Track market selection
  Future<void> trackMarketSelection({
    required String userId,
    required String? marketId,
    required String? marketName,
  }) async {
    try {
      await RealTimeAnalyticsService.trackEvent('market_selected', {
        'userId': userId,
        'marketId': marketId ?? 'none',
        'marketName': marketName ?? 'independent',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Track date/time selection
  Future<void> trackDateTimeSelection({
    required String userId,
    required DateTime? dateTime,
    required String type,
  }) async {
    try {
      await RealTimeAnalyticsService.trackEvent('datetime_selected', {
        'userId': userId,
        'type': type,
        'hasDateTime': dateTime != null,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Track photo upload interactions
  Future<void> trackPhotoUploadInteraction({
    required String userId,
    required int photoCount,
    required String action,
  }) async {
    try {
      await RealTimeAnalyticsService.trackEvent('photo_interaction', {
        'userId': userId,
        'photoCount': photoCount,
        'action': action, // 'add', 'remove', 'view'
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }
}