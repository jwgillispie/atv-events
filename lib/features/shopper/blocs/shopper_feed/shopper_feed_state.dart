part of 'shopper_feed_bloc.dart';

/// Base state for shopper feed
abstract class ShopperFeedState extends Equatable {
  const ShopperFeedState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any data is loaded
class ShopperFeedInitial extends ShopperFeedState {}

/// Loading state while fetching initial data
class ShopperFeedLoading extends ShopperFeedState {}

/// Loaded state with feed data
class ShopperFeedLoaded extends ShopperFeedState {
  final List<Market> markets;
  final List<VendorPost> vendorPosts;
  final List<Event> events;
  final FeedFilter filter;
  final String? location;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final bool isRefreshing;
  final bool isSearching;
  final bool isFromCache;
  final String? error;

  const ShopperFeedLoaded({
    required this.markets,
    required this.vendorPosts,
    required this.events,
    required this.filter,
    this.location,
    this.hasReachedMax = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.isSearching = false,
    this.isFromCache = false,
    this.error,
  });

  /// Get total count of all items
  int get totalItemCount => markets.length + vendorPosts.length + events.length;

  /// Check if there are any items
  bool get hasItems => totalItemCount > 0;

  /// Get combined list of all items for mixed feed
  List<dynamic> get allItems {
    final items = <dynamic>[];
    items.addAll(markets);
    items.addAll(vendorPosts);
    items.addAll(events);
    return items;
  }

  /// Create a copy with updated values
  ShopperFeedLoaded copyWith({
    List<Market>? markets,
    List<VendorPost>? vendorPosts,
    List<Event>? events,
    FeedFilter? filter,
    String? location,
    bool? hasReachedMax,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool? isSearching,
    bool? isFromCache,
    String? error,
  }) {
    return ShopperFeedLoaded(
      markets: markets ?? this.markets,
      vendorPosts: vendorPosts ?? this.vendorPosts,
      events: events ?? this.events,
      filter: filter ?? this.filter,
      location: location ?? this.location,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSearching: isSearching ?? this.isSearching,
      isFromCache: isFromCache ?? this.isFromCache,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        markets,
        vendorPosts,
        events,
        filter,
        location,
        hasReachedMax,
        isLoadingMore,
        isRefreshing,
        isSearching,
        isFromCache,
        error,
      ];
}

/// Error state when feed loading fails
class ShopperFeedError extends ShopperFeedState {
  final String message;
  final FeedFilter filter;
  final String? location;

  const ShopperFeedError({
    required this.message,
    required this.filter,
    this.location,
  });

  @override
  List<Object?> get props => [message, filter, location];
}