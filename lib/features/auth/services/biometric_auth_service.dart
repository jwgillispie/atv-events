import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

/// Enterprise-grade biometric authentication service for HiPop marketplace
/// Handles Face ID, Touch ID, and fingerprint authentication with secure credential storage
/// Designed for multi-user type support (shopper, vendor, market_organizer)
class BiometricAuthService {
  static final BiometricAuthService _instance = BiometricAuthService._internal();
  factory BiometricAuthService() => _instance;
  BiometricAuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked,
      synchronizable: false,
    ),
  );

  // Storage keys with user type segmentation
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _userCredentialsKey = 'user_credentials'; // Legacy key for migration
  static const String _lastAuthTimestampKey = 'last_auth_timestamp';
  static const String _userTypeKey = 'user_type';
  static const String _quickAccessEnabledKey = 'quick_access_enabled';
  static const String _biometricTypeKey = 'biometric_type';
  static const String _registeredEmailsKey = 'registered_biometric_emails';
  
  // Dynamic key generators for email-based storage
  static String _getCredentialsKey(String email) => 'user_credentials_${email.toLowerCase().replaceAll('@', '_at_').replaceAll('.', '_dot_')}';
  static String _getLastAuthKey(String email) => 'last_auth_${email.toLowerCase().replaceAll('@', '_at_').replaceAll('.', '_dot_')}';
  static String _getUserTypeKeyForEmail(String email) => 'user_type_${email.toLowerCase().replaceAll('@', '_at_').replaceAll('.', '_dot_')}';

  // Security constants
  static const int _maxFailedAttempts = 3;
  static const String _failedAttemptsKey = 'failed_attempts';
  static const Duration _lockoutDuration = Duration(minutes: 5);
  static const String _lockoutTimestampKey = 'lockout_timestamp';

  /// Check if biometric authentication is available on the device
  Future<BiometricAvailability> checkBiometricAvailability() async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (!isDeviceSupported) {
        return BiometricAvailability(
          isAvailable: false,
          reason: 'Device does not support biometric authentication',
        );
      }

      if (!canCheckBiometrics) {
        return BiometricAvailability(
          isAvailable: false,
          reason: 'Biometric authentication is not available',
        );
      }

      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      if (availableBiometrics.isEmpty) {
        return BiometricAvailability(
          isAvailable: false,
          reason: 'No biometric methods enrolled. Please set up Face ID or Touch ID in Settings',
        );
      }

      // Determine the primary biometric type
      BiometricAuthType authType = BiometricAuthType.fingerprint;
      String displayName = 'Biometric Authentication';
      
      if (availableBiometrics.contains(BiometricType.face)) {
        authType = BiometricAuthType.faceId;
        displayName = 'Face ID';
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        authType = BiometricAuthType.touchId;
        displayName = 'Touch ID';
      } else if (availableBiometrics.contains(BiometricType.strong)) {
        authType = BiometricAuthType.androidBiometric;
        displayName = 'Fingerprint';
      }

      // Store the biometric type for UI customization
      await _secureStorage.write(key: _biometricTypeKey, value: authType.toString());

      return BiometricAvailability(
        isAvailable: true,
        authType: authType,
        displayName: displayName,
        availableBiometrics: availableBiometrics,
      );
    } on PlatformException catch (e) {
      return BiometricAvailability(
        isAvailable: false,
        reason: _handlePlatformException(e),
      );
    } catch (e) {
      return BiometricAvailability(
        isAvailable: false,
        reason: 'Failed to check biometric availability',
      );
    }
  }

  /// Authenticate user with biometrics
  Future<BiometricAuthResult> authenticateWithBiometrics({
    required String reason,
    bool stickyAuth = true,
    bool useErrorDialogs = true,
  }) async {
    try {
      // Check lockout status
      if (await _isLockedOut()) {
        return BiometricAuthResult(
          success: false,
          error: 'Too many failed attempts. Please try again later',
          errorType: BiometricErrorType.lockedOut,
        );
      }

      // Customize the authentication prompt based on user type
      final String? userType = await _secureStorage.read(key: _userTypeKey);
      final String customReason = _getCustomizedReason(reason, userType);

      final bool authenticated = await _localAuth.authenticate(
        localizedReason: customReason,
        options: AuthenticationOptions(
          stickyAuth: stickyAuth,
          useErrorDialogs: useErrorDialogs,
          biometricOnly: false, // Allow device PIN as fallback
        ),
      );

      if (authenticated) {
        // Reset failed attempts on successful authentication
        await _resetFailedAttempts();
        await _updateLastAuthTimestamp();
        
        return BiometricAuthResult(
          success: true,
          authenticatedAt: DateTime.now(),
        );
      } else {
        // Increment failed attempts
        await _incrementFailedAttempts();
        
        return BiometricAuthResult(
          success: false,
          error: 'Authentication failed',
          errorType: BiometricErrorType.authenticationFailed,
        );
      }
    } on PlatformException catch (e) {
      // Handle specific biometric errors
      BiometricErrorType errorType = BiometricErrorType.unknown;
      String errorMessage = _handlePlatformException(e);
      
      if (e.code == auth_error.notEnrolled) {
        errorType = BiometricErrorType.notEnrolled;
      } else if (e.code == auth_error.lockedOut) {
        errorType = BiometricErrorType.lockedOut;
        await _setLockout();
      } else if (e.code == auth_error.permanentlyLockedOut) {
        errorType = BiometricErrorType.permanentlyLockedOut;
      } else if (e.code == auth_error.notAvailable) {
        errorType = BiometricErrorType.notAvailable;
      }
      
      return BiometricAuthResult(
        success: false,
        error: errorMessage,
        errorType: errorType,
      );
    } catch (e) {
      return BiometricAuthResult(
        success: false,
        error: 'Authentication error: ${e.toString()}',
        errorType: BiometricErrorType.unknown,
      );
    }
  }

  /// Save user credentials securely for biometric login
  Future<bool> saveCredentials({
    required String email,
    required String password,
    required String userType,
    String? userId,
  }) async {
    try {
      // Validate email
      if (email.isEmpty || !email.contains('@')) {
        return false;
      }
      
      final credentials = {
        'email': email,
        'password': password,
        'userType': userType,
        'userId': userId,
        'savedAt': DateTime.now().toIso8601String(),
      };

      final String encodedCredentials = jsonEncode(credentials);
      
      // Save with email-specific key
      final String credentialsKey = _getCredentialsKey(email);
      await _secureStorage.write(key: credentialsKey, value: encodedCredentials);
      
      // Save user type with email-specific key
      final String userTypeKey = _getUserTypeKeyForEmail(email);
      await _secureStorage.write(key: userTypeKey, value: userType);
      
      // Update the list of registered emails
      await _addRegisteredEmail(email);
      
      // Also maintain the legacy key for backward compatibility during transition
      await _secureStorage.write(key: _userTypeKey, value: userType);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Retrieve saved credentials after successful biometric authentication
  Future<UserCredentials?> getCredentials() async {
    // This method is deprecated, use getStoredCredentials with email instead
    // Kept for backward compatibility
    try {
      final String? encodedCredentials = await _secureStorage.read(key: _userCredentialsKey);
      
      if (encodedCredentials == null) {
        return null;
      }

      final Map<String, dynamic> credentials = jsonDecode(encodedCredentials);
      
      // Check if credentials are still valid (not expired)
      final DateTime savedAt = DateTime.parse(credentials['savedAt']);
      if (DateTime.now().difference(savedAt) > const Duration(days: 30)) {
        // Credentials expired, clear them
        await clearCredentials();
        return null;
      }

      return UserCredentials(
        email: credentials['email'],
        password: credentials['password'],
        userType: credentials['userType'],
        userId: credentials['userId'],
      );
    } catch (e) {
      return null;
    }
  }
  
  /// Retrieve saved credentials for a specific email
  Future<UserCredentials?> getStoredCredentials(String email) async {
    try {
      // Validate email
      if (email.isEmpty || !email.contains('@')) {
        return null;
      }
      
      final String credentialsKey = _getCredentialsKey(email);
      final String? encodedCredentials = await _secureStorage.read(key: credentialsKey);
      
      if (encodedCredentials == null) {
        // Try to migrate from old format if exists
        final migrated = await _migrateCredentialsIfNeeded(email);
        if (migrated) {
          // Retry after migration
          return getStoredCredentials(email);
        }
        return null;
      }

      final Map<String, dynamic> credentials = jsonDecode(encodedCredentials);
      
      // Check if credentials are still valid (not expired)
      final DateTime savedAt = DateTime.parse(credentials['savedAt']);
      if (DateTime.now().difference(savedAt) > const Duration(days: 30)) {
        // Credentials expired, clear them
        await deleteCredentials(email);
        return null;
      }

      return UserCredentials(
        email: credentials['email'],
        password: credentials['password'],
        userType: credentials['userType'],
        userId: credentials['userId'],
      );
    } catch (e) {
      return null;
    }
  }

  /// Clear stored credentials (legacy method)
  Future<void> clearCredentials() async {
    try {
      await _secureStorage.delete(key: _userCredentialsKey);
      await _secureStorage.delete(key: _lastAuthTimestampKey);
      await _secureStorage.delete(key: _userTypeKey);
    } catch (e) {
      // Handle error silently
    }
  }
  
  /// Delete credentials for a specific email
  Future<void> deleteCredentials(String email) async {
    try {
      if (email.isEmpty || !email.contains('@')) return;
      
      final String credentialsKey = _getCredentialsKey(email);
      final String lastAuthKey = _getLastAuthKey(email);
      final String userTypeKey = _getUserTypeKeyForEmail(email);
      
      await _secureStorage.delete(key: credentialsKey);
      await _secureStorage.delete(key: lastAuthKey);
      await _secureStorage.delete(key: userTypeKey);
      
      // Remove from registered emails list
      await _removeRegisteredEmail(email);
    } catch (e) {
      // Handle error silently
    }
  }

  /// Enable or disable biometric authentication
  Future<bool> setBiometricEnabled(bool enabled) async {
    try {
      await _secureStorage.write(key: _biometricEnabledKey, value: enabled.toString());
      
      if (!enabled) {
        // Clear credentials when disabling biometric auth
        await clearCredentials();
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if biometric authentication is enabled
  Future<bool> isBiometricEnabled() async {
    try {
      final String? enabled = await _secureStorage.read(key: _biometricEnabledKey);
      return enabled == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Enable or disable quick access (show biometric prompt immediately on app launch)
  Future<bool> setQuickAccessEnabled(bool enabled) async {
    try {
      await _secureStorage.write(key: _quickAccessEnabledKey, value: enabled.toString());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if quick access is enabled
  Future<bool> isQuickAccessEnabled() async {
    try {
      final String? enabled = await _secureStorage.read(key: _quickAccessEnabledKey);
      return enabled == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Check if user has saved credentials (legacy method)
  Future<bool> hasStoredCredentials() async {
    try {
      final String? credentials = await _secureStorage.read(key: _userCredentialsKey);
      return credentials != null;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if credentials exist for a specific email
  Future<bool> hasCredentialsForEmail(String email) async {
    try {
      if (email.isEmpty || !email.contains('@')) return false;
      
      final String credentialsKey = _getCredentialsKey(email);
      final String? credentials = await _secureStorage.read(key: credentialsKey);
      
      if (credentials == null) {
        // Check if we need to migrate
        final String? legacyCredentials = await _secureStorage.read(key: _userCredentialsKey);
        if (legacyCredentials != null) {
          final Map<String, dynamic> decoded = jsonDecode(legacyCredentials);
          if (decoded['email']?.toLowerCase() == email.toLowerCase()) {
            // Legacy credentials match this email
            return true;
          }
        }
        return false;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get the stored user type without retrieving full credentials
  Future<String?> getStoredUserType() async {
    try {
      return await _secureStorage.read(key: _userTypeKey);
    } catch (e) {
      return null;
    }
  }

  /// Cancel ongoing authentication
  Future<bool> cancelAuthentication() async {
    try {
      return await _localAuth.stopAuthentication();
    } catch (e) {
      return false;
    }
  }

  // Private helper methods

  String _getCustomizedReason(String baseReason, String? userType) {
    switch (userType) {
      case 'vendor':
        return 'Authenticate to access your vendor dashboard';
      case 'market_organizer':
        return 'Authenticate to access your market management tools';
      case 'shopper':
        return 'Authenticate to continue shopping';
      default:
        return baseReason;
    }
  }

  String _handlePlatformException(PlatformException e) {
    switch (e.code) {
      case auth_error.notEnrolled:
        return 'No biometric methods enrolled. Please set up Face ID or Touch ID in Settings';
      case auth_error.lockedOut:
        return 'Biometric authentication is temporarily locked. Please try again later';
      case auth_error.permanentlyLockedOut:
        return 'Biometric authentication is permanently locked. Please use your password';
      case auth_error.notAvailable:
        return 'Biometric authentication is not available on this device';
      case auth_error.passcodeNotSet:
        return 'Device passcode is not set. Please set up a passcode first';
      case auth_error.otherOperatingSystem:
        return 'Biometric authentication is not supported on this operating system';
      default:
        return e.message ?? 'Biometric authentication failed';
    }
  }

  Future<void> _updateLastAuthTimestamp([String? email]) async {
    // Update legacy timestamp
    await _secureStorage.write(
      key: _lastAuthTimestampKey,
      value: DateTime.now().toIso8601String(),
    );
    
    // Update email-specific timestamp if email provided
    if (email != null && email.isNotEmpty) {
      final lastAuthKey = _getLastAuthKey(email);
      await _secureStorage.write(
        key: lastAuthKey,
        value: DateTime.now().toIso8601String(),
      );
    }
  }

  Future<void> _incrementFailedAttempts() async {
    final String? attemptsStr = await _secureStorage.read(key: _failedAttemptsKey);
    final int attempts = (attemptsStr != null ? int.tryParse(attemptsStr) ?? 0 : 0) + 1;
    
    await _secureStorage.write(key: _failedAttemptsKey, value: attempts.toString());
    
    if (attempts >= _maxFailedAttempts) {
      await _setLockout();
    }
  }

  Future<void> _resetFailedAttempts() async {
    await _secureStorage.delete(key: _failedAttemptsKey);
    await _secureStorage.delete(key: _lockoutTimestampKey);
  }

  Future<void> _setLockout() async {
    await _secureStorage.write(
      key: _lockoutTimestampKey,
      value: DateTime.now().toIso8601String(),
    );
  }

  Future<bool> _isLockedOut() async {
    final String? lockoutStr = await _secureStorage.read(key: _lockoutTimestampKey);
    if (lockoutStr == null) return false;
    
    final DateTime lockoutTime = DateTime.parse(lockoutStr);
    final bool isLocked = DateTime.now().difference(lockoutTime) < _lockoutDuration;
    
    if (!isLocked) {
      // Clear lockout if duration has passed
      await _resetFailedAttempts();
    }
    
    return isLocked;
  }
  
  // New helper methods for multi-account support
  
  /// Get all emails that have Face ID enabled
  Future<List<String>> getRegisteredEmails() async {
    try {
      final String? emailsJson = await _secureStorage.read(key: _registeredEmailsKey);
      if (emailsJson == null) return [];
      
      final List<dynamic> emails = jsonDecode(emailsJson);
      return emails.cast<String>();
    } catch (e) {
      return [];
    }
  }
  
  /// Get the most recently authenticated email for quick access
  Future<String?> getMostRecentEmail() async {
    try {
      // First check if there are any registered emails
      final emails = await getRegisteredEmails();
      if (emails.isEmpty) {
        // Check for legacy credentials
        final legacyCredentials = await getCredentials();
        return legacyCredentials?.email;
      }
      
      // Find the email with the most recent authentication timestamp
      String? mostRecentEmail;
      DateTime? mostRecentTime;
      
      for (final email in emails) {
        final lastAuthKey = _getLastAuthKey(email);
        final String? timestamp = await _secureStorage.read(key: lastAuthKey);
        
        if (timestamp != null) {
          try {
            final authTime = DateTime.parse(timestamp);
            if (mostRecentTime == null || authTime.isAfter(mostRecentTime)) {
              mostRecentTime = authTime;
              mostRecentEmail = email;
            }
          } catch (e) {
            // Skip invalid timestamps
          }
        }
      }
      
      // If no timestamps found, return the first registered email
      return mostRecentEmail ?? (emails.isNotEmpty ? emails.first : null);
    } catch (e) {
      return null;
    }
  }
  
  /// Add email to registered list
  Future<void> _addRegisteredEmail(String email) async {
    try {
      final emails = await getRegisteredEmails();
      final normalizedEmail = email.toLowerCase();
      
      if (!emails.contains(normalizedEmail)) {
        emails.add(normalizedEmail);
        await _secureStorage.write(key: _registeredEmailsKey, value: jsonEncode(emails));
      }
    } catch (e) {
      // Handle error silently
    }
  }
  
  /// Remove email from registered list
  Future<void> _removeRegisteredEmail(String email) async {
    try {
      final emails = await getRegisteredEmails();
      final normalizedEmail = email.toLowerCase();
      
      emails.remove(normalizedEmail);
      await _secureStorage.write(key: _registeredEmailsKey, value: jsonEncode(emails));
    } catch (e) {
      // Handle error silently
    }
  }
  
  /// Migrate credentials from old format to new email-based format
  Future<bool> _migrateCredentialsIfNeeded(String email) async {
    try {
      // Check if old credentials exist
      final String? oldCredentials = await _secureStorage.read(key: _userCredentialsKey);
      if (oldCredentials == null) return false;
      
      final Map<String, dynamic> credentials = jsonDecode(oldCredentials);
      final String storedEmail = credentials['email'];
      
      // Check if the old credentials match the requested email
      if (storedEmail.toLowerCase() != email.toLowerCase()) {
        return false;
      }
      
      // Migrate to new format
      await saveCredentials(
        email: storedEmail,
        password: credentials['password'],
        userType: credentials['userType'],
        userId: credentials['userId'],
      );
      
      // Clear old credentials after successful migration
      await _secureStorage.delete(key: _userCredentialsKey);
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Clean up expired credentials for all registered emails
  Future<void> cleanupExpiredCredentials() async {
    try {
      final emails = await getRegisteredEmails();
      
      for (final email in emails) {
        // getStoredCredentials automatically handles expiration and cleanup
        await getStoredCredentials(email);
      }
    } catch (e) {
      // Handle error silently
    }
  }
}

/// Result of biometric availability check
class BiometricAvailability {
  final bool isAvailable;
  final String? reason;
  final BiometricAuthType? authType;
  final String? displayName;
  final List<BiometricType>? availableBiometrics;

  BiometricAvailability({
    required this.isAvailable,
    this.reason,
    this.authType,
    this.displayName,
    this.availableBiometrics,
  });
}

/// Types of biometric authentication
enum BiometricAuthType {
  faceId,
  touchId,
  fingerprint,
  androidBiometric,
}

/// Result of biometric authentication attempt
class BiometricAuthResult {
  final bool success;
  final String? error;
  final BiometricErrorType? errorType;
  final DateTime? authenticatedAt;

  BiometricAuthResult({
    required this.success,
    this.error,
    this.errorType,
    this.authenticatedAt,
  });
}

/// Types of biometric errors
enum BiometricErrorType {
  notEnrolled,
  lockedOut,
  permanentlyLockedOut,
  notAvailable,
  authenticationFailed,
  cancelled,
  unknown,
}

/// User credentials model
class UserCredentials {
  final String email;
  final String password;
  final String userType;
  final String? userId;

  UserCredentials({
    required this.email,
    required this.password,
    required this.userType,
    this.userId,
  });
}