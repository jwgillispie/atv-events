import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Universal review model that handles all review relationships
/// Replaces CustomerFeedback and MarketRating with a single unified model
class UniversalReview {
  final String id;
  final String reviewerId; // User who wrote the review
  final String reviewerName;
  final String reviewerType; // 'shopper', 'vendor', 'organizer'
  final String? reviewerBusinessName; // For vendors/organizers
  final String? reviewerPhotoUrl;

  final String reviewedId; // Entity being reviewed
  final String reviewedName;
  final String reviewedType; // 'vendor', 'market', 'organizer'
  final String? reviewedBusinessName;

  // Context for the review
  final String? eventId; // The event/market where interaction happened
  final String? eventName;
  final DateTime eventDate;

  // Core review data
  final double overallRating; // 1-5 stars with 0.5 increments
  final String? reviewText;
  final List<String> photos; // Up to 3 photos
  final Map<String, double> aspectRatings; // Dynamic based on relationship
  final List<String> tags; // Quick tags like "Great selection", "Fair prices"

  // Response capability
  final String? responseText;
  final DateTime? responseDate;
  final String? responderId;
  final String? responderName;

  // Verification and trust
  final bool isVerified; // GPS check-in, QR scan, or purchase proof
  final String? verificationMethod; // 'gps', 'qr', 'purchase', 'registration'
  final bool isAnonymous;

  // Engagement metrics
  final int helpfulCount;
  final List<String> helpfulVoters; // User IDs who marked helpful
  final bool isFlagged;
  final String? flagReason;

  // Metadata
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastEditedAt;
  final int editCount;

  // Matching algorithm data
  final Map<String, dynamic> matchingSignals; // For AI/ML matching

  UniversalReview({
    required this.id,
    required this.reviewerId,
    required this.reviewerName,
    required this.reviewerType,
    this.reviewerBusinessName,
    this.reviewerPhotoUrl,
    required this.reviewedId,
    required this.reviewedName,
    required this.reviewedType,
    this.reviewedBusinessName,
    this.eventId,
    this.eventName,
    required this.eventDate,
    required this.overallRating,
    this.reviewText,
    this.photos = const [],
    this.aspectRatings = const {},
    this.tags = const [],
    this.responseText,
    this.responseDate,
    this.responderId,
    this.responderName,
    this.isVerified = false,
    this.verificationMethod,
    this.isAnonymous = false,
    this.helpfulCount = 0,
    this.helpfulVoters = const [],
    this.isFlagged = false,
    this.flagReason,
    required this.createdAt,
    this.updatedAt,
    this.lastEditedAt,
    this.editCount = 0,
    this.matchingSignals = const {},
  });

  /// Get aspect ratings based on relationship type
  static Map<String, String> getAspectDefinitions(String reviewerType, String reviewedType) {
    // Shopper → Vendor
    if (reviewerType == 'shopper' && reviewedType == 'vendor') {
      return {
        'quality': 'Product quality & freshness',
        'selection': 'Variety & selection',
        'value': 'Pricing & value',
        'service': 'Customer service',
        'presentation': 'Display & presentation',
      };
    }

    // Shopper → Market
    if (reviewerType == 'shopper' && reviewedType == 'market') {
      return {
        'atmosphere': 'Overall vibe & ambiance',
        'variety': 'Vendor variety & selection',
        'organization': 'Layout & organization',
        'facilities': 'Amenities & facilities',
        'accessibility': 'Parking & accessibility',
      };
    }

    // Vendor → Market/Organizer
    if (reviewerType == 'vendor' && (reviewedType == 'market' || reviewedType == 'organizer')) {
      return {
        'organization': 'Setup & organization',
        'communication': 'Communication & support',
        'marketing': 'Marketing & promotion',
        'facilities': 'Facilities & amenities',
        'value': 'Fee value & ROI',
      };
    }

    // Organizer → Vendor
    if (reviewerType == 'organizer' && reviewedType == 'vendor') {
      return {
        'professionalism': 'Professional conduct',
        'reliability': 'Punctuality & reliability',
        'presentation': 'Booth presentation',
        'engagement': 'Customer engagement',
        'compliance': 'Rule compliance',
      };
    }

    return {};
  }

