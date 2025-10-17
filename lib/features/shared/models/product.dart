import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:hipop/features/vendor/models/vendor_product.dart';

// Payment options removed - everything is preorder only

/// Product model optimized for shopper feed display
/// Includes pre-order support and enhanced media capabilities
class Product extends Equatable {
  final String id;
  final String vendorId;
  final String vendorName;
  final String vendorImageUrl;
  final String name;
  final String category;
  final String? description;
  final double? price;
  final double? compareAtPrice; // For showing discounts
  final List<String> imageUrls;
  final String? videoUrl;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  // Pre-order fields
  final bool isPreOrder;
  final DateTime? preOrderAvailableDate;
  final int? preOrderQuantityLimit;
  final int? preOrderQuantitySold;
  final String? preOrderNotes;

  // Market/Event association
  final String? marketId;
  final String? marketName;
  final String? eventId;
  final String? eventName;
  final DateTime? eventDate;

  // Location info for proximity features
  final String? location;
  final double? latitude;
  final double? longitude;

  // Inventory
  final int? stockQuantity;
  final bool isInStock;

  // Analytics
  final int viewCount;
  final int likeCount;
  final int shareCount;
  final int preOrderCount;

  // Additional vendor info
  final String? vendorInstagram;
  final double? vendorRating;
  final int? vendorReviewCount;

  // Product review info
  final double? productRating;
  final int? productReviewCount;

  // Popup association fields (from VendorPost)
  final String? popupId; // VendorPost ID
  final DateTime? popupStartTime;
  final DateTime? popupEndTime;
  final String? popupLocation;
  final double? popupLatitude;
  final double? popupLongitude;

  const Product({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    this.vendorImageUrl = '',
    required this.name,
    required this.category,
    this.description,
    this.price,
    this.compareAtPrice,
    this.imageUrls = const [],
    this.videoUrl,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.isPreOrder = false,
    this.preOrderAvailableDate,
    this.preOrderQuantityLimit,
    this.preOrderQuantitySold,
    this.preOrderNotes,
    this.marketId,
    this.marketName,
    this.eventId,
    this.eventName,
    this.eventDate,
    this.location,
    this.latitude,
    this.longitude,
    this.stockQuantity,
    this.isInStock = true,
    this.viewCount = 0,
    this.likeCount = 0,
    this.shareCount = 0,
    this.preOrderCount = 0,
    this.vendorInstagram,
    this.vendorRating,
    this.vendorReviewCount,
    this.productRating,
    this.productReviewCount,
    this.popupId,
    this.popupStartTime,
    this.popupEndTime,
    this.popupLocation,
    this.popupLatitude,
    this.popupLongitude,
  });

