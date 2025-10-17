// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:cloud_firestore/cloud_firestore.dart';

class VendorContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendContactMessage({
    required String vendorId,
    required String userId,
    required String message,
  }) async {
    // Do nothing - vendor features disabled
  }

  Future<List<Map<String, dynamic>>> getContactMessages(String vendorId) async {
    // Return empty list - vendor features disabled
    return [];
  }
}
