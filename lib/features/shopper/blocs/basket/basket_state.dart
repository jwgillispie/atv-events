import 'package:equatable/equatable.dart';
import 'package:hipop/features/shopper/models/basket_item.dart';

abstract class BasketState extends Equatable {
  const BasketState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class BasketInitial extends BasketState {}

/// Loading basket
class BasketLoading extends BasketState {}

/// Basket loaded with items
class BasketLoaded extends BasketState {
  final List<BasketItem> items;
  final bool isSubmitting;
  final String? submittingVendorPostId;

  const BasketLoaded({
    this.items = const [],
    this.isSubmitting = false,
    this.submittingVendorPostId,
  });

  /// Group items by vendor post/popup
  List<BasketGroup> get groupedItems {
    final Map<String, List<BasketItem>> groups = {};

    for (final item in items) {
      if (!groups.containsKey(item.vendorPostId)) {
        groups[item.vendorPostId] = [];
      }
      groups[item.vendorPostId]!.add(item);
    }

    return groups.entries.map((entry) {
      final firstItem = entry.value.first;
      return BasketGroup(
        vendorPostId: entry.key,
        marketId: firstItem.marketId,
        marketName: firstItem.marketName,
        popupDateTime: firstItem.popupDateTime,
        popupLocation: firstItem.popupLocation,
        items: entry.value,
      );
    }).toList()
      ..sort((a, b) => a.popupDateTime.compareTo(b.popupDateTime));
  }

  /// Get total item count
  int get totalItems {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  /// Get unique vendor count
  int get uniqueVendorCount {
    return items.map((item) => item.product.vendorId).toSet().length;
  }

  /// Get unique popup count
  int get uniquePopupCount {
    return items.map((item) => item.vendorPostId).toSet().length;
  }

  /// Calculate total amount (if all prices available)
  double? get totalAmount {
    double total = 0;
    bool hasPrice = false;

    for (final item in items) {
      if (item.totalPrice != null) {
        total += item.totalPrice!;
        hasPrice = true;
      } else {
        // If any item doesn't have a price, return null
        return null;
      }
    }

    return hasPrice ? total : null;
  }

  /// Check if product is in basket
  bool isProductInBasket(String productId) {
    return items.any((item) => item.product.id == productId);
  }

  /// Get quantity of product in basket
  int getProductQuantity(String productId) {
    try {
      final item = items.firstWhere(
        (item) => item.product.id == productId,
      );
      return item.quantity;
    } catch (e) {
      // Product not found in basket
      return 0;
    }
  }

  BasketLoaded copyWith({
    List<BasketItem>? items,
    bool? isSubmitting,
    String? submittingVendorPostId,
  }) {
    return BasketLoaded(
      items: items ?? this.items,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submittingVendorPostId: submittingVendorPostId ?? this.submittingVendorPostId,
    );
  }

  @override
  List<Object?> get props => [items, isSubmitting, submittingVendorPostId];
}

/// Error state
class BasketError extends BasketState {
  final String message;
  final List<BasketItem> previousItems;

  const BasketError({
    required this.message,
    this.previousItems = const [],
  });

  @override
  List<Object?> get props => [message, previousItems];
}

/// Reservation confirmation success
class BasketReservationSuccess extends BasketState {
  final String vendorPostId;
  final int itemCount;
  final List<String> reservationIds;

  const BasketReservationSuccess({
    required this.vendorPostId,
    required this.itemCount,
    required this.reservationIds,
  });

  @override
  List<Object?> get props => [vendorPostId, itemCount, reservationIds];
}