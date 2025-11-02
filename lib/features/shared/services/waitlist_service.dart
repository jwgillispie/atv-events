import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/waitlist_models.dart';

/// Service for managing product waitlists in ATV shop
class WaitlistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Join a product waitlist
  Future<WaitlistEntry> joinWaitlist({
    required String productId,
    required String productName,
    String? productImageUrl,
    required String sellerId,
    required String sellerName,
    int quantityRequested = 1,
    NotificationPreference notificationPreference = NotificationPreference.push,
    String? deviceToken,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    debugPrint('🟡 [WaitlistService] Joining waitlist for product: $productId');

    // Get user profile for name
    final userProfile = await _firestore
        .collection('user_profiles')
        .doc(user.uid)
        .get();

    final userName = userProfile.data()?['displayName'] ?? 'Unknown';
    final userEmail = user.email ?? '';
    final userPhone = userProfile.data()?['phone'];

    // Get or create product waitlist
    final waitlistRef = _firestore
        .collection('product_waitlists')
        .doc(productId);

    final waitlistDoc = await waitlistRef.get();

    int nextPosition = 1;
    if (waitlistDoc.exists) {
      nextPosition = (waitlistDoc.data()?['nextPosition'] ?? 1) as int;
    } else {
      // Create new waitlist
      await waitlistRef.set({
        'sellerId': sellerId,
        'vendorId': sellerId,  // DB compatibility
        'totalWaiting': 0,
        'nextPosition': 1,
        'conversions': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Create waitlist entry
    final entry = WaitlistEntry(
      id: '', // Will be set by Firestore
      productId: productId,
      productName: productName,
      productImageUrl: productImageUrl,
      sellerId: sellerId,
      sellerName: sellerName,
      shopperId: user.uid,
      shopperEmail: userEmail,
      shopperPhone: userPhone,
      shopperName: userName,
      position: nextPosition,
      quantityRequested: quantityRequested,
      notificationPreference: notificationPreference,
      joinedAt: DateTime.now(),
      deviceToken: deviceToken,
      timezone: DateTime.now().timeZoneName,
    );

    // Add entry to subcollection
    final entryRef = await waitlistRef
        .collection('entries')
        .add(entry.toFirestore());

    // Update waitlist summary
    await waitlistRef.update({
      'totalWaiting': FieldValue.increment(1),
      'nextPosition': nextPosition + 1,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Add to user's waitlist tracking
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('waitlists')
        .doc(entryRef.id)
        .set({
      'productId': productId,
      'productName': productName,
      'productImageUrl': productImageUrl,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'position': nextPosition,
      'status': 'waiting',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ [WaitlistService] Joined waitlist at position $nextPosition');

    return entry.copyWith(id: entryRef.id);
  }

  /// Leave a waitlist
  Future<void> leaveWaitlist({
    required String productId,
    required String entryId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    debugPrint('🟡 [WaitlistService] Leaving waitlist: $entryId');

    final batch = _firestore.batch();

    // Delete entry
    final entryRef = _firestore
        .collection('product_waitlists')
        .doc(productId)
        .collection('entries')
        .doc(entryId);

    batch.delete(entryRef);

    // Update waitlist summary
    final waitlistRef = _firestore
        .collection('product_waitlists')
        .doc(productId);

    batch.update(waitlistRef, {
      'totalWaiting': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Remove from user's tracking
    final userWaitlistRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('waitlists')
        .doc(entryId);

    batch.delete(userWaitlistRef);

    await batch.commit();

    debugPrint('✅ [WaitlistService] Left waitlist successfully');
  }

  /// Get waitlist count for a product
  Future<int> getWaitlistCount(String productId) async {
    try {
      final waitlistDoc = await _firestore
          .collection('product_waitlists')
          .doc(productId)
          .get();

      if (!waitlistDoc.exists) return 0;

      return (waitlistDoc.data()?['totalWaiting'] ?? 0) as int;
    } catch (e) {
      debugPrint('❌ [WaitlistService] Error getting waitlist count: $e');
      return 0;
    }
  }

  /// Check if user is on waitlist for a product
  Future<WaitlistEntry?> getUserWaitlistEntry(String productId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final entriesSnapshot = await _firestore
          .collection('product_waitlists')
          .doc(productId)
          .collection('entries')
          .where('shopperId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'waiting')
          .limit(1)
          .get();

      if (entriesSnapshot.docs.isEmpty) return null;

      return WaitlistEntry.fromFirestore(entriesSnapshot.docs.first);
    } catch (e) {
      debugPrint('❌ [WaitlistService] Error checking user waitlist: $e');
      return null;
    }
  }

  /// Get all waitlist entries for a product (seller view)
  Stream<List<WaitlistEntry>> getProductWaitlistEntries(String productId) {
    return _firestore
        .collection('product_waitlists')
        .doc(productId)
        .collection('entries')
        .where('status', isEqualTo: 'waiting')
        .orderBy('position')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WaitlistEntry.fromFirestore(doc))
            .toList());
  }

  /// Get all user's waitlist entries
  Stream<List<WaitlistEntry>> getUserWaitlistEntries() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collectionGroup('entries')
        .where('shopperId', isEqualTo: user.uid)
        .where('status', whereIn: ['waiting', 'notified'])
        .orderBy('joinedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WaitlistEntry.fromFirestore(doc))
            .toList());
  }

  /// Manually release inventory to waitlist (seller action)
  Future<void> manualReleaseToWaitlist({
    required String productId,
    required int quantity,
  }) async {
    debugPrint('🟡 [WaitlistService] Manually releasing $quantity units to waitlist');

    // Get first N entries in waitlist
    final entriesSnapshot = await _firestore
        .collection('product_waitlists')
        .doc(productId)
        .collection('entries')
        .where('status', isEqualTo: 'waiting')
        .orderBy('position')
        .limit(quantity)
        .get();

    if (entriesSnapshot.docs.isEmpty) {
      debugPrint('⚠️ [WaitlistService] No waitlist entries to release to');
      return;
    }

    final batch = _firestore.batch();

    for (final entryDoc in entriesSnapshot.docs) {
      final entry = WaitlistEntry.fromFirestore(entryDoc);

      // Update entry status to notified
      batch.update(entryDoc.reference, {
        'status': 'notified',
        'notifiedAt': FieldValue.serverTimestamp(),
        'claimExpiresAt': Timestamp.fromDate(
          DateTime.now().add(Duration(hours: 24)),
        ),
      });

      // Update user's waitlist tracking
      batch.update(
        _firestore
            .collection('users')
            .doc(entry.shopperId)
            .collection('waitlists')
            .doc(entryDoc.id),
        {
          'status': 'notified',
        },
      );

      // TODO: Send push notification to shopper
      debugPrint('✅ [WaitlistService] Notified ${entry.shopperName} (position ${entry.position})');
    }

    // Update waitlist summary
    batch.update(
      _firestore.collection('product_waitlists').doc(productId),
      {
        'totalWaiting': FieldValue.increment(-entriesSnapshot.docs.length),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();

    debugPrint('✅ [WaitlistService] Released $quantity units to waitlist');
  }

  /// Get waitlist statistics for a seller
  Future<Map<String, dynamic>> getSellerWaitlistStats(String sellerId) async {
    try {
      final waitlistsSnapshot = await _firestore
          .collection('product_waitlists')
          .where('sellerId', isEqualTo: sellerId)
          .get();

      int totalWaiting = 0;
      int totalConversions = 0;
      int productsWithWaitlist = 0;

      for (final doc in waitlistsSnapshot.docs) {
        final data = doc.data();
        final waiting = (data['totalWaiting'] ?? 0) as int;
        if (waiting > 0) productsWithWaitlist++;
        totalWaiting += waiting;
        totalConversions += (data['conversions'] ?? 0) as int;
      }

      return {
        'totalWaiting': totalWaiting,
        'totalConversions': totalConversions,
        'productsWithWaitlist': productsWithWaitlist,
        'conversionRate': totalConversions > 0
            ? (totalConversions / (totalConversions + totalWaiting)) * 100
            : 0.0,
      };
    } catch (e) {
      debugPrint('❌ [WaitlistService] Error getting stats: $e');
      return {
        'totalWaiting': 0,
        'totalConversions': 0,
        'productsWithWaitlist': 0,
        'conversionRate': 0.0,
      };
    }
  }
}
