// TODO: Removed for ATV Events demo - Product reservation features disabled
// This is a stub to maintain compilation

import 'package:cloud_firestore/cloud_firestore.dart';

class ProductReservationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
