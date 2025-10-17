import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/market.dart';
import '../../../core/extensions/map_extensions.dart';

/// Service for managing vendor recruitment features
/// Provides optimized queries and real-time updates for markets looking for vendors
class VendorRecruitmentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Get all markets actively looking for vendors
  /// Optimized with compound indexes for performance
  static Stream<List<Market>> getMarketsLookingForVendors({
    int limit = 20,
    DateTime? afterDate,
  }) {
    Query query = _firestore
        .collection('markets')
        .where('isLookingForVendors', isEqualTo: true)
        .where('isActive', isEqualTo: true);
    
    // Filter by event date if provided
    if (afterDate != null) {
      query = query.where('eventDate', isGreaterThan: Timestamp.fromDate(afterDate));
    } else {
      // Default to future events only
      query = query.where('eventDate', isGreaterThan: Timestamp.now());
    }
    
    // Order by urgency (application deadline)
    query = query.orderBy('applicationDeadline').limit(limit);
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Market.fromFirestore(doc))
          .where((market) => 
              !market.isApplicationDeadlinePassed &&
              market.hasAvailableSpots)
          .toList();
    });
  }
  
  /// Get markets with urgent deadlines (within 3 days)
  static Future<List<Market>> getUrgentRecruitingMarkets() async {
    try {
      final now = DateTime.now();
      final urgentDeadline = now.add(const Duration(days: 3));
      
      final snapshot = await _firestore
          .collection('markets')
          .where('isLookingForVendors', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .where('applicationDeadline', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('applicationDeadline', isLessThanOrEqualTo: Timestamp.fromDate(urgentDeadline))
          .orderBy('applicationDeadline')
          .get();
      
      return snapshot.docs
          .map((doc) => Market.fromFirestore(doc))
          .where((market) => market.hasAvailableSpots)
          .toList();
    } catch (e) {
      // Debug print for Firestore index errors
      
      final errorString = e.toString();
      if (errorString.contains('index')) {
        
        // Extract URL if present
        final urlPattern = RegExp(r'https://console\.firebase\.google\.com/[^\s]+');
        final match = urlPattern.firstMatch(errorString);
        if (match != null) {
        }
      }
      rethrow; // Re-throw the error
    }
  }
  
  /// Update vendor spots when a vendor is accepted
  static Future<void> updateVendorSpots(
    String marketId, {
    required int spotsToDeduct,
  }) async {
    final marketRef = _firestore.collection('markets').doc(marketId);
    
    await _firestore.runTransaction((transaction) async {
      final marketDoc = await transaction.get(marketRef);
      
      if (!marketDoc.exists) {
        throw Exception('Market not found');
      }
      
      final currentSpots = marketDoc.data()?['vendorSpotsAvailable'] as int? ?? 0;
      final newSpots = (currentSpots - spotsToDeduct).clamp(0, double.infinity).toInt();
      
      transaction.update(marketRef, {
        'vendorSpotsAvailable': newSpots,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // If no spots left, optionally update isLookingForVendors
      if (newSpots == 0) {
        transaction.update(marketRef, {
          'isLookingForVendors': false,
        });
      }
    });
  }
  
  /// Toggle market recruitment status
  static Future<void> toggleRecruitmentStatus(
    String marketId,
    bool isLookingForVendors,
  ) async {
    await _firestore.collection('markets').doc(marketId).update({
      'isLookingForVendors': isLookingForVendors,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  /// Get markets by location with recruitment filter
  static Future<List<Market>> getNearbyRecruitingMarkets({
    required double latitude,
    required double longitude,
    double radiusInMiles = 25,
  }) async {
    // Calculate bounding box for initial query
    const double milesPerDegree = 69.0;
    final double latDelta = radiusInMiles / milesPerDegree;
    
    // Note: Firestore has limitations on range queries
    // We'll do a broad latitude filter and calculate exact distance in memory
    final snapshot = await _firestore
        .collection('markets')
        .where('isLookingForVendors', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .where('latitude', isGreaterThan: latitude - latDelta)
        .where('latitude', isLessThan: latitude + latDelta)
        .get();
    
    // Filter by actual distance and other criteria
    final markets = snapshot.docs
        .map((doc) => Market.fromFirestore(doc))
        .where((market) {
          // Calculate actual distance
          final distance = _calculateDistance(
            latitude,
            longitude,
            market.latitude,
            market.longitude,
          );
          
          return distance <= radiusInMiles &&
                 !market.isApplicationDeadlinePassed &&
                 market.hasAvailableSpots &&
                 market.eventDate.isAfter(DateTime.now());
        })
        .toList();
    
    // Sort by distance
    markets.sort((a, b) {
      final distA = _calculateDistance(latitude, longitude, a.latitude, a.longitude);
      final distB = _calculateDistance(latitude, longitude, b.latitude, b.longitude);
      return distA.compareTo(distB);
    });
    
    return markets;
  }
  
  /// Calculate distance between two coordinates in miles
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 3959; // Earth's radius in miles
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
  
  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
  
  /// Track vendor application
  static Future<void> trackVendorApplication({
    required String vendorId,
    required String marketId,
    String? applicationUrl,
  }) async {
    await _firestore.collection('vendor_applications').add({
      'vendorId': vendorId,
      'marketId': marketId,
      'applicationUrl': applicationUrl,
      'appliedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    
    // Also update vendor's application history
    await _firestore
        .collection('users')
        .doc(vendorId)
        .collection('market_applications')
        .doc(marketId)
        .set({
      'marketId': marketId,
      'appliedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }
  
  /// Get vendor's application history
  static Future<List<Map<String, dynamic>>> getVendorApplications(
    String vendorId,
  ) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(vendorId)
        .collection('market_applications')
        .orderBy('appliedAt', descending: true)
        .get();
    
    return snapshot.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }
  
  /// Update market recruitment details
  static Future<void> updateRecruitmentDetails(
    String marketId, {
    String? applicationUrl,
    double? applicationFee,
    double? dailyBoothFee,
    int? vendorSpotsTotal,
    int? vendorSpotsAvailable,
    DateTime? applicationDeadline,
    String? vendorRequirements,
    List<String>? targetCategories,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    }
      ..addIfNotNull('applicationUrl', applicationUrl)
      ..addIfNotNull('applicationFee', applicationFee)
      ..addIfNotNull('dailyBoothFee', dailyBoothFee)
      ..addIfNotNull('vendorSpotsTotal', vendorSpotsTotal)
      ..addIfNotNull('vendorSpotsAvailable', vendorSpotsAvailable)
      ..addIfNotNull('applicationDeadline',
        applicationDeadline != null ? Timestamp.fromDate(applicationDeadline) : null)
      ..addIfNotNull('vendorRequirements', vendorRequirements)
      ..addIfNotNull('targetCategories', targetCategories);

    await _firestore.collection('markets').doc(marketId).update(updates);
  }
  
  /// Get markets looking for vendors filtered by vendor categories
  /// Returns only markets that either have no target categories (open to all)
  /// or have target categories that match the vendor's categories
  static Stream<List<Market>> getTargetedMarketsForVendor({
    required List<String> vendorCategories,
    int limit = 20,
    DateTime? afterDate,
  }) {
    if (vendorCategories.isEmpty) {
      // If vendor has no categories, show all markets with no targeting
      return _firestore
          .collection('markets')
          .where('isLookingForVendors', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .where('targetCategories', isEqualTo: null)
          .where('eventDate', isGreaterThan: Timestamp.fromDate(afterDate ?? DateTime.now()))
          .orderBy('eventDate')
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => Market.fromFirestore(doc))
                .where((market) =>
                    !market.isApplicationDeadlinePassed &&
                    market.hasAvailableSpots)
                .toList();
          });
    }

    // For vendors with categories, we need to do client-side filtering
    // because Firestore doesn't support array-contains-any with other compound queries
    Query query = _firestore
        .collection('markets')
        .where('isLookingForVendors', isEqualTo: true)
        .where('isActive', isEqualTo: true);

    if (afterDate != null) {
      query = query.where('eventDate', isGreaterThan: Timestamp.fromDate(afterDate));
    } else {
      query = query.where('eventDate', isGreaterThan: Timestamp.now());
    }

    query = query.orderBy('eventDate').limit(limit * 2); // Get extra to filter client-side

    return query.snapshots().map((snapshot) {
      final markets = snapshot.docs
          .map((doc) => Market.fromFirestore(doc))
          .where((market) {
            // Include markets with no targeting (open to all)
            if (market.targetCategories == null || market.targetCategories!.isEmpty) {
              return true;
            }

            // Include markets that target any of the vendor's categories
            return market.targetCategories!.any((targetCategory) =>
                vendorCategories.contains(targetCategory));
          })
          .where((market) =>
              !market.isApplicationDeadlinePassed &&
              market.hasAvailableSpots)
          .take(limit)
          .toList();

      // Sort by relevance (markets targeting specific categories first)
      markets.sort((a, b) {
        final aHasTargeting = a.targetCategories?.isNotEmpty ?? false;
        final bHasTargeting = b.targetCategories?.isNotEmpty ?? false;

        if (aHasTargeting && !bHasTargeting) return -1;
        if (!aHasTargeting && bHasTargeting) return 1;

        // If both have targeting, sort by how many matching categories
        if (aHasTargeting && bHasTargeting) {
          final aMatches = a.targetCategories!
              .where((cat) => vendorCategories.contains(cat))
              .length;
          final bMatches = b.targetCategories!
              .where((cat) => vendorCategories.contains(cat))
              .length;

          if (aMatches != bMatches) {
            return bMatches.compareTo(aMatches); // More matches first
          }
        }

        // Finally sort by date
        return a.applicationDeadline?.compareTo(b.applicationDeadline ?? DateTime.now()) ?? 0;
      });

      return markets;
    });
  }

  /// Get recruitment analytics for a market with financial tracking
  static Future<Map<String, dynamic>> getRecruitmentAnalytics(
    String marketId,
  ) async {
    // Get market data
    final marketDoc = await _firestore.collection('markets').doc(marketId).get();
    if (!marketDoc.exists) {
      throw Exception('Market not found');
    }

    final marketData = marketDoc.data()!;
    final applicationFee = (marketData['applicationFee'] as num?)?.toDouble() ?? 0.0;
    final dailyBoothFee = (marketData['dailyBoothFee'] as num?)?.toDouble() ?? 0.0;

    // Get application count
    final applicationsSnapshot = await _firestore
        .collection('vendor_applications')
        .where('marketId', isEqualTo: marketId)
        .get();

    final totalApplications = applicationsSnapshot.docs.length;
    final pendingApplications = applicationsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'pending')
        .length;
    final approvedApplications = applicationsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'approved')
        .length;
    final confirmedApplications = applicationsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'confirmed')
        .length;
    final deniedApplications = applicationsSnapshot.docs
        .where((doc) => doc.data()['status'] == 'denied')
        .length;

    // Financial calculations
    final totalApplicationFeeRevenue = confirmedApplications * applicationFee;
    final totalBoothFeeRevenue = confirmedApplications * dailyBoothFee;
    final totalRevenue = totalApplicationFeeRevenue + totalBoothFeeRevenue;

    // Potential revenue from pending + approved applications
    final potentialApplications = pendingApplications + approvedApplications;
    final potentialRevenue = potentialApplications * (applicationFee + dailyBoothFee);

    return {
      // Spot metrics
      'totalSpots': marketData['vendorSpotsTotal'] ?? 0,
      'availableSpots': marketData['vendorSpotsAvailable'] ?? 0,
      'fillRate': marketData['vendorSpotsTotal'] != null && marketData['vendorSpotsTotal'] > 0
          ? ((marketData['vendorSpotsTotal'] - (marketData['vendorSpotsAvailable'] ?? 0)) /
             marketData['vendorSpotsTotal'] * 100).toStringAsFixed(1)
          : '0.0',

      // Application metrics
      'totalApplications': totalApplications,
      'pendingApplications': pendingApplications,
      'approvedApplications': approvedApplications,
      'confirmedApplications': confirmedApplications,
      'deniedApplications': deniedApplications,
      'conversionRate': totalApplications > 0
          ? (confirmedApplications / totalApplications * 100).toStringAsFixed(1)
          : '0.0',

      // Financial metrics
      'applicationFee': applicationFee,
      'dailyBoothFee': dailyBoothFee,
      'totalApplicationFeeRevenue': totalApplicationFeeRevenue,
      'totalBoothFeeRevenue': totalBoothFeeRevenue,
      'totalRevenue': totalRevenue,
      'potentialRevenue': potentialRevenue,
      'projectedTotalRevenue': totalRevenue + potentialRevenue,

      // Revenue breakdown
      'revenueBreakdown': {
        'confirmed': totalRevenue,
        'potential': potentialRevenue,
        'applicationFees': totalApplicationFeeRevenue,
        'boothFees': totalBoothFeeRevenue,
      },
    };
  }
}

