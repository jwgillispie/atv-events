import 'package:equatable/equatable.dart';
import 'package:hipop/features/shared/models/product.dart';
import 'package:hipop/features/shopper/models/basket_item.dart';

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
  final String vendorPostId;
  final String marketId;
  final String marketName;
  final DateTime popupDateTime;
  final String popupLocation;
  final int quantity;
  final String? notes;
  final bool isPaymentItem; // Whether user chose to pay now vs reserve only

  const AddToBasket({
    required this.product,
    required this.vendorPostId,
    required this.marketId,
    required this.marketName,
    required this.popupDateTime,
    required this.popupLocation,
    this.quantity = 1,
    this.notes,
    this.isPaymentItem = false,
  });

  @override
  List<Object?> get props => [
    product.id,
    vendorPostId,
    quantity,
    notes,
    isPaymentItem,
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

/// Update pickup time slot
class UpdatePickupTimeSlot extends BasketEvent {
  final String itemId;
  final PickupTimeSlot slot;

  const UpdatePickupTimeSlot({
    required this.itemId,
    required this.slot,
  });

  @override
  List<Object?> get props => [itemId, slot];
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

/// Confirm reservations for a popup group
class ConfirmReservations extends BasketEvent {
  final String vendorPostId;
  final String customerPhone;
  final String? customerNotes;

  const ConfirmReservations({
    required this.vendorPostId,
    required this.customerPhone,
    this.customerNotes,
  });

  @override
  List<Object?> get props => [vendorPostId, customerPhone, customerNotes];
}

/// Remove all items for a specific popup
class RemovePopupItems extends BasketEvent {
  final String vendorPostId;

  const RemovePopupItems(this.vendorPostId);

  @override
  List<Object?> get props => [vendorPostId];
}