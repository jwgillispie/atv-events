import 'package:equatable/equatable.dart';
import 'package:atv_events/features/shared/models/product.dart';
import 'package:atv_events/features/shopper/models/basket_item.dart';

abstract class BasketEvent extends Equatable {
  const BasketEvent();

  @override
  List<Object?> get props => [];
}

/// Load basket from local storage
class LoadBasket extends BasketEvent {}

/// Add product to basket
class AddToBasket extends BasketEvent {
  final Product product;
  final int quantity;
  final String? notes;

  const AddToBasket({
    required this.product,
    this.quantity = 1,
    this.notes,
  });

  @override
  List<Object?> get props => [
    product.id,
    quantity,
    notes,
  ];
}

/// Remove item from basket
class RemoveFromBasket extends BasketEvent {
  final String itemId;

  const RemoveFromBasket(this.itemId);

  @override
  List<Object?> get props => [itemId];
}

/// Update item quantity
class UpdateBasketItemQuantity extends BasketEvent {
  final String itemId;
  final int quantity;

  const UpdateBasketItemQuantity({
    required this.itemId,
    required this.quantity,
  });

  @override
  List<Object?> get props => [itemId, quantity];
}


/// Update item notes
class UpdateBasketItemNotes extends BasketEvent {
  final String itemId;
  final String notes;

  const UpdateBasketItemNotes({
    required this.itemId,
    required this.notes,
  });

  @override
  List<Object?> get props => [itemId, notes];
}

/// Clear entire basket
class ClearBasket extends BasketEvent {}

/// Checkout basket and create order
class CheckoutBasket extends BasketEvent {
  final String customerPhone;
  final String? customerNotes;

  const CheckoutBasket({
    required this.customerPhone,
    this.customerNotes,
  });

  @override
  List<Object?> get props => [customerPhone, customerNotes];
}