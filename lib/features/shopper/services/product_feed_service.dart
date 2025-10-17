// TODO: Removed for ATV MVP - Product feed service stub
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:atv_events/features/shopper/models/product_feed_item.dart';

/// Service for fetching and managing product feed
/// Stub implementation for ATV Events MVP
class ProductFeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch product feed with optional filters
  Future<List<ProductFeedItem>> fetchProductFeed({
    String? category,
    DocumentSnapshot? lastDocument,
    Position? userLocation,
    String? searchQuery,
    bool onlyAvailableNow = false,
  }) async {
    // TODO: Implement product feed logic for ATV Events
    // For now, return empty list since vendor features are removed
    return [];
  }

  /// Search products
  Future<List<ProductFeedItem>> searchProducts({
    required String query,
    String? category,
    Position? userLocation,
  }) async {
    // TODO: Implement search logic
    return [];
  }

  /// Clear cache
  void clearCache() {
    // TODO: Implement cache clearing
  }
}