  /// Get suggested tags based on relationship and rating
  static List<String> getSuggestedTags(String reviewerType, String reviewedType, double rating) {
    final isPositive = rating >= 4.0;

    // Shopper → Vendor tags
    if (reviewerType == 'shopper' && reviewedType == 'vendor') {
      return isPositive ? [
        'Great quality',
        'Fair prices',
        'Friendly service',
        'Fresh products',
        'Wide selection',
        'Will return',
        'Hidden gem',
        'Best at market',
      ] : [
        'Overpriced',
        'Limited selection',
        'Poor quality',
        'Unfriendly service',
        'Not fresh',
        'Disappointing',
      ];
    }

    // Shopper → Market tags
    if (reviewerType == 'shopper' && reviewedType == 'market') {
      return isPositive ? [
        'Great atmosphere',
        'Well organized',
        'Easy parking',
        'Family friendly',
        'Dog friendly',
        'Live music',
        'Food trucks',
        'Clean facilities',
      ] : [
        'Crowded',
        'Poor layout',
        'Parking issues',
        'Limited vendors',
        'Needs improvement',
        'Hard to navigate',
      ];
    }

    // Vendor → Market tags
    if (reviewerType == 'vendor' && (reviewedType == 'market' || reviewedType == 'organizer')) {
      return isPositive ? [
        'Well organized',
        'Great communication',
        'Good foot traffic',
        'Supportive staff',
        'Fair fees',
        'Easy setup',
        'Strong sales',
        'Will return',
      ] : [
        'Disorganized',
        'Poor communication',
        'Low traffic',
        'High fees',
        'Difficult setup',
        'Weak sales',
        'Needs improvement',
      ];
    }

    // Organizer → Vendor tags
    if (reviewerType == 'organizer' && reviewedType == 'vendor') {
      return isPositive ? [
        'Professional',
        'Reliable',
        'Great display',
        'Engaged customers',
        'On time',
        'Follows rules',
        'Adds value',
        'Crowd favorite',
      ] : [
        'Unprofessional',
        'Late arrival',
        'Poor display',
        'Rule violations',
        'Early departure',
        'Customer complaints',
      ];
    }

    return [];
  }

