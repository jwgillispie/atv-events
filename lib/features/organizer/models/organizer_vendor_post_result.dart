import 'package:equatable/equatable.dart';
import '../../market/models/market.dart';
import 'organizer_vendor_post.dart';

class OrganizerVendorPostResult extends Equatable {
  final OrganizerVendorPost post;
  final Market market;
  final double relevanceScore;
  final double? distanceFromVendor;
  final List<String> matchReasons;
  final List<String> opportunities;
  final bool isPremiumOnly;
  final DateTime? applicationDeadline;
  final bool isUrgent;
  final int responseCount;

  const OrganizerVendorPostResult({
    required this.post,
    required this.market,
    required this.relevanceScore,
    this.distanceFromVendor,
    required this.matchReasons,
    required this.opportunities,
    required this.isPremiumOnly,
    this.applicationDeadline,
    this.isUrgent = false,
    this.responseCount = 0,
  });

  bool get hasApplicationDeadline => applicationDeadline != null;
  
  bool get isDeadlineApproaching {
    if (applicationDeadline == null) return false;
    final now = DateTime.now();
    final daysUntilDeadline = applicationDeadline!.difference(now).inDays;
    return daysUntilDeadline <= 7 && daysUntilDeadline >= 0;
  }

  bool get isExpired {
    if (applicationDeadline == null) return false;
    return DateTime.now().isAfter(applicationDeadline!);
  }

  String get urgencyLevel {
    if (isExpired) return 'expired';
    if (isDeadlineApproaching) return 'urgent';
    if (isUrgent) return 'high';
    return 'normal';
  }

  @override
  List<Object?> get props => [
        post,
        market,
        relevanceScore,
        distanceFromVendor,
        matchReasons,
        opportunities,
        isPremiumOnly,
        applicationDeadline,
        isUrgent,
        responseCount,
      ];

  @override
  String toString() {
    return 'OrganizerVendorPostResult(title: ${post.title}, relevanceScore: $relevanceScore, market: ${market.name})';
  }
}