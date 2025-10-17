// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/managed_vendor.dart';

class ManagedVendorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Static method to get a vendor
  static Future<ManagedVendor?> getVendor(String vendorId) async {
    // Return null - vendor features disabled
    return null;
  }

  /// Instance method to get a vendor
  Future<ManagedVendor?> getVendorInstance(String vendorId) async {
    // Return null - vendor features disabled
    return null;
  }

  Stream<ManagedVendor?> getVendorStream(String vendorId) {
    // Return empty stream - vendor features disabled
    return Stream.value(null);
  }

  Stream<List<ManagedVendor>> getVendors() {
    // Return empty stream - vendor features disabled
    return Stream.value([]);
  }

  Future<void> createVendor(ManagedVendor vendor) async {
    // Do nothing - vendor features disabled
  }

  Future<void> updateVendor(String vendorId, Map<String, dynamic> updates) async {
    // Do nothing - vendor features disabled
  }

  Future<void> deleteVendor(String vendorId) async {
    // Do nothing - vendor features disabled
  }
}
