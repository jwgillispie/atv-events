import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:atv_events/features/shopper/blocs/basket/basket_event.dart';
import 'package:atv_events/features/shopper/blocs/basket/basket_state.dart';
import 'package:atv_events/features/shopper/models/basket_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:atv_events/features/shared/models/product.dart';

/// BLoC for managing the shopping basket
class BasketBloc extends Bloc<BasketEvent, BasketState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? userId;
  static const String _basketKey = 'atv_basket';
  final _uuid = const Uuid();

  BasketBloc({
    this.userId,
  }) : super(BasketInitial()) {
    on<LoadBasket>(_onLoadBasket);
    on<AddToBasket>(_onAddToBasket);
    on<RemoveFromBasket>(_onRemoveFromBasket);
    on<UpdateBasketItemQuantity>(_onUpdateQuantity);
    on<UpdateBasketItemNotes>(_onUpdateNotes);
    on<ClearBasket>(_onClearBasket);
    on<CheckoutBasket>(_onCheckoutBasket);

    // Load basket on initialization
    add(LoadBasket());
  }

  /// Load basket from Firestore (with local cache fallback)
  Future<void> _onLoadBasket(LoadBasket event, Emitter<BasketState> emit) async {
    emit(BasketLoading());

    try {
      List<BasketItem> items = [];

      // Try loading from Firestore if userId is available
      if (userId != null) {
        try {
          final basketSnapshot = await _firestore
              .collection('users')
              .doc(userId)
              .collection('basket')
              .get();

          items = basketSnapshot.docs
              .map((doc) => _deserializeBasketItemFromFirestore(doc))
              .toList();

          print('Loaded ${items.length} items from Firestore basket');
        } catch (e) {
          print('Failed to load from Firestore, falling back to local: $e');
          // Fall back to local storage
          items = await _loadFromLocalStorage();
        }
      } else {
        // No userId, load from local storage
        items = await _loadFromLocalStorage();
      }

      emit(BasketLoaded(items: items));
    } catch (e) {
      print('Error loading basket: $e');
      emit(BasketError(message: 'Failed to load basket: $e'));
    }
  }

  /// Load basket from local storage (fallback)
  Future<List<BasketItem>> _loadFromLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final basketJson = prefs.getString(_basketKey);

    if (basketJson != null) {
      final List<dynamic> decoded = json.decode(basketJson);
      return decoded.map((item) => _deserializeBasketItem(item)).toList();
    }

    return [];
  }

  /// Add product to basket
  Future<void> _onAddToBasket(AddToBasket event, Emitter<BasketState> emit) async {
    final currentState = state;
    if (currentState is! BasketLoaded) return;

    try {
      // Check if product already in basket
      final existingIndex = currentState.items.indexWhere(
        (item) => item.product.id == event.product.id,
      );

      List<BasketItem> updatedItems;

      if (existingIndex != -1) {
        // Update quantity if already exists
        updatedItems = List.from(currentState.items);
        final existing = updatedItems[existingIndex];
        updatedItems[existingIndex] = existing.copyWith(
          quantity: existing.quantity + event.quantity,
        );
      } else {
        // Add new item
        final newItem = BasketItem(
          id: _uuid.v4(),
          product: event.product,
          quantity: event.quantity,
          addedAt: DateTime.now(),
          notes: event.notes,
        );
        updatedItems = [...currentState.items, newItem];
      }

      emit(currentState.copyWith(items: updatedItems));
      await _saveBasket(updatedItems);
    } catch (e) {
      emit(BasketError(
        message: 'Failed to add to basket: $e',
        previousItems: currentState.items,
      ));
    }
  }

  /// Remove item from basket
  Future<void> _onRemoveFromBasket(RemoveFromBasket event, Emitter<BasketState> emit) async {
    final currentState = state;
    if (currentState is! BasketLoaded) return;

    try {
      final updatedItems = currentState.items
          .where((item) => item.id != event.itemId)
          .toList();

      emit(currentState.copyWith(items: updatedItems));
      await _saveBasket(updatedItems);
    } catch (e) {
      emit(BasketError(
        message: 'Failed to remove from basket: $e',
        previousItems: currentState.items,
      ));
    }
  }

  /// Update item quantity
  Future<void> _onUpdateQuantity(UpdateBasketItemQuantity event, Emitter<BasketState> emit) async {
    final currentState = state;
    if (currentState is! BasketLoaded) return;

    try {
      if (event.quantity <= 0) {
        // Remove item if quantity is 0 or less
        add(RemoveFromBasket(event.itemId));
        return;
      }

      final updatedItems = currentState.items.map((item) {
        if (item.id == event.itemId) {
          return item.copyWith(quantity: event.quantity);
        }
        return item;
      }).toList();

      emit(currentState.copyWith(items: updatedItems));
      await _saveBasket(updatedItems);
    } catch (e) {
      emit(BasketError(
        message: 'Failed to update quantity: $e',
        previousItems: currentState.items,
      ));
    }
  }

  /// Update item notes
  Future<void> _onUpdateNotes(UpdateBasketItemNotes event, Emitter<BasketState> emit) async {
    final currentState = state;
    if (currentState is! BasketLoaded) return;

    try {
      final updatedItems = currentState.items.map((item) {
        if (item.id == event.itemId) {
          return item.copyWith(notes: event.notes);
        }
        return item;
      }).toList();

      emit(currentState.copyWith(items: updatedItems));
      await _saveBasket(updatedItems);
    } catch (e) {
      emit(BasketError(
        message: 'Failed to update notes: $e',
        previousItems: currentState.items,
      ));
    }
  }

  /// Clear entire basket
  Future<void> _onClearBasket(ClearBasket event, Emitter<BasketState> emit) async {
    try {
      emit(const BasketLoaded());
      await _saveBasket([]);
    } catch (e) {
      emit(BasketError(message: 'Failed to clear basket: $e'));
    }
  }

  /// Checkout basket and create order
  Future<void> _onCheckoutBasket(CheckoutBasket event, Emitter<BasketState> emit) async {
    final currentState = state;
    if (currentState is! BasketLoaded) return;

    emit(currentState.copyWith(isSubmitting: true));

    try {
      if (currentState.items.isEmpty) {
        throw Exception('Basket is empty');
      }

      if (userId == null) {
        throw Exception('Must be logged in to checkout');
      }

      // Get user profile for customer info
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final customerName = userData?['displayName'] ?? 'Unknown';
      final customerEmail = userData?['email'] ?? '';

      // Create order for each seller (group by sellerId)
      final ordersBySeller = <String, List<BasketItem>>{};
      for (final item in currentState.items) {
        final sellerId = item.product.sellerId;
        if (!ordersBySeller.containsKey(sellerId)) {
          ordersBySeller[sellerId] = [];
        }
        ordersBySeller[sellerId]!.add(item);
      }

      final orderIds = <String>[];

      // Create separate order for each seller
      for (final entry in ordersBySeller.entries) {
        final sellerId = entry.key;
        final sellerItems = entry.value;
        final sellerName = sellerItems.first.product.sellerName;

        // Calculate seller's total
        double sellerTotal = 0;
        for (final item in sellerItems) {
          if (item.totalPrice != null) {
            sellerTotal += item.totalPrice!;
          }
        }

        // Create order items
        final orderItems = sellerItems.map((item) => {
          'productId': item.product.id,
          'productName': item.product.name,
          'quantity': item.quantity,
          'price': item.product.price,
          'totalPrice': item.totalPrice,
          'imageUrl': item.product.primaryImageUrl,
          'notes': item.notes,
        }).toList();

        // Create order document
        final orderId = _uuid.v4();
        final now = DateTime.now();

        final orderData = {
          'orderId': orderId,
          'customerId': userId,
          'customerName': customerName,
          'customerEmail': customerEmail,
          'customerPhone': event.customerPhone,
          'vendorId': sellerId,
          'vendorName': sellerName,
          'marketId': 'atv-shop',  // ATV shop identifier
          'marketName': 'ATV Shop',
          'items': orderItems,
          'totalAmount': sellerTotal,
          'status': 'pending',  // pending, confirmed, preparing, ready, completed, cancelled
          'paymentStatus': 'pending',  // pending, paid, refunded
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'orderNumber': '#${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${orderId.substring(0, 6).toUpperCase()}',
          'customerNotes': event.customerNotes,
        };

        // Save order
        await _firestore.collection('orders').doc(orderId).set(orderData);

        // Add to user's orders subcollection
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('orders')
            .doc(orderId)
            .set({
          'orderId': orderId,
          'vendorId': sellerId,
          'vendorName': sellerName,
          'totalAmount': sellerTotal,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Add to seller's orders
        await _firestore
            .collection('users')
            .doc(sellerId)
            .collection('vendor_orders')
            .doc(orderId)
            .set({
          'orderId': orderId,
          'customerId': userId,
          'customerName': customerName,
          'customerEmail': customerEmail,
          'customerPhone': event.customerPhone,
          'totalAmount': sellerTotal,
          'itemCount': sellerItems.length,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        orderIds.add(orderId);

        print('✅ Created order $orderId for seller $sellerName');
      }

      // Clear the basket
      await _saveBasket([]);

      // Show success state
      emit(BasketCheckoutSuccess(
        itemCount: currentState.items.length,
        orderId: orderIds.first,  // Show first order ID
      ));

      print('✅ Checkout complete - ${orderIds.length} orders created');

    } catch (e) {
      print('❌ Checkout failed: $e');
      emit(BasketError(
        message: 'Failed to checkout: $e',
        previousItems: currentState.items,
      ));

      // Return to loaded state after brief delay
      await Future.delayed(const Duration(seconds: 2));
      emit(currentState.copyWith(isSubmitting: false));
    }
  }

  /// Save basket to both Firestore and local storage
  Future<void> _saveBasket(List<BasketItem> items) async {
    // Save to local storage
    final prefs = await SharedPreferences.getInstance();
    final basketJson = json.encode(items.map(_serializeBasketItem).toList());
    await prefs.setString(_basketKey, basketJson);

    // Save to Firestore if userId is available
    if (userId != null) {
      try {
        final basketRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('basket');

        // Use batch to update all items efficiently
        final batch = _firestore.batch();

        // Get existing basket items to delete ones not in the new list
        final existingSnapshot = await basketRef.get();
        final existingIds = existingSnapshot.docs.map((doc) => doc.id).toSet();
        final newIds = items.map((item) => item.id).toSet();

        // Delete items that are no longer in the basket
        for (final id in existingIds) {
          if (!newIds.contains(id)) {
            batch.delete(basketRef.doc(id));
          }
        }

        // Add or update current items
        for (final item in items) {
          batch.set(
            basketRef.doc(item.id),
            _serializeBasketItemForFirestore(item),
            SetOptions(merge: true),
          );
        }

        await batch.commit();
      } catch (e) {
        print('Failed to save basket to Firestore: $e');
        // Continue anyway - local storage is saved
      }
    }
  }

  /// Serialize basket item for storage
  Map<String, dynamic> _serializeBasketItem(BasketItem item) {
    return {
      'id': item.id,
      'product': item.product.toJson(), // Use toJson for local storage
      'quantity': item.quantity,
      'addedAt': item.addedAt.toIso8601String(),
      'notes': item.notes,
    };
  }

  /// Deserialize basket item from storage
  BasketItem _deserializeBasketItem(Map<String, dynamic> json) {
    // Convert product data using Product.fromJson
    final productData = json['product'] as Map<String, dynamic>;
    final product = Product.fromJson(productData);

    return BasketItem(
      id: json['id'],
      product: product,
      quantity: json['quantity'],
      addedAt: DateTime.parse(json['addedAt']),
      notes: json['notes'],
    );
  }

  /// Serialize basket item for Firestore
  Map<String, dynamic> _serializeBasketItemForFirestore(BasketItem item) {
    return {
      'id': item.id,
      'product': item.product.toFirestore(), // Use toFirestore for Firestore
      'quantity': item.quantity,
      'addedAt': Timestamp.fromDate(item.addedAt),
      'notes': item.notes,
    };
  }

  /// Deserialize basket item from Firestore document
  BasketItem _deserializeBasketItemFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Convert product data using Product.fromJson (since it's stored as Map)
    final productData = data['product'] as Map<String, dynamic>;
    final product = Product.fromJson(productData);

    return BasketItem(
      id: data['id'] ?? doc.id,
      product: product,
      quantity: data['quantity'],
      addedAt: (data['addedAt'] as Timestamp).toDate(),
      notes: data['notes'],
    );
  }
}
