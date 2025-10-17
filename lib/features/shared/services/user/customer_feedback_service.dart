import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:atv_events/features/shared/models/customer_feedback.dart';
import 'package:atv_events/features/shared/models/universal_review.dart';
import 'package:atv_events/features/shared/services/universal_review_service.dart';

/// Service for managing customer feedback data
/// DEPRECATED: This service is being replaced by UniversalReviewService
/// This now acts as an adapter/wrapper for backwards compatibility
///
/// Migration Notes:
/// - Use UniversalReviewService directly for new features
/// - CustomerFeedback maps to UniversalReview with reviewedType = 'vendor' or 'market'
/// - CategoryRatings map to aspectRatings in UniversalReview
///
@Deprecated('Use UniversalReviewService instead. This class is maintained for backwards compatibility only.')
class CustomerFeedbackService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'customer_feedback'; // Legacy collection
  static final UniversalReviewService _reviewService = UniversalReviewService();

  /// Submit new customer feedback - MIGRATED to UniversalReviewService
  static Future<String> submitFeedback(CustomerFeedback feedback) async {
    try {
      // Convert CustomerFeedback to UniversalReview parameters
      final reviewedType = feedback.vendorId != null ? 'vendor' : 'market';
      final reviewedId = feedback.vendorId ?? feedback.marketId ?? '';
      final reviewedName = reviewedType == 'vendor'
          ? 'Vendor' // Would need actual vendor name
          : 'Market'; // Would need actual market name

      // Convert category ratings to aspect ratings
      final aspectRatings = <String, double>{};
      for (final entry in feedback.categoryRatings.entries) {
        aspectRatings[entry.key.name] = entry.value.toDouble();
      }

      // Submit via UniversalReviewService
      final reviewId = await _reviewService.submitReview(
        reviewedId: reviewedId,
        reviewedName: reviewedName,
        reviewedType: reviewedType,
        overallRating: feedback.overallRating.toDouble(),
        aspectRatings: aspectRatings,
        tags: feedback.tags,
        reviewText: feedback.reviewText,
        isAnonymous: feedback.isAnonymous,
        eventId: feedback.eventId,
        eventDate: feedback.visitDate,
      );

      // Update real-time analytics after feedback submission
      await _updateRealTimeAnalytics(feedback);

      return reviewId;
    } catch (e) {
      throw Exception('Failed to submit feedback: $e');
    }
  }

  /// Get feedback for a specific market - MIGRATED to UniversalReviewService
  static Future<List<CustomerFeedback>> getMarketFeedback(
    String marketId, {
    int? limit,
    DateTime? since,
  }) async {
    try {
      // Fetch from UniversalReviewService
      final reviews = await _reviewService.getReviewsForEntity(
        entityId: marketId,
        entityType: 'market',
        limit: limit ?? 20,
        sortBy: ReviewSortOption.newest,
      );

      // Convert UniversalReview to CustomerFeedback for backwards compatibility
      return reviews.map((review) => _convertUniversalReviewToCustomerFeedback(review)).toList();
    } catch (e) {
      // Fallback to legacy collection if new system fails
      try {
        Query query = _firestore
            .collection(_collection)
            .where('marketId', isEqualTo: marketId)
            .orderBy('createdAt', descending: true);

        if (since != null) {
          query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(since));
        }

        if (limit != null) {
          query = query.limit(limit);
        }

        final snapshot = await query.get();
        return snapshot.docs
            .map((doc) => CustomerFeedback.fromFirestore(doc))
            .toList();
      } catch (fallbackError) {
        throw Exception('Failed to get market feedback: $e');
      }
    }
  }

  /// Get feedback for a specific vendor - MIGRATED to UniversalReviewService
  static Future<List<CustomerFeedback>> getVendorFeedback(
    String vendorId, {
    int? limit,
    DateTime? since,
  }) async {
    try {
      // Fetch from UniversalReviewService
      final reviews = await _reviewService.getReviewsForEntity(
        entityId: vendorId,
        entityType: 'vendor',
        limit: limit ?? 20,
        sortBy: ReviewSortOption.newest,
      );

      // Convert UniversalReview to CustomerFeedback for backwards compatibility
      return reviews.map((review) => _convertUniversalReviewToCustomerFeedback(review)).toList();
    } catch (e) {
      // Fallback to legacy collection if new system fails
      try {
        Query query = _firestore
            .collection(_collection)
            .where('vendorId', isEqualTo: vendorId)
            .orderBy('createdAt', descending: true);

        if (since != null) {
          query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(since));
        }

        if (limit != null) {
          query = query.limit(limit);
        }

        final snapshot = await query.get();
        return snapshot.docs
            .map((doc) => CustomerFeedback.fromFirestore(doc))
            .toList();
      } catch (fallbackError) {
        throw Exception('Failed to get vendor feedback: $e');
      }
    }
  }

  /// Get feedback analytics for a market - MIGRATED to UniversalReviewService
  static Future<Map<String, dynamic>> getMarketAnalytics(
    String marketId, {
    DateTime? since,
    DateTime? until,
  }) async {
    try {
      // Get review stats from UniversalReviewService
      final reviewStats = await _reviewService.getReviewStats(
        entityId: marketId,
        entityType: 'market',
      );

      // Get reviews for detailed analytics
      final reviews = await _reviewService.getReviewsForEntity(
        entityId: marketId,
        entityType: 'market',
        limit: 1000,
      );

      // Convert to CustomerFeedback format for analytics calculation
      final feedbackList = reviews.map((r) => _convertUniversalReviewToCustomerFeedback(r)).toList();

      // Use existing analytics calculation
      final analytics = _calculateAnalytics(feedbackList, 'market');

      // Enhance with UniversalReview stats
      analytics['universalStats'] = {
        'totalReviews': reviewStats.totalReviews,
        'averageRating': reviewStats.averageRating,
        'verifiedCount': reviewStats.verifiedCount,
        'photoCount': reviewStats.photoCount,
        'responseRate': reviewStats.responseRate,
      };

      return analytics;
    } catch (e) {
      // Fallback to legacy system
      try {
        Query query = _firestore
            .collection(_collection)
            .where('marketId', isEqualTo: marketId);

        if (since != null) {
          query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(since));
        }

        if (until != null) {
          query = query.where('createdAt', isLessThan: Timestamp.fromDate(until));
        }

        final snapshot = await query.get();
        final feedbackList = snapshot.docs
            .map((doc) => CustomerFeedback.fromFirestore(doc))
            .toList();

        return _calculateAnalytics(feedbackList, 'market');
      } catch (fallbackError) {
        throw Exception('Failed to get market analytics: $e');
      }
    }
  }

  /// Get feedback analytics for a vendor - MIGRATED to UniversalReviewService
  static Future<Map<String, dynamic>> getVendorAnalytics(
    String vendorId, {
    DateTime? since,
    DateTime? until,
  }) async {
    try {
      // Get review stats from UniversalReviewService
      final reviewStats = await _reviewService.getReviewStats(
        entityId: vendorId,
        entityType: 'vendor',
      );

      // Get reviews for detailed analytics
      final reviews = await _reviewService.getReviewsForEntity(
        entityId: vendorId,
        entityType: 'vendor',
        limit: 1000,
      );

      // Convert to CustomerFeedback format for analytics calculation
      final feedbackList = reviews.map((r) => _convertUniversalReviewToCustomerFeedback(r)).toList();

      // Use existing analytics calculation
      final analytics = _calculateAnalytics(feedbackList, 'vendor');

      // Enhance with UniversalReview stats
      analytics['universalStats'] = {
        'totalReviews': reviewStats.totalReviews,
        'averageRating': reviewStats.averageRating,
        'verifiedCount': reviewStats.verifiedCount,
        'photoCount': reviewStats.photoCount,
        'responseRate': reviewStats.responseRate,
      };

      return analytics;
    } catch (e) {
      // Fallback to legacy system
      try {
        Query query = _firestore
            .collection(_collection)
            .where('vendorId', isEqualTo: vendorId);

        if (since != null) {
          query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(since));
        }

        if (until != null) {
          query = query.where('createdAt', isLessThan: Timestamp.fromDate(until));
        }

        final snapshot = await query.get();
        final feedbackList = snapshot.docs
            .map((doc) => CustomerFeedback.fromFirestore(doc))
            .toList();

        return _calculateAnalytics(feedbackList, 'vendor');
      } catch (fallbackError) {
        throw Exception('Failed to get vendor analytics: $e');
      }
    }
  }

  /// Get comparative analytics for multiple vendors in a market
  static Future<Map<String, Map<String, dynamic>>> getVendorComparison(
    String marketId, {
    DateTime? since,
  }) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .where('marketId', isEqualTo: marketId)
          .where('vendorId', isNull: false);

      if (since != null) {
        query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(since));
      }

      final snapshot = await query.get();
      final feedbackList = snapshot.docs
          .map((doc) => CustomerFeedback.fromFirestore(doc))
          .toList();

      // Group feedback by vendor
      final vendorFeedback = <String, List<CustomerFeedback>>{};
      for (final feedback in feedbackList) {
        if (feedback.vendorId != null) {
          vendorFeedback.putIfAbsent(feedback.vendorId!, () => []);
          vendorFeedback[feedback.vendorId!]!.add(feedback);
        }
      }

      // Calculate analytics for each vendor
      final result = <String, Map<String, dynamic>>{};
      for (final entry in vendorFeedback.entries) {
        result[entry.key] = _calculateAnalytics(entry.value, 'vendor');
      }

      return result;
    } catch (e) {
      throw Exception('Failed to get vendor comparison: $e');
    }
  }

  /// Get sentiment analysis summary
  static Future<Map<String, dynamic>> getSentimentAnalysis(
    String? marketId,
    String? vendorId, {
    DateTime? since,
  }) async {
    try {
      Query query = _firestore.collection(_collection);

      if (marketId != null) {
        query = query.where('marketId', isEqualTo: marketId);
      }

      if (vendorId != null) {
        query = query.where('vendorId', isEqualTo: vendorId);
      }

      if (since != null) {
        query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(since));
      }

      final snapshot = await query.get();
      final feedbackList = snapshot.docs
          .map((doc) => CustomerFeedback.fromFirestore(doc))
          .toList();

      return _analyzeSentiment(feedbackList);
    } catch (e) {
      throw Exception('Failed to analyze sentiment: $e');
    }
  }

  /// Get trending feedback topics
  static Future<Map<String, int>> getTrendingTopics(
    String? marketId,
    String? vendorId, {
    DateTime? since,
    int limit = 20,
  }) async {
    try {
      Query query = _firestore.collection(_collection);

      if (marketId != null) {
        query = query.where('marketId', isEqualTo: marketId);
      }

      if (vendorId != null) {
        query = query.where('vendorId', isEqualTo: vendorId);
      }

      if (since != null) {
        query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(since));
      }

      final snapshot = await query.get();
      final feedbackList = snapshot.docs
          .map((doc) => CustomerFeedback.fromFirestore(doc))
          .toList();

      return _extractTrendingTopics(feedbackList, limit);
    } catch (e) {
      throw Exception('Failed to get trending topics: $e');
    }
  }

  /// Export feedback data for analytics
  static Future<Map<String, dynamic>> exportFeedbackData(
    String? marketId,
    String? vendorId, {
    DateTime? since,
    DateTime? until,
    String format = 'summary', // 'summary', 'detailed', 'raw'
  }) async {
    try {
      Query query = _firestore.collection(_collection);

      if (marketId != null) {
        query = query.where('marketId', isEqualTo: marketId);
      }

      if (vendorId != null) {
        query = query.where('vendorId', isEqualTo: vendorId);
      }

      if (since != null) {
        query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(since));
      }

      if (until != null) {
        query = query.where('createdAt', isLessThan: Timestamp.fromDate(until));
      }

      final snapshot = await query.get();
      final feedbackList = snapshot.docs
          .map((doc) => CustomerFeedback.fromFirestore(doc))
          .toList();

      switch (format) {
        case 'summary':
          return _generateSummaryReport(feedbackList);
        case 'detailed':
          return _generateDetailedReport(feedbackList);
        case 'raw':
          return _generateRawDataExport(feedbackList);
        default:
          throw ArgumentError('Invalid export format: $format');
      }
    } catch (e) {
      throw Exception('Failed to export feedback data: $e');
    }
  }

  /// Get customer return rate analytics
  static Future<Map<String, dynamic>> getCustomerReturnAnalytics(
    String? marketId,
    String? vendorId, {
    DateTime? since,
  }) async {
    try {
      Query query = _firestore.collection(_collection);

      if (marketId != null) {
        query = query.where('marketId', isEqualTo: marketId);
      }

      if (vendorId != null) {
        query = query.where('vendorId', isEqualTo: vendorId);
      }

      if (since != null) {
        query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(since));
      }

      final snapshot = await query.get();
      final feedbackList = snapshot.docs
          .map((doc) => CustomerFeedback.fromFirestore(doc))
          .toList();

      return _calculateReturnCustomerMetrics(feedbackList);
    } catch (e) {
      throw Exception('Failed to get customer return analytics: $e');
    }
  }

  /// Calculate comprehensive analytics from feedback list
  static Map<String, dynamic> _calculateAnalytics(
    List<CustomerFeedback> feedbackList,
    String targetType,
  ) {
    if (feedbackList.isEmpty) {
      return _getEmptyAnalytics(targetType);
    }

    final totalFeedback = feedbackList.length;
    final averageRating = feedbackList.map((f) => f.overallRating).fold(0, (a, b) => a + b) / totalFeedback;
    
    final categoryAverages = <ReviewCategory, double>{};
    for (final category in ReviewCategory.values) {
      final ratings = feedbackList
          .where((f) => f.categoryRatings.containsKey(category))
          .map((f) => f.categoryRatings[category]!)
          .toList();
      
      if (ratings.isNotEmpty) {
        categoryAverages[category] = ratings.fold(0, (a, b) => a + b) / ratings.length;
      }
    }

    final positiveFeedback = feedbackList.where((f) => f.isPositiveFeedback).length;
    final criticalFeedback = feedbackList.where((f) => f.isCriticalFeedback).length;
    final wouldRecommendCount = feedbackList.where((f) => f.wouldRecommend).length;
    
    final npsScores = feedbackList.where((f) => f.npsScore != null).map((f) => f.npsScore!);
    final averageNPS = npsScores.isNotEmpty ? npsScores.fold(0, (a, b) => a + b) / npsScores.length : null;
    
    final purchaseCount = feedbackList.where((f) => f.madeAPurchase).length;
    final totalSpend = feedbackList
        .where((f) => f.estimatedSpendAmount != null)
        .map((f) => f.estimatedSpendAmount!)
        .fold(0.0, (a, b) => a + b);
    
    final averageSpend = purchaseCount > 0 ? totalSpend / purchaseCount : 0.0;
    final conversionRate = totalFeedback > 0 ? purchaseCount / totalFeedback : 0.0;

    // Time-based analytics
    final timeSpentData = feedbackList
        .where((f) => (targetType == 'market' ? f.timeSpentAtMarket : f.timeSpentAtVendor) != null)
        .map((f) => targetType == 'market' ? f.timeSpentAtMarket! : f.timeSpentAtVendor!)
        .toList();
    
    final averageTimeSpent = timeSpentData.isNotEmpty 
        ? Duration(seconds: timeSpentData.map((d) => d.inSeconds).fold(0, (a, b) => a + b) ~/ timeSpentData.length)
        : null;

    // Tag analysis
    final allTags = <String>[];
    for (final feedback in feedbackList) {
      if (feedback.tags != null) {
        allTags.addAll(feedback.tags!);
      }
    }
    
    final tagFrequency = <String, int>{};
    for (final tag in allTags) {
      tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
    }

    // Recent trends (last 30 days vs previous period)
    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));
    final recentFeedback = feedbackList.where((f) => f.createdAt.isAfter(last30Days)).toList();
    final previousFeedback = feedbackList.where((f) => f.createdAt.isBefore(last30Days)).toList();

    final recentAverage = recentFeedback.isNotEmpty 
        ? recentFeedback.map((f) => f.overallRating).fold(0, (a, b) => a + b) / recentFeedback.length 
        : 0.0;
    final previousAverage = previousFeedback.isNotEmpty 
        ? previousFeedback.map((f) => f.overallRating).fold(0, (a, b) => a + b) / previousFeedback.length 
        : 0.0;
    
    final ratingTrend = previousAverage > 0 ? (recentAverage - previousAverage) / previousAverage : 0.0;

    return {
      'totalFeedback': totalFeedback,
      'averageRating': double.parse(averageRating.toStringAsFixed(2)),
      'categoryAverages': categoryAverages.map((k, v) => MapEntry(k.name, double.parse(v.toStringAsFixed(2)))),
      'positiveFeedback': positiveFeedback,
      'positiveFeedbackRate': double.parse((positiveFeedback / totalFeedback).toStringAsFixed(3)),
      'criticalFeedback': criticalFeedback,
      'criticalFeedbackRate': double.parse((criticalFeedback / totalFeedback).toStringAsFixed(3)),
      'recommendationRate': double.parse((wouldRecommendCount / totalFeedback).toStringAsFixed(3)),
      'averageNPS': averageNPS?.toStringAsFixed(1),
      'purchaseCount': purchaseCount,
      'conversionRate': double.parse(conversionRate.toStringAsFixed(3)),
      'averageSpend': double.parse(averageSpend.toStringAsFixed(2)),
      'totalSpend': double.parse(totalSpend.toStringAsFixed(2)),
      'averageTimeSpentMinutes': averageTimeSpent?.inMinutes,
      'topTags': tagFrequency.entries
          .where((entry) => entry.value >= 2)
          .map((entry) => {'tag': entry.key, 'count': entry.value})
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int)),
      'ratingTrend': double.parse(ratingTrend.toStringAsFixed(3)),
      'recentFeedbackCount': recentFeedback.length,
      'dataFreshness': feedbackList.isNotEmpty 
          ? DateTime.now().difference(feedbackList.first.createdAt).inDays 
          : 0,
    };
  }

  /// Generate empty analytics for when no data exists
  static Map<String, dynamic> _getEmptyAnalytics(String targetType) {
    return {
      'totalFeedback': 0,
      'averageRating': 0.0,
      'categoryAverages': {},
      'positiveFeedback': 0,
      'positiveFeedbackRate': 0.0,
      'criticalFeedback': 0,
      'criticalFeedbackRate': 0.0,
      'recommendationRate': 0.0,
      'averageNPS': null,
      'purchaseCount': 0,
      'conversionRate': 0.0,
      'averageSpend': 0.0,
      'totalSpend': 0.0,
      'averageTimeSpentMinutes': null,
      'topTags': [],
      'ratingTrend': 0.0,
      'recentFeedbackCount': 0,
      'dataFreshness': 0,
    };
  }

  /// Analyze sentiment from feedback text and ratings
  static Map<String, dynamic> _analyzeSentiment(List<CustomerFeedback> feedbackList) {
    final positiveKeywords = ['great', 'excellent', 'amazing', 'wonderful', 'fantastic', 'love', 'perfect', 'best'];
    final negativeKeywords = ['bad', 'terrible', 'awful', 'horrible', 'worst', 'hate', 'disgusting', 'poor'];
    
    int positiveCount = 0;
    int negativeCount = 0;
    int neutralCount = 0;
    
    for (final feedback in feedbackList) {
      final reviewText = feedback.reviewText?.toLowerCase() ?? '';
      
      // Combine text sentiment with rating
      final hasPositiveKeywords = positiveKeywords.any((keyword) => reviewText.contains(keyword));
      final hasNegativeKeywords = negativeKeywords.any((keyword) => reviewText.contains(keyword));
      
      if (feedback.overallRating >= 4 || hasPositiveKeywords) {
        positiveCount++;
      } else if (feedback.overallRating <= 2 || hasNegativeKeywords) {
        negativeCount++;
      } else {
        neutralCount++;
      }
    }
    
    final total = feedbackList.length;
    return {
      'positive': positiveCount,
      'negative': negativeCount,
      'neutral': neutralCount,
      'positivePercentage': total > 0 ? (positiveCount / total * 100).toStringAsFixed(1) : '0.0',
      'negativePercentage': total > 0 ? (negativeCount / total * 100).toStringAsFixed(1) : '0.0',
      'neutralPercentage': total > 0 ? (neutralCount / total * 100).toStringAsFixed(1) : '0.0',
    };
  }

  /// Extract trending topics from feedback
  static Map<String, int> _extractTrendingTopics(List<CustomerFeedback> feedbackList, int limit) {
    final wordFrequency = <String, int>{};
    final commonWords = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by'};
    
    for (final feedback in feedbackList) {
      final text = feedback.reviewText?.toLowerCase() ?? '';
      if (text.isNotEmpty) {
        final words = text.split(RegExp(r'\W+'))
            .where((word) => word.length > 2 && !commonWords.contains(word))
            .toList();
        
        for (final word in words) {
          wordFrequency[word] = (wordFrequency[word] ?? 0) + 1;
        }
      }
      
      // Add tags to trending topics
      if (feedback.tags != null) {
        for (final tag in feedback.tags!) {
          wordFrequency[tag] = (wordFrequency[tag] ?? 0) + 1;
        }
      }
    }
    
    final sortedEntries = wordFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Map.fromEntries(sortedEntries.take(limit));
  }

  /// Generate summary report
  static Map<String, dynamic> _generateSummaryReport(List<CustomerFeedback> feedbackList) {
    final analytics = _calculateAnalytics(feedbackList, 'summary');
    final sentiment = _analyzeSentiment(feedbackList);
    
    return {
      'reportGeneratedAt': DateTime.now().toIso8601String(),
      'period': {
        'from': feedbackList.isNotEmpty ? feedbackList.last.createdAt.toIso8601String() : null,
        'to': feedbackList.isNotEmpty ? feedbackList.first.createdAt.toIso8601String() : null,
      },
      'overview': analytics,
      'sentiment': sentiment,
      'recommendations': _generateRecommendations(analytics, sentiment),
    };
  }

  /// Generate detailed report
  static Map<String, dynamic> _generateDetailedReport(List<CustomerFeedback> feedbackList) {
    final summary = _generateSummaryReport(feedbackList);
    
    return {
      ...summary,
      'detailed': {
        'categoryBreakdown': _getCategoryBreakdown(feedbackList),
        'timeAnalysis': _getTimeAnalysis(feedbackList),
        'customerSegmentation': _getCustomerSegmentation(feedbackList),
        'purchasePatterns': _getPurchasePatterns(feedbackList),
      }
    };
  }

  /// Generate raw data export
  static Map<String, dynamic> _generateRawDataExport(List<CustomerFeedback> feedbackList) {
    return {
      'exportGeneratedAt': DateTime.now().toIso8601String(),
      'totalRecords': feedbackList.length,
      'data': feedbackList.map((feedback) => {
        ...feedback.toFirestore(),
        'id': feedback.id,
      }).toList(),
    };
  }

  /// Update real-time analytics after feedback submission
  static Future<void> _updateRealTimeAnalytics(CustomerFeedback feedback) async {
    try {
      final batch = _firestore.batch();
      
      // Update market analytics
      if (feedback.marketId != null) {
        final marketAnalyticsRef = _firestore
            .collection('market_analytics')
            .doc(feedback.marketId);
        
        batch.set(marketAnalyticsRef, {
          'lastFeedbackAt': Timestamp.fromDate(feedback.createdAt),
          'feedbackCount': FieldValue.increment(1),
          'totalRatingPoints': FieldValue.increment(feedback.overallRating),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      
      // Update vendor analytics
      if (feedback.vendorId != null) {
        final vendorAnalyticsRef = _firestore
            .collection('vendor_analytics')
            .doc(feedback.vendorId);
        
        batch.set(vendorAnalyticsRef, {
          'lastFeedbackAt': Timestamp.fromDate(feedback.createdAt),
          'feedbackCount': FieldValue.increment(1),
          'totalRatingPoints': FieldValue.increment(feedback.overallRating),
          'purchaseCount': feedback.madeAPurchase ? FieldValue.increment(1) : null,
          'lastUpdated': FieldValue.serverTimestamp(),
        }..removeWhere((key, value) => value == null), SetOptions(merge: true));
      }
      
      await batch.commit();
    } catch (e) {
      // Don't throw error for analytics update failures
      // Log error for debugging - could integrate with Firebase Crashlytics
    }
  }

  /// Calculate return customer metrics
  static Map<String, dynamic> _calculateReturnCustomerMetrics(List<CustomerFeedback> feedbackList) {
    final userVisits = <String, List<CustomerFeedback>>{};
    
    for (final feedback in feedbackList) {
      if (feedback.userId != null) {
        userVisits.putIfAbsent(feedback.userId!, () => []);
        userVisits[feedback.userId!]!.add(feedback);
      }
    }
    
    final returningCustomers = userVisits.entries.where((entry) => entry.value.length > 1).length;
    final totalCustomers = userVisits.length;
    final returnRate = totalCustomers > 0 ? returningCustomers / totalCustomers : 0.0;
    
    return {
      'totalCustomers': totalCustomers,
      'returningCustomers': returningCustomers,
      'returnRate': double.parse(returnRate.toStringAsFixed(3)),
      'averageVisitsPerCustomer': totalCustomers > 0 
          ? double.parse((feedbackList.length / totalCustomers).toStringAsFixed(2))
          : 0.0,
    };
  }

  /// Generate actionable recommendations
  static List<String> _generateRecommendations(
    Map<String, dynamic> analytics,
    Map<String, dynamic> sentiment,
  ) {
    final recommendations = <String>[];
    final avgRating = analytics['averageRating'] as double;
    final conversionRate = analytics['conversionRate'] as double;
    final negativePercentage = double.parse(sentiment['negativePercentage'] as String);
    
    if (avgRating < 3.5) {
      recommendations.add('Focus on improving overall customer experience - average rating is below 3.5 stars');
    }
    
    if (conversionRate < 0.5) {
      recommendations.add('Work on increasing purchase conversion - less than 50% of visitors make purchases');
    }
    
    if (negativePercentage > 20) {
      recommendations.add('Address customer concerns - over 20% of feedback is negative');
    }
    
    // Category-specific recommendations
    final categoryAverages = analytics['categoryAverages'] as Map<String, dynamic>;
    for (final entry in categoryAverages.entries) {
      if (entry.value < 3.0) {
        recommendations.add('Improve ${entry.key} - currently rated below 3.0 stars');
      }
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('Great job! Customer satisfaction metrics are strong across all areas');
    }
    
    return recommendations;
  }

  /// Get category breakdown analysis
  static Map<String, dynamic> _getCategoryBreakdown(List<CustomerFeedback> feedbackList) {
    final categoryData = <String, List<int>>{};
    
    for (final feedback in feedbackList) {
      for (final entry in feedback.categoryRatings.entries) {
        categoryData.putIfAbsent(entry.key.name, () => []);
        categoryData[entry.key.name]!.add(entry.value);
      }
    }
    
    return categoryData.map((category, ratings) {
      final average = ratings.fold(0, (a, b) => a + b) / ratings.length;
      return MapEntry(category, {
        'average': double.parse(average.toStringAsFixed(2)),
        'count': ratings.length,
        'distribution': {
          for (int i = 1; i <= 5; i++)
            '$i-star': ratings.where((r) => r == i).length,
        },
      });
    });
  }

  /// Get time-based analysis
  static Map<String, dynamic> _getTimeAnalysis(List<CustomerFeedback> feedbackList) {
    final dayOfWeekData = <int, List<int>>{};
    final hourData = <int, List<int>>{};
    
    for (final feedback in feedbackList) {
      final dayOfWeek = feedback.visitDate.weekday;
      final hour = feedback.visitDate.hour;
      
      dayOfWeekData.putIfAbsent(dayOfWeek, () => []);
      dayOfWeekData[dayOfWeek]!.add(feedback.overallRating);
      
      hourData.putIfAbsent(hour, () => []);
      hourData[hour]!.add(feedback.overallRating);
    }
    
    return {
      'byDayOfWeek': dayOfWeekData.map((day, ratings) => MapEntry(
        ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][day - 1],
        {
          'averageRating': ratings.fold(0, (a, b) => a + b) / ratings.length,
          'feedbackCount': ratings.length,
        },
      )),
      'byHour': hourData.map((hour, ratings) => MapEntry(
        hour.toString(),
        {
          'averageRating': ratings.fold(0, (a, b) => a + b) / ratings.length,
          'feedbackCount': ratings.length,
        },
      )),
    };
  }

  /// Get customer segmentation
  static Map<String, dynamic> _getCustomerSegmentation(List<CustomerFeedback> feedbackList) {
    final segments = <String, List<CustomerFeedback>>{};
    
    for (final feedback in feedbackList) {
      final userType = feedback.userType ?? 'unknown';
      segments.putIfAbsent(userType, () => []);
      segments[userType]!.add(feedback);
    }
    
    return segments.map((segment, feedbacks) => MapEntry(segment, {
      'count': feedbacks.length,
      'averageRating': feedbacks.map((f) => f.overallRating).fold(0, (a, b) => a + b) / feedbacks.length,
      'conversionRate': feedbacks.where((f) => f.madeAPurchase).length / feedbacks.length,
    }));
  }

  /// Get purchase patterns
  static Map<String, dynamic> _getPurchasePatterns(List<CustomerFeedback> feedbackList) {
    final purchaseData = feedbackList.where((f) => f.madeAPurchase).toList();
    
    if (purchaseData.isEmpty) {
      return {'totalPurchases': 0, 'averageSpend': 0.0, 'spendDistribution': {}};
    }
    
    final spendAmounts = purchaseData
        .where((f) => f.estimatedSpendAmount != null)
        .map((f) => f.estimatedSpendAmount!)
        .toList();
    
    return {
      'totalPurchases': purchaseData.length,
      'averageSpend': spendAmounts.isNotEmpty 
          ? spendAmounts.fold(0.0, (a, b) => a + b) / spendAmounts.length 
          : 0.0,
      'spendDistribution': {
        'under10': spendAmounts.where((s) => s < 10).length,
        '10to25': spendAmounts.where((s) => s >= 10 && s < 25).length,
        '25to50': spendAmounts.where((s) => s >= 25 && s < 50).length,
        'over50': spendAmounts.where((s) => s >= 50).length,
      },
    };
  }

  /// Helper method to convert UniversalReview to CustomerFeedback for backwards compatibility
  static CustomerFeedback _convertUniversalReviewToCustomerFeedback(UniversalReview review) {
    // Convert aspect ratings back to category ratings
    final categoryRatings = <ReviewCategory, int>{};
    for (final entry in review.aspectRatings.entries) {
      try {
        final category = ReviewCategory.values.firstWhere(
          (c) => c.name == entry.key,
          orElse: () => ReviewCategory.quality,
        );
        categoryRatings[category] = entry.value.round();
      } catch (e) {
        // Skip unknown categories
      }
    }

    // Determine target type and IDs
    final isVendor = review.reviewedType == 'vendor';
    final target = isVendor ? FeedbackTarget.vendor : FeedbackTarget.market;

    return CustomerFeedback(
      id: review.id,
      userId: review.reviewerId,
      marketId: isVendor ? null : review.reviewedId,
      vendorId: isVendor ? review.reviewedId : null,
      eventId: review.eventId,
      target: target,
      overallRating: review.overallRating.round(),
      categoryRatings: categoryRatings,
      reviewText: review.reviewText,
      isAnonymous: review.isAnonymous,
      visitDate: review.eventDate,
      createdAt: review.createdAt,
      updatedAt: review.updatedAt,
      tags: review.tags,
      wouldRecommend: review.overallRating >= 4.0, // Inferred from rating
      npsScore: review.overallRating >= 4.0 ? 8 : 5, // Estimated NPS
      sessionId: 'migrated-${review.id}', // Generated session ID
      madeAPurchase: false, // Not tracked in UniversalReview
    );
  }
}