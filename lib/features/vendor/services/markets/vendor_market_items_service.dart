// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:cloud_firestore/cloud_firestore.dart';

class VendorMarketItemsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getMarketItems(String marketId) async {
    // Return empty list - vendor features disabled
    return [];
  }

  Stream<List<Map<String, dynamic>>> getMarketItemsStream(String marketId) {
    // Return empty stream - vendor features disabled
    return Stream.value([]);
  }

  Future<void> addMarketItem(String marketId, Map<String, dynamic> item) async {
    // Do nothing - vendor features disabled
  }

  Future<void> updateMarketItem(String marketId, String itemId, Map<String, dynamic> updates) async {
    // Do nothing - vendor features disabled
  }

  Future<void> deleteMarketItem(String marketId, String itemId) async {
    // Do nothing - vendor features disabled
  }

  /// Static method for compatibility
  static Future<List<Map<String, dynamic>>> getMarketVendorItems(String marketId) async {
    // Return empty list - vendor features disabled
    return [];
  }

  /// Get vendor market items stub
  static Future<VendorMarketItems?> getVendorMarketItems(String vendorId, String marketId) async {
    // Return null - vendor features disabled
    return null;
  }

  /// Get market vendor items stream (instance method)
  Stream<List<Map<String, dynamic>>> getMarketVendorItemsStream(String marketId) {
    // Return empty stream - vendor features disabled
    return Stream.value([]);
  }

  /// Get market vendor items stream (static method for compatibility)
  static Stream<Map<String, List<String>>> getMarketVendorItemsStreamStatic(String marketId) {
    // Return empty stream - vendor features disabled
    return Stream.value({});
  }
}

/// Stub class for vendor market items
class VendorMarketItems {
  final List<String>? itemList;

  VendorMarketItems({this.itemList});
}
