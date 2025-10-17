import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:atv_events/features/shopper/blocs/product_feed/product_feed_event.dart';
import 'package:atv_events/features/shopper/blocs/product_feed/product_feed_state.dart';
import 'package:atv_events/features/shopper/models/product_feed_item.dart';
import 'package:atv_events/features/shopper/services/product_feed_service.dart';

/// BLoC for managing product feed state and business logic
/// Handles product loading, filtering, pagination, and caching
class ProductFeedBloc extends Bloc<ProductFeedEvent, ProductFeedState> {
  final ProductFeedService _productFeedService;

  // Cache settings
  static const Duration _cacheValidity = Duration(minutes: 5);
  DateTime? _lastFetchTime;
  List<ProductFeedItem>? _cachedProducts;

  // Pagination tracking
  DocumentSnapshot? _lastDocument;
  bool _hasReachedMax = false;

  // Current filters
  String? _currentCategory;
  String? _searchQuery;
  bool _onlyAvailableNow = false;
  Position? _userLocation;

  ProductFeedBloc({
    ProductFeedService? productFeedService,
  })  : _productFeedService = productFeedService ?? ProductFeedService(),
        super(const ProductFeedInitial()) {
    // Register event handlers
    on<LoadProductsRequested>(_onLoadProductsRequested);
    on<LoadMoreProductsRequested>(_onLoadMoreProductsRequested);
    on<RefreshProductsRequested>(_onRefreshProductsRequested);
    on<FilterByCategoryChanged>(_onFilterByCategoryChanged);
    on<SearchProductsRequested>(_onSearchProductsRequested);
    on<ClearFiltersRequested>(_onClearFiltersRequested);
    on<ToggleAvailableNowFilter>(_onToggleAvailableNowFilter);
    on<UpdateUserLocation>(_onUpdateUserLocation);
    on<ToggleProductFavorite>(_onToggleProductFavorite);
  }

  /// Handle initial product loading
  Future<void> _onLoadProductsRequested(
    LoadProductsRequested event,
    Emitter<ProductFeedState> emit,
  ) async {
    try {
      // Check cache validity
      if (_isCacheValid() && _cachedProducts != null && event.category == _currentCategory) {
        emit(ProductFeedLoaded(
          products: _cachedProducts!,
          hasReachedMax: _hasReachedMax,
          currentCategory: _currentCategory,
          searchQuery: _searchQuery,
          onlyAvailableNow: _onlyAvailableNow,
          userLocation: _userLocation,
          lastDocument: _lastDocument,
          lastUpdated: _lastFetchTime ?? DateTime.now(),
        ));
        return;
      }

      emit(const ProductFeedLoading());

      // Update filters
      _currentCategory = event.category;
      _userLocation = event.userLocation ?? _userLocation;
      _onlyAvailableNow = event.onlyAvailableNow;

      // Reset pagination
      _lastDocument = null;
      _hasReachedMax = false;

      // Fetch products
      final products = await _productFeedService.fetchProductFeed(
        category: _currentCategory,
        userLocation: _userLocation,
        onlyAvailableNow: _onlyAvailableNow,
      );

      if (products.isEmpty) {
        emit(ProductFeedEmpty(
          currentCategory: _currentCategory,
          searchQuery: _searchQuery,
          onlyAvailableNow: _onlyAvailableNow,
        ));
        return;
      }

      // Update cache
      _cachedProducts = products;
      _lastFetchTime = DateTime.now();

      // Track last document for pagination
      if (products.isNotEmpty) {
        // Note: We'll need to modify the service to return the last document
        // For now, we'll track based on product count
        _hasReachedMax = products.length < 20; // Assuming page size is 20
      }

      emit(ProductFeedLoaded(
        products: products,
        hasReachedMax: _hasReachedMax,
        currentCategory: _currentCategory,
        searchQuery: _searchQuery,
        onlyAvailableNow: _onlyAvailableNow,
        userLocation: _userLocation,
        lastDocument: _lastDocument,
        lastUpdated: DateTime.now(),
      ));
    } catch (e) {
      emit(ProductFeedError(
        message: 'Failed to load products',
        details: e.toString(),
      ));
    }
  }

  /// Handle loading more products (pagination)
  Future<void> _onLoadMoreProductsRequested(
    LoadMoreProductsRequested event,
    Emitter<ProductFeedState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProductFeedLoaded) return;
    if (currentState.hasReachedMax || currentState.isLoadingMore) return;

