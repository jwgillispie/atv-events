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

  /// Static method to create a vendor - stub for web build compatibility
  static Future<void> createVendor(dynamic vendorData) async {
    // Stub implementation - vendor features disabled
  }

  /// Instance method to create a vendor - stub
  Future<void> createVendorInstance(ManagedVendor vendor) async {
    // Do nothing - vendor features disabled
  }

  Future<void> updateVendor(String vendorId, Map<String, dynamic> updates) async {
    // Do nothing - vendor features disabled
  }

  Future<void> deleteVendor(String vendorId) async {
    // Do nothing - vendor features disabled
  }

  /// Static methods for compatibility
  static Future<List<ManagedVendor>> getVendorsForMarketAsync(String marketId) async {
    // Return empty list - vendor features disabled
    return [];
  }

  static Stream<List<ManagedVendor>> getVendorsForMarket(String marketId) {
    // Return empty stream - vendor features disabled
    return Stream.value([]);
  }

  static Stream<List<ManagedVendor>> getActiveVendorsForMarket(String marketId) {
    // Return empty stream - vendor features disabled
    return Stream.value([]);
  }
}
