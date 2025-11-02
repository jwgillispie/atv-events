import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:atv_events/features/vendor/models/vendor_product.dart';
import 'package:atv_events/features/vendor/models/vendor_product_list.dart';
import 'package:atv_events/utils/firestore_error_logger.dart';


/// Service for managing vendor's global product catalog
class VendorProductService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _productsCollection = 'vendor_products';
  static const String _listsCollection = 'vendor_product_lists';

  // =============================================================================
  // GLOBAL PRODUCT CATALOG METHODS
  // =============================================================================

  /// Create a new product in vendor's global catalog
  static Future<VendorProduct> createProduct({
    required String vendorId,
    required String name,
    required String category,
    String? description,
    double? basePrice,
    String? imageUrl,
    List<String>? photoUrls,
    List<String>? tags,
  }) async {
    try {
      final now = DateTime.now();
      final productData = {
        'vendorId': vendorId,
        'name': name.trim(),
        'category': category,
        'description': description?.trim(),
        'basePrice': basePrice,
        'imageUrl': imageUrl,
        'photoUrls': photoUrls ?? [],
        'tags': tags ?? [],
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'isActive': true,
      };

      final docRef = await _firestore.collection(_productsCollection).add(productData);
      
      return VendorProduct(
        id: docRef.id,
        vendorId: vendorId,
        name: name.trim(),
        category: category,
        description: description?.trim(),
        basePrice: basePrice,
        imageUrl: imageUrl,
        photoUrls: photoUrls ?? [],
        tags: tags ?? [],
        createdAt: now,
        updatedAt: now,
        isActive: true,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Get all products for a vendor
  static Future<List<VendorProduct>> getVendorProducts(String vendorId) async {
    try {
      FirestoreErrorLogger.logQuery('vendor_products', {
        'vendorId': vendorId,
        'isActive': true,
        'orderBy': 'updatedAt DESC'
      });

      final querySnapshot = await FirestoreErrorLogger.wrapQuery(
        () => _firestore
            .collection(_productsCollection)
            .where('vendorId', isEqualTo: vendorId)
            .where('isActive', isEqualTo: true)
            .orderBy('updatedAt', descending: true)
            .get(),
        'VendorProductService.getVendorProducts(vendorId: $vendorId)',
      );

      return querySnapshot.docs
          .map((doc) => VendorProduct.fromFirestore(doc))
          .toList();
    } catch (e) {
      FirestoreErrorLogger.logError(e, 'VendorProductService.getVendorProducts(vendorId: $vendorId)');
      return [];
    }
  }

  /// Update an existing product
  static Future<VendorProduct> updateProduct({
    required String productId,
    String? name,
    String? category,
    String? description,
    double? basePrice,
    String? imageUrl,
    List<String>? photoUrls,
    List<String>? tags,
    bool? isActive,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (name != null) updateData['name'] = name.trim();
      if (category != null) updateData['category'] = category;
      if (description != null) updateData['description'] = description.trim();
      if (basePrice != null) updateData['basePrice'] = basePrice;
      if (imageUrl != null) updateData['imageUrl'] = imageUrl;
      if (photoUrls != null) updateData['photoUrls'] = photoUrls;
      if (tags != null) updateData['tags'] = tags;
      if (isActive != null) updateData['isActive'] = isActive;

      await _firestore.collection(_productsCollection).doc(productId).update(updateData);

      // Return updated product
      final doc = await _firestore.collection(_productsCollection).doc(productId).get();
      return VendorProduct.fromFirestore(doc);
    } catch (e) {
      rethrow;
    }
  }

  /// Soft delete a product (mark as inactive)
  static Future<void> deleteProduct(String productId) async {
    try {
      debugPrint('VendorProductService: Attempting to delete product: $productId');

      // First check if the document exists
      final doc = await _firestore.collection(_productsCollection).doc(productId).get();
      if (!doc.exists) {
        debugPrint('VendorProductService: Product $productId does not exist');
        throw Exception('Product not found');
      }

      debugPrint('VendorProductService: Product exists, updating to inactive...');
      await _firestore.collection(_productsCollection).doc(productId).update({
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      debugPrint('VendorProductService: Product marked as inactive');
    } catch (e) {
      debugPrint('VendorProductService: Error deleting product: $e');
      rethrow;
    }
  }

  /// Get a single product by ID
  static Future<VendorProduct?> getProduct(String productId) async {
    try {
      final doc = await _firestore.collection(_productsCollection).doc(productId).get();
      if (!doc.exists) return null;
      return VendorProduct.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  // =============================================================================
  // PRODUCT LIST MANAGEMENT METHODS
  // =============================================================================

  /// Create a new product list
  static Future<VendorProductList> createProductList({
    required String vendorId,
    required String name,
    String? description,
    List<String>? productIds,
    String? color,
  }) async {
    try {
      final list = VendorProductList.create(
        vendorId: vendorId,
        name: name,
        description: description,
        productIds: productIds,
        color: color,
      );

      // Validate the list
      final validationError = list.validate();
      if (validationError != null) {
        throw Exception('Invalid product list: $validationError');
      }

      // Save to Firestore
      final docRef = await _firestore
          .collection(_listsCollection)
          .add(list.toFirestore());

      return list.copyWith(id: docRef.id);
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing product list
  static Future<VendorProductList> updateProductList(VendorProductList list) async {
    try {
      if (list.id.isEmpty) {
        throw Exception('Cannot update list without ID');
      }

      // Validate the list
      final validationError = list.validate();
      if (validationError != null) {
        throw Exception('Invalid product list: $validationError');
      }

      final updatedList = list.copyWith(updatedAt: DateTime.now());
      
      await _firestore
          .collection(_listsCollection)
          .doc(list.id)
          .update(updatedList.toFirestore());

      return updatedList;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a product list
  static Future<void> deleteProductList(String listId) async {
    try {
      await _firestore
          .collection(_listsCollection)
          .doc(listId)
          .delete();

    } catch (e) {
      rethrow;
    }
  }

  /// Get all product lists for a vendor
  static Future<List<VendorProductList>> getProductLists(String vendorId) async {
    try {
      FirestoreErrorLogger.logQuery('vendor_product_lists', {
        'vendorId': vendorId,
        'orderBy': 'updatedAt DESC'
      });

      final querySnapshot = await FirestoreErrorLogger.wrapQuery(
        () => _firestore
            .collection(_listsCollection)
            .where('vendorId', isEqualTo: vendorId)
            .orderBy('updatedAt', descending: true)
            .get(),
        'VendorProductService.getProductLists(vendorId: $vendorId)',
      );

      return querySnapshot.docs
          .map((doc) => VendorProductList.fromFirestore(doc))
          .toList();
    } catch (e) {
      FirestoreErrorLogger.logError(e, 'VendorProductService.getProductLists(vendorId: $vendorId)');
      return [];
    }
  }

  /// Get a specific product list
  static Future<VendorProductList?> getProductList(String listId) async {
    try {
      final docSnapshot = await _firestore
          .collection(_listsCollection)
          .doc(listId)
          .get();

      if (docSnapshot.exists) {
        return VendorProductList.fromFirestore(docSnapshot);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Add product to a list
  static Future<VendorProductList> addProductToList(
    String listId, 
    String productId
  ) async {
    try {
      final list = await getProductList(listId);
      if (list == null) {
        throw Exception('Product list not found');
      }

      final updatedList = list.addProduct(productId);
      return await updateProductList(updatedList);
    } catch (e) {
      rethrow;
    }
  }

  /// Remove product from a list
  static Future<VendorProductList> removeProductFromList(
    String listId, 
    String productId
  ) async {
    try {
      final list = await getProductList(listId);
      if (list == null) {
        throw Exception('Product list not found');
      }

      final updatedList = list.removeProduct(productId);
      return await updateProductList(updatedList);
    } catch (e) {
      rethrow;
    }
  }

  /// Get products that belong to a specific list
  static Future<List<VendorProduct>> getProductsInList(String listId) async {
    try {
      final list = await getProductList(listId);
      if (list == null) return [];

      if (list.productIds.isEmpty) return [];

      // Get all products that are in this list
      final products = <VendorProduct>[];
      for (final productId in list.productIds) {
        try {
          final product = await getProduct(productId);
          if (product != null) {
            products.add(product);
          }
        } catch (e) {
          // Continue loading other products even if one fails
          FirestoreErrorLogger.logError(e, 'VendorProductService.getProductsFromList(productId: $productId)');
        }
      }

      return products;
    } catch (e) {
      return [];
    }
  }

  /// Get lists that contain a specific product
  static Future<List<VendorProductList>> getListsContainingProduct(
    String vendorId, 
    String productId
  ) async {
    try {
      final allLists = await getProductLists(vendorId);
      return allLists
          .where((list) => list.containsProduct(productId))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
