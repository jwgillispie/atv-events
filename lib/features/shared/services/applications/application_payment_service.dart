import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/vendor_application.dart';
import 'vendor_application_service.dart';

/// Service for handling Stripe Connect payments for vendor applications
/// Coordinates with Stripe payment intents and application confirmations
class ApplicationPaymentService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final VendorApplicationService _applicationService;

  ApplicationPaymentService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    VendorApplicationService? applicationService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _applicationService = applicationService ?? VendorApplicationService();

  // Platform fee percentage (10%)
  static const double platformFeePercentage = 0.10;

  /// Create a Stripe payment intent for an application
  /// This should be called from your existing payment checkout flow
  /// Returns metadata to pass to Stripe
  Future<Map<String, dynamic>> createApplicationPaymentMetadata({
    required String applicationId,
  }) async {
    final application = await _applicationService.getApplication(applicationId);
    if (application == null) {
      throw Exception('Application not found');
    }

    // Verify application is approved
    if (application.status != ApplicationStatus.approved) {
      throw Exception('Application must be approved before payment');
    }

    // Check if approval has expired
    if (application.hasApprovalExpired) {
      throw Exception('Approval has expired. Please reapply.');
    }

    // Get organizer's Stripe account ID
    final organizerDoc = await _firestore
        .collection('organizer_integrations')
        .doc(application.organizerId)
        .get();

    if (!organizerDoc.exists) {
      throw Exception('Organizer payment account not set up');
    }

    final stripeAccountId = organizerDoc.data()?['stripe']?['accountId'];
    if (stripeAccountId == null) {
      throw Exception('Organizer Stripe account not configured');
    }

    // Calculate fees
    final totalAmount = application.totalFee;
    final platformFee = calculatePlatformFee(totalAmount);
    final organizerPayout = calculateOrganizerPayout(totalAmount);

    // Return metadata for Stripe payment intent
    return {
      'type': 'vendor_application',
      'applicationId': applicationId,
      'vendorId': application.vendorId,
      'marketId': application.marketId,
      'organizerId': application.organizerId,
      'amount': totalAmount,
      'platformFee': platformFee,
      'organizerPayout': organizerPayout,
      'stripeAccountId': stripeAccountId,
      'applicationFee': application.applicationFee,
      'boothFee': application.boothFee,
    };
  }

  /// Calculate platform fee (10% of total)
  double calculatePlatformFee(double totalAmount) {
    return totalAmount * platformFeePercentage;
  }

  /// Calculate organizer payout (90% of total)
  double calculateOrganizerPayout(double totalAmount) {
    return totalAmount * (1 - platformFeePercentage);
  }

  /// Confirm application payment after Stripe webhook confirms success
  /// This is typically called by your Cloud Function webhook handler
  Future<void> confirmApplicationPayment({
    required String applicationId,
    required String paymentIntentId,
    String? transferId,
  }) async {
    final application = await _applicationService.getApplication(applicationId);
    if (application == null) {
      throw Exception('Application not found');
    }

    final platformFee = calculatePlatformFee(application.totalFee);
    final organizerPayout = calculateOrganizerPayout(application.totalFee);

    // Use the service method to update application and market
    await _applicationService.confirmApplicationPayment(
      applicationId: applicationId,
      paymentIntentId: paymentIntentId,
      transferId: transferId,
      platformFee: platformFee,
      organizerPayout: organizerPayout,
    );
  }

  /// Check if vendor can pay for an application (validation)
  Future<Map<String, dynamic>> validatePaymentEligibility({
    required String applicationId,
  }) async {
    final application = await _applicationService.getApplication(applicationId);

    if (application == null) {
      return {
        'canPay': false,
        'error': 'Application not found',
      };
    }

    // Check status
    if (application.status != ApplicationStatus.approved) {
      return {
        'canPay': false,
        'error': 'Application must be approved before payment',
        'currentStatus': application.status.toString(),
      };
    }

    // Check if already paid
    if (application.status == ApplicationStatus.confirmed) {
      return {
        'canPay': false,
        'error': 'Application already confirmed',
      };
    }

    // Check if expired
    if (application.hasApprovalExpired) {
      return {
        'canPay': false,
        'error': 'Approval expired. Payment window closed.',
        'expiredAt': application.approvalExpiresAt?.toIso8601String(),
      };
    }

    // Check if market is still available
    final marketDoc = await _firestore
        .collection('markets')
        .doc(application.marketId)
        .get();

    if (!marketDoc.exists) {
      return {
        'canPay': false,
        'error': 'Market not found',
      };
    }

    final marketData = marketDoc.data()!;
    final spotsAvailable = marketData['vendorSpotsAvailable'] as int? ?? 0;

    if (spotsAvailable <= 0) {
      return {
        'canPay': false,
        'error': 'Market is full. No spots available.',
      };
    }

    // Check organizer Stripe setup
    final organizerDoc = await _firestore
        .collection('organizer_integrations')
        .doc(application.organizerId)
        .get();

    final hasStripe = organizerDoc.exists &&
        organizerDoc.data()?['stripe']?['accountId'] != null;

    if (!hasStripe) {
      return {
        'canPay': false,
        'error': 'Organizer payment setup incomplete. Please contact organizer.',
        'requiresManualPayment': true,
      };
    }

    // All checks passed
    return {
      'canPay': true,
      'totalAmount': application.totalFee,
      'applicationFee': application.applicationFee,
      'boothFee': application.boothFee,
      'timeRemaining': application.timeRemainingToPay?.inHours ?? 0,
      'marketName': application.marketName,
      'spotsAvailable': spotsAvailable,
    };
  }

  /// Get payment summary for display before checkout
  Future<Map<String, dynamic>> getPaymentSummary({
    required String applicationId,
  }) async {
    final application = await _applicationService.getApplication(applicationId);
    if (application == null) {
      throw Exception('Application not found');
    }

    final platformFee = calculatePlatformFee(application.totalFee);
    final organizerPayout = calculateOrganizerPayout(application.totalFee);

    return {
      'applicationFee': application.applicationFee,
      'boothFee': application.boothFee,
      'subtotal': application.totalFee,
      'platformFee': platformFee,
      'organizerReceives': organizerPayout,
      'total': application.totalFee,
      'marketName': application.marketName,
      'vendorName': application.vendorName,
      'breakdown': {
        'Application Fee': '\$${application.applicationFee.toStringAsFixed(2)}',
        'Booth Fee': '\$${application.boothFee.toStringAsFixed(2)}',
        'Total': '\$${application.totalFee.toStringAsFixed(2)}',
      },
    };
  }

  /// Handle payment failure (for retry logic)
  Future<void> handlePaymentFailure({
    required String applicationId,
    required String errorMessage,
  }) async {
    // Log payment failure for tracking
    await _firestore.collection('payment_failures').add({
      'applicationId': applicationId,
      'type': 'vendor_application',
      'error': errorMessage,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': _auth.currentUser?.uid,
    });

    // Application stays in 'approved' status for retry
    // User can try again within 24-hour window
  }
}
