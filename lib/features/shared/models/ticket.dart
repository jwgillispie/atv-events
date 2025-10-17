import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Ticket status enum
enum TicketStatus {
  active('active'),           // Valid ticket
  used('used'),              // Ticket has been scanned/used
  cancelled('cancelled'),     // Ticket cancelled
  refunded('refunded'),       // Ticket refunded
  expired('expired');         // Event has passed

  final String value;
  const TicketStatus(this.value);

  static TicketStatus fromString(String value) {
    return TicketStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TicketStatus.active,
    );
  }
}

/// Ticket model for event tickets
class Ticket extends Equatable {
  final String id;
  final String ticketNumber; // Display-friendly ticket number
  final TicketStatus status;

  // Event details
  final String eventId;
  final String eventName;
  final DateTime eventDate;
  final String eventLocation;
  final String? eventImage;

  // Organizer details
  final String organizerId;
  final String organizerName;

  // Purchaser details
  final String userId;
  final String userEmail;
  final String userName;
  final String? userPhone;

  // Ticket details
  final String? ticketType; // 'general', 'vip', 'early_bird', etc.
  final double price;
  final String currency;

  // Transaction details
  final String? transactionId;
  final String? stripePaymentIntentId;
  final DateTime purchasedAt;

  // QR Code for entry
  final String qrCode;
  final bool qrScanned;
  final DateTime? qrScannedAt;
  final String? scannedBy; // Staff member who scanned

