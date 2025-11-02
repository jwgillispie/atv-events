import 'package:equatable/equatable.dart';
import 'package:atv_events/features/shopper/models/basket_item.dart';

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

  const BasketLoaded({
    this.items = const [],
    this.isSubmitting = false,
  });

  /// Get total item count
  int get totalItems {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  /// Get unique seller count
  int get uniqueSellerCount {
    return items.map((item) => item.product.sellerId).toSet().length;
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
  }) {
    return BasketLoaded(
      items: items ?? this.items,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  List<Object?> get props => [items, isSubmitting];
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

/// Checkout success
class BasketCheckoutSuccess extends BasketState {
  final int itemCount;
  final String orderId;

  const BasketCheckoutSuccess({
    required this.itemCount,
    required this.orderId,
  });

  @override
  List<Object?> get props => [itemCount, orderId];
}