import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Waitlist entry status
enum WaitlistStatus {
  waiting('waiting'),
  notified('notified'),
  claimed('claimed'),
  expired('expired'),
  cancelled('cancelled');

  final String value;
  const WaitlistStatus(this.value);

  static WaitlistStatus fromString(String value) {
    return WaitlistStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => WaitlistStatus.waiting,
    );
  }
}

/// Notification preference for waitlist
enum NotificationPreference {
  push('push'),
  email('email'),
  sms('sms');

  final String value;
  const NotificationPreference(this.value);

  static NotificationPreference fromString(String value) {
    return NotificationPreference.values.firstWhere(
      (pref) => pref.value == value,
      orElse: () => NotificationPreference.push,
    );
  }
}

/// Product waitlist entry model
class WaitlistEntry extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final String? productImageUrl;
  final String vendorId;
  final String vendorName;
  final String popupId;
  final String marketId;
  final String marketName;
  final DateTime popupDate;

  // Shopper details
  final String shopperId;
  final String shopperEmail;
  final String? shopperPhone;
  final String shopperName;

  // Waitlist details
  final int position;
  final int quantityRequested;
  final NotificationPreference notificationPreference;
  final WaitlistStatus status;

  // Timestamps
  final DateTime joinedAt;
  final DateTime? notifiedAt;
  final DateTime? claimExpiresAt;
  final DateTime? claimedAt;

  // Order linkage
  final String? orderId;

  // Metadata
  final String? deviceToken;
  final String? timezone;

  const WaitlistEntry({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.vendorId,
    required this.vendorName,
    required this.popupId,
    required this.marketId,
    required this.marketName,
    required this.popupDate,
    required this.shopperId,
    required this.shopperEmail,
    this.shopperPhone,
    required this.shopperName,
    required this.position,
    this.quantityRequested = 1,
    this.notificationPreference = NotificationPreference.push,
    this.status = WaitlistStatus.waiting,
    required this.joinedAt,
    this.notifiedAt,
    this.claimExpiresAt,
    this.claimedAt,
    this.orderId,
    this.deviceToken,
    this.timezone,
  });

  factory WaitlistEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return WaitlistEntry(
      id: doc.id,
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      productImageUrl: data['productImageUrl'],
      vendorId: data['vendorId'] ?? '',
      vendorName: data['vendorName'] ?? '',
      popupId: data['popupId'] ?? '',
      marketId: data['marketId'] ?? '',
      marketName: data['marketName'] ?? '',
      popupDate: (data['popupDate'] as Timestamp).toDate(),
      shopperId: data['shopperId'] ?? '',
      shopperEmail: data['shopperEmail'] ?? '',
      shopperPhone: data['shopperPhone'],
      shopperName: data['shopperName'] ?? '',
      position: data['position'] ?? 0,
      quantityRequested: data['quantityRequested'] ?? 1,
      notificationPreference: NotificationPreference.fromString(
        data['notificationPreference'] ?? 'push',
      ),
      status: WaitlistStatus.fromString(data['status'] ?? 'waiting'),
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
      notifiedAt: data['notifiedAt'] != null
          ? (data['notifiedAt'] as Timestamp).toDate()
          : null,
      claimExpiresAt: data['claimExpiresAt'] != null
          ? (data['claimExpiresAt'] as Timestamp).toDate()
          : null,
      claimedAt: data['claimedAt'] != null
          ? (data['claimedAt'] as Timestamp).toDate()
          : null,
      orderId: data['orderId'],
      deviceToken: data['metadata']?['deviceToken'],
      timezone: data['metadata']?['timezone'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'productName': productName,
      'productImageUrl': productImageUrl,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'popupId': popupId,
      'marketId': marketId,
      'marketName': marketName,
      'popupDate': Timestamp.fromDate(popupDate),
      'shopperId': shopperId,
      'shopperEmail': shopperEmail,
      'shopperPhone': shopperPhone,
      'shopperName': shopperName,
      'position': position,
      'quantityRequested': quantityRequested,
      'notificationPreference': notificationPreference.value,
      'status': status.value,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'notifiedAt': notifiedAt != null ? Timestamp.fromDate(notifiedAt!) : null,
      'claimExpiresAt': claimExpiresAt != null ? Timestamp.fromDate(claimExpiresAt!) : null,
      'claimedAt': claimedAt != null ? Timestamp.fromDate(claimedAt!) : null,
      'orderId': orderId,
      'metadata': {
        'deviceToken': deviceToken,
        'timezone': timezone,
      },
    };
  }

  bool get isWaiting => status == WaitlistStatus.waiting;
  bool get isNotified => status == WaitlistStatus.notified;
  bool get isClaimed => status == WaitlistStatus.claimed;
  bool get isExpired => status == WaitlistStatus.expired;
  bool get isCancelled => status == WaitlistStatus.cancelled;

  bool get hasClaimExpired {
    if (claimExpiresAt == null) return false;
    return DateTime.now().isAfter(claimExpiresAt!);
  }

  String get statusDisplayText {
    switch (status) {
      case WaitlistStatus.waiting:
        return 'Waiting';
      case WaitlistStatus.notified:
        return 'Available to Claim';
      case WaitlistStatus.claimed:
        return 'Claimed';
      case WaitlistStatus.expired:
        return 'Expired';
      case WaitlistStatus.cancelled:
        return 'Cancelled';
    }
  }

  WaitlistEntry copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productImageUrl,
    String? vendorId,
    String? vendorName,
    String? popupId,
    String? marketId,
    String? marketName,
    DateTime? popupDate,
    String? shopperId,
    String? shopperEmail,
    String? shopperPhone,
    String? shopperName,
    int? position,
    int? quantityRequested,
    NotificationPreference? notificationPreference,
    WaitlistStatus? status,
    DateTime? joinedAt,
    DateTime? notifiedAt,
    DateTime? claimExpiresAt,
    DateTime? claimedAt,
    String? orderId,
    String? deviceToken,
    String? timezone,
  }) {
    return WaitlistEntry(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      popupId: popupId ?? this.popupId,
      marketId: marketId ?? this.marketId,
      marketName: marketName ?? this.marketName,
      popupDate: popupDate ?? this.popupDate,
      shopperId: shopperId ?? this.shopperId,
      shopperEmail: shopperEmail ?? this.shopperEmail,
      shopperPhone: shopperPhone ?? this.shopperPhone,
      shopperName: shopperName ?? this.shopperName,
      position: position ?? this.position,
      quantityRequested: quantityRequested ?? this.quantityRequested,
      notificationPreference: notificationPreference ?? this.notificationPreference,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      notifiedAt: notifiedAt ?? this.notifiedAt,
      claimExpiresAt: claimExpiresAt ?? this.claimExpiresAt,
      claimedAt: claimedAt ?? this.claimedAt,
      orderId: orderId ?? this.orderId,
      deviceToken: deviceToken ?? this.deviceToken,
      timezone: timezone ?? this.timezone,
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        shopperId,
        position,
        status,
        joinedAt,
      ];
}

/// Product waitlist summary (stored at product level)
class ProductWaitlist extends Equatable {
  final String productId;
  final String vendorId;
  final String popupId;
  final String marketId;
  final int totalWaiting;
  final int nextPosition;
  final int conversions;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductWaitlist({
    required this.productId,
    required this.vendorId,
    required this.popupId,
    required this.marketId,
    this.totalWaiting = 0,
    this.nextPosition = 1,
    this.conversions = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductWaitlist.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ProductWaitlist(
      productId: doc.id,
      vendorId: data['vendorId'] ?? '',
      popupId: data['popupId'] ?? '',
      marketId: data['marketId'] ?? '',
      totalWaiting: data['totalWaiting'] ?? 0,
      nextPosition: data['nextPosition'] ?? 1,
      conversions: data['conversions'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'popupId': popupId,
      'marketId': marketId,
      'totalWaiting': totalWaiting,
      'nextPosition': nextPosition,
      'conversions': conversions,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  @override
  List<Object?> get props => [
        productId,
        totalWaiting,
        nextPosition,
        updatedAt,
      ];
}
