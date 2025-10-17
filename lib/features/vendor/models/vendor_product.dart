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
  final String? imageUrl;
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
    this.imageUrl,
    this.category,
    this.available = true,
    required this.createdAt,
    this.metadata,
  });

  factory VendorProduct.fromMap(Map<String, dynamic> map, String id) {
    return VendorProduct(
      id: id,
      vendorId: map['vendorId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      price: (map['price'] as num?)?.toDouble(),
      imageUrl: map['imageUrl'] as String?,
      category: map['category'] as String?,
      available: map['available'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
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
        imageUrl,
        category,
        available,
        createdAt,
        metadata,
      ];
}
