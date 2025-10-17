import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Product Reservation Model
/// Represents a customer's reservation for a product at an upcoming popup
class ProductReservation extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final String vendorId;
  final String vendorName;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final String? customerPhone;
  final String vendorPostId; // The popup where product will be picked up
  final DateTime pickupDateTime;
  final String pickupLocation;
  final int quantity;
  final double? unitPrice;
  final double? totalAmount;
  final ReservationStatus status;
  final String? notes; // Customer notes
  final String? vendorNotes; // Vendor response/notes
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;
  final DateTime? completedAt;
  final String? cancellationReason;
  final bool notificationSent;

  const ProductReservation({
    required this.id,
    required this.productId,
    required this.productName,
    required this.vendorId,
    required this.vendorName,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    this.customerPhone,
    required this.vendorPostId,
    required this.pickupDateTime,
    required this.pickupLocation,
    this.quantity = 1,
    this.unitPrice,
    this.totalAmount,
    this.status = ReservationStatus.pending,
    this.notes,
    this.vendorNotes,
    required this.createdAt,
    this.confirmedAt,
    this.cancelledAt,
    this.completedAt,
    this.cancellationReason,
    this.notificationSent = false,
  });

  factory ProductReservation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ProductReservation(
      id: doc.id,
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      vendorId: data['vendorId'] ?? '',
      vendorName: data['vendorName'] ?? '',
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      customerEmail: data['customerEmail'] ?? '',
      customerPhone: data['customerPhone'],
      vendorPostId: data['vendorPostId'] ?? '',
      pickupDateTime: (data['pickupDateTime'] as Timestamp).toDate(),
      pickupLocation: data['pickupLocation'] ?? '',
      quantity: data['quantity'] ?? 1,
      unitPrice: data['unitPrice']?.toDouble(),
      totalAmount: data['totalAmount']?.toDouble(),
      status: ReservationStatus.fromString(data['status'] ?? 'pending'),
      notes: data['notes'],
      vendorNotes: data['vendorNotes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      confirmedAt: data['confirmedAt'] != null
          ? (data['confirmedAt'] as Timestamp).toDate()
          : null,
      cancelledAt: data['cancelledAt'] != null
          ? (data['cancelledAt'] as Timestamp).toDate()
          : null,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      cancellationReason: data['cancellationReason'],
      notificationSent: data['notificationSent'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'productName': productName,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'customerId': customerId,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'vendorPostId': vendorPostId,
      'pickupDateTime': Timestamp.fromDate(pickupDateTime),
      'pickupLocation': pickupLocation,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalAmount': totalAmount,
      'status': status.value,
      'notes': notes,
      'vendorNotes': vendorNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'confirmedAt': confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'cancellationReason': cancellationReason,
      'notificationSent': notificationSent,
    };
  }

  /// Check if reservation can be cancelled
  bool get canBeCancelled {
    if (status != ReservationStatus.pending && status != ReservationStatus.confirmed) {
      return false;
    }
    // Cannot cancel if pickup is within 2 hours
    return pickupDateTime.difference(DateTime.now()).inHours > 2;
  }

  /// Check if reservation is upcoming
  bool get isUpcoming {
    return pickupDateTime.isAfter(DateTime.now()) &&
           (status == ReservationStatus.pending || status == ReservationStatus.confirmed);
  }

  /// Check if reservation is past
  bool get isPast {
    return pickupDateTime.isBefore(DateTime.now()) || status == ReservationStatus.completed;
  }

  /// Get status display text
  String get statusText {
    switch (status) {
      case ReservationStatus.pending:
        return 'Pending Confirmation';
      case ReservationStatus.confirmed:
        return 'Confirmed';
      case ReservationStatus.cancelled:
        return 'Cancelled';
      case ReservationStatus.completed:
        return 'Completed';
      case ReservationStatus.noShow:
        return 'No Show';
    }
  }

  /// Get status color code
  String get statusColor {
    switch (status) {
      case ReservationStatus.pending:
        return 'warning';
      case ReservationStatus.confirmed:
        return 'success';
      case ReservationStatus.cancelled:
        return 'error';
      case ReservationStatus.completed:
        return 'info';
      case ReservationStatus.noShow:
        return 'error';
    }
  }

  /// Format pickup time
  String get formattedPickupTime {
    final hour = pickupDateTime.hour == 0 ? 12 : pickupDateTime.hour > 12 ? pickupDateTime.hour - 12 : pickupDateTime.hour;
    final period = pickupDateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = pickupDateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  /// Format pickup date
  String get formattedPickupDate {
    return '${pickupDateTime.month}/${pickupDateTime.day}/${pickupDateTime.year}';
  }

  /// Get display amount
  String get displayAmount {
    if (totalAmount == null) return 'Price TBD';
    return '\$${totalAmount!.toStringAsFixed(2)}';
  }

  ProductReservation copyWith({
    String? id,
    String? productId,
    String? productName,
    String? vendorId,
    String? vendorName,
    String? customerId,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    String? vendorPostId,
    DateTime? pickupDateTime,
    String? pickupLocation,
    int? quantity,
    double? unitPrice,
    double? totalAmount,
    ReservationStatus? status,
    String? notes,
    String? vendorNotes,
    DateTime? createdAt,
    DateTime? confirmedAt,
    DateTime? cancelledAt,
    DateTime? completedAt,
    String? cancellationReason,
    bool? notificationSent,
  }) {
    return ProductReservation(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhone: customerPhone ?? this.customerPhone,
      vendorPostId: vendorPostId ?? this.vendorPostId,
      pickupDateTime: pickupDateTime ?? this.pickupDateTime,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      vendorNotes: vendorNotes ?? this.vendorNotes,
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      completedAt: completedAt ?? this.completedAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      notificationSent: notificationSent ?? this.notificationSent,
    );
  }

  @override
  List<Object?> get props => [
    id,
    productId,
    productName,
    vendorId,
    vendorName,
    customerId,
    customerName,
    customerEmail,
    customerPhone,
    vendorPostId,
    pickupDateTime,
    pickupLocation,
    quantity,
    unitPrice,
    totalAmount,
    status,
    notes,
    vendorNotes,
    createdAt,
    confirmedAt,
    cancelledAt,
    completedAt,
    cancellationReason,
    notificationSent,
  ];
}

/// Reservation Status Enum
enum ReservationStatus {
  pending,
  confirmed,
  cancelled,
  completed,
  noShow;

  String get value {
    switch (this) {
      case ReservationStatus.pending:
        return 'pending';
      case ReservationStatus.confirmed:
        return 'confirmed';
      case ReservationStatus.cancelled:
        return 'cancelled';
      case ReservationStatus.completed:
        return 'completed';
      case ReservationStatus.noShow:
        return 'no_show';
    }
  }

  static ReservationStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return ReservationStatus.pending;
      case 'confirmed':
        return ReservationStatus.confirmed;
      case 'cancelled':
        return ReservationStatus.cancelled;
      case 'completed':
        return ReservationStatus.completed;
      case 'no_show':
        return ReservationStatus.noShow;
      default:
        return ReservationStatus.pending;
    }
  }
}