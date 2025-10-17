import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:atv_events/features/premium/services/subscription_service.dart';

/// Types of notifications for shoppers
enum NotificationType {
  vendorNewPopup,
  vendorLocationUpdate,
  recommendedVendor,
  marketUpdate,
  specialOffer,
  weeklyDigest,
}

/// Enhanced notification service for premium shoppers
/// Provides push notifications when followed vendors post new pop-ups
class ShopperNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _notificationsCollection = 
      _firestore.collection('shopper_notifications');
  static final CollectionReference _notificationSettingsCollection = 
      _firestore.collection('notification_settings');

  /// Create a notification for a vendor's new pop-up
  static Future<void> createVendorPopupNotification({
    required String vendorId,
    required String vendorName,
    required String postId,
    required String location,
    required DateTime popupDateTime,
    String? description,
  }) async {
    try {
      // Find all premium shoppers following this vendor
      final followsSnapshot = await _firestore
          .collection('vendor_follows')
          .where('vendorId', isEqualTo: vendorId)
          .where('isActive', isEqualTo: true)
          .get();

      final followerIds = followsSnapshot.docs
          .map((doc) => doc.data()['shopperId'] as String)
          .toList();

      if (followerIds.isEmpty) return;

      // Check which followers are premium users
      final batch = _firestore.batch();
      final timestamp = FieldValue.serverTimestamp();

      for (final shopperId in followerIds) {
        // Check if user has premium notification features
        final hasFeature = await SubscriptionService.hasFeature(
          shopperId,
          'vendor_following_system',
        );

        if (hasFeature) {
          // Check user's notification preferences
          final notificationSettings = await getNotificationSettings(shopperId);
          if (!(notificationSettings['vendorNewPopup'] ?? false)) continue;

          final notificationDoc = _notificationsCollection.doc();
          batch.set(notificationDoc, {
            'shopperId': shopperId,
            'type': NotificationType.vendorNewPopup.name,
            'title': '$vendorName has a new pop-up!',
            'body': 'Check out their latest location at $location',
            'data': {
              'vendorId': vendorId,
              'vendorName': vendorName,
              'postId': postId,
              'location': location,
              'popupDateTime': Timestamp.fromDate(popupDateTime),
              'description': description,
            },
            'isRead': false,
            'isDelivered': false,
            'createdAt': timestamp,
            'scheduledFor': timestamp, // Send immediately
          });
        }
      }

      await batch.commit();
    } catch (e) {
    }
  }

  /// Create personalized recommendation notification
  static Future<void> createRecommendationNotification({
    required String shopperId,
    required List<Map<String, dynamic>> recommendedVendors,
  }) async {
    try {
      final hasFeature = await SubscriptionService.hasFeature(
        shopperId,
        'personalized_discovery',
      );

      if (!hasFeature) return;

      final notificationSettings = await getNotificationSettings(shopperId);
      if (!(notificationSettings['recommendedVendor'] ?? false)) return;

      final vendorNames = recommendedVendors
          .map((v) => v['businessName'] as String)
          .take(3)
          .join(', ');

      await _notificationsCollection.add({
        'shopperId': shopperId,
        'type': NotificationType.recommendedVendor.name,
        'title': 'New vendors you might love!',
        'body': 'Check out $vendorNames and ${recommendedVendors.length > 3 ? '${recommendedVendors.length - 3} others' : 'more'}',
        'data': {
          'recommendedVendors': recommendedVendors,
          'generatedAt': FieldValue.serverTimestamp(),
        },
        'isRead': false,
        'isDelivered': false,
        'createdAt': FieldValue.serverTimestamp(),
        'scheduledFor': FieldValue.serverTimestamp(),
      });

    } catch (e) {
    }
  }

  /// Create weekly digest notification for premium shoppers
  static Future<void> createWeeklyDigest(String shopperId) async {
    try {
      final hasFeature = await SubscriptionService.hasFeature(
        shopperId,
        'vendor_following_system',
      );

      if (!hasFeature) return;

      final notificationSettings = await getNotificationSettings(shopperId);
      if (!(notificationSettings['weeklyDigest'] ?? false)) return;

      // Get followed vendors activity for the week
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
      final followedVendors = await _getFollowedVendorsActivity(shopperId, oneWeekAgo);

      if (followedVendors.isEmpty) return;

      final activeVendorsCount = followedVendors.length;
      await _notificationsCollection.add({
        'shopperId': shopperId,
        'type': NotificationType.weeklyDigest.name,
        'title': 'Your weekly vendor digest',
        'body': '$activeVendorsCount vendors you follow were active this week',
        'data': {
          'followedVendorsActivity': followedVendors,
          'weekStartDate': Timestamp.fromDate(oneWeekAgo),
          'weekEndDate': FieldValue.serverTimestamp(),
        },
        'isRead': false,
        'isDelivered': false,
        'createdAt': FieldValue.serverTimestamp(),
        'scheduledFor': FieldValue.serverTimestamp(),
      });

    } catch (e) {
    }
  }

  /// Get notification settings for a shopper
  static Future<Map<String, bool>> getNotificationSettings(String shopperId) async {
    try {
      final doc = await _notificationSettingsCollection.doc(shopperId).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'vendorNewPopup': data['vendorNewPopup'] ?? true,
          'vendorLocationUpdate': data['vendorLocationUpdate'] ?? true,
          'recommendedVendor': data['recommendedVendor'] ?? true,
          'marketUpdate': data['marketUpdate'] ?? false,
          'specialOffer': data['specialOffer'] ?? true,
          'weeklyDigest': data['weeklyDigest'] ?? true,
        };
      }
      
      // Default settings for new users
      return {
        'vendorNewPopup': true,
        'vendorLocationUpdate': true,
        'recommendedVendor': true,
        'marketUpdate': false,
        'specialOffer': true,
        'weeklyDigest': true,
      };
    } catch (e) {
      return {
        'vendorNewPopup': false,
        'vendorLocationUpdate': false,
        'recommendedVendor': false,
        'marketUpdate': false,
        'specialOffer': false,
        'weeklyDigest': false,
      };
    }
  }

  /// Update notification settings for a shopper
  static Future<void> updateNotificationSettings(
    String shopperId,
    Map<String, bool> settings,
  ) async {
    try {
      await _notificationSettingsCollection.doc(shopperId).set({
        ...settings,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
      throw Exception('Failed to update notification settings: $e');
    }
  }

  /// Get unread notifications for a shopper
  static Future<List<Map<String, dynamic>>> getUnreadNotifications(String shopperId) async {
    try {
      final snapshot = await _notificationsCollection
          .where('shopperId', isEqualTo: shopperId)
          .where('isRead', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
    }
  }

  /// Mark all notifications as read for a shopper
  static Future<void> markAllNotificationsAsRead(String shopperId) async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _notificationsCollection
          .where('shopperId', isEqualTo: shopperId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
    }
  }

  /// Stream notifications for real-time updates
  static Stream<List<Map<String, dynamic>>> streamNotifications(String shopperId) {
    return _notificationsCollection
        .where('shopperId', isEqualTo: shopperId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              ...data,
            };
          }).toList();
        });
  }

  /// Get followed vendors activity for time period
  static Future<List<Map<String, dynamic>>> _getFollowedVendorsActivity(
    String shopperId,
    DateTime since,
  ) async {
    try {
      // Get followed vendor IDs
      final followsSnapshot = await _firestore
          .collection('vendor_follows')
          .where('shopperId', isEqualTo: shopperId)
          .where('isActive', isEqualTo: true)
          .get();

      final vendorIds = followsSnapshot.docs
          .map((doc) => doc.data()['vendorId'] as String)
          .toList();

      if (vendorIds.isEmpty) return [];

      // Get vendor posts since the date
      final postsSnapshot = await _firestore
          .collection('vendor_posts')
          .where('vendorId', whereIn: vendorIds.take(10).toList()) // Firestore limit
          .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
          .where('isActive', isEqualTo: true)
          .get();

      final vendorActivity = <String, Map<String, dynamic>>{};

      for (final doc in postsSnapshot.docs) {
        final data = doc.data();
        final vendorId = data['vendorId'] as String;
        
        if (!vendorActivity.containsKey(vendorId)) {
          vendorActivity[vendorId] = {
            'vendorId': vendorId,
            'vendorName': data['vendorName'],
            'postCount': 0,
            'locations': <String>{},
            'latestPostDate': null,
          };
        }

        vendorActivity[vendorId]!['postCount'] = 
            (vendorActivity[vendorId]!['postCount'] as int) + 1;
        
        (vendorActivity[vendorId]!['locations'] as Set<String>)
            .add(data['location'] ?? 'Unknown');
        
        final postDate = (data['createdAt'] as Timestamp).toDate();
        final currentLatest = vendorActivity[vendorId]!['latestPostDate'] as DateTime?;
        if (currentLatest == null || postDate.isAfter(currentLatest)) {
          vendorActivity[vendorId]!['latestPostDate'] = postDate;
        }
      }

      return vendorActivity.values.toList();
    } catch (e) {
      return [];
    }
  }

  /// Clean up old notifications (run periodically)
  static Future<void> cleanupOldNotifications() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final snapshot = await _notificationsCollection
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
    }
  }

  /// Get notification statistics for analytics
  static Future<Map<String, dynamic>> getNotificationStats(String shopperId) async {
    try {
      final snapshot = await _notificationsCollection
          .where('shopperId', isEqualTo: shopperId)
          .get();

      final notifications = snapshot.docs.map((doc) => doc.data()).toList();
      final stats = {
        'total': notifications.length,
        'unread': notifications.where((n) => (n as Map<String, dynamic>)['isRead'] == false).length,
        'byType': <String, int>{},
        'thisWeek': 0,
        'thisMonth': 0,
      };

      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final monthAgo = now.subtract(const Duration(days: 30));

      for (final notification in notifications) {
        final notificationMap = notification as Map<String, dynamic>;
        // Count by type
        final type = notificationMap['type'] as String;
        final byType = stats['byType'] as Map<String, int>;
        byType[type] = (byType[type] ?? 0) + 1;

        // Count by time period
        final createdAt = (notificationMap['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null) continue;
        if (createdAt.isAfter(weekAgo)) {
          stats['thisWeek'] = (stats['thisWeek'] as int) + 1;
        }
        if (createdAt.isAfter(monthAgo)) {
          stats['thisMonth'] = (stats['thisMonth'] as int) + 1;
        }
      }

      return stats;
    } catch (e) {
      return {
        'total': 0,
        'unread': 0,
        'byType': <String, int>{},
        'thisWeek': 0,
        'thisMonth': 0,
      };
    }
  }
}