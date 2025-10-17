import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/vendor_application.dart';

/// Service for managing vendor applications to markets
/// Handles CRUD operations and status updates
class VendorApplicationService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  VendorApplicationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Collection reference
  CollectionReference get _applicationsCollection =>
      _firestore.collection('vendor_applications');

  // ============================================================================
  // VENDOR METHODS
  // ============================================================================

  /// Submit a new vendor application to a market
  Future<String> submitApplication({
    required String marketId,
    required String description,
    required List<String> photoUrls,
    Map<String, dynamic>? customResponses,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get market details
    final marketDoc = await _firestore.collection('markets').doc(marketId).get();
    if (!marketDoc.exists) throw Exception('Market not found');

    final marketData = marketDoc.data()!;
    final applicationFee = (marketData['applicationFee'] as num?)?.toDouble() ?? 0.0;
    final boothFee = (marketData['boothFee'] as num?)?.toDouble() ?? 0.0;

    // Get vendor details
    final userProfileDoc =
        await _firestore.collection('user_profiles').doc(user.uid).get();
    final userData = userProfileDoc.data() ?? {};

    // Create application
    final applicationData = {
      'vendorId': user.uid,
      'vendorName': userData['displayName'] ?? user.displayName ?? 'Unknown Vendor',
      'vendorPhotoUrl': userData['photoURL'] ?? user.photoURL,
      'marketId': marketId,
      'marketName': marketData['name'] ?? 'Unknown Market',
      'organizerId': marketData['organizerId'],
      'description': description,
      'photoUrls': photoUrls,
      'customResponses': customResponses,
      'applicationFee': applicationFee,
      'boothFee': boothFee,
      'totalFee': applicationFee + boothFee,
      'status': 'pending',
      'appliedAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _applicationsCollection.add(applicationData);

    // Update market's appliedVendorIds array
    await _firestore.collection('markets').doc(marketId).update({
      'appliedVendorIds': FieldValue.arrayUnion([user.uid]),
    });

    return docRef.id;
  }

  /// Get all applications for a specific vendor (real-time stream)
  Stream<List<VendorApplication>> getVendorApplications(String vendorId) {
    return _applicationsCollection
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VendorApplication.fromFirestore(doc))
            .toList());
  }

  /// Check if vendor has already applied to a market
  Future<VendorApplication?> getExistingApplication(
    String vendorId,
    String marketId,
  ) async {
    final querySnapshot = await _applicationsCollection
        .where('vendorId', isEqualTo: vendorId)
        .where('marketId', isEqualTo: marketId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;

    return VendorApplication.fromFirestore(querySnapshot.docs.first);
  }

  /// Get a single application by ID
  Future<VendorApplication?> getApplication(String applicationId) async {
    final doc = await _applicationsCollection.doc(applicationId).get();
    if (!doc.exists) return null;
    return VendorApplication.fromFirestore(doc);
  }

  // ============================================================================
  // ORGANIZER METHODS
  // ============================================================================

  /// Get all applications for a specific market (real-time stream)
  Stream<List<VendorApplication>> getMarketApplications(
    String marketId, {
    ApplicationStatus? filterStatus,
  }) {
    Query query = _applicationsCollection
        .where('marketId', isEqualTo: marketId)
        .orderBy('appliedAt', descending: true);

    if (filterStatus != null) {
      query = query.where('status', isEqualTo: _statusToString(filterStatus));
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => VendorApplication.fromFirestore(doc)).toList());
  }

  /// Approve a vendor application
  Future<void> approveApplication(String applicationId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Calculate approval expiration (24 hours from now)
    final approvalExpiresAt = DateTime.now().add(const Duration(hours: 24));

    await _applicationsCollection.doc(applicationId).update({
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': user.uid,
      'approvalExpiresAt': Timestamp.fromDate(approvalExpiresAt),
    });

    // Cloud Function will handle sending notification to vendor
  }

  /// Deny a vendor application with optional note
  Future<void> denyApplication(String applicationId, String? note) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final updateData = {
      'status': 'denied',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': user.uid,
    };

    if (note != null && note.isNotEmpty) {
      updateData['denialNote'] = note;
    }

    await _applicationsCollection.doc(applicationId).update(updateData);

    // Cloud Function will handle sending notification to vendor
  }

  // ============================================================================
  // PAYMENT METHODS
  // ============================================================================

  /// Confirm payment for an application (called after Stripe payment succeeds)
  Future<void> confirmApplicationPayment({
    required String applicationId,
    required String paymentIntentId,
    required String? transferId,
    required double platformFee,
    required double organizerPayout,
  }) async {
    // Get application to access marketId and vendorId
    final appDoc = await _applicationsCollection.doc(applicationId).get();
    if (!appDoc.exists) throw Exception('Application not found');

    final appData = appDoc.data() as Map<String, dynamic>;
    final marketId = appData['marketId'] as String;
    final vendorId = appData['vendorId'] as String;

    // Update application status
    await _applicationsCollection.doc(applicationId).update({
      'status': 'confirmed',
      'paidAt': FieldValue.serverTimestamp(),
      'stripePaymentIntentId': paymentIntentId,
      'stripeTransferId': transferId,
      'platformFee': platformFee,
      'organizerPayout': organizerPayout,
    });

    // Update market: add to confirmedVendorIds, decrement available spots
    await _firestore.collection('markets').doc(marketId).update({
      'confirmedVendorIds': FieldValue.arrayUnion([vendorId]),
      'vendorSpotsAvailable': FieldValue.increment(-1),
    });

    // Cloud Function will handle sending confirmation notifications
  }

  // ============================================================================
  // SYSTEM METHODS (Called by Cloud Functions)
  // ============================================================================

  /// Expire an application (called by Cloud Function after 24hr)
  Future<void> expireApplication(String applicationId) async {
    // Get application to verify it exists
    final appDoc = await _applicationsCollection.doc(applicationId).get();
    if (!appDoc.exists) return;

    // Update application status
    await _applicationsCollection.doc(applicationId).update({
      'status': 'expired',
      'expiredAt': FieldValue.serverTimestamp(),
    });

    // Don't need to update market spots since they were never decremented
    // (only confirmed applications decrement spots)

    // Cloud Function will handle sending expiration notifications
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Convert status enum to string
  String _statusToString(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.pending:
        return 'pending';
      case ApplicationStatus.approved:
        return 'approved';
      case ApplicationStatus.denied:
        return 'denied';
      case ApplicationStatus.confirmed:
        return 'confirmed';
      case ApplicationStatus.expired:
        return 'expired';
    }
  }

  /// Get application statistics for a market
  Future<Map<String, int>> getMarketApplicationStats(String marketId) async {
    final snapshot = await _applicationsCollection
        .where('marketId', isEqualTo: marketId)
        .get();

    int pending = 0;
    int approved = 0;
    int confirmed = 0;
    int denied = 0;
    int expired = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final status = data['status'] as String?;
      if (status == null) continue;

      switch (status) {
        case 'pending':
          pending++;
          break;
        case 'approved':
          approved++;
          break;
        case 'confirmed':
          confirmed++;
          break;
        case 'denied':
          denied++;
          break;
        case 'expired':
          expired++;
          break;
      }
    }

    return {
      'pending': pending,
      'approved': approved,
      'confirmed': confirmed,
      'denied': denied,
      'expired': expired,
      'total': snapshot.docs.length,
    };
  }

  /// Get application statistics for a vendor
  Future<Map<String, int>> getVendorApplicationStats(String vendorId) async {
    final snapshot = await _applicationsCollection
        .where('vendorId', isEqualTo: vendorId)
        .get();

    int pending = 0;
    int approved = 0;
    int confirmed = 0;
    int denied = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final status = data['status'] as String?;
      if (status == null) continue;

      switch (status) {
        case 'pending':
          pending++;
          break;
        case 'approved':
          approved++;
          break;
        case 'confirmed':
          confirmed++;
          break;
        case 'denied':
          denied++;
          break;
      }
    }

    return {
      'pending': pending,
      'approved': approved,
      'confirmed': confirmed,
      'denied': denied,
      'total': snapshot.docs.length,
    };
  }
}
