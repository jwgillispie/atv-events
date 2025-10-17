import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:atv_events/features/premium/services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Search types
enum SearchType {
  productSearch,
  categorySearch,
  vendorSearch,
  locationSearch,
  combinedSearch,
}

/// Search history and saved searches service for premium shoppers
class SearchHistoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _searchHistoryCollection = 
      _firestore.collection('search_history');
  static final CollectionReference _savedSearchesCollection = 
      _firestore.collection('saved_searches');

  // Local storage keys
  static const String _localSearchHistoryKey = 'local_search_history';
  static const String _localSavedSearchesKey = 'local_saved_searches';

  /// Record a search in history (both local and cloud for premium)
  static Future<void> recordSearch({
    required String shopperId,
    required String query,
    required SearchType searchType,
    List<String>? categories,
    String? location,
    Map<String, dynamic>? filters,
    int? resultsCount,
  }) async {
    try {
      final searchData = {
        'query': query,
        'searchType': searchType.name,
        'categories': categories ?? [],
        'location': location,
        'filters': filters ?? {},
        'resultsCount': resultsCount ?? 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // Always save locally (works for free users)
      await _saveSearchLocally(searchData);

      // Save to cloud for premium users
      final hasFeature = await SubscriptionService.hasFeature(
        shopperId,
        'advanced_filters',
      );

      if (hasFeature) {
        await _firestore.collection('search_history').add({
          'shopperId': shopperId,
          'query': query,
          'searchType': searchType.name,
          'categories': categories ?? [],
          'location': location,
          'filters': filters ?? {},
          'resultsCount': resultsCount ?? 0,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

    } catch (e) {
    }
  }

  /// Get search history (local for free, cloud for premium)
  static Future<List<Map<String, dynamic>>> getSearchHistory({
    required String shopperId,
    int limit = 50,
  }) async {
    try {
      final hasFeature = await SubscriptionService.hasFeature(
        shopperId,
        'advanced_filters',
      );

      if (hasFeature) {
        // Get from cloud for premium users
        final snapshot = await _searchHistoryCollection
            .where('shopperId', isEqualTo: shopperId)
            .orderBy('timestamp', descending: true)
            .limit(limit)
            .get();

        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
            'timestamp': (data['timestamp'] as Timestamp).millisecondsSinceEpoch,
          };
        }).toList();
      } else {
        // Get from local storage for free users
        return await _getLocalSearchHistory();
      }
    } catch (e) {
      return await _getLocalSearchHistory(); // Fallback to local
    }
  }

  /// Save a search for later (premium feature)
  static Future<String?> saveSearch({
    required String shopperId,
    required String name,
    required String query,
    required SearchType searchType,
    List<String>? categories,
    String? location,
    Map<String, dynamic>? filters,
  }) async {
    try {
      final hasFeature = await SubscriptionService.hasFeature(
        shopperId,
        'advanced_filters',
      );

      if (!hasFeature) {
        throw Exception('Saved searches is a premium feature');
      }

      final doc = await _savedSearchesCollection.add({
        'shopperId': shopperId,
        'name': name,
        'query': query,
        'searchType': searchType.name,
        'categories': categories ?? [],
        'location': location,
        'filters': filters ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'lastUsed': FieldValue.serverTimestamp(),
      });

      return doc.id;
    } catch (e) {
      throw Exception('Failed to save search: $e');
    }
  }

  /// Get saved searches (premium feature)
  static Future<List<Map<String, dynamic>>> getSavedSearches(String shopperId) async {
    try {
      final hasFeature = await SubscriptionService.hasFeature(
        shopperId,
        'advanced_filters',
      );

      if (!hasFeature) {
        return [];
      }

      final snapshot = await _savedSearchesCollection
          .where('shopperId', isEqualTo: shopperId)
          .orderBy('lastUsed', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Update last used time for a saved search
  static Future<void> updateSavedSearchUsage(String savedSearchId) async {
    try {
      await _savedSearchesCollection.doc(savedSearchId).update({
        'lastUsed': FieldValue.serverTimestamp(),
        'usageCount': FieldValue.increment(1),
      });
    } catch (e) {
    }
  }

  /// Delete a saved search
  static Future<void> deleteSavedSearch(String savedSearchId) async {
    try {
      await _savedSearchesCollection.doc(savedSearchId).delete();
    } catch (e) {
      throw Exception('Failed to delete saved search: $e');
    }
  }

  /// Get search suggestions based on history
  static Future<List<String>> getSearchSuggestions({
    required String shopperId,
    required String partialQuery,
    int limit = 10,
  }) async {
    try {
      final history = await getSearchHistory(shopperId: shopperId, limit: 100);
      final suggestions = <String>{};

      final lowerQuery = partialQuery.toLowerCase();

      // Add suggestions from search history
      for (final search in history) {
        final query = search['query'] as String;
        if (query.toLowerCase().startsWith(lowerQuery) && query.length > partialQuery.length) {
          suggestions.add(query);
        }
      }

      // Add common search terms for the category if available
      suggestions.addAll(_getCommonSearchTerms(partialQuery));

      return suggestions.take(limit).toList();
    } catch (e) {
      return _getCommonSearchTerms(partialQuery);
    }
  }

  /// Get popular searches across all users (anonymized)
  static Future<List<String>> getPopularSearches({int limit = 10}) async {
    try {
      // This would require aggregation in production
      // For now, return common search terms
      return [
        'honey',
        'bread',
        'vegetables',
        'coffee',
        'flowers',
        'organic produce',
        'artisan cheese',
        'handmade soap',
        'pottery',
        'jewelry',
      ].take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get search analytics for a user
  static Future<Map<String, dynamic>> getSearchAnalytics(String shopperId) async {
    try {
      final history = await getSearchHistory(shopperId: shopperId, limit: 1000);
      
      final analytics = {
        'totalSearches': history.length,
        'searchesByType': <String, int>{},
        'topQueries': <String, int>{},
        'averageResultsPerSearch': 0.0,
        'searchesByDay': <String, int>{},
        'lastSearchDate': null,
      };

      if (history.isEmpty) return analytics;

      final queryCount = <String, int>{};
      final typeCount = <String, int>{};
      final dayCount = <String, int>{};
      var totalResults = 0;

      for (final search in history) {
        // Count by query
        final query = search['query'] as String;
        queryCount[query] = (queryCount[query] ?? 0) + 1;

        // Count by type
        final type = search['searchType'] as String;
        typeCount[type] = (typeCount[type] ?? 0) + 1;

        // Count by day
        final timestamp = search['timestamp'] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dayCount[dayKey] = (dayCount[dayKey] ?? 0) + 1;

        // Sum results
        totalResults += (search['resultsCount'] as int?) ?? 0;
      }

      // Sort and get top queries
      final sortedQueries = queryCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      analytics['searchesByType'] = typeCount;
      analytics['topQueries'] = Map.fromEntries(sortedQueries.take(10));
      analytics['averageResultsPerSearch'] = totalResults / history.length;
      analytics['searchesByDay'] = dayCount;
      analytics['lastSearchDate'] = DateTime.fromMillisecondsSinceEpoch(
        history.first['timestamp'] as int,
      );

      return analytics;
    } catch (e) {
      return {
        'totalSearches': 0,
        'searchesByType': <String, int>{},
        'topQueries': <String, int>{},
        'averageResultsPerSearch': 0.0,
        'searchesByDay': <String, int>{},
        'lastSearchDate': null,
      };
    }
  }

  /// Clear search history
  static Future<void> clearSearchHistory(String shopperId) async {
    try {
      // Clear local history
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localSearchHistoryKey);

      // Clear cloud history for premium users
      final hasFeature = await SubscriptionService.hasFeature(
        shopperId,
        'advanced_filters',
      );

      if (hasFeature) {
        final snapshot = await _searchHistoryCollection
            .where('shopperId', isEqualTo: shopperId)
            .get();

        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

    } catch (e) {
      throw Exception('Failed to clear search history: $e');
    }
  }

  /// Local storage helpers
  static Future<void> _saveSearchLocally(Map<String, dynamic> searchData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_localSearchHistoryKey) ?? '[]';
      final List<dynamic> history = json.decode(historyJson);
      
      // Add new search at the beginning
      history.insert(0, searchData);
      
      // Keep only last 50 searches locally
      if (history.length > 50) {
        history.removeRange(50, history.length);
      }
      
      await prefs.setString(_localSearchHistoryKey, json.encode(history));
    } catch (e) {
    }
  }

  static Future<List<Map<String, dynamic>>> _getLocalSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_localSearchHistoryKey) ?? '[]';
      final List<dynamic> history = json.decode(historyJson);
      
      return history.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Get common search terms based on partial query
  static List<String> _getCommonSearchTerms(String partialQuery) {
    final common = [
      'honey', 'bread', 'sourdough', 'vegetables', 'tomatoes', 'lettuce', 'carrots',
      'coffee', 'tea', 'flowers', 'roses', 'jewelry', 'necklace', 'earrings',
      'organic', 'local', 'fresh', 'handmade', 'artisan', 'craft', 'pottery',
      'soap', 'candles', 'cheese', 'milk', 'eggs', 'chicken', 'beef', 'pork',
      'herbs', 'basil', 'thyme', 'rosemary', 'jam', 'preserves', 'pickles',
    ];

    final lowerQuery = partialQuery.toLowerCase();
    return common
        .where((term) => term.startsWith(lowerQuery))
        .toList();
  }

  /// Export search history (for user data export)
  static Future<Map<String, dynamic>> exportSearchHistory(String shopperId) async {
    try {
      final history = await getSearchHistory(shopperId: shopperId, limit: 10000);
      final savedSearches = await getSavedSearches(shopperId);
      final analytics = await getSearchAnalytics(shopperId);

      return {
        'exportDate': DateTime.now().toIso8601String(),
        'shopperId': shopperId,
        'searchHistory': history,
        'savedSearches': savedSearches,
        'analytics': analytics,
      };
    } catch (e) {
      throw Exception('Failed to export search history: $e');
    }
  }
}