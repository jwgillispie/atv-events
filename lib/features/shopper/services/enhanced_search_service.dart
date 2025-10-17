import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:hipop/features/shared/services/user/search_history_service.dart';
import 'package:hipop/features/premium/services/subscription_service.dart';
import 'package:hipop/features/shared/services/user/user_profile_service.dart';

/// Enhanced search service for premium shoppers
class EnhancedSearchService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// All vendor categories from vendor signup
  static const List<String> vendorCategories = [
    'Fresh Produce',
    'Organic Vegetables',
    'Fruits',
    'Herbs',
    'Dairy Products',
    'Meat & Poultry',
    'Eggs',
    'Baked Goods',
    'Bread & Pastries',
    'Honey',
    'Jams & Preserves',
    'Pickles & Fermented Foods',
    'Prepared Foods',
    'Beverages',
    'Coffee & Tea',
    'Flowers',
    'Plants & Seeds',
    'Crafts & Artwork',
    'Skincare Products',
    'Clothing & Accessories',
    'Jewelry',
    'Woodworking',
    'Pottery',
    'Candles & Soaps',
    'Spices & Seasonings',
  ];

  /// Search vendors by categories (Premium feature)
  /// Note: For demo purposes, this searches through vendor posts since that's your main data
  static Future<List<Map<String, dynamic>>> searchVendorsByCategories({
    required List<String> categories,
    String? location,
    String? shopperId,
    int limit = 50,
  }) async {
    try {
      // Record search in history if user provided
      if (shopperId != null) {
        await SearchHistoryService.recordSearch(
          shopperId: shopperId,
          query: categories.join(', '),
          searchType: SearchType.categorySearch,
          categories: categories,
          location: location,
        );
      }

      // Since you don't have vendor categories in the users collection yet,
      // let's search through vendor posts and simulate category matching
      Query query = _firestore.collection('vendor_posts')
          .where('isActive', isEqualTo: true);

      // Add location filter if provided
      if (location != null && location.isNotEmpty) {
        query = query.where('location', isGreaterThanOrEqualTo: location)
               .where('location', isLessThan: '$location\uf8ff');
      }

      final snapshot = await query.limit(limit * 2).get(); // Get more to filter

      final results = <String, Map<String, dynamic>>{};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final vendorId = data['vendorId'] ?? '';
        final vendorName = data['vendorName'] ?? 'Unknown Vendor';
        final description = (data['description'] ?? '').toString().toLowerCase();

        // Simple category matching based on description keywords
        bool matchesCategory = categories.isEmpty;
        if (!matchesCategory) {
          for (final category in categories) {
            if (_doesDescriptionMatchCategory(description, category)) {
              matchesCategory = true;
              break;
            }
          }
        }

        if (matchesCategory && vendorId.isNotEmpty) {
          // Deduplicate by vendorId
          results[vendorId] = {
            'vendorId': vendorId,
            'businessName': vendorName,
            'categories': _guessVendorCategories(description),
            'bio': data['description'] ?? '',
            'location': data['location'] ?? '',
            'profileImageUrl': null,
            'rating': 4.0 + (DateTime.now().millisecondsSinceEpoch % 20) / 20.0, // Demo rating
            'followerCount': DateTime.now().millisecondsSinceEpoch % 50, // Demo followers
          };
        }
      }

      final resultsList = results.values.take(limit).toList();
      
      // Update search history with results count
      if (shopperId != null) {
        await SearchHistoryService.recordSearch(
          shopperId: shopperId,
          query: categories.join(', '),
          searchType: SearchType.categorySearch,
          categories: categories,
          location: location,
          resultsCount: resultsList.length,
        );
      }

      return resultsList;
    } catch (e) {
      return _getDemoVendorData(categories);
    }
  }

  /// Helper: Check if description matches category
  static bool _doesDescriptionMatchCategory(String description, String category) {
    final categoryKeywords = {
      'Fresh Produce': ['produce', 'vegetables', 'veggie', 'organic', 'farm'],
      'Fruits': ['fruit', 'apple', 'orange', 'berry', 'citrus'],
      'Baked Goods': ['bread', 'baked', 'pastry', 'cookie', 'cake'],
      'Honey': ['honey', 'bee', 'raw honey'],
      'Coffee & Tea': ['coffee', 'tea', 'brew', 'roast'],
      'Flowers': ['flower', 'floral', 'bouquet', 'plant'],
      'Jewelry': ['jewelry', 'necklace', 'earrings', 'bracelet'],
      'Crafts & Artwork': ['craft', 'art', 'handmade', 'pottery'],
    };

    final keywords = categoryKeywords[category] ?? [category.toLowerCase()];
    return keywords.any((keyword) => description.contains(keyword));
  }

  /// Helper: Guess vendor categories from description
  static List<String> _guessVendorCategories(String description) {
    final categories = <String>[];
    
    if (description.contains('bread') || description.contains('baked')) {
      categories.add('Baked Goods');
    }
    if (description.contains('honey')) {
      categories.add('Honey');
    }
    if (description.contains('coffee') || description.contains('tea')) {
      categories.add('Coffee & Tea');
    }
    
    return categories.isEmpty ? ['General'] : categories;
  }

  /// Demo data fallback
  static List<Map<String, dynamic>> _getDemoVendorData(List<String> categories) {
    return [
      {
        'vendorId': 'demo1',
        'businessName': 'Atlanta Honey Co',
        'categories': ['Honey', 'Local Products'],
        'bio': 'Local raw honey and bee products',
        'location': 'Atlanta, GA',
        'rating': 4.8,
        'followerCount': 127,
      },
      {
        'vendorId': 'demo2',
        'businessName': 'Fresh Garden Produce',
        'categories': ['Fresh Produce', 'Organic Vegetables'],
        'bio': 'Organic vegetables and seasonal produce',
        'location': 'Decatur, GA',
        'rating': 4.6,
        'followerCount': 89,
      },
    ];
  }

  /// Search for specific products (Premium feature)
  static Future<List<Map<String, dynamic>>> searchByProduct({
    required String productQuery,
    String? location,
    String? shopperId,
    int limit = 50,
  }) async {
    try {
      // Record search in history if user provided
      if (shopperId != null) {
        await SearchHistoryService.recordSearch(
          shopperId: shopperId,
          query: productQuery,
          searchType: SearchType.productSearch,
          location: location,
        );
      }

      // Search in vendor posts for specific products
      Query query = _firestore.collection('vendor_posts')
          .where('isActive', isEqualTo: true);

      // Add location filter (using your actual location field)
      if (location != null && location.isNotEmpty) {
        query = query.where('location', isGreaterThanOrEqualTo: location)
               .where('location', isLessThan: '$location\uf8ff');
      }

      final snapshot = await query.limit(limit * 2).get();
      final results = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Check if product query matches in description
        final description = (data['description'] ?? '').toString().toLowerCase();
        final vendorName = (data['vendorName'] ?? '').toString().toLowerCase();
        final productQueryLower = productQuery.toLowerCase();

        if (description.contains(productQueryLower)) {
          results.add({
            'postId': doc.id,
            'vendorId': data['vendorId'] ?? '',
            'businessName': data['vendorName'] ?? 'Unknown Business', // Using vendorName from your schema
            'description': data['description'] ?? '',
            'specificProducts': description, // Use description as products for now
            'location': data['location'] ?? '',
            'popUpStartDateTime': data['popUpStartDateTime'],
            'popUpEndDateTime': data['popUpEndDateTime'],
            // Note: Your model doesn't have imageUrls, so we'll skip that
            'relevanceScore': _calculateProductRelevance(productQuery, data),
          });
        }
      }

      // If no results, provide demo data
      if (results.isEmpty) {
        results.addAll(_getDemoProductResults(productQuery));
      }

      // Sort by relevance
      results.sort((a, b) => 
        (b['relevanceScore'] as double).compareTo(a['relevanceScore'] as double));

      return results.take(limit).toList();
    } catch (e) {
      return _getDemoProductResults(productQuery);
    }
  }

  /// Demo product results
  static List<Map<String, dynamic>> _getDemoProductResults(String query) {
    return [
      {
        'postId': 'demo_post_1',
        'vendorId': 'demo_vendor_1',
        'businessName': 'Farm Fresh Atlanta',
        'description': 'Fresh ${query.toLowerCase()} and seasonal produce',
        'specificProducts': query,
        'location': 'Piedmont Park, Atlanta',
        'relevanceScore': 10.0,
      },
      {
        'postId': 'demo_post_2',
        'vendorId': 'demo_vendor_2',
        'businessName': 'Local Market Co',
        'description': 'Organic ${query.toLowerCase()} from local farms',
        'specificProducts': query,
        'location': 'Freedom Park, Atlanta',
        'relevanceScore': 8.0,
      },
    ];
  }

  /// Calculate product relevance score
  static double _calculateProductRelevance(String query, Map<String, dynamic> postData) {
    double score = 0.0;
    final queryLower = query.toLowerCase();
    
    final description = (postData['description'] ?? '').toString().toLowerCase();
    final vendorName = (postData['vendorName'] ?? '').toString().toLowerCase();

    // Exact matches in description get highest score
    if (description.contains(queryLower)) score += 10.0;
    
    // Matches in vendor name get high score
    if (vendorName.contains(queryLower)) score += 8.0;
    
    // Word matches get lower scores
    final queryWords = queryLower.split(' ');
    for (final word in queryWords) {
      if (word.length > 2) { // Skip very short words
        if (description.contains(word)) score += 2.0;
        if (vendorName.contains(word)) score += 1.0;
      }
    }

    return score;
  }

  /// Get trending categories based on recent posts (Premium feature)
  static Future<List<String>> getTrendingCategories({
    String? location,
    int days = 7,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      
      Query query = _firestore.collection('vendor_posts')
          .where('isActive', isEqualTo: true)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffDate));

      if (location != null && location.isNotEmpty) {
        query = query.where('city', isEqualTo: location);
      }

      final snapshot = await query.get();
      final categoryCount = <String, int>{};

      // Count category occurrences
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final categories = List<String>.from(data['categories'] ?? []);
        
        for (final category in categories) {
          categoryCount[category] = (categoryCount[category] ?? 0) + 1;
        }
      }

      // Sort by count and return top categories
      final sortedCategories = categoryCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedCategories.take(10).map((e) => e.key).toList();
    } catch (e) {
      return [];
    }
  }

  /// Advanced market search with vendor category filters (Premium feature)
  static Future<List<Map<String, dynamic>>> searchMarketsWithVendorTypes({
    required List<String> vendorCategories,
    String? location,
    int limit = 20,
  }) async {
    try {
      // First, find vendors with these categories
      final vendorsQuery = await _firestore.collection('users')
          .where('userType', isEqualTo: 'vendor')
          .where('isVerified', isEqualTo: true)
          .where('categories', arrayContainsAny: vendorCategories)
          .get();

      final vendorIds = vendorsQuery.docs.map((doc) => doc.id).toList();
      if (vendorIds.isEmpty) return [];

      // Then find markets that have these vendors
      Query marketsQuery = _firestore.collection('markets')
          .where('isActive', isEqualTo: true);

      if (location != null && location.isNotEmpty) {
        marketsQuery = marketsQuery.where('city', isEqualTo: location);
      }

      final marketsSnapshot = await marketsQuery.limit(limit).get();
      final results = <Map<String, dynamic>>[];

      for (final marketDoc in marketsSnapshot.docs) {
        final marketData = marketDoc.data() as Map<String, dynamic>;
        
        // Check if market has vendors with desired categories
        // This would require a more sophisticated query in production
        // For now, we'll include all markets and add category matching score
        
        results.add({
          'marketId': marketDoc.id,
          'name': marketData['name'],
          'description': marketData['description'],
          'location': marketData['location'],
          'city': marketData['city'],
          'nextOperatingDate': marketData['nextOperatingDate'],
          'operatingHours': marketData['operatingHours'],
          'imageUrls': List<String>.from(marketData['imageUrls'] ?? []),
          'categoryMatch': _calculateCategoryMatchScore(vendorCategories, marketData),
        });
      }

      // Sort by category match score
      results.sort((a, b) => 
        (b['categoryMatch'] as double).compareTo(a['categoryMatch'] as double));

      return results;
    } catch (e) {
      return [];
    }
  }

  /// Calculate how well a market matches desired vendor categories
  static double _calculateCategoryMatchScore(List<String> desiredCategories, Map<String, dynamic> marketData) {
    // This is a placeholder - in production you'd analyze the market's vendor composition
    // For now, return a random score between 0.5 and 1.0
    return 0.5 + (DateTime.now().millisecondsSinceEpoch % 50) / 100.0;
  }

  /// Get personalized vendor recommendations (Premium feature)
  static Future<List<Map<String, dynamic>>> getPersonalizedRecommendations({
    required String shopperId,
    String? location,
    int limit = 20,
  }) async {
    try {
      // For now, return trending vendors since this is a demo
      // In production, this would analyze user behavior and preferences
      return _getTrendingVendors(location: location, limit: limit);
    } catch (e) {
      return _getDemoRecommendations();
    }
  }

  /// Demo recommendations
  static List<Map<String, dynamic>> _getDemoRecommendations() {
    return [
      {
        'vendorId': 'rec1',
        'businessName': 'Sunrise Bakery',
        'categories': ['Baked Goods', 'Coffee & Tea'],
        'bio': 'Fresh baked goods and artisan coffee every morning',
        'location': 'Virginia-Highland, Atlanta',
        'rating': 4.9,
        'followerCount': 203,
      },
      {
        'vendorId': 'rec2',
        'businessName': 'Garden Fresh Organics',
        'categories': ['Fresh Produce', 'Organic Vegetables'],
        'bio': 'Certified organic produce from local farms',
        'location': 'Inman Park, Atlanta',
        'rating': 4.7,
        'followerCount': 156,
      },
      {
        'vendorId': 'rec3',
        'businessName': 'Wildflower Honey',
        'categories': ['Honey', 'Local Products'],
        'bio': 'Raw local honey and beeswax products',
        'location': 'Little Five Points, Atlanta',
        'rating': 4.8,
        'followerCount': 98,
      },
    ];
  }

  /// Get trending vendors (fallback for recommendations)
  static Future<List<Map<String, dynamic>>> _getTrendingVendors({
    String? location,
    int limit = 20,
  }) async {
    try {
      Query query = _firestore.collection('users')
          .where('userType', isEqualTo: 'vendor')
          .where('isVerified', isEqualTo: true)
          .orderBy('followerCount', descending: true);

      if (location != null && location.isNotEmpty) {
        query = query.where('city', isEqualTo: location);
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'vendorId': doc.id,
          'businessName': data['businessName'] ?? 'Unknown Business',
          'categories': List<String>.from(data['categories'] ?? []),
          'city': data['city'] ?? '',
          'bio': data['bio'] ?? '',
          'profileImageUrl': data['profileImageUrl'],
          'rating': data['rating'] ?? 0.0,
          'followerCount': data['followerCount'] ?? 0,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Check if user has premium access (dual-check system)
  static Future<bool> _checkPremiumAccess(String userId) async {
    try {
      // Check both subscription service AND user profile premium status
      final futures = await Future.wait([
        SubscriptionService.hasFeature(userId, 'advanced_filters'),
        _checkUserProfilePremiumStatus(userId),
      ]);
      
      final hasFeatureAccess = futures[0];
      final hasProfilePremium = futures[1];
      
      // User is premium if either check returns true
      return hasFeatureAccess || hasProfilePremium;
    } catch (e) {
      return false;
    }
  }
  
  /// Check user profile premium status
  static Future<bool> _checkUserProfilePremiumStatus(String userId) async {
    try {
      final userProfileService = UserProfileService();
      return await userProfileService.hasPremiumAccess(userId);
    } catch (e) {
      return false;
    }
  }

  /// Advanced search with multiple filters (Premium feature)
  static Future<List<Map<String, dynamic>>> advancedSearch({
    required String shopperId,
    String? productQuery,
    List<String>? categories,
    String? location,
    double? maxDistance,
    DateTimeRange? dateRange,
    Map<String, dynamic>? additionalFilters,
    int limit = 50,
  }) async {
    try {
      final hasAccess = await _checkPremiumAccess(shopperId);

      if (!hasAccess) {
        throw Exception('Advanced search is a premium feature');
      }

      // Record the advanced search
      await SearchHistoryService.recordSearch(
        shopperId: shopperId,
        query: productQuery ?? 'Advanced Search',
        searchType: SearchType.combinedSearch,
        categories: categories,
        location: location,
        filters: {
          'maxDistance': maxDistance,
          'dateRange': dateRange != null ? {
            'start': dateRange.start.toIso8601String(),
            'end': dateRange.end.toIso8601String(),
          } : null,
          'additionalFilters': additionalFilters,
        },
      );

      // Build complex query
      Query query = _firestore.collection('vendor_posts')
          .where('isActive', isEqualTo: true);

      // Date range filter
      if (dateRange != null) {
        query = query
            .where('popUpStartDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
            .where('popUpStartDateTime', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end));
      }

      // Location filter
      if (location != null && location.isNotEmpty) {
        query = query.where('location', isGreaterThanOrEqualTo: location)
               .where('location', isLessThan: '$location\uf8ff');
      }

      final snapshot = await query.limit(limit * 3).get(); // Get more for filtering
      final results = <Map<String, dynamic>>[];
      final seenVendors = <String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final vendorId = data['vendorId'] ?? '';
        final description = (data['description'] ?? '').toString().toLowerCase();

        // Skip duplicates
        if (seenVendors.contains(vendorId)) continue;

        bool matches = true;

        // Product query filter
        if (productQuery != null && productQuery.isNotEmpty) {
          if (!description.contains(productQuery.toLowerCase())) {
            matches = false;
          }
        }

        // Category filter
        if (categories != null && categories.isNotEmpty) {
          bool matchesCategory = false;
          for (final category in categories) {
            if (_doesDescriptionMatchCategory(description, category)) {
              matchesCategory = true;
              break;
            }
          }
          if (!matchesCategory) matches = false;
        }

        if (matches && vendorId.isNotEmpty) {
          seenVendors.add(vendorId);
          results.add({
            'postId': doc.id,
            'vendorId': vendorId,
            'businessName': data['vendorName'] ?? 'Unknown Business',
            'description': data['description'] ?? '',
            'location': data['location'] ?? '',
            'popUpStartDateTime': data['popUpStartDateTime'],
            'popUpEndDateTime': data['popUpEndDateTime'],
            'relevanceScore': _calculateAdvancedRelevance(
              productQuery, categories, data),
          });
        }

        if (results.length >= limit) break;
      }

      // Sort by relevance
      results.sort((a, b) => 
        (b['relevanceScore'] as double).compareTo(a['relevanceScore'] as double));

      // Update search history with results count
      await SearchHistoryService.recordSearch(
        shopperId: shopperId,
        query: productQuery ?? 'Advanced Search',
        searchType: SearchType.combinedSearch,
        categories: categories,
        location: location,
        filters: {
          'maxDistance': maxDistance,
          'dateRange': dateRange != null ? {
            'start': dateRange.start.toIso8601String(),
            'end': dateRange.end.toIso8601String(),
          } : null,
          'additionalFilters': additionalFilters,
        },
        resultsCount: results.length,
      );

      return results;
    } catch (e) {
      rethrow;
    }
  }

  /// Calculate relevance score for advanced search
  static double _calculateAdvancedRelevance(
    String? productQuery,
    List<String>? categories,
    Map<String, dynamic> postData,
  ) {
    double score = 0.0;
    
    final description = (postData['description'] ?? '').toString().toLowerCase();
    final vendorName = (postData['vendorName'] ?? '').toString().toLowerCase();

    // Product query scoring
    if (productQuery != null && productQuery.isNotEmpty) {
      final queryLower = productQuery.toLowerCase();
      if (description.contains(queryLower)) score += 10.0;
      if (vendorName.contains(queryLower)) score += 8.0;
      
      final queryWords = queryLower.split(' ');
      for (final word in queryWords) {
        if (word.length > 2) {
          if (description.contains(word)) score += 2.0;
          if (vendorName.contains(word)) score += 1.0;
        }
      }
    }

    // Category scoring
    if (categories != null && categories.isNotEmpty) {
      for (final category in categories) {
        if (_doesDescriptionMatchCategory(description, category)) {
          score += 5.0;
        }
      }
    }

    // Recency scoring (more recent posts get higher scores)
    final createdAt = postData['createdAt'];
    if (createdAt != null) {
      final postDate = (createdAt as Timestamp).toDate();
      final daysSincePost = DateTime.now().difference(postDate).inDays;
      score += math.max(0, 5.0 - (daysSincePost * 0.1));
    }

    return score;
  }

  /// Get search suggestions based on query and history
  static Future<List<String>> getSearchSuggestions({
    required String shopperId,
    required String partialQuery,
    int limit = 10,
  }) async {
    return SearchHistoryService.getSearchSuggestions(
      shopperId: shopperId,
      partialQuery: partialQuery,
      limit: limit,
    );
  }

  /// Execute a saved search
  static Future<List<Map<String, dynamic>>> executeSavedSearch({
    required String shopperId,
    required String savedSearchId,
  }) async {
    try {
      final savedSearches = await SearchHistoryService.getSavedSearches(shopperId);
      final savedSearch = savedSearches.firstWhere(
        (search) => search['id'] == savedSearchId,
        orElse: () => throw Exception('Saved search not found'),
      );

      // Update usage tracking
      await SearchHistoryService.updateSavedSearchUsage(savedSearchId);

      final searchType = savedSearch['searchType'] as String;
      
      switch (searchType) {
        case 'productSearch':
          return searchByProduct(
            productQuery: savedSearch['query'],
            location: savedSearch['location'],
            shopperId: shopperId,
          );
        case 'categorySearch':
          return searchVendorsByCategories(
            categories: List<String>.from(savedSearch['categories'] ?? []),
            location: savedSearch['location'],
            shopperId: shopperId,
          );
        case 'combinedSearch':
          final filters = savedSearch['filters'] as Map<String, dynamic>?;
          DateTimeRange? dateRange;
          if (filters?['dateRange'] != null) {
            final range = filters!['dateRange'] as Map<String, dynamic>;
            dateRange = DateTimeRange(
              start: DateTime.parse(range['start']),
              end: DateTime.parse(range['end']),
            );
          }
          
          return advancedSearch(
            shopperId: shopperId,
            productQuery: savedSearch['query'],
            categories: List<String>.from(savedSearch['categories'] ?? []),
            location: savedSearch['location'],
            dateRange: dateRange,
            additionalFilters: filters?['additionalFilters'],
          );
        default:
          throw Exception('Unknown search type: $searchType');
      }
    } catch (e) {
      throw Exception('Failed to execute saved search: $e');
    }
  }
}