  // Additional info
  final Map<String, dynamic>? metadata;
  final String? notes;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  const Ticket({
    required this.id,
    required this.ticketNumber,
    required this.status,
    required this.eventId,
    required this.eventName,
    required this.eventDate,
    required this.eventLocation,
    this.eventImage,
    required this.organizerId,
    required this.organizerName,
    required this.userId,
    required this.userEmail,
    required this.userName,
    this.userPhone,
    this.ticketType,
    required this.price,
    this.currency = 'USD',
    this.transactionId,
    this.stripePaymentIntentId,
    required this.purchasedAt,
    required this.qrCode,
    this.qrScanned = false,
    this.qrScannedAt,
    this.scannedBy,
    this.metadata,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Generate a display-friendly ticket number
  static String generateTicketNumber(String eventId) {
    final now = DateTime.now();
    final eventPrefix = eventId.substring(0, 3).toUpperCase();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(7);
    final random = (now.microsecond % 1000).toString().padLeft(3, '0');
    return 'TKT-$eventPrefix-$timestamp$random';
  }

  /// Generate QR code data
  static String generateQRCode(String ticketId) {
    return 'hipop://ticket/$ticketId';
  }

  factory Ticket.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Ticket(
      id: doc.id,
      ticketNumber: data['ticketNumber'] ?? '',
      status: TicketStatus.fromString(data['status'] ?? 'active'),
      eventId: data['eventId'] ?? '',
      eventName: data['eventName'] ?? '',
      eventDate: (data['eventDate'] as Timestamp).toDate(),
      eventLocation: data['eventLocation'] ?? '',
      eventImage: data['eventImage'],
      organizerId: data['organizerId'] ?? '',
      organizerName: data['organizerName'] ?? '',
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userName: data['userName'] ?? '',
      userPhone: data['userPhone'],
      ticketType: data['ticketType'],
      price: (data['price'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'USD',
      transactionId: data['transactionId'],
      stripePaymentIntentId: data['stripePaymentIntentId'],
      purchasedAt: (data['purchasedAt'] as Timestamp).toDate(),
      qrCode: data['qrCode'] ?? '',
      qrScanned: data['qrScanned'] ?? false,
      qrScannedAt: data['qrScannedAt'] != null
          ? (data['qrScannedAt'] as Timestamp).toDate()
          : null,
      scannedBy: data['scannedBy'],
      metadata: data['metadata'],
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ticketNumber': ticketNumber,
      'status': status.value,
      'eventId': eventId,
      'eventName': eventName,
      'eventDate': Timestamp.fromDate(eventDate),
      'eventLocation': eventLocation,
      'eventImage': eventImage,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'userPhone': userPhone,
      'ticketType': ticketType,
      'price': price,
      'currency': currency,
      'transactionId': transactionId,
      'stripePaymentIntentId': stripePaymentIntentId,
      'purchasedAt': Timestamp.fromDate(purchasedAt),
      'qrCode': qrCode,
      'qrScanned': qrScanned,
      'qrScannedAt': qrScannedAt != null ? Timestamp.fromDate(qrScannedAt!) : null,
      'scannedBy': scannedBy,
      'metadata': metadata,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Check if ticket is valid for entry
  bool get isValidForEntry =>
      status == TicketStatus.active &&
      !qrScanned &&
      eventDate.isAfter(DateTime.now());

  /// Check if ticket can be refunded (within 24 hours of purchase)
  bool get canBeRefunded {
    if (status != TicketStatus.active) return false;
    if (qrScanned) return false;

    final now = DateTime.now();
    final hoursSincePurchase = now.difference(purchasedAt).inHours;
    final hoursUntilEvent = eventDate.difference(now).inHours;

    // Can refund if within 24 hours of purchase AND at least 48 hours before event
    return hoursSincePurchase <= 24 && hoursUntilEvent >= 48;
  }

  /// Check if event has passed
  bool get hasEventPassed => DateTime.now().isAfter(eventDate);

  /// Get status color (using HiPop color scheme)
  String get statusColorHex {
    switch (status) {
      case TicketStatus.active:
        return '#558B6E'; // Deep Sage (success)
      case TicketStatus.used:
        return '#88A09E'; // Info Blue-Gray
      case TicketStatus.cancelled:
      case TicketStatus.refunded:
        return '#704C5E'; // Error Plum
      case TicketStatus.expired:
        return '#7C767E'; // Warm Gray
    }
  }

  /// Get display status text
  String get displayStatus {
    switch (status) {
      case TicketStatus.active:
        return 'Active';
      case TicketStatus.used:
        return 'Used';
      case TicketStatus.cancelled:
        return 'Cancelled';
      case TicketStatus.refunded:
        return 'Refunded';
      case TicketStatus.expired:
        return 'Expired';
    }
  }

  /// Get ticket type display text
  String get displayTicketType {
    if (ticketType == null) return 'General Admission';

    switch (ticketType!.toLowerCase()) {
      case 'general':
        return 'General Admission';
      case 'vip':
        return 'VIP';
      case 'early_bird':
        return 'Early Bird';
      case 'group':
        return 'Group Ticket';
      default:
        return ticketType!;
    }
  }

  Ticket copyWith({
    String? id,
    String? ticketNumber,
    TicketStatus? status,
    String? eventId,
    String? eventName,
    DateTime? eventDate,
    String? eventLocation,
    String? eventImage,
    String? organizerId,
    String? organizerName,
    String? userId,
    String? userEmail,
    String? userName,
    String? userPhone,
    String? ticketType,
    double? price,
    String? currency,
    String? transactionId,
    String? stripePaymentIntentId,
    DateTime? purchasedAt,
    String? qrCode,
    bool? qrScanned,
    DateTime? qrScannedAt,
    String? scannedBy,
    Map<String, dynamic>? metadata,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Ticket(
      id: id ?? this.id,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      status: status ?? this.status,
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      eventDate: eventDate ?? this.eventDate,
      eventLocation: eventLocation ?? this.eventLocation,
      eventImage: eventImage ?? this.eventImage,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      ticketType: ticketType ?? this.ticketType,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      transactionId: transactionId ?? this.transactionId,
      stripePaymentIntentId: stripePaymentIntentId ?? this.stripePaymentIntentId,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      qrCode: qrCode ?? this.qrCode,
      qrScanned: qrScanned ?? this.qrScanned,
      qrScannedAt: qrScannedAt ?? this.qrScannedAt,
      scannedBy: scannedBy ?? this.scannedBy,
      metadata: metadata ?? this.metadata,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    ticketNumber,
    status,
    eventId,
    userId,
    eventDate,
    qrScanned,
  ];
}

/// Batch ticket purchase (for buying multiple tickets at once)
class TicketBatch extends Equatable {
  final String id;
  final String transactionId;
  final String eventId;
  final String eventName;
  final String userId;
  final String userEmail;
  final int quantity;
  final double pricePerTicket;
  final double total;
  final List<String> ticketIds;
  final DateTime purchasedAt;

  const TicketBatch({
    required this.id,
    required this.transactionId,
    required this.eventId,
    required this.eventName,
    required this.userId,
    required this.userEmail,
    required this.quantity,
    required this.pricePerTicket,
    required this.total,
    required this.ticketIds,
    required this.purchasedAt,
  });

  factory TicketBatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return TicketBatch(
      id: doc.id,
      transactionId: data['transactionId'] ?? '',
      eventId: data['eventId'] ?? '',
      eventName: data['eventName'] ?? '',
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      quantity: data['quantity'] ?? 0,
      pricePerTicket: (data['pricePerTicket'] ?? 0).toDouble(),
      total: (data['total'] ?? 0).toDouble(),
      ticketIds: List<String>.from(data['ticketIds'] ?? []),
      purchasedAt: (data['purchasedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'transactionId': transactionId,
      'eventId': eventId,
      'eventName': eventName,
      'userId': userId,
      'userEmail': userEmail,
      'quantity': quantity,
      'pricePerTicket': pricePerTicket,
      'total': total,
      'ticketIds': ticketIds,
      'purchasedAt': Timestamp.fromDate(purchasedAt),
    };
  }

  @override
  List<Object?> get props => [id, transactionId, eventId, userId, quantity];
}