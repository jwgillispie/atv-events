import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Simplified Product model for ATV shop
/// No popup/market associations - products are permanent catalog items
class Product extends Equatable {
  final String id;
  final String sellerId;
  final String sellerName;
  final String? sellerImageUrl;
  final String name;
  final String category;
  final String? description;
  final double? price;
  final List<String> imageUrls;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  // Inventory
  final int? stockQuantity; // null = unlimited
  final bool isInStock;

  // Waitlist
  final bool waitlistEnabled;
  final int waitlistCount;
  final int? maxWaitlistSize;

  // Analytics
  final int viewCount;
  final int likeCount;
  final int shareCount;
  final int orderCount;

  // Reviews
  final double? productRating;
  final int? productReviewCount;

  const Product({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    this.sellerImageUrl,
    required this.name,
    required this.category,
    this.description,
    this.price,
    this.imageUrls = const [],
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.stockQuantity,
    this.isInStock = true,
    this.waitlistEnabled = true,
    this.waitlistCount = 0,
    this.maxWaitlistSize,
    this.viewCount = 0,
    this.likeCount = 0,
    this.shareCount = 0,
    this.orderCount = 0,
    this.productRating,
    this.productReviewCount,
  });


  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Product(
      id: doc.id,
      sellerId: data['sellerId'] ?? data['vendorId'] ?? '',
      sellerName: data['sellerName'] ?? data['vendorName'] ?? 'ATV Shop',
      sellerImageUrl: data['sellerImageUrl'] ?? data['vendorImageUrl'],
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      description: data['description'],
      price: data['price']?.toDouble(),
      imageUrls: data['imageUrls'] != null
          ? List<String>.from(data['imageUrls'])
          : [],
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      stockQuantity: data['stockQuantity'] ?? data['quantityAvailable'],
      isInStock: data['isInStock'] ?? true,
      waitlistEnabled: data['waitlistEnabled'] ?? true,
      waitlistCount: data['waitlistCount'] ?? 0,
      maxWaitlistSize: data['maxWaitlistSize'] as int?,
      viewCount: data['viewCount'] ?? 0,
      likeCount: data['likeCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      orderCount: data['orderCount'] ?? data['preOrderCount'] ?? 0,
      productRating: data['productRating']?.toDouble(),
      productReviewCount: data['productReviewCount'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerImageUrl': sellerImageUrl,
      'name': name,
      'category': category,
      'description': description,
      'price': price,
      'imageUrls': imageUrls,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'stockQuantity': stockQuantity,
      'isInStock': isInStock,
      'waitlistEnabled': waitlistEnabled,
      'waitlistCount': waitlistCount,
      'maxWaitlistSize': maxWaitlistSize,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'shareCount': shareCount,
      'orderCount': orderCount,
      'productRating': productRating,
      'productReviewCount': productReviewCount,
    };
  }

  /// Convert to JSON for local storage (no Firestore Timestamps)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerImageUrl': sellerImageUrl,
      'name': name,
      'category': category,
      'description': description,
      'price': price,
      'imageUrls': imageUrls,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
      'stockQuantity': stockQuantity,
      'isInStock': isInStock,
      'waitlistEnabled': waitlistEnabled,
      'waitlistCount': waitlistCount,
      'maxWaitlistSize': maxWaitlistSize,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'shareCount': shareCount,
      'orderCount': orderCount,
      'productRating': productRating,
      'productReviewCount': productReviewCount,
    };
  }

  /// Create Product from JSON (for local storage deserialization)
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      sellerId: json['sellerId'] ?? json['vendorId'] ?? '',
      sellerName: json['sellerName'] ?? json['vendorName'] ?? 'ATV Shop',
      sellerImageUrl: json['sellerImageUrl'] ?? json['vendorImageUrl'],
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      description: json['description'],
      price: json['price']?.toDouble(),
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isActive: json['isActive'] ?? true,
      stockQuantity: json['stockQuantity'],
      isInStock: json['isInStock'] ?? true,
      waitlistEnabled: json['waitlistEnabled'] ?? true,
      waitlistCount: json['waitlistCount'] ?? 0,
      maxWaitlistSize: json['maxWaitlistSize'],
      viewCount: json['viewCount'] ?? 0,
      likeCount: json['likeCount'] ?? 0,
      shareCount: json['shareCount'] ?? 0,
      orderCount: json['orderCount'] ?? 0,
      productRating: json['productRating']?.toDouble(),
      productReviewCount: json['productReviewCount'],
    );
  }

  /// Backward compatibility - vendorId maps to sellerId
  String get vendorId => sellerId;

  /// Backward compatibility - vendorName maps to sellerName
  String get vendorName => sellerName;

  /// Format price display
  String get formattedPrice {
    if (price == null) return 'Price TBD';
    if (price! % 1 == 0) {
      return '\$${price!.toInt()}';
    }
    return '\$${price!.toStringAsFixed(2)}';
  }

  /// Get primary image URL
  String? get primaryImageUrl {
    return imageUrls.isNotEmpty ? imageUrls.first : null;
  }

  /// Check if product has media
  bool get hasMedia {
    return imageUrls.isNotEmpty;
  }

  /// Check if out of stock
  bool get isOutOfStock {
    return stockQuantity != null && stockQuantity! <= 0;
  }

  /// Check if can join waitlist
  bool get canJoinWaitlist {
    if (!waitlistEnabled || !isOutOfStock) return false;
    if (maxWaitlistSize == null) return true;
    return waitlistCount < maxWaitlistSize!;
  }

  /// Get availability status
  String get availabilityStatus {
    if (isInStock) {
      if (stockQuantity == null) return 'In Stock';
      return '$stockQuantity available';
    }
    if (canJoinWaitlist) {
      return 'Out of Stock - Join Waitlist';
    }
    return 'Out of Stock';
  }

  Product copyWith({
    String? id,
    String? sellerId,
    String? sellerName,
    String? sellerImageUrl,
    String? name,
    String? category,
    String? description,
    double? price,
    List<String>? imageUrls,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    int? stockQuantity,
    bool? isInStock,
    bool? waitlistEnabled,
    int? waitlistCount,
    int? maxWaitlistSize,
    int? viewCount,
    int? likeCount,
    int? shareCount,
    int? orderCount,
    double? productRating,
    int? productReviewCount,
  }) {
    return Product(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerImageUrl: sellerImageUrl ?? this.sellerImageUrl,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrls: imageUrls ?? this.imageUrls,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isInStock: isInStock ?? this.isInStock,
      waitlistEnabled: waitlistEnabled ?? this.waitlistEnabled,
      waitlistCount: waitlistCount ?? this.waitlistCount,
      maxWaitlistSize: maxWaitlistSize ?? this.maxWaitlistSize,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      shareCount: shareCount ?? this.shareCount,
      orderCount: orderCount ?? this.orderCount,
      productRating: productRating ?? this.productRating,
      productReviewCount: productReviewCount ?? this.productReviewCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        sellerId,
        sellerName,
        name,
        category,
        price,
        stockQuantity,
        waitlistCount,
      ];
}
