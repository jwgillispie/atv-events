import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Status of a vendor application
enum ApplicationStatus {
  pending, // Submitted, waiting for organizer review
  approved, // Organizer approved, waiting for vendor payment (24hr window)
  denied, // Organizer denied
  confirmed, // Vendor paid, spot secured
  expired, // Approval expired (24hr passed without payment)
}

/// Model representing a vendor's application to sell at a specific market
class VendorApplication extends Equatable {
  /// Unique application ID
  final String id;

  /// Vendor who applied
  final String vendorId;
  final String vendorName;
  final String? vendorPhotoUrl;

  /// Market applied to
  final String marketId;
  final String marketName;

  /// Organizer who reviews
  final String organizerId;

  // ============================================================================
  // APPLICATION CONTENT
  // ============================================================================

  /// Vendor's pitch/description (why they want to sell at this market)
  final String description;

  /// Product photos submitted with application
  final List<String> photoUrls;

  /// Responses to custom form fields (Phase 2)
  /// Key = field ID, Value = response
  final Map<String, dynamic>? customResponses;

  // ============================================================================
  // FEES & PAYMENT
  // ============================================================================

  /// Application fee (can be $0)
  final double applicationFee;

  /// Booth/spot fee
  final double boothFee;

  /// Total fee (application + booth)
  final double totalFee;

  /// Stripe payment intent ID (after payment)
  final String? stripePaymentIntentId;

  /// Stripe transfer ID (transfer to organizer)
  final String? stripeTransferId;

  /// Platform fee (10% of total)
  final double? platformFee;

  /// Amount organizer receives (90% of total)
  final double? organizerPayout;

  // ============================================================================
  // STATUS & TRACKING
  // ============================================================================

  /// Current application status
  final ApplicationStatus status;

  /// When vendor submitted application
  final DateTime appliedAt;

  /// When organizer reviewed (approved or denied)
  final DateTime? reviewedAt;

  /// Who reviewed (organizer user ID)
  final String? reviewedBy;

  /// When vendor paid (if approved)
  final DateTime? paidAt;

  /// When approval expires (reviewedAt + 24 hours for approved applications)
  final DateTime? approvalExpiresAt;

  /// When application expired (if payment window passed)
  final DateTime? expiredAt;

  // ============================================================================
  // COMMUNICATION
  // ============================================================================

  /// Organizer's note when denying (optional)
  final String? denialNote;

  /// Vendor's additional notes/questions (Phase 2)
  final String? vendorNotes;

  const VendorApplication({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    this.vendorPhotoUrl,
    required this.marketId,
    required this.marketName,
    required this.organizerId,
    required this.description,
    required this.photoUrls,
    this.customResponses,
    required this.applicationFee,
    required this.boothFee,
    required this.totalFee,
    this.stripePaymentIntentId,
    this.stripeTransferId,
    this.platformFee,
    this.organizerPayout,
    required this.status,
    required this.appliedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.paidAt,
    this.approvalExpiresAt,
    this.expiredAt,
    this.denialNote,
    this.vendorNotes,
  });

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Check if application is pending review
  bool get isPending => status == ApplicationStatus.pending;

  /// Check if application is approved (waiting for payment)
  bool get isApproved => status == ApplicationStatus.approved;

  /// Check if application is confirmed (paid)
  bool get isConfirmed => status == ApplicationStatus.confirmed;

  /// Check if application was denied
  bool get isDenied => status == ApplicationStatus.denied;

  /// Check if application expired
  bool get isExpired => status == ApplicationStatus.expired;

  /// Check if payment is required (approved but not paid)
  bool get requiresPayment => isApproved && paidAt == null;

  /// Get time remaining to pay (if approved)
  Duration? get timeRemainingToPay {
    if (!isApproved || approvalExpiresAt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(approvalExpiresAt!)) return Duration.zero;
    return approvalExpiresAt!.difference(now);
  }

  /// Check if payment window is expiring soon (< 2 hours)
  bool get isPaymentExpiringSoon {
    final remaining = timeRemainingToPay;
    if (remaining == null) return false;
    return remaining.inHours < 2;
  }

  /// Check if approval has expired
  bool get hasApprovalExpired {
    if (!isApproved || approvalExpiresAt == null) return false;
    return DateTime.now().isAfter(approvalExpiresAt!);
  }

  /// Getter for business name (alias for vendorName)
  String get vendorBusinessName => vendorName;

  /// Getter for display name (alias for vendorName)
  String get vendorDisplayName => vendorName;

  /// Getter for categories (backward compatibility)
  List<String> get vendorCategories => customResponses?['categories'] as List<String>? ?? [];

  // ============================================================================
  // FIRESTORE SERIALIZATION
  // ============================================================================

