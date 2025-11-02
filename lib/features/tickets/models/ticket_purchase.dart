import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Status of a ticket purchase
enum TicketPurchaseStatus {
  pending('pending'),
  processing('processing'),
  completed('completed'),
  failed('failed'),
  refunded('refunded'),
  cancelled('cancelled');

  final String value;
  const TicketPurchaseStatus(this.value);

  static TicketPurchaseStatus fromString(String value) {
    return TicketPurchaseStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TicketPurchaseStatus.pending,
    );
  }
}

/// Represents a ticket purchase transaction
class TicketPurchase extends Equatable {
  final String id;
  final String eventId;
  final String eventName;
  final String ticketId;
  final String ticketName;
  final String userId;
  final String userEmail;
  final String userName;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final double platformFee; // 6% platform fee
  final double totalAmount;
  final String? stripeSessionId;
  final String? stripePaymentIntentId;
  final String qrCode; // Unique QR code for this purchase
  final TicketPurchaseStatus status;
  final DateTime? usedAt; // When ticket was scanned/used
  final String? usedBy; // Staff member who validated the ticket
  final Map<String, dynamic>? metadata;
  final DateTime purchasedAt;
  final DateTime updatedAt;

  // Event details for display
  final DateTime? eventStartDate;
  final DateTime? eventEndDate;
  final String? eventLocation;
  final String? eventAddress;
  final String? eventImageUrl;

  const TicketPurchase({
    required this.id,
    required this.eventId,
    required this.eventName,
    required this.ticketId,
    required this.ticketName,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.platformFee,
    required this.totalAmount,
    this.stripeSessionId,
    this.stripePaymentIntentId,
    required this.qrCode,
    required this.status,
    this.usedAt,
    this.usedBy,
    this.metadata,
    required this.purchasedAt,
    required this.updatedAt,
    this.eventStartDate,
    this.eventEndDate,
    this.eventLocation,
    this.eventAddress,
    this.eventImageUrl,
  });

  /// Check if ticket is valid for use
  bool get isValid =>
      status == TicketPurchaseStatus.completed &&
      usedAt == null &&
      (eventStartDate == null || DateTime.now().isBefore(eventEndDate ?? eventStartDate!.add(const Duration(days: 1))));

  /// Check if ticket has been used
  bool get isUsed => usedAt != null;

  /// Check if event has passed
  bool get isEventPassed =>
      eventEndDate != null && DateTime.now().isAfter(eventEndDate!);

  /// Get ticket status text for display
  String get statusText {
    if (isUsed) return 'Used';
    if (isEventPassed) return 'Event Passed';
    if (!isValid) return 'Invalid';
    if (status == TicketPurchaseStatus.completed) return 'Valid';
    return status.value.toUpperCase();
  }

  /// Get ticket status color for UI
  String get statusColorHex {
    if (isUsed) return '#6B7280'; // Gray
    if (isEventPassed) return '#6B7280'; // Gray
    if (!isValid) return '#EF4444'; // Red
    if (status == TicketPurchaseStatus.completed) return '#10B981'; // Green
    if (status == TicketPurchaseStatus.refunded) return '#F59E0B'; // Amber
    return '#6B7280'; // Gray for other statuses
  }

  /// Format total amount for display
  String get formattedTotalAmount => '\$${totalAmount.toStringAsFixed(2)}';

  /// Format unit price for display
  String get formattedUnitPrice => '\$${unitPrice.toStringAsFixed(2)}';

  /// Format platform fee for display
  String get formattedPlatformFee => '\$${platformFee.toStringAsFixed(2)}';

  /// Get purchase summary text
  String get purchaseSummary => '$quantity × $ticketName @ $formattedUnitPrice';

  @override
  List<Object?> get props => [
        id,
        eventId,
        eventName,
        ticketId,
        ticketName,
        userId,
        userEmail,
        userName,
        quantity,
        unitPrice,
        subtotal,
        platformFee,
        totalAmount,
        stripeSessionId,
        stripePaymentIntentId,
        qrCode,
        status,
        usedAt,
        usedBy,
        metadata,
        purchasedAt,
        updatedAt,
        eventStartDate,
        eventEndDate,
        eventLocation,
        eventAddress,
        eventImageUrl,
      ];

