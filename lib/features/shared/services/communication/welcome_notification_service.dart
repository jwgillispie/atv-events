import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage welcome notification for newly verified users
class WelcomeNotificationService {
  static const String _shownKey = 'welcome_notification_shown_';
  static const String _lastVerificationKey = 'last_verification_status_';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Check if user should see welcome notification
  /// Returns CEO notes if notification should be shown, null otherwise
  Future<String?> checkAndGetWelcomeNotes(String userId) async {
    try {
      // Get user profile from Firestore
      final doc = await _firestore
          .collection('user_profiles')
          .doc(userId)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      final data = doc.data()!;
      final verificationStatus = data['verificationStatus'] as String?;
      final verificationNotes = data['verificationNotes'] as String?;
      final verifiedAt = (data['verifiedAt'] as Timestamp?)?.toDate();
      final welcomeShownInDb = data['welcomeNotificationShown'] as bool?;
      
      // Check if user is approved
      if (verificationStatus != 'approved') {
        return null;
      }
      
      // Check if notes exist
      if (verificationNotes == null || verificationNotes.isEmpty) {
        return null;
      }
      
      // Check if already shown (check both DB and local prefs)
      if (welcomeShownInDb == true) {
        return null;
      }
      
      // Check local preferences as backup
      final prefs = await SharedPreferences.getInstance();
      final shownKey = '$_shownKey$userId';
      final lastStatusKey = '$_lastVerificationKey$userId';
      
      final hasShown = prefs.getBool(shownKey) ?? false;
      final lastStatus = prefs.getString(lastStatusKey);
      
      // If status changed from non-approved to approved, reset the shown flag
      if (lastStatus != null && lastStatus != 'approved') {
        await prefs.setBool(shownKey, false);
      }
      
      // Update last known status
      await prefs.setString(lastStatusKey, verificationStatus ?? 'pending');
      
      // If already shown for this approval, return null
      if (hasShown && lastStatus == 'approved') {
        return null;
      }
      
      // Check if verification was recent (within last 30 days)
      if (verifiedAt != null) {
        final daysSinceVerification = DateTime.now().difference(verifiedAt).inDays;
        if (daysSinceVerification > 30) {
          // Mark as shown since it's old
          await markWelcomeNotificationShown(userId);
          return null;
        }
      }
      
      return verificationNotes;
    } catch (e) {
      return null;
    }
  }
  
  /// Mark welcome notification as shown for user
  Future<void> markWelcomeNotificationShown(String userId) async {
    try {
      // Update local preferences
      final prefs = await SharedPreferences.getInstance();
      final shownKey = '$_shownKey$userId';
      await prefs.setBool(shownKey, true);
      
      // Also update Firestore for persistence across devices
      await _firestore
          .collection('user_profiles')
          .doc(userId)
          .update({'welcomeNotificationShown': true});
    } catch (e) {
    }
  }
  
  /// Reset welcome notification for user (useful for testing)
  Future<void> resetWelcomeNotification(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shownKey = '$_shownKey$userId';
      final lastStatusKey = '$_lastVerificationKey$userId';
      
      await prefs.remove(shownKey);
      await prefs.remove(lastStatusKey);
    } catch (e) {
    }
  }
  
  /// Check if user has pending verification notes to see
  Future<bool> hasPendingWelcomeNotification(String userId) async {
    final notes = await checkAndGetWelcomeNotes(userId);
    return notes != null;
  }
}