  /// Create from Firestore document
  factory VendorApplication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return VendorApplication(
      id: doc.id,
      vendorId: data['vendorId'] as String,
      vendorName: data['vendorName'] as String,
      vendorPhotoUrl: data['vendorPhotoUrl'] as String?,
      marketId: data['marketId'] as String,
      marketName: data['marketName'] as String,
      organizerId: data['organizerId'] as String,
      description: data['description'] as String,
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      customResponses: data['customResponses'] as Map<String, dynamic>?,
      applicationFee: (data['applicationFee'] as num).toDouble(),
      boothFee: (data['boothFee'] as num).toDouble(),
      totalFee: (data['totalFee'] as num).toDouble(),
      stripePaymentIntentId: data['stripePaymentIntentId'] as String?,
      stripeTransferId: data['stripeTransferId'] as String?,
      platformFee: (data['platformFee'] as num?)?.toDouble(),
      organizerPayout: (data['organizerPayout'] as num?)?.toDouble(),
      status: _statusFromString(data['status'] as String),
      appliedAt: (data['appliedAt'] as Timestamp).toDate(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'] as String?,
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      approvalExpiresAt: (data['approvalExpiresAt'] as Timestamp?)?.toDate(),
      expiredAt: (data['expiredAt'] as Timestamp?)?.toDate(),
      denialNote: data['denialNote'] as String?,
      vendorNotes: data['vendorNotes'] as String?,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'vendorName': vendorName,
      'vendorPhotoUrl': vendorPhotoUrl,
      'marketId': marketId,
      'marketName': marketName,
      'organizerId': organizerId,
      'description': description,
      'photoUrls': photoUrls,
      'customResponses': customResponses,
      'applicationFee': applicationFee,
      'boothFee': boothFee,
      'totalFee': totalFee,
      'stripePaymentIntentId': stripePaymentIntentId,
      'stripeTransferId': stripeTransferId,
      'platformFee': platformFee,
      'organizerPayout': organizerPayout,
      'status': _statusToString(status),
      'appliedAt': Timestamp.fromDate(appliedAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewedBy': reviewedBy,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'approvalExpiresAt':
          approvalExpiresAt != null ? Timestamp.fromDate(approvalExpiresAt!) : null,
      'expiredAt': expiredAt != null ? Timestamp.fromDate(expiredAt!) : null,
      'denialNote': denialNote,
      'vendorNotes': vendorNotes,
    };
  }

  /// Convert status enum to string
  static String _statusToString(ApplicationStatus status) {
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

  /// Convert string to status enum
  static ApplicationStatus _statusFromString(String status) {
    switch (status) {
      case 'pending':
        return ApplicationStatus.pending;
      case 'approved':
        return ApplicationStatus.approved;
      case 'denied':
        return ApplicationStatus.denied;
      case 'confirmed':
        return ApplicationStatus.confirmed;
      case 'expired':
        return ApplicationStatus.expired;
      default:
        return ApplicationStatus.pending;
    }
  }

  // ============================================================================
  // COPY WITH
  // ============================================================================

  VendorApplication copyWith({
    String? id,
    String? vendorId,
    String? vendorName,
    String? vendorPhotoUrl,
    String? marketId,
    String? marketName,
    String? organizerId,
    String? description,
    List<String>? photoUrls,
    Map<String, dynamic>? customResponses,
    double? applicationFee,
    double? boothFee,
    double? totalFee,
    String? stripePaymentIntentId,
    String? stripeTransferId,
    double? platformFee,
    double? organizerPayout,
    ApplicationStatus? status,
    DateTime? appliedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    DateTime? paidAt,
    DateTime? approvalExpiresAt,
    DateTime? expiredAt,
    String? denialNote,
    String? vendorNotes,
  }) {
    return VendorApplication(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      vendorPhotoUrl: vendorPhotoUrl ?? this.vendorPhotoUrl,
      marketId: marketId ?? this.marketId,
      marketName: marketName ?? this.marketName,
      organizerId: organizerId ?? this.organizerId,
      description: description ?? this.description,
      photoUrls: photoUrls ?? this.photoUrls,
      customResponses: customResponses ?? this.customResponses,
      applicationFee: applicationFee ?? this.applicationFee,
      boothFee: boothFee ?? this.boothFee,
      totalFee: totalFee ?? this.totalFee,
      stripePaymentIntentId: stripePaymentIntentId ?? this.stripePaymentIntentId,
      stripeTransferId: stripeTransferId ?? this.stripeTransferId,
      platformFee: platformFee ?? this.platformFee,
      organizerPayout: organizerPayout ?? this.organizerPayout,
      status: status ?? this.status,
      appliedAt: appliedAt ?? this.appliedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      paidAt: paidAt ?? this.paidAt,
      approvalExpiresAt: approvalExpiresAt ?? this.approvalExpiresAt,
      expiredAt: expiredAt ?? this.expiredAt,
      denialNote: denialNote ?? this.denialNote,
      vendorNotes: vendorNotes ?? this.vendorNotes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        vendorId,
        marketId,
        status,
        appliedAt,
        reviewedAt,
        paidAt,
      ];
}
