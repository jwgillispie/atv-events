import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents a custom product list created by a vendor
/// Examples: "Grant Park List", "Summer Items", "Bestsellers", etc.
/// 
/// Allows vendors to organize their products into named collections
/// that can be easily assigned to specific markets
class VendorProductList extends Equatable {
  final String id;
  final String vendorId;
  final String name;
  final String? description;
  final List<String> productIds;
  final String? color; // Optional color coding for UI
  final DateTime createdAt;
  final DateTime updatedAt;

  const VendorProductList({
    required this.id,
    required this.vendorId,
    required this.name,
    this.description,
    required this.productIds,
    this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a new product list
  factory VendorProductList.create({
    required String vendorId,
    required String name,
    String? description,
    List<String>? productIds,
    String? color,
  }) {
    final now = DateTime.now();
    return VendorProductList(
      id: '', // Will be set by Firestore
      vendorId: vendorId,
      name: name.trim(),
      description: description?.trim(),
      productIds: productIds ?? [],
      color: color,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create from Firestore document
  factory VendorProductList.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VendorProductList(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      productIds: List<String>.from(data['productIds'] ?? []),
      color: data['color'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'name': name,
      'description': description,
      'productIds': productIds,
      'color': color,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated fields
  VendorProductList copyWith({
    String? id,
    String? vendorId,
    String? name,
    String? description,
    List<String>? productIds,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VendorProductList(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      description: description ?? this.description,
      productIds: productIds ?? this.productIds,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Add product to list
  VendorProductList addProduct(String productId) {
    if (productIds.contains(productId)) return this;
    return copyWith(
      productIds: [...productIds, productId],
      updatedAt: DateTime.now(),
    );
  }

  /// Remove product from list
  VendorProductList removeProduct(String productId) {
    if (!productIds.contains(productId)) return this;
    return copyWith(
      productIds: productIds.where((id) => id != productId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// Get display name with product count
  String get displayName => '$name (${productIds.length} products)';

  /// Check if list is empty
  bool get isEmpty => productIds.isEmpty;

  /// Check if list contains a specific product
  bool containsProduct(String productId) => productIds.contains(productId);

  /// Get product count
  int get productCount => productIds.length;

  /// Validate the product list
  String? validate() {
    if (name.isEmpty) {
      return 'List name is required';
    }
    if (name.length > 100) {
      return 'List name must be less than 100 characters';
    }
    if (description != null && description!.length > 500) {
      return 'Description must be less than 500 characters';
    }
    if (productIds.length > 200) {
      return 'Cannot have more than 200 products in a single list';
    }
    return null;
  }

  /// Get suggested colors for lists
  static List<String> get suggestedColors => [
    '#FF6B6B', // Red
    '#4ECDC4', // Teal
    '#45B7D1', // Blue
    '#96CEB4', // Green
    '#FFEAA7', // Yellow
    '#DDA0DD', // Plum
    '#98D8C8', // Mint
    '#F7DC6F', // Gold
    '#BB8FCE', // Lavender
    '#F8C471', // Orange
  ];

  @override
  List<Object?> get props => [
        id,
        vendorId,
        name,
        description,
        productIds,
        color,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'VendorProductList(id: $id, name: $name, productCount: ${productIds.length})';
  }
}