import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// CEO-only service for sending email blasts to users
class CeoEmailBlastService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Get all user emails with their user type for personalized CTAs
  Future<List<Map<String, String>>> getUserEmailsWithType({
    String? userType, // 'vendor', 'shopper', 'market_organizer', or null for all
    bool? phoneVerified,
    bool? isPremium,
    bool? isVerified,
  }) async {
    try {
      Query query = _firestore.collection('user_profiles');

      // Apply filters
      if (userType != null && userType.isNotEmpty) {
        query = query.where('userType', isEqualTo: userType);
      }
      if (phoneVerified != null) {
        query = query.where('phoneVerified', isEqualTo: phoneVerified);
      }
      if (isPremium != null) {
        query = query.where('isPremium', isEqualTo: isPremium);
      }
      if (isVerified != null) {
        query = query.where('verificationStatus', isEqualTo: isVerified ? 'approved' : 'pending');
      }

      final snapshot = await query.get();

      final recipients = <Map<String, String>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final email = data['email'] as String?;
        final type = data['userType'] as String? ?? 'shopper';
        final name = data['displayName'] as String? ?? '';

        if (email != null && email.isNotEmpty && email.contains('@')) {
          recipients.add({
            'email': email,
            'userType': type,
            'name': name,
          });
        }
      }

      debugPrint('📧 Found ${recipients.length} recipients matching filters');
      return recipients;
    } catch (e) {
      debugPrint('❌ Error fetching user emails: $e');
      rethrow;
    }
  }

  /// Get count of users by filter (for preview before sending)
  Future<Map<String, int>> getUserCounts() async {
    try {
      final allUsers = await _firestore.collection('user_profiles').get();

      int vendors = 0;
      int shoppers = 0;
      int organizers = 0;
      int verified = 0;
      int phoneVerified = 0;
      int premium = 0;

      for (final doc in allUsers.docs) {
        final data = doc.data();
        final userType = data['userType'] as String?;

        if (userType == 'vendor') vendors++;
        if (userType == 'shopper') shoppers++;
        if (userType == 'market_organizer') organizers++;
        if (data['verificationStatus'] == 'approved') verified++;
        if (data['phoneVerified'] == true) phoneVerified++;
        if (data['isPremium'] == true) premium++;
      }

      return {
        'total': allUsers.docs.length,
        'vendors': vendors,
        'shoppers': shoppers,
        'organizers': organizers,
        'verified': verified,
        'phoneVerified': phoneVerified,
        'premium': premium,
      };
    } catch (e) {
      debugPrint('❌ Error getting user counts: $e');
      return {};
    }
  }

  /// Send email blast via Cloud Function with branded template
  Future<bool> sendEmailBlast({
    required String subject,
    required String messageBody,
    required List<Map<String, String>> recipients,
    String? fromName,
  }) async {
    try {
      debugPrint('📧 Sending branded email blast to ${recipients.length} recipients');

      // Call Cloud Function to send emails with branding
      final callable = _functions.httpsCallable('sendEmailBlast');
      final result = await callable.call({
        'subject': subject,
        'messageBody': messageBody,
        'recipients': recipients, // Now includes email, userType, name
        'fromName': fromName ?? 'HiPop Markets',
      });

      final success = result.data['success'] as bool? ?? false;
      final sent = result.data['sent'] as int? ?? 0;

      debugPrint('✅ Email blast complete: $sent emails sent');
      return success;
    } catch (e) {
      debugPrint('❌ Error sending email blast: $e');
      rethrow;
    }
  }

  /// Log email blast for record keeping
  Future<void> logEmailBlast({
    required String subject,
    required int recipientCount,
    required String filters,
    required String ceoUserId,
  }) async {
    try {
      await _firestore.collection('email_blasts').add({
        'subject': subject,
        'recipientCount': recipientCount,
        'filters': filters,
        'sentBy': ceoUserId,
        'sentAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Error logging email blast: $e');
    }
  }

  /// Get email blast history
  Future<List<Map<String, dynamic>>> getEmailBlastHistory({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('email_blasts')
          .orderBy('sentAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'subject': data['subject'],
          'recipientCount': data['recipientCount'],
          'filters': data['filters'],
          'sentAt': (data['sentAt'] as Timestamp?)?.toDate(),
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching email blast history: $e');
      return [];
    }
  }
}
