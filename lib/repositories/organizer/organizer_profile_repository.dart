import 'dart:io';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/shared/models/user_profile.dart';
import '../../features/shared/services/user/user_profile_service.dart';

/// Interface for the Organizer Profile Repository
/// 
/// Defines the contract for all organizer profile operations,
/// allowing for easy testing and alternative implementations.
abstract class IOrganizerProfileRepository {
  /// Get a user profile by ID
  Future<UserProfile?> getUserProfile(String userId);
  
  /// Update an existing user profile
  Future<UserProfile> updateUserProfile(UserProfile profile);
  
  /// Upload a profile photo and return the URL
  Future<String> uploadProfilePhoto(
    String userId, 
    File file, {
    void Function(double progress)? onProgress,
  });
  
  /// Delete the user's profile photo
  Future<void> deleteProfilePhoto(String userId);
  
  /// Check if user has premium access
  Future<bool> checkPremiumAccess(String userId);
  
  /// Stream real-time profile updates
  Stream<UserProfile?> streamUserProfile(String userId);
  
  /// Ensure a user profile exists, creating if necessary
  Future<UserProfile> ensureUserProfile({
    required String userId,
    required String userType,
    String? displayName,
  });
  
  /// Invalidate cache for a specific user
  Future<void> invalidateCache(String userId);
}

/// Implementation of the Organizer Profile Repository
/// 
/// Handles all data operations for organizer profiles including
/// caching, Firebase integration, and photo management.
class OrganizerProfileRepository implements IOrganizerProfileRepository {
  final UserProfileService _profileService;
  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  
  // Cache management
  final Map<String, CachedData<UserProfile>> _profileCache = {};
  static const Duration _cacheTimeout = Duration(minutes: 5);
  
  OrganizerProfileRepository({
    UserProfileService? profileService,
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _profileService = profileService ?? UserProfileService(),
        _storage = storage ?? FirebaseStorage.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<UserProfile?> getUserProfile(String userId) async {
    // Check cache first
    final cached = _profileCache[userId];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }
    
    try {
      // Fetch from service
      final profile = await _profileService.getUserProfile(userId);
      
      // Cache the result if successful
      if (profile != null) {
        _profileCache[userId] = CachedData(
          data: profile,
          timestamp: DateTime.now(),
        );
      }
      
      return profile;
    } catch (e) {
      // Log error but don't throw - return null instead
      developer.log('Error fetching user profile: $e', name: 'OrganizerProfileRepository');
      return null;
    }
  }

  @override
  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    try {
      // Update via service
      final updatedProfile = await _profileService.updateUserProfile(profile);
      
      // Update cache
      _profileCache[profile.userId] = CachedData(
        data: updatedProfile,
        timestamp: DateTime.now(),
      );
      
      return updatedProfile;
    } catch (e) {
      throw RepositoryException('Failed to update profile: $e');
    }
  }

  @override
  Future<String> uploadProfilePhoto(
    String userId, 
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      // Validate file
      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) { // 5MB limit
        throw RepositoryException('Photo size must be less than 5MB');
      }
      
      // Create storage reference
      final storageRef = _storage.ref().child('profile_photos/$userId.jpg');
      
      // Create upload task
      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });
      
      // Wait for completion and get URL
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Update profile with photo URL
      // Note: This would need to be implemented when photoUrl field is added to UserProfile
      // For now, we'll store it in preferences or a separate collection
      await _firestore.collection('user_profiles').doc(userId).update({
        'photoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Invalidate cache to force refresh
      await invalidateCache(userId);
      
      return downloadUrl;
    } catch (e) {
      throw RepositoryException('Failed to upload photo: $e');
    }
  }

  @override
  Future<void> deleteProfilePhoto(String userId) async {
    try {
      // Delete from storage
      final storageRef = _storage.ref().child('profile_photos/$userId.jpg');
      
      try {
        await storageRef.delete();
      } catch (e) {
        // Photo might not exist, continue anyway
        developer.log('Photo deletion failed (might not exist): $e', name: 'OrganizerProfileRepository');
      }
      
      // Remove photo URL from profile
      await _firestore.collection('user_profiles').doc(userId).update({
        'photoUrl': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Invalidate cache
      await invalidateCache(userId);
    } catch (e) {
      throw RepositoryException('Failed to delete photo: $e');
    }
  }

  @override
  Future<bool> checkPremiumAccess(String userId) async {
    try {
      // Check via service
      return await _profileService.hasPremiumAccess(userId);
    } catch (e) {
      // Default to false on error
      return false;
    }
  }

  @override
  Stream<UserProfile?> streamUserProfile(String userId) {
    return _profileService.watchUserProfile(userId).handleError((error) {
      developer.log('Error streaming profile: $error', name: 'OrganizerProfileRepository');
      return null;
    });
  }

  @override
  Future<UserProfile> ensureUserProfile({
    required String userId,
    required String userType,
    String? displayName,
  }) async {
    try {
      // Check if profile exists
      UserProfile? existingProfile = await getUserProfile(userId);
      
      if (existingProfile != null) {
        return existingProfile;
      }
      
      // Get current user info from Firebase Auth
      final user = _auth.currentUser;
      if (user == null || user.uid != userId) {
        throw RepositoryException('User not authenticated or ID mismatch');
      }
      
      // Create new profile
      final newProfile = await _profileService.createUserProfile(
        userId: userId,
        userType: userType,
        email: user.email ?? '',
        displayName: displayName ?? user.displayName ?? 'Organizer',
      );
      
      // Cache the new profile
      _profileCache[userId] = CachedData(
        data: newProfile,
        timestamp: DateTime.now(),
      );
      
      return newProfile;
    } catch (e) {
      throw RepositoryException('Failed to ensure profile exists: $e');
    }
  }

  @override
  Future<void> invalidateCache(String userId) async {
    _profileCache.remove(userId);
  }
  
  /// Clear all cached data
  void clearCache() {
    _profileCache.clear();
  }
  
  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'entries': _profileCache.length,
      'userIds': _profileCache.keys.toList(),
      'expired': _profileCache.entries
          .where((e) => e.value.isExpired)
          .map((e) => e.key)
          .toList(),
    };
  }
}

/// Cached data wrapper with expiration tracking
class CachedData<T> {
  final T data;
  final DateTime timestamp;
  
  CachedData({
    required this.data,
    required this.timestamp,
  });
  
  /// Check if cache entry has expired
  bool get isExpired {
    final age = DateTime.now().difference(timestamp);
    return age > OrganizerProfileRepository._cacheTimeout;
  }
  
  /// Get age of cache entry
  Duration get age => DateTime.now().difference(timestamp);
}

/// Custom exception for repository errors
class RepositoryException implements Exception {
  final String message;
  
  RepositoryException(this.message);
  
  @override
  String toString() => 'RepositoryException: $message';
}