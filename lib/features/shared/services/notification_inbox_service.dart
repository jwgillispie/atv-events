import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_log.dart';

/// Service for managing notification inbox operations
/// Handles CRUD operations for notification logs and provides
/// real-time streams for notification updates
class NotificationInboxService {
  static final NotificationInboxService _instance = NotificationInboxService._internal();
  factory NotificationInboxService() => _instance;
  NotificationInboxService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get notifications stream for current user
  Stream<List<NotificationLog>> getNotificationsStream({
    bool unreadOnly = false,
    int limit = 50,
    String? filterType,
  }) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    Query query = _firestore
        .collection('notification_logs')
        .where('userId', isEqualTo: user.uid);

    if (unreadOnly) {
      query = query.where('read', isEqualTo: false);
    }

    if (filterType != null && filterType.isNotEmpty) {
      query = query.where('type', isEqualTo: filterType);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationLog.fromFirestore(doc))
            .toList());
  }

  /// Get unread notifications count
  Stream<int> getUnreadCount() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('notification_logs')
        .where('userId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notification_logs').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      rethrow;
    }
  }

  /// Mark multiple notifications as read
  Future<void> markMultipleAsRead(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;

    final batch = _firestore.batch();
    for (final id in notificationIds) {
      final docRef = _firestore.collection('notification_logs').doc(id);
      batch.update(docRef, {
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking multiple notifications as read: $e');
      rethrow;
    }
  }

  /// Mark all notifications as seen (viewed in inbox)
  Future<void> markAllAsSeen() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();
      final unseenNotifications = await _firestore
          .collection('notification_logs')
          .where('userId', isEqualTo: user.uid)
          .where('seen', isEqualTo: false)
          .limit(50)
          .get();

      for (final doc in unseenNotifications.docs) {
        batch.update(doc.reference, {
          'seen': true,
          'seenAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking notifications as seen: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();
      final unreadNotifications = await _firestore
          .collection('notification_logs')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .limit(100)
          .get();

      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
      rethrow;
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notification_logs').doc(notificationId).delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      rethrow;
    }
  }

  /// Delete multiple notifications
  Future<void> deleteMultipleNotifications(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;

    final batch = _firestore.batch();
    for (final id in notificationIds) {
      final docRef = _firestore.collection('notification_logs').doc(id);
      batch.delete(docRef);
    }

    try {
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting multiple notifications: $e');
      rethrow;
    }
  }

  /// Clear all read notifications
  Future<int> clearReadNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final batch = _firestore.batch();
      final readNotifications = await _firestore
          .collection('notification_logs')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: true)
          .get();

      for (final doc in readNotifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return readNotifications.docs.length;
    } catch (e) {
      debugPrint('Error clearing read notifications: $e');
      rethrow;
    }
  }

  /// Get notification by ID
  Future<NotificationLog?> getNotification(String notificationId) async {
    try {
      final doc = await _firestore
          .collection('notification_logs')
          .doc(notificationId)
          .get();

      if (!doc.exists) return null;
      return NotificationLog.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting notification: $e');
      return null;
    }
  }

  /// Get notifications by type
  Future<List<NotificationLog>> getNotificationsByType(
    String type, {
    int limit = 20,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('notification_logs')
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: type)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => NotificationLog.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting notifications by type: $e');
      return [];
    }
  }

  /// Get recent notifications (last 24 hours)
  Future<List<NotificationLog>> getRecentNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    try {
      final snapshot = await _firestore
          .collection('notification_logs')
          .where('userId', isEqualTo: user.uid)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(yesterday))
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => NotificationLog.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting recent notifications: $e');
      return [];
    }
  }

  /// Log notification opened (when user taps to navigate)
  Future<void> logNotificationOpened(String notificationId) async {
    try {
      await _firestore.collection('notification_logs').doc(notificationId).update({
        'opened': true,
        'openedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging notification opened: $e');
    }
  }

  /// Create a test notification (for debugging)
  Future<void> createTestNotification({
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('notification_logs').add({
        'userId': user.uid,
        'type': type,
        'title': title,
        'body': body,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'seen': false,
        'opened': false,
      });
    } catch (e) {
      debugPrint('Error creating test notification: $e');
      rethrow;
    }
  }

  /// Get notification statistics for user
  Future<Map<String, dynamic>> getNotificationStats() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final allNotifications = await _firestore
          .collection('notification_logs')
          .where('userId', isEqualTo: user.uid)
          .get();

      final unreadCount = allNotifications.docs
          .where((doc) => doc.data()['read'] == false)
          .length;

      final typeCount = <String, int>{};
      for (final doc in allNotifications.docs) {
        final type = doc.data()['type'] as String? ?? 'unknown';
        typeCount[type] = (typeCount[type] ?? 0) + 1;
      }

      return {
        'total': allNotifications.docs.length,
        'unread': unreadCount,
        'read': allNotifications.docs.length - unreadCount,
        'byType': typeCount,
      };
    } catch (e) {
      debugPrint('Error getting notification stats: $e');
      return {};
    }
  }
}