  /// Create Product from VendorProduct for compatibility
  factory Product.fromVendorProduct(VendorProduct vendorProduct, {
    String? vendorName,
    String? vendorImageUrl,
    String? marketId,
    String? marketName,
    String? location,
    double? latitude,
    double? longitude,
    double? vendorRating,
    int? vendorReviewCount,
  }) {
    // All products are preorder-only now

    return Product(
      id: vendorProduct.id,
      vendorId: vendorProduct.vendorId,
      vendorName: vendorName ?? 'Unknown Vendor',
      vendorImageUrl: vendorImageUrl ?? '',
      name: vendorProduct.name,
      category: vendorProduct.category,
      description: vendorProduct.description,
      price: vendorProduct.basePrice,
      imageUrls: vendorProduct.photoUrls.isNotEmpty
          ? vendorProduct.photoUrls
          : (vendorProduct.imageUrl != null ? [vendorProduct.imageUrl!] : []),
      tags: vendorProduct.tags,
      createdAt: vendorProduct.createdAt,
      updatedAt: vendorProduct.updatedAt,
      isActive: vendorProduct.isActive,
      marketId: marketId,
      marketName: marketName,
      location: location,
      latitude: latitude,
      longitude: longitude,
      stockQuantity: vendorProduct.quantityAvailable,
      isInStock: vendorProduct.quantityAvailable == null || vendorProduct.quantityAvailable! > 0,
      vendorRating: vendorRating,
      vendorReviewCount: vendorReviewCount,
      productRating: null,
      productReviewCount: null,
      // Popup fields will be set when product is assigned to a popup
      popupId: null,
      popupStartTime: null,
      popupEndTime: null,
      popupLocation: null,
      popupLatitude: null,
      popupLongitude: null,
    );
  }


  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Product(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      vendorName: data['vendorName'] ?? 'Unknown Vendor',
      vendorImageUrl: data['vendorImageUrl'] ?? '',
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      description: data['description'],
      price: data['price']?.toDouble(),
      compareAtPrice: data['compareAtPrice']?.toDouble(),
      imageUrls: data['imageUrls'] != null
          ? List<String>.from(data['imageUrls'])
          : [],
      videoUrl: data['videoUrl'],
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      isPreOrder: data['isPreOrder'] ?? false,
      preOrderAvailableDate: data['preOrderAvailableDate'] != null
          ? (data['preOrderAvailableDate'] as Timestamp).toDate()
          : null,
      preOrderQuantityLimit: data['preOrderQuantityLimit'],
      preOrderQuantitySold: data['preOrderQuantitySold'] ?? 0,
      preOrderNotes: data['preOrderNotes'],
      marketId: data['marketId'],
      marketName: data['marketName'],
      eventId: data['eventId'],
      eventName: data['eventName'],
      eventDate: data['eventDate'] != null
          ? (data['eventDate'] as Timestamp).toDate()
          : null,
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      stockQuantity: data['stockQuantity'] ?? data['quantityAvailable'],
      isInStock: data['isInStock'] ?? true,
      viewCount: data['viewCount'] ?? 0,
      likeCount: data['likeCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      preOrderCount: data['preOrderCount'] ?? 0,
      vendorInstagram: data['vendorInstagram'],
      vendorRating: data['vendorRating']?.toDouble(),
      vendorReviewCount: data['vendorReviewCount'],
      productRating: data['productRating']?.toDouble(),
      productReviewCount: data['productReviewCount'],
      popupId: data['popupId'],
      popupStartTime: data['popupStartTime'] != null
          ? (data['popupStartTime'] as Timestamp).toDate()
          : null,
      popupEndTime: data['popupEndTime'] != null
          ? (data['popupEndTime'] as Timestamp).toDate()
          : null,
      popupLocation: data['popupLocation'],
      popupLatitude: data['popupLatitude']?.toDouble(),
      popupLongitude: data['popupLongitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'vendorName': vendorName,
      'vendorImageUrl': vendorImageUrl,
      'name': name,
      'category': category,
      'description': description,
      'price': price,
      'compareAtPrice': compareAtPrice,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'isPreOrder': isPreOrder,
      'preOrderAvailableDate': preOrderAvailableDate != null
          ? Timestamp.fromDate(preOrderAvailableDate!)
          : null,
      'preOrderQuantityLimit': preOrderQuantityLimit,
      'preOrderQuantitySold': preOrderQuantitySold,
      'preOrderNotes': preOrderNotes,
      'marketId': marketId,
      'marketName': marketName,
      'eventId': eventId,
      'eventName': eventName,
      'eventDate': eventDate != null ? Timestamp.fromDate(eventDate!) : null,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'stockQuantity': stockQuantity,
      'isInStock': isInStock,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'shareCount': shareCount,
      'preOrderCount': preOrderCount,
      'vendorInstagram': vendorInstagram,
      'vendorRating': vendorRating,
      'vendorReviewCount': vendorReviewCount,
      'productRating': productRating,
      'productReviewCount': productReviewCount,
      'popupId': popupId,
      'popupStartTime': popupStartTime != null ? Timestamp.fromDate(popupStartTime!) : null,
      'popupEndTime': popupEndTime != null ? Timestamp.fromDate(popupEndTime!) : null,
      'popupLocation': popupLocation,
      'popupLatitude': popupLatitude,
      'popupLongitude': popupLongitude,
    };
  }

  /// Convert to JSON for local storage (no Firestore Timestamps)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'vendorImageUrl': vendorImageUrl,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'compareAtPrice': compareAtPrice,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
      'isPreOrder': isPreOrder,
      'preOrderAvailableDate': preOrderAvailableDate?.toIso8601String(),
      'preOrderQuantityLimit': preOrderQuantityLimit,
      'preOrderQuantitySold': preOrderQuantitySold,
      'preOrderNotes': preOrderNotes,
      'marketId': marketId,
      'marketName': marketName,
      'eventId': eventId,
      'eventName': eventName,
      'eventDate': eventDate?.toIso8601String(),
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'stockQuantity': stockQuantity,
      'isInStock': isInStock,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'shareCount': shareCount,
      'preOrderCount': preOrderCount,
      'vendorInstagram': vendorInstagram,
      'vendorRating': vendorRating,
      'vendorReviewCount': vendorReviewCount,
      'productRating': productRating,
      'productReviewCount': productReviewCount,
      'popupId': popupId,
      'popupStartTime': popupStartTime?.toIso8601String(),
      'popupEndTime': popupEndTime?.toIso8601String(),
      'popupLocation': popupLocation,
      'popupLatitude': popupLatitude,
      'popupLongitude': popupLongitude,
    };
  }

  /// Create Product from JSON (for local storage deserialization)
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      vendorId: json['vendorId'],
      vendorName: json['vendorName'] ?? '',
      vendorImageUrl: json['vendorImageUrl'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      category: json['category'] ?? 'Other',
      price: json['price']?.toDouble(),
      compareAtPrice: json['compareAtPrice']?.toDouble(),
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      videoUrl: json['videoUrl'],
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isActive: json['isActive'] ?? true,
      isPreOrder: json['isPreOrder'] ?? false,
      preOrderAvailableDate: json['preOrderAvailableDate'] != null
          ? DateTime.parse(json['preOrderAvailableDate'])
          : null,
      preOrderQuantityLimit: json['preOrderQuantityLimit'],
      preOrderQuantitySold: json['preOrderQuantitySold'] ?? 0,
      preOrderNotes: json['preOrderNotes'],
      marketId: json['marketId'],
      marketName: json['marketName'],
      eventId: json['eventId'],
      eventName: json['eventName'],
      eventDate: json['eventDate'] != null
          ? DateTime.parse(json['eventDate'])
          : null,
      location: json['location'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      stockQuantity: json['stockQuantity'],
      isInStock: json['isInStock'] ?? true,
      viewCount: json['viewCount'] ?? 0,
      likeCount: json['likeCount'] ?? 0,
      shareCount: json['shareCount'] ?? 0,
      preOrderCount: json['preOrderCount'] ?? 0,
      vendorInstagram: json['vendorInstagram'],
      vendorRating: json['vendorRating']?.toDouble(),
      vendorReviewCount: json['vendorReviewCount'],
      productRating: json['productRating']?.toDouble(),
      productReviewCount: json['productReviewCount'],
      popupId: json['popupId'],
      popupStartTime: json['popupStartTime'] != null
          ? DateTime.parse(json['popupStartTime'])
          : null,
      popupEndTime: json['popupEndTime'] != null
          ? DateTime.parse(json['popupEndTime'])
          : null,
      popupLocation: json['popupLocation'],
      popupLatitude: json['popupLatitude']?.toDouble(),
      popupLongitude: json['popupLongitude']?.toDouble(),
    );
  }

  /// Check if pre-order is still available
  bool get isPreOrderAvailable {
    if (!isPreOrder) return false;

    // Check if we've reached the limit
    if (preOrderQuantityLimit != null && preOrderQuantitySold != null) {
      if (preOrderQuantitySold! >= preOrderQuantityLimit!) {
        return false;
      }
    }

    // Check if pre-order date has passed
    if (preOrderAvailableDate != null) {
      if (DateTime.now().isAfter(preOrderAvailableDate!)) {
        return false;
      }
    }

    return true;
  }

  /// Check if the popup is currently active
  bool get isPopupActive {
    if (popupStartTime == null || popupEndTime == null) return false;
    final now = DateTime.now();
    return now.isAfter(popupStartTime!) && now.isBefore(popupEndTime!);
  }

  /// Check if the popup hasn't started yet
  bool get isPopupUpcoming {
    if (popupStartTime == null) return false;
    return DateTime.now().isBefore(popupStartTime!);
  }

  /// Check if the popup has ended
  bool get isPopupEnded {
    if (popupEndTime == null) return false;
    return DateTime.now().isAfter(popupEndTime!);
  }

  /// Get remaining pre-order quantity
  int? get remainingPreOrderQuantity {
    if (!isPreOrder || preOrderQuantityLimit == null) return null;
    final sold = preOrderQuantitySold ?? 0;
    return preOrderQuantityLimit! - sold;
  }

  /// Format price display
  String get formattedPrice {
    if (price == null) return 'Price TBD';
    return '\$${price!.toStringAsFixed(2)}';
  }

  /// Format compare at price display
  String? get formattedCompareAtPrice {
    if (compareAtPrice == null) return null;
    return '\$${compareAtPrice!.toStringAsFixed(2)}';
  }

  /// Calculate discount percentage
  int? get discountPercentage {
    if (price == null || compareAtPrice == null) return null;
    if (compareAtPrice! <= price!) return null;

    final discount = ((compareAtPrice! - price!) / compareAtPrice!) * 100;
    return discount.round();
  }

  /// Get primary image URL
  String? get primaryImageUrl {
    return imageUrls.isNotEmpty ? imageUrls.first : null;
  }

  /// Check if product has media
  bool get hasMedia {
    return imageUrls.isNotEmpty || videoUrl != null;
  }

  Product copyWith({
    String? id,
    String? vendorId,
    String? vendorName,
    String? vendorImageUrl,
    String? name,
    String? category,
    String? description,
    double? price,
    double? compareAtPrice,
    List<String>? imageUrls,
    String? videoUrl,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    bool? isPreOrder,
    DateTime? preOrderAvailableDate,
    int? preOrderQuantityLimit,
    int? preOrderQuantitySold,
    String? preOrderNotes,
    String? marketId,
    String? marketName,
    String? eventId,
    String? eventName,
    DateTime? eventDate,
    String? location,
    double? latitude,
    double? longitude,
    int? stockQuantity,
    bool? isInStock,
    int? viewCount,
    int? likeCount,
    int? shareCount,
    int? preOrderCount,
    String? vendorInstagram,
    double? vendorRating,
    int? vendorReviewCount,
    double? productRating,
    int? productReviewCount,
    String? popupId,
    DateTime? popupStartTime,
    DateTime? popupEndTime,
    String? popupLocation,
    double? popupLatitude,
    double? popupLongitude,
  }) {
    return Product(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      vendorImageUrl: vendorImageUrl ?? this.vendorImageUrl,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      price: price ?? this.price,
      compareAtPrice: compareAtPrice ?? this.compareAtPrice,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      isPreOrder: isPreOrder ?? this.isPreOrder,
      preOrderAvailableDate: preOrderAvailableDate ?? this.preOrderAvailableDate,
      preOrderQuantityLimit: preOrderQuantityLimit ?? this.preOrderQuantityLimit,
      preOrderQuantitySold: preOrderQuantitySold ?? this.preOrderQuantitySold,
      preOrderNotes: preOrderNotes ?? this.preOrderNotes,
      marketId: marketId ?? this.marketId,
      marketName: marketName ?? this.marketName,
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      eventDate: eventDate ?? this.eventDate,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isInStock: isInStock ?? this.isInStock,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      shareCount: shareCount ?? this.shareCount,
      preOrderCount: preOrderCount ?? this.preOrderCount,
      vendorInstagram: vendorInstagram ?? this.vendorInstagram,
      vendorRating: vendorRating ?? this.vendorRating,
      vendorReviewCount: vendorReviewCount ?? this.vendorReviewCount,
      productRating: productRating ?? this.productRating,
      productReviewCount: productReviewCount ?? this.productReviewCount,
      popupId: popupId ?? this.popupId,
      popupStartTime: popupStartTime ?? this.popupStartTime,
      popupEndTime: popupEndTime ?? this.popupEndTime,
      popupLocation: popupLocation ?? this.popupLocation,
      popupLatitude: popupLatitude ?? this.popupLatitude,
      popupLongitude: popupLongitude ?? this.popupLongitude,
    );
  }

  @override
  List<Object?> get props => [
    id,
    vendorId,
    vendorName,
    name,
    category,
    price,
    isPreOrder,
    preOrderAvailableDate,
    marketId,
    eventId,
  ];
}