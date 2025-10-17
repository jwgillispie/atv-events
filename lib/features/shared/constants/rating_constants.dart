import 'package:flutter/material.dart';
import '../models/customer_feedback.dart';

/// Centralized constants for all rating-related features
class RatingConstants {
  RatingConstants._();

  /// Rating descriptions for different star values
  static const Map<int, String> ratingDescriptions = {
    1: 'Poor - Would not return',
    2: 'Fair - Below expectations',
    3: 'Good - Met expectations',
    4: 'Very Good - Exceeded expectations',
    5: 'Excellent - Outstanding experience',
  };

  /// Short rating labels
  static const Map<int, String> shortRatingLabels = {
    1: 'Poor',
    2: 'Fair',
    3: 'Good',
    4: 'Very Good',
    5: 'Excellent',
  };

  /// Category-specific descriptions for vendor ratings
  static const Map<ReviewCategory, String> vendorCategoryDescriptions = {
    ReviewCategory.quality: 'Freshness and quality of products',
    ReviewCategory.variety: 'Selection and range of offerings',
    ReviewCategory.prices: 'Value for money and fair pricing',
    ReviewCategory.service: 'Friendliness and knowledge of staff',
  };

  /// Category-specific descriptions for market ratings
  static const Map<ReviewCategory, String> marketCategoryDescriptions = {
    ReviewCategory.organization: 'Layout, flow, and vendor arrangement',
    ReviewCategory.atmosphere: 'Overall ambiance and experience',
    ReviewCategory.cleanliness: 'Facility cleanliness and maintenance',
    ReviewCategory.accessibility: 'Ease of access and navigation',
  };

  /// Icons for review categories
  static const Map<ReviewCategory, IconData> categoryIcons = {
    ReviewCategory.quality: Icons.star,
    ReviewCategory.variety: Icons.category,
    ReviewCategory.prices: Icons.attach_money,
    ReviewCategory.service: Icons.support_agent,
    ReviewCategory.cleanliness: Icons.cleaning_services,
    ReviewCategory.atmosphere: Icons.celebration,
    ReviewCategory.accessibility: Icons.accessible,
    ReviewCategory.organization: Icons.dashboard_customize,
  };

  /// Arrival methods for market visits
  static const List<String> arrivalMethods = [
    'Walking',
    'Driving',
    'Cycling',
    'Public Transit',
    'Rideshare/Taxi',
    'Other',
  ];

  /// Icons for arrival methods
  static const Map<String, IconData> arrivalMethodIcons = {
    'Walking': Icons.directions_walk,
    'Driving': Icons.directions_car,
    'Cycling': Icons.directions_bike,
    'Public Transit': Icons.directions_bus,
    'Rideshare/Taxi': Icons.local_taxi,
    'Other': Icons.more_horiz,
  };

  /// Success messages for different rating types
  static const Map<FeedbackTarget, String> successMessages = {
    FeedbackTarget.vendor: 'Thank you for rating this vendor!',
    FeedbackTarget.market: 'Thank you for your market feedback!',
    FeedbackTarget.event: 'Thank you for rating this event!',
    FeedbackTarget.overall: 'Thank you for your feedback!',
  };

  /// Minimum review text lengths (optional reviews)
  static const int minReviewLength = 10;
  static const int maxReviewLength = 500;

  /// NPS Score thresholds
  static const int npsDetractorMax = 6;
  static const int npsPassiveMax = 8;
  static const int npsPromoterMin = 9;

  /// Rating quality thresholds
  static const double excellentRatingThreshold = 4.5;
  static const double goodRatingThreshold = 4.0;
  static const double averageRatingThreshold = 3.0;
  static const double poorRatingThreshold = 2.0;

  /// Cache durations
  static const Duration ratingsCacheDuration = Duration(minutes: 15);
  static const Duration analyticsCacheDuration = Duration(minutes: 30);

  /// Validation helpers
  static bool isValidRating(int rating) => rating >= 1 && rating <= 5;
  static bool isValidNPS(int score) => score >= 0 && score <= 10;
  
  /// Get color for rating value
  static Color getRatingColor(double rating) {
    if (rating >= excellentRatingThreshold) return Colors.green.shade600;
    if (rating >= goodRatingThreshold) return Colors.lightGreen.shade600;
    if (rating >= averageRatingThreshold) return Colors.orange.shade600;
    if (rating >= poorRatingThreshold) return Colors.deepOrange.shade600;
    return Colors.red.shade600;
  }

  /// Get icon for rating value
  static IconData getRatingIcon(double rating) {
    if (rating >= excellentRatingThreshold) return Icons.sentiment_very_satisfied;
    if (rating >= goodRatingThreshold) return Icons.sentiment_satisfied;
    if (rating >= averageRatingThreshold) return Icons.sentiment_neutral;
    if (rating >= poorRatingThreshold) return Icons.sentiment_dissatisfied;
    return Icons.sentiment_very_dissatisfied;
  }

  /// Format rating display
  static String formatRating(double rating, {int decimals = 1}) {
    return rating.toStringAsFixed(decimals);
  }

  /// Format review count
  static String formatReviewCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  /// Get review age label
  static String getReviewAgeLabel(DateTime reviewDate) {
    final now = DateTime.now();
    final difference = now.difference(reviewDate);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes < 5) return 'Just now';
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years == 1 ? '' : 's'} ago';
    }
  }
}