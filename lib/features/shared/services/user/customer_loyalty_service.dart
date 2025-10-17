import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for tracking customer loyalty, return visits, and lifetime value
/// This replaces mock customer behavior data with real tracking metrics
class CustomerLoyaltyService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _checkInsCollection = 'customer_checkins';
  static const String _loyaltyProfilesCollection = 'customer_loyalty_profiles';

  /// Record a customer check-in at a market or vendor
  static Future<void> recordCheckIn({
    required String userId,
    required String marketId,
    String? vendorId,
    String? eventId,
    required DateTime timestamp,
    Duration? timeSpent,
    bool? madeAPurchase,
    double? estimatedSpend,
    String? sessionId,
  }) async {
    try {
      final checkInData = {
        'userId': userId,
        'marketId': marketId,
        'vendorId': vendorId,
        'eventId': eventId,
        'timestamp': Timestamp.fromDate(timestamp),
        'timeSpentMinutes': timeSpent?.inMinutes,
        'madeAPurchase': madeAPurchase ?? false,
        'estimatedSpend': estimatedSpend,
        'sessionId': sessionId ?? '${timestamp.millisecondsSinceEpoch}_$userId',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection(_checkInsCollection).add(checkInData);
      
      // Update loyalty profile
      await _updateLoyaltyProfile(
        userId: userId,
        marketId: marketId,
        vendorId: vendorId,
        visitTimestamp: timestamp,
        purchaseMade: madeAPurchase ?? false,
        spendAmount: estimatedSpend,
      );
      
    } catch (e) {
      throw Exception('Failed to record check-in: $e');
    }
  }

  /// Get customer loyalty profile
  static Future<Map<String, dynamic>> getCustomerLoyaltyProfile(String userId) async {
    try {
      final profileDoc = await _firestore
          .collection(_loyaltyProfilesCollection)
          .doc(userId)
          .get();

      if (!profileDoc.exists) {
        return _createEmptyLoyaltyProfile(userId);
      }

      final data = profileDoc.data()!;
      
      // Get recent check-ins for detailed analysis
      final recentCheckIns = await _getRecentCheckIns(userId, days: 90);
      
      return {
        ...data,
        'recentActivity': _analyzeRecentActivity(recentCheckIns),
        'loyaltyTier': _calculateLoyaltyTier(data),
        'recommendations': _generateLoyaltyRecommendations(data),
      };
    } catch (e) {
      throw Exception('Failed to get loyalty profile: $e');
    }
  }

  /// Get market-specific customer return analytics
  static Future<Map<String, dynamic>> getMarketReturnAnalytics(
    String marketId, {
    DateTime? since,
    DateTime? until,
  }) async {
    try {
      Query query = _firestore
          .collection(_checkInsCollection)
          .where('marketId', isEqualTo: marketId);

      if (since != null) {
        query = query.where('timestamp', isGreaterThan: Timestamp.fromDate(since));
      }

      if (until != null) {
        query = query.where('timestamp', isLessThan: Timestamp.fromDate(until));
      }

      final snapshot = await query.get();
      final checkIns = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      return _calculateMarketReturnMetrics(checkIns);
    } catch (e) {
      throw Exception('Failed to get market return analytics: $e');
    }
  }

  /// Get vendor-specific customer return analytics
  static Future<Map<String, dynamic>> getVendorReturnAnalytics(
    String vendorId, {
    DateTime? since,
    DateTime? until,
  }) async {
    try {
      Query query = _firestore
          .collection(_checkInsCollection)
          .where('vendorId', isEqualTo: vendorId);

      if (since != null) {
        query = query.where('timestamp', isGreaterThan: Timestamp.fromDate(since));
      }

      if (until != null) {
        query = query.where('timestamp', isLessThan: Timestamp.fromDate(until));
      }

      final snapshot = await query.get();
      final checkIns = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      return _calculateVendorReturnMetrics(checkIns);
    } catch (e) {
      throw Exception('Failed to get vendor return analytics: $e');
    }
  }

  /// Get customer lifetime value analytics
  static Future<Map<String, dynamic>> getCustomerLifetimeValueAnalytics(
    String? marketId,
    String? vendorId, {
    DateTime? since,
  }) async {
    try {
      Query query = _firestore.collection(_checkInsCollection);

      if (marketId != null) {
        query = query.where('marketId', isEqualTo: marketId);
      }

      if (vendorId != null) {
        query = query.where('vendorId', isEqualTo: vendorId);
      }

      if (since != null) {
        query = query.where('timestamp', isGreaterThan: Timestamp.fromDate(since));
      }

      final snapshot = await query.get();
      final checkIns = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      return _calculateLifetimeValueMetrics(checkIns);
    } catch (e) {
      throw Exception('Failed to get CLV analytics: $e');
    }
  }

  /// Get customer segment analytics
  static Future<Map<String, dynamic>> getCustomerSegmentAnalytics(
    String? marketId,
    String? vendorId, {
    DateTime? since,
  }) async {
    try {
      Query query = _firestore.collection(_checkInsCollection);

      if (marketId != null) {
        query = query.where('marketId', isEqualTo: marketId);
      }

      if (vendorId != null) {
        query = query.where('vendorId', isEqualTo: vendorId);
      }

      if (since != null) {
        query = query.where('timestamp', isGreaterThan: Timestamp.fromDate(since));
      }

      final snapshot = await query.get();
      final checkIns = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      return _segmentCustomers(checkIns);
    } catch (e) {
      throw Exception('Failed to get customer segment analytics: $e');
    }
  }

  /// Get customer retention cohort analysis
  static Future<Map<String, dynamic>> getCohortAnalysis(
    String? marketId,
    String? vendorId, {
    int months = 12,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = DateTime(endDate.year, endDate.month - months, endDate.day);

      Query query = _firestore
          .collection(_checkInsCollection)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThan: Timestamp.fromDate(endDate));

      if (marketId != null) {
        query = query.where('marketId', isEqualTo: marketId);
      }

      if (vendorId != null) {
        query = query.where('vendorId', isEqualTo: vendorId);
      }

      final snapshot = await query.get();
      final checkIns = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      return _performCohortAnalysis(checkIns, months);
    } catch (e) {
      throw Exception('Failed to perform cohort analysis: $e');
    }
  }

  /// Export loyalty data for business intelligence
  static Future<Map<String, dynamic>> exportLoyaltyData(
    String? marketId,
    String? vendorId, {
    DateTime? since,
    DateTime? until,
    String format = 'summary',
  }) async {
    try {
      Query query = _firestore.collection(_checkInsCollection);

      if (marketId != null) {
        query = query.where('marketId', isEqualTo: marketId);
      }

      if (vendorId != null) {
        query = query.where('vendorId', isEqualTo: vendorId);
      }

      if (since != null) {
        query = query.where('timestamp', isGreaterThan: Timestamp.fromDate(since));
      }

      if (until != null) {
        query = query.where('timestamp', isLessThan: Timestamp.fromDate(until));
      }

      final snapshot = await query.get();
      final checkIns = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>
      }).toList();

      switch (format) {
        case 'summary':
          return _generateLoyaltySummaryReport(checkIns);
        case 'detailed':
          return _generateDetailedLoyaltyReport(checkIns);
        case 'raw':
          return _generateRawLoyaltyExport(checkIns);
        default:
          throw ArgumentError('Invalid export format: $format');
      }
    } catch (e) {
      throw Exception('Failed to export loyalty data: $e');
    }
  }

  /// Update customer loyalty profile
  static Future<void> _updateLoyaltyProfile({
    required String userId,
    required String marketId,
    String? vendorId,
    required DateTime visitTimestamp,
    required bool purchaseMade,
    double? spendAmount,
  }) async {
    try {
      final profileRef = _firestore.collection(_loyaltyProfilesCollection).doc(userId);
      
      await _firestore.runTransaction((transaction) async {
        final profileDoc = await transaction.get(profileRef);
        
        Map<String, dynamic> profileData;
        if (profileDoc.exists) {
          profileData = profileDoc.data()!;
        } else {
          profileData = _createEmptyLoyaltyProfile(userId);
        }

        // Update visit counts
        profileData['totalVisits'] = (profileData['totalVisits'] as int) + 1;
        profileData['lastVisitAt'] = Timestamp.fromDate(visitTimestamp);
        
        // Update market-specific data
        final marketVisits = profileData['marketVisits'] as Map<String, dynamic>;
        final currentMarketVisits = marketVisits[marketId] as int? ?? 0;
        marketVisits[marketId] = currentMarketVisits + 1;
        
        // Update vendor-specific data if applicable
        if (vendorId != null) {
          final vendorVisits = profileData['vendorVisits'] as Map<String, dynamic>;
          final currentVendorVisits = vendorVisits[vendorId] as int? ?? 0;
          vendorVisits[vendorId] = currentVendorVisits + 1;
        }

        // Update purchase data
        if (purchaseMade) {
          profileData['totalPurchases'] = (profileData['totalPurchases'] as int) + 1;
          if (spendAmount != null) {
            profileData['totalSpent'] = (profileData['totalSpent'] as double) + spendAmount;
          }
        }

        // Calculate visit frequency
        final firstVisit = (profileData['firstVisitAt'] as Timestamp).toDate();
        final daysSinceFirst = visitTimestamp.difference(firstVisit).inDays;
        profileData['visitFrequency'] = daysSinceFirst > 0 
            ? (profileData['totalVisits'] as int) / daysSinceFirst 
            : 1.0;

        // Update streaks
        _updateVisitStreaks(profileData, visitTimestamp);

        profileData['updatedAt'] = FieldValue.serverTimestamp();
        
        transaction.set(profileRef, profileData, SetOptions(merge: true));
      });
    } catch (e) {
    }
  }

  /// Create empty loyalty profile
  static Map<String, dynamic> _createEmptyLoyaltyProfile(String userId) {
    final now = DateTime.now();
    return {
      'userId': userId,
      'totalVisits': 0,
      'totalPurchases': 0,
      'totalSpent': 0.0,
      'firstVisitAt': Timestamp.fromDate(now),
      'lastVisitAt': Timestamp.fromDate(now),
      'marketVisits': <String, int>{},
      'vendorVisits': <String, int>{},
      'visitFrequency': 0.0,
      'currentStreak': 0,
      'longestStreak': 0,
      'lastStreakDate': Timestamp.fromDate(now),
      'loyaltyPoints': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Get recent check-ins for a user
  static Future<List<Map<String, dynamic>>> _getRecentCheckIns(String userId, {int days = 30}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    
    final snapshot = await _firestore
        .collection(_checkInsCollection)
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('timestamp', descending: true)
        .limit(100)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Analyze recent activity patterns
  static Map<String, dynamic> _analyzeRecentActivity(List<Map<String, dynamic>> checkIns) {
    if (checkIns.isEmpty) {
      return {
        'totalVisits': 0,
        'uniqueMarkets': 0,
        'uniqueVendors': 0,
        'averageSessionLength': 0,
        'purchaseRate': 0.0,
        'preferredDays': [],
        'preferredTimes': [],
      };
    }

    final uniqueMarkets = <String>{};
    final uniqueVendors = <String>{};
    final sessionLengths = <int>[];
    int purchaseCount = 0;
    final dayOfWeekCounts = <int, int>{};
    final hourCounts = <int, int>{};

    for (final checkIn in checkIns) {
      if (checkIn['marketId'] != null) {
        uniqueMarkets.add(checkIn['marketId'] as String);
      }
      
      if (checkIn['vendorId'] != null) {
        uniqueVendors.add(checkIn['vendorId'] as String);
      }
      
      if (checkIn['timeSpentMinutes'] != null) {
        sessionLengths.add(checkIn['timeSpentMinutes'] as int);
      }
      
      if (checkIn['madeAPurchase'] == true) {
        purchaseCount++;
      }
      
      final timestamp = (checkIn['timestamp'] as Timestamp).toDate();
      final dayOfWeek = timestamp.weekday;
      final hour = timestamp.hour;
      
      dayOfWeekCounts[dayOfWeek] = (dayOfWeekCounts[dayOfWeek] ?? 0) + 1;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    final averageSessionLength = sessionLengths.isNotEmpty 
        ? sessionLengths.fold(0, (a, b) => a + b) / sessionLengths.length 
        : 0;

    final purchaseRate = checkIns.isNotEmpty ? purchaseCount / checkIns.length : 0.0;

    // Find preferred days and times
    final preferredDays = dayOfWeekCounts.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
    
    final preferredTimes = hourCounts.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'totalVisits': checkIns.length,
      'uniqueMarkets': uniqueMarkets.length,
      'uniqueVendors': uniqueVendors.length,
      'averageSessionLength': averageSessionLength.round(),
      'purchaseRate': double.parse(purchaseRate.toStringAsFixed(3)),
      'preferredDays': preferredDays.take(3).map((e) => {
        'day': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][e.key - 1],
        'visits': e.value,
      }).toList(),
      'preferredTimes': preferredTimes.take(3).map((e) => {
        'hour': e.key,
        'visits': e.value,
      }).toList(),
    };
  }

  /// Calculate loyalty tier based on profile data
  static String _calculateLoyaltyTier(Map<String, dynamic> profileData) {
    final totalVisits = profileData['totalVisits'] as int;
    final totalSpent = profileData['totalSpent'] as double;
    final visitFrequency = profileData['visitFrequency'] as double;

    if (totalVisits >= 20 && totalSpent >= 500 && visitFrequency >= 0.1) {
      return 'VIP';
    } else if (totalVisits >= 10 && totalSpent >= 200) {
      return 'Gold';
    } else if (totalVisits >= 5 && totalSpent >= 50) {
      return 'Silver';
    } else if (totalVisits >= 2) {
      return 'Bronze';
    } else {
      return 'New';
    }
  }

  /// Generate loyalty recommendations
  static List<String> _generateLoyaltyRecommendations(Map<String, dynamic> profileData) {
    final recommendations = <String>[];
    final tier = _calculateLoyaltyTier(profileData);
    final totalVisits = profileData['totalVisits'] as int;
    final purchaseRate = totalVisits > 0 
        ? (profileData['totalPurchases'] as int) / totalVisits 
        : 0.0;

    switch (tier) {
      case 'New':
        recommendations.add('Welcome! Complete 2 more visits to reach Bronze tier');
        break;
      case 'Bronze':
        recommendations.add('Make 3 more visits to reach Silver tier');
        break;
      case 'Silver':
        recommendations.add('Visit 5 more times to unlock Gold benefits');
        break;
      case 'Gold':
        recommendations.add('Reach VIP status with 10 more visits and \$300 more spent');
        break;
      case 'VIP':
        recommendations.add('You\'re our most valued customer! Thank you for your loyalty');
        break;
    }

    if (purchaseRate < 0.5) {
      recommendations.add('Try making purchases during your visits to maximize benefits');
    }

    return recommendations;
  }

  /// Calculate market return metrics
  static Map<String, dynamic> _calculateMarketReturnMetrics(List<Map<String, dynamic>> checkIns) {
    if (checkIns.isEmpty) {
      return {
        'totalVisits': 0,
        'uniqueCustomers': 0,
        'returnCustomers': 0,
        'returnRate': 0.0,
        'averageVisitsPerCustomer': 0.0,
        'purchaseConversion': 0.0,
      };
    }

    final customerVisits = <String, int>{};
    int totalPurchases = 0;

    for (final checkIn in checkIns) {
      final userId = checkIn['userId'] as String;
      customerVisits[userId] = (customerVisits[userId] ?? 0) + 1;
      
      if (checkIn['madeAPurchase'] == true) {
        totalPurchases++;
      }
    }

    final uniqueCustomers = customerVisits.length;
    final returnCustomers = customerVisits.values.where((visits) => visits > 1).length;
    final returnRate = uniqueCustomers > 0 ? returnCustomers / uniqueCustomers : 0.0;
    final averageVisits = uniqueCustomers > 0 ? checkIns.length / uniqueCustomers : 0.0;
    final conversionRate = checkIns.isNotEmpty ? totalPurchases / checkIns.length : 0.0;

    return {
      'totalVisits': checkIns.length,
      'uniqueCustomers': uniqueCustomers,
      'returnCustomers': returnCustomers,
      'returnRate': double.parse(returnRate.toStringAsFixed(3)),
      'averageVisitsPerCustomer': double.parse(averageVisits.toStringAsFixed(2)),
      'purchaseConversion': double.parse(conversionRate.toStringAsFixed(3)),
    };
  }

  /// Calculate vendor return metrics
  static Map<String, dynamic> _calculateVendorReturnMetrics(List<Map<String, dynamic>> checkIns) {
    return _calculateMarketReturnMetrics(checkIns); // Same logic applies
  }

  /// Calculate customer lifetime value metrics
  static Map<String, dynamic> _calculateLifetimeValueMetrics(List<Map<String, dynamic>> checkIns) {
    final customerData = <String, Map<String, dynamic>>{};

    for (final checkIn in checkIns) {
      final userId = checkIn['userId'] as String;
      
      if (!customerData.containsKey(userId)) {
        customerData[userId] = {
          'visits': 0,
          'purchases': 0,
          'totalSpent': 0.0,
          'firstVisit': checkIn['timestamp'],
          'lastVisit': checkIn['timestamp'],
        };
      }

      final data = customerData[userId]!;
      data['visits'] = (data['visits'] as int) + 1;
      data['lastVisit'] = checkIn['timestamp'];

      if (checkIn['madeAPurchase'] == true) {
        data['purchases'] = (data['purchases'] as int) + 1;
        if (checkIn['estimatedSpend'] != null) {
          data['totalSpent'] = (data['totalSpent'] as double) + (checkIn['estimatedSpend'] as double);
        }
      }
    }

    final totalCustomers = customerData.length;
    if (totalCustomers == 0) {
      return {
        'averageLifetimeValue': 0.0,
        'averageVisitsPerCustomer': 0.0,
        'averagePurchasesPerCustomer': 0.0,
        'customerSegments': {},
      };
    }

    final totalSpent = customerData.values
        .map((data) => data['totalSpent'] as double)
        .fold(0.0, (a, b) => a + b);
    
    final totalVisits = customerData.values
        .map((data) => data['visits'] as int)
        .fold(0, (a, b) => a + b);
    
    final totalPurchases = customerData.values
        .map((data) => data['purchases'] as int)
        .fold(0, (a, b) => a + b);

    return {
      'averageLifetimeValue': double.parse((totalSpent / totalCustomers).toStringAsFixed(2)),
      'averageVisitsPerCustomer': double.parse((totalVisits / totalCustomers).toStringAsFixed(2)),
      'averagePurchasesPerCustomer': double.parse((totalPurchases / totalCustomers).toStringAsFixed(2)),
      'totalCustomers': totalCustomers,
      'customerSegments': _segmentCustomersByValue(customerData),
    };
  }

  /// Segment customers by behavior patterns
  static Map<String, dynamic> _segmentCustomers(List<Map<String, dynamic>> checkIns) {
    final customerBehavior = <String, Map<String, dynamic>>{};

    for (final checkIn in checkIns) {
      final userId = checkIn['userId'] as String;
      
      if (!customerBehavior.containsKey(userId)) {
        customerBehavior[userId] = {
          'visits': 0,
          'purchases': 0,
          'totalSpent': 0.0,
        };
      }

      final behavior = customerBehavior[userId]!;
      behavior['visits'] = (behavior['visits'] as int) + 1;

      if (checkIn['madeAPurchase'] == true) {
        behavior['purchases'] = (behavior['purchases'] as int) + 1;
        if (checkIn['estimatedSpend'] != null) {
          behavior['totalSpent'] = (behavior['totalSpent'] as double) + (checkIn['estimatedSpend'] as double);
        }
      }
    }

    final segments = {
      'high_value': 0, // High spend, frequent visits
      'loyal': 0,      // Many visits, some purchases
      'occasional': 0,  // Few visits, some purchases
      'browsers': 0,    // Many visits, few purchases
      'new': 0,         // Single visit
    };

    for (final behavior in customerBehavior.values) {
      final visits = behavior['visits'] as int;
      final purchases = behavior['purchases'] as int;
      final spent = behavior['totalSpent'] as double;

      if (spent > 100 && visits > 5) {
        segments['high_value'] = segments['high_value']! + 1;
      } else if (visits > 5 && purchases > 2) {
        segments['loyal'] = segments['loyal']! + 1;
      } else if (visits > 1 && purchases > 0) {
        segments['occasional'] = segments['occasional']! + 1;
      } else if (visits > 3 && purchases == 0) {
        segments['browsers'] = segments['browsers']! + 1;
      } else {
        segments['new'] = segments['new']! + 1;
      }
    }

    return segments;
  }

  /// Segment customers by lifetime value
  static Map<String, int> _segmentCustomersByValue(Map<String, Map<String, dynamic>> customerData) {
    final segments = {
      'high_value': 0,    // $100+
      'medium_value': 0,  // $25-$99
      'low_value': 0,     // $5-$24
      'browsers': 0,      // $0-$4
    };

    for (final data in customerData.values) {
      final totalSpent = data['totalSpent'] as double;

      if (totalSpent >= 100) {
        segments['high_value'] = segments['high_value']! + 1;
      } else if (totalSpent >= 25) {
        segments['medium_value'] = segments['medium_value']! + 1;
      } else if (totalSpent >= 5) {
        segments['low_value'] = segments['low_value']! + 1;
      } else {
        segments['browsers'] = segments['browsers']! + 1;
      }
    }

    return segments;
  }

  /// Perform cohort analysis
  static Map<String, dynamic> _performCohortAnalysis(List<Map<String, dynamic>> checkIns, int months) {
    // Group customers by first visit month
    final cohorts = <String, Map<String, dynamic>>{};

    for (final checkIn in checkIns) {
      final userId = checkIn['userId'] as String;
      final timestamp = (checkIn['timestamp'] as Timestamp).toDate();
      final monthKey = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}';

      if (!cohorts.containsKey(monthKey)) {
        cohorts[monthKey] = {
          'customers': <String>{},
          'monthlyRetention': <String, Set<String>>{},
        };
      }

      final cohort = cohorts[monthKey]!;
      (cohort['customers'] as Set<String>).add(userId);
      
      final retentionKey = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}';
      if (!(cohort['monthlyRetention'] as Map).containsKey(retentionKey)) {
        (cohort['monthlyRetention'] as Map<String, Set<String>>)[retentionKey] = <String>{};
      }
      ((cohort['monthlyRetention'] as Map<String, Set<String>>)[retentionKey]!).add(userId);
    }

    // Calculate retention rates
    final retentionMatrix = <String, Map<String, double>>{};
    
    for (final cohortEntry in cohorts.entries) {
      final cohortMonth = cohortEntry.key;
      final cohortData = cohortEntry.value;
      final totalCustomers = (cohortData['customers'] as Set<String>).length;
      
      retentionMatrix[cohortMonth] = {};
      
      for (final retentionEntry in (cohortData['monthlyRetention'] as Map<String, Set<String>>).entries) {
        final retentionMonth = retentionEntry.key;
        final activeCustomers = retentionEntry.value.length;
        
        final retentionRate = totalCustomers > 0 ? activeCustomers / totalCustomers : 0.0;
        retentionMatrix[cohortMonth]![retentionMonth] = double.parse(retentionRate.toStringAsFixed(3));
      }
    }

    return {
      'cohorts': retentionMatrix,
      'totalCohorts': cohorts.length,
      'analysisMonths': months,
    };
  }

  /// Update visit streaks
  static void _updateVisitStreaks(Map<String, dynamic> profileData, DateTime visitTimestamp) {
    final lastStreakDate = (profileData['lastStreakDate'] as Timestamp).toDate();
    final daysSinceLastVisit = visitTimestamp.difference(lastStreakDate).inDays;
    
    if (daysSinceLastVisit == 1) {
      // Consecutive day visit - increment streak
      profileData['currentStreak'] = (profileData['currentStreak'] as int) + 1;
    } else if (daysSinceLastVisit > 1) {
      // Streak broken - reset
      profileData['currentStreak'] = 1;
    }
    // Same day visit - no change to streak
    
    // Update longest streak if current is longer
    if ((profileData['currentStreak'] as int) > (profileData['longestStreak'] as int)) {
      profileData['longestStreak'] = profileData['currentStreak'];
    }
    
    profileData['lastStreakDate'] = Timestamp.fromDate(visitTimestamp);
  }

  /// Generate loyalty summary report
  static Map<String, dynamic> _generateLoyaltySummaryReport(List<Map<String, dynamic>> checkIns) {
    final marketMetrics = _calculateMarketReturnMetrics(checkIns);
    final clvMetrics = _calculateLifetimeValueMetrics(checkIns);
    final segmentation = _segmentCustomers(checkIns);

    return {
      'reportGeneratedAt': DateTime.now().toIso8601String(),
      'period': {
        'from': checkIns.isNotEmpty ? (checkIns.last['timestamp'] as Timestamp).toDate().toIso8601String() : null,
        'to': checkIns.isNotEmpty ? (checkIns.first['timestamp'] as Timestamp).toDate().toIso8601String() : null,
      },
      'overview': marketMetrics,
      'lifetimeValue': clvMetrics,
      'customerSegments': segmentation,
    };
  }

  /// Generate detailed loyalty report
  static Map<String, dynamic> _generateDetailedLoyaltyReport(List<Map<String, dynamic>> checkIns) {
    final summary = _generateLoyaltySummaryReport(checkIns);
    
    return {
      ...summary,
      'detailed': {
        'temporalAnalysis': _analyzeTemporalPatterns(checkIns),
        'behaviorPatterns': _analyzeBehaviorPatterns(checkIns),
        'purchaseAnalysis': _analyzePurchasePatterns(checkIns),
      }
    };
  }

  /// Generate raw loyalty data export
  static Map<String, dynamic> _generateRawLoyaltyExport(List<Map<String, dynamic>> checkIns) {
    return {
      'exportGeneratedAt': DateTime.now().toIso8601String(),
      'totalRecords': checkIns.length,
      'data': checkIns.map((checkIn) => {
        ...checkIn,
        'timestamp': (checkIn['timestamp'] as Timestamp).toDate().toIso8601String(),
        'createdAt': checkIn['createdAt'] != null 
            ? (checkIn['createdAt'] as Timestamp).toDate().toIso8601String()
            : null,
      }).toList(),
    };
  }

  /// Analyze temporal patterns in check-ins
  static Map<String, dynamic> _analyzeTemporalPatterns(List<Map<String, dynamic>> checkIns) {
    final dayOfWeekCounts = <int, int>{};
    final hourCounts = <int, int>{};
    final monthCounts = <int, int>{};

    for (final checkIn in checkIns) {
      final timestamp = (checkIn['timestamp'] as Timestamp).toDate();
      
      dayOfWeekCounts[timestamp.weekday] = (dayOfWeekCounts[timestamp.weekday] ?? 0) + 1;
      hourCounts[timestamp.hour] = (hourCounts[timestamp.hour] ?? 0) + 1;
      monthCounts[timestamp.month] = (monthCounts[timestamp.month] ?? 0) + 1;
    }

    return {
      'byDayOfWeek': dayOfWeekCounts,
      'byHour': hourCounts,
      'byMonth': monthCounts,
    };
  }

  /// Analyze behavior patterns
  static Map<String, dynamic> _analyzeBehaviorPatterns(List<Map<String, dynamic>> checkIns) {
    final sessionLengths = <int>[];
    final purchaseRates = <String, double>{};
    
    for (final checkIn in checkIns) {
      if (checkIn['timeSpentMinutes'] != null) {
        sessionLengths.add(checkIn['timeSpentMinutes'] as int);
      }
      
      final marketId = checkIn['marketId'] as String;
      if (!purchaseRates.containsKey(marketId)) {
        purchaseRates[marketId] = 0.0;
      }
      
      if (checkIn['madeAPurchase'] == true) {
        purchaseRates[marketId] = purchaseRates[marketId]! + 1;
      }
    }
    
    // Calculate averages
    final averageSessionLength = sessionLengths.isNotEmpty 
        ? sessionLengths.fold(0, (a, b) => a + b) / sessionLengths.length 
        : 0.0;
    
    return {
      'averageSessionLength': averageSessionLength,
      'sessionLengthDistribution': _getDistribution(sessionLengths),
      'marketPurchaseRates': purchaseRates,
    };
  }

  /// Analyze purchase patterns
  static Map<String, dynamic> _analyzePurchasePatterns(List<Map<String, dynamic>> checkIns) {
    final spendAmounts = <double>[];
    final purchasesByMarket = <String, int>{};
    
    for (final checkIn in checkIns) {
      if (checkIn['madeAPurchase'] == true) {
        final marketId = checkIn['marketId'] as String;
        purchasesByMarket[marketId] = (purchasesByMarket[marketId] ?? 0) + 1;
        
        if (checkIn['estimatedSpend'] != null) {
          spendAmounts.add(checkIn['estimatedSpend'] as double);
        }
      }
    }
    
    final averageSpend = spendAmounts.isNotEmpty 
        ? spendAmounts.fold(0.0, (a, b) => a + b) / spendAmounts.length 
        : 0.0;
    
    return {
      'totalPurchases': purchasesByMarket.values.fold(0, (a, b) => a + b),
      'averageSpend': averageSpend,
      'spendDistribution': _getSpendDistribution(spendAmounts),
      'purchasesByMarket': purchasesByMarket,
    };
  }

  /// Get distribution of values
  static Map<String, int> _getDistribution(List<int> values) {
    if (values.isEmpty) return {};
    
    values.sort();
    final min = values.first;
    final max = values.last;
    final range = max - min;
    final bucketSize = range > 0 ? (range / 5).ceil() : 1;
    
    final distribution = <String, int>{};
    for (final value in values) {
      final bucketIndex = ((value - min) / bucketSize).floor();
      final bucketStart = min + (bucketIndex * bucketSize);
      final bucketEnd = bucketStart + bucketSize;
      final bucketKey = '$bucketStart-$bucketEnd';
      
      distribution[bucketKey] = (distribution[bucketKey] ?? 0) + 1;
    }
    
    return distribution;
  }

  /// Get spend amount distribution
  static Map<String, int> _getSpendDistribution(List<double> amounts) {
    final distribution = {
      'under-10': 0,
      '10-25': 0,
      '25-50': 0,
      '50-100': 0,
      'over-100': 0,
    };
    
    for (final amount in amounts) {
      if (amount < 10) {
        distribution['under-10'] = distribution['under-10']! + 1;
      } else if (amount < 25) {
        distribution['10-25'] = distribution['10-25']! + 1;
      } else if (amount < 50) {
        distribution['25-50'] = distribution['25-50']! + 1;
      } else if (amount < 100) {
        distribution['50-100'] = distribution['50-100']! + 1;
      } else {
        distribution['over-100'] = distribution['over-100']! + 1;
      }
    }
    
    return distribution;
  }
}