import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper service for managing Stripe-related notifications
/// Provides functionality for tracking unread payment notifications and verification status
class StripeNotificationHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Mark all Stripe payment notifications as read when vendor views orders
  static Future<void> markStripePaymentsAsRead(String vendorId) async {
    try {
      // Query all unread Stripe payment notifications for this vendor
      final batch = _firestore.batch();
      final notificationsSnapshot = await _firestore
          .collection('notification_logs')
          .where('userId', isEqualTo: vendorId)
          .where('type', isEqualTo: 'stripe_payment_received')
          .where('read', isEqualTo: false)
          .get();

      // Batch update all notifications to mark as read
      for (final doc in notificationsSnapshot.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error marking Stripe payments as read: $e');
    }
  }

  /// Get stream of unread Stripe notification count for badge display
  static Stream<int> getUnreadStripeNotificationCount(String vendorId) {
    return _firestore
        .collection('notification_logs')
        .where('userId', isEqualTo: vendorId)
        .where('read', isEqualTo: false)
        .where('type', whereIn: ['stripe_payment_received', 'stripe_verified'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark Stripe verification notification as read
  static Future<void> markVerificationNotificationAsRead(String vendorId) async {
    try {
      final batch = _firestore.batch();
      final notificationsSnapshot = await _firestore
          .collection('notification_logs')
          .where('userId', isEqualTo: vendorId)
          .where('type', isEqualTo: 'stripe_verified')
          .where('read', isEqualTo: false)
          .get();

      for (final doc in notificationsSnapshot.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error marking verification notification as read: $e');
    }
  }

  /// Mark all Stripe-related notifications as read
  static Future<void> markAllStripeNotificationsAsRead(String vendorId) async {
    try {
      final batch = _firestore.batch();
      final notificationsSnapshot = await _firestore
          .collection('notification_logs')
          .where('userId', isEqualTo: vendorId)
          .where('type', whereIn: ['stripe_payment_received', 'stripe_verified', 'stripe_transfer_completed'])
          .where('read', isEqualTo: false)
          .get();

      for (final doc in notificationsSnapshot.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error marking all Stripe notifications as read: $e');
    }
  }

  /// Get stream of unread payment notifications specifically
  static Stream<int> getUnreadPaymentNotificationCount(String vendorId) {
    return _firestore
        .collection('notification_logs')
        .where('userId', isEqualTo: vendorId)
        .where('type', isEqualTo: 'stripe_payment_received')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Check if vendor has been verified on Stripe
  static Future<bool> isVendorStripeVerified(String vendorId) async {
    try {
      final vendorDoc = await _firestore
          .collection('users')
          .doc(vendorId)
          .get();

      if (vendorDoc.exists) {
        final data = vendorDoc.data();
        return data?['stripeAccountStatus'] == 'active';
      }
      return false;
    } catch (e) {
      print('Error checking Stripe verification status: $e');
      return false;
    }
  }

  /// Create a notification log entry (used by backend functions)
  static Future<void> createNotificationLog({
    required String userId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('notification_logs').add({
        'userId': userId,
        'type': type,
        'title': title,
        'message': message,
        'metadata': metadata ?? {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating notification log: $e');
    }
  }
}