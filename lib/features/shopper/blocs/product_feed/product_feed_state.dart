import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hipop/features/shopper/models/product_feed_item.dart';

abstract class ProductFeedState extends Equatable {
  const ProductFeedState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class ProductFeedInitial extends ProductFeedState {
  const ProductFeedInitial();
}

/// Loading state
class ProductFeedLoading extends ProductFeedState {
  const ProductFeedLoading();
}

/// Loaded state with products
class ProductFeedLoaded extends ProductFeedState {
  final List<ProductFeedItem> products;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final String? currentCategory;
  final String? searchQuery;
  final bool onlyAvailableNow;
  final Position? userLocation;
  final DocumentSnapshot? lastDocument;
  final DateTime lastUpdated;

  ProductFeedLoaded({
    required this.products,
    this.hasReachedMax = false,
    this.isLoadingMore = false,
    this.currentCategory,
    this.searchQuery,
    this.onlyAvailableNow = false,
    this.userLocation,
    this.lastDocument,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  /// Check if feed is filtered
  bool get isFiltered {
    return currentCategory != null ||
           searchQuery != null ||
           onlyAvailableNow;
  }

  /// Get unique categories from loaded products
  List<String> get availableCategories {
    final categories = <String>{};
    for (final item in products) {
      categories.add(item.product.category);
    }
    return categories.toList()..sort();
  }

  /// Get products available now
  List<ProductFeedItem> get productsAvailableNow {
    return products.where((item) => item.isAvailableNow).toList();
  }

  /// Get products by category
  List<ProductFeedItem> getProductsByCategory(String category) {
    return products.where((item) => item.product.category == category).toList();
  }

  ProductFeedLoaded copyWith({
    List<ProductFeedItem>? products,
    bool? hasReachedMax,
    bool? isLoadingMore,
    String? currentCategory,
    String? searchQuery,
    bool? onlyAvailableNow,
    Position? userLocation,
    DocumentSnapshot? lastDocument,
    DateTime? lastUpdated,
  }) {
    return ProductFeedLoaded(
      products: products ?? this.products,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      currentCategory: currentCategory ?? this.currentCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      onlyAvailableNow: onlyAvailableNow ?? this.onlyAvailableNow,
      userLocation: userLocation ?? this.userLocation,
      lastDocument: lastDocument ?? this.lastDocument,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [
    products,
    hasReachedMax,
    isLoadingMore,
    currentCategory,
    searchQuery,
    onlyAvailableNow,
    userLocation,
    lastDocument,
    lastUpdated,
  ];
}

/// Error state
class ProductFeedError extends ProductFeedState {
  final String message;
  final String? details;

  const ProductFeedError({
    required this.message,
    this.details,
  });

  @override
  List<Object?> get props => [message, details];
}

/// Empty state (no products found)
class ProductFeedEmpty extends ProductFeedState {
  final String? currentCategory;
  final String? searchQuery;
  final bool onlyAvailableNow;

  const ProductFeedEmpty({
    this.currentCategory,
    this.searchQuery,
    this.onlyAvailableNow = false,
  });

  /// Get appropriate empty message
  String get emptyMessage {
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      return 'No products found for "$searchQuery"';
    }
    if (currentCategory != null) {
      return 'No products found in $currentCategory';
    }
    if (onlyAvailableNow) {
      return 'No products available right now';
    }
    return 'No products available';
  }

  @override
  List<Object?> get props => [currentCategory, searchQuery, onlyAvailableNow];
}