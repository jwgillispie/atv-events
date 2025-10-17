import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hipop/features/shared/models/analytics.dart';
import 'real_time_analytics_service.dart';

/// Comprehensive Analytics Dashboard Service for HiPop Platform
/// 
/// This service aggregates analytics data from various sources to provide
/// comprehensive insights for vendors, organizers, and administrators.
/// Supports the new 1:1 market-event system with specialized metrics.
class AnalyticsDashboardService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Get comprehensive vendor analytics dashboard
  /// 
  /// Provides metrics specific to vendor performance including:
  /// - Post creation and engagement metrics
  /// - Market participation analytics 
  /// - Monthly usage and limits tracking
  /// - Revenue and conversion insights
  static Future<VendorDashboardAnalytics> getVendorDashboard({
    required String vendorId,
    String timeRange = '30d',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final dateRange = _calculateDateRange(timeRange, startDate, endDate);
      
      // Get basic vendor analytics from RealTimeAnalyticsService
      final basicMetrics = await RealTimeAnalyticsService.getAnalyticsMetrics(
        vendorId: vendorId,
        startDate: dateRange.start,
        endDate: dateRange.end,
      );
      
      // Get vendor-specific post creation metrics
      final postCreationMetrics = await _getVendorPostCreationMetrics(
        vendorId,
        dateRange.start,
        dateRange.end,
      );
      
      // Get monthly usage tracking
      final monthlyUsage = await _getVendorMonthlyUsage(vendorId);
      
      // Get market participation analytics
      final marketParticipation = await _getVendorMarketParticipation(
        vendorId,
        dateRange.start,
        dateRange.end,
      );
      
      // Get conversion funnel analytics
      final conversionMetrics = await _getVendorConversionMetrics(
        vendorId,
        dateRange.start,
        dateRange.end,
      );
      
      return VendorDashboardAnalytics(
        vendorId: vendorId,
        timeRange: timeRange,
        dateRange: dateRange,
        basicMetrics: basicMetrics,
        postCreationMetrics: postCreationMetrics,
        monthlyUsage: monthlyUsage,
        marketParticipation: marketParticipation,
        conversionMetrics: conversionMetrics,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      rethrow;
    }
  }
  
  /// Get comprehensive organizer analytics dashboard
  /// 
  /// Provides metrics specific to market organizer performance including:
  /// - Market event performance analytics
  /// - Vendor approval workflow efficiency
  /// - Market discovery and engagement metrics
  /// - Revenue and growth insights
  static Future<OrganizerDashboardAnalytics> getOrganizerDashboard({
    required String organizerId,
    String? marketId,
    String timeRange = '30d',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final dateRange = _calculateDateRange(timeRange, startDate, endDate);
      
      // Get basic organizer analytics
      final basicMetrics = await RealTimeAnalyticsService.getAnalyticsMetrics(
        startDate: dateRange.start,
        endDate: dateRange.end,
      );
      
      // Get market event performance using the new analytics
      final eventPerformance = await MarketEventAnalytics.getMarketEventAnalytics(
        organizerId: organizerId,
        marketId: marketId,
        startDate: dateRange.start,
        endDate: dateRange.end,
        timeRange: timeRange,
      );
      
      // Get approval workflow metrics
      final approvalMetrics = await _getApprovalWorkflowMetrics(
        organizerId,
        marketId,
        dateRange.start,
        dateRange.end,
      );
      
      // Get market discovery analytics
      final discoveryMetrics = await _getMarketDiscoveryMetrics(
        organizerId,
        marketId,
        dateRange.start,
        dateRange.end,
      );
      
      // Get vendor engagement metrics
      final vendorEngagement = await _getVendorEngagementMetrics(
        organizerId,
        marketId,
        dateRange.start,
        dateRange.end,
      );
      
      return OrganizerDashboardAnalytics(
        organizerId: organizerId,
        marketId: marketId,
        timeRange: timeRange,
        dateRange: dateRange,
        basicMetrics: basicMetrics,
        eventPerformance: eventPerformance,
        approvalMetrics: approvalMetrics,
        discoveryMetrics: discoveryMetrics,
        vendorEngagement: vendorEngagement,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      rethrow;
    }
  }
  
  /// Get platform-wide analytics for administrators
  static Future<PlatformDashboardAnalytics> getPlatformDashboard({
    String timeRange = '30d',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final dateRange = _calculateDateRange(timeRange, startDate, endDate);
      
      // Get comprehensive platform metrics
      final platformMetrics = await MarketEventAnalytics.getMarketEventAnalytics(
        startDate: dateRange.start,
        endDate: dateRange.end,
        timeRange: timeRange,
      );
      
      // Get user acquisition and retention metrics
      final userMetrics = await _getPlatformUserMetrics(
        dateRange.start,
        dateRange.end,
      );
      
      // Get subscription and monetization metrics
      final monetizationMetrics = await _getPlatformMonetizationMetrics(
        dateRange.start,
        dateRange.end,
      );
      
      // Get system performance metrics
      final performanceMetrics = await _getPlatformPerformanceMetrics(
        dateRange.start,
        dateRange.end,
      );
      
      return PlatformDashboardAnalytics(
        timeRange: timeRange,
        dateRange: dateRange,
        platformMetrics: platformMetrics,
        userMetrics: userMetrics,
        monetizationMetrics: monetizationMetrics,
        performanceMetrics: performanceMetrics,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      rethrow;
    }
  }
  
  /// Get real-time analytics summary for quick insights
  static Future<AnalyticsSummary> getRealtimeSummary({
    String? userId,
    String? userType,
    String? marketId,
  }) async {
    try {
      // Get last 24 hours of data for real-time insights
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final now = DateTime.now();
      
      final metrics = await RealTimeAnalyticsService.getAnalyticsMetrics(
        marketId: marketId,
        vendorId: userType == 'vendor' ? userId : null,
        startDate: yesterday,
        endDate: now,
      );
      
      // Process metrics into summary format
      return AnalyticsSummary(
        totalVendors: metrics['uniqueUsers'] ?? 0,
        totalEvents: metrics['totalEvents'] ?? 0,
        totalViews: metrics['pageViews'] ?? 0,
        vendorApplicationsByStatus: _extractStatusBreakdown(metrics, 'approval'),
        eventsByStatus: _extractStatusBreakdown(metrics, 'event'),
        dailyData: [], // Real-time doesn't need daily breakdown
      );
    } catch (e) {
      return const AnalyticsSummary();
    }
  }
  
  // Private helper methods
  
  static AnalyticsDateRange _calculateDateRange(
    String timeRange,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    final now = DateTime.now();
    final calculatedStart = startDate ?? _getStartDateFromRange(timeRange, now);
    final calculatedEnd = endDate ?? now;
    
    return AnalyticsDateRange(
      start: calculatedStart,
      end: calculatedEnd,
      range: timeRange,
    );
  }
  
  static DateTime _getStartDateFromRange(String range, DateTime end) {
    switch (range) {
      case '7d':
        return end.subtract(const Duration(days: 7));
      case '30d':
        return end.subtract(const Duration(days: 30));
      case '90d':
        return end.subtract(const Duration(days: 90));
      case '1y':
        return end.subtract(const Duration(days: 365));
      default:
        return end.subtract(const Duration(days: 30));
    }
  }
  
  static Future<Map<String, dynamic>> _getVendorPostCreationMetrics(
    String vendorId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final query = await _firestore
          .collection('user_events')
          .where('userId', isEqualTo: vendorId)
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .where('eventType', whereIn: [
            'post_creation_started',
            'post_creation_completed',
            'post_creation_abandoned',
            'form_field_interaction',
          ])
          .get();
      
      int started = 0;
      int completed = 0;
      int abandoned = 0;
      final Map<String, int> abandonmentStages = {};
      final Map<String, int> fieldInteractions = {};
      
      for (final doc in query.docs) {
        final data = doc.data();
        final eventType = data['eventType'] as String?;
        final eventData = data['data'] as Map<String, dynamic>? ?? {};
        
        switch (eventType) {
          case 'post_creation_started':
            started++;
            break;
          case 'post_creation_completed':
            completed++;
            break;
          case 'post_creation_abandoned':
            abandoned++;
            final stage = eventData['abandonmentStage'] as String? ?? 'unknown';
            abandonmentStages[stage] = (abandonmentStages[stage] ?? 0) + 1;
            break;
          case 'form_field_interaction':
            final field = eventData['fieldName'] as String? ?? 'unknown';
            fieldInteractions[field] = (fieldInteractions[field] ?? 0) + 1;
            break;
        }
      }
      
      return {
        'postsStarted': started,
        'postsCompleted': completed,
        'postsAbandoned': abandoned,
        'completionRate': started > 0 ? (completed / started) * 100 : 0,
        'abandonmentRate': started > 0 ? (abandoned / started) * 100 : 0,
        'abandonmentStages': abandonmentStages,
        'fieldInteractions': fieldInteractions,
      };
    } catch (e) {
      return {};
    }
  }
  
  static Future<Map<String, dynamic>> _getVendorMonthlyUsage(String vendorId) async {
    try {
      final now = DateTime.now();
      final currentMonthId = '${vendorId}_${now.year}_${now.month.toString().padLeft(2, '0')}';
      
      final doc = await _firestore
          .collection('vendor_monthly_tracking')
          .doc(currentMonthId)
          .get();
      
      if (!doc.exists) {
        return {
          'currentUsage': 0,
          'monthlyLimit': 3,
          'remainingPosts': 3,
          'usagePercentage': 0,
          'subscriptionTier': 'free',
        };
      }
      
      final data = doc.data()!;
      final posts = data['posts'] as Map<String, dynamic>? ?? {};
      final totalPosts = posts['total'] as int? ?? 0;
      const monthlyLimit = 3; // Free tier limit
      
      return {
        'currentUsage': totalPosts,
        'monthlyLimit': monthlyLimit,
        'remainingPosts': monthlyLimit - totalPosts,
        'usagePercentage': (totalPosts / monthlyLimit) * 100,
        'subscriptionTier': data['subscriptionTier'] ?? 'free',
        'independentPosts': posts['independent'] ?? 0,
        'marketPosts': posts['market'] ?? 0,
        'deniedPosts': posts['denied'] ?? 0,
      };
    } catch (e) {
      return {};
    }
  }
  
  static Future<Map<String, dynamic>> _getVendorMarketParticipation(
    String vendorId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final query = await _firestore
          .collection('user_events')
          .where('userId', isEqualTo: vendorId)
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .where('eventType', isEqualTo: 'vendor_participation_pattern')
          .get();
      
      final Map<String, int> participationTypes = {};
      final Set<String> uniqueMarkets = {};
      int approvedApplications = 0;
      int totalApplications = 0;
      
      for (final doc in query.docs) {
        final data = doc.data();
        final eventData = data['data'] as Map<String, dynamic>? ?? {};
        
        final participationType = eventData['participationType'] as String? ?? 'unknown';
        participationTypes[participationType] = (participationTypes[participationType] ?? 0) + 1;
        
        final marketId = eventData['marketId'] as String?;
        if (marketId != null) uniqueMarkets.add(marketId);
        
        if (participationType == 'application_submitted') totalApplications++;
        if (participationType == 'approved') approvedApplications++;
      }
      
      return {
        'participationTypes': participationTypes,
        'uniqueMarketsCount': uniqueMarkets.length,
        'uniqueMarkets': uniqueMarkets.toList(),
        'totalApplications': totalApplications,
        'approvedApplications': approvedApplications,
        'approvalRate': totalApplications > 0 ? (approvedApplications / totalApplications) * 100 : 0,
      };
    } catch (e) {
      return {};
    }
  }
  
  static Future<Map<String, dynamic>> _getVendorConversionMetrics(
    String vendorId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final query = await _firestore
          .collection('user_events')
          .where('userId', isEqualTo: vendorId)
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .where('eventType', whereIn: [
            'monthly_limit_encountered',
            'upgrade_dialog_viewed',
            'upgrade_clicked_from_limit',
          ])
          .get();
      
      int limitEncounters = 0;
      int upgradeViews = 0;
      int upgradeClicks = 0;
      
      for (final doc in query.docs) {
        final data = doc.data();
        final eventType = data['eventType'] as String?;
        
        switch (eventType) {
          case 'monthly_limit_encountered':
            limitEncounters++;
            break;
          case 'upgrade_dialog_viewed':
            upgradeViews++;
            break;
          case 'upgrade_clicked_from_limit':
            upgradeClicks++;
            break;
        }
      }
      
      return {
        'limitEncounters': limitEncounters,
        'upgradeViews': upgradeViews,
        'upgradeClicks': upgradeClicks,
        'viewToClickRate': upgradeViews > 0 ? (upgradeClicks / upgradeViews) * 100 : 0,
        'limitToUpgradeRate': limitEncounters > 0 ? (upgradeClicks / limitEncounters) * 100 : 0,
      };
    } catch (e) {
      return {};
    }
  }
  
  static Future<Map<String, dynamic>> _getApprovalWorkflowMetrics(
    String organizerId,
    String? marketId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      Query query = _firestore
          .collection('user_events')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .where('eventType', whereIn: [
            'market_post_approval_decision',
            'market_bulk_approval_decision',
          ]);
      
      final snapshot = await query.get();
      
      int totalDecisions = 0;
      int approvals = 0;
      int denials = 0;
      List<int> approvalTimes = [];
      final Map<String, int> decisionsByHour = {};
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final eventData = data['data'] as Map<String, dynamic>? ?? {};
        
        // Filter by organizer and market if specified
        if (eventData['approverId'] != organizerId) continue;
        if (marketId != null && eventData['marketId'] != marketId) continue;
        
        final eventType = data['eventType'] as String?;
        
        if (eventType == 'market_post_approval_decision') {
          totalDecisions++;
          final decision = eventData['decision'] as String?;
          if (decision == 'approved') approvals++;
          if (decision == 'denied') denials++;
          
          final timeToDecision = eventData['timeToDecisionMinutes'] as int?;
          if (timeToDecision != null) approvalTimes.add(timeToDecision);
          
          final hourOfDay = eventData['hourOfDay'] as int?;
          if (hourOfDay != null) {
            decisionsByHour[hourOfDay.toString()] = (decisionsByHour[hourOfDay.toString()] ?? 0) + 1;
          }
        } else if (eventType == 'market_bulk_approval_decision') {
          final postCount = eventData['postCount'] as int? ?? 0;
          totalDecisions += postCount;
          
          final decision = eventData['decision'] as String?;
          if (decision == 'approved') approvals += postCount;
          if (decision == 'denied') denials += postCount;
        }
      }
      
      return {
        'totalDecisions': totalDecisions,
        'approvals': approvals,
        'denials': denials,
        'approvalRate': totalDecisions > 0 ? (approvals / totalDecisions) * 100 : 0,
        'averageApprovalTimeMinutes': approvalTimes.isNotEmpty 
            ? approvalTimes.reduce((a, b) => a + b) / approvalTimes.length 
            : 0,
        'decisionsByHour': decisionsByHour,
      };
    } catch (e) {
      return {};
    }
  }
  
  static Future<Map<String, dynamic>> _getMarketDiscoveryMetrics(
    String organizerId,
    String? marketId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      Query query = _firestore
          .collection('user_events')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .where('eventType', isEqualTo: 'market_discovery_pattern');
      
      final snapshot = await query.get();
      
      final Map<String, int> discoverySourceBreakdown = {};
      final Map<String, int> userTypeBreakdown = {};
      int totalDiscoveries = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final eventData = data['data'] as Map<String, dynamic>? ?? {};
        
        // Filter by market if specified
        if (marketId != null && eventData['marketId'] != marketId) continue;
        
        totalDiscoveries++;
        
        final discoverySource = eventData['discoverySource'] as String? ?? 'unknown';
        discoverySourceBreakdown[discoverySource] = (discoverySourceBreakdown[discoverySource] ?? 0) + 1;
        
        final userType = eventData['userType'] as String? ?? 'unknown';
        userTypeBreakdown[userType] = (userTypeBreakdown[userType] ?? 0) + 1;
      }
      
      return {
        'totalDiscoveries': totalDiscoveries,
        'discoverySourceBreakdown': discoverySourceBreakdown,
        'userTypeBreakdown': userTypeBreakdown,
      };
    } catch (e) {
      return {};
    }
  }
  
  static Future<Map<String, dynamic>> _getVendorEngagementMetrics(
    String organizerId,
    String? marketId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      Query query = _firestore
          .collection('user_events')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .where('eventType', isEqualTo: 'vendor_interaction');
      
      final snapshot = await query.get();
      
      final Map<String, int> interactionTypes = {};
      final Set<String> uniqueVendors = {};
      int totalInteractions = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final eventData = data['data'] as Map<String, dynamic>? ?? {};
        
        // Filter by market if specified
        if (marketId != null && eventData['marketId'] != marketId) continue;
        
        totalInteractions++;
        
        final action = eventData['action'] as String? ?? 'unknown';
        interactionTypes[action] = (interactionTypes[action] ?? 0) + 1;
        
        final vendorId = eventData['vendorId'] as String?;
        if (vendorId != null) uniqueVendors.add(vendorId);
      }
      
      return {
        'totalInteractions': totalInteractions,
        'uniqueVendors': uniqueVendors.length,
        'interactionTypes': interactionTypes,
        'averageInteractionsPerVendor': uniqueVendors.isNotEmpty 
            ? totalInteractions / uniqueVendors.length 
            : 0,
      };
    } catch (e) {
      return {};
    }
  }
  
  static Future<Map<String, dynamic>> _getPlatformUserMetrics(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final metrics = await RealTimeAnalyticsService.getAnalyticsMetrics(
        startDate: startDate,
        endDate: endDate,
      );
      
      return {
        'totalUsers': metrics['uniqueUsers'] ?? 0,
        'newUsers': metrics['newUsers'] ?? 0,
        'activeUsers': metrics['activeUsers'] ?? 0,
        'userRetentionRate': metrics['retentionRate'] ?? 0,
        'averageSessionDuration': metrics['averageSessionDuration'] ?? 0,
      };
    } catch (e) {
      return {};
    }
  }
  
  static Future<Map<String, dynamic>> _getPlatformMonetizationMetrics(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // This would integrate with subscription/payment analytics
      // For now, return placeholder structure
      return {
        'totalRevenue': 0.0,
        'newSubscriptions': 0,
        'churnRate': 0.0,
        'averageRevenuePerUser': 0.0,
        'conversionRate': 0.0,
      };
    } catch (e) {
      return {};
    }
  }
  
  static Future<Map<String, dynamic>> _getPlatformPerformanceMetrics(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // This would integrate with performance monitoring
      // For now, return placeholder structure
      return {
        'averageLoadTime': 0.0,
        'errorRate': 0.0,
        'uptime': 99.9,
        'apiResponseTime': 0.0,
      };
    } catch (e) {
      return {};
    }
  }
  
  static Map<String, int> _extractStatusBreakdown(
    Map<String, dynamic> metrics,
    String statusType,
  ) {
    // Extract status breakdown from metrics based on type
    return {};
  }
}