  factory UniversalReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UniversalReview(
      id: doc.id,
      reviewerId: data['reviewerId'] ?? '',
      reviewerName: data['reviewerName'] ?? '',
      reviewerType: data['reviewerType'] ?? '',
      reviewerBusinessName: data['reviewerBusinessName'],
      reviewerPhotoUrl: data['reviewerPhotoUrl'],
      reviewedId: data['reviewedId'] ?? '',
      reviewedName: data['reviewedName'] ?? '',
      reviewedType: data['reviewedType'] ?? '',
      reviewedBusinessName: data['reviewedBusinessName'],
      eventId: data['eventId'],
      eventName: data['eventName'],
      eventDate: (data['eventDate'] as Timestamp).toDate(),
      overallRating: (data['overallRating'] ?? 0).toDouble(),
      reviewText: data['reviewText'],
      photos: List<String>.from(data['photos'] ?? []),
      aspectRatings: Map<String, double>.from(data['aspectRatings'] ?? {}),
      tags: List<String>.from(data['tags'] ?? []),
      responseText: data['responseText'],
      responseDate: data['responseDate'] != null
          ? (data['responseDate'] as Timestamp).toDate()
          : null,
      responderId: data['responderId'],
      responderName: data['responderName'],
      isVerified: data['isVerified'] ?? false,
      verificationMethod: data['verificationMethod'],
      isAnonymous: data['isAnonymous'] ?? false,
      helpfulCount: data['helpfulCount'] ?? 0,
      helpfulVoters: List<String>.from(data['helpfulVoters'] ?? []),
      isFlagged: data['isFlagged'] ?? false,
      flagReason: data['flagReason'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      lastEditedAt: data['lastEditedAt'] != null
          ? (data['lastEditedAt'] as Timestamp).toDate()
          : null,
      editCount: data['editCount'] ?? 0,
      matchingSignals: Map<String, dynamic>.from(data['matchingSignals'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewerType': reviewerType,
      'reviewerBusinessName': reviewerBusinessName,
      'reviewerPhotoUrl': reviewerPhotoUrl,
      'reviewedId': reviewedId,
      'reviewedName': reviewedName,
      'reviewedType': reviewedType,
      'reviewedBusinessName': reviewedBusinessName,
      'eventId': eventId,
      'eventName': eventName,
      'eventDate': Timestamp.fromDate(eventDate),
      'overallRating': overallRating,
      'reviewText': reviewText,
      'photos': photos,
      'aspectRatings': aspectRatings,
      'tags': tags,
      'responseText': responseText,
      'responseDate': responseDate != null ? Timestamp.fromDate(responseDate!) : null,
      'responderId': responderId,
      'responderName': responderName,
      'isVerified': isVerified,
      'verificationMethod': verificationMethod,
      'isAnonymous': isAnonymous,
      'helpfulCount': helpfulCount,
      'helpfulVoters': helpfulVoters,
      'isFlagged': isFlagged,
      'flagReason': flagReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'lastEditedAt': lastEditedAt != null ? Timestamp.fromDate(lastEditedAt!) : null,
      'editCount': editCount,
      'matchingSignals': matchingSignals,
    };
  }

  /// Calculate average aspect rating
  double get averageAspectRating {
    if (aspectRatings.isEmpty) return overallRating;
    final total = aspectRatings.values.fold(0.0, (sum, rating) => sum + rating);
    return total / aspectRatings.length;
  }

  /// Check if this is a positive review
  bool get isPositive => overallRating >= 4.0;

  /// Check if this is a critical review
  bool get isCritical => overallRating <= 2.0;

  /// Get review age for display
  String get ageDisplay {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}mo ago';
    }
    return '${(difference.inDays / 365).floor()}y ago';
  }

  /// Get color for rating display
  Color get ratingColor {
    if (overallRating >= 4.5) return Colors.green;
    if (overallRating >= 4.0) return Colors.lightGreen;
    if (overallRating >= 3.0) return Colors.orange;
    if (overallRating >= 2.0) return Colors.deepOrange;
    return Colors.red;
  }

  /// Format for matching algorithm
  Map<String, dynamic> toMatchingData() {
    return {
      'reviewerType': reviewerType,
      'reviewedType': reviewedType,
      'overallRating': overallRating,
      'averageAspectRating': averageAspectRating,
      'hasPhotos': photos.isNotEmpty,
      'hasDetailedReview': (reviewText?.length ?? 0) > 100,
      'isVerified': isVerified,
      'helpfulRatio': helpfulCount / (helpfulVoters.length + 1),
      'sentiment': isPositive ? 'positive' : (isCritical ? 'negative' : 'neutral'),
      'engagement': {
        'hasResponse': responseText != null,
        'responseTime': responseDate != null
            ? responseDate!.difference(createdAt).inHours
            : null,
      },
      ...matchingSignals,
    };
  }
}

/// Aggregated review statistics for an entity
class ReviewStats {
  final String entityId;
  final String entityType;
  final int totalReviews;
  final double averageRating;
  final Map<String, double> aspectAverages;
  final Map<int, int> ratingDistribution; // 1-5 star counts
  final Map<String, int> reviewerTypeBreakdown; // Count by reviewer type
  final List<String> topTags;
  final int verifiedCount;
  final int photoCount;
  final double responseRate;
  final Duration? averageResponseTime;

