import 'package:equatable/equatable.dart';
import 'package:atv_events/features/shared/models/product.dart';
import 'package:atv_events/features/shared/models/user_profile.dart';

/// Product Feed Item for ATV shop
/// Combines product with seller information for display in shopper feed
class ProductFeedItem extends Equatable {
  final Product product;
  final UserProfile sellerProfile;
  final double? distance; // Distance from user's location (in miles)
  final bool isFavorited;

  const ProductFeedItem({
    required this.product,
    required this.sellerProfile,
    this.distance,
    this.isFavorited = false,
  });

  /// Get seller display name
  String get sellerName => sellerProfile.businessName ?? sellerProfile.displayName ?? 'Unknown Seller';

  /// Get seller Instagram handle
  String? get sellerInstagramHandle => sellerProfile.instagramHandle;

  /// Get seller website
  String? get sellerWebsite => sellerProfile.website;

  /// Get seller profile image
  String? get sellerImageUrl => sellerProfile.profilePhotoUrl;

  /// Get distance display text
  String get distanceText {
    if (distance == null) return '';
    if (distance! < 0.1) return 'Very close';
    if (distance! < 1) return '${(distance! * 5280).toStringAsFixed(0)} ft away';
    return '${distance!.toStringAsFixed(1)} mi away';
  }

  /// Get availability status for display
  String get availabilityStatus {
    if (product.isInStock) {
      if (product.stockQuantity == null) return 'In Stock';
      if (product.stockQuantity! > 10) return 'In Stock';
      if (product.stockQuantity! > 0) return 'Low Stock';
    }
    if (product.canJoinWaitlist) return 'Join Waitlist';
    return 'Out of Stock';
  }

  /// Get status color code for UI
  String get statusColorCode {
    if (product.isInStock) return 'success';
    if (product.canJoinWaitlist) return 'warning';
    return 'error';
  }

  /// Check if product can be added to basket
  bool get canAddToBasket {
    return product.isInStock && product.isActive;
  }

  /// Create a copy with updated fields
  ProductFeedItem copyWith({
    Product? product,
    UserProfile? sellerProfile,
    double? distance,
    bool? isFavorited,
  }) {
    return ProductFeedItem(
      product: product ?? this.product,
      sellerProfile: sellerProfile ?? this.sellerProfile,
      distance: distance ?? this.distance,
      isFavorited: isFavorited ?? this.isFavorited,
    );
  }

  @override
  List<Object?> get props => [
    product,
    sellerProfile,
    distance,
    isFavorited,
  ];
}
