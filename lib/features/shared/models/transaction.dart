import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Types of transactions in the system
enum TransactionType {
  productPurchase('product_purchase'),
  ticketPurchase('ticket_purchase'),
  vendorPayout('vendor_payout'),
  subscription('subscription'),
  refund('refund');

  final String value;
  const TransactionType(this.value);

  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => TransactionType.productPurchase,
    );
  }
}

/// Status of a transaction
enum TransactionStatus {
  pending('pending'),
  processing('processing'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled'),
  refunded('refunded');

  final String value;
  const TransactionStatus(this.value);

  static TransactionStatus fromString(String value) {
    return TransactionStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TransactionStatus.pending,
    );
  }
}

/// Transaction model for tracking all payments in HiPop
class Transaction extends Equatable {
  final String id;
  final TransactionType type;
  final TransactionStatus status;
  final String userId;
  final String userEmail;
  final String userName;

  // Amount details
  final double subtotal;
  final double platformFee;
  final double total;
  final String currency;

  // Stripe details
  final String? stripePaymentIntentId;
  final String? stripeChargeId;
  final String? stripeRefundId;

  // Recipient details (vendor or organizer)
  final String? recipientId;
  final String? recipientName;
  final double? recipientPayout; // 94% of subtotal

  // Product purchase specific
  final List<String>? productIds;
  final String? marketId;
  final String? marketName;
  final DateTime? pickupDate;
  final String? pickupTimeSlot;
  final String? orderId;
  final String? qrCode;

  // Ticket purchase specific
  final String? eventId;
  final String? eventName;
  final DateTime? eventDate;
  final int? ticketQuantity;
  final String? ticketType;
  final List<String>? ticketIds;

