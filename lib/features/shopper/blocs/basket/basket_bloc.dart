import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:atv_events/features/shopper/blocs/basket/basket_event.dart';
import 'package:atv_events/features/shopper/blocs/basket/basket_state.dart';
import 'package:atv_events/features/shopper/models/basket_item.dart';
import 'package:atv_events/features/shopper/services/product_reservation_service.dart';
import 'package:atv_events/features/vendor/models/vendor_product.dart';
import 'package:atv_events/features/vendor/models/vendor_post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:atv_events/features/shared/models/user_profile.dart';
import 'package:atv_events/features/shared/models/product.dart';

/// BLoC for managing the reservation basket
class BasketBloc extends Bloc<BasketEvent, BasketState> {
  final ProductReservationService _reservationService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? userId;
  static const String _basketKey = 'hipop_basket';
  final _uuid = const Uuid();

  BasketBloc({
    ProductReservationService? reservationService,
    this.userId,
  }) : _reservationService = reservationService ?? ProductReservationService(),
        super(BasketInitial()) {
    on<LoadBasket>(_onLoadBasket);
    on<AddToBasket>(_onAddToBasket);
    on<RemoveFromBasket>(_onRemoveFromBasket);
    on<UpdateBasketItemQuantity>(_onUpdateQuantity);
    on<UpdatePickupTimeSlot>(_onUpdatePickupTimeSlot);
    on<UpdateBasketItemNotes>(_onUpdateNotes);
    on<ClearBasket>(_onClearBasket);
    on<ConfirmReservations>(_onConfirmReservations);
    on<RemovePopupItems>(_onRemovePopupItems);

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

      // Filter out expired items and verify vendor posts still exist
      final validItems = await _validateBasketItems(items);

      emit(BasketLoaded(items: validItems));

      // Save if we filtered any items
      if (validItems.length != items.length) {
        await _saveBasket(validItems);
      }
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

  /// Validate basket items by checking:
  /// 1. If the item is still upcoming (not expired)
  /// 2. If the vendor post still exists (skip for direct purchases)
  Future<List<BasketItem>> _validateBasketItems(List<BasketItem> items) async {
    final validItems = <BasketItem>[];

    // Get vendor post IDs that need validation (exclude direct purchases)
    final vendorPostIds = items
        .map((item) => item.vendorPostId)
        .where((id) => !id.startsWith('direct-'))
        .toSet();

    // Batch check which vendor posts still exist
    final existingPosts = <String>{};
    for (final postId in vendorPostIds) {
      try {
        final postDoc = await _firestore
            .collection('vendor_posts')
            .doc(postId)
            .get();

        if (postDoc.exists) {
          existingPosts.add(postId);
        }
      } catch (e) {
        // Post doesn't exist or error accessing it
        print('Error checking vendor post $postId: $e');
      }
    }

    // Filter items
    for (final item in items) {
      // Check if item is still upcoming
      if (!item.isUpcoming) {
        print('Removing expired basket item: ${item.product.name}');
        continue;
      }

      // Check if vendor post still exists (skip validation for direct purchases)
      final isDirectPurchase = item.vendorPostId.startsWith('direct-');
      if (!isDirectPurchase && !existingPosts.contains(item.vendorPostId)) {
        print('Removing basket item for deleted vendor post: ${item.product.name}');
        continue;
      }

      validItems.add(item);
    }

    // Log cleanup statistics
    if (items.length != validItems.length) {
      print('Basket cleanup: ${items.length - validItems.length} items removed (${items.length} -> ${validItems.length})');
    }

    return validItems;
  }

  /// Add product to basket
  Future<void> _onAddToBasket(AddToBasket event, Emitter<BasketState> emit) async {
    final currentState = state;
    if (currentState is! BasketLoaded) return;

    try {
      // Check if product already in basket for this popup
      final existingIndex = currentState.items.indexWhere(
        (item) => item.product.id == event.product.id &&
                  item.vendorPostId == event.vendorPostId,
      );

      List<BasketItem> updatedItems;

      if (existingIndex != -1) {
        // Update quantity if already exists
        updatedItems = List.from(currentState.items);
        final existing = updatedItems[existingIndex];
        updatedItems[existingIndex] = existing.copyWith(
          quantity: existing.quantity + event.quantity,
          // Keep the original payment preference unless different
          isPaymentItem: event.isPaymentItem,
          paidAmount: event.isPaymentItem
            ? (event.product.price != null ? event.product.price! * (existing.quantity + event.quantity) : null)
            : null,
        );
      } else {
        // Add new item
        final newItem = BasketItem(
          id: _uuid.v4(),
          product: event.product,
          vendorPostId: event.vendorPostId,
          marketId: event.marketId,
          marketName: event.marketName,
          popupDateTime: event.popupDateTime,
          popupLocation: event.popupLocation,
          quantity: event.quantity,
          addedAt: DateTime.now(),
          notes: event.notes,
          isPaymentItem: event.isPaymentItem,
          paidAmount: event.isPaymentItem ? event.product.price : null,
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

  /// Update pickup time slot
  Future<void> _onUpdatePickupTimeSlot(UpdatePickupTimeSlot event, Emitter<BasketState> emit) async {
    final currentState = state;
    if (currentState is! BasketLoaded) return;

    try {
      final updatedItems = currentState.items.map((item) {
        if (item.id == event.itemId) {
          return item.copyWith(selectedPickupSlot: event.slot);
        }
        return item;
      }).toList();

      emit(currentState.copyWith(items: updatedItems));
      await _saveBasket(updatedItems);
    } catch (e) {
      emit(BasketError(
        message: 'Failed to update pickup time: $e',
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

  /// Confirm reservations for a popup
  Future<void> _onConfirmReservations(ConfirmReservations event, Emitter<BasketState> emit) async {
    final currentState = state;
    if (currentState is! BasketLoaded) return;

    emit(currentState.copyWith(
      isSubmitting: true,
      submittingVendorPostId: event.vendorPostId,
    ));

    try {
      // Get items for this popup
      final popupItems = currentState.items
          .where((item) => item.vendorPostId == event.vendorPostId)
          .toList();

      if (popupItems.isEmpty) {
        throw Exception('No items found for this popup');
      }

      // Get vendor post details and verify it still exists
      final vendorPostDoc = await _firestore
          .collection('vendor_posts')
          .doc(event.vendorPostId)
          .get();

      if (!vendorPostDoc.exists) {
        // Vendor post has been deleted - remove items from basket
        await _handleDeletedVendorPost(event.vendorPostId, currentState, emit);
        throw Exception('This popup event has been cancelled. Your basket has been updated.');
      }

      final vendorPost = VendorPost.fromFirestore(vendorPostDoc);
      final reservationIds = <String>[];

      // Create reservations for each item
      for (final item in popupItems) {
        // Get vendor profile
        final vendorDoc = await _firestore
            .collection('users')
            .doc(item.product.vendorId)
            .get();

        if (!vendorDoc.exists) {
          throw Exception('Vendor not found');
        }

        final vendorProfile = UserProfile.fromFirestore(vendorDoc);

        // Create vendor product from product model
        final vendorProduct = VendorProduct(
          id: item.product.id,
          vendorId: item.product.vendorId,
          name: item.product.name,
          description: item.product.description,
          category: item.product.category,
          basePrice: item.product.price,
          photoUrls: item.product.imageUrls,
          createdAt: item.product.createdAt,
        );

        // Create reservation
        final reservation = await _reservationService.createReservation(
          product: vendorProduct,
          vendorPost: vendorPost,
          vendorProfile: vendorProfile.toFirestore(),
          quantity: item.quantity,
          customerNotes: '${item.notes ?? ''}\nPickup Time: ${item.selectedPickupSlot?.label ?? 'Flexible'}',
          customerPhone: event.customerPhone,
        );

        reservationIds.add(reservation.id);
      }

      // Remove confirmed items from basket
      final remainingItems = currentState.items
          .where((item) => item.vendorPostId != event.vendorPostId)
          .toList();

      await _saveBasket(remainingItems);

      // Show success state briefly
      emit(BasketReservationSuccess(
        vendorPostId: event.vendorPostId,
        itemCount: popupItems.length,
        reservationIds: reservationIds,
      ));

      // Return to loaded state after delay
      await Future.delayed(const Duration(seconds: 2));
      emit(BasketLoaded(items: remainingItems));

    } catch (e) {
      emit(BasketError(
        message: 'Failed to confirm reservations: $e',
        previousItems: currentState.items,
      ));

      // Return to loaded state after error
      await Future.delayed(const Duration(seconds: 2));
      emit(currentState.copyWith(isSubmitting: false, submittingVendorPostId: null));
    }
  }

  /// Remove all items for a specific popup
  Future<void> _onRemovePopupItems(RemovePopupItems event, Emitter<BasketState> emit) async {
    final currentState = state;
    if (currentState is! BasketLoaded) return;

    try {
      final updatedItems = currentState.items
          .where((item) => item.vendorPostId != event.vendorPostId)
          .toList();

      emit(currentState.copyWith(items: updatedItems));
      await _saveBasket(updatedItems);
    } catch (e) {
      emit(BasketError(
        message: 'Failed to remove popup items: $e',
        previousItems: currentState.items,
      ));
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
      'vendorPostId': item.vendorPostId,
      'marketId': item.marketId,
      'marketName': item.marketName,
      'popupDateTime': item.popupDateTime.toIso8601String(),
      'popupLocation': item.popupLocation,
      'quantity': item.quantity,
      'addedAt': item.addedAt.toIso8601String(),
      'notes': item.notes,
      'selectedPickupSlot': item.selectedPickupSlot?.index,
      'isPaymentItem': item.isPaymentItem,
      'paidAmount': item.paidAmount,
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
      vendorPostId: json['vendorPostId'],
      marketId: json['marketId'],
      marketName: json['marketName'],
      popupDateTime: DateTime.parse(json['popupDateTime']),
      popupLocation: json['popupLocation'],
      quantity: json['quantity'],
      addedAt: DateTime.parse(json['addedAt']),
      notes: json['notes'],
      selectedPickupSlot: json['selectedPickupSlot'] != null
          ? PickupTimeSlot.values[json['selectedPickupSlot']]
          : null,
      isPaymentItem: json['isPaymentItem'] ?? false,
      paidAmount: json['paidAmount'] != null ? (json['paidAmount'] as num).toDouble() : null,
    );
  }

  /// Serialize basket item for Firestore
  Map<String, dynamic> _serializeBasketItemForFirestore(BasketItem item) {
    return {
      'id': item.id,
      'product': item.product.toFirestore(), // Use toFirestore for Firestore
      'vendorPostId': item.vendorPostId,
      'marketId': item.marketId,
      'marketName': item.marketName,
      'popupDateTime': Timestamp.fromDate(item.popupDateTime),
      'popupLocation': item.popupLocation,
      'quantity': item.quantity,
      'addedAt': Timestamp.fromDate(item.addedAt),
      'notes': item.notes,
      'selectedPickupSlot': item.selectedPickupSlot?.index,
      'isPaymentItem': item.isPaymentItem,
      'paidAmount': item.paidAmount,
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
      vendorPostId: data['vendorPostId'],
      marketId: data['marketId'],
      marketName: data['marketName'],
      popupDateTime: (data['popupDateTime'] as Timestamp).toDate(),
      popupLocation: data['popupLocation'],
      quantity: data['quantity'],
      addedAt: (data['addedAt'] as Timestamp).toDate(),
      notes: data['notes'],
      selectedPickupSlot: data['selectedPickupSlot'] != null
          ? PickupTimeSlot.values[data['selectedPickupSlot']]
          : null,
      isPaymentItem: data['isPaymentItem'] ?? false,
      paidAmount: data['paidAmount'] != null ? (data['paidAmount'] as num).toDouble() : null,
    );
  }

  /// Handle the case where a vendor post has been deleted
  Future<void> _handleDeletedVendorPost(
    String vendorPostId,
    BasketLoaded currentState,
    Emitter<BasketState> emit,
  ) async {
    // Remove all items for the deleted vendor post
    final remainingItems = currentState.items
        .where((item) => item.vendorPostId != vendorPostId)
        .toList();

    // Save updated basket
    await _saveBasket(remainingItems);

    // Emit updated state
    emit(BasketLoaded(items: remainingItems));
  }

  /// Periodically validate basket items (can be called on app resume)
  Future<void> revalidateBasket() async {
    final currentState = state;
    if (currentState is! BasketLoaded) return;

    final validItems = await _validateBasketItems(currentState.items);

    if (validItems.length != currentState.items.length) {
      add(LoadBasket()); // Reload basket with validation
    }
  }
}