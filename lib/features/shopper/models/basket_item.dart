import 'package:equatable/equatable.dart';
import 'package:atv_events/features/shared/models/product.dart';

/// Represents an item in the shopping basket
class BasketItem extends Equatable {
  final String id; // Unique basket item ID
  final Product product;
  final int quantity;
  final DateTime addedAt;
  final String? notes;

  const BasketItem({
    required this.id,
    required this.product,
    this.quantity = 1,
    required this.addedAt,
    this.notes,
  });

  /// Calculate total price if available
  double? get totalPrice {
    if (product.price == null) return null;
    return product.price! * quantity;
  }

  /// Format display price
  String get displayPrice {
    if (totalPrice == null) return 'Price TBD';
    return '\$${totalPrice!.toStringAsFixed(2)}';
  }

  BasketItem copyWith({
    String? id,
    Product? product,
    int? quantity,
    DateTime? addedAt,
    String? notes,
  }) {
    return BasketItem(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt ?? this.addedAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        product.id,
        quantity,
        notes,
      ];
}
