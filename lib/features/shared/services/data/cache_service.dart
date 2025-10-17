import 'dart:async';

/// A simple in-memory cache service with TTL support
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, CacheEntry> _cache = {};
  final Duration defaultTTL = const Duration(minutes: 5);

  /// Store data in cache with optional TTL
  void set<T>(String key, T data, {Duration? ttl}) {
    final expiry = DateTime.now().add(ttl ?? defaultTTL);
    _cache[key] = CacheEntry(data: data, expiry: expiry);
  }

  /// Get data from cache if not expired
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    
    return entry.data as T?;
  }

  /// Check if cache has valid entry
  bool has(String key) {
    final entry = _cache[key];
    if (entry == null) return false;
    
    if (entry.isExpired) {
      _cache.remove(key);
      return false;
    }
    
    return true;
  }

  /// Clear specific cache entry
  void clear(String key) {
    _cache.remove(key);
  }

  /// Clear all cache entries
  void clearAll() {
    _cache.clear();
  }

  /// Get or fetch data with caching
  Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher, {
    Duration? ttl,
  }) async {
    // Check cache first
    final cached = get<T>(key);
    if (cached != null) {
      return cached;
    }

    // Fetch fresh data
    final data = await fetcher();
    
    // Store in cache
    set(key, data, ttl: ttl);
    
    return data;
  }

  /// Stream with caching support
  Stream<T> getCachedStream<T>(
    String key,
    Stream<T> Function() streamProvider, {
    Duration? ttl,
  }) {
    // Create a broadcast stream controller
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;
    Timer? cacheTimer;

    controller = StreamController<T>.broadcast(
      onListen: () {
        // Check cache first
        final cached = get<T>(key);
        if (cached != null) {
          controller.add(cached);
        }

        // Subscribe to the actual stream
        subscription = streamProvider().listen(
          (data) {
            // Update cache
            set(key, data, ttl: ttl);
            
            // Forward to listeners
            controller.add(data);

            // Reset cache timer
            cacheTimer?.cancel();
            cacheTimer = Timer(ttl ?? defaultTTL, () {
              clear(key);
            });
          },
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () {
        subscription?.cancel();
        cacheTimer?.cancel();
      },
    );

    return controller.stream;
  }
}

class CacheEntry {
  final dynamic data;
  final DateTime expiry;

  CacheEntry({required this.data, required this.expiry});

  bool get isExpired => DateTime.now().isAfter(expiry);
}