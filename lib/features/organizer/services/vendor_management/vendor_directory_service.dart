import 'package:cloud_firestore/cloud_firestore.dart';

class VendorDirectoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Search vendors with filters
  static Future<List<Map<String, dynamic>>> searchVendors({
    String? searchQuery,
    List<String>? categories,
    String? location,
    String? experienceLevel,
    bool onlyAvailable = false,
    int limit = 50,
  }) async {
    try {

      // Start with base query for vendor profiles
      Query query = _firestore.collection('user_profiles')
          .where('userType', isEqualTo: 'vendor')
          .where('profileSubmitted', isEqualTo: true);

      // Add verification filter (only show verified vendors)
      query = query.where('verificationStatus', isEqualTo: 'approved');

      final snapshot = await query.limit(limit * 2).get(); // Get extra for filtering

      List<Map<String, dynamic>> results = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        bool matches = true;

        // Apply search query filter
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final searchLower = searchQuery.toLowerCase();
          final businessName = (data['businessName'] ?? '').toString().toLowerCase();
          final displayName = (data['displayName'] ?? '').toString().toLowerCase();
          final bio = (data['bio'] ?? '').toString().toLowerCase();
          final specificProducts = (data['specificProducts'] ?? '').toString().toLowerCase();
          
          matches = businessName.contains(searchLower) ||
                   displayName.contains(searchLower) ||
                   bio.contains(searchLower) ||
                   specificProducts.contains(searchLower);
        }

        // Apply category filter
        if (matches && categories != null && categories.isNotEmpty) {
          final vendorCategories = List<String>.from(data['categories'] ?? []);
          matches = categories.any((cat) => vendorCategories.contains(cat));
        }

        // Apply location filter (basic string matching)
        if (matches && location != null && location.isNotEmpty) {
          // Get vendor's recent posts to find locations they operate in
          final postsSnapshot = await _firestore.collection('vendor_posts')
              .where('vendorId', isEqualTo: doc.id)
              .limit(5)
              .get();
          
          if (postsSnapshot.docs.isNotEmpty) {
            final locations = postsSnapshot.docs
                .map((post) => (post.data()['location'] ?? '').toString().toLowerCase())
                .toList();
            matches = locations.any((loc) => loc.contains(location.toLowerCase()));
          }
        }

        if (matches) {
          // Get vendor stats
          final stats = await _getVendorStats(doc.id);
          
          results.add({
            'vendorId': doc.id,
            'businessName': data['businessName'] ?? data['displayName'] ?? 'Unknown Vendor',
            'displayName': data['displayName'],
            'email': data['email'],
            'phoneNumber': data['phoneNumber'],
            'instagramHandle': data['instagramHandle'],
            'website': data['website'],
            'bio': data['bio'],
            'categories': List<String>.from(data['categories'] ?? []),
            'specificProducts': data['specificProducts'],
            'featuredItems': data['featuredItems'],
            'verificationStatus': data['verificationStatus'],
            'profileSubmitted': data['profileSubmitted'] ?? false,
            'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
            ...stats,
          });

          if (results.length >= limit) break;
        }
      }

      return results;

    } catch (e) {
      return [];
    }
  }

  /// Get vendors by specific categories
  static Future<List<Map<String, dynamic>>> getVendorsByCategory(
    List<String> categories, {
    int limit = 50,
  }) async {
    try {

      final snapshot = await _firestore.collection('user_profiles')
          .where('userType', isEqualTo: 'vendor')
          .where('profileSubmitted', isEqualTo: true)
          .where('verificationStatus', isEqualTo: 'approved')
          .where('categories', arrayContainsAny: categories)
          .limit(limit)
          .get();

      List<Map<String, dynamic>> results = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final stats = await _getVendorStats(doc.id);
        
        results.add({
          'vendorId': doc.id,
          'businessName': data['businessName'] ?? data['displayName'] ?? 'Unknown Vendor',
          'displayName': data['displayName'],
          'email': data['email'],
          'phoneNumber': data['phoneNumber'],
          'instagramHandle': data['instagramHandle'],
          'website': data['website'],
          'bio': data['bio'],
          'categories': List<String>.from(data['categories'] ?? []),
          'specificProducts': data['specificProducts'],
          'featuredItems': data['featuredItems'],
          ...stats,
        });
      }

      return results;

    } catch (e) {
      return [];
    }
  }

  /// Get vendor details
  static Future<Map<String, dynamic>?> getVendorDetails(String vendorId) async {
    try {
      final doc = await _firestore.collection('user_profiles').doc(vendorId).get();
      
      if (!doc.exists) return null;

      final data = doc.data()!;
      final stats = await _getVendorStats(vendorId);

      return {
        'vendorId': vendorId,
        'businessName': data['businessName'] ?? data['displayName'] ?? 'Unknown Vendor',
        'displayName': data['displayName'],
        'email': data['email'],
        'phoneNumber': data['phoneNumber'],
        'instagramHandle': data['instagramHandle'],
        'website': data['website'],
        'bio': data['bio'],
        'categories': List<String>.from(data['categories'] ?? []),
        'specificProducts': data['specificProducts'],
        'featuredItems': data['featuredItems'],
        'ccEmails': List<String>.from(data['ccEmails'] ?? []),
        'verificationStatus': data['verificationStatus'],
        'profileSubmitted': data['profileSubmitted'] ?? false,
        'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
        'updatedAt': (data['updatedAt'] as Timestamp?)?.toDate(),
        ...stats,
      };

    } catch (e) {
      return null;
    }
  }

  /// Get vendor statistics
  static Future<Map<String, dynamic>> _getVendorStats(String vendorId) async {
    try {
      // Get active posts count
      final postsSnapshot = await _firestore.collection('vendor_posts')
          .where('vendorId', isEqualTo: vendorId)
          .where('isActive', isEqualTo: true)
          .get();

      // Get markets they've participated in
      final marketsSnapshot = await _firestore.collection('vendor_applications')
          .where('vendorId', isEqualTo: vendorId)
          .where('status', isEqualTo: 'accepted')
          .get();

      // Get recent activity (last post date)
      final recentPostSnapshot = await _firestore.collection('vendor_posts')
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      DateTime? lastActiveDate;
      if (recentPostSnapshot.docs.isNotEmpty) {
        lastActiveDate = (recentPostSnapshot.docs.first.data()['createdAt'] as Timestamp?)?.toDate();
      }

      return {
        'activePostsCount': postsSnapshot.docs.length,
        'marketsParticipated': marketsSnapshot.docs.length,
        'lastActiveDate': lastActiveDate,
        'experienceLevel': _calculateExperienceLevel(marketsSnapshot.docs.length),
      };

    } catch (e) {
      return {
        'activePostsCount': 0,
        'marketsParticipated': 0,
        'lastActiveDate': null,
        'experienceLevel': 'Beginner',
      };
    }
  }

  /// Calculate experience level based on markets participated
  static String _calculateExperienceLevel(int marketsCount) {
    if (marketsCount >= 20) return 'Expert';
    if (marketsCount >= 10) return 'Experienced';
    if (marketsCount >= 5) return 'Intermediate';
    return 'Beginner';
  }

  /// Get popular categories
  static Future<List<String>> getPopularCategories({int limit = 10}) async {
    try {
      final snapshot = await _firestore.collection('user_profiles')
          .where('userType', isEqualTo: 'vendor')
          .where('profileSubmitted', isEqualTo: true)
          .where('verificationStatus', isEqualTo: 'approved')
          .get();

      Map<String, int> categoryCounts = {};

      for (final doc in snapshot.docs) {
        final categories = List<String>.from(doc.data()['categories'] ?? []);
        for (final category in categories) {
          categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
        }
      }

      // Sort by count and return top categories
      final sortedCategories = categoryCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedCategories
          .take(limit)
          .map((entry) => entry.key)
          .toList();

    } catch (e) {
      return [];
    }
  }

  /// Track vendor view (for analytics)
  static Future<void> trackVendorView(String organizerId, String vendorId) async {
    try {
      await _firestore.collection('vendor_directory_analytics').add({
        'organizerId': organizerId,
        'vendorId': vendorId,
        'action': 'view',
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
    }
  }

  /// Track vendor contact (for analytics)
  static Future<void> trackVendorContact(
    String organizerId,
    String vendorId,
    String contactMethod,
  ) async {
    try {
      await _firestore.collection('vendor_directory_analytics').add({
        'organizerId': organizerId,
        'vendorId': vendorId,
        'action': 'contact',
        'contactMethod': contactMethod,
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
    }
  }
}