  ReviewStats({
    required this.entityId,
    required this.entityType,
    required this.totalReviews,
    required this.averageRating,
    required this.aspectAverages,
    required this.ratingDistribution,
    required this.reviewerTypeBreakdown,
    required this.topTags,
    required this.verifiedCount,
    required this.photoCount,
    required this.responseRate,
    this.averageResponseTime,
  });

  /// Calculate from list of reviews
  factory ReviewStats.fromReviews(String entityId, String entityType, List<UniversalReview> reviews) {
    if (reviews.isEmpty) {
      return ReviewStats(
        entityId: entityId,
        entityType: entityType,
        totalReviews: 0,
        averageRating: 0,
        aspectAverages: {},
        ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        reviewerTypeBreakdown: {},
        topTags: [],
        verifiedCount: 0,
        photoCount: 0,
        responseRate: 0,
      );
    }

    // Calculate average rating
    final totalRating = reviews.fold(0.0, (sum, r) => sum + r.overallRating);
    final avgRating = totalRating / reviews.length;

    // Calculate aspect averages
    final aspectTotals = <String, double>{};
    final aspectCounts = <String, int>{};
    for (final review in reviews) {
      for (final entry in review.aspectRatings.entries) {
        aspectTotals[entry.key] = (aspectTotals[entry.key] ?? 0) + entry.value;
        aspectCounts[entry.key] = (aspectCounts[entry.key] ?? 0) + 1;
      }
    }
    final aspectAvgs = aspectTotals.map((key, total) =>
        MapEntry(key, total / aspectCounts[key]!));

    // Calculate rating distribution
    final distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final review in reviews) {
      final roundedRating = review.overallRating.round().clamp(1, 5);
      distribution[roundedRating] = distribution[roundedRating]! + 1;
    }

    // Calculate reviewer type breakdown
    final typeBreakdown = <String, int>{};
    for (final review in reviews) {
      typeBreakdown[review.reviewerType] =
          (typeBreakdown[review.reviewerType] ?? 0) + 1;
    }

    // Get top tags
    final tagCounts = <String, int>{};
    for (final review in reviews) {
      for (final tag in review.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    final sortedTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTags = sortedTags.take(5).map((e) => e.key).toList();

    // Calculate other metrics
    final verifiedCount = reviews.where((r) => r.isVerified).length;
    final photoCount = reviews.where((r) => r.photos.isNotEmpty).length;
    final responsesCount = reviews.where((r) => r.responseText != null).length;
    final responseRate = responsesCount / reviews.length;

    // Calculate average response time
    Duration? avgResponseTime;
    final responseTimes = reviews
        .where((r) => r.responseDate != null)
        .map((r) => r.responseDate!.difference(r.createdAt))
        .toList();
    if (responseTimes.isNotEmpty) {
      final totalSeconds = responseTimes.fold(0,
          (sum, duration) => sum + duration.inSeconds);
      avgResponseTime = Duration(seconds: totalSeconds ~/ responseTimes.length);
    }

    return ReviewStats(
      entityId: entityId,
      entityType: entityType,
      totalReviews: reviews.length,
      averageRating: avgRating,
      aspectAverages: aspectAvgs,
      ratingDistribution: distribution,
      reviewerTypeBreakdown: typeBreakdown,
      topTags: topTags,
      verifiedCount: verifiedCount,
      photoCount: photoCount,
      responseRate: responseRate,
      averageResponseTime: avgResponseTime,
    );
  }

  /// Get percentage for a specific star rating
  double getRatingPercentage(int stars) {
    if (totalReviews == 0) return 0;
    return (ratingDistribution[stars] ?? 0) / totalReviews * 100;
  }

  /// Get formatted average rating
  String get formattedRating => averageRating.toStringAsFixed(1);

  /// Get review count display
  String get reviewCountDisplay {
    if (totalReviews >= 1000) {
      return '${(totalReviews / 1000).toStringAsFixed(1)}k reviews';
    }
    return '$totalReviews ${totalReviews == 1 ? 'review' : 'reviews'}';
  }
}