    try {
      emit(currentState.copyWith(isLoadingMore: true));

      // Fetch more products
      final moreProducts = await _productFeedService.fetchProductFeed(
        category: _currentCategory,
        lastDocument: _lastDocument,
        userLocation: _userLocation,
        searchQuery: _searchQuery,
        onlyAvailableNow: _onlyAvailableNow,
      );

      if (moreProducts.isEmpty) {
        emit(currentState.copyWith(
          hasReachedMax: true,
          isLoadingMore: false,
        ));
        return;
      }

      // Combine with existing products
      final allProducts = [...currentState.products, ...moreProducts];

      // Update cache
      _cachedProducts = allProducts;
      _hasReachedMax = moreProducts.length < 20;

      emit(ProductFeedLoaded(
        products: allProducts,
        hasReachedMax: _hasReachedMax,
        isLoadingMore: false,
        currentCategory: _currentCategory,
        searchQuery: _searchQuery,
        onlyAvailableNow: _onlyAvailableNow,
        userLocation: _userLocation,
        lastDocument: _lastDocument,
        lastUpdated: DateTime.now(),
      ));
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  /// Handle refresh
  Future<void> _onRefreshProductsRequested(
    RefreshProductsRequested event,
    Emitter<ProductFeedState> emit,
  ) async {
    // Clear cache
    _cachedProducts = null;
    _lastFetchTime = null;
    _lastDocument = null;
    _hasReachedMax = false;

    // Reload products
    add(LoadProductsRequested(
      category: _currentCategory,
      userLocation: _userLocation,
      onlyAvailableNow: _onlyAvailableNow,
    ));
  }

  /// Handle category filter change
  Future<void> _onFilterByCategoryChanged(
    FilterByCategoryChanged event,
    Emitter<ProductFeedState> emit,
  ) async {
    if (_currentCategory == event.category) return;

    _currentCategory = event.category;
    _searchQuery = null; // Clear search when changing category

    add(LoadProductsRequested(
      category: _currentCategory,
      userLocation: _userLocation,
      onlyAvailableNow: _onlyAvailableNow,
    ));
  }

  /// Handle search
  Future<void> _onSearchProductsRequested(
    SearchProductsRequested event,
    Emitter<ProductFeedState> emit,
  ) async {
    if (_searchQuery == event.query) return;

    try {
      emit(const ProductFeedLoading());

      _searchQuery = event.query;

      final products = await _productFeedService.searchProducts(
        query: _searchQuery!,
        category: _currentCategory,
        userLocation: _userLocation,
      );

      if (products.isEmpty) {
        emit(ProductFeedEmpty(
          currentCategory: _currentCategory,
          searchQuery: _searchQuery,
          onlyAvailableNow: _onlyAvailableNow,
        ));
        return;
      }

      emit(ProductFeedLoaded(
        products: products,
        hasReachedMax: true, // Search doesn't paginate
        currentCategory: _currentCategory,
        searchQuery: _searchQuery,
        onlyAvailableNow: _onlyAvailableNow,
        userLocation: _userLocation,
        lastUpdated: DateTime.now(),
      ));
    } catch (e) {
      emit(ProductFeedError(
        message: 'Search failed',
        details: e.toString(),
      ));
    }
  }

  /// Handle clear filters
  Future<void> _onClearFiltersRequested(
    ClearFiltersRequested event,
    Emitter<ProductFeedState> emit,
  ) async {
    _currentCategory = null;
    _searchQuery = null;
    _onlyAvailableNow = false;

    add(LoadProductsRequested(userLocation: _userLocation));
  }

  /// Handle availability filter toggle
  Future<void> _onToggleAvailableNowFilter(
    ToggleAvailableNowFilter event,
    Emitter<ProductFeedState> emit,
  ) async {
    if (_onlyAvailableNow == event.onlyAvailableNow) return;

    _onlyAvailableNow = event.onlyAvailableNow;

    add(LoadProductsRequested(
      category: _currentCategory,
      userLocation: _userLocation,
      onlyAvailableNow: _onlyAvailableNow,
    ));
  }

  /// Handle user location update
  Future<void> _onUpdateUserLocation(
    UpdateUserLocation event,
    Emitter<ProductFeedState> emit,
  ) async {
    _userLocation = event.userLocation;

    final currentState = state;
    if (currentState is ProductFeedLoaded) {
      // Re-sort products by distance
      final sortedProducts = List<ProductFeedItem>.from(currentState.products);

      // Recalculate distances and sort
      for (var i = 0; i < sortedProducts.length; i++) {
        final item = sortedProducts[i];
        if (item.hasLocationData) {
          final distance = Geolocator.distanceBetween(
            _userLocation!.latitude,
            _userLocation!.longitude,
            item.nextLatitude!,
            item.nextLongitude!,
          ) / 1609.344; // Convert to miles

          sortedProducts[i] = item.copyWith(distance: distance);
        }
      }

      // Sort by distance
      sortedProducts.sort((a, b) {
        if (a.distance == null && b.distance == null) return 0;
        if (a.distance == null) return 1;
        if (b.distance == null) return -1;
        return a.distance!.compareTo(b.distance!);
      });

      emit(currentState.copyWith(
        products: sortedProducts,
        userLocation: _userLocation,
      ));
    }
  }

  /// Handle product favorite toggle
  Future<void> _onToggleProductFavorite(
    ToggleProductFavorite event,
    Emitter<ProductFeedState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProductFeedLoaded) return;

    // Update the favorited status in the products list
    final updatedProducts = currentState.products.map((item) {
      if (item.product.id == event.productId) {
        return item.copyWith(isFavorited: !item.isFavorited);
      }
      return item;
    }).toList();

    emit(currentState.copyWith(products: updatedProducts));

    // TODO: Integrate with favorites service to persist the change
  }

  /// Check if cache is still valid
  bool _isCacheValid() {
    if (_lastFetchTime == null) return false;
    final now = DateTime.now();
    return now.difference(_lastFetchTime!) < _cacheValidity;
  }

  @override
  Future<void> close() {
    _productFeedService.clearCache();
    return super.close();
  }
}