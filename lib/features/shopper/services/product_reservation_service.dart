// TODO: Removed for ATV Events demo - Product reservation features disabled
// This is a stub to maintain compilation

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../vendor/models/vendor_product.dart';
import '../../vendor/models/vendor_post.dart';

class ProductReservation {
  final String id;
  final String productId;
  final String userId;
  final int quantity;
  final DateTime createdAt;
  final String status;

  ProductReservation({
    required this.id,
    required this.productId,
    required this.userId,
    required this.quantity,
    required this.createdAt,
    this.status = 'pending',
  });
}

class ProductReservationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a product reservation
  Future<ProductReservation> createReservation({
    required VendorProduct product,
    required VendorPost vendorPost,
    required Map<String, dynamic> vendorProfile,
    required int quantity,
    String? customerNotes,
    String? customerPhone,
  }) async {
    // Stub implementation - returns a dummy reservation
    final reservationId = _firestore.collection('reservations').doc().id;

    return ProductReservation(
      id: reservationId,
      productId: product.id,
      userId: 'stub_user',
      quantity: quantity,
      createdAt: DateTime.now(),
      status: 'pending',
    );
  }

  Future<void> reserveProduct({
    required String productId,
    required String userId,
    required int quantity,
  }) async {
    // Do nothing - product reservation features disabled
  }

  Future<void> cancelReservation(String reservationId) async {
    // Do nothing - product reservation features disabled
  }

  Future<List<Map<String, dynamic>>> getUserReservations(String userId) async {
    // Return empty list - product reservation features disabled
    return [];
  }

  Stream<List<Map<String, dynamic>>> getUserReservationsStream(String userId) {
    // Return empty stream - product reservation features disabled
    return Stream.value([]);
  }

  Future<void> completeReservation(String reservationId) async {
    // Do nothing - product reservation features disabled
  }
}
