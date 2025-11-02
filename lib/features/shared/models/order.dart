import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Order status enum
enum OrderStatus {
  pending('pending'),           // Payment pending
  paid('paid'),                 // Payment completed
  confirmed('confirmed'),       // Order confirmed by seller
  preparing('preparing'),       // Seller preparing order
  readyForPickup('ready_for_pickup'), // Ready for customer pickup
  pickedUp('picked_up'),       // Customer picked up order
  cancelled('cancelled'),       // Order cancelled
  refunded('refunded');        // Order refunded

  final String value;
  const OrderStatus(this.value);

  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => OrderStatus.pending,
    );
  }
}

/// Order model for product purchases
class Order extends Equatable {
  final String id;
  final String orderNumber; // Display-friendly order number
  final OrderStatus status;

  // Customer details
  final String customerId;
  final String customerEmail;
  final String customerName;
  final String? customerPhone;

  // Seller details
  final String vendorId;
  final String vendorName;

  // Shop details
  final String marketId;
  final String marketName;
  final String marketLocation;

  // Event details (for analytics tracking)
  final String? popupId; // Links order to specific event for location-based analytics

  // Order items
  final List<OrderItem> items;
  final int totalItems;

  // Pricing
  final double subtotal;
  final double platformFee;
  final double total;
  final String currency;

  // Pickup details
  final DateTime pickupDate;
  final String? pickupTimeSlot;
  final String? pickupInstructions;

  // Payment details
  final String? transactionId;
  final String? stripePaymentIntentId;
  final DateTime? paidAt;

  // QR Code for pickup verification
  final String qrCode;
  final bool qrScanned;
  final DateTime? qrScannedAt;