  TicketPurchase copyWith({
    String? id,
    String? eventId,
    String? eventName,
    String? ticketId,
    String? ticketName,
    String? userId,
    String? userEmail,
    String? userName,
    int? quantity,
    double? unitPrice,
    double? subtotal,
    double? platformFee,
    double? totalAmount,
    String? stripeSessionId,
    String? stripePaymentIntentId,
    String? qrCode,
    TicketPurchaseStatus? status,
    DateTime? usedAt,
    String? usedBy,
    Map<String, dynamic>? metadata,
    DateTime? purchasedAt,
    DateTime? updatedAt,
    DateTime? eventStartDate,
    DateTime? eventEndDate,
    String? eventLocation,
    String? eventAddress,
    String? eventImageUrl,
  }) {
    return TicketPurchase(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      ticketId: ticketId ?? this.ticketId,
      ticketName: ticketName ?? this.ticketName,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      subtotal: subtotal ?? this.subtotal,
      platformFee: platformFee ?? this.platformFee,
      totalAmount: totalAmount ?? this.totalAmount,
      stripeSessionId: stripeSessionId ?? this.stripeSessionId,
      stripePaymentIntentId: stripePaymentIntentId ?? this.stripePaymentIntentId,
      qrCode: qrCode ?? this.qrCode,
      status: status ?? this.status,
      usedAt: usedAt ?? this.usedAt,
      usedBy: usedBy ?? this.usedBy,
      metadata: metadata ?? this.metadata,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      eventStartDate: eventStartDate ?? this.eventStartDate,
      eventEndDate: eventEndDate ?? this.eventEndDate,
      eventLocation: eventLocation ?? this.eventLocation,
      eventAddress: eventAddress ?? this.eventAddress,
      eventImageUrl: eventImageUrl ?? this.eventImageUrl,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'eventName': eventName,
      'ticketId': ticketId,
      'ticketName': ticketName,
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'subtotal': subtotal,
      'platformFee': platformFee,
      'totalAmount': totalAmount,
      'stripeSessionId': stripeSessionId,
      'stripePaymentIntentId': stripePaymentIntentId,
      'qrCode': qrCode,
      'status': status.value,
      'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
      'usedBy': usedBy,
      'metadata': metadata,
      'purchasedAt': Timestamp.fromDate(purchasedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'eventStartDate': eventStartDate != null
          ? Timestamp.fromDate(eventStartDate!)
          : null,
      'eventEndDate': eventEndDate != null
          ? Timestamp.fromDate(eventEndDate!)
          : null,
      'eventLocation': eventLocation,
      'eventAddress': eventAddress,
      'eventImageUrl': eventImageUrl,
    };
  }

  factory TicketPurchase.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TicketPurchase(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      eventName: data['eventName'] ?? '',
      ticketId: data['ticketId'] ?? '',
      ticketName: data['ticketName'] ?? '',
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userName: data['userName'] ?? '',
      quantity: data['quantity'] ?? 1,
      unitPrice: (data['unitPrice'] ?? 0.0).toDouble(),
      subtotal: (data['subtotal'] ?? 0.0).toDouble(),
      platformFee: (data['platformFee'] ?? 0.0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      stripeSessionId: data['stripeSessionId'],
      stripePaymentIntentId: data['stripePaymentIntentId'],
      qrCode: data['qrCode'] ?? '',
      status: TicketPurchaseStatus.fromString(data['status'] ?? 'pending'),
      usedAt: data['usedAt'] != null
          ? (data['usedAt'] as Timestamp).toDate()
          : null,
      usedBy: data['usedBy'],
      metadata: data['metadata'] as Map<String, dynamic>?,
      purchasedAt: data['purchasedAt'] != null
          ? (data['purchasedAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      eventStartDate: data['eventStartDate'] != null
          ? (data['eventStartDate'] as Timestamp).toDate()
          : null,
      eventEndDate: data['eventEndDate'] != null
          ? (data['eventEndDate'] as Timestamp).toDate()
          : null,
      eventLocation: data['eventLocation'],
      eventAddress: data['eventAddress'],
      eventImageUrl: data['eventImageUrl'],
    );
  }

  factory TicketPurchase.fromMap(Map<String, dynamic> map, String id) {
    return TicketPurchase(
      id: id,
      eventId: map['eventId'] ?? '',
      eventName: map['eventName'] ?? '',
      ticketId: map['ticketId'] ?? '',
      ticketName: map['ticketName'] ?? '',
      userId: map['userId'] ?? '',
      userEmail: map['userEmail'] ?? '',
      userName: map['userName'] ?? '',
      quantity: map['quantity'] ?? 1,
      unitPrice: (map['unitPrice'] ?? 0.0).toDouble(),
      subtotal: (map['subtotal'] ?? 0.0).toDouble(),
      platformFee: (map['platformFee'] ?? 0.0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      stripeSessionId: map['stripeSessionId'],
      stripePaymentIntentId: map['stripePaymentIntentId'],
      qrCode: map['qrCode'] ?? '',
      status: TicketPurchaseStatus.fromString(map['status'] ?? 'pending'),
      usedAt: map['usedAt'] is Timestamp
          ? (map['usedAt'] as Timestamp).toDate()
          : map['usedAt'] != null
              ? DateTime.parse(map['usedAt'])
              : null,
      usedBy: map['usedBy'],
      metadata: map['metadata'] as Map<String, dynamic>?,
      purchasedAt: map['purchasedAt'] is Timestamp
          ? (map['purchasedAt'] as Timestamp).toDate()
          : DateTime.parse(map['purchasedAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
      eventStartDate: map['eventStartDate'] is Timestamp
          ? (map['eventStartDate'] as Timestamp).toDate()
          : map['eventStartDate'] != null
              ? DateTime.parse(map['eventStartDate'])
              : null,
      eventEndDate: map['eventEndDate'] is Timestamp
          ? (map['eventEndDate'] as Timestamp).toDate()
          : map['eventEndDate'] != null
              ? DateTime.parse(map['eventEndDate'])
              : null,
      eventLocation: map['eventLocation'],
      eventAddress: map['eventAddress'],
      eventImageUrl: map['eventImageUrl'],
    );
  }
}