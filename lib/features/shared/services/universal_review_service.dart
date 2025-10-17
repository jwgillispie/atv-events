import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/universal_review.dart';
import '../models/user_profile.dart';

/// Service for managing universal reviews across all entity types
class UniversalReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _reviewsCollection = 'universal_reviews';
  static const String _reviewStatsCollection = 'review_stats';

  /// Submit a new review
  Future<String> submitReview({
    required String reviewedId,
    required String reviewedName,
    required String reviewedType,
    String? reviewedBusinessName,
    required double overallRating,
    Map<String, double>? aspectRatings,
    List<String>? tags,
    String? reviewText,
    List<File>? photoFiles,
    bool isAnonymous = false,
    String? eventId,
    String? eventName,
    DateTime? eventDate,
    String? verificationMethod,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user profile
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) throw Exception('User profile not found');

      final userProfile = UserProfile.fromFirestore(userDoc);

      // Check if user can review this entity
      final canReview = await canUserReview(
        userId: user.uid,
        entityId: reviewedId,
        entityType: reviewedType,
      );

      if (!canReview) {
        throw Exception('You cannot review this entity at this time');
      }

      // Upload photos if provided
      List<String> photoUrls = [];
      if (photoFiles != null && photoFiles.isNotEmpty) {
        photoUrls = await _uploadReviewPhotos(
          reviewId: '', // Will be updated after creation
          photos: photoFiles,
        );
      }

      // Determine reviewer type based on user profile
      String reviewerType = _getReviewerType(userProfile);

      // Create review document
      final review = UniversalReview(
        id: '', // Will be set by Firestore
        reviewerId: user.uid,
        reviewerName: isAnonymous ? 'Anonymous' : (userProfile.displayName ?? 'User'),
        reviewerType: reviewerType,
        reviewerBusinessName: isAnonymous ? null : userProfile.businessName,
        reviewerPhotoUrl: null, // Profile photos not stored in UserProfile
        reviewedId: reviewedId,
        reviewedName: reviewedName,
        reviewedType: reviewedType,
        reviewedBusinessName: reviewedBusinessName,
        eventId: eventId,
        eventName: eventName,
        eventDate: eventDate ?? DateTime.now(),
        overallRating: overallRating,
        reviewText: reviewText,
        photos: photoUrls,
        aspectRatings: aspectRatings ?? {},
        tags: tags ?? [],
        isVerified: verificationMethod != null,
        verificationMethod: verificationMethod,
        isAnonymous: isAnonymous,
        createdAt: DateTime.now(),
      );

      // Add to Firestore
      final docRef = await _firestore
          .collection(_reviewsCollection)
          .add(review.toFirestore());

      // Update photo URLs with actual review ID
      if (photoUrls.isNotEmpty) {
        await docRef.update({'photos': photoUrls});
      }

      // Update review stats for the entity
      await _updateReviewStats(reviewedId, reviewedType);

      // Award bonus points for first review if applicable
      await _awardBonusPoints(user.uid, reviewedId, reviewedType);

      // Send notification to reviewed entity
      await _sendReviewNotification(review);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to submit review: $e');
    }
  }

  /// Get reviews for a specific entity (alias for backwards compatibility)
  Future<List<UniversalReview>> getReviews({
    required String reviewedId,
    required String reviewedType,
    String? reviewerType,
    bool? verifiedOnly,
    bool? withPhotosOnly,
    int? minRating,
    int? maxRating,
    ReviewSortOption sortBy = ReviewSortOption.newest,
    int limit = 20,
    DocumentSnapshot? lastDocument,
    DateTime? startAfter,
  }) async {
    return getReviewsForEntity(
      entityId: reviewedId,
      entityType: reviewedType,
      reviewerType: reviewerType,
      verifiedOnly: verifiedOnly,
      withPhotosOnly: withPhotosOnly,
      minRating: minRating,
      maxRating: maxRating,
      sortBy: sortBy,
      limit: limit,
      lastDocument: lastDocument,
    );
  }

  /// Get reviews for a specific entity
  Future<List<UniversalReview>> getReviewsForEntity({
    required String entityId,
    required String entityType,
    String? reviewerType,
    bool? verifiedOnly,
    bool? withPhotosOnly,
    int? minRating,
    int? maxRating,
    ReviewSortOption sortBy = ReviewSortOption.newest,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection(_reviewsCollection)
          .where('reviewedId', isEqualTo: entityId)
          .where('reviewedType', isEqualTo: entityType);

      // Apply filters
      if (reviewerType != null) {
        query = query.where('reviewerType', isEqualTo: reviewerType);
      }

      if (verifiedOnly == true) {
        query = query.where('isVerified', isEqualTo: true);
      }

      if (withPhotosOnly == true) {
        query = query.where('photos', isNotEqualTo: []);
      }

      if (minRating != null) {
        query = query.where('overallRating', isGreaterThanOrEqualTo: minRating);
      }

      if (maxRating != null) {
        query = query.where('overallRating', isLessThanOrEqualTo: maxRating);
      }

      // Apply sorting
      switch (sortBy) {
        case ReviewSortOption.newest:
          query = query.orderBy('createdAt', descending: true);
          break;
        case ReviewSortOption.oldest:
          query = query.orderBy('createdAt');
          break;
        case ReviewSortOption.highestRated:
          query = query.orderBy('overallRating', descending: true)
                      .orderBy('createdAt', descending: true);
          break;
        case ReviewSortOption.lowestRated:
          query = query.orderBy('overallRating')
                      .orderBy('createdAt', descending: true);
          break;
        case ReviewSortOption.mostHelpful:
          query = query.orderBy('helpfulCount', descending: true)
                      .orderBy('createdAt', descending: true);
          break;
      }

      // Apply pagination
      query = query.limit(limit);
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => UniversalReview.fromFirestore(doc))
          .toList();
    } catch (e) {
      // Log Firestore index errors explicitly
      final errorString = e.toString();
      if (errorString.contains('index') || errorString.contains('Index')) {
        print('❌ FIRESTORE INDEX ERROR in getReviewsForEntity:');
        print('   Entity ID: $entityId');
        print('   Entity Type: $entityType');
        print('   Reviewer Type: $reviewerType');
        print('   Verified Only: $verifiedOnly');
        print('   With Photos Only: $withPhotosOnly');
        print('   Min Rating: $minRating');
        print('   Max Rating: $maxRating');
        print('   Sort By: $sortBy');
        print('   Error: $errorString');

        // Extract index creation URL if present
        final urlPattern = RegExp(r'https://console\.firebase\.google\.com/[^\s]+');
        final match = urlPattern.firstMatch(errorString);
        if (match != null) {
          print('   📍 Create index at: ${match.group(0)}');
        }
      }
      throw Exception('Failed to fetch reviews: $e');
    }
  }

  /// Get review stats for multiple products at once (batch operation)
  Future<Map<String, ReviewStats>> getProductReviewStatsBatch(
    List<String> productIds,
  ) async {
    try {
      final Map<String, ReviewStats> statsMap = {};

      // Batch fetch from review_stats collection
      final List<Future<DocumentSnapshot>> futures = productIds.map((id) {
        return _firestore
            .collection(_reviewStatsCollection)
            .doc('product_$id')
            .get();
      }).toList();

      final snapshots = await Future.wait(futures);

      for (int i = 0; i < productIds.length; i++) {
        final productId = productIds[i];
        final statsDoc = snapshots[i];

        if (statsDoc.exists) {
          final data = statsDoc.data() as Map<String, dynamic>;
          statsMap[productId] = ReviewStats(
            entityId: productId,
            entityType: 'product',
            totalReviews: data['totalReviews'] ?? 0,
            averageRating: (data['averageRating'] ?? 0).toDouble(),
            aspectAverages: Map<String, double>.from(data['aspectAverages'] ?? {}),
            ratingDistribution: Map<int, int>.from(data['ratingDistribution'] ?? {}),
            reviewerTypeBreakdown: Map<String, int>.from(data['reviewerTypeBreakdown'] ?? {}),
            topTags: List<String>.from(data['topTags'] ?? []),
            verifiedCount: data['verifiedCount'] ?? 0,
            photoCount: data['photoCount'] ?? 0,
            responseRate: (data['responseRate'] ?? 0).toDouble(),
            averageResponseTime: data['averageResponseTime'] != null
                ? Duration(seconds: data['averageResponseTime'])
                : null,
          );
        }
      }

      return statsMap;
    } catch (e) {
      print('Error fetching product review stats batch: $e');
      return {};
    }
  }

  /// Get aggregated review statistics for an entity
  Future<ReviewStats> getReviewStats({
    required String entityId,
    required String entityType,
  }) async {
    try {
      // Try to get cached stats first
      final statsDoc = await _firestore
          .collection(_reviewStatsCollection)
          .doc('${entityType}_$entityId')
          .get();

      if (statsDoc.exists) {
        final data = statsDoc.data()!;
        return ReviewStats(
          entityId: entityId,
          entityType: entityType,
          totalReviews: data['totalReviews'] ?? 0,
          averageRating: (data['averageRating'] ?? 0).toDouble(),
          aspectAverages: Map<String, double>.from(data['aspectAverages'] ?? {}),
          ratingDistribution: Map<int, int>.from(data['ratingDistribution'] ?? {}),
          reviewerTypeBreakdown: Map<String, int>.from(data['reviewerTypeBreakdown'] ?? {}),
          topTags: List<String>.from(data['topTags'] ?? []),
          verifiedCount: data['verifiedCount'] ?? 0,
          photoCount: data['photoCount'] ?? 0,
          responseRate: (data['responseRate'] ?? 0).toDouble(),
          averageResponseTime: data['averageResponseTime'] != null
              ? Duration(seconds: data['averageResponseTime'])
              : null,
        );
      }

      // If no cached stats, calculate from reviews
      final reviews = await getReviewsForEntity(
        entityId: entityId,
        entityType: entityType,
        limit: 1000, // Get all reviews for stats calculation
      );

      return ReviewStats.fromReviews(entityId, entityType, reviews);
    } catch (e) {
      // Return empty stats on error
      return ReviewStats(
        entityId: entityId,
        entityType: entityType,
        totalReviews: 0,
        averageRating: 0,
        aspectAverages: {},
        ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        reviewerTypeBreakdown: {},
        topTags: [],
        verifiedCount: 0,
        photoCount: 0,
        responseRate: 0,
      );
    }
  }

  /// Check if a user has already reviewed an entity
  Future<bool> hasUserReviewed({
    required String reviewerId,
    required String reviewedId,
    required String reviewedType,
  }) async {
    try {
      final existingReview = await _firestore
          .collection(_reviewsCollection)
          .where('reviewerId', isEqualTo: reviewerId)
          .where('reviewedId', isEqualTo: reviewedId)
          .where('reviewedType', isEqualTo: reviewedType)
          .limit(1)
          .get();

      return existingReview.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Check if a user can review an entity
  Future<bool> canUserReview({
    required String userId,
    required String entityId,
    required String entityType,
  }) async {
    try {
      // Check if user has already reviewed this entity
      final existingReview = await _firestore
          .collection(_reviewsCollection)
          .where('reviewerId', isEqualTo: userId)
          .where('reviewedId', isEqualTo: entityId)
          .where('reviewedType', isEqualTo: entityType)
          .limit(1)
          .get();

      if (existingReview.docs.isNotEmpty) {
        // Check if enough time has passed for re-review (30 days)
        final lastReview = UniversalReview.fromFirestore(existingReview.docs.first);
        final daysSinceLastReview = DateTime.now().difference(lastReview.createdAt).inDays;
        if (daysSinceLastReview < 30) {
          return false;
        }
      }

      // Get user profile to determine user type
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      final userType = userData['userType'] as String?;

      // Implement ManagedVendor relationship-based eligibility
      if (entityType == 'market') {
        return await _canReviewMarket(userId, entityId, userType);
      } else if (entityType == 'vendor') {
        return await _canReviewVendor(userId, entityId, userType);
      }

      // For other entity types (products, etc.), keep existing QR code requirements
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if user can review a market
  Future<bool> _canReviewMarket(String userId, String marketId, String? userType) async {
    try {
      // Get market info
      final marketDoc = await _firestore
          .collection('markets')
          .doc(marketId)
          .get();

      if (!marketDoc.exists) return false;

      final marketData = marketDoc.data() as Map<String, dynamic>;
      final eventDate = (marketData['eventDate'] as Timestamp?)?.toDate();
      final organizerId = marketData['organizerId'] as String?;

      // Market event must have passed
      if (eventDate != null && DateTime.now().isBefore(eventDate)) {
        return false;
      }

      // Vendors can only review markets where they have a ManagedVendor record
      if (userType == 'vendor') {
        final managedVendorQuery = await _firestore
            .collection('managed_vendors')
            .where('marketId', isEqualTo: marketId)
            .where('userProfileId', isEqualTo: userId)
            .limit(1)
            .get();

        return managedVendorQuery.docs.isNotEmpty;
      }

      // Market organizers can only review markets they organize (but this is rare)
      if (userType == 'market_organizer') {
        return organizerId == userId;
      }

      // Shoppers can review markets (would need attendance tracking for full implementation)
      // For now, allow all shoppers to review past markets
      return userType == 'shopper';
    } catch (e) {
      return false;
    }
  }

  /// Check if user can review a vendor
  Future<bool> _canReviewVendor(String userId, String vendorId, String? userType) async {
    try {
      // Get vendor info
      final vendorDoc = await _firestore
          .collection('managed_vendors')
          .doc(vendorId)
          .get();

      if (!vendorDoc.exists) return false;

      final vendorData = vendorDoc.data() as Map<String, dynamic>;
      final marketId = vendorData['marketId'] as String?;
      final vendorUserId = vendorData['userProfileId'] as String?;
      final organizerId = vendorData['organizerId'] as String?;

      if (marketId == null) return false;

      // Get market event date
      final marketDoc = await _firestore
          .collection('markets')
          .doc(marketId)
          .get();

      if (!marketDoc.exists) return false;

      final marketData = marketDoc.data() as Map<String, dynamic>;
      final eventDate = (marketData['eventDate'] as Timestamp?)?.toDate();

      // Market event must have passed
      if (eventDate != null && DateTime.now().isBefore(eventDate)) {
        return false;
      }

      // Market organizers can only review vendors they manage
      if (userType == 'market_organizer') {
        return organizerId == userId;
      }

      // Vendors cannot review themselves
      if (userType == 'vendor' && vendorUserId == userId) {
        return false;
      }

      // Vendors can review other vendors if they both participated in the same market
      if (userType == 'vendor') {
        final managedVendorQuery = await _firestore
            .collection('managed_vendors')
            .where('marketId', isEqualTo: marketId)
            .where('userProfileId', isEqualTo: userId)
            .limit(1)
            .get();

        return managedVendorQuery.docs.isNotEmpty;
      }

      // Shoppers can review vendors (would need QR code scanning for full implementation)
      // For now, allow all shoppers to review vendors from past markets
      return userType == 'shopper';
    } catch (e) {
      return false;
    }
  }

  /// Mark a review as helpful
  Future<void> markReviewHelpful({
    required String reviewId,
    required String userId,
  }) async {
    try {
      final reviewRef = _firestore
          .collection(_reviewsCollection)
          .doc(reviewId);

      await _firestore.runTransaction((transaction) async {
        final reviewDoc = await transaction.get(reviewRef);
        if (!reviewDoc.exists) {
          throw Exception('Review not found');
        }

        final review = UniversalReview.fromFirestore(reviewDoc);

        // Check if user has already marked as helpful
        if (review.helpfulVoters.contains(userId)) {
          return;
        }

        // Update helpful count and voters list
        transaction.update(reviewRef, {
          'helpfulCount': FieldValue.increment(1),
          'helpfulVoters': FieldValue.arrayUnion([userId]),
        });
      });
    } catch (e) {
      throw Exception('Failed to mark review as helpful: $e');
    }
  }

  /// Add a response to a review
  Future<void> respondToReview({
    required String reviewId,
    required String responseText,
    String? responderId,
    required String responderName,
  }) async {
    try {
      await _firestore
          .collection(_reviewsCollection)
          .doc(reviewId)
          .update({
        'responseText': responseText,
        'responseDate': Timestamp.now(),
        'responderId': responderId ?? _auth.currentUser?.uid,
        'responderName': responderName,
      });

      // Send notification to reviewer
      await _sendResponseNotification(reviewId, responderName);
    } catch (e) {
      throw Exception('Failed to respond to review: $e');
    }
  }

  /// Flag a review as inappropriate
  Future<void> flagReview({
    required String reviewId,
    required String reason,
    required String reporterId,
  }) async {
    try {
      await _firestore
          .collection(_reviewsCollection)
          .doc(reviewId)
          .update({
        'isFlagged': true,
        'flagReason': reason,
        'flaggedBy': reporterId,
        'flaggedAt': Timestamp.now(),
      });

      // Create a report document for admin review
      await _firestore.collection('review_reports').add({
        'reviewId': reviewId,
        'reason': reason,
        'reporterId': reporterId,
        'reportedAt': Timestamp.now(),
        'status': 'pending',
      });
    } catch (e) {
      throw Exception('Failed to flag review: $e');
    }
  }

  /// Get review streaks for gamification
  Future<Map<String, dynamic>> getReviewStreaks(String userId) async {
    try {
      final reviews = await _firestore
          .collection(_reviewsCollection)
          .where('reviewerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();

      if (reviews.docs.isEmpty) {
        return {
          'currentStreak': 0,
          'longestStreak': 0,
          'totalReviews': 0,
          'lastReviewDate': null,
        };
      }

      // Calculate streaks
      int currentStreak = 0;
      int longestStreak = 0;
      DateTime? lastDate;

      for (final doc in reviews.docs) {
        final review = UniversalReview.fromFirestore(doc);

        if (lastDate == null) {
          currentStreak = 1;
          longestStreak = 1;
        } else {
          final daysDiff = lastDate.difference(review.createdAt).inDays;
          if (daysDiff <= 7) { // Within a week
            currentStreak++;
            if (currentStreak > longestStreak) {
              longestStreak = currentStreak;
            }
          } else {
            currentStreak = 1;
          }
        }

        lastDate = review.createdAt;
      }

      return {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'totalReviews': reviews.docs.length,
        'lastReviewDate': lastDate,
      };
    } catch (e) {
      return {
        'currentStreak': 0,
        'longestStreak': 0,
        'totalReviews': 0,
        'lastReviewDate': null,
      };
    }
  }

  /// Get users with similar review patterns for discovery
  Future<List<String>> getSimilarReviewers({
    required String userId,
    int limit = 10,
  }) async {
    try {
      // Get user's recent reviews
      final userReviews = await _firestore
          .collection(_reviewsCollection)
          .where('reviewerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      if (userReviews.docs.isEmpty) return [];

      // Extract entities and ratings
      final reviewedEntities = <String>{};
      double avgRating = 0;

      for (final doc in userReviews.docs) {
        final review = UniversalReview.fromFirestore(doc);
        reviewedEntities.add(review.reviewedId);
        avgRating += review.overallRating;
      }
      avgRating /= userReviews.docs.length;

      // Find users who reviewed similar entities
      final similarUsers = <String, int>{};

      for (final entityId in reviewedEntities) {
        final entityReviews = await _firestore
            .collection(_reviewsCollection)
            .where('reviewedId', isEqualTo: entityId)
            .where('reviewerId', isNotEqualTo: userId)
            .limit(50)
            .get();

        for (final doc in entityReviews.docs) {
          final review = UniversalReview.fromFirestore(doc);
          // Count users with similar rating patterns
          if ((review.overallRating - avgRating).abs() < 1.0) {
            similarUsers[review.reviewerId] =
                (similarUsers[review.reviewerId] ?? 0) + 1;
          }
        }
      }

      // Sort by similarity score and return top matches
      final sortedUsers = similarUsers.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedUsers
          .take(limit)
          .map((entry) => entry.key)
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Private helper methods

  String _getReviewerType(UserProfile userProfile) {
    // Determine reviewer type based on user profile
    if (userProfile.userType == 'vendor') return 'vendor';
    if (userProfile.userType == 'market_organizer') return 'organizer';
    return 'shopper';
  }

  Future<List<String>> _uploadReviewPhotos({
    required String reviewId,
    required List<File> photos,
  }) async {
    final List<String> urls = [];

    for (int i = 0; i < photos.length && i < 3; i++) {
      final file = photos[i];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'review_${reviewId}_${timestamp}_$i.jpg';
      final ref = _storage.ref().child('review_photos/$fileName');

      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }

  Future<void> _updateReviewStats(String entityId, String entityType) async {
    try {
      // Get all reviews for this entity
      final reviews = await getReviewsForEntity(
        entityId: entityId,
        entityType: entityType,
        limit: 1000,
      );

      // Calculate stats
      final stats = ReviewStats.fromReviews(entityId, entityType, reviews);

      // Save to cache
      await _firestore
          .collection(_reviewStatsCollection)
          .doc('${entityType}_$entityId')
          .set({
        'entityId': entityId,
        'entityType': entityType,
        'totalReviews': stats.totalReviews,
        'averageRating': stats.averageRating,
        'aspectAverages': stats.aspectAverages,
        'ratingDistribution': stats.ratingDistribution,
        'reviewerTypeBreakdown': stats.reviewerTypeBreakdown,
        'topTags': stats.topTags,
        'verifiedCount': stats.verifiedCount,
        'photoCount': stats.photoCount,
        'responseRate': stats.responseRate,
        'averageResponseTime': stats.averageResponseTime?.inSeconds,
        'lastUpdated': Timestamp.now(),
      });

      // If it's a product review, also update the vendor_products document
      if (entityType == 'product') {
        await _updateProductDocument(entityId, stats);
      }
    } catch (e) {
      print('Failed to update review stats: $e');
    }
  }

  Future<void> _updateProductDocument(String productId, ReviewStats stats) async {
    try {
      // Update the vendor_products document with review stats
      await _firestore
          .collection('vendor_products')
          .doc(productId)
          .update({
        'productRating': stats.averageRating,
        'productReviewCount': stats.totalReviews,
        'lastReviewUpdate': Timestamp.now(),
      });
    } catch (e) {
      print('Failed to update product document with review stats: $e');
    }
  }

  Future<void> _awardBonusPoints(
    String userId,
    String entityId,
    String entityType,
  ) async {
    try {
      // Check if this is the first review for the entity
      final existingReviews = await _firestore
          .collection(_reviewsCollection)
          .where('reviewedId', isEqualTo: entityId)
          .where('reviewedType', isEqualTo: entityType)
          .limit(2)
          .get();

      if (existingReviews.docs.length == 1) {
        // This is the first review! Award bonus points
        await _firestore
            .collection('users')
            .doc(userId)
            .update({
          'points': FieldValue.increment(50),
          'firstReviewBonuses': FieldValue.arrayUnion([entityId]),
        });

        // Create achievement
        await _firestore.collection('achievements').add({
          'userId': userId,
          'type': 'first_review',
          'entityId': entityId,
          'entityType': entityType,
          'points': 50,
          'createdAt': Timestamp.now(),
        });
      }
    } catch (e) {
      print('Failed to award bonus points: $e');
    }
  }

  Future<void> _sendReviewNotification(UniversalReview review) async {
    // Implementation would send push notification to reviewed entity
    // This would integrate with your push notification service
  }

  Future<void> _sendResponseNotification(String reviewId, String responderName) async {
    // Implementation would send push notification to original reviewer
    // This would integrate with your push notification service
  }

  /// Get all reviews written by a specific user
  Future<List<UniversalReview>> getReviewsByUser({
    required String reviewerId,
    int limit = 20,
    DateTime? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection(_reviewsCollection)
          .where('reviewerId', isEqualTo: reviewerId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfter([startAfter]);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => UniversalReview.fromFirestore(doc))
          .toList();
    } catch (e) {
      // Log Firestore index errors explicitly
      final errorString = e.toString();
      if (errorString.contains('index') || errorString.contains('Index')) {
        print('❌ FIRESTORE INDEX ERROR in getReviewsByUser:');
        print('   Reviewer ID: $reviewerId');
        print('   Limit: $limit');
        print('   Start After: $startAfter');
        print('   Error: $errorString');

        // Extract index creation URL if present
        final urlPattern = RegExp(r'https://console\.firebase\.google\.com/[^\s]+');
        final match = urlPattern.firstMatch(errorString);
        if (match != null) {
          print('   📍 Create index at: ${match.group(0)}');
        }
      } else {
        print('Error getting user reviews: $e');
      }
      return [];
    }
  }

  /// Delete a review
  Future<void> deleteReview(String reviewId) async {
    try {
      // Get the review first to update stats
      final reviewDoc = await _firestore
          .collection(_reviewsCollection)
          .doc(reviewId)
          .get();

      if (!reviewDoc.exists) {
        throw Exception('Review not found');
      }

      final review = UniversalReview.fromFirestore(reviewDoc);

      // Delete the review
      await _firestore
          .collection(_reviewsCollection)
          .doc(reviewId)
          .delete();

      // Update stats for the reviewed entity
      await _updateReviewStats(review.reviewedId, review.reviewedType);
    } catch (e) {
      print('Error deleting review: $e');
      throw Exception('Failed to delete review: $e');
    }
  }
}

/// Sorting options for reviews
enum ReviewSortOption {
  newest,
  oldest,
  highestRated,
  lowestRated,
  mostHelpful,
}