  // Notes
  final String? customerNotes;
  final String? sellerNotes;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.customerId,
    required this.customerEmail,
    required this.customerName,
    this.customerPhone,
    required this.vendorId,
    required this.vendorName,
    required this.marketId,
    required this.marketName,
    required this.marketLocation,
    this.popupId,
    required this.items,
    required this.totalItems,
    required this.subtotal,
    required this.platformFee,
    required this.total,
    this.currency = 'USD',
    required this.pickupDate,
    this.pickupTimeSlot,
    this.pickupInstructions,
    this.transactionId,
    this.stripePaymentIntentId,
    this.paidAt,
    required this.qrCode,
    this.qrScanned = false,
    this.qrScannedAt,
    this.customerNotes,
    this.sellerNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Generate a display-friendly order number
  static String generateOrderNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(6);
    final random = (now.microsecond % 1000).toString().padLeft(3, '0');
    return 'ATV-$timestamp$random';
  }

  /// Generate QR code data
  static String generateQRCode(String orderId) {
    return 'atv-events://order/$orderId';
  }

  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Order(
      id: doc.id,
      orderNumber: data['orderNumber'] ?? '',
      status: OrderStatus.fromString(data['status'] ?? 'pending'),
      customerId: data['customerId'] ?? '',
      customerEmail: data['customerEmail'] ?? '',
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'],
      vendorId: data['vendorId'] ?? '',
      vendorName: data['vendorName'] ?? '',
      marketId: data['marketId'] ?? '',
      marketName: data['marketName'] ?? '',
      marketLocation: data['marketLocation'] ?? '',
      popupId: data['popupId'],
      items: (data['items'] as List<dynamic>? ?? [])
          .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      totalItems: data['totalItems'] ?? 0,
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      platformFee: (data['platformFee'] ?? 0).toDouble(),
      total: (data['total'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'USD',
      pickupDate: (data['pickupDate'] as Timestamp).toDate(),
      pickupTimeSlot: data['pickupTimeSlot'],
      pickupInstructions: data['pickupInstructions'],
      transactionId: data['transactionId'],
      stripePaymentIntentId: data['stripePaymentIntentId'],
      paidAt: data['paidAt'] != null
          ? (data['paidAt'] as Timestamp).toDate()
          : null,
      qrCode: data['qrCode'] ?? '',
      qrScanned: data['qrScanned'] ?? false,
      qrScannedAt: data['qrScannedAt'] != null
          ? (data['qrScannedAt'] as Timestamp).toDate()
          : null,
      customerNotes: data['customerNotes'],
      sellerNotes: data['vendorNotes'], // vendorNotes in DB for compatibility
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orderNumber': orderNumber,
      'status': status.value,
      'customerId': customerId,
      'customerEmail': customerEmail,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'marketId': marketId,
      'marketName': marketName,
      'marketLocation': marketLocation,
      'popupId': popupId,
      'items': items.map((item) => item.toMap()).toList(),
      'totalItems': totalItems,
      'subtotal': subtotal,
      'platformFee': platformFee,
      'total': total,
      'currency': currency,
      'pickupDate': Timestamp.fromDate(pickupDate),
      'pickupTimeSlot': pickupTimeSlot,
      'pickupInstructions': pickupInstructions,
      'transactionId': transactionId,
      'stripePaymentIntentId': stripePaymentIntentId,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'qrCode': qrCode,
      'qrScanned': qrScanned,
      'qrScannedAt': qrScannedAt != null ? Timestamp.fromDate(qrScannedAt!) : null,
      'customerNotes': customerNotes,
      'vendorNotes': sellerNotes, // vendorNotes in DB for compatibility
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Check if order is active (not cancelled or refunded)
  bool get isActive =>
      status != OrderStatus.cancelled && status != OrderStatus.refunded;

  /// Check if order can be cancelled
  bool get canBeCancelled =>
      status == OrderStatus.pending || status == OrderStatus.paid;

  /// Check if order is ready for pickup
  bool get isReadyForPickup => status == OrderStatus.readyForPickup;

  /// Check if order has been picked up
  bool get isPickedUp => status == OrderStatus.pickedUp;

  /// Get status color (using HiPop color scheme)
  String get statusColorHex {
    switch (status) {
      case OrderStatus.paid:
      case OrderStatus.confirmed:
      case OrderStatus.pickedUp:
        return '#558B6E'; // Deep Sage (success)
      case OrderStatus.preparing:
      case OrderStatus.readyForPickup:
        return '#E8A87C'; // Warning Amber
      case OrderStatus.pending:
        return '#88A09E'; // Info Blue-Gray
      case OrderStatus.cancelled:
      case OrderStatus.refunded:
        return '#704C5E'; // Error Plum
    }
  }

  /// Get display status text
  String get displayStatus {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending Payment';
      case OrderStatus.paid:
        return 'Paid';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.readyForPickup:
        return 'Ready for Pickup';
      case OrderStatus.pickedUp:
        return 'Picked Up';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.refunded:
        return 'Refunded';
    }
  }

  Order copyWith({
    String? id,
    String? orderNumber,
    OrderStatus? status,
    String? customerId,
    String? customerEmail,
    String? customerName,
    String? customerPhone,
    String? vendorId,
    String? vendorName,
    String? marketId,
    String? marketName,
    String? marketLocation,
    String? popupId,
    List<OrderItem>? items,
    int? totalItems,
    double? subtotal,
    double? platformFee,
    double? total,
    String? currency,
    DateTime? pickupDate,
    String? pickupTimeSlot,
    String? pickupInstructions,
    String? transactionId,
    String? stripePaymentIntentId,
    DateTime? paidAt,
    String? qrCode,
    bool? qrScanned,
    DateTime? qrScannedAt,
    String? customerNotes,
    String? sellerNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      status: status ?? this.status,
      customerId: customerId ?? this.customerId,
      customerEmail: customerEmail ?? this.customerEmail,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      marketId: marketId ?? this.marketId,
      marketName: marketName ?? this.marketName,
      marketLocation: marketLocation ?? this.marketLocation,
      popupId: popupId ?? this.popupId,
      items: items ?? this.items,
      totalItems: totalItems ?? this.totalItems,
      subtotal: subtotal ?? this.subtotal,
      platformFee: platformFee ?? this.platformFee,
      total: total ?? this.total,
      currency: currency ?? this.currency,
      pickupDate: pickupDate ?? this.pickupDate,
      pickupTimeSlot: pickupTimeSlot ?? this.pickupTimeSlot,
      pickupInstructions: pickupInstructions ?? this.pickupInstructions,
      transactionId: transactionId ?? this.transactionId,
      stripePaymentIntentId: stripePaymentIntentId ?? this.stripePaymentIntentId,
      paidAt: paidAt ?? this.paidAt,
      qrCode: qrCode ?? this.qrCode,
      qrScanned: qrScanned ?? this.qrScanned,
      qrScannedAt: qrScannedAt ?? this.qrScannedAt,
      customerNotes: customerNotes ?? this.customerNotes,
      sellerNotes: sellerNotes ?? this.sellerNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    orderNumber,
    status,
    customerId,
    vendorId,
    marketId,
    total,
    pickupDate,
  ];
}

/// Order item model
class OrderItem extends Equatable {
  final String productId;
  final String productName;
  final String? productImage;
  final String category;
  final int quantity;
  final double pricePerUnit;
  final double totalPrice;
  final String? notes;

  const OrderItem({
    required this.productId,
    required this.productName,
    this.productImage,
    required this.category,
    required this.quantity,
    required this.pricePerUnit,
    required this.totalPrice,
    this.notes,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productImage: map['productImage'],
      category: map['category'] ?? '',
      quantity: map['quantity'] ?? 1,
      pricePerUnit: (map['pricePerUnit'] ?? 0).toDouble(),
      totalPrice: (map['totalPrice'] ?? 0).toDouble(),
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'category': category,
      'quantity': quantity,
      'pricePerUnit': pricePerUnit,
      'totalPrice': totalPrice,
      'notes': notes,
    };
  }

  @override
  List<Object?> get props => [productId, quantity, pricePerUnit];
}