/// Analytics Dashboard Data Models

class VendorDashboardAnalytics {
  final String vendorId;
  final String timeRange;
  final AnalyticsDateRange dateRange;
  final Map<String, dynamic> basicMetrics;
  final Map<String, dynamic> postCreationMetrics;
  final Map<String, dynamic> monthlyUsage;
  final Map<String, dynamic> marketParticipation;
  final Map<String, dynamic> conversionMetrics;
  final DateTime generatedAt;

  const VendorDashboardAnalytics({
    required this.vendorId,
    required this.timeRange,
    required this.dateRange,
    required this.basicMetrics,
    required this.postCreationMetrics,
    required this.monthlyUsage,
    required this.marketParticipation,
    required this.conversionMetrics,
    required this.generatedAt,
  });
}

class OrganizerDashboardAnalytics {
  final String organizerId;
  final String? marketId;
  final String timeRange;
  final AnalyticsDateRange dateRange;
  final Map<String, dynamic> basicMetrics;
  final Map<String, dynamic> eventPerformance;
  final Map<String, dynamic> approvalMetrics;
  final Map<String, dynamic> discoveryMetrics;
  final Map<String, dynamic> vendorEngagement;
  final DateTime generatedAt;

  const OrganizerDashboardAnalytics({
    required this.organizerId,
    this.marketId,
    required this.timeRange,
    required this.dateRange,
    required this.basicMetrics,
    required this.eventPerformance,
    required this.approvalMetrics,
    required this.discoveryMetrics,
    required this.vendorEngagement,
    required this.generatedAt,
  });
}

class PlatformDashboardAnalytics {
  final String timeRange;
  final AnalyticsDateRange dateRange;
  final Map<String, dynamic> platformMetrics;
  final Map<String, dynamic> userMetrics;
  final Map<String, dynamic> monetizationMetrics;
  final Map<String, dynamic> performanceMetrics;
  final DateTime generatedAt;

  const PlatformDashboardAnalytics({
    required this.timeRange,
    required this.dateRange,
    required this.platformMetrics,
    required this.userMetrics,
    required this.monetizationMetrics,
    required this.performanceMetrics,
    required this.generatedAt,
  });
}

class AnalyticsDateRange {
  final DateTime start;
  final DateTime end;
  final String range;

  const AnalyticsDateRange({
    required this.start,
    required this.end,
    required this.range,
  });
}