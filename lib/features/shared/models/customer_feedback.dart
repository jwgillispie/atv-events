import 'package:cloud_firestore/cloud_firestore.dart';

/// DEPRECATED: This model is being replaced by UniversalReview
///
/// Migration Guide:
/// - Use UniversalReview instead of CustomerFeedback
/// - CustomerFeedback.vendorId maps to UniversalReview.reviewedId (with reviewedType='vendor')
/// - CustomerFeedback.marketId maps to UniversalReview.reviewedId (with reviewedType='market')
/// - CustomerFeedback.categoryRatings maps to UniversalReview.aspectRatings
/// - CustomerFeedback.overallRating maps to UniversalReview.overallRating (as double)
/// - CustomerFeedback.reviewText maps to UniversalReview.reviewText
/// - CustomerFeedback.isAnonymous maps to UniversalReview.isAnonymous
/// - CustomerFeedback.visitDate maps to UniversalReview.eventDate
///
/// For new features, use:
/// - UniversalReviewService.submitReview() instead of CustomerFeedbackService.submitFeedback()
/// - UniversalReviewService.getReviewsForEntity() instead of CustomerFeedbackService.getMarketFeedback()
///
/// This model will be removed in a future version.
///
/// Enum for different review categories to provide structured feedback
@Deprecated('Use UniversalReview.getAspectDefinitions() for category/aspect definitions')
enum ReviewCategory {
  quality,
  variety,
  prices,
  service,
  cleanliness,
  atmosphere,
  accessibility,
  organization
}

/// Enum for different types of feedback targets
enum FeedbackTarget {
  market,
  vendor,
  event,
  overall
}

/// Model representing customer feedback for markets, vendors, and events
/// This replaces mock customer data with real satisfaction metrics
///
/// DEPRECATED: Use UniversalReview instead
@Deprecated('Use UniversalReview instead. This model is maintained for backwards compatibility only.')
class CustomerFeedback {
  final String id;
  final String? userId; // Optional - anonymous feedback allowed
  final String? marketId;
  final String? vendorId;
  final String? eventId;
  final FeedbackTarget target;
  final int overallRating; // 1-5 stars
  final Map<ReviewCategory, int> categoryRatings; // 1-5 for each category
  final String? reviewText;
  final bool isAnonymous;
  final DateTime visitDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Additional context for analytics
  final String? userType; // 'regular', 'returning', 'new'
  final int? userAge; // Optional demographic data
  final String? userLocation; // General area, not specific address
  final List<String>? tags; // ['family-friendly', 'accessible', 'value', etc.]
  final bool wouldRecommend;
  final int? npsScore; // Net Promoter Score (0-10)
  
  // Interaction tracking for loyalty analytics
  final String sessionId;
  final Duration? timeSpentAtVendor;
  final Duration? timeSpentAtMarket;
  final bool madeAPurchase;
  final double? estimatedSpendAmount;

  const CustomerFeedback({
    required this.id,
    this.userId,
    this.marketId,
    this.vendorId,
    this.eventId,
    required this.target,
    required this.overallRating,
    required this.categoryRatings,
    this.reviewText,
    required this.isAnonymous,
    required this.visitDate,
    required this.createdAt,
    this.updatedAt,
    this.userType,
    this.userAge,
    this.userLocation,
    this.tags,
    required this.wouldRecommend,
    this.npsScore,
    required this.sessionId,
    this.timeSpentAtVendor,
    this.timeSpentAtMarket,
    required this.madeAPurchase,
    this.estimatedSpendAmount,
  });

  /// Create CustomerFeedback from Firestore document
  factory CustomerFeedback.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse category ratings from map
    final categoryRatingsData = data['categoryRatings'] as Map<String, dynamic>? ?? {};
    final categoryRatings = <ReviewCategory, int>{};
    
    for (final entry in categoryRatingsData.entries) {
      final category = ReviewCategory.values.firstWhere(
        (c) => c.name == entry.key,
        orElse: () => ReviewCategory.quality,
      );
      categoryRatings[category] = entry.value as int;
    }
    
