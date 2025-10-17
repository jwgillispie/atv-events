// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class VendorProduct extends Equatable {
  final String id;
  final String vendorId;
  final String name;
  final String? description;
  final double? price;
  final double? basePrice; // Base price for compatibility
  final String? imageUrl;
  final List<String> photoUrls; // Multiple photo URLs
  final String? category;
  final bool available;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const VendorProduct({
    required this.id,
    required this.vendorId,
    required this.name,
    this.description,
    this.price,
    double? basePrice,
    this.imageUrl,
    this.photoUrls = const [],
    this.category,
    this.available = true,
    required this.createdAt,
    this.metadata,
  }) : basePrice = basePrice ?? price;

  /// Getter for backward compatibility with imageUrls field
  List<String> get imageUrls => photoUrls.isNotEmpty ? photoUrls : (imageUrl != null ? [imageUrl!] : []);

  /// Additional getters for compatibility
  List<String> get tags => []; // Stub - tags not implemented
  DateTime? get updatedAt => createdAt; // Stub - use createdAt as fallback
  bool get isActive => available; // Map available to isActive
  int? get quantityAvailable => null; // Stub - quantity tracking not implemented

  factory VendorProduct.fromMap(Map<String, dynamic> map, String id) {
    return VendorProduct(
      id: id,
      vendorId: map['vendorId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      price: (map['price'] as num?)?.toDouble(),
      basePrice: (map['basePrice'] as num?)?.toDouble(),
      imageUrl: map['imageUrl'] as String?,
      photoUrls: (map['photoUrls'] as List?)?.cast<String>() ?? [],
      category: map['category'] as String?,
      available: map['available'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Factory constructor from Firestore DocumentSnapshot
  factory VendorProduct.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }
    return VendorProduct.fromMap(data, doc.id);
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return toMap();
  }

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'name': name,
      'description': description,
      'price': price,
      'basePrice': basePrice,
      'imageUrl': imageUrl,
      'photoUrls': photoUrls,
      'category': category,
      'available': available,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [
        id,
        vendorId,
        name,
        description,
        price,
        basePrice,
        imageUrl,
        photoUrls,
        category,
        available,
        createdAt,
        metadata,
      ];
}
