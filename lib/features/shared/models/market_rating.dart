import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// DEPRECATED: This model is being replaced by UniversalReview
///
/// Migration Guide:
/// - Use UniversalReview for all rating relationships (vendor→market, shopper→vendor, etc.)
/// - MarketRating.vendorId maps to UniversalReview.reviewerId
/// - MarketRating.marketId maps to UniversalReview.reviewedId (with reviewedType='market')
/// - MarketRating.overallRating maps to UniversalReview.overallRating
/// - MarketRating.review maps to UniversalReview.reviewText
/// - MarketRating.categoryRatings maps to UniversalReview.aspectRatings
/// - MarketRating.organizerResponse maps to UniversalReview.responseText
///
/// For new features, use:
/// - UniversalReviewService.submitReview() with reviewedType='market' and reviewerType='vendor'
/// - UniversalReviewService.getReviewsForEntity() to fetch market ratings
/// - UniversalReviewService.respondToReview() for organizer responses
///
/// This model will be removed in a future version.
///
/// Simplified market rating model for vendor-to-market ratings
@Deprecated('Use UniversalReview instead. This model is maintained for backwards compatibility only.')
class MarketRating {
  final String id;
  final String vendorId;
  final String vendorName;
  final String vendorBusinessName;
  final String marketId;
  final String marketName;
  final String organizerId;
  final double overallRating; // 1-5 stars
  final String? review;
  final Map<String, double> categoryRatings; // organization, communication, facilities, support
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? organizerResponse;
  final DateTime? organizerResponseAt;

  MarketRating({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.vendorBusinessName,
    required this.marketId,
    required this.marketName,
    required this.organizerId,
    required this.overallRating,
    this.review,
    required this.categoryRatings,
    required this.createdAt,
    this.updatedAt,
    this.organizerResponse,
    this.organizerResponseAt,
  });

  factory MarketRating.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MarketRating(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      vendorName: data['vendorName'] ?? '',
      vendorBusinessName: data['vendorBusinessName'] ?? '',
      marketId: data['marketId'] ?? '',
      marketName: data['marketName'] ?? '',
      organizerId: data['organizerId'] ?? '',
      overallRating: (data['overallRating'] ?? 0).toDouble(),
      review: data['review'],
      categoryRatings: Map<String, double>.from(
        data['categoryRatings'] ?? {
          'organization': 0.0,
          'communication': 0.0,
          'facilities': 0.0,
          'support': 0.0,
        },
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      organizerResponse: data['organizerResponse'],
      organizerResponseAt: data['organizerResponseAt'] != null
          ? (data['organizerResponseAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'vendorName': vendorName,
      'vendorBusinessName': vendorBusinessName,
      'marketId': marketId,
      'marketName': marketName,
      'organizerId': organizerId,
      'overallRating': overallRating,
      'review': review,
      'categoryRatings': categoryRatings,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'organizerResponse': organizerResponse,
      'organizerResponseAt': organizerResponseAt != null 
          ? Timestamp.fromDate(organizerResponseAt!) 
          : null,
    };
  }

  MarketRating copyWith({
    String? id,
    String? vendorId,
    String? vendorName,
    String? vendorBusinessName,
    String? marketId,
    String? marketName,
    String? organizerId,
    double? overallRating,
    String? review,
    Map<String, double>? categoryRatings,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? organizerResponse,
    DateTime? organizerResponseAt,
  }) {
    return MarketRating(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      vendorBusinessName: vendorBusinessName ?? this.vendorBusinessName,
      marketId: marketId ?? this.marketId,
      marketName: marketName ?? this.marketName,
      organizerId: organizerId ?? this.organizerId,
      overallRating: overallRating ?? this.overallRating,
      review: review ?? this.review,
      categoryRatings: categoryRatings ?? this.categoryRatings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      organizerResponse: organizerResponse ?? this.organizerResponse,
      organizerResponseAt: organizerResponseAt ?? this.organizerResponseAt,
    );
  }
}

/// Rating categories for vendor evaluation of markets
/// DEPRECATED: Use UniversalReview.getAspectDefinitions('vendor', 'market') for category definitions
@Deprecated('Use UniversalReview.getAspectDefinitions() for dynamic category definitions')
class RatingCategory {
  static const String organization = 'organization';
  static const String communication = 'communication';
  static const String facilities = 'facilities';
  static const String support = 'support';
  
  static const Map<String, String> labels = {
    organization: 'Organization & Setup',
    communication: 'Communication',
    facilities: 'Facilities & Amenities',
    support: 'Vendor Support',
  };
  
  static const Map<String, IconData> icons = {
    organization: Icons.event_note,
    communication: Icons.chat,
    facilities: Icons.business,
    support: Icons.support_agent,
  };
}