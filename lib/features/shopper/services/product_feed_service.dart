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

  /// Fetch products for the feed
  /// Shows all active products from the permanent catalog
  Future<List<ProductFeedItem>> fetchProductFeed({
    String? category,
    DocumentSnapshot? lastDocument,
    String? searchQuery,
  }) async {
    try {
      final feedItems = <ProductFeedItem>[];

      // Query vendor_products collection for active products
      Query query = _firestore
          .collection('vendor_products')
          .where('isActive', isEqualTo: true);

      // Apply category filter
      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      // Order by most recently updated
      query = query.orderBy('updatedAt', descending: true);

      // Apply pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(_pageSize);

      FirestoreErrorLogger.logQuery('vendor_products', {
        'isActive': true,
        'category': category,
        'orderBy': 'updatedAt',
        'limit': _pageSize,
      });

      final snapshot = await FirestoreErrorLogger.wrapQuery(
        () => query.get(),
        'ProductFeedService.fetchProductFeed(category: $category)',
      );

      if (snapshot.docs.isEmpty) {
        return [];
      }

      // Process each product
      for (final doc in snapshot.docs) {
        final vendorProduct = VendorProduct.fromFirestore(doc);

        // Apply search filter if provided
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final searchLower = searchQuery.toLowerCase();
          final nameMatch = vendorProduct.name.toLowerCase().contains(searchLower);
          final categoryMatch = vendorProduct.category.toLowerCase().contains(searchLower);
          final descriptionMatch = vendorProduct.description?.toLowerCase().contains(searchLower) ?? false;
          final tagsMatch = vendorProduct.tags.any((tag) => tag.toLowerCase().contains(searchLower));

          if (!nameMatch && !categoryMatch && !descriptionMatch && !tagsMatch) {
            continue;
          }
        }

        // Get seller profile
        final sellerProfile = await _getSellerProfile(vendorProduct.vendorId);
        if (sellerProfile == null) continue;

        // Convert VendorProduct to Product model
        final product = Product.fromVendorProduct(
          vendorProduct,
          sellerName: sellerProfile.businessName ?? sellerProfile.displayName,
          sellerImageUrl: sellerProfile.profilePhotoUrl,
        );

        // Check if product is favorited (placeholder for now)
        final isFavorited = await _isProductFavorited(product.id);

        // Create feed item
        final feedItem = ProductFeedItem(
          product: product,
          sellerProfile: sellerProfile,
          distance: null, // Location-based distance can be added later
          isFavorited: isFavorited,
        );

        feedItems.add(feedItem);
      }

      return feedItems;
    } catch (e) {
      FirestoreErrorLogger.logError(e, 'ProductFeedService.fetchProductFeed(category: $category)');
      throw Exception('Failed to fetch product feed: $e');
    }
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

  /// Fetch featured products
  Future<List<ProductFeedItem>> fetchFeaturedProducts({
    int limit = 10,
  }) async {
    try {
      // Get recently added or updated products
      final query = _firestore
          .collection('vendor_products')
          .where('isActive', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .limit(limit);

      final snapshot = await query.get();

      final feedItems = <ProductFeedItem>[];

      for (final doc in snapshot.docs) {
        final vendorProduct = VendorProduct.fromFirestore(doc);

        final sellerProfile = await _getSellerProfile(vendorProduct.vendorId);
        if (sellerProfile == null) continue;

        final product = Product.fromVendorProduct(
          vendorProduct,
          sellerName: sellerProfile.businessName ?? sellerProfile.displayName,
          sellerImageUrl: sellerProfile.profilePhotoUrl,
        );

        feedItems.add(ProductFeedItem(
          product: product,
          sellerProfile: sellerProfile,
          isFavorited: false,
        ));
      }

      return feedItems;
    } catch (e) {
      throw Exception('Failed to fetch featured products: $e');
    }
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

  /// Get products by seller
  Future<List<ProductFeedItem>> getSellerProducts({
    required String sellerId,
  }) async {
    try {
      final query = _firestore
          .collection('vendor_products')
          .where('vendorId', isEqualTo: sellerId)
          .where('isActive', isEqualTo: true)
          .orderBy('updatedAt', descending: true);

      final snapshot = await query.get();

      final sellerProfile = await _getSellerProfile(sellerId);
      if (sellerProfile == null) return [];

      final feedItems = <ProductFeedItem>[];

      for (final doc in snapshot.docs) {
        final vendorProduct = VendorProduct.fromFirestore(doc);

        final product = Product.fromVendorProduct(
          vendorProduct,
          sellerName: sellerProfile.businessName ?? sellerProfile.displayName,
          sellerImageUrl: sellerProfile.profilePhotoUrl,
        );

        feedItems.add(ProductFeedItem(
          product: product,
          sellerProfile: sellerProfile,
          isFavorited: false,
        ));
      }

      return feedItems;
    } catch (e) {
      throw Exception('Failed to get seller products: $e');
    }
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
