import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Utility class for logging Firestore errors with clickable index creation URLs
class FirestoreErrorLogger {
  /// Log a Firestore error and extract index creation URL if present
  static void logError(dynamic error, String context) {
    if (error == null) return;

    final errorString = error.toString();

    // Check if this is an index error
    if (errorString.contains('failed-precondition') ||
        errorString.contains('requires an index') ||
        errorString.contains('create_composite')) {

      debugPrint('╔═══════════════════════════════════════════════════════════════════════════════');
      debugPrint('║ FIRESTORE INDEX ERROR DETECTED');
      debugPrint('║ Context: $context');
      debugPrint('╠═══════════════════════════════════════════════════════════════════════════════');
      debugPrint('║ Error: $error');
      debugPrint('╠═══════════════════════════════════════════════════════════════════════════════');

      // Extract the URL from the error message
      final urlMatch = RegExp(r'https://console\.firebase\.google\.com[^\s\]]+').firstMatch(errorString);
      if (urlMatch != null) {
        final url = urlMatch.group(0);
        debugPrint('║ 🔗 CLICKABLE INDEX CREATION URL:');
        debugPrint('║ $url');
        debugPrint('╠═══════════════════════════════════════════════════════════════════════════════');
        debugPrint('║ 📋 INSTRUCTIONS:');
        debugPrint('║ 1. Copy the URL above');
        debugPrint('║ 2. Paste it in your browser');
        debugPrint('║ 3. Click "Create Index" in Firebase Console');
        debugPrint('║ 4. Wait 2-5 minutes for the index to build');
        debugPrint('║ 5. Retry your operation');
      } else {
        debugPrint('║ ⚠️ Could not extract index creation URL from error');
      }

      debugPrint('╚═══════════════════════════════════════════════════════════════════════════════');

      // Also log to console for better visibility
      // ignore: avoid_print
      debugPrint('\n🚨 FIRESTORE INDEX ERROR in $context');
      // ignore: avoid_print
      debugPrint('Full error: $error');
      if (urlMatch != null) {
        // ignore: avoid_print
        debugPrint('🔗 Index creation URL: ${urlMatch.group(0)}');
      }
      // ignore: avoid_print
      debugPrint('');
    } else {
      // Log other Firestore errors
      debugPrint('Firestore error in $context: $error');
    }
  }

  /// Wrap a Future query with error logging
  static Future<T> wrapQuery<T>(
    Future<T> Function() query,
    String context,
  ) async {
    try {
      return await query();
    } catch (e) {
      logError(e, context);
      rethrow;
    }
  }

  /// Wrap a Stream query with error logging
  static Stream<T> wrapStream<T>(
    Stream<T> stream,
    String context,
  ) {
    return stream.handleError((error) {
      logError(error, context);
    });
  }

  /// Log a query being executed (for debugging)
  static void logQuery(String collection, Map<String, dynamic> filters) {
    if (kDebugMode) {
      debugPrint('🔍 Firestore Query: $collection');
      filters.forEach((key, value) {
        debugPrint('   $key: $value');
      });
    }
  }
}

/// Extension on Query to add error logging
extension QueryErrorLogging on Query {
  /// Get documents with automatic error logging
  Future<QuerySnapshot> getWithLogging(String context) async {
    try {
      return await FirestoreErrorLogger.wrapQuery(
        () => get(),
        context,
      );
    } catch (e) {
      FirestoreErrorLogger.logError(e, context);
      rethrow;
    }
  }

  /// Get snapshots stream with automatic error logging
  Stream<QuerySnapshot> snapshotsWithLogging(String context) {
    return FirestoreErrorLogger.wrapStream(
      snapshots(),
      context,
    );
  }
}
