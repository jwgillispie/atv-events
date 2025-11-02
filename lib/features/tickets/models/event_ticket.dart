import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents a ticket configuration for an event
class EventTicket extends Equatable {
  final String id;
  final String eventId;
  final String name; // e.g., "General Admission", "VIP", "Early Bird"
  final String description;
  final double price; // Price in USD
  final int totalQuantity; // Total tickets available
  final int soldQuantity; // Number of tickets sold
  final int maxPerPurchase; // Max tickets per transaction
  final DateTime? salesStartDate; // When ticket sales open
  final DateTime? salesEndDate; // When ticket sales close
  final bool isActive; // Whether ticket is currently available
  final Map<String, dynamic>? metadata; // Additional ticket info
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventTicket({
    required this.id,
    required this.eventId,
    required this.name,
    required this.description,
    required this.price,
    required this.totalQuantity,
    this.soldQuantity = 0,
    this.maxPerPurchase = 10,
    this.salesStartDate,
    this.salesEndDate,
    this.isActive = true,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if tickets are still available
  bool get isAvailable =>
      isActive &&
      soldQuantity < totalQuantity &&
      (salesStartDate == null || DateTime.now().isAfter(salesStartDate!)) &&
      (salesEndDate == null || DateTime.now().isBefore(salesEndDate!));

  /// Get remaining tickets
  int get remainingQuantity => totalQuantity - soldQuantity;

  /// Get availability percentage
  double get availabilityPercentage =>
      totalQuantity > 0 ? (remainingQuantity / totalQuantity) * 100 : 0;

  /// Check if ticket is sold out
  bool get isSoldOut => soldQuantity >= totalQuantity;

  /// Format price for display
  String get formattedPrice => '\$${price.toStringAsFixed(2)}';

  /// Get availability status text
  String get availabilityStatus {
    if (isSoldOut) return 'Sold Out';
    if (remainingQuantity <= 10) return 'Only $remainingQuantity left!';
    if (availabilityPercentage <= 20) return 'Limited Availability';
    return 'Available';
  }

  /// Get availability status color for UI
  String get availabilityColorHex {
    if (isSoldOut) return '#EF4444'; // Red
    if (remainingQuantity <= 10) return '#F59E0B'; // Amber
    if (availabilityPercentage <= 20) return '#F59E0B'; // Amber
    return '#10B981'; // Green
  }

  @override
  List<Object?> get props => [
        id,
        eventId,
        name,
        description,
        price,
        totalQuantity,
        soldQuantity,
        maxPerPurchase,
        salesStartDate,
        salesEndDate,
        isActive,
        metadata,
        createdAt,
        updatedAt,
      ];

  EventTicket copyWith({
    String? id,
    String? eventId,
    String? name,
    String? description,
    double? price,
    int? totalQuantity,
    int? soldQuantity,
    int? maxPerPurchase,
    DateTime? salesStartDate,
    DateTime? salesEndDate,
    bool? isActive,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventTicket(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      soldQuantity: soldQuantity ?? this.soldQuantity,
      maxPerPurchase: maxPerPurchase ?? this.maxPerPurchase,
      salesStartDate: salesStartDate ?? this.salesStartDate,
      salesEndDate: salesEndDate ?? this.salesEndDate,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'name': name,
      'description': description,
      'price': price,
      'totalQuantity': totalQuantity,
      'soldQuantity': soldQuantity,
      'maxPerPurchase': maxPerPurchase,
      'salesStartDate': salesStartDate != null
          ? Timestamp.fromDate(salesStartDate!)
          : null,
      'salesEndDate': salesEndDate != null
          ? Timestamp.fromDate(salesEndDate!)
          : null,
      'isActive': isActive,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory EventTicket.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventTicket(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      totalQuantity: data['totalQuantity'] ?? 0,
      soldQuantity: data['soldQuantity'] ?? 0,
      maxPerPurchase: data['maxPerPurchase'] ?? 10,
      salesStartDate: data['salesStartDate'] != null
          ? (data['salesStartDate'] as Timestamp).toDate()
          : null,
      salesEndDate: data['salesEndDate'] != null
          ? (data['salesEndDate'] as Timestamp).toDate()
          : null,
      isActive: data['isActive'] ?? true,
      metadata: data['metadata'] as Map<String, dynamic>?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory EventTicket.fromMap(Map<String, dynamic> map, String id) {
    return EventTicket(
      id: id,
      eventId: map['eventId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      totalQuantity: map['totalQuantity'] ?? 0,
      soldQuantity: map['soldQuantity'] ?? 0,
      maxPerPurchase: map['maxPerPurchase'] ?? 10,
      salesStartDate: map['salesStartDate'] is Timestamp
          ? (map['salesStartDate'] as Timestamp).toDate()
          : map['salesStartDate'] != null
              ? DateTime.parse(map['salesStartDate'])
              : null,
      salesEndDate: map['salesEndDate'] is Timestamp
          ? (map['salesEndDate'] as Timestamp).toDate()
          : map['salesEndDate'] != null
              ? DateTime.parse(map['salesEndDate'])
              : null,
      isActive: map['isActive'] ?? true,
      metadata: map['metadata'] as Map<String, dynamic>?,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}