  // Metadata
  final Map<String, dynamic>? metadata;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Transaction({
    required this.id,
    required this.type,
    required this.status,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.subtotal,
    required this.platformFee,
    required this.total,
    this.currency = 'USD',
    this.stripePaymentIntentId,
    this.stripeChargeId,
    this.stripeRefundId,
    this.recipientId,
    this.recipientName,
    this.recipientPayout,
    this.productIds,
    this.marketId,
    this.marketName,
    this.pickupDate,
    this.pickupTimeSlot,
    this.orderId,
    this.qrCode,
    this.eventId,
    this.eventName,
    this.eventDate,
    this.ticketQuantity,
    this.ticketType,
    this.ticketIds,
    this.metadata,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Transaction(
      id: doc.id,
      type: TransactionType.fromString(data['type'] ?? 'product_purchase'),
      status: TransactionStatus.fromString(data['status'] ?? 'pending'),
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userName: data['userName'] ?? '',
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      platformFee: (data['platformFee'] ?? 0).toDouble(),
      total: (data['total'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'USD',
      stripePaymentIntentId: data['stripePaymentIntentId'],
      stripeChargeId: data['stripeChargeId'],
      stripeRefundId: data['stripeRefundId'],
      recipientId: data['recipientId'],
      recipientName: data['recipientName'],
      recipientPayout: data['recipientPayout']?.toDouble(),
      productIds: data['productIds'] != null
          ? List<String>.from(data['productIds'])
          : null,
      marketId: data['marketId'],
      marketName: data['marketName'],
      pickupDate: data['pickupDate'] != null
          ? (data['pickupDate'] as Timestamp).toDate()
          : null,
      pickupTimeSlot: data['pickupTimeSlot'],
      orderId: data['orderId'],
      qrCode: data['qrCode'],
      eventId: data['eventId'],
      eventName: data['eventName'],
      eventDate: data['eventDate'] != null
          ? (data['eventDate'] as Timestamp).toDate()
          : null,
      ticketQuantity: data['ticketQuantity'],
      ticketType: data['ticketType'],
      ticketIds: data['ticketIds'] != null
          ? List<String>.from(data['ticketIds'])
          : null,
      metadata: data['metadata'],
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.value,
      'status': status.value,
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'subtotal': subtotal,
      'platformFee': platformFee,
      'total': total,
      'currency': currency,
      'stripePaymentIntentId': stripePaymentIntentId,
      'stripeChargeId': stripeChargeId,
      'stripeRefundId': stripeRefundId,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'recipientPayout': recipientPayout,
      'productIds': productIds,
      'marketId': marketId,
      'marketName': marketName,
      'pickupDate': pickupDate != null ? Timestamp.fromDate(pickupDate!) : null,
      'pickupTimeSlot': pickupTimeSlot,
      'orderId': orderId,
      'qrCode': qrCode,
      'eventId': eventId,
      'eventName': eventName,
      'eventDate': eventDate != null ? Timestamp.fromDate(eventDate!) : null,
      'ticketQuantity': ticketQuantity,
      'ticketType': ticketType,
      'ticketIds': ticketIds,
      'metadata': metadata,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Check if transaction is successful
  bool get isSuccessful => status == TransactionStatus.completed;

  /// Check if transaction can be refunded
  bool get canBeRefunded =>
      status == TransactionStatus.completed &&
      stripeRefundId == null;

  /// Get display status text
  String get displayStatus {
    switch (status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.processing:
        return 'Processing';
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.cancelled:
        return 'Cancelled';
      case TransactionStatus.refunded:
        return 'Refunded';
    }
  }

  /// Get status color (using HiPop color scheme)
  String get statusColorHex {
    switch (status) {
      case TransactionStatus.completed:
        return '#558B6E'; // Deep Sage (success)
      case TransactionStatus.processing:
        return '#E8A87C'; // Warning Amber
      case TransactionStatus.pending:
        return '#88A09E'; // Info Blue-Gray
      case TransactionStatus.failed:
      case TransactionStatus.cancelled:
        return '#704C5E'; // Error Plum
      case TransactionStatus.refunded:
        return '#946C7E'; // Mauve
    }
  }

  Transaction copyWith({
    String? id,
    TransactionType? type,
    TransactionStatus? status,
    String? userId,
    String? userEmail,
    String? userName,
    double? subtotal,
    double? platformFee,
    double? total,
    String? currency,
    String? stripePaymentIntentId,
    String? stripeChargeId,
    String? stripeRefundId,
    String? recipientId,
    String? recipientName,
    double? recipientPayout,
    List<String>? productIds,
    String? marketId,
    String? marketName,
    DateTime? pickupDate,
    String? pickupTimeSlot,
    String? orderId,
    String? qrCode,
    String? eventId,
    String? eventName,
    DateTime? eventDate,
    int? ticketQuantity,
    String? ticketType,
    List<String>? ticketIds,
    Map<String, dynamic>? metadata,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      subtotal: subtotal ?? this.subtotal,
      platformFee: platformFee ?? this.platformFee,
      total: total ?? this.total,
      currency: currency ?? this.currency,
      stripePaymentIntentId: stripePaymentIntentId ?? this.stripePaymentIntentId,
      stripeChargeId: stripeChargeId ?? this.stripeChargeId,
      stripeRefundId: stripeRefundId ?? this.stripeRefundId,
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      recipientPayout: recipientPayout ?? this.recipientPayout,
      productIds: productIds ?? this.productIds,
      marketId: marketId ?? this.marketId,
      marketName: marketName ?? this.marketName,
      pickupDate: pickupDate ?? this.pickupDate,
      pickupTimeSlot: pickupTimeSlot ?? this.pickupTimeSlot,
      orderId: orderId ?? this.orderId,
      qrCode: qrCode ?? this.qrCode,
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      eventDate: eventDate ?? this.eventDate,
      ticketQuantity: ticketQuantity ?? this.ticketQuantity,
      ticketType: ticketType ?? this.ticketType,
      ticketIds: ticketIds ?? this.ticketIds,
      metadata: metadata ?? this.metadata,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    status,
    userId,
    total,
    recipientId,
    orderId,
    eventId,
  ];
}

/// Vendor payout model for tracking weekly payouts
class VendorPayout extends Equatable {
  final String id;
  final String vendorId;
  final String vendorName;
  final String vendorEmail;

  // Payout details
  final double amount;
  final String currency;
  final String payoutMethod; // 'bank_transfer', 'check', 'paypal', etc.
  final String? payoutReference; // Bank transfer ID, check number, etc.

  // Period covered
  final DateTime periodStart;
  final DateTime periodEnd;
  final int transactionCount;
  final List<String> transactionIds;

  // Status
  final PayoutStatus status;
  final DateTime? processedAt;
  final String? processedBy;
  final String? notes;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  const VendorPayout({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.vendorEmail,
    required this.amount,
    this.currency = 'USD',
    required this.payoutMethod,
    this.payoutReference,
    required this.periodStart,
    required this.periodEnd,
    required this.transactionCount,
    required this.transactionIds,
    required this.status,
    this.processedAt,
    this.processedBy,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendorPayout.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return VendorPayout(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      vendorName: data['vendorName'] ?? '',
      vendorEmail: data['vendorEmail'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'USD',
      payoutMethod: data['payoutMethod'] ?? 'bank_transfer',
      payoutReference: data['payoutReference'],
      periodStart: (data['periodStart'] as Timestamp).toDate(),
      periodEnd: (data['periodEnd'] as Timestamp).toDate(),
      transactionCount: data['transactionCount'] ?? 0,
      transactionIds: List<String>.from(data['transactionIds'] ?? []),
      status: PayoutStatus.fromString(data['status'] ?? 'pending'),
      processedAt: data['processedAt'] != null
          ? (data['processedAt'] as Timestamp).toDate()
          : null,
      processedBy: data['processedBy'],
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'vendorName': vendorName,
      'vendorEmail': vendorEmail,
      'amount': amount,
      'currency': currency,
      'payoutMethod': payoutMethod,
      'payoutReference': payoutReference,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
      'transactionCount': transactionCount,
      'transactionIds': transactionIds,
      'status': status.value,
      'processedAt': processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'processedBy': processedBy,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  @override
  List<Object?> get props => [id, vendorId, amount, periodStart, periodEnd, status];
}

/// Status of vendor payouts
enum PayoutStatus {
  pending('pending'),
  processing('processing'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled');

  final String value;
  const PayoutStatus(this.value);

  static PayoutStatus fromString(String value) {
    return PayoutStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => PayoutStatus.pending,
    );
  }
}