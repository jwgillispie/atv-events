import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

abstract class ProductFeedEvent extends Equatable {
  const ProductFeedEvent();

  @override
  List<Object?> get props => [];
}

/// Load initial products
class LoadProductsRequested extends ProductFeedEvent {
  final String? category;
  final Position? userLocation;
  final bool onlyAvailableNow;
  final bool nearbyOnly;
  final String? location;

  const LoadProductsRequested({
    this.category,
    this.userLocation,
    this.onlyAvailableNow = false,
    this.nearbyOnly = true,
    this.location,
  });

  @override
  List<Object?> get props => [category, userLocation, onlyAvailableNow, nearbyOnly, location];
}

/// Load more products (pagination)
class LoadMoreProductsRequested extends ProductFeedEvent {
  const LoadMoreProductsRequested();
}

/// Refresh the product feed
class RefreshProductsRequested extends ProductFeedEvent {
  const RefreshProductsRequested();
}

/// Filter products by category
class FilterByCategoryChanged extends ProductFeedEvent {
  final String? category;

  const FilterByCategoryChanged(this.category);

  @override
  List<Object?> get props => [category];
}

/// Search products
class SearchProductsRequested extends ProductFeedEvent {
  final String query;

  const SearchProductsRequested(this.query);

  @override
  List<Object?> get props => [query];
}

/// Clear search/filters
class ClearFiltersRequested extends ProductFeedEvent {
  const ClearFiltersRequested();
}

/// Toggle availability filter
class ToggleAvailableNowFilter extends ProductFeedEvent {
  final bool onlyAvailableNow;

  const ToggleAvailableNowFilter(this.onlyAvailableNow);

  @override
  List<Object?> get props => [onlyAvailableNow];
}

/// Update user location for distance calculations
class UpdateUserLocation extends ProductFeedEvent {
  final Position userLocation;

  const UpdateUserLocation(this.userLocation);

  @override
  List<Object?> get props => [userLocation];
}

/// Toggle favorite status for a product
class ToggleProductFavorite extends ProductFeedEvent {
  final String productId;

  const ToggleProductFavorite(this.productId);

  @override
  List<Object?> get props => [productId];
}

/// Alias for FilterByCategoryChanged for better naming consistency
class FilterProductsByCategory extends ProductFeedEvent {
  final String category;

  const FilterProductsByCategory(this.category);

  @override
  List<Object?> get props => [category];
}