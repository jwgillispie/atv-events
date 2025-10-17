import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to handle password reset functionality for all user types
class PasswordResetService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Send password reset email to the user
  static Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    try {
      // Validate email format
      if (!_isValidEmail(email)) {
        throw Exception('Please enter a valid email address');
      }
      
      // Check if user exists and get their user type
      final userType = await _getUserType(email);
      if (userType == null) {
        // Don't reveal if user doesn't exist for security
        // But still send the reset email (Firebase handles this)
        debugPrint('User not found for email: $email');
      } else {
        debugPrint('Sending password reset to $userType: $email');
      }
      
      // Send the password reset email
      await _auth.sendPasswordResetEmail(email: email);
      
      // Log the password reset request
      await _logPasswordResetRequest(email, userType);
      
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      switch (e.code) {
        case 'invalid-email':
          throw Exception('The email address is invalid');
        case 'user-not-found':
          // Don't reveal that user doesn't exist
          // Firebase actually doesn't throw this for sendPasswordResetEmail
          throw Exception('If an account exists with this email, you will receive a password reset link');
        default:
          throw Exception('Failed to send reset email. Please try again.');
      }
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      throw Exception('An error occurred. Please try again later.');
    }
  }
  
  /// Validate email format
  static bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }
  
  /// Get user type from email
  static Future<String?> _getUserType(String email) async {
    try {
      // Query users collection to find user by email
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return null;
      }
      
      final userData = querySnapshot.docs.first.data();
      return userData['userType'] as String?;
    } catch (e) {
      debugPrint('Error getting user type: $e');
      return null;
    }
  }
  
  /// Log password reset request for analytics
  static Future<void> _logPasswordResetRequest(String email, String? userType) async {
    try {
      await _firestore.collection('password_reset_logs').add({
        'email': email,
        'userType': userType ?? 'unknown',
        'requestedAt': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      // Don't throw error for logging failure
      debugPrint('Failed to log password reset request: $e');
    }
  }
  
  /// Verify password reset code (for custom flow if needed)
  static Future<String?> verifyPasswordResetCode(String code) async {
    try {
      final email = await _auth.verifyPasswordResetCode(code);
      return email;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'expired-action-code':
          throw Exception('This password reset link has expired. Please request a new one.');
        case 'invalid-action-code':
          throw Exception('This password reset link is invalid. Please request a new one.');
        default:
          throw Exception('Failed to verify reset code. Please try again.');
      }
    } catch (e) {
      throw Exception('An error occurred. Please try again.');
    }
  }
  
  /// Confirm password reset with new password
  static Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      // Validate password strength
      _validatePassword(newPassword);
      
      // Confirm the password reset
      await _auth.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );
      
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'expired-action-code':
          throw Exception('This password reset link has expired. Please request a new one.');
        case 'invalid-action-code':
          throw Exception('This password reset link is invalid. Please request a new one.');
        case 'weak-password':
          throw Exception('Password is too weak. Please use a stronger password.');
        default:
          throw Exception('Failed to reset password. Please try again.');
      }
    } catch (e) {
      throw Exception('An error occurred. Please try again.');
    }
  }
  
  /// Validate password strength
  static void _validatePassword(String password) {
    if (password.length < 8) {
      throw Exception('Password must be at least 8 characters long');
    }
    
    if (!password.contains(RegExp(r'[A-Z]'))) {
      throw Exception('Password must contain at least one uppercase letter');
    }
    
    if (!password.contains(RegExp(r'[0-9]'))) {
      throw Exception('Password must contain at least one number');
    }
    
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      throw Exception('Password must contain at least one special character');
    }
  }
  
  /// Get password strength for UI feedback
  static PasswordStrength getPasswordStrength(String password) {
    if (password.isEmpty) {
      return PasswordStrength.none;
    }
    
    int strength = 0;
    
    // Check length
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;
    
    // Check for uppercase
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    
    // Check for numbers
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    
    // Check for special characters
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;
    
    if (strength <= 2) return PasswordStrength.weak;
    if (strength <= 3) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }
}

/// Password strength levels
enum PasswordStrength {
  none,
  weak,
  medium,
  strong,
}

/// Extension to get display properties for password strength
extension PasswordStrengthExtension on PasswordStrength {
  String get label {
    switch (this) {
      case PasswordStrength.none:
        return '';
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.medium:
        return 'Medium';
      case PasswordStrength.strong:
        return 'Strong';
    }
  }
  
  double get value {
    switch (this) {
      case PasswordStrength.none:
        return 0.0;
      case PasswordStrength.weak:
        return 0.33;
      case PasswordStrength.medium:
        return 0.66;
      case PasswordStrength.strong:
        return 1.0;
    }
  }
}