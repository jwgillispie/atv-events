import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:atv_events/features/shared/models/product.dart';
import 'package:atv_events/features/shared/models/user_profile.dart';
import 'package:atv_events/features/shopper/models/product_feed_item.dart';
import 'package:atv_events/utils/firestore_error_logger.dart';

/// Service for managing the product feed
/// Fetches all active products from the permanent catalog
class ProductFeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache for seller profiles to reduce reads
  final Map<String, UserProfile> _sellerProfileCache = {};

  // Pagination settings
  static const int _pageSize = 20;

  /// [DEPRECATED] Fetch products for the feed
  /// No vendor products in ATV Events - organizers sell event tickets and their own products
  Future<List<ProductFeedItem>> fetchProductFeed({
    String? category,
    DocumentSnapshot? lastDocument,
    String? searchQuery,
  }) async {
    // No vendor products in ATV Events
    return [];
  }

  /// Get seller profile with caching
  Future<UserProfile?> _getSellerProfile(String sellerId) async {
    // Check cache first
    if (_sellerProfileCache.containsKey(sellerId)) {
      return _sellerProfileCache[sellerId];
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(sellerId)
          .get();

      if (!doc.exists) return null;

      final profile = UserProfile.fromFirestore(doc);

      // Cache the profile
      _sellerProfileCache[sellerId] = profile;

      return profile;
    } catch (e) {
      return null;
    }
  }

  /// Check if a product is favorited by the current user
  Future<bool> _isProductFavorited(String productId) async {
    // TODO: Integrate with existing favorites system
    return false;
  }

  /// [DEPRECATED] Fetch featured products
  /// No vendor products in ATV Events
  Future<List<ProductFeedItem>> fetchFeaturedProducts({
    int limit = 10,
  }) async {
    // No vendor products in ATV Events
    return [];
  }

  /// Search products by query
  Future<List<ProductFeedItem>> searchProducts({
    required String query,
    String? category,
  }) async {
    if (query.isEmpty) return [];

    return fetchProductFeed(
      searchQuery: query,
      category: category,
    );
  }

  /// [DEPRECATED] Get products by seller
  /// No vendor products in ATV Events
  Future<List<ProductFeedItem>> getSellerProducts({
    required String sellerId,
  }) async {
    // No vendor products in ATV Events
    return [];
  }

  /// Get products by category
  Future<List<ProductFeedItem>> getProductsByCategory(String category) async {
    return fetchProductFeed(category: category);
  }

  /// Clear seller profile cache
  void clearCache() {
    _sellerProfileCache.clear();
  }
}
