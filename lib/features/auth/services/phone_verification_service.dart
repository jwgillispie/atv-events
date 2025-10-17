import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/user_profile.dart';

class PhoneVerificationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Store verification ID for the current session
  String? _verificationId;
  int? _resendToken;

  // Send verification code to phone number
  Future<String> sendVerificationCode(String phoneNumber) async {
    try {
      // Ensure phone number is properly formatted
      String formattedPhone = phoneNumber;
      if (!phoneNumber.startsWith('+')) {
        // Default to US country code if not provided
        formattedPhone = '+1$phoneNumber';
      }

      // Clean up the phone number (remove spaces, dashes, etc.)
      formattedPhone = formattedPhone.replaceAll(RegExp(r'[^\d+]'), '');

      // Store verification ID when received
      String? verificationIdResult;

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // This callback is called when verification is done automatically
          // (e.g., on Android devices that can auto-retrieve SMS codes)
          if (!kIsWeb) {
            await _handlePhoneAuthCredential(credential);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (e.code == 'invalid-phone-number') {
            throw Exception('Invalid phone number format');
          } else if (e.code == 'too-many-requests') {
            throw Exception('Too many requests. Please try again later');
          } else {
            throw Exception('Phone verification failed: ${e.message}');
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          verificationIdResult = verificationId;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
      );

      // Wait for the codeSent callback to complete
      await Future.delayed(const Duration(milliseconds: 100));

      if (verificationIdResult == null) {
        throw Exception('Failed to send verification code');
      }

      return verificationIdResult!;
    } catch (e) {
      debugPrint('Error sending verification code: $e');
      rethrow;
    }
  }

  // Verify the SMS code entered by the user
  Future<bool> verifyCode(String verificationId, String smsCode) async {
    try {
      // Create credential with verification ID and SMS code
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // Link or sign in with the credential
      return await _handlePhoneAuthCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        throw Exception('Invalid verification code');
      } else if (e.code == 'session-expired') {
        throw Exception('Verification session expired. Please request a new code');
      } else {
        throw Exception('Verification failed: ${e.message}');
      }
    } catch (e) {
      debugPrint('Error verifying code: $e');
      rethrow;
    }
  }

  // Handle phone authentication credential
  Future<bool> _handlePhoneAuthCredential(PhoneAuthCredential credential) async {
    try {
      final currentUser = _auth.currentUser;

      if (currentUser != null) {
        // Link phone number to existing user account
        await currentUser.linkWithCredential(credential);

        // Extract phone number from credential or user
        String? phoneNumber = currentUser.phoneNumber;

        // Mark phone as verified
        if (phoneNumber != null) {
          await markPhoneVerified(currentUser.uid, phoneNumber);
        }

        return true;
      } else {
        // Sign in with phone credential if no user is logged in
        final userCredential = await _auth.signInWithCredential(credential);

        if (userCredential.user != null) {
          String? phoneNumber = userCredential.user!.phoneNumber;

          if (phoneNumber != null) {
            await markPhoneVerified(userCredential.user!.uid, phoneNumber);
          }

          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error handling phone auth credential: $e');
      rethrow;
    }
  }

  // Mark phone as verified and apply auto-approval logic
  Future<void> markPhoneVerified(String userId, String phoneNumber) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final userProfile = UserProfile.fromFirestore(userDoc);

      // Update user profile with phone verification
      final updates = <String, dynamic>{
        'phoneNumber': phoneNumber,
        'phoneVerified': true,
        'phoneVerifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Auto-approval logic for phone-verified users
      // Set verification status to approved and upgrade account tier
      if (userProfile.verificationStatus != VerificationStatus.approved) {
        updates['verificationStatus'] = VerificationStatus.approved.name;
        updates['autoApproved'] = true;
        updates['verifiedAt'] = FieldValue.serverTimestamp();
        updates['verificationNotes'] = 'Auto-approved via phone verification';
      }

      // Upgrade account tier for phone-verified users
      if (userProfile.accountTier < 2) {
        updates['accountTier'] = 2;
      }

      // Update the user document
      await _firestore.collection('users').doc(userId).update(updates);

      debugPrint('Phone verification completed for user: $userId');
    } catch (e) {
      debugPrint('Error marking phone as verified: $e');
      throw Exception('Failed to update phone verification status');
    }
  }

  // Check if current user has verified phone
  Future<bool> isPhoneVerified(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return data['phoneVerified'] ?? false;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking phone verification status: $e');
      return false;
    }
  }

  // Resend verification code
  Future<String> resendVerificationCode(String phoneNumber) async {
    // Reset verification ID to force a new code
    _verificationId = null;
    return sendVerificationCode(phoneNumber);
  }

  // Get formatted phone number for display
  String formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters except +
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Format US phone numbers
    if (cleaned.startsWith('+1') && cleaned.length == 12) {
      // +1 XXX XXX XXXX
      return '+1 (${cleaned.substring(2, 5)}) ${cleaned.substring(5, 8)}-${cleaned.substring(8)}';
    } else if (cleaned.startsWith('1') && cleaned.length == 11) {
      // 1XXXXXXXXXX
      return '+1 (${cleaned.substring(1, 4)}) ${cleaned.substring(4, 7)}-${cleaned.substring(7)}';
    } else if (cleaned.length == 10) {
      // XXXXXXXXXX
      return '(${cleaned.substring(0, 3)}) ${cleaned.substring(3, 6)}-${cleaned.substring(6)}';
    }

    // Return original if not a recognized format
    return phoneNumber;
  }

  // Validate phone number format
  bool isValidPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Check for valid US phone number (10 digits)
    if (cleaned.length == 10) {
      // Area code should not start with 0 or 1
      return !cleaned.startsWith('0') && !cleaned.startsWith('1');
    }

    // Check for US number with country code
    if (cleaned.length == 11 && cleaned.startsWith('1')) {
      // Area code should not start with 0 or 1
      return !cleaned[1].startsWith('0') && !cleaned[1].startsWith('1');
    }

    return false;
  }
}