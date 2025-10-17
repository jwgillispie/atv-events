import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/market.dart';

/// Service for efficiently batch loading market data to prevent N+1 queries.
/// 
/// This service provides optimized batch query methods that reduce Firebase reads
/// by up to 90% compared to individual queries. It handles Firestore's whereIn
/// limit of 10 items by automatically splitting large queries into batches.
/// 
/// Performance improvements:
/// - 10 markets: 1 query instead of 10 (90% reduction)
/// - 30 markets: 3 queries instead of 30 (90% reduction)
/// - Caching layer reduces repeated queries
/// 
/// Example usage:
/// ```dart
/// // Instead of N+1 queries:
/// for (final id in marketIds) {
///   final market = await MarketService.getMarket(id);
/// }
/// 
/// // Use batch loading:
/// final markets = await MarketBatchService.batchLoadMarkets(marketIds);
/// ```
class MarketBatchService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache for recently loaded markets (15-minute TTL)
  static final Map<String, _CachedMarket> _marketCache = {};
  static const _cacheTTL = Duration(minutes: 15);
  
  // Firestore whereIn limit
  static const _whereInLimit = 10;

  /// Batch load markets by their IDs with automatic chunking for large lists.
  /// 
  /// Handles Firestore's whereIn limit by splitting queries into chunks of 10.
  /// Returns markets in the same order as the provided IDs when possible.
  /// 
  /// Performance: O(n/10) Firebase reads where n = number of market IDs
  static Future<List<Market>> batchLoadMarkets(List<String> marketIds) async {
    if (marketIds.isEmpty) return [];
    
    // Remove duplicates
    final uniqueIds = marketIds.toSet().toList();
    
    // Check cache first
    final now = DateTime.now();
    final cachedMarkets = <String, Market>{};
    final idsToFetch = <String>[];
    
    for (final id in uniqueIds) {
      final cached = _marketCache[id];
      if (cached != null && now.isBefore(cached.expiry)) {
        cachedMarkets[id] = cached.market;
      } else {
        idsToFetch.add(id);
        // Clean up expired cache entry
        _marketCache.remove(id);
      }
    }
    
    // Fetch uncached markets in batches
    final fetchedMarkets = <String, Market>{};
    if (idsToFetch.isNotEmpty) {
      
      // Split into chunks to respect Firestore's whereIn limit
      final chunks = _chunkList(idsToFetch, _whereInLimit);
      final futures = <Future<QuerySnapshot>>[];
      
      for (final chunk in chunks) {
        futures.add(
          _firestore
            .collection('markets')
            .where(FieldPath.documentId, whereIn: chunk)
            .get()
        );
      }
      
      // Execute all batch queries in parallel
      final snapshots = await Future.wait(futures);
      
      // Process results and update cache
      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          final market = Market.fromFirestore(doc);
          fetchedMarkets[market.id] = market;
          
          // Update cache
          _marketCache[market.id] = _CachedMarket(
            market: market,
            expiry: now.add(_cacheTTL),
          );
        }
      }
      
    }
    
    // Combine cached and fetched results, preserving original order
    final allMarkets = {...cachedMarkets, ...fetchedMarkets};
    final result = <Market>[];
    
    for (final id in marketIds) {
      final market = allMarkets[id];
      if (market != null) {
        result.add(market);
      }
    }
    
    return result;
  }

  /// Batch load markets with vendor statistics.
  /// 
  /// Returns a map of market ID to market with vendor count.
  /// Efficiently loads both market data and vendor counts in parallel.
  static Future<Map<String, MarketWithStats>> batchLoadMarketsWithStats(
    List<String> marketIds,
  ) async {
    if (marketIds.isEmpty) return {};
    
    // Load markets and vendor counts in parallel
    final results = await Future.wait([
      batchLoadMarkets(marketIds),
      _batchLoadVendorCounts(marketIds),
    ]);
    
    final markets = results[0] as List<Market>;
    final vendorCounts = results[1] as Map<String, int>;
    
    // Combine results
    final marketStats = <String, MarketWithStats>{};
    for (final market in markets) {
      marketStats[market.id] = MarketWithStats(
        market: market,
        vendorCount: vendorCounts[market.id] ?? 0,
      );
    }
    
    return marketStats;
  }

  /// Stream markets with automatic batching for real-time updates.
  /// 
  /// Provides real-time updates while maintaining batch efficiency.
  /// Note: Streams bypass the cache to ensure real-time data.
  static Stream<List<Market>> watchMarkets(List<String> marketIds) {
    if (marketIds.isEmpty) return Stream.value([]);
    
    // Remove duplicates
    final uniqueIds = marketIds.toSet().toList();
    
    // Split into chunks for batch streaming
    final chunks = _chunkList(uniqueIds, _whereInLimit);
    
    // Create streams for each chunk
    final streams = <Stream<QuerySnapshot>>[];
    for (final chunk in chunks) {
      streams.add(
        _firestore
          .collection('markets')
          .where(FieldPath.documentId, whereIn: chunk)
          .snapshots()
      );
    }
    
    // Combine all streams
    return _combineStreams(streams).map((snapshots) {
      final marketMap = <String, Market>{};
      
      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          final market = Market.fromFirestore(doc);
          marketMap[market.id] = market;
        }
      }
      
      // Preserve original order
      final result = <Market>[];
      for (final id in marketIds) {
        final market = marketMap[id];
        if (market != null) {
          result.add(market);
        }
      }
      
      return result;
    });
  }

  /// Batch load markets by organizer ID.
  /// 
  /// Efficiently loads all markets managed by a specific organizer.
  static Future<List<Market>> batchLoadMarketsByOrganizer(String organizerId) async {
    try {
      final snapshot = await _firestore
        .collection('markets')
        .where('organizerId', isEqualTo: organizerId)
        .where('isActive', isEqualTo: true)
        .get();
      
      final markets = snapshot.docs
        .map((doc) => Market.fromFirestore(doc))
        .toList();
      
      // Update cache
      final now = DateTime.now();
      for (final market in markets) {
        _marketCache[market.id] = _CachedMarket(
          market: market,
          expiry: now.add(_cacheTTL),
        );
      }
      
      return markets;
    } catch (e) {
      return [];
    }
  }

  /// Clear the market cache.
  /// 
  /// Use this when data changes require fresh queries.
  static void clearCache() {
    _marketCache.clear();
  }

  /// Clear cache for specific market IDs.
  static void clearCacheForMarkets(List<String> marketIds) {
    for (final id in marketIds) {
      _marketCache.remove(id);
    }
  }

  // Private helper methods

  /// Load vendor counts for multiple markets efficiently.
  static Future<Map<String, int>> _batchLoadVendorCounts(List<String> marketIds) async {
    if (marketIds.isEmpty) return {};
    
    final vendorCounts = <String, int>{};
    
    try {
      // Query vendor_markets collection for all markets at once
      final chunks = _chunkList(marketIds, _whereInLimit);
      final futures = <Future<QuerySnapshot>>[];
      
      for (final chunk in chunks) {
        futures.add(
          _firestore
            .collection('vendor_markets')
            .where('marketId', whereIn: chunk)
            .where('isActive', isEqualTo: true)
            .where('isApproved', isEqualTo: true)
            .get()
        );
      }
      
      final snapshots = await Future.wait(futures);
      
      // Count vendors per market
      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final marketId = data['marketId'] as String?;
          if (marketId != null) {
            vendorCounts[marketId] = (vendorCounts[marketId] ?? 0) + 1;
          }
        }
      }
      
    } catch (e) {
    }
    
    return vendorCounts;
  }

  /// Split a list into chunks of specified size.
  static List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      final end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }

  /// Combine multiple streams into a single stream of lists.
  static Stream<List<QuerySnapshot>> _combineStreams(
    List<Stream<QuerySnapshot>> streams,
  ) async* {
    if (streams.isEmpty) {
      yield [];
      return;
    }
    
    if (streams.length == 1) {
      await for (final snapshot in streams.first) {
        yield [snapshot];
      }
      return;
    }
    
    // For multiple streams, we need to combine them
    // This is a simplified version - in production you might want to use StreamZip
    final latestSnapshots = List<QuerySnapshot?>.filled(streams.length, null);
    var initialized = false;
    
    // Listen to all streams
    final subscriptions = <int, Stream<QuerySnapshot>>{};
    for (var i = 0; i < streams.length; i++) {
      subscriptions[i] = streams[i];
    }
    
    // Yield combined results whenever any stream updates
    await for (final entry in _mergeStreams(subscriptions)) {
      latestSnapshots[entry.key] = entry.value;
      
      // Only yield once all streams have emitted at least once
      if (!initialized) {
        initialized = latestSnapshots.every((s) => s != null);
      }
      
      if (initialized) {
        yield latestSnapshots.whereType<QuerySnapshot>().toList();
      }
    }
  }

  /// Merge multiple indexed streams into a single stream.
  static Stream<MapEntry<int, QuerySnapshot>> _mergeStreams(
    Map<int, Stream<QuerySnapshot>> streams,
  ) async* {
    final controllers = <int, Stream<MapEntry<int, QuerySnapshot>>>{};
    
    for (final entry in streams.entries) {
      controllers[entry.key] = entry.value.map((snapshot) => 
        MapEntry(entry.key, snapshot)
      );
    }
    
    // Merge all streams
    await for (final event in _mergeAllStreams(controllers.values.toList())) {
      yield event;
    }
  }

  /// Merge all streams into a single stream.
  static Stream<T> _mergeAllStreams<T>(List<Stream<T>> streams) async* {
    if (streams.isEmpty) return;
    if (streams.length == 1) {
      yield* streams.first;
      return;
    }
    
    // Simple round-robin merge
    final subscriptions = streams.map((s) => s.listen(null)).toList();
    final controller = StreamController<T>();
    
    for (var i = 0; i < subscriptions.length; i++) {
      subscriptions[i].onData((data) {
        controller.add(data);
      });
      
      subscriptions[i].onError((error) {
      });
      
      subscriptions[i].onDone(() {
        subscriptions[i].cancel();
      });
    }
    
    yield* controller.stream;
  }
}

/// Market with additional statistics.
class MarketWithStats {
  final Market market;
  final int vendorCount;
  final int? eventCount;
  final double? revenue;

  MarketWithStats({
    required this.market,
    required this.vendorCount,
    this.eventCount,
    this.revenue,
  });
}

/// Cached market with expiry time.
class _CachedMarket {
  final Market market;
  final DateTime expiry;

  _CachedMarket({
    required this.market,
    required this.expiry,
  });
}