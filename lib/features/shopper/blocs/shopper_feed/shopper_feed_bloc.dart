import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:atv_events/features/market/models/market.dart';
import 'package:atv_events/features/shared/models/event.dart';
import 'package:atv_events/features/market/services/market_service.dart';
import 'package:atv_events/features/shared/services/data/event_service.dart';
import 'package:atv_events/features/shared/services/data/cache_service.dart';

part 'shopper_feed_event.dart';
part 'shopper_feed_state.dart';

/// BLoC for managing the shopper home feed with optimized performance
/// Implements pagination, caching, and debouncing for a smooth user experience
class ShopperFeedBloc extends Bloc<ShopperFeedEvent, ShopperFeedState> {
  final CacheService _cacheService;

  // Pagination tracking
  DocumentSnapshot? _lastMarketDoc;
  DocumentSnapshot? _lastEventDoc;

  // Stream subscriptions
  final CompositeSubscription _subscriptions = CompositeSubscription();
  StreamSubscription? _feedSubscription;

  // Debounce timers
  Timer? _searchDebounceTimer;
  Timer? _loadMoreDebounceTimer;

  static const int _pageSize = 20;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 500);
  static const Duration _loadMoreDebounceDuration = Duration(milliseconds: 300);
  static const Duration _cacheDuration = Duration(minutes: 5);

  ShopperFeedBloc({
    required CacheService cacheService,
  })  : _cacheService = cacheService,
        super(ShopperFeedInitial()) {
    // Register event handlers with transformers
    on<LoadFeedRequested>(_onLoadFeedRequested);
    on<RefreshFeedRequested>(_onRefreshFeedRequested);
    on<LoadMoreRequested>(_onLoadMoreRequested);
    on<SearchLocationChanged>(_onSearchLocationChanged);
    on<FilterChanged>(_onFilterChanged);
    on<ClearSearch>(_onClearSearch);
  }

  /// Load initial feed data with caching support
  Future<void> _onLoadFeedRequested(
    LoadFeedRequested event,
    Emitter<ShopperFeedState> emit,
  ) async {
    emit(ShopperFeedLoading());

    try {
      // Build cache key based on filter and location
      final cacheKey = _buildCacheKey(event.filter, event.location);

      // Try to get cached data first for instant display
      final cachedData = _cacheService.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        emit(ShopperFeedLoaded(
          markets: (cachedData['markets'] as List).cast<Market>(),
          events: (cachedData['events'] as List).cast<Event>(),
          filter: event.filter,
          location: event.location,
          hasReachedMax: false,
          isFromCache: true,
        ));

        // Load fresh data in background
        _loadFreshDataInBackground(event.filter, event.location);
        return;
      }

      // Load fresh data
      await _loadFreshData(emit, event.filter, event.location);
    } catch (error) {
      // Print full error details for Firestore index errors
      print('🔴 [SHOPPER FEED] ERROR: $error');
      if (error is FirebaseException) {
        print('🔴 [FIRESTORE ERROR] Code: ${error.code}');
        print('🔴 [FIRESTORE ERROR] Message: ${error.message}');
        print('🔴 [FIRESTORE ERROR] Plugin: ${error.plugin}');
        print('🔴 [FIRESTORE ERROR] Stack: ${error.stackTrace}');
      }
      emit(ShopperFeedError(
        message: 'Failed to load feed: ${error.toString()}',
        filter: event.filter,
        location: event.location,
      ));
    }
  }

  /// Refresh feed with pull-to-refresh support
  Future<void> _onRefreshFeedRequested(
    RefreshFeedRequested event,
    Emitter<ShopperFeedState> emit,
  ) async {
    if (state is! ShopperFeedLoaded) return;

    final currentState = state as ShopperFeedLoaded;
    emit(currentState.copyWith(isRefreshing: true));

    try {
      // Clear pagination cursors
      _lastMarketDoc = null;
      _lastEventDoc = null;

      // Clear cache for this query
      final cacheKey = _buildCacheKey(currentState.filter, currentState.location);
      _cacheService.clear(cacheKey);

      // Load fresh data
      await _loadFreshData(emit, currentState.filter, currentState.location);
    } catch (error) {
      // Print full error details for Firestore index errors
      print('🔴 [SHOPPER FEED REFRESH] ERROR: $error');
      if (error is FirebaseException) {
        print('🔴 [FIRESTORE ERROR] Code: ${error.code}');
        print('🔴 [FIRESTORE ERROR] Message: ${error.message}');
        print('🔴 [FIRESTORE ERROR] Plugin: ${error.plugin}');
      }
      emit(currentState.copyWith(
        isRefreshing: false,
        error: 'Failed to refresh: ${error.toString()}',
      ));
    }
  }

  /// Load more items with pagination
  Future<void> _onLoadMoreRequested(
    LoadMoreRequested event,
    Emitter<ShopperFeedState> emit,
  ) async {
    if (state is! ShopperFeedLoaded) return;

    final currentState = state as ShopperFeedLoaded;

    // Prevent multiple simultaneous load more requests
    if (currentState.isLoadingMore || currentState.hasReachedMax) return;

    // Debounce load more requests
    _loadMoreDebounceTimer?.cancel();
    _loadMoreDebounceTimer = Timer(_loadMoreDebounceDuration, () async {
      emit(currentState.copyWith(isLoadingMore: true));

      try {
        final newData = await _fetchNextPage(
          filter: currentState.filter,
          location: currentState.location,
        );

        final hasReachedMax = newData.markets.length < _pageSize &&
            newData.events.length < _pageSize;

        emit(currentState.copyWith(
          markets: [...currentState.markets, ...newData.markets],
          events: [...currentState.events, ...newData.events],
          hasReachedMax: hasReachedMax,
          isLoadingMore: false,
        ));
      } catch (error) {
        emit(currentState.copyWith(
          isLoadingMore: false,
          error: 'Failed to load more: ${error.toString()}',
        ));
      }
    });
  }

  /// Handle location search with debouncing
  Future<void> _onSearchLocationChanged(
    SearchLocationChanged event,
    Emitter<ShopperFeedState> emit,
  ) async {
    // Cancel previous debounce timer
    _searchDebounceTimer?.cancel();

    // Show loading indicator for search
    if (state is ShopperFeedLoaded) {
      final currentState = state as ShopperFeedLoaded;
      emit(currentState.copyWith(isSearching: true));
    }

    // Debounce search requests
    _searchDebounceTimer = Timer(_searchDebounceDuration, () async {
      // Reset pagination
      _lastMarketDoc = null;
      _lastEventDoc = null;

      // Load data for new location
      await _loadFreshData(emit,
        state is ShopperFeedLoaded ? (state as ShopperFeedLoaded).filter : FeedFilter.all,
        event.location,
      );
    });
  }

  /// Handle filter changes
  Future<void> _onFilterChanged(
    FilterChanged event,
    Emitter<ShopperFeedState> emit,
  ) async {
    if (state is! ShopperFeedLoaded) return;

    final currentState = state as ShopperFeedLoaded;

    // Don't reload if filter hasn't changed
    if (currentState.filter == event.filter) return;

    // Reset pagination
    _lastMarketDoc = null;
    _lastEventDoc = null;

    emit(ShopperFeedLoading());

    await _loadFreshData(emit, event.filter, currentState.location);
  }

  /// Clear search and show all items
  Future<void> _onClearSearch(
    ClearSearch event,
    Emitter<ShopperFeedState> emit,
  ) async {
    // Reset pagination
    _lastMarketDoc = null;
    _lastEventDoc = null;

    emit(ShopperFeedLoading());

    await _loadFreshData(emit,
      state is ShopperFeedLoaded ? (state as ShopperFeedLoaded).filter : FeedFilter.all,
      null,
    );
  }

  /// Load fresh data from Firestore
  Future<void> _loadFreshData(
    Emitter<ShopperFeedState> emit,
    FeedFilter filter,
    String? location,
  ) async {
    try {
      final data = await _fetchFeedData(
        filter: filter,
        location: location,
        isInitialLoad: true,
      );

      // Cache the data
      final cacheKey = _buildCacheKey(filter, location);
      _cacheService.set(
        cacheKey,
        {
          'markets': data.markets,
          'events': data.events,
        },
        ttl: _cacheDuration,
      );

      emit(ShopperFeedLoaded(
        markets: data.markets,
        events: data.events,
        filter: filter,
        location: location,
        hasReachedMax: data.markets.length < _pageSize &&
            data.events.length < _pageSize,
        isFromCache: false,
      ));
    } catch (error) {
      // Print full error details for Firestore index errors
      print('🔴 [LOAD FRESH DATA] ERROR: $error');
      if (error is FirebaseException) {
        print('🔴 [FIRESTORE ERROR] Code: ${error.code}');
        print('🔴 [FIRESTORE ERROR] Message: ${error.message}');
        print('🔴 [FIRESTORE ERROR] Plugin: ${error.plugin}');
        // Print the full error string which contains the index URL
        print('🔴 [FIRESTORE ERROR] Full error: ${error.toString()}');
      }
      emit(ShopperFeedError(
        message: 'Failed to load data: ${error.toString()}',
        filter: filter,
        location: location,
      ));
    }
  }

  /// Load fresh data in background (for cache refresh)
  Future<void> _loadFreshDataInBackground(FeedFilter filter, String? location) async {
    try {
      final data = await _fetchFeedData(
        filter: filter,
        location: location,
        isInitialLoad: true,
      );

      // Update cache
      final cacheKey = _buildCacheKey(filter, location);
      _cacheService.set(
        cacheKey,
        {
          'markets': data.markets,
          'events': data.events,
        },
        ttl: _cacheDuration,
      );

      // Emit updated state if still on same filter/location
      if (state is ShopperFeedLoaded) {
        final currentState = state as ShopperFeedLoaded;
        if (currentState.filter == filter && currentState.location == location) {
          emit(currentState.copyWith(
            markets: data.markets,
                events: data.events,
            isFromCache: false,
          ));
        }
      }
    } catch (_) {
      // Silent fail for background refresh
    }
  }

  /// Fetch feed data with pagination support
  Future<FeedData> _fetchFeedData({
    required FeedFilter filter,
    String? location,
    required bool isInitialLoad,
  }) async {
    List<Market> markets = [];
    List<Event> events = [];

    // Fetch based on filter
    if (filter == FeedFilter.all || filter == FeedFilter.markets) {
      markets = await _fetchMarkets(location, isInitialLoad);
    }

    if (filter == FeedFilter.all || filter == FeedFilter.events) {
      events = await _fetchEvents(location, isInitialLoad);
    }

    return FeedData(
      markets: markets,
      events: events,
    );
  }

  /// Fetch next page of data
  Future<FeedData> _fetchNextPage({
    required FeedFilter filter,
    String? location,
  }) async {
    return _fetchFeedData(
      filter: filter,
      location: location,
      isInitialLoad: false,
    );
  }

  /// Fetch markets with pagination
  Future<List<Market>> _fetchMarkets(String? location, bool isInitialLoad) async {
    Stream<List<Market>> marketStream;

    if (location != null && location.isNotEmpty) {
      marketStream = MarketService.getMarketsByCityStream(location);
    } else {
      marketStream = MarketService.getAllActiveMarketsStream();
    }

    final markets = await marketStream.first;

    // Sort by date
    markets.sort((a, b) => a.eventDate.compareTo(b.eventDate));

    // Apply pagination
    if (isInitialLoad) {
      _lastMarketDoc = null;
      return markets.take(_pageSize).toList();
    } else {
      // Find the index to start from
      final startIndex = _lastMarketDoc != null
        ? markets.indexWhere((m) => m.id == (_lastMarketDoc as DocumentSnapshot).id) + 1
        : 0;

      return markets.skip(startIndex).take(_pageSize).toList();
    }
  }


  /// Fetch events with pagination
  Future<List<Event>> _fetchEvents(String? location, bool isInitialLoad) async {
    Stream<List<Event>> eventsStream;

    if (location != null && location.isNotEmpty) {
      eventsStream = EventService.getEventsByCityStream(location);
    } else {
      eventsStream = EventService.getAllActiveEventsStream();
    }

    final allEvents = await eventsStream.first;
    final activeEvents = EventService.filterCurrentAndUpcomingEvents(allEvents);

    // Apply pagination
    if (isInitialLoad) {
      _lastEventDoc = null;
      return activeEvents.take(_pageSize).toList();
    } else {
      // Find the index to start from
      final startIndex = _lastEventDoc != null
        ? activeEvents.indexWhere((e) => e.id == (_lastEventDoc as DocumentSnapshot).id) + 1
        : 0;

      return activeEvents.skip(startIndex).take(_pageSize).toList();
    }
  }

  /// Build cache key for data
  String _buildCacheKey(FeedFilter filter, String? location) {
    return 'feed_${filter.name}_${location ?? 'all'}';
  }

  @override
  Future<void> close() {
    _searchDebounceTimer?.cancel();
    _loadMoreDebounceTimer?.cancel();
    _feedSubscription?.cancel();
    _subscriptions.cancel();
    return super.close();
  }
}

/// Helper class for combined feed data
class FeedData {
  final List<Market> markets;
  final List<Event> events;

  const FeedData({
    required this.markets,
    required this.events,
  });
}

/// Composite subscription helper
class CompositeSubscription {
  final List<StreamSubscription> _subscriptions = [];

  void add(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  void cancel() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}