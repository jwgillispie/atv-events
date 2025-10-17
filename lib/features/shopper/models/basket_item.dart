import 'package:equatable/equatable.dart';
import 'package:atv_events/features/shared/models/product.dart';

/// Represents an item in the reservation basket
class BasketItem extends Equatable {
  final String id; // Unique basket item ID
  final Product product;
  final String vendorPostId; // The popup where this will be picked up
  final String marketId;
  final String marketName;
  final DateTime popupDateTime;
  final String popupLocation;
  final int quantity;
  final DateTime addedAt;
  final String? notes;

  // Pickup time selection
  final PickupTimeSlot? selectedPickupSlot;

  // Payment tracking
  final bool isPaymentItem; // true if user chose to pay, false if reservation only
  final double? paidAmount; // Amount if payment was made

  const BasketItem({
    required this.id,
    required this.product,
    required this.vendorPostId,
    required this.marketId,
    required this.marketName,
    required this.popupDateTime,
    required this.popupLocation,
    this.quantity = 1,
    required this.addedAt,
    this.notes,
    this.selectedPickupSlot,
    this.isPaymentItem = false,
    this.paidAmount,
  });

  /// Calculate total price if available
  double? get totalPrice {
    if (product.price == null) return null;
    return product.price! * quantity;
  }

  /// Check if pickup is upcoming
  bool get isUpcoming => popupDateTime.isAfter(DateTime.now());

  /// Format display price
  String get displayPrice {
    if (totalPrice == null) return 'Price TBD';
    return '\$${totalPrice!.toStringAsFixed(2)}';
  }

  BasketItem copyWith({
    String? id,
    Product? product,
    String? vendorPostId,
    String? marketId,
    String? marketName,
    DateTime? popupDateTime,
    String? popupLocation,
    int? quantity,
    DateTime? addedAt,
    String? notes,
    PickupTimeSlot? selectedPickupSlot,
    bool? isPaymentItem,
    double? paidAmount,
  }) {
    return BasketItem(
      id: id ?? this.id,
      product: product ?? this.product,
      vendorPostId: vendorPostId ?? this.vendorPostId,
      marketId: marketId ?? this.marketId,
      marketName: marketName ?? this.marketName,
      popupDateTime: popupDateTime ?? this.popupDateTime,
      popupLocation: popupLocation ?? this.popupLocation,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt ?? this.addedAt,
      notes: notes ?? this.notes,
      selectedPickupSlot: selectedPickupSlot ?? this.selectedPickupSlot,
      isPaymentItem: isPaymentItem ?? this.isPaymentItem,
      paidAmount: paidAmount ?? this.paidAmount,
    );
  }

  @override
  List<Object?> get props => [
    id,
    product.id,
    vendorPostId,
    quantity,
    selectedPickupSlot,
    isPaymentItem,
    paidAmount,
  ];
}

/// Pickup time slot options
enum PickupTimeSlot {
  morning('Morning', '9:00 AM - 12:00 PM'),
  midday('Midday', '12:00 PM - 3:00 PM'),
  afternoon('Afternoon', '3:00 PM - 6:00 PM'),
  evening('Evening', '6:00 PM - 9:00 PM');

  final String label;
  final String timeRange;

  const PickupTimeSlot(this.label, this.timeRange);

  /// Get actual pickup time based on popup date
  DateTime getPickupTime(DateTime popupDate) {
    switch (this) {
      case PickupTimeSlot.morning:
        return DateTime(popupDate.year, popupDate.month, popupDate.day, 10, 0);
      case PickupTimeSlot.midday:
        return DateTime(popupDate.year, popupDate.month, popupDate.day, 13, 30);
      case PickupTimeSlot.afternoon:
        return DateTime(popupDate.year, popupDate.month, popupDate.day, 16, 30);
      case PickupTimeSlot.evening:
        return DateTime(popupDate.year, popupDate.month, popupDate.day, 19, 30);
    }
  }
}

/// Groups basket items by popup/market
class BasketGroup {
  final String vendorPostId;
  final String marketId;
  final String marketName;
  final DateTime popupDateTime;
  final String popupLocation;
  final List<BasketItem> items;

  BasketGroup({
    required this.vendorPostId,
    required this.marketId,
    required this.marketName,
    required this.popupDateTime,
    required this.popupLocation,
    required this.items,
  });

  /// Calculate group total
  double? get totalAmount {
    double total = 0;
    bool hasPrice = false;

    for (final item in items) {
      if (item.totalPrice != null) {
        total += item.totalPrice!;
        hasPrice = true;
      }
    }

    return hasPrice ? total : null;
  }

  /// Get total item count
  int get totalItems {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  /// Check if all items have selected pickup times
  bool get allItemsHavePickupTime {
    return items.every((item) => item.selectedPickupSlot != null);
  }

  /// Get unique vendors in this group
  Set<String> get vendorIds {
    return items.map((item) => item.product.vendorId).toSet();
  }
}