    return CustomerFeedback(
      id: doc.id,
      userId: data['userId'] as String?,
      marketId: data['marketId'] as String?,
      vendorId: data['vendorId'] as String?,
      eventId: data['eventId'] as String?,
      target: FeedbackTarget.values.firstWhere(
        (t) => t.name == data['target'],
        orElse: () => FeedbackTarget.market,
      ),
      overallRating: data['overallRating'] as int,
      categoryRatings: categoryRatings,
      reviewText: data['reviewText'] as String?,
      isAnonymous: data['isAnonymous'] as bool? ?? false,
      visitDate: (data['visitDate'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      userType: data['userType'] as String?,
      userAge: data['userAge'] as int?,
      userLocation: data['userLocation'] as String?,
      tags: data['tags'] != null 
          ? List<String>.from(data['tags'] as List) 
          : null,
      wouldRecommend: data['wouldRecommend'] as bool? ?? false,
      npsScore: data['npsScore'] as int?,
      sessionId: data['sessionId'] as String,
      timeSpentAtVendor: data['timeSpentAtVendorSeconds'] != null
          ? Duration(seconds: data['timeSpentAtVendorSeconds'] as int)
          : null,
      timeSpentAtMarket: data['timeSpentAtMarketSeconds'] != null
          ? Duration(seconds: data['timeSpentAtMarketSeconds'] as int)
          : null,
      madeAPurchase: data['madeAPurchase'] as bool? ?? false,
      estimatedSpendAmount: data['estimatedSpendAmount'] as double?,
    );
  }

  /// Convert CustomerFeedback to Firestore map
  Map<String, dynamic> toFirestore() {
    final categoryRatingsData = <String, int>{};
    for (final entry in categoryRatings.entries) {
      categoryRatingsData[entry.key.name] = entry.value;
    }
    
    return {
      'userId': userId,
      'marketId': marketId,
      'vendorId': vendorId,
      'eventId': eventId,
      'target': target.name,
      'overallRating': overallRating,
      'categoryRatings': categoryRatingsData,
      'reviewText': reviewText,
      'isAnonymous': isAnonymous,
      'visitDate': Timestamp.fromDate(visitDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'userType': userType,
      'userAge': userAge,
      'userLocation': userLocation,
      'tags': tags,
      'wouldRecommend': wouldRecommend,
      'npsScore': npsScore,
      'sessionId': sessionId,
      'timeSpentAtVendorSeconds': timeSpentAtVendor?.inSeconds,
      'timeSpentAtMarketSeconds': timeSpentAtMarket?.inSeconds,
      'madeAPurchase': madeAPurchase,
      'estimatedSpendAmount': estimatedSpendAmount,
    };
  }

  /// Create a copy with updated values
  CustomerFeedback copyWith({
    String? id,
    String? userId,
    String? marketId,
    String? vendorId,
    String? eventId,
    FeedbackTarget? target,
    int? overallRating,
    Map<ReviewCategory, int>? categoryRatings,
    String? reviewText,
    bool? isAnonymous,
    DateTime? visitDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userType,
    int? userAge,
    String? userLocation,
    List<String>? tags,
    bool? wouldRecommend,
    int? npsScore,
    String? sessionId,
    Duration? timeSpentAtVendor,
    Duration? timeSpentAtMarket,
    bool? madeAPurchase,
    double? estimatedSpendAmount,
  }) {
    return CustomerFeedback(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      marketId: marketId ?? this.marketId,
      vendorId: vendorId ?? this.vendorId,
      eventId: eventId ?? this.eventId,
      target: target ?? this.target,
      overallRating: overallRating ?? this.overallRating,
      categoryRatings: categoryRatings ?? this.categoryRatings,
      reviewText: reviewText ?? this.reviewText,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      visitDate: visitDate ?? this.visitDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userType: userType ?? this.userType,
      userAge: userAge ?? this.userAge,
      userLocation: userLocation ?? this.userLocation,
      tags: tags ?? this.tags,
      wouldRecommend: wouldRecommend ?? this.wouldRecommend,
      npsScore: npsScore ?? this.npsScore,
      sessionId: sessionId ?? this.sessionId,
      timeSpentAtVendor: timeSpentAtVendor ?? this.timeSpentAtVendor,
      timeSpentAtMarket: timeSpentAtMarket ?? this.timeSpentAtMarket,
      madeAPurchase: madeAPurchase ?? this.madeAPurchase,
      estimatedSpendAmount: estimatedSpendAmount ?? this.estimatedSpendAmount,
    );
  }

  /// Calculate average category rating
  double get averageCategoryRating {
    if (categoryRatings.isEmpty) return overallRating.toDouble();
    
    final total = categoryRatings.values.fold(0, (accumulator, rating) => accumulator + rating);
    return total / categoryRatings.length;
  }

  /// Get the primary concern based on lowest category rating
  ReviewCategory? get primaryConcern {
    if (categoryRatings.isEmpty) return null;
    
    int lowestRating = 5;
    ReviewCategory? lowestCategory;
    
    for (final entry in categoryRatings.entries) {
      if (entry.value < lowestRating) {
        lowestRating = entry.value;
        lowestCategory = entry.key;
      }
    }
    
    return lowestCategory;
  }

  /// Get the strongest aspect based on highest category rating
  ReviewCategory? get strongestAspect {
    if (categoryRatings.isEmpty) return null;
    
    int highestRating = 1;
    ReviewCategory? highestCategory;
    
    for (final entry in categoryRatings.entries) {
      if (entry.value > highestRating) {
        highestRating = entry.value;
        highestCategory = entry.key;
      }
    }
    
    return highestCategory;
  }

  /// Check if this is positive feedback (4+ stars overall)
  bool get isPositiveFeedback => overallRating >= 4;

  /// Check if this is critical feedback (2 or lower overall)
  bool get isCriticalFeedback => overallRating <= 2;

  /// Generate feedback summary for analytics
  Map<String, dynamic> get analyticsData {
    return {
      'overallRating': overallRating,
      'averageCategoryRating': averageCategoryRating,
      'isPositive': isPositiveFeedback,
      'isCritical': isCriticalFeedback,
      'wouldRecommend': wouldRecommend,
      'npsScore': npsScore,
      'madeAPurchase': madeAPurchase,
      'estimatedSpendAmount': estimatedSpendAmount,
      'timeSpentMinutes': timeSpentAtMarket?.inMinutes ?? timeSpentAtVendor?.inMinutes,
      'primaryConcern': primaryConcern?.name,
      'strongestAspect': strongestAspect?.name,
      'reviewLength': reviewText?.length ?? 0,
      'tagCount': tags?.length ?? 0,
      'isAnonymous': isAnonymous,
      'userType': userType,
      'userAge': userAge,
      'dayOfWeek': visitDate.weekday,
      'hourOfDay': visitDate.hour,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is CustomerFeedback &&
        other.id == id &&
        other.userId == userId &&
        other.marketId == marketId &&
        other.vendorId == vendorId &&
        other.eventId == eventId &&
        other.target == target &&
        other.overallRating == overallRating &&
        other.sessionId == sessionId;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      marketId,
      vendorId,
      eventId,
      target,
      overallRating,
      sessionId,
    );
  }

  @override
  String toString() {
    return 'CustomerFeedback(id: $id, target: $target, overallRating: $overallRating, madeAPurchase: $madeAPurchase)';
  }
}

/// Extension methods for ReviewCategory enum
extension ReviewCategoryExtension on ReviewCategory {
  String get displayName {
    switch (this) {
      case ReviewCategory.quality:
        return 'Product Quality';
      case ReviewCategory.variety:
        return 'Product Variety';
      case ReviewCategory.prices:
        return 'Fair Prices';
      case ReviewCategory.service:
        return 'Customer Service';
      case ReviewCategory.cleanliness:
        return 'Cleanliness';
      case ReviewCategory.atmosphere:
        return 'Atmosphere';
      case ReviewCategory.accessibility:
        return 'Accessibility';
      case ReviewCategory.organization:
        return 'Organization';
    }
  }

  String get description {
    switch (this) {
      case ReviewCategory.quality:
        return 'Quality of products and goods offered';
      case ReviewCategory.variety:
        return 'Range and diversity of products available';
      case ReviewCategory.prices:
        return 'Value for money and pricing fairness';
      case ReviewCategory.service:
        return 'Friendliness and helpfulness of vendors';
      case ReviewCategory.cleanliness:
        return 'Overall cleanliness and hygiene';
      case ReviewCategory.atmosphere:
        return 'Market ambiance and overall feel';
      case ReviewCategory.accessibility:
        return 'Ease of access and mobility-friendly features';
      case ReviewCategory.organization:
        return 'Layout, signage, and overall organization';
    }
  }
}

/// Extension methods for FeedbackTarget enum
extension FeedbackTargetExtension on FeedbackTarget {
  String get displayName {
    switch (this) {
      case FeedbackTarget.market:
        return 'Market Experience';
      case FeedbackTarget.vendor:
        return 'Vendor Experience';
      case FeedbackTarget.event:
        return 'Event Experience';
      case FeedbackTarget.overall:
        return 'Overall Experience';
    }
  }
}