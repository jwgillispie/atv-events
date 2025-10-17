import 'package:equatable/equatable.dart';
import 'package:atv_events/features/vendor/models/vendor_product.dart';
import 'package:atv_events/features/vendor/models/vendor_post.dart';
import 'package:atv_events/features/shared/models/user_profile.dart';

/// Product Feed Item combining product, vendor info, and availability
/// This model represents a product in the shopper feed with all necessary context
class ProductFeedItem extends Equatable {
  final VendorProduct product;
  final UserProfile vendorProfile;
  final VendorPost? nextAvailability; // Next popup where this product will be available
  final List<VendorPost> upcomingAvailabilities; // All upcoming popups with this product
  final double? distance; // Distance from user's location (in miles)
  final bool isFavorited;
  final DateTime? lastUpdated;

  const ProductFeedItem({
    required this.product,
    required this.vendorProfile,
    this.nextAvailability,
    this.upcomingAvailabilities = const [],
    this.distance,
    this.isFavorited = false,
    this.lastUpdated,
  });

  /// Get vendor display name
  String get vendorName => vendorProfile.businessName ?? vendorProfile.displayName ?? 'Unknown Vendor';

  /// Get vendor Instagram handle
  String? get vendorInstagramHandle => vendorProfile.instagramHandle;

  /// Get vendor website
  String? get vendorWebsite => vendorProfile.website;

  /// Check if product is currently available (vendor has active popup now)
  bool get isAvailableNow {
    if (nextAvailability == null) return false;
    return nextAvailability!.isHappening;
  }

  /// Get next availability display text
  String get nextAvailabilityText {
    if (nextAvailability == null) {
      return 'No upcoming popups';
    }
    if (nextAvailability!.isHappening) {
      return 'Available now at ${nextAvailability!.locationName ?? nextAvailability!.location}';
    }
    return nextAvailability!.formattedDateTime;
  }

  /// Get location for next availability
  String? get nextLocation {
    return nextAvailability?.locationName ?? nextAvailability?.location;
  }

  /// Get coordinates for next availability
  double? get nextLatitude => nextAvailability?.latitude;
  double? get nextLongitude => nextAvailability?.longitude;

  /// Check if has location data
  bool get hasLocationData {
    return nextLatitude != null && nextLongitude != null;
  }

  /// Get distance display text
  String get distanceText {
    if (distance == null) return '';
    if (distance! < 0.1) return 'Very close';
    if (distance! < 1) return '${(distance! * 5280).toStringAsFixed(0)} ft away';
    return '${distance!.toStringAsFixed(1)} mi away';
  }

  /// Get availability status color code
  String get availabilityStatus {
    if (isAvailableNow) return 'now';
    if (nextAvailability != null && nextAvailability!.isUpcoming) {
      final hoursUntil = nextAvailability!.popUpStartDateTime.difference(DateTime.now()).inHours;
      if (hoursUntil <= 24) return 'today';
      if (hoursUntil <= 48) return 'tomorrow';
      if (hoursUntil <= 168) return 'this_week';
    }
    return 'future';
  }

  /// Create a copy with updated fields
  ProductFeedItem copyWith({
    VendorProduct? product,
    UserProfile? vendorProfile,
    VendorPost? nextAvailability,
    List<VendorPost>? upcomingAvailabilities,
    double? distance,
    bool? isFavorited,
    DateTime? lastUpdated,
  }) {
    return ProductFeedItem(
      product: product ?? this.product,
      vendorProfile: vendorProfile ?? this.vendorProfile,
      nextAvailability: nextAvailability ?? this.nextAvailability,
      upcomingAvailabilities: upcomingAvailabilities ?? this.upcomingAvailabilities,
      distance: distance ?? this.distance,
      isFavorited: isFavorited ?? this.isFavorited,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [
    product,
    vendorProfile,
    nextAvailability,
    upcomingAvailabilities,
    distance,
    isFavorited,
    lastUpdated,
  ];
}