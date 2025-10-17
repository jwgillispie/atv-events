import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class MarketAnalytics extends Equatable {
  final String marketId;
  final String organizerId;
  final DateTime date;
  
  // Vendor metrics
  final int totalVendors;
  final int activeVendors;
  final int newVendorApplications;
  final int approvedApplications;
  final int rejectedApplications;
  
  // Event metrics
  final int totalEvents;
  final int publishedEvents;
  final int completedEvents;
  final int upcomingEvents;
  final double averageEventOccupancy;
  
  
  // Favorites metrics
  final int totalMarketFavorites;
  final int totalVendorFavorites;
  final int newMarketFavoritesToday;
  final int newVendorFavoritesToday;
  
  // Engagement metrics
  final int totalViews;
  final int uniqueVisitors;
  final double averageSessionDuration;
  final int totalSearches;
  
  // Revenue metrics (if applicable)
  final double totalRevenue;
  final double averageOrderValue;
  final int totalOrders;
  
  const MarketAnalytics({
    required this.marketId,
    required this.organizerId,
    required this.date,
    this.totalVendors = 0,
    this.activeVendors = 0,
    this.newVendorApplications = 0,
    this.approvedApplications = 0,
    this.rejectedApplications = 0,
    this.totalEvents = 0,
    this.publishedEvents = 0,
    this.completedEvents = 0,
    this.upcomingEvents = 0,
    this.averageEventOccupancy = 0.0,
    this.totalMarketFavorites = 0,
    this.totalVendorFavorites = 0,
    this.newMarketFavoritesToday = 0,
    this.newVendorFavoritesToday = 0,
    this.totalViews = 0,
    this.uniqueVisitors = 0,
    this.averageSessionDuration = 0.0,
    this.totalSearches = 0,
    this.totalRevenue = 0.0,
    this.averageOrderValue = 0.0,
    this.totalOrders = 0,
  });

  factory MarketAnalytics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return MarketAnalytics(
      marketId: data['marketId'] ?? '',
      organizerId: data['organizerId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalVendors: data['totalVendors'] ?? 0,
      activeVendors: data['activeVendors'] ?? 0,
      newVendorApplications: data['newVendorApplications'] ?? 0,
      approvedApplications: data['approvedApplications'] ?? 0,
      rejectedApplications: data['rejectedApplications'] ?? 0,
      totalEvents: data['totalEvents'] ?? 0,
      publishedEvents: data['publishedEvents'] ?? 0,
      completedEvents: data['completedEvents'] ?? 0,
      upcomingEvents: data['upcomingEvents'] ?? 0,
      averageEventOccupancy: (data['averageEventOccupancy'] ?? 0.0).toDouble(),
      totalMarketFavorites: data['totalMarketFavorites'] ?? 0,
      totalVendorFavorites: data['totalVendorFavorites'] ?? 0,
      newMarketFavoritesToday: data['newMarketFavoritesToday'] ?? 0,
      newVendorFavoritesToday: data['newVendorFavoritesToday'] ?? 0,
      totalViews: data['totalViews'] ?? 0,
      uniqueVisitors: data['uniqueVisitors'] ?? 0,
      averageSessionDuration: (data['averageSessionDuration'] ?? 0.0).toDouble(),
      totalSearches: data['totalSearches'] ?? 0,
      totalRevenue: (data['totalRevenue'] ?? 0.0).toDouble(),
      averageOrderValue: (data['averageOrderValue'] ?? 0.0).toDouble(),
      totalOrders: data['totalOrders'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'marketId': marketId,
      'organizerId': organizerId,
      'date': Timestamp.fromDate(date),
      'totalVendors': totalVendors,
      'activeVendors': activeVendors,
      'newVendorApplications': newVendorApplications,
      'approvedApplications': approvedApplications,
      'rejectedApplications': rejectedApplications,
      'totalEvents': totalEvents,
      'publishedEvents': publishedEvents,
      'completedEvents': completedEvents,
      'upcomingEvents': upcomingEvents,
      'averageEventOccupancy': averageEventOccupancy,
      'totalMarketFavorites': totalMarketFavorites,
      'totalVendorFavorites': totalVendorFavorites,
      'newMarketFavoritesToday': newMarketFavoritesToday,
      'newVendorFavoritesToday': newVendorFavoritesToday,
      'totalViews': totalViews,
      'uniqueVisitors': uniqueVisitors,
      'averageSessionDuration': averageSessionDuration,
      'totalSearches': totalSearches,
      'totalRevenue': totalRevenue,
      'averageOrderValue': averageOrderValue,
      'totalOrders': totalOrders,
    };
  }

  @override
  List<Object?> get props => [
        marketId,
        organizerId,
        date,
        totalVendors,
        activeVendors,
        newVendorApplications,
        approvedApplications,
        rejectedApplications,
        totalEvents,
        publishedEvents,
        completedEvents,
        upcomingEvents,
        averageEventOccupancy,
        totalMarketFavorites,
        totalVendorFavorites,
        newMarketFavoritesToday,
        newVendorFavoritesToday,
        totalViews,
        uniqueVisitors,
        averageSessionDuration,
        totalSearches,
        totalRevenue,
        averageOrderValue,
        totalOrders,
      ];
}

class AnalyticsSummary extends Equatable {
  final int totalVendors;
  final int totalEvents;
  final double totalRevenue;
  final int totalViews;
  final double growthRate;
  final Map<String, int> vendorApplicationsByStatus;
  final Map<String, int> eventsByStatus;
  final int totalFavorites;
  final Map<String, int> favoritesByType;
  final List<MarketAnalytics> dailyData;

  const AnalyticsSummary({
    this.totalVendors = 0,
    this.totalEvents = 0,
    this.totalRevenue = 0.0,
    this.totalViews = 0,
    this.growthRate = 0.0,
    this.vendorApplicationsByStatus = const {},
    this.eventsByStatus = const {},
    this.totalFavorites = 0,
    this.favoritesByType = const {},
    this.dailyData = const [],
  });

  @override
  List<Object?> get props => [
        totalVendors,
        totalEvents,
        totalRevenue,
        totalViews,
        growthRate,
        vendorApplicationsByStatus,
        eventsByStatus,
        totalFavorites,
        favoritesByType,
        dailyData,
      ];
}

enum AnalyticsTimeRange {
  week,
  month,
  quarter,
  year,
}

/// Enhanced analytics models for new 1:1 market-event system

/// Comprehensive vendor analytics model for new market-event system
class VendorAnalytics extends Equatable {
  final String vendorId;
  final DateTime date;
  final VendorPostMetrics postMetrics;
  final VendorMarketParticipation marketParticipation;
  final VendorMonthlyUsage monthlyUsage;
  final VendorConversionMetrics conversionMetrics;
  final VendorEngagementMetrics engagementMetrics;

  const VendorAnalytics({
    required this.vendorId,
    required this.date,
    required this.postMetrics,
    required this.marketParticipation,
    required this.monthlyUsage,
    required this.conversionMetrics,
    required this.engagementMetrics,
  });

  factory VendorAnalytics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return VendorAnalytics(
      vendorId: data['vendorId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      postMetrics: VendorPostMetrics.fromMap(data['postMetrics'] ?? {}),
      marketParticipation: VendorMarketParticipation.fromMap(data['marketParticipation'] ?? {}),
      monthlyUsage: VendorMonthlyUsage.fromMap(data['monthlyUsage'] ?? {}),
      conversionMetrics: VendorConversionMetrics.fromMap(data['conversionMetrics'] ?? {}),
      engagementMetrics: VendorEngagementMetrics.fromMap(data['engagementMetrics'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'date': Timestamp.fromDate(date),
      'postMetrics': postMetrics.toMap(),
      'marketParticipation': marketParticipation.toMap(),
      'monthlyUsage': monthlyUsage.toMap(),
      'conversionMetrics': conversionMetrics.toMap(),
      'engagementMetrics': engagementMetrics.toMap(),
    };
  }

  @override
  List<Object?> get props => [
    vendorId,
    date,
    postMetrics,
    marketParticipation,
    monthlyUsage,
    conversionMetrics,
    engagementMetrics,
  ];
}

/// Vendor post creation and management metrics
class VendorPostMetrics extends Equatable {
  final int totalPostsCreated;
  final int independentPosts;
  final int marketPosts;
  final int approvedPosts;
  final int deniedPosts;
  final int pendingPosts;
  final double completionRate;
  final double abandonmentRate;
  final Map<String, int> abandonmentStages;
  final double averageCreationTimeMinutes;

  const VendorPostMetrics({
    this.totalPostsCreated = 0,
    this.independentPosts = 0,
    this.marketPosts = 0,
    this.approvedPosts = 0,
    this.deniedPosts = 0,
    this.pendingPosts = 0,
    this.completionRate = 0.0,
    this.abandonmentRate = 0.0,
    this.abandonmentStages = const {},
    this.averageCreationTimeMinutes = 0.0,
  });

  factory VendorPostMetrics.fromMap(Map<String, dynamic> map) {
    return VendorPostMetrics(
      totalPostsCreated: map['totalPostsCreated'] ?? 0,
      independentPosts: map['independentPosts'] ?? 0,
      marketPosts: map['marketPosts'] ?? 0,
      approvedPosts: map['approvedPosts'] ?? 0,
      deniedPosts: map['deniedPosts'] ?? 0,
      pendingPosts: map['pendingPosts'] ?? 0,
      completionRate: (map['completionRate'] ?? 0.0).toDouble(),
      abandonmentRate: (map['abandonmentRate'] ?? 0.0).toDouble(),
      abandonmentStages: Map<String, int>.from(map['abandonmentStages'] ?? {}),
      averageCreationTimeMinutes: (map['averageCreationTimeMinutes'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalPostsCreated': totalPostsCreated,
      'independentPosts': independentPosts,
      'marketPosts': marketPosts,
      'approvedPosts': approvedPosts,
      'deniedPosts': deniedPosts,
      'pendingPosts': pendingPosts,
      'completionRate': completionRate,
      'abandonmentRate': abandonmentRate,
      'abandonmentStages': abandonmentStages,
      'averageCreationTimeMinutes': averageCreationTimeMinutes,
    };
  }

  @override
  List<Object?> get props => [
    totalPostsCreated,
    independentPosts,
    marketPosts,
    approvedPosts,
    deniedPosts,
    pendingPosts,
    completionRate,
    abandonmentRate,
    abandonmentStages,
    averageCreationTimeMinutes,
  ];
}

/// Vendor market participation analytics
class VendorMarketParticipation extends Equatable {
  final int totalMarketsApplied;
  final int uniqueMarketsParticipated;
  final int totalApplications;
  final int approvedApplications;
  final int deniedApplications;
  final double approvalRate;
  final List<String> topMarkets;
  final Map<String, int> participationByMarket;
  final bool isRepeatVendor;
  final int consecutiveEventsParticipated;

  const VendorMarketParticipation({
    this.totalMarketsApplied = 0,
    this.uniqueMarketsParticipated = 0,
    this.totalApplications = 0,
    this.approvedApplications = 0,
    this.deniedApplications = 0,
    this.approvalRate = 0.0,
    this.topMarkets = const [],
    this.participationByMarket = const {},
    this.isRepeatVendor = false,
    this.consecutiveEventsParticipated = 0,
  });

  factory VendorMarketParticipation.fromMap(Map<String, dynamic> map) {
    return VendorMarketParticipation(
      totalMarketsApplied: map['totalMarketsApplied'] ?? 0,
      uniqueMarketsParticipated: map['uniqueMarketsParticipated'] ?? 0,
      totalApplications: map['totalApplications'] ?? 0,
      approvedApplications: map['approvedApplications'] ?? 0,
      deniedApplications: map['deniedApplications'] ?? 0,
      approvalRate: (map['approvalRate'] ?? 0.0).toDouble(),
      topMarkets: List<String>.from(map['topMarkets'] ?? []),
      participationByMarket: Map<String, int>.from(map['participationByMarket'] ?? {}),
      isRepeatVendor: map['isRepeatVendor'] ?? false,
      consecutiveEventsParticipated: map['consecutiveEventsParticipated'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalMarketsApplied': totalMarketsApplied,
      'uniqueMarketsParticipated': uniqueMarketsParticipated,
      'totalApplications': totalApplications,
      'approvedApplications': approvedApplications,
      'deniedApplications': deniedApplications,
      'approvalRate': approvalRate,
      'topMarkets': topMarkets,
      'participationByMarket': participationByMarket,
      'isRepeatVendor': isRepeatVendor,
      'consecutiveEventsParticipated': consecutiveEventsParticipated,
    };
  }

  @override
  List<Object?> get props => [
    totalMarketsApplied,
    uniqueMarketsParticipated,
    totalApplications,
    approvedApplications,
    deniedApplications,
    approvalRate,
    topMarkets,
    participationByMarket,
    isRepeatVendor,
    consecutiveEventsParticipated,
  ];
}

/// Vendor monthly usage and limits tracking
class VendorMonthlyUsage extends Equatable {
  final int currentMonthPosts;
  final int monthlyLimit;
  final int remainingPosts;
  final double usagePercentage;
  final String subscriptionTier;
  final bool isNearLimit;
  final bool hasHitLimit;
  final DateTime lastPostDate;
  final Map<String, int> postsByType;

  const VendorMonthlyUsage({
    this.currentMonthPosts = 0,
    this.monthlyLimit = 3,
    this.remainingPosts = 3,
    this.usagePercentage = 0.0,
    this.subscriptionTier = 'free',
    this.isNearLimit = false,
    this.hasHitLimit = false,
    required this.lastPostDate,
    this.postsByType = const {},
  });

  factory VendorMonthlyUsage.fromMap(Map<String, dynamic> map) {
    return VendorMonthlyUsage(
      currentMonthPosts: map['currentMonthPosts'] ?? 0,
      monthlyLimit: map['monthlyLimit'] ?? 3,
      remainingPosts: map['remainingPosts'] ?? 3,
      usagePercentage: (map['usagePercentage'] ?? 0.0).toDouble(),
      subscriptionTier: map['subscriptionTier'] ?? 'free',
      isNearLimit: map['isNearLimit'] ?? false,
      hasHitLimit: map['hasHitLimit'] ?? false,
      lastPostDate: (map['lastPostDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      postsByType: Map<String, int>.from(map['postsByType'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentMonthPosts': currentMonthPosts,
      'monthlyLimit': monthlyLimit,
      'remainingPosts': remainingPosts,
      'usagePercentage': usagePercentage,
      'subscriptionTier': subscriptionTier,
      'isNearLimit': isNearLimit,
      'hasHitLimit': hasHitLimit,
      'lastPostDate': Timestamp.fromDate(lastPostDate),
      'postsByType': postsByType,
    };
  }

  @override
  List<Object?> get props => [
    currentMonthPosts,
    monthlyLimit,
    remainingPosts,
    usagePercentage,
    subscriptionTier,
    isNearLimit,
    hasHitLimit,
    lastPostDate,
    postsByType,
  ];
}

/// Vendor conversion and upgrade metrics
class VendorConversionMetrics extends Equatable {
  final int monthlyLimitEncounters;
  final int upgradeDialogsViewed;
  final int upgradeButtonClicks;
  final double viewToClickConversionRate;
  final double limitToUpgradeConversionRate;
  final bool hasUpgraded;
  final DateTime? upgradeDate;
  final String? upgradeSource;

  const VendorConversionMetrics({
    this.monthlyLimitEncounters = 0,
    this.upgradeDialogsViewed = 0,
    this.upgradeButtonClicks = 0,
    this.viewToClickConversionRate = 0.0,
    this.limitToUpgradeConversionRate = 0.0,
    this.hasUpgraded = false,
    this.upgradeDate,
    this.upgradeSource,
  });

  factory VendorConversionMetrics.fromMap(Map<String, dynamic> map) {
    return VendorConversionMetrics(
      monthlyLimitEncounters: map['monthlyLimitEncounters'] ?? 0,
      upgradeDialogsViewed: map['upgradeDialogsViewed'] ?? 0,
      upgradeButtonClicks: map['upgradeButtonClicks'] ?? 0,
      viewToClickConversionRate: (map['viewToClickConversionRate'] ?? 0.0).toDouble(),
      limitToUpgradeConversionRate: (map['limitToUpgradeConversionRate'] ?? 0.0).toDouble(),
      hasUpgraded: map['hasUpgraded'] ?? false,
      upgradeDate: (map['upgradeDate'] as Timestamp?)?.toDate(),
      upgradeSource: map['upgradeSource'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'monthlyLimitEncounters': monthlyLimitEncounters,
      'upgradeDialogsViewed': upgradeDialogsViewed,
      'upgradeButtonClicks': upgradeButtonClicks,
      'viewToClickConversionRate': viewToClickConversionRate,
      'limitToUpgradeConversionRate': limitToUpgradeConversionRate,
      'hasUpgraded': hasUpgraded,
      'upgradeDate': upgradeDate != null ? Timestamp.fromDate(upgradeDate!) : null,
      'upgradeSource': upgradeSource,
    };
  }

  @override
  List<Object?> get props => [
    monthlyLimitEncounters,
    upgradeDialogsViewed,
    upgradeButtonClicks,
    viewToClickConversionRate,
    limitToUpgradeConversionRate,
    hasUpgraded,
    upgradeDate,
    upgradeSource,
  ];
}

/// Vendor engagement and interaction metrics
class VendorEngagementMetrics extends Equatable {
  final int profileViews;
  final int postViews;
  final int postLikes;
  final int contactClicks;
  final int shareClicks;
  final int favoriteAdds;
  final double averageEngagementRate;
  final Map<String, int> engagementByType;
  final List<String> topEngagingMarkets;

  const VendorEngagementMetrics({
    this.profileViews = 0,
    this.postViews = 0,
    this.postLikes = 0,
    this.contactClicks = 0,
    this.shareClicks = 0,
    this.favoriteAdds = 0,
    this.averageEngagementRate = 0.0,
    this.engagementByType = const {},
    this.topEngagingMarkets = const [],
  });

  factory VendorEngagementMetrics.fromMap(Map<String, dynamic> map) {
    return VendorEngagementMetrics(
      profileViews: map['profileViews'] ?? 0,
      postViews: map['postViews'] ?? 0,
      postLikes: map['postLikes'] ?? 0,
      contactClicks: map['contactClicks'] ?? 0,
      shareClicks: map['shareClicks'] ?? 0,
      favoriteAdds: map['favoriteAdds'] ?? 0,
      averageEngagementRate: (map['averageEngagementRate'] ?? 0.0).toDouble(),
      engagementByType: Map<String, int>.from(map['engagementByType'] ?? {}),
      topEngagingMarkets: List<String>.from(map['topEngagingMarkets'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'profileViews': profileViews,
      'postViews': postViews,
      'postLikes': postLikes,
      'contactClicks': contactClicks,
      'shareClicks': shareClicks,
      'favoriteAdds': favoriteAdds,
      'averageEngagementRate': averageEngagementRate,
      'engagementByType': engagementByType,
      'topEngagingMarkets': topEngagingMarkets,
    };
  }

  @override
  List<Object?> get props => [
    profileViews,
    postViews,
    postLikes,
    contactClicks,
    shareClicks,
    favoriteAdds,
    averageEngagementRate,
    engagementByType,
    topEngagingMarkets,
  ];
}

/// Market organizer analytics for 1:1 market-event system
class OrganizerAnalytics extends Equatable {
  final String organizerId;
  final String? marketId;
  final DateTime date;
  final MarketEventPerformance eventPerformance;
  final ApprovalWorkflowMetrics approvalMetrics;
  final MarketDiscoveryMetrics discoveryMetrics;
  final OrganizerVendorEngagement vendorEngagement;

  const OrganizerAnalytics({
    required this.organizerId,
    this.marketId,
    required this.date,
    required this.eventPerformance,
    required this.approvalMetrics,
    required this.discoveryMetrics,
    required this.vendorEngagement,
  });

  factory OrganizerAnalytics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return OrganizerAnalytics(
      organizerId: data['organizerId'] ?? '',
      marketId: data['marketId'],
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      eventPerformance: MarketEventPerformance.fromMap(data['eventPerformance'] ?? {}),
      approvalMetrics: ApprovalWorkflowMetrics.fromMap(data['approvalMetrics'] ?? {}),
      discoveryMetrics: MarketDiscoveryMetrics.fromMap(data['discoveryMetrics'] ?? {}),
      vendorEngagement: OrganizerVendorEngagement.fromMap(data['vendorEngagement'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizerId': organizerId,
      'marketId': marketId,
      'date': Timestamp.fromDate(date),
      'eventPerformance': eventPerformance.toMap(),
      'approvalMetrics': approvalMetrics.toMap(),
      'discoveryMetrics': discoveryMetrics.toMap(),
      'vendorEngagement': vendorEngagement.toMap(),
    };
  }

  @override
  List<Object?> get props => [
    organizerId,
    marketId,
    date,
    eventPerformance,
    approvalMetrics,
    discoveryMetrics,
    vendorEngagement,
  ];
}

/// Market event performance analytics for single events vs recurring schedules
class MarketEventPerformance extends Equatable {
  final int totalEvents;
  final int singleEvents;
  final int recurringEvents;
  final double averageVendorParticipation;
  final double averageCustomerAttendance;
  final Map<String, double> performanceByEventType;
  final double singleEventConversionRate;
  final double recurringEventConversionRate;
  final List<String> topPerformingEvents;

  const MarketEventPerformance({
    this.totalEvents = 0,
    this.singleEvents = 0,
    this.recurringEvents = 0,
    this.averageVendorParticipation = 0.0,
    this.averageCustomerAttendance = 0.0,
    this.performanceByEventType = const {},
    this.singleEventConversionRate = 0.0,
    this.recurringEventConversionRate = 0.0,
    this.topPerformingEvents = const [],
  });

  factory MarketEventPerformance.fromMap(Map<String, dynamic> map) {
    return MarketEventPerformance(
      totalEvents: map['totalEvents'] ?? 0,
      singleEvents: map['singleEvents'] ?? 0,
      recurringEvents: map['recurringEvents'] ?? 0,
      averageVendorParticipation: (map['averageVendorParticipation'] ?? 0.0).toDouble(),
      averageCustomerAttendance: (map['averageCustomerAttendance'] ?? 0.0).toDouble(),
      performanceByEventType: Map<String, double>.from(map['performanceByEventType'] ?? {}),
      singleEventConversionRate: (map['singleEventConversionRate'] ?? 0.0).toDouble(),
      recurringEventConversionRate: (map['recurringEventConversionRate'] ?? 0.0).toDouble(),
      topPerformingEvents: List<String>.from(map['topPerformingEvents'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalEvents': totalEvents,
      'singleEvents': singleEvents,
      'recurringEvents': recurringEvents,
      'averageVendorParticipation': averageVendorParticipation,
      'averageCustomerAttendance': averageCustomerAttendance,
      'performanceByEventType': performanceByEventType,
      'singleEventConversionRate': singleEventConversionRate,
      'recurringEventConversionRate': recurringEventConversionRate,
      'topPerformingEvents': topPerformingEvents,
    };
  }

  @override
  List<Object?> get props => [
    totalEvents,
    singleEvents,
    recurringEvents,
    averageVendorParticipation,
    averageCustomerAttendance,
    performanceByEventType,
    singleEventConversionRate,
    recurringEventConversionRate,
    topPerformingEvents,
  ];
}

/// Approval workflow efficiency metrics for organizers
class ApprovalWorkflowMetrics extends Equatable {
  final int totalPendingApprovals;
  final int totalProcessedApprovals;
  final int approvedCount;
  final int deniedCount;
  final double approvalRate;
  final double averageApprovalTimeMinutes;
  final Map<String, int> approvalsByTimeOfDay;
  final Map<String, int> denialReasonBreakdown;
  final double workflowEfficiencyScore;

  const ApprovalWorkflowMetrics({
    this.totalPendingApprovals = 0,
    this.totalProcessedApprovals = 0,
    this.approvedCount = 0,
    this.deniedCount = 0,
    this.approvalRate = 0.0,
    this.averageApprovalTimeMinutes = 0.0,
    this.approvalsByTimeOfDay = const {},
    this.denialReasonBreakdown = const {},
    this.workflowEfficiencyScore = 0.0,
  });

  factory ApprovalWorkflowMetrics.fromMap(Map<String, dynamic> map) {
    return ApprovalWorkflowMetrics(
      totalPendingApprovals: map['totalPendingApprovals'] ?? 0,
      totalProcessedApprovals: map['totalProcessedApprovals'] ?? 0,
      approvedCount: map['approvedCount'] ?? 0,
      deniedCount: map['deniedCount'] ?? 0,
      approvalRate: (map['approvalRate'] ?? 0.0).toDouble(),
      averageApprovalTimeMinutes: (map['averageApprovalTimeMinutes'] ?? 0.0).toDouble(),
      approvalsByTimeOfDay: Map<String, int>.from(map['approvalsByTimeOfDay'] ?? {}),
      denialReasonBreakdown: Map<String, int>.from(map['denialReasonBreakdown'] ?? {}),
      workflowEfficiencyScore: (map['workflowEfficiencyScore'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalPendingApprovals': totalPendingApprovals,
      'totalProcessedApprovals': totalProcessedApprovals,
      'approvedCount': approvedCount,
      'deniedCount': deniedCount,
      'approvalRate': approvalRate,
      'averageApprovalTimeMinutes': averageApprovalTimeMinutes,
      'approvalsByTimeOfDay': approvalsByTimeOfDay,
      'denialReasonBreakdown': denialReasonBreakdown,
      'workflowEfficiencyScore': workflowEfficiencyScore,
    };
  }

  @override
  List<Object?> get props => [
    totalPendingApprovals,
    totalProcessedApprovals,
    approvedCount,
    deniedCount,
    approvalRate,
    averageApprovalTimeMinutes,
    approvalsByTimeOfDay,
    denialReasonBreakdown,
    workflowEfficiencyScore,
  ];
}

/// Market discovery patterns and analytics
class MarketDiscoveryMetrics extends Equatable {
  final int totalDiscoveries;
  final Map<String, int> discoverySourceBreakdown;
  final Map<String, int> userTypeBreakdown;
  final double organicDiscoveryRate;
  final double searchDiscoveryRate;
  final List<String> topDiscoverySources;
  final Map<String, double> conversionBySource;

  const MarketDiscoveryMetrics({
    this.totalDiscoveries = 0,
    this.discoverySourceBreakdown = const {},
    this.userTypeBreakdown = const {},
    this.organicDiscoveryRate = 0.0,
    this.searchDiscoveryRate = 0.0,
    this.topDiscoverySources = const [],
    this.conversionBySource = const {},
  });

  factory MarketDiscoveryMetrics.fromMap(Map<String, dynamic> map) {
    return MarketDiscoveryMetrics(
      totalDiscoveries: map['totalDiscoveries'] ?? 0,
      discoverySourceBreakdown: Map<String, int>.from(map['discoverySourceBreakdown'] ?? {}),
      userTypeBreakdown: Map<String, int>.from(map['userTypeBreakdown'] ?? {}),
      organicDiscoveryRate: (map['organicDiscoveryRate'] ?? 0.0).toDouble(),
      searchDiscoveryRate: (map['searchDiscoveryRate'] ?? 0.0).toDouble(),
      topDiscoverySources: List<String>.from(map['topDiscoverySources'] ?? []),
      conversionBySource: Map<String, double>.from(map['conversionBySource'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalDiscoveries': totalDiscoveries,
      'discoverySourceBreakdown': discoverySourceBreakdown,
      'userTypeBreakdown': userTypeBreakdown,
      'organicDiscoveryRate': organicDiscoveryRate,
      'searchDiscoveryRate': searchDiscoveryRate,
      'topDiscoverySources': topDiscoverySources,
      'conversionBySource': conversionBySource,
    };
  }

  @override
  List<Object?> get props => [
    totalDiscoveries,
    discoverySourceBreakdown,
    userTypeBreakdown,
    organicDiscoveryRate,
    searchDiscoveryRate,
    topDiscoverySources,
    conversionBySource,
  ];
}

/// Organizer vendor engagement metrics
class OrganizerVendorEngagement extends Equatable {
  final int totalVendorInteractions;
  final int uniqueVendorsEngaged;
  final Map<String, int> interactionTypeBreakdown;
  final double averageInteractionsPerVendor;
  final List<String> topEngagingVendors;
  final double vendorRetentionRate;
  final Map<String, int> engagementByMarket;

  const OrganizerVendorEngagement({
    this.totalVendorInteractions = 0,
    this.uniqueVendorsEngaged = 0,
    this.interactionTypeBreakdown = const {},
    this.averageInteractionsPerVendor = 0.0,
    this.topEngagingVendors = const [],
    this.vendorRetentionRate = 0.0,
    this.engagementByMarket = const {},
  });

  factory OrganizerVendorEngagement.fromMap(Map<String, dynamic> map) {
    return OrganizerVendorEngagement(
      totalVendorInteractions: map['totalVendorInteractions'] ?? 0,
      uniqueVendorsEngaged: map['uniqueVendorsEngaged'] ?? 0,
      interactionTypeBreakdown: Map<String, int>.from(map['interactionTypeBreakdown'] ?? {}),
      averageInteractionsPerVendor: (map['averageInteractionsPerVendor'] ?? 0.0).toDouble(),
      topEngagingVendors: List<String>.from(map['topEngagingVendors'] ?? []),
      vendorRetentionRate: (map['vendorRetentionRate'] ?? 0.0).toDouble(),
      engagementByMarket: Map<String, int>.from(map['engagementByMarket'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalVendorInteractions': totalVendorInteractions,
      'uniqueVendorsEngaged': uniqueVendorsEngaged,
      'interactionTypeBreakdown': interactionTypeBreakdown,
      'averageInteractionsPerVendor': averageInteractionsPerVendor,
      'topEngagingVendors': topEngagingVendors,
      'vendorRetentionRate': vendorRetentionRate,
      'engagementByMarket': engagementByMarket,
    };
  }

  @override
  List<Object?> get props => [
    totalVendorInteractions,
    uniqueVendorsEngaged,
    interactionTypeBreakdown,
    averageInteractionsPerVendor,
    topEngagingVendors,
    vendorRetentionRate,
    engagementByMarket,
  ];
}

extension AnalyticsTimeRangeExtension on AnalyticsTimeRange {
  String get displayName {
    switch (this) {
      case AnalyticsTimeRange.week:
        return '7 Days';
      case AnalyticsTimeRange.month:
        return '30 Days';
      case AnalyticsTimeRange.quarter:
        return '3 Months';
      case AnalyticsTimeRange.year:
        return '1 Year';
    }
  }

  int get days {
    switch (this) {
      case AnalyticsTimeRange.week:
        return 7;
      case AnalyticsTimeRange.month:
        return 30;
      case AnalyticsTimeRange.quarter:
        return 90;
      case AnalyticsTimeRange.year:
        return 365;
    }
  }
}

/// Analytics insight levels for different stakeholder views
enum AnalyticsInsightLevel {
  basic,
  detailed,
  comprehensive,
  executive
}

/// Analytics comparison periods
enum AnalyticsComparisonPeriod {
  previousPeriod,
  previousMonth,
  previousQuarter,
  previousYear,
  customRange
}

/// Trend direction indicators
enum TrendDirection {
  up,
  down,
  stable,
  unknown
}

/// Key performance indicator model
class KPIMetric extends Equatable {
  final String name;
  final String displayName;
  final double value;
  final double? previousValue;
  final String unit;
  final TrendDirection trend;
  final double changePercentage;
  final bool isPositiveTrend;
  final String? description;

  const KPIMetric({
    required this.name,
    required this.displayName,
    required this.value,
    this.previousValue,
    required this.unit,
    this.trend = TrendDirection.unknown,
    this.changePercentage = 0.0,
    this.isPositiveTrend = true,
    this.description,
  });

  factory KPIMetric.fromMap(Map<String, dynamic> map) {
    return KPIMetric(
      name: map['name'] ?? '',
      displayName: map['displayName'] ?? '',
      value: (map['value'] ?? 0.0).toDouble(),
      previousValue: map['previousValue']?.toDouble(),
      unit: map['unit'] ?? '',
      trend: TrendDirection.values.firstWhere(
        (e) => e.toString().split('.').last == map['trend'],
        orElse: () => TrendDirection.unknown,
      ),
      changePercentage: (map['changePercentage'] ?? 0.0).toDouble(),
      isPositiveTrend: map['isPositiveTrend'] ?? true,
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'displayName': displayName,
      'value': value,
      'previousValue': previousValue,
      'unit': unit,
      'trend': trend.toString().split('.').last,
      'changePercentage': changePercentage,
      'isPositiveTrend': isPositiveTrend,
      'description': description,
    };
  }

  @override
  List<Object?> get props => [
    name,
    displayName,
    value,
    previousValue,
    unit,
    trend,
    changePercentage,
    isPositiveTrend,
    description,
  ];
}