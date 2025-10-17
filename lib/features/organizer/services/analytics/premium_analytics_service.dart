import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:atv_events/features/shared/services/user/customer_loyalty_service.dart';
import 'dart:math';

import '../../../vendor/services/products/vendor_sales_service.dart';
import '../../../shared/services/user/customer_feedback_service.dart';
import '../../../shared/models/customer_feedback.dart';

/// Premium analytics service for market organizers
/// Provides comprehensive market management, vendor analytics, and business intelligence
/// Now uses real sales data from vendor sales tracking system
class MarketOrganizerPremiumAnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final VendorSalesService _salesService = VendorSalesService();

  /// Get comprehensive market performance analytics
  static Future<Map<String, dynamic>> getMarketPerformanceAnalytics({
    required String organizerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      startDate ??= DateTime.now().subtract(const Duration(days: 30));
      endDate ??= DateTime.now();

      final random = Random();
      final days = endDate.difference(startDate).inDays;
      
      List<Map<String, dynamic>> dailyMetrics = [];
      double totalRevenue = 0;
      int totalFootTraffic = 0;
      
      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final revenue = random.nextDouble() * 2000 + 500; // $500-$2500 per day
        final footTraffic = random.nextInt(500) + 200; // 200-700 visitors
        
        totalRevenue += revenue;
        totalFootTraffic += footTraffic;
        
        dailyMetrics.add({
          'date': date,
          'revenue': revenue,
          'footTraffic': footTraffic,
          'vendorCount': random.nextInt(20) + 15,
          'averageSpend': revenue / footTraffic,
        });
      }

      return {
        'totalRevenue': totalRevenue,
        'totalFootTraffic': totalFootTraffic,
        'averageDailyRevenue': totalRevenue / days,
        'averageDailyFootTraffic': totalFootTraffic / days,
        'dailyMetrics': dailyMetrics,
        'revenueGrowth': _calculateGrowthRate(dailyMetrics, 'revenue'),
        'trafficGrowth': _calculateGrowthRate(dailyMetrics, 'footTraffic'),
        'marketHealthScore': _calculateMarketHealthScore(dailyMetrics),
      };
    } catch (e) {
      return {};
    }
  }

  /// Get vendor performance metrics and analytics
  static Future<Map<String, dynamic>> getVendorPerformanceAnalytics({
    required String organizerId,
  }) async {
    try {
      final random = Random();
      
      // Generate mock vendor data
      List<Map<String, dynamic>> vendorMetrics = [];
      final vendorNames = [
        'Fresh Farm Produce', 'Artisan Bakery', 'Local Honey Co.',
        'Organic Greens', 'Craft Coffee Roasters', 'Heritage Meats',
        'Seasonal Fruits', 'Handmade Soaps'
      ];
      
      for (int i = 0; i < 8; i++) {
        vendorMetrics.add({
          'vendorId': 'vendor_$i',
          'vendorName': vendorNames[i],
          'monthlyRevenue': random.nextDouble() * 3000 + 1000,
          'footTraffic': random.nextInt(200) + 50,
          'averageTransaction': random.nextDouble() * 25 + 15,
          'customerSatisfaction': 4.2, // Will be replaced by real feedback data when available
          'attendance': random.nextDouble() * 0.3 + 0.7, // 70-100%
          'growthRate': random.nextDouble() * 0.4 - 0.1, // -10% to +30%
          'category': _getRandomCategory(random),
        });
      }

      // Sort by revenue
      vendorMetrics.sort((a, b) => b['monthlyRevenue'].compareTo(a['monthlyRevenue']));

      return {
        'totalVendors': vendorMetrics.length,
        'activeVendors': vendorMetrics.where((v) => v['attendance'] > 0.8).length,
        'averageVendorRevenue': vendorMetrics.fold(0.0, (sum, v) => sum + v['monthlyRevenue']) / vendorMetrics.length,
        'topPerformers': vendorMetrics.take(5).toList(),
        'vendorRetentionRate': random.nextDouble() * 0.2 + 0.75, // 75-95%
        'categoryDistribution': _getCategoryDistribution(vendorMetrics),
        'performanceIssues': _identifyPerformanceIssues(vendorMetrics),
      };
    } catch (e) {
      return {};
    }
  }

  /// Get vendor application analytics and conversion tracking
  static Future<Map<String, dynamic>> getApplicationAnalytics({
    required String organizerId,
  }) async {
    try {
      final random = Random();
      
      return {
        'applicationStats': {
          'totalApplications': random.nextInt(50) + 30,
          'approvedApplications': random.nextInt(30) + 20,
          'pendingApplications': random.nextInt(15) + 5,
          'rejectedApplications': random.nextInt(10) + 2,
          'approvalRate': random.nextDouble() * 0.3 + 0.6, // 60-90%
          'averageProcessingTime': random.nextInt(5) + 2, // 2-7 days
        },
        'monthlyTrends': _generateApplicationTrends(),
        'categoryDemand': {
          'Fresh Produce': random.nextInt(15) + 10,
          'Baked Goods': random.nextInt(12) + 8,
          'Crafts & Artwork': random.nextInt(10) + 5,
          'Prepared Foods': random.nextInt(8) + 4,
          'Flowers & Plants': random.nextInt(6) + 3,
        },
        'qualityMetrics': {
          'completeApplicationRate': random.nextDouble() * 0.2 + 0.7, // 70-90%
          'documentCompleteness': random.nextDouble() * 0.25 + 0.75, // 75-100%
          'responseRate': random.nextDouble() * 0.15 + 0.85, // 85-100%
        },
      };
    } catch (e) {
      return {};
    }
  }

  /// Get revenue tracking and commission analytics using real sales data
  static Future<Map<String, dynamic>> getRevenueTrackingAnalytics({
    required String organizerId,
  }) async {
    try {
      final startDate = DateTime.now().subtract(const Duration(days: 30));
      final endDate = DateTime.now();
      
      // Get real market financial data by querying all vendors' sales for this organizer's markets
      final marketFinancialData = await _getMarketFinancialSummary(organizerId, startDate, endDate);
      
      if (marketFinancialData['totalRevenue'] == 0.0) {
        return _getEmptyRevenueAnalytics();
      }

      final totalCommissions = marketFinancialData['totalCommissions'] as double;
      final totalMarketFees = marketFinancialData['totalMarketFees'] as double;
      final totalRevenue = marketFinancialData['totalRevenue'] as double;
      final grossProfit = totalCommissions + totalMarketFees;
      
      return {
        'revenueBreakdown': {
          'vendorCommissions': totalCommissions,
          'marketFees': totalMarketFees,
          'totalVendorRevenue': totalRevenue,
          'grossMarketRevenue': grossProfit,
        },
        'commissionTracking': {
          'totalCommissions': totalCommissions,
          'averageCommissionRate': totalRevenue > 0 ? (totalCommissions / totalRevenue) * 100 : 0.0,
          'topCommissionVendors': marketFinancialData['topCommissionVendors'],
        },
        'profitMargins': {
          'grossProfit': grossProfit,
          'operatingCosts': grossProfit * 0.4, // Estimated operating costs (40% of gross profit)
          'netProfit': grossProfit * 0.6, // Estimated net profit
          'profitMargin': 60.0, // Based on 60% net margin estimate
        },
        'vendorMetrics': {
          'totalVendors': marketFinancialData['totalVendors'],
          'totalTransactions': marketFinancialData['totalTransactions'],
          'averageVendorRevenue': marketFinancialData['averageVendorRevenue'],
        },
        'periodComparison': await _getPeriodComparison(organizerId, startDate, endDate),
      };
    } catch (e) {
      return _getEmptyRevenueAnalytics();
    }
  }

  /// Get market capacity and layout analytics
  static Future<Map<String, dynamic>> getCapacityAndLayoutAnalytics({
    required String organizerId,
  }) async {
    try {
      final random = Random();
      
      return {
        'capacityMetrics': {
          'totalStalls': random.nextInt(50) + 30,
          'occupiedStalls': random.nextInt(40) + 25,
          'occupancyRate': random.nextDouble() * 0.2 + 0.75, // 75-95%
          'peakCapacityUtilization': random.nextDouble() * 0.15 + 0.85, // 85-100%
          'averageStallSize': '${random.nextInt(5) + 10}x${random.nextInt(5) + 10} ft',
        },
        'layoutOptimization': {
          'customerFlowScore': random.nextDouble() * 20 + 70, // 70-90
          'vendorAccessibility': random.nextDouble() * 15 + 80, // 80-95
          'wasteManagementEfficiency': random.nextDouble() * 10 + 85, // 85-95
          'emergencyAccessCompliance': random.nextBool(),
        },
        'spaceDemand': {
          'waitingList': random.nextInt(15) + 5,
          'premiumSpotDemand': random.nextInt(8) + 3,
          'expansionOpportunities': random.nextInt(10) + 2,
        },
        'recommendations': _generateLayoutRecommendations(),
      };
    } catch (e) {
      return {};
    }
  }

  /// Get weather integration and impact analytics
  static Future<Map<String, dynamic>> getWeatherImpactAnalytics({
    required String organizerId,
  }) async {
    try {
      final random = Random();
      
      return {
        'weatherCorrelations': {
          'sunnyDayAttendance': random.nextDouble() * 200 + 400, // 400-600 avg
          'rainyDayAttendance': random.nextDouble() * 100 + 150, // 150-250 avg
          'temperatureImpact': {
            'optimal': '${random.nextInt(10) + 70}-${random.nextInt(5) + 80}°F',
            'attendanceDropBelowTemp': random.nextInt(10) + 45,
            'attendanceDropAboveTemp': random.nextInt(10) + 85,
          },
        },
        'seasonalTrends': {
          'spring': {'avgAttendance': random.nextInt(100) + 350, 'vendorParticipation': random.nextDouble() * 0.2 + 0.75},
          'summer': {'avgAttendance': random.nextInt(150) + 450, 'vendorParticipation': random.nextDouble() * 0.15 + 0.85},
          'fall': {'avgAttendance': random.nextInt(120) + 380, 'vendorParticipation': random.nextDouble() * 0.2 + 0.8},
          'winter': {'avgAttendance': random.nextInt(80) + 200, 'vendorParticipation': random.nextDouble() * 0.3 + 0.6},
        },
        'cancellationMetrics': {
          'weatherCancellations': random.nextInt(8) + 2,
          'economicImpact': random.nextDouble() * 5000 + 2000,
          'makeupEventSuccess': random.nextDouble() * 0.3 + 0.5, // 50-80%
        },
        'weatherAlerts': [
          'Rain expected this weekend - consider covered areas',
          'High temperatures forecasted - ensure vendor hydration',
          'Perfect weather conditions for outdoor market',
        ],
      };
    } catch (e) {
      return {};
    }
  }

  /// Get comprehensive market health dashboard
  static Future<Map<String, dynamic>> getMarketHealthDashboard({
    required String organizerId,
  }) async {
    try {
      final random = Random();
      
      return {
        'overallHealthScore': random.nextDouble() * 25 + 70, // 70-95
        'keyIndicators': {
          'vendorSatisfaction': random.nextDouble() * 1.5 + 3.5, // 3.5-5.0
          'customerSatisfaction': 4.1, // Will be replaced by real feedback data from getCustomerAnalytics()
          'financialHealth': random.nextDouble() * 20 + 75, // 75-95
          'operationalEfficiency': random.nextDouble() * 15 + 80, // 80-95
        },
        'growthMetrics': {
          'customerGrowth': random.nextDouble() * 0.3 + 0.05, // 5-35%
          'vendorGrowth': random.nextDouble() * 0.25 + 0.02, // 2-27%
          'revenueGrowth': random.nextDouble() * 0.4 + 0.1, // 10-50%
        },
        'competitiveAnalysis': {
          'marketPosition': random.nextBool() ? 'Leading' : 'Competitive',
          'uniqueStrengths': [
            'Strong vendor diversity',
            'Prime location',
            'Excellent customer service',
            'Community engagement',
          ],
          'improvementAreas': [
            'Parking availability',
            'Marketing reach',
            'Event programming',
          ],
        },
        'actionItems': _generateActionItems(random),
      };
    } catch (e) {
      return {};
    }
  }

  /// Get comprehensive customer analytics using real feedback data
  /// This replaces mock customer satisfaction data with real metrics
  static Future<Map<String, dynamic>> getCustomerAnalytics({
    required String organizerId,
    String? marketId,
    DateTime? since,
  }) async {
    try {
      since ??= DateTime.now().subtract(const Duration(days: 90));
      
      // Get all feedback for markets managed by this organizer
      Query feedbackQuery = _firestore.collection('customer_feedback');
      
      if (marketId != null) {
        feedbackQuery = feedbackQuery.where('marketId', isEqualTo: marketId);
      } else {
        // Get all markets for this organizer first
        final marketsSnapshot = await _firestore
            .collection('markets')
            .where('organizerId', isEqualTo: organizerId)
            .get();
        
        final marketIds = marketsSnapshot.docs.map((doc) => doc.id).toList();
        
        if (marketIds.isEmpty) {
          return _getEmptyCustomerAnalytics();
        }
        
        // Query feedback for all organizer's markets
        feedbackQuery = feedbackQuery.where('marketId', whereIn: marketIds);
      }
      
      feedbackQuery = feedbackQuery.where('createdAt', isGreaterThan: Timestamp.fromDate(since));
      
      final feedbackSnapshot = await feedbackQuery.get();
      final allFeedback = feedbackSnapshot.docs
          .map((doc) => CustomerFeedback.fromFirestore(doc))
          .toList();
      
      if (allFeedback.isEmpty) {
        return _getEmptyCustomerAnalytics();
      }
      
      // Calculate overall customer satisfaction metrics
      final totalRatings = allFeedback.length;
      final averageRating = allFeedback
          .map((f) => f.overallRating)
          .fold(0, (total, rating) => total + rating) / totalRatings;
      
      // Get customer loyalty analytics
      final loyaltyAnalytics = marketId != null
          ? await CustomerLoyaltyService.getMarketReturnAnalytics(marketId, since: since)
          : await _getOrganizerLoyaltyAnalytics(organizerId, since);
      
      // Calculate satisfaction trends
      final last30DaysFeedback = allFeedback
          .where((f) => f.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 30))))
          .toList();
      
      final previous30DaysFeedback = allFeedback
          .where((f) => 
              f.createdAt.isBefore(DateTime.now().subtract(const Duration(days: 30))) &&
              f.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 60))))
          .toList();
      
      final recentAverage = last30DaysFeedback.isNotEmpty
          ? last30DaysFeedback.map((f) => f.overallRating).fold(0, (total, rating) => total + rating) / last30DaysFeedback.length
          : 0.0;
      
      final previousAverage = previous30DaysFeedback.isNotEmpty
          ? previous30DaysFeedback.map((f) => f.overallRating).fold(0, (total, rating) => total + rating) / previous30DaysFeedback.length
          : 0.0;
      
      final satisfactionTrend = previousAverage > 0 
          ? (recentAverage - previousAverage) / previousAverage 
          : 0.0;
      
      // Analyze category performance
      final categoryAnalysis = _analyzeCategoryPerformance(allFeedback);
      
      // Get sentiment breakdown
      final sentimentData = await CustomerFeedbackService.getSentimentAnalysis(
        marketId,
        null, // vendorId
        since: since,
      );
      
      // Calculate Net Promoter Score
      final npsScores = allFeedback
          .where((f) => f.npsScore != null)
          .map((f) => f.npsScore!)
          .toList();
      
      final averageNPS = npsScores.isNotEmpty
          ? npsScores.fold(0, (total, score) => total + score) / npsScores.length
          : null;
      
      // Analyze time patterns
      final timeAnalysis = _analyzeCustomerTimePatterns(allFeedback);
      
      // Get top concerns and praise
      final topConcerns = _getTopCustomerConcerns(allFeedback);
      final topPraise = _getTopCustomerPraise(allFeedback);
      
      // Calculate purchase metrics
      final purchaseFeedback = allFeedback.where((f) => f.madeAPurchase).toList();
      final totalSpent = purchaseFeedback
          .where((f) => f.estimatedSpendAmount != null)
          .map((f) => f.estimatedSpendAmount!)
          .fold(0.0, (total, amount) => total + amount);
      
      final averageSpend = purchaseFeedback.isNotEmpty 
          ? totalSpent / purchaseFeedback.length 
          : 0.0;
      
      return {
        'overview': {
          'totalFeedback': totalRatings,
          'averageRating': double.parse(averageRating.toStringAsFixed(2)),
          'satisfactionTrend': double.parse(satisfactionTrend.toStringAsFixed(3)),
          'recommendationRate': allFeedback.where((f) => f.wouldRecommend).length / totalRatings,
          'averageNPS': averageNPS?.toStringAsFixed(1),
        },
        'categoryPerformance': categoryAnalysis,
        'customerBehavior': {
          'returningCustomerRate': loyaltyAnalytics['returnRate'] ?? 0.0,
          'averageVisitsPerCustomer': loyaltyAnalytics['averageVisitsPerCustomer'] ?? 0.0,
          'purchaseConversionRate': purchaseFeedback.length / totalRatings,
          'averageSpendPerVisit': double.parse(averageSpend.toStringAsFixed(2)),
          'totalCustomerSpending': double.parse(totalSpent.toStringAsFixed(2)),
        },
        'demographics': {
          'visitPatterns': timeAnalysis,
          'ageDistribution': _getAgeDistribution(allFeedback),
          'locationData': _getLocationDistribution(allFeedback),
        },
        'sentiment': {
          'positive': double.parse(sentimentData['positivePercentage'] as String? ?? '0.0'),
          'negative': double.parse(sentimentData['negativePercentage'] as String? ?? '0.0'),
          'neutral': double.parse(sentimentData['neutralPercentage'] as String? ?? '0.0'),
        },
        'feedback': {
          'topConcerns': topConcerns,
          'topPraise': topPraise,
          'recentFeedbackCount': last30DaysFeedback.length,
        },
        'actionableInsights': _generateCustomerActionItems(
          averageRating, 
          satisfactionTrend, 
          topConcerns,
          loyaltyAnalytics['returnRate'] ?? 0.0,
        ),
        'dataFreshness': allFeedback.isNotEmpty
            ? DateTime.now().difference(allFeedback.first.createdAt).inDays
            : 0,
      };
      
    } catch (e) {
      return _getEmptyCustomerAnalytics();
    }
  }

  /// Export analytics data for reporting
  static Future<Map<String, dynamic>> exportAnalyticsReport({
    required String organizerId,
    required String reportType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // In a real implementation, this would generate downloadable reports
      final random = Random();
      
      return {
        'reportGenerated': true,
        'reportId': 'report_${DateTime.now().millisecondsSinceEpoch}',
        'reportType': reportType,
        'dateRange': {
          'start': startDate?.toIso8601String(),
          'end': endDate?.toIso8601String(),
        },
        'fileSize': '${random.nextInt(500) + 100}KB',
        'downloadUrl': 'https://example.com/reports/export_${DateTime.now().millisecondsSinceEpoch}.pdf',
        'expiresAt': DateTime.now().add(const Duration(days: 7)),
      };
    } catch (e) {
      return {'reportGenerated': false, 'error': e.toString()};
    }
  }

  // Helper methods

  /// Get financial summary for all markets managed by this organizer
  static Future<Map<String, dynamic>> _getMarketFinancialSummary(
    String organizerId, 
    DateTime startDate, 
    DateTime endDate
  ) async {
    try {
      // In a real implementation, you would:
      // 1. Query all markets managed by this organizer
      // 2. Get all vendor sales data for those markets in the date range
      // 3. Aggregate the financial data
      
      // For now, we'll query the market_financials collection directly
      final financialSnapshot = await _firestore
          .collection('market_financials')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      if (financialSnapshot.docs.isEmpty) {
        return {
          'totalRevenue': 0.0,
          'totalCommissions': 0.0,
          'totalMarketFees': 0.0,
          'totalVendors': 0,
          'totalTransactions': 0,
          'averageVendorRevenue': 0.0,
          'topCommissionVendors': <Map<String, dynamic>>[],
        };
      }

      double totalRevenue = 0.0;
      double totalCommissions = 0.0;
      double totalMarketFees = 0.0;
      int totalTransactions = 0;
      int totalVendors = 0;

      for (final doc in financialSnapshot.docs) {
        final data = doc.data();
        totalRevenue += (data['totalMarketRevenue'] ?? 0.0).toDouble();
        totalCommissions += (data['totalCommissionsCollected'] ?? 0.0).toDouble();
        totalMarketFees += (data['totalVendorFees'] ?? 0.0).toDouble();
        totalTransactions += (data['totalTransactions'] ?? 0) as int;
        totalVendors += (data['vendorCount'] ?? 0) as int;
      }

      final averageVendorRevenue = totalVendors > 0 ? totalRevenue / totalVendors : 0.0;

      return {
        'totalRevenue': totalRevenue,
        'totalCommissions': totalCommissions,
        'totalMarketFees': totalMarketFees,
        'totalVendors': totalVendors,
        'totalTransactions': totalTransactions,
        'averageVendorRevenue': averageVendorRevenue,
        'topCommissionVendors': await _getTopCommissionVendors(organizerId, startDate, endDate),
      };
    } catch (e) {
      return {
        'totalRevenue': 0.0,
        'totalCommissions': 0.0,
        'totalMarketFees': 0.0,
        'totalVendors': 0,
        'totalTransactions': 0,
        'averageVendorRevenue': 0.0,
        'topCommissionVendors': <Map<String, dynamic>>[],
      };
    }
  }

  static Future<List<Map<String, dynamic>>> _getTopCommissionVendors(
    String organizerId, 
    DateTime startDate, 
    DateTime endDate
  ) async {
    try {
      // Query vendor sales data to find top commission payers
      final salesSnapshot = await _firestore
          .collection('vendor_sales')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final vendorCommissions = <String, double>{};

      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        final vendorId = data['vendorId'] as String;
        final commission = (data['commissionPaid'] ?? 0.0).toDouble();
        
        vendorCommissions[vendorId] = (vendorCommissions[vendorId] ?? 0.0) + commission;
      }

      final topVendors = vendorCommissions.entries
          .map((entry) => {'vendorId': entry.key, 'commission': entry.value})
          .toList();
      
      topVendors.sort((a, b) => (b['commission'] as double).compareTo(a['commission'] as double));
      
      return topVendors.take(5).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> _getPeriodComparison(
    String organizerId, 
    DateTime startDate, 
    DateTime endDate
  ) async {
    try {
      final previousPeriodStart = startDate.subtract(endDate.difference(startDate));
      final previousPeriodEnd = startDate;

      final currentPeriod = await _getMarketFinancialSummary(organizerId, startDate, endDate);
      final previousPeriod = await _getMarketFinancialSummary(organizerId, previousPeriodStart, previousPeriodEnd);

      final currentRevenue = currentPeriod['totalRevenue'] as double;
      final previousRevenue = previousPeriod['totalRevenue'] as double;
      
      final revenueGrowth = previousRevenue > 0 
          ? ((currentRevenue - previousRevenue) / previousRevenue) * 100 
          : 0.0;

      return {
        'currentPeriodRevenue': currentRevenue,
        'previousPeriodRevenue': previousRevenue,
        'revenueGrowth': revenueGrowth,
        'transactionGrowth': _calculateTransactionGrowth(currentPeriod, previousPeriod),
        'vendorGrowth': _calculateVendorGrowth(currentPeriod, previousPeriod),
      };
    } catch (e) {
      return {
        'currentPeriodRevenue': 0.0,
        'previousPeriodRevenue': 0.0,
        'revenueGrowth': 0.0,
        'transactionGrowth': 0.0,
        'vendorGrowth': 0.0,
      };
    }
  }

  static Map<String, dynamic> _getEmptyRevenueAnalytics() {
    return {
      'revenueBreakdown': {
        'vendorCommissions': 0.0,
        'marketFees': 0.0,
        'totalVendorRevenue': 0.0,
        'grossMarketRevenue': 0.0,
      },
      'commissionTracking': {
        'totalCommissions': 0.0,
        'averageCommissionRate': 0.0,
        'topCommissionVendors': <Map<String, dynamic>>[],
      },
      'profitMargins': {
        'grossProfit': 0.0,
        'operatingCosts': 0.0,
        'netProfit': 0.0,
        'profitMargin': 0.0,
      },
      'vendorMetrics': {
        'totalVendors': 0,
        'totalTransactions': 0,
        'averageVendorRevenue': 0.0,
      },
      'periodComparison': {
        'currentPeriodRevenue': 0.0,
        'previousPeriodRevenue': 0.0,
        'revenueGrowth': 0.0,
        'transactionGrowth': 0.0,
        'vendorGrowth': 0.0,
      },
    };
  }

  static double _calculateTransactionGrowth(Map<String, dynamic> current, Map<String, dynamic> previous) {
    final currentTransactions = current['totalTransactions'] as int;
    final previousTransactions = previous['totalTransactions'] as int;
    
    return previousTransactions > 0 
        ? ((currentTransactions - previousTransactions) / previousTransactions) * 100 
        : 0.0;
  }

  static double _calculateVendorGrowth(Map<String, dynamic> current, Map<String, dynamic> previous) {
    final currentVendors = current['totalVendors'] as int;
    final previousVendors = previous['totalVendors'] as int;
    
    return previousVendors > 0 
        ? ((currentVendors - previousVendors) / previousVendors) * 100 
        : 0.0;
  }

  static double _calculateGrowthRate(List<Map<String, dynamic>> metrics, String field) {
    if (metrics.length < 7) return 0.0;
    
    final recent = metrics.skip(metrics.length - 7).fold(0.0, (sum, day) => sum + day[field]);
    final previous = metrics.take(7).fold(0.0, (sum, day) => sum + day[field]);
    
    return previous > 0 ? ((recent - previous) / previous) * 100 : 0.0;
  }

  static double _calculateMarketHealthScore(List<Map<String, dynamic>> metrics) {
    final avgRevenue = metrics.fold(0.0, (sum, day) => sum + day['revenue']) / metrics.length;
    final avgTraffic = metrics.fold(0.0, (sum, day) => sum + day['footTraffic']) / metrics.length;
    
    // Simple health score calculation based on revenue and traffic
    return ((avgRevenue / 1500) * 50 + (avgTraffic / 450) * 50).clamp(0, 100);
  }

  static String _getRandomCategory(Random random) {
    final categories = [
      'Fresh Produce', 'Baked Goods', 'Dairy & Eggs', 'Meat & Poultry',
      'Prepared Foods', 'Beverages', 'Crafts & Artwork', 'Flowers & Plants'
    ];
    return categories[random.nextInt(categories.length)];
  }

  static Map<String, int> _getCategoryDistribution(List<Map<String, dynamic>> vendors) {
    final distribution = <String, int>{};
    for (final vendor in vendors) {
      final category = vendor['category'] as String;
      distribution[category] = (distribution[category] ?? 0) + 1;
    }
    return distribution;
  }

  static List<String> _identifyPerformanceIssues(List<Map<String, dynamic>> vendors) {
    final issues = <String>[];
    final lowPerformers = vendors.where((v) => v['growthRate'] < 0).length;
    final lowSatisfaction = vendors.where((v) => v['customerSatisfaction'] < 4.0).length;
    
    if (lowPerformers > vendors.length * 0.3) {
      issues.add('$lowPerformers vendors showing negative growth');
    }
    if (lowSatisfaction > vendors.length * 0.2) {
      issues.add('$lowSatisfaction vendors with low customer satisfaction');
    }
    
    return issues.isEmpty ? ['No significant performance issues identified'] : issues;
  }

  static List<Map<String, dynamic>> _generateApplicationTrends() {
    final random = Random();
    return List.generate(6, (index) => {
      'month': DateTime.now().subtract(Duration(days: index * 30)).month,
      'applications': random.nextInt(15) + 8,
      'approvals': random.nextInt(12) + 6,
    });
  }

  static Map<String, dynamic> _generateRevenueForecasting(Random random) {
    return {
      'nextMonthPrediction': random.nextDouble() * 2000 + 8000,
      'nextQuarterPrediction': random.nextDouble() * 6000 + 24000,
      'confidence': random.nextDouble() * 0.2 + 0.75, // 75-95%
      'factors': [
        'Seasonal trends',
        'Vendor growth',
        'Community events',
        'Economic indicators'
      ],
    };
  }

  static List<String> _generateLayoutRecommendations() {
    return [
      'Consider expanding produce section due to high demand',
      'Improve foot traffic flow near entrance',
      'Add more covered areas for weather protection',
      'Create dedicated space for food trucks',
    ];
  }

  static List<String> _generateActionItems(Random random) {
    final items = [
      'Review underperforming vendors this month',
      'Plan capacity expansion for next season',
      'Update vendor fee structure',
      'Implement customer feedback system',
      'Organize vendor training workshop',
      'Review emergency procedures',
    ];
    
    return items.take(random.nextInt(3) + 3).toList();
  }

  // Customer analytics helper methods

  /// Get empty customer analytics structure
  static Map<String, dynamic> _getEmptyCustomerAnalytics() {
    return {
      'overview': {
        'totalFeedback': 0,
        'averageRating': 0.0,
        'satisfactionTrend': 0.0,
        'recommendationRate': 0.0,
        'averageNPS': null,
      },
      'categoryPerformance': <String, dynamic>{},
      'customerBehavior': {
        'returningCustomerRate': 0.0,
        'averageVisitsPerCustomer': 0.0,
        'purchaseConversionRate': 0.0,
        'averageSpendPerVisit': 0.0,
        'totalCustomerSpending': 0.0,
      },
      'demographics': {
        'visitPatterns': <String, dynamic>{},
        'ageDistribution': <String, int>{},
        'locationData': <String, int>{},
      },
      'sentiment': {
        'positive': 0.0,
        'negative': 0.0,
        'neutral': 0.0,
      },
      'feedback': {
        'topConcerns': [],
        'topPraise': [],
        'recentFeedbackCount': 0,
      },
      'actionableInsights': [],
      'dataFreshness': 0,
    };
  }

  /// Get organizer-wide loyalty analytics
  static Future<Map<String, dynamic>> _getOrganizerLoyaltyAnalytics(String organizerId, DateTime since) async {
    try {
      // Get all markets for this organizer
      final marketsSnapshot = await _firestore
          .collection('markets')
          .where('organizerId', isEqualTo: organizerId)
          .get();
      
      final marketIds = marketsSnapshot.docs.map((doc) => doc.id).toList();
      
      if (marketIds.isEmpty) {
        return {
          'returnRate': 0.0,
          'averageVisitsPerCustomer': 0.0,
          'uniqueCustomers': 0,
        };
      }

      // Get check-ins for all organizer's markets
      final checkInsSnapshot = await _firestore
          .collection('customer_checkins')
          .where('marketId', whereIn: marketIds)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .get();

      final checkInsData = checkInsSnapshot.docs
          .map((doc) => doc.data())
          .toList();

      // Calculate basic loyalty metrics from check-ins data
      final userVisits = <String, int>{};
      for (final checkIn in checkInsData) {
        final userId = checkIn['userId'] as String?;
        if (userId != null) {
          userVisits[userId] = (userVisits[userId] ?? 0) + 1;
        }
      }

      final uniqueCustomers = userVisits.length;
      final returningCustomers = userVisits.values.where((visits) => visits > 1).length;
      final returnRate = uniqueCustomers > 0 ? returningCustomers / uniqueCustomers : 0.0;
      final averageVisits = uniqueCustomers > 0 ? checkInsData.length / uniqueCustomers : 0.0;

      return {
        'returnRate': returnRate,
        'averageVisitsPerCustomer': averageVisits,
        'uniqueCustomers': uniqueCustomers,
      };
    } catch (e) {
      return {
        'returnRate': 0.0,
        'averageVisitsPerCustomer': 0.0,
        'uniqueCustomers': 0,
      };
    }
  }

  /// Analyze category performance from feedback
  static Map<String, dynamic> _analyzeCategoryPerformance(List<CustomerFeedback> feedbackList) {
    if (feedbackList.isEmpty) {
      return <String, dynamic>{};
    }

    final categoryData = <ReviewCategory, List<int>>{};
    
    for (final feedback in feedbackList) {
      for (final entry in feedback.categoryRatings.entries) {
        categoryData.putIfAbsent(entry.key, () => []);
        categoryData[entry.key]!.add(entry.value);
      }
    }
    
    return categoryData.map((category, ratings) {
      final average = ratings.fold(0, (total, rating) => total + rating) / ratings.length;
      return MapEntry(category.name, {
        'average': double.parse(average.toStringAsFixed(2)),
        'count': ratings.length,
        'strongPerformance': ratings.where((r) => r >= 4).length,
        'needsImprovement': ratings.where((r) => r <= 2).length,
      });
    });
  }

  /// Analyze customer time patterns
  static Map<String, dynamic> _analyzeCustomerTimePatterns(List<CustomerFeedback> feedbackList) {
    if (feedbackList.isEmpty) {
      return {
        'preferredDays': <String, int>{},
        'preferredTimes': <String, int>{},
      };
    }

    final dayPatterns = <int, int>{};
    final timePatterns = <int, int>{};

    for (final feedback in feedbackList) {
      final visitDate = feedback.visitDate;
      final dayOfWeek = visitDate.weekday;
      final hour = visitDate.hour;

      dayPatterns[dayOfWeek] = (dayPatterns[dayOfWeek] ?? 0) + 1;
      timePatterns[hour] = (timePatterns[hour] ?? 0) + 1;
    }

    // Convert to readable format
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final preferredDays = <String, int>{};
    for (final entry in dayPatterns.entries) {
      preferredDays[dayNames[entry.key - 1]] = entry.value;
    }

    final preferredTimes = <String, int>{};
    for (final entry in timePatterns.entries) {
      final hour = entry.key;
      String timeSlot;
      if (hour >= 6 && hour < 9) {
        timeSlot = 'Early Morning (6-9am)';
      } else if (hour >= 9 && hour < 12) {
        timeSlot = 'Morning (9am-12pm)';
      } else if (hour >= 12 && hour < 15) {
        timeSlot = 'Afternoon (12-3pm)';
      } else if (hour >= 15 && hour < 18) {
        timeSlot = 'Late Afternoon (3-6pm)';
      } else {
        timeSlot = 'Evening (6pm+)';
      }
      
      preferredTimes[timeSlot] = (preferredTimes[timeSlot] ?? 0) + entry.value;
    }

    return {
      'preferredDays': preferredDays,
      'preferredTimes': preferredTimes,
    };
  }

  /// Get top customer concerns
  static List<Map<String, dynamic>> _getTopCustomerConcerns(List<CustomerFeedback> feedbackList) {
    final concerns = <String, int>{};
    final lowRatingFeedback = feedbackList.where((f) => f.overallRating <= 2).toList();

    for (final feedback in lowRatingFeedback) {
      // Analyze category ratings for concerns
      for (final entry in feedback.categoryRatings.entries) {
        if (entry.value <= 2) {
          final concern = entry.key.displayName;
          concerns[concern] = (concerns[concern] ?? 0) + 1;
        }
      }

      // Extract keywords from negative reviews
      if (feedback.reviewText != null) {
        final text = feedback.reviewText!.toLowerCase();
        if (text.contains('expensive') || text.contains('costly')) {
          concerns['Pricing'] = (concerns['Pricing'] ?? 0) + 1;
        }
        if (text.contains('crowded') || text.contains('busy')) {
          concerns['Overcrowding'] = (concerns['Overcrowding'] ?? 0) + 1;
        }
        if (text.contains('parking')) {
          concerns['Parking'] = (concerns['Parking'] ?? 0) + 1;
        }
      }
    }

    final sortedConcerns = concerns.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedConcerns.take(5).map((entry) => {
      'concern': entry.key,
      'count': entry.value,
      'percentage': feedbackList.isNotEmpty 
          ? (entry.value / feedbackList.length * 100).toStringAsFixed(1) 
          : '0.0',
    }).toList();
  }

  /// Get top customer praise
  static List<Map<String, dynamic>> _getTopCustomerPraise(List<CustomerFeedback> feedbackList) {
    final praise = <String, int>{};
    final highRatingFeedback = feedbackList.where((f) => f.overallRating >= 4).toList();

    for (final feedback in highRatingFeedback) {
      // Analyze high category ratings
      for (final entry in feedback.categoryRatings.entries) {
        if (entry.value >= 4) {
          final strength = entry.key.displayName;
          praise[strength] = (praise[strength] ?? 0) + 1;
        }
      }

      // Extract positive keywords
      if (feedback.reviewText != null) {
        final text = feedback.reviewText!.toLowerCase();
        if (text.contains('variety') || text.contains('selection')) {
          praise['Great Variety'] = (praise['Great Variety'] ?? 0) + 1;
        }
        if (text.contains('fresh') || text.contains('quality')) {
          praise['Fresh Products'] = (praise['Fresh Products'] ?? 0) + 1;
        }
        if (text.contains('friendly') || text.contains('helpful')) {
          praise['Friendly Vendors'] = (praise['Friendly Vendors'] ?? 0) + 1;
        }
        if (text.contains('organized') || text.contains('clean')) {
          praise['Well Organized'] = (praise['Well Organized'] ?? 0) + 1;
        }
      }
    }

    final sortedPraise = praise.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedPraise.take(5).map((entry) => {
      'praise': entry.key,
      'count': entry.value,
      'percentage': feedbackList.isNotEmpty 
          ? (entry.value / feedbackList.length * 100).toStringAsFixed(1) 
          : '0.0',
    }).toList();
  }

  /// Get age distribution from feedback
  static Map<String, int> _getAgeDistribution(List<CustomerFeedback> feedbackList) {
    final ageDistribution = <String, int>{
      '18-24': 0,
      '25-34': 0,
      '35-44': 0,
      '45-54': 0,
      '55+': 0,
      'Unknown': 0,
    };

    for (final feedback in feedbackList) {
      final userAge = feedback.userAge;
      if (userAge != null) {
        if (userAge >= 18 && userAge <= 24) {
          ageDistribution['18-24'] = ageDistribution['18-24']! + 1;
        } else if (userAge >= 25 && userAge <= 34) {
          ageDistribution['25-34'] = ageDistribution['25-34']! + 1;
        } else if (userAge >= 35 && userAge <= 44) {
          ageDistribution['35-44'] = ageDistribution['35-44']! + 1;
        } else if (userAge >= 45 && userAge <= 54) {
          ageDistribution['45-54'] = ageDistribution['45-54']! + 1;
        } else if (userAge >= 55) {
          ageDistribution['55+'] = ageDistribution['55+']! + 1;
        }
      } else {
        ageDistribution['Unknown'] = ageDistribution['Unknown']! + 1;
      }
    }

    return ageDistribution;
  }

  /// Get location distribution from feedback
  static Map<String, int> _getLocationDistribution(List<CustomerFeedback> feedbackList) {
    final locationDistribution = <String, int>{};

    for (final feedback in feedbackList) {
      final location = feedback.userLocation ?? 'Unknown';
      locationDistribution[location] = (locationDistribution[location] ?? 0) + 1;
    }

    return locationDistribution;
  }

  /// Generate customer action items based on analytics
  static List<String> _generateCustomerActionItems(
    double averageRating, 
    double satisfactionTrend, 
    List<Map<String, dynamic>> topConcerns,
    double returnRate,
  ) {
    final actionItems = <String>[];

    if (averageRating < 3.5) {
      actionItems.add('Focus on improving overall customer satisfaction - rating is below 3.5 stars');
    }

    if (satisfactionTrend < -0.05) {
      actionItems.add('Address declining satisfaction trend - implement immediate improvements');
    }

    if (returnRate < 0.3) {
      actionItems.add('Improve customer retention - less than 30% of customers return');
    }

    // Add specific concerns
    for (final concern in topConcerns.take(3)) {
      final concernName = concern['concern'] as String;
      actionItems.add('Address customer concern: $concernName');
    }

    if (actionItems.isEmpty) {
      actionItems.add('Maintain current high standards and continue monitoring feedback');
    }

    return actionItems;
  }
}