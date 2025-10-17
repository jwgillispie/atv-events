import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Base service class with common Firebase patterns for organizer services
abstract class BaseOrganizerService {
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;
  
  /// Get vendors query with common filters
  static Query getVendorsQuery({
    bool verified = true,
    List<String>? categories,
    String? location,
  }) {
    Query query = firestore.collection('user_profiles')
        .where('userType', isEqualTo: 'vendor');
    
    if (verified) {
      query = query.where('isVerified', isEqualTo: true);
    }
    
    if (categories != null && categories.isNotEmpty) {
      query = query.where('categories', arrayContainsAny: categories);
    }
    
    if (location != null && location.isNotEmpty) {
      query = query.where('city', isEqualTo: location);
    }
    
    return query;
  }
  
  /// Get markets query for an organizer
  static Query getOrganizerMarketsQuery(String organizerId) {
    return firestore.collection('markets')
        .where('organizerId', isEqualTo: organizerId)
        .orderBy('createdAt', descending: true);
  }
  
  /// Common error handling wrapper
  static Future<T> executeQuery<T>(
    Future<T> Function() query, {
    String? errorContext,
  }) async {
    try {
      return await query();
    } catch (e) {
      debugPrint('Service error${errorContext != null ? ' ($errorContext)' : ''}: $e');
      rethrow;
    }
  }
  
  /// Batch operation helper
  static Future<void> performBatchOperation(
    Future<void> Function(WriteBatch batch) operation,
  ) async {
    final batch = firestore.batch();
    try {
      await operation(batch);
      await batch.commit();
    } catch (e) {
      debugPrint('Batch operation failed: $e');
      rethrow;
    }
  }
  
  /// Get document with error handling
  static Future<DocumentSnapshot?> getDocument(
    String collection,
    String documentId,
  ) async {
    try {
      final doc = await firestore.collection(collection).doc(documentId).get();
      return doc.exists ? doc : null;
    } catch (e) {
      debugPrint('Failed to get document $collection/$documentId: $e');
      return null;
    }
  }
  
  /// Stream document changes
  static Stream<DocumentSnapshot> streamDocument(
    String collection,
    String documentId,
  ) {
    return firestore.collection(collection).doc(documentId).snapshots();
  }
  
  /// Check if vendor has recent interaction with organizer
  static Future<bool> hasRecentInteraction(
    String organizerId,
    String vendorId, {
    Duration recency = const Duration(days: 30),
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(recency);
      
      // Check invitations
      final invitations = await firestore
          .collection('vendor_invitations')
          .where('organizerId', isEqualTo: organizerId)
          .where('vendorId', isEqualTo: vendorId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .limit(1)
          .get();
      
      if (invitations.docs.isNotEmpty) return true;
      
      // Check vendor post responses
      final responses = await firestore
          .collection('vendor_post_responses')
          .where('organizerId', isEqualTo: organizerId)
          .where('vendorId', isEqualTo: vendorId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .limit(1)
          .get();
      
      return responses.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking recent interaction: $e');
      return false;
    }
  }
  
  /// Common date range query helper
  static Query applyDateRangeToQuery(
    Query query,
    String dateField,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (startDate != null) {
      query = query.where(dateField, isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where(dateField, isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }
    return query;
  }
  
  /// Pagination helper
  static Future<QuerySnapshot> getPaginatedResults(
    Query baseQuery, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = baseQuery.limit(limit);
    
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    
    return await query.get();
  }
}