import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:atv_events/features/premium/services/subscription_service.dart';
import 'package:atv_events/features/shared/services/user/search_history_service.dart';
import 'package:atv_events/features/vendor/services/engagement/vendor_following_service.dart';

/// Types of user interactions for building recommendations
enum InteractionType {
  vendorView,
  vendorFollow,
  vendorUnfollow,
  postView,
  postFavorite,
  searchQuery,
  marketVisit,
  productInquiry,
}

/// Recommendation reasons for transparency
enum RecommendationReason {
  similarUsers,
  basedOnSearchHistory,
  basedOnFollowedVendors,
  trendingInArea,
  seasonalMatch,
  categoryInterest,
  newVendorSuggestion,
}

/// Advanced personalized recommendation service for premium shoppers
/// Uses machine learning-like algorithms to provide tailored vendor suggestions
class PersonalizedRecommendationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _recommendationsCollection = 
      _firestore.collection('shopper_recommendations');
  static final CollectionReference _interactionsCollection = 
      _firestore.collection('user_interactions');

  /// Record user interaction for learning
  static Future<void> recordInteraction({
    required String shopperId,
    required InteractionType type,
    required String targetId, // vendorId, postId, etc.
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _interactionsCollection.add({
        'shopperId': shopperId,
        'type': type.name,
        'targetId': targetId,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });

    } catch (e) {
    }
  }

  /// Generate personalized recommendations for a shopper
  static Future<List<Map<String, dynamic>>> generateRecommendations({
    required String shopperId,
    String? location,
    int limit = 20,
  }) async {
    try {
      final hasFeature = await SubscriptionService.hasFeature(
        shopperId,
        'personalized_discovery',
      );

      if (!hasFeature) {
        // Return basic trending vendors for free users
        return _getBasicRecommendations(location: location, limit: limit);
      }

      // Build comprehensive user profile
      final userProfile = await _buildUserProfile(shopperId);
      
      // Generate recommendations using multiple algorithms
      final recommendations = <Map<String, dynamic>>[];
      
      // 1. Collaborative filtering (users with similar tastes)
      final collaborativeRecs = await _getCollaborativeRecommendations(
        shopperId, userProfile, limit: limit ~/ 3);
      recommendations.addAll(collaborativeRecs);

      // 2. Content-based filtering (based on user preferences)
      final contentRecs = await _getContentBasedRecommendations(
        shopperId, userProfile, location: location, limit: limit ~/ 3);
      recommendations.addAll(contentRecs);

      // 3. Trending and seasonal recommendations
      final trendingRecs = await _getTrendingRecommendations(
        location: location, limit: limit ~/ 3);
      recommendations.addAll(trendingRecs);

      // Deduplicate and rank
      final deduplicatedRecs = _deduplicateAndRank(recommendations, userProfile);
      
      // Store recommendations for analytics
      await _storeGeneratedRecommendations(shopperId, deduplicatedRecs);

      return deduplicatedRecs.take(limit).toList();
    } catch (e) {
      return _getBasicRecommendations(location: location, limit: limit);
    }
  }

  /// Build comprehensive user profile from interactions and preferences
  static Future<Map<String, dynamic>> _buildUserProfile(String shopperId) async {
    try {
      // Get user interactions
      final interactionsSnapshot = await _interactionsCollection
          .where('shopperId', isEqualTo: shopperId)
          .orderBy('timestamp', descending: true)
          .limit(500) // Last 500 interactions
          .get();

      // Get search history
      final searchHistory = await SearchHistoryService.getSearchHistory(
        shopperId: shopperId, limit: 100);

      // Get followed vendors
      final followedVendorIds = await VendorFollowingService.getFollowedVendors(shopperId);

      // Analyze category preferences
      final categoryPreferences = <String, double>{};
      final vendorPreferences = <String, double>{};
      final locationPreferences = <String, double>{};
      final timePreferences = <int, double>{}; // Hour of day preferences

      // Process interactions
      for (final doc in interactionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final type = data['type'] as String;
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final weight = _getInteractionWeight(type);

        // Time preferences
        final hour = timestamp.hour;
        timePreferences[hour] = (timePreferences[hour] ?? 0.0) + weight;

        // Get vendor/post data for category analysis
        final targetId = data['targetId'] as String;
        if (type.contains('vendor')) {
          vendorPreferences[targetId] = (vendorPreferences[targetId] ?? 0.0) + weight;
        }
      }

      // Process search history for category preferences
      for (final search in searchHistory) {
        final categories = List<String>.from(search['categories'] ?? []);
        final location = search['location'] as String?;

        for (final category in categories) {
          categoryPreferences[category] = (categoryPreferences[category] ?? 0.0) + 2.0;
        }

        if (location != null && location.isNotEmpty) {
          locationPreferences[location] = (locationPreferences[location] ?? 0.0) + 1.0;
        }
      }

      // Process followed vendors - Note: followedVendorIds is now just a list of IDs
      // We would need to fetch vendor details to get categories, but vendor features are disabled
      // So we'll just skip this processing for now since it's a stub implementation

      // Normalize scores
      final maxCategoryScore = categoryPreferences.values.isEmpty ? 1.0 : 
        categoryPreferences.values.reduce(math.max);
      final maxLocationScore = locationPreferences.values.isEmpty ? 1.0 : 
        locationPreferences.values.reduce(math.max);

      final normalizedCategoryPrefs = <String, double>{};
      categoryPreferences.forEach((category, score) {
        normalizedCategoryPrefs[category] = score / maxCategoryScore;
      });

      final normalizedLocationPrefs = <String, double>{};
      locationPreferences.forEach((location, score) {
        normalizedLocationPrefs[location] = score / maxLocationScore;
      });

      return {
        'shopperId': shopperId,
        'categoryPreferences': normalizedCategoryPrefs,
        'locationPreferences': normalizedLocationPrefs,
        'vendorPreferences': vendorPreferences,
        'timePreferences': timePreferences,
        'totalInteractions': interactionsSnapshot.docs.length,
        'followedVendorCount': followedVendorIds.length,
        'searchCount': searchHistory.length,
        'profileStrength': _calculateProfileStrength(
          interactionsSnapshot.docs.length,
          followedVendorIds.length,
          searchHistory.length,
        ),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'shopperId': shopperId,
        'categoryPreferences': <String, double>{},
        'locationPreferences': <String, double>{},
        'vendorPreferences': <String, double>{},
        'timePreferences': <int, double>{},
        'totalInteractions': 0,
        'followedVendorCount': 0,
        'searchCount': 0,
        'profileStrength': 0.0,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Collaborative filtering: find users with similar preferences
  static Future<List<Map<String, dynamic>>> _getCollaborativeRecommendations(
    String shopperId,
    Map<String, dynamic> userProfile,
    {int limit = 10}
  ) async {
    try {
      // Find similar users based on followed vendors
      final followedVendorIds = await VendorFollowingService.getFollowedVendors(shopperId);

      if (followedVendorIds.isEmpty) return [];

      // Find other users who follow similar vendors
      final similarUsersSnapshot = await _firestore
          .collection('vendor_follows')
          .where('vendorId', whereIn: followedVendorIds.take(10).toList())
          .where('isActive', isEqualTo: true)
          .get();

      final userSimilarity = <String, double>{};
      for (final doc in similarUsersSnapshot.docs) {
        final data = doc.data();
        final otherShopperId = data['shopperId'] as String;
        
        if (otherShopperId != shopperId) {
          userSimilarity[otherShopperId] = (userSimilarity[otherShopperId] ?? 0.0) + 1.0;
        }
      }

      // Get vendors followed by similar users that current user doesn't follow
      final similarUserIds = userSimilarity.keys.take(10).toList();
      if (similarUserIds.isEmpty) return [];

      final recommendedVendorsSnapshot = await _firestore
          .collection('vendor_follows')
          .where('shopperId', whereIn: similarUserIds)
          .where('isActive', isEqualTo: true)
          .get();

      final vendorScores = <String, double>{};
      for (final doc in recommendedVendorsSnapshot.docs) {
        final data = doc.data();
        final vendorId = data['vendorId'] as String;
        final recommenderId = data['shopperId'] as String;
        
        // Skip if user already follows this vendor
        if (followedVendorIds.contains(vendorId)) continue;

        final similarity = userSimilarity[recommenderId] ?? 1.0;
        vendorScores[vendorId] = (vendorScores[vendorId] ?? 0.0) + similarity;
      }

      // Get vendor details and create recommendations
      final recommendations = <Map<String, dynamic>>[];
      final topVendorIds = vendorScores.entries
          .toList()..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in topVendorIds.take(limit)) {
        final vendorDoc = await _firestore.collection('users').doc(entry.key).get();
        if (vendorDoc.exists) {
          final vendorData = vendorDoc.data() as Map<String, dynamic>;
          recommendations.add({
            ...vendorData,
            'vendorId': entry.key,
            'recommendationScore': entry.value,
            'recommendationReason': RecommendationReason.similarUsers.name,
            'reasonDetails': 'Users with similar tastes also follow this vendor',
          });
        }
      }

      return recommendations;
    } catch (e) {
      return [];
    }
  }

  /// Content-based filtering: recommend based on user's category preferences
  static Future<List<Map<String, dynamic>>> _getContentBasedRecommendations(
    String shopperId,
    Map<String, dynamic> userProfile,
    {String? location, int limit = 10}
  ) async {
    try {
      final categoryPrefs = Map<String, double>.from(
        userProfile['categoryPreferences'] ?? {}
      );
      
      if (categoryPrefs.isEmpty) return [];

      // Get top preferred categories
      final topCategories = categoryPrefs.entries
          .toList()..sort((a, b) => b.value.compareTo(a.value));

      final preferredCategories = topCategories
          .take(5)
          .map((e) => e.key)
          .toList();

      // Find vendors matching preferred categories
      Query vendorsQuery = _firestore
          .collection('users')
          .where('userType', isEqualTo: 'vendor')
          .where('isVerified', isEqualTo: true);

      if (location != null && location.isNotEmpty) {
        vendorsQuery = vendorsQuery.where('city', isEqualTo: location);
      }

      final vendorsSnapshot = await vendorsQuery.limit(100).get();
      final recommendations = <Map<String, dynamic>>[];

      for (final doc in vendorsSnapshot.docs) {
        final vendorData = doc.data() as Map<String, dynamic>;
        final vendorCategories = List<String>.from(vendorData['categories'] ?? []);
        
        // Calculate category match score
        double categoryScore = 0.0;
        for (final category in vendorCategories) {
          categoryScore += categoryPrefs[category] ?? 0.0;
        }

        if (categoryScore > 0) {
          recommendations.add({
            ...vendorData,
            'vendorId': doc.id,
            'recommendationScore': categoryScore,
            'recommendationReason': RecommendationReason.categoryInterest.name,
            'reasonDetails': 'Matches your interest in ${vendorCategories.take(2).join(" and ")}',
            'matchingCategories': vendorCategories.where((c) => categoryPrefs.containsKey(c)).toList(),
          });
        }
      }

      // Sort by score and return top recommendations
      recommendations.sort((a, b) => 
        (b['recommendationScore'] as double).compareTo(a['recommendationScore'] as double));

      return recommendations.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get trending recommendations based on recent activity
  static Future<List<Map<String, dynamic>>> _getTrendingRecommendations({
    String? location,
    int limit = 10,
  }) async {
    try {
      // Get recently active vendors
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      Query postsQuery = _firestore
          .collection('vendor_posts')
          .where('isActive', isEqualTo: true)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(oneWeekAgo));

      if (location != null && location.isNotEmpty) {
        postsQuery = postsQuery.where('city', isEqualTo: location);
      }

      final postsSnapshot = await postsQuery.get();
      final vendorActivity = <String, int>{};

      // Count posts per vendor
      for (final doc in postsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final vendorId = data['vendorId'] as String;
        vendorActivity[vendorId] = (vendorActivity[vendorId] ?? 0) + 1;
      }

      // Get vendor details for most active vendors
      final recommendations = <Map<String, dynamic>>[];
      final topVendors = vendorActivity.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in topVendors.take(limit)) {
        final vendorDoc = await _firestore.collection('users').doc(entry.key).get();
        if (vendorDoc.exists) {
          final vendorData = vendorDoc.data() as Map<String, dynamic>;
          recommendations.add({
            ...vendorData,
            'vendorId': entry.key,
            'recommendationScore': entry.value.toDouble(),
            'recommendationReason': RecommendationReason.trendingInArea.name,
            'reasonDetails': 'Very active this week with ${entry.value} new posts',
            'activityCount': entry.value,
          });
        }
      }

      return recommendations;
    } catch (e) {
      return [];
    }
  }

  /// Basic recommendations for free users
  static Future<List<Map<String, dynamic>>> _getBasicRecommendations({
    String? location,
    int limit = 10,
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .where('userType', isEqualTo: 'vendor')
          .where('isVerified', isEqualTo: true)
          .orderBy('createdAt', descending: true);

      if (location != null && location.isNotEmpty) {
        query = query.where('city', isEqualTo: location);
      }

      final snapshot = await query.limit(limit).get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          ...data,
          'vendorId': doc.id,
          'recommendationScore': 1.0,
          'recommendationReason': RecommendationReason.newVendorSuggestion.name,
          'reasonDetails': 'New vendor on the platform',
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Deduplicate and rank final recommendations
  static List<Map<String, dynamic>> _deduplicateAndRank(
    List<Map<String, dynamic>> recommendations,
    Map<String, dynamic> userProfile,
  ) {
    final seen = <String>{};
    final deduplicated = <Map<String, dynamic>>[];

    // Remove duplicates by vendorId
    for (final rec in recommendations) {
      final vendorId = rec['vendorId'] as String;
      if (!seen.contains(vendorId)) {
        seen.add(vendorId);
        deduplicated.add(rec);
      }
    }

    // Apply additional scoring based on user profile
    for (final rec in deduplicated) {
      final baseScore = rec['recommendationScore'] as double;
      double bonusScore = 0.0;

      // Location bonus
      final vendorLocation = rec['city'] as String?;
      final locationPrefs = Map<String, double>.from(
        userProfile['locationPreferences'] ?? {}
      );
      if (vendorLocation != null && locationPrefs.containsKey(vendorLocation)) {
        bonusScore += locationPrefs[vendorLocation]! * 2.0;
      }

      // Category bonus
      final vendorCategories = List<String>.from(rec['categories'] ?? []);
      final categoryPrefs = Map<String, double>.from(
        userProfile['categoryPreferences'] ?? {}
      );
      for (final category in vendorCategories) {
        bonusScore += categoryPrefs[category] ?? 0.0;
      }

      rec['finalScore'] = baseScore + bonusScore;
    }

    // Sort by final score
    deduplicated.sort((a, b) => 
      (b['finalScore'] as double).compareTo(a['finalScore'] as double));

    return deduplicated;
  }

  /// Store generated recommendations for analytics
  static Future<void> _storeGeneratedRecommendations(
    String shopperId,
    List<Map<String, dynamic>> recommendations,
  ) async {
    try {
      await _recommendationsCollection.add({
        'shopperId': shopperId,
        'recommendations': recommendations.map((r) => {
          'vendorId': r['vendorId'],
          'score': r['finalScore'],
          'reason': r['recommendationReason'],
        }).toList(),
        'generatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
    }
  }

  /// Get interaction weight for scoring
  static double _getInteractionWeight(String interactionType) {
    switch (interactionType) {
      case 'vendorFollow':
        return 5.0;
      case 'postFavorite':
        return 3.0;
      case 'vendorView':
        return 2.0;
      case 'postView':
        return 1.5;
      case 'searchQuery':
        return 1.0;
      case 'vendorUnfollow':
        return -2.0;
      default:
        return 1.0;
    }
  }

  /// Calculate profile strength score
  static double _calculateProfileStrength(
    int interactionCount,
    int followedVendorCount,
    int searchCount,
  ) {
    final interactionScore = math.min(interactionCount / 50.0, 1.0);
    final followScore = math.min(followedVendorCount / 10.0, 1.0);
    final searchScore = math.min(searchCount / 20.0, 1.0);
    
    return (interactionScore + followScore + searchScore) / 3.0;
  }

  /// Get recommendation analytics for admin dashboard
  static Future<Map<String, dynamic>> getRecommendationAnalytics() async {
    try {
      final recentRecommendations = await _recommendationsCollection
          .where('generatedAt', isGreaterThan: 
            Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30))))
          .get();

      final stats = {
        'totalRecommendationsGenerated': recentRecommendations.docs.length,
        'averageRecommendationsPerUser': 0.0,
        'reasonBreakdown': <String, int>{},
        'userEngagement': <String, int>{},
      };

      final userRecommendationCounts = <String, int>{};
      
      for (final doc in recentRecommendations.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final shopperId = data['shopperId'] as String;
        final recommendations = List<Map<String, dynamic>>.from(data['recommendations'] ?? []);
        
        userRecommendationCounts[shopperId] = 
          (userRecommendationCounts[shopperId] ?? 0) + recommendations.length;

        // Count reasons
        for (final rec in recommendations) {
          final reason = rec['reason'] as String;
          final reasonBreakdown = stats['reasonBreakdown'] as Map<String, int>;
          reasonBreakdown[reason] = (reasonBreakdown[reason] ?? 0) + 1;
        }
      }

      if (userRecommendationCounts.isNotEmpty) {
        stats['averageRecommendationsPerUser'] = 
          userRecommendationCounts.values.reduce((a, b) => a + b) / 
          userRecommendationCounts.length;
      }

      return stats;
    } catch (e) {
      return {
        'totalRecommendationsGenerated': 0,
        'averageRecommendationsPerUser': 0.0,
        'reasonBreakdown': <String, int>{},
        'userEngagement': <String, int>{},
      };
    }
  }
}