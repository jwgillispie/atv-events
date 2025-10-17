import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/organizer_vendor_post.dart';
import '../../models/vendor_post_response.dart';

class OrganizerVendorPostService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new vendor post
  static Future<String> createVendorPost(OrganizerVendorPost post) async {
    try {
      final now = DateTime.now();
      final postWithTimestamps = post.copyWith(
        createdAt: now,
        updatedAt: now,
      );

      final docRef = await _firestore
          .collection('organizer_vendor_posts')
          .add(postWithTimestamps.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create vendor post: $e');
    }
  }

  /// Update an existing vendor post
  static Future<void> updateVendorPost(
      String postId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());

      await _firestore
          .collection('organizer_vendor_posts')
          .doc(postId)
          .update(updates);

    } catch (e) {
      throw Exception('Failed to update vendor post: $e');
    }
  }

  /// Delete a vendor post
  static Future<void> deleteVendorPost(String postId) async {
    try {
      final batch = _firestore.batch();

      // Delete the post
      batch.delete(_firestore.collection('organizer_vendor_posts').doc(postId));

      // Delete all related responses
      final responseQuery = await _firestore
          .collection('organizer_vendor_post_responses')
          .where('postId', isEqualTo: postId)
          .get();

      for (final doc in responseQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete vendor post: $e');
    }
  }

  /// Get posts for a specific organizer
  static Future<List<OrganizerVendorPost>> getOrganizerPosts(
    String organizerId, {
    int limit = 20,
    PostStatus? status,
    String? marketId,
  }) async {
    try {
      Query query = _firestore
          .collection('organizer_vendor_posts')
          .where('organizerId', isEqualTo: organizerId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      if (marketId != null) {
        query = query.where('marketId', isEqualTo: marketId);
      }

      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => OrganizerVendorPost.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get organizer posts: $e');
    }
  }

  /// Get a specific vendor post by ID
  static Future<OrganizerVendorPost?> getVendorPost(String postId) async {
    try {
      final doc = await _firestore
          .collection('organizer_vendor_posts')
          .doc(postId)
          .get();

      if (!doc.exists) return null;

      return OrganizerVendorPost.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get vendor post: $e');
    }
  }

  /// Search vendor posts by criteria
  static Future<List<OrganizerVendorPost>> searchVendorPosts({
    List<String>? categories,
    String? searchQuery,
    double? maxDistance,
    double? latitude,
    double? longitude,
    bool onlyActive = true,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore.collection('organizer_vendor_posts');

      if (onlyActive) {
        query = query.where('status', isEqualTo: PostStatus.active.name);
      }

      if (categories != null && categories.isNotEmpty) {
        query = query.where('categories', arrayContainsAny: categories);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      final snapshot = await query.get();
      
      List<OrganizerVendorPost> posts = snapshot.docs
          .map((doc) => OrganizerVendorPost.fromFirestore(doc))
          .toList();

      // Apply text search filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final queryLower = searchQuery.toLowerCase();
        posts = posts.where((post) {
          final searchText = '${post.title} ${post.description}'.toLowerCase();
          return searchText.contains(queryLower);
        }).toList();
      }

      // Apply distance filter if location is provided
      if (latitude != null && longitude != null && maxDistance != null) {
        posts = posts.where((post) {
          // In a real implementation, you'd calculate distance to market location
          // For now, include all posts
          return true;
        }).toList();
      }

      return posts;
    } catch (e) {
      throw Exception('Failed to search vendor posts: $e');
    }
  }

  /// Track post view analytics
  static Future<void> trackPostView(String postId, String? vendorId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final postRef = _firestore
            .collection('organizer_vendor_posts')
            .doc(postId);
        
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) return;

        final currentAnalytics = PostAnalytics.fromMap(
          postDoc.data()?['analytics'] ?? {}
        );
        
        final updatedAnalytics = currentAnalytics.copyWith(
          views: currentAnalytics.views + 1,
        );

        transaction.update(postRef, {
          'analytics': updatedAnalytics.toMap(),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      });

    } catch (e) {
    }
  }

  /// Get analytics for a specific post
  static Future<Map<String, int>> getPostAnalytics(String postId) async {
    try {
      final postDoc = await _firestore
          .collection('organizer_vendor_posts')
          .doc(postId)
          .get();

      if (!postDoc.exists) {
        return {'views': 0, 'applications': 0, 'responses': 0};
      }

      final post = OrganizerVendorPost.fromFirestore(postDoc);
      
      // Get response count from related responses
      final responseCount = await _getResponseCount(postId);

      return {
        'views': post.analytics.views,
        'applications': post.analytics.applications,
        'responses': responseCount,
      };
    } catch (e) {
      return {'views': 0, 'applications': 0, 'responses': 0};
    }
  }

  /// Get comprehensive analytics for all organizer posts
  static Future<Map<String, dynamic>> getOrganizerPostAnalytics(
      String organizerId) async {
    try {
      // Get all posts for organizer
      final posts = await getOrganizerPosts(organizerId, limit: 1000);
      
      int totalPosts = posts.length;
      int activePosts = posts.where((p) => p.isActive).length;
      int totalViews = posts.fold(0, (sum, p) => sum + p.analytics.views);
      int totalApplications = posts.fold(0, (sum, p) => sum + p.analytics.applications);
      
      // Get total responses across all posts
      int totalResponses = 0;
      for (final post in posts) {
        totalResponses += await _getResponseCount(post.id);
      }

      // Calculate averages
      double avgViewsPerPost = totalPosts > 0 ? totalViews / totalPosts : 0;
      double responseRate = totalViews > 0 ? (totalResponses / totalViews) * 100 : 0;

      return {
        'totalPosts': totalPosts,
        'activePosts': activePosts,
        'totalViews': totalViews,
        'totalApplications': totalApplications,
        'totalResponses': totalResponses,
        'avgViewsPerPost': avgViewsPerPost.round(),
        'responseRate': responseRate.round(),
      };
    } catch (e) {
      return {
        'totalPosts': 0,
        'activePosts': 0,
        'totalViews': 0,
        'totalApplications': 0,
        'totalResponses': 0,
        'avgViewsPerPost': 0,
        'responseRate': 0,
      };
    }
  }

  /// Update post status
  static Future<void> updatePostStatus(String postId, PostStatus status) async {
    try {
      await updateVendorPost(postId, {
        'status': status.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
    } catch (e) {
      throw Exception('Failed to update post status: $e');
    }
  }

  /// Activate post
  static Future<void> activatePost(String postId) async {
    await updatePostStatus(postId, PostStatus.active);
  }

  /// Pause post
  static Future<void> pausePost(String postId) async {
    await updatePostStatus(postId, PostStatus.paused);
  }

  /// Close post
  static Future<void> closePost(String postId) async {
    await updatePostStatus(postId, PostStatus.closed);
  }

  /// Check and update expired posts
  static Future<void> updateExpiredPosts() async {
    try {
      final now = DateTime.now();
      final expiredQuery = await _firestore
          .collection('organizer_vendor_posts')
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .where('status', isEqualTo: PostStatus.active.name)
          .get();

      final batch = _firestore.batch();
      for (final doc in expiredQuery.docs) {
        batch.update(doc.reference, {
          'status': PostStatus.expired.name,
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      if (expiredQuery.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
    }
  }

  /// Get response count for a post
  static Future<int> _getResponseCount(String postId) async {
    try {
      final responseQuery = await _firestore
          .collection('organizer_vendor_post_responses')
          .where('postId', isEqualTo: postId)
          .get();
      
      return responseQuery.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Get responses for a specific post
  static Future<List<VendorPostResponse>> getPostResponses(
    String postId, {
    ResponseStatus? status,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('organizer_vendor_post_responses')
          .where('postId', isEqualTo: postId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => VendorPostResponse.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get post responses: $e');
    }
  }

  /// Get all responses for organizer's posts
  static Future<List<VendorPostResponse>> getOrganizerResponses(
    String organizerId, {
    ResponseStatus? status,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore
          .collection('organizer_vendor_post_responses')
          .where('organizerId', isEqualTo: organizerId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => VendorPostResponse.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get organizer responses: $e');
    }
  }

  /// Update response status
  static Future<void> updateResponseStatus(
    String responseId, 
    ResponseStatus status, {
    String? organizerNotes,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (organizerNotes != null) {
        updates['organizerNotes'] = organizerNotes;
      }

      await _firestore
          .collection('organizer_vendor_post_responses')
          .doc(responseId)
          .update(updates);

    } catch (e) {
      throw Exception('Failed to update response status: $e');
    }
  }
}