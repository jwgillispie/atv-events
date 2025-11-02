import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Product catalog item for ATV shop
/// Permanent products available for purchase with inventory management
class VendorProduct extends Equatable {
  final String id;
  final String vendorId;
  final String name;
  final String category;
  final String? description;
  final double? basePrice;
  final String? imageUrl; // @deprecated Use photoUrls instead
  final List<String> photoUrls;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final int? quantityAvailable; // null = unlimited

  // Waitlist support
  final bool waitlistEnabled;
  final int waitlistCount;
  final int? maxWaitlistSize; // null = unlimited waitlist

  // All products require payment upfront

  const VendorProduct({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.category,
    this.description,
    this.basePrice,
    this.imageUrl,
    this.photoUrls = const [],
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.quantityAvailable,
    this.waitlistEnabled = true,
    this.waitlistCount = 0,
    this.maxWaitlistSize,
  });

  /// Get formatted display price
  String get displayPrice {
    if (basePrice == null) return 'Price varies';
    if (basePrice! % 1 == 0) {
      return '\$${basePrice!.toInt()}';
    }
    return '\$${basePrice!.toStringAsFixed(2)}';
  }

  factory VendorProduct.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return VendorProduct(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      description: data['description'],
      basePrice: data['basePrice']?.toDouble(),
      imageUrl: data['imageUrl'],
      photoUrls: data['photoUrls'] != null
          ? List<String>.from(data['photoUrls'])
          : (data['imageUrl'] != null ? [data['imageUrl']] : []), // Migration support
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      quantityAvailable: data['quantityAvailable'] as int?,
      waitlistEnabled: data['waitlistEnabled'] ?? true,
      waitlistCount: data['waitlistCount'] ?? 0,
      maxWaitlistSize: data['maxWaitlistSize'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'name': name,
      'category': category,
      'description': description,
      'basePrice': basePrice,
      'imageUrl': imageUrl,
      'photoUrls': photoUrls,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'quantityAvailable': quantityAvailable,
      'waitlistEnabled': waitlistEnabled,
      'waitlistCount': waitlistCount,
      'maxWaitlistSize': maxWaitlistSize,
    };
  }

  VendorProduct copyWith({
    String? id,
    String? vendorId,
    String? name,
    String? category,
    String? description,
    double? basePrice,
    String? imageUrl,
    List<String>? photoUrls,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    int? quantityAvailable,
    bool? waitlistEnabled,
    int? waitlistCount,
    int? maxWaitlistSize,
  }) {
    return VendorProduct(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      basePrice: basePrice ?? this.basePrice,
      imageUrl: imageUrl ?? this.imageUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      quantityAvailable: quantityAvailable ?? this.quantityAvailable,
      waitlistEnabled: waitlistEnabled ?? this.waitlistEnabled,
      waitlistCount: waitlistCount ?? this.waitlistCount,
      maxWaitlistSize: maxWaitlistSize ?? this.maxWaitlistSize,
    );
  }

  @override
  List<Object?> get props => [
        id,
        vendorId,
        name,
        category,
        description,
        basePrice,
        imageUrl,
        photoUrls,
        tags,
        createdAt,
        updatedAt,
        isActive,
        quantityAvailable,
        waitlistEnabled,
        waitlistCount,
        maxWaitlistSize,
      ];

  @override
  String toString() {
    return 'VendorProduct(id: $id, vendorId: $vendorId, name: $name, category: $category)';
  }

  /// Common product categories for vendors
  static const List<String> commonCategories = [
    'Artisan Goods',
    'Baked Goods',
    'Beverages',
    'Clothing & Accessories',
    'Crafts & Handmade',
    'Food & Produce',
    'Health & Beauty',
    'Home & Garden',
    'Jewelry',
    'Prepared Foods',
    'Specialty Items',
    'Other',
  ];

  /// Get all image URLs (combines photoUrls with imageUrl for migration)
  List<String> get allImageUrls {
    final urls = <String>[];
    urls.addAll(photoUrls);
    if (imageUrl != null && !urls.contains(imageUrl)) {
      urls.add(imageUrl!);
    }
    return urls;
  }

  /// Check if product has valid data for creation
  bool get isValid {
    return name.isNotEmpty && 
           category.isNotEmpty && 
           vendorId.isNotEmpty;
  }


  /// Get formatted tags string
  String get formattedTags {
    return tags.join(', ');
  }

  /// Get primary image URL (first photo or imageUrl for backward compatibility)
  String? get primaryImageUrl {
    if (photoUrls.isNotEmpty) {
      return photoUrls.first;
    }
    return imageUrl;
  }

  /// Check if product has any images
  bool get hasImages {
    return photoUrls.isNotEmpty || imageUrl != null;
  }

  /// Check if product is out of stock
  bool get isOutOfStock {
    return quantityAvailable != null && quantityAvailable! <= 0;
  }

  /// Check if product is in stock
  bool get inStock {
    return quantityAvailable == null || quantityAvailable! > 0;
  }

  /// Check if waitlist is available
  bool get canJoinWaitlist {
    if (!waitlistEnabled || !isOutOfStock) return false;
    if (maxWaitlistSize == null) return true;
    return waitlistCount < maxWaitlistSize!;
  }

  /// Check if waitlist is full
  bool get isWaitlistFull {
    if (maxWaitlistSize == null) return false;
    return waitlistCount >= maxWaitlistSize!;
  }

  /// Get availability status text
  String get availabilityStatus {
    if (inStock) {
      if (quantityAvailable == null) return 'In Stock';
      return '$quantityAvailable available';
    }
    if (canJoinWaitlist) {
      return 'Out of Stock - Join Waitlist';
    }
    if (isWaitlistFull) {
      return 'Out of Stock - Waitlist Full';
    }
    return 'Out of Stock';
  }

}