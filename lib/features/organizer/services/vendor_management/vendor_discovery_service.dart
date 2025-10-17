import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../core/base_service.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/services/user/user_profile_service.dart';
import '../../models/organizer_vendor_post.dart';
import '../../models/organizer_vendor_post_result.dart';
import '../../../market/models/market.dart';
import 'vendor_post_service.dart';

/// Unified vendor discovery service for organizers
/// Combines vendor discovery and vendor post discovery functionality
class VendorDiscoveryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Discover qualified vendors for organizer's markets
  static Future<List<VendorDiscoveryResult>> discoverVendorsForOrganizer(
    String organizerId, {
    List<String>? categories,
    String? location,
    List<String>? experienceLevels,
    double? minRating,
    List<String>? availableMarketIds,
    String? searchQuery,
    bool onlyVerified = true,
    bool onlyAvailable = false,
    int limit = 20,
  }) async {
    return await BaseOrganizerService.executeQuery(() async {
      // Get organizer's markets to understand their categories and requirements
      final organizerMarkets = await getOrganizerMarkets(organizerId);

      // Use base service method for vendor query
      Query vendorQuery = BaseOrganizerService.getVendorsQuery(
        verified: onlyVerified,
        categories: categories,
        location: location,
      );

      final snapshot = await vendorQuery.limit(200).get(); // Get larger pool for filtering

      final results = <VendorDiscoveryResult>[];
      
      for (final doc in snapshot.docs) {
        try {
          final vendorProfile = UserProfile.fromFirestore(doc);
          
          // Skip if vendor has already been invited recently
          if (await BaseOrganizerService.hasRecentInteraction(organizerId, vendorProfile.userId)) {
            continue;
          }

          final result = await _analyzeVendorForOrganizer(
            vendorProfile,
            organizerMarkets,
            organizerId: organizerId,
            categories: categories,
            location: location,
            experienceLevels: experienceLevels,
            minRating: minRating,
            searchQuery: searchQuery,
            onlyAvailable: onlyAvailable,
          );

          if (result != null && results.length < limit) {
            results.add(result);
          }
        } catch (e) {
          // Skip vendor if there's an error processing
          continue;
        }
      }

      // Sort by match score  
      results.sort((a, b) => b.matchScore.compareTo(a.matchScore));
      
      return results.take(limit).toList();
    }, errorContext: 'discoverVendorsForOrganizer');
  }

  /// Discover organizer vendor posts relevant to a specific vendor
  static Future<List<OrganizerVendorPostResult>> discoverVendorPosts({
    String? vendorId,
    List<String>? categories,
    double? latitude,
    double? longitude,
    double maxDistance = 50.0,
    String? searchQuery,
    bool onlyActivelyRecruiting = false,
    int limit = 20,
  }) async {
    return await BaseOrganizerService.executeQuery(() async {
      // Get vendor profile if vendorId provided
      UserProfile? vendorProfile;
      if (vendorId != null) {
        vendorProfile = await UserProfileService().getUserProfile(vendorId);
        
        // Use vendor's categories if not provided
        categories ??= vendorProfile?.categories;
      }

      // Get vendor's existing responses to avoid duplicates
      final respondedPostIds = await _getVendorRespondedPosts(vendorId);

      // Search for relevant vendor posts
      final posts = await OrganizerVendorPostService.searchVendorPosts(
        categories: categories,
        searchQuery: searchQuery,
        maxDistance: maxDistance,
        latitude: latitude,
        longitude: longitude,
        onlyActive: true,
        limit: limit * 2, // Get more to filter later
      );

      // Filter out posts vendor has already responded to
      final filteredPosts = posts.where((post) => 
        !respondedPostIds.contains(post.id)
      ).toList();

      // Calculate match scores and create results
      final results = <OrganizerVendorPostResult>[];
      
      for (final post in filteredPosts) {
        final score = _calculatePostMatchScore(
          post: post,
          vendorProfile: vendorProfile,
          vendorLat: latitude,
          vendorLon: longitude,
        );
        
        // Get organizer info
        final organizerProfile = await _getOrganizerProfile(post.organizerId);
        
        // Need to get market for the post
        final marketDoc = await _firestore
            .collection('markets')
            .doc(post.marketId)
            .get();
        
        if (!marketDoc.exists) continue;
        
        final market = Market.fromFirestore(marketDoc);
        
        results.add(OrganizerVendorPostResult(
          post: post,
          market: market,
          relevanceScore: score,
          distanceFromVendor: latitude != null && longitude != null ? 
            _calculateDistance(latitude, longitude, market.latitude ?? 0, market.longitude ?? 0) : null,
          matchReasons: ['Matching category', 'Near your location'],
          opportunities: ['High demand', 'Regular event'],
          isPremiumOnly: false,
        ));
      }

      // Sort by relevance score  
      results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
      
      return results.take(limit).toList();
    }, errorContext: 'discoverVendorPosts');
  }

  /// Get organizer markets
  static Future<List<Market>> getOrganizerMarkets(String organizerId) async {
    try {
      final marketsSnapshot = await BaseOrganizerService.getOrganizerMarketsQuery(organizerId).get();
      
      return marketsSnapshot.docs
          .map((doc) => Market.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching organizer markets: $e');
      return [];
    }
  }

  /// Get vendor responded posts
  static Future<Set<String>> _getVendorRespondedPosts(String? vendorId) async {
    if (vendorId == null) return {};
    
    try {
      final snapshot = await _firestore
          .collection('vendor_post_responses')
          .where('vendorId', isEqualTo: vendorId)
          .get();
      
      return snapshot.docs.map((doc) => doc.data()['postId'] as String).toSet();
    } catch (e) {
      print('Error getting vendor responses: $e');
      return {};
    }
  }

  /// Analyze vendor for organizer
  static Future<VendorDiscoveryResult?> _analyzeVendorForOrganizer(
    UserProfile vendor,
    List<Market> organizerMarkets,
    {
      required String organizerId,
      List<String>? categories,
      String? location,
      List<String>? experienceLevels,
      double? minRating,
      String? searchQuery,
      bool onlyAvailable = false,
    }
  ) async {
    // Calculate match score based on various factors
    double matchScore = 0;
    final matchReasons = <String>[];
    
    // Category matching
    if (categories != null && categories.isNotEmpty) {
      final categoryMatch = vendor.categories
          ?.any((cat) => categories.contains(cat)) ?? false;
      if (categoryMatch) {
        matchScore += 30;
        matchReasons.add('Matching category');
      }
    }
    
    // Location matching - fetch vendor's recent posts to get location data
    if (location != null) {
      try {
        // Try to get vendor's recent posts to extract city (only public posts)
        final vendorPostsQuery = await _firestore
            .collection('vendor_posts')
            .where('vendorId', isEqualTo: vendor.userId)
            .where('isActive', isEqualTo: true)
            .where('isPrivate', isEqualTo: false) // Only show public posts
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        if (vendorPostsQuery.docs.isNotEmpty) {
          final vendorPostData = vendorPostsQuery.docs.first.data();
          // Check if LocationData has city
          if (vendorPostData['locationData'] != null &&
              vendorPostData['locationData']['city'] != null &&
              vendorPostData['locationData']['city'] == location) {
            matchScore += 20;
            matchReasons.add('Same location');
          }
        } else {
          // Fallback: Check if vendor is a ManagedVendor with city data
          final managedVendorQuery = await _firestore
              .collection('managed_vendors')
              .where('userProfileId', isEqualTo: vendor.userId)
              .limit(1)
              .get();

          if (managedVendorQuery.docs.isNotEmpty) {
            final managedVendorData = managedVendorQuery.docs.first.data();
            if (managedVendorData['city'] == location) {
              matchScore += 20;
              matchReasons.add('Same location');
            }
          }
        }
      } catch (e) {
        // Location matching failed, continue without it
      }
    }

    // Rating check - fetch from feedback collection
    double vendorRating = 0;
    try {
      final feedbackQuery = await _firestore
          .collection('feedback')
          .where('vendorId', isEqualTo: vendor.userId)
          .get();

      if (feedbackQuery.docs.isNotEmpty) {
        double totalRating = 0;
        int count = 0;
        for (final doc in feedbackQuery.docs) {
          final rating = doc.data()['overallRating'];
          if (rating != null) {
            totalRating += (rating as num).toDouble();
            count++;
          }
        }
        if (count > 0) {
          vendorRating = totalRating / count;
        }
      }
    } catch (e) {
      // Rating fetch failed, default to 0
      vendorRating = 0;
    }

    if (minRating != null && vendorRating < minRating) {
      return null; // Skip vendors below minimum rating
    }
    if (vendorRating > 4) {
      matchScore += vendorRating * 5;
      matchReasons.add('High rating');
    }
    
    // Search query matching
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      if (vendor.businessName?.toLowerCase().contains(query) ?? false) {
        matchScore += 25;
        matchReasons.add('Name matches search');
      }
    }
    
    // Calculate distance to nearest market
    double? nearestMarketDistance;
    Market? nearestMarket;
    double? vendorLat;
    double? vendorLon;

    // Try to get vendor's location from recent posts (only public posts)
    try {
      final vendorPostsQuery = await _firestore
          .collection('vendor_posts')
          .where('vendorId', isEqualTo: vendor.userId)
          .where('isActive', isEqualTo: true)
          .where('isPrivate', isEqualTo: false) // Only show public posts
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (vendorPostsQuery.docs.isNotEmpty) {
        final postData = vendorPostsQuery.docs.first.data();
        vendorLat = postData['latitude']?.toDouble();
        vendorLon = postData['longitude']?.toDouble();
      }
    } catch (e) {
      // Failed to get location
    }

    for (final market in organizerMarkets) {
      if (market.latitude != null && market.longitude != null &&
          vendorLat != null && vendorLon != null) {
        final distance = _calculateDistance(
          vendorLat,
          vendorLon,
          market.latitude,
          market.longitude,
        );

        if (nearestMarketDistance == null || distance < nearestMarketDistance) {
          nearestMarketDistance = distance;
          nearestMarket = market;
        }
      }
    }
    
    // Proximity bonus
    if (nearestMarketDistance != null && nearestMarketDistance < 10) {
      matchScore += (10 - nearestMarketDistance) * 2;
      matchReasons.add('Near market');
    }
    
    // Skip if match score is too low
    if (matchScore < 10) return null;
    
    return VendorDiscoveryResult(
      vendor: vendor,
      matchScore: matchScore,
      matchReasons: matchReasons,
      distanceToNearestMarket: nearestMarketDistance,
      nearestMarket: nearestMarket,
      hasBeenInvited: false,
      lastInteraction: null,
    );
  }

  /// Calculate post match score
  static double _calculatePostMatchScore({
    required OrganizerVendorPost post,
    UserProfile? vendorProfile,
    double? vendorLat,
    double? vendorLon,
  }) {
    double score = 0;
    
    // Category matching
    if (vendorProfile?.categories != null && post.categories != null) {
      final matchingCategories = vendorProfile!.categories!
          .where((cat) => post.categories!.contains(cat))
          .length;
      score += matchingCategories * 20;
    }
    
    // Location proximity - posts don't have latitude/longitude in current model
    // This would need to be fetched from the associated market
    // TODO: Implement location matching if needed

    // Check if post has urgent requirements based on deadline
    final deadline = post.requirements.applicationDeadline;
    if (deadline != null && deadline.difference(DateTime.now()).inDays < 7) {
      score += 15; // Urgency bonus for posts expiring soon
    }

    // Compensation bonus based on booth fee
    if (post.requirements.boothFee != null && post.requirements.boothFee! > 0) {
      score += 10;
    }
    
    return score;
  }

  /// Calculate distance between two points
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 3959; // in miles
    final latDiff = _toRadians(lat2 - lat1);
    final lonDiff = _toRadians(lon2 - lon1);
    
    final a = math.sin(latDiff / 2) * math.sin(latDiff / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(lonDiff / 2) * math.sin(lonDiff / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  static double _toRadians(double degree) {
    return degree * math.pi / 180;
  }

  /// Get organizer profile
  static Future<Map<String, dynamic>?> _getOrganizerProfile(String organizerId) async {
    try {
      final doc = await _firestore
          .collection('user_profiles')
          .doc(organizerId)
          .get();
      
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('Error fetching organizer profile: $e');
      return null;
    }
  }
}

/// Vendor discovery result model
class VendorDiscoveryResult {
  final UserProfile vendor;
  final double matchScore;
  final List<String> matchReasons;
  final double? distanceToNearestMarket;
  final Market? nearestMarket;
  final bool hasBeenInvited;
  final DateTime? lastInteraction;

  VendorDiscoveryResult({
    required this.vendor,
    required this.matchScore,
    required this.matchReasons,
    this.distanceToNearestMarket,
    this.nearestMarket,
    required this.hasBeenInvited,
    this.lastInteraction,
  });
  
  // Convenience getters that delegate to vendor profile
  String get experienceLevel => 'Experienced'; // TODO: Calculate from vendor history
  double get averageRating => 4.5; // TODO: Get from ratings
  int get totalMarkets => 5; // TODO: Get from vendor history
  List<String>? get categories => vendor.categories;
  List<String> get insights => matchReasons; // Use match reasons as insights
}