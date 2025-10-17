import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:atv_events/features/shared/models/user_feedback.dart';

/// Service for managing user feedback submissions and admin responses
/// All feedback is stored centrally and accessible via CEO verification dashboard
class UserFeedbackService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'user_feedback';

  // =============================================================================
  // FEEDBACK SUBMISSION METHODS (For all user types)
  // =============================================================================

  /// Submit new feedback from any user type
  static Future<UserFeedback> submitFeedback({
    required String userId,
    required String userType,
    required String userEmail,
    String? userName,
    required FeedbackCategory category,
    required String title,
    required String description,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Create feedback object
      final feedback = UserFeedback.create(
        userId: userId,
        userType: userType,
        userEmail: userEmail,
        userName: userName,
        category: category,
        title: title,
        description: description,
        tags: tags,
        metadata: metadata,
      );

      // Validate feedback
      final validationError = feedback.validate();
      if (validationError != null) {
        throw Exception('Invalid feedback: $validationError');
      }

      // Save to Firestore
      final docRef = await _firestore
          .collection(_collection)
          .add(feedback.toFirestore());

      return feedback.copyWith(id: docRef.id);
    } catch (e) {
      rethrow;
    }
  }

  /// Get all feedback submitted by a specific user
  static Future<List<UserFeedback>> getUserFeedback(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => UserFeedback.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream all feedback for real-time updates (for user's own feedback)
  static Stream<List<UserFeedback>> streamUserFeedback(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserFeedback.fromFirestore(doc))
            .toList());
  }

  // =============================================================================
  // ADMIN MANAGEMENT METHODS (For CEO Dashboard)
  // =============================================================================

  /// Get all feedback across all users (for CEO dashboard)
  static Future<List<UserFeedback>> getAllFeedback({
    int? limit,
    FeedbackStatus? statusFilter,
    FeedbackPriority? priorityFilter,
    FeedbackCategory? categoryFilter,
    String? userTypeFilter,
  }) async {
    try {
      Query query = _firestore.collection(_collection);

      // Apply filters
      if (statusFilter != null) {
        query = query.where('status', isEqualTo: statusFilter.name);
      }
      if (priorityFilter != null) {
        query = query.where('priority', isEqualTo: priorityFilter.name);
      }
      if (categoryFilter != null) {
        query = query.where('category', isEqualTo: categoryFilter.name);
      }
      if (userTypeFilter != null) {
        query = query.where('userType', isEqualTo: userTypeFilter);
      }

      // Order and limit
      query = query.orderBy('createdAt', descending: true);
      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => UserFeedback.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream all feedback for real-time CEO dashboard updates
  static Stream<List<UserFeedback>> streamAllFeedback({
    int? limit,
    FeedbackStatus? statusFilter,
  }) {
    Query query = _firestore.collection(_collection);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.name);
    }

    query = query.orderBy('createdAt', descending: true);
    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) => 
        snapshot.docs.map((doc) => UserFeedback.fromFirestore(doc)).toList());
  }

  /// Get feedback statistics for dashboard overview
  static Future<Map<String, dynamic>> getFeedbackStats() async {
    try {
      final allFeedback = await getAllFeedback();
      
      final stats = <String, dynamic>{
        'total': allFeedback.length,
        'byStatus': <String, int>{},
        'byCategory': <String, int>{},
        'byPriority': <String, int>{},
        'byUserType': <String, int>{},
        'averageResponseTime': 0.0,
        'activeCount': 0,
        'resolvedCount': 0,
      };

      // Calculate statistics
      int totalResponseTime = 0;
      int respondedCount = 0;

      for (final feedback in allFeedback) {
        // Status distribution
        final status = feedback.status.name;
        stats['byStatus'][status] = (stats['byStatus'][status] ?? 0) + 1;

        // Category distribution
        final category = feedback.category.name;
        stats['byCategory'][category] = (stats['byCategory'][category] ?? 0) + 1;

        // Priority distribution
        final priority = feedback.priority.name;
        stats['byPriority'][priority] = (stats['byPriority'][priority] ?? 0) + 1;

        // User type distribution
        final userType = feedback.userType;
        stats['byUserType'][userType] = (stats['byUserType'][userType] ?? 0) + 1;

        // Active vs resolved count
        if (feedback.isActive) {
          stats['activeCount'] = stats['activeCount'] + 1;
        } else {
          stats['resolvedCount'] = stats['resolvedCount'] + 1;
        }

        // Response time calculation
        if (feedback.hasResponse && feedback.respondedAt != null) {
          final responseTime = feedback.respondedAt!.difference(feedback.createdAt).inHours;
          totalResponseTime += responseTime;
          respondedCount++;
        }
      }

      // Average response time
      if (respondedCount > 0) {
        stats['averageResponseTime'] = totalResponseTime / respondedCount;
      }

      return stats;
    } catch (e) {
      return {};
    }
  }

  /// Update feedback status (admin action)
  static Future<UserFeedback> updateFeedbackStatus(
    String feedbackId,
    FeedbackStatus newStatus,
  ) async {
    try {
      final docRef = _firestore.collection(_collection).doc(feedbackId);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        throw Exception('Feedback not found');
      }

      final feedback = UserFeedback.fromFirestore(docSnapshot);
      final updatedFeedback = feedback.updateStatus(newStatus);

      await docRef.update(updatedFeedback.toFirestore());
      
      return updatedFeedback;
    } catch (e) {
      rethrow;
    }
  }

  /// Respond to feedback (admin action)
  static Future<UserFeedback> respondToFeedback({
    required String feedbackId,
    required String response,
    required String adminUserId,
  }) async {
    try {
      final docRef = _firestore.collection(_collection).doc(feedbackId);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        throw Exception('Feedback not found');
      }

      final feedback = UserFeedback.fromFirestore(docSnapshot);
      final respondedFeedback = feedback.respondTo(
        response: response,
        adminUserId: adminUserId,
      );

      await docRef.update(respondedFeedback.toFirestore());
      
      return respondedFeedback;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete feedback (admin action - use sparingly)
  static Future<void> deleteFeedback(String feedbackId) async {
    try {
      await _firestore.collection(_collection).doc(feedbackId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // =============================================================================
  // UTILITY METHODS
  // =============================================================================

  /// Search feedback by text content
  static Future<List<UserFeedback>> searchFeedback({
    required String searchTerm,
    int limit = 50,
  }) async {
    try {
      // Firestore doesn't support full-text search, so we'll do a simple contains search
      // In production, consider using Algolia or Elasticsearch for better search
      final allFeedback = await getAllFeedback(limit: 500); // Get more for searching
      
      final searchLower = searchTerm.toLowerCase();
      final results = allFeedback.where((feedback) {
        return feedback.title.toLowerCase().contains(searchLower) ||
               feedback.description.toLowerCase().contains(searchLower) ||
               feedback.userEmail.toLowerCase().contains(searchLower) ||
               feedback.userName?.toLowerCase().contains(searchLower) == true;
      }).take(limit).toList();

      return results;
    } catch (e) {
      return [];
    }
  }

  /// Get recent feedback for dashboard quick view
  static Future<List<UserFeedback>> getRecentFeedback({int limit = 10}) async {
    return getAllFeedback(limit: limit);
  }

  /// Get high priority unresolved feedback
  static Future<List<UserFeedback>> getHighPriorityFeedback() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('priority', whereIn: [FeedbackPriority.high.name, FeedbackPriority.critical.name])
          .where('status', whereIn: [FeedbackStatus.submitted.name, FeedbackStatus.reviewing.name, FeedbackStatus.inProgress.name])
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return querySnapshot.docs
          .map((doc) => UserFeedback.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Batch update multiple feedback items (admin bulk operations)
  static Future<void> batchUpdateStatus(
    List<String> feedbackIds,
    FeedbackStatus newStatus,
  ) async {
    try {
      final batch = _firestore.batch();
      
      for (final feedbackId in feedbackIds) {
        final docRef = _firestore.collection(_collection).doc(feedbackId);
        batch.update(docRef, {
          'status': newStatus.name,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
      
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// Get feedback count by user type (for analytics)
  static Future<Map<String, int>> getFeedbackCountByUserType() async {
    try {
      final allFeedback = await getAllFeedback();
      final counts = <String, int>{};
      
      for (final feedback in allFeedback) {
        counts[feedback.userType] = (counts[feedback.userType] ?? 0) + 1;
      }
      
      return counts;
    } catch (e) {
      return {};
    }
  }
}