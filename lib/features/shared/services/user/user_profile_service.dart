import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:atv_events/features/shared/models/user_profile.dart';

abstract class IUserProfileService {
  Future<UserProfile?> getUserProfile(String userId);
  Future<UserProfile> createUserProfile({
    required String userId,
    required String userType,
    required String email,
    String? displayName,
  });
  Future<UserProfile> updateUserProfile(UserProfile profile);
  Future<void> deleteUserProfile(String userId);
  Stream<UserProfile?> watchUserProfile(String userId);
}

class UserProfileService implements IUserProfileService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  static const String _collection = 'user_profiles';

  UserProfileService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      
      // Check if we can get an ID token
      try {
        final token = await _auth.currentUser?.getIdToken();
        if (token != null) {
        }
      } catch (tokenError) {
      }
      
      // Test with a simple read first
      final testQuery = await _firestore.collection('test').limit(1).get();
      
      final doc = await _firestore.collection(_collection).doc(userId).get();
      
      
      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      }
      
      // Handle missing user profile gracefully
      
      // If this is the current authenticated user and they don't have a profile,
      // sign them out to force re-authentication/profile creation
      if (_auth.currentUser?.uid == userId) {
        
        // Sign out the user with missing profile
        try {
          await _auth.signOut();
        } catch (signOutError) {
        }
      }
      
      return null;
    } catch (e) {
      developer.log('Error getting user profile: $e', name: 'UserProfileService');
      if (kIsWeb) {
        // Also log to browser console for web
        // ignore: avoid_print
      }
      rethrow;
    }
  }

  @override
  Future<UserProfile> createUserProfile({
    required String userId,
    required String userType,
    required String email,
    String? displayName,
  }) async {
    try {
      final now = DateTime.now();
      final profile = UserProfile(
        userId: userId,
        userType: userType,
        email: email,
        displayName: displayName,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore.collection(_collection).doc(userId).set(profile.toFirestore());
      
      return profile;
    } catch (e) {
      developer.log('Error creating user profile: $e', name: 'UserProfileService');
      if (kIsWeb) {
        // ignore: avoid_print
      }
      throw UserProfileException('Failed to create user profile: $e');
    }
  }

  @override
  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    try {
      final updatedProfile = profile.copyWith(updatedAt: DateTime.now());
      
      await _firestore
          .collection(_collection)
          .doc(profile.userId)
          .update(updatedProfile.toFirestore());

      // Also update Firebase Auth display name if it changed
      final user = _auth.currentUser;
      if (user != null && 
          user.uid == profile.userId && 
          user.displayName != updatedProfile.displayName) {
        await user.updateDisplayName(updatedProfile.displayName);
        await user.reload();
      }

      return updatedProfile;
    } catch (e) {
      developer.log('Error updating user profile: $e', name: 'UserProfileService');
      if (kIsWeb) {
        // ignore: avoid_print
      }
      throw UserProfileException('Failed to update user profile: $e');
    }
  }

  @override
  Future<void> deleteUserProfile(String userId) async {
    try {
      
      // Get user profile to understand what type of user this is
      final profile = await getUserProfile(userId);
      if (profile == null) {
      }
      
      // Start a batch operation for atomic deletion
      final batch = _firestore.batch();
      
      // 1. Delete user profile
      batch.delete(_firestore.collection(_collection).doc(userId));
      
      if (profile?.isMarketOrganizer == true) {
        
        // 2. Delete or transfer managed markets
        if (profile!.managedMarketIds.isNotEmpty) {
          for (final marketId in profile.managedMarketIds) {
            // Delete market and associated data
            batch.delete(_firestore.collection('markets').doc(marketId));
            
            // Delete vendor applications for this market
            final vendorApps = await _firestore
                .collection('vendor_applications')
                .where('marketId', isEqualTo: marketId)
                .get();
            
            for (final app in vendorApps.docs) {
              batch.delete(app.reference);
            }
          }
        }
        
        // 3. Delete managed vendors
        final managedVendors = await _firestore
            .collection('managed_vendors')
            .where('organizerId', isEqualTo: userId)
            .get();
        
        for (final vendor in managedVendors.docs) {
          batch.delete(vendor.reference);
        }
      }
      
      if (profile?.userType == 'vendor') {
        
        // 4. Delete vendor posts
        final vendorPosts = await _firestore
            .collection('vendor_posts')
            .where('vendorId', isEqualTo: userId)
            .get();
        
        for (final post in vendorPosts.docs) {
          batch.delete(post.reference);
        }
        
        // 5. Delete vendor products
        final vendorProducts = await _firestore
            .collection('vendor_products')
            .where('vendorId', isEqualTo: userId)
            .get();
        
        for (final product in vendorProducts.docs) {
          batch.delete(product.reference);
        }
        
        // 6. Delete vendor product lists
        final productLists = await _firestore
            .collection('vendor_product_lists')
            .where('vendorId', isEqualTo: userId)
            .get();
        
        for (final list in productLists.docs) {
          batch.delete(list.reference);
        }
        
        // 7. Delete vendor applications
        final applications = await _firestore
            .collection('vendor_applications')
            .where('vendorId', isEqualTo: userId)
            .get();
        
        for (final app in applications.docs) {
          batch.delete(app.reference);
        }
      }
      
      // 8. Delete user feedback
      final feedback = await _firestore
          .collection('user_feedback')
          .where('userId', isEqualTo: userId)
          .get();
      
      for (final fb in feedback.docs) {
        batch.delete(fb.reference);
      }
      
      // 9. Delete analytics data (if any)
      final analytics = await _firestore
          .collection('user_analytics')
          .where('userId', isEqualTo: userId)
          .get();
      
      for (final analytic in analytics.docs) {
        batch.delete(analytic.reference);
      }
      
      // Execute all deletions atomically
      await batch.commit();
      
      
    } catch (e) {
      throw UserProfileException('Failed to delete user profile and associated data: $e');
    }
  }

  @override
  Stream<UserProfile?> watchUserProfile(String userId) {
    return _firestore
        .collection(_collection)
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return UserProfile.fromFirestore(doc);
          }
          return null;
        });
  }

  // Helper method to create or get profile for current user
  Future<UserProfile> ensureUserProfile({
    required String userType,
    String? displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw UserProfileException('No authenticated user');
    }

    // Try to get existing profile
    UserProfile? profile = await getUserProfile(user.uid);
    
    profile ??= await createUserProfile(
        userId: user.uid,
        userType: userType,
        email: user.email ?? '',
        displayName: displayName ?? user.displayName,
      );

    return profile;
  }

  // Helper method to update only specific fields
  Future<UserProfile> updateUserProfileFields(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final profile = await getUserProfile(userId);
      if (profile == null) {
        throw UserProfileException('User profile not found');
      }

      // Add updatedAt timestamp
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());

      await _firestore
          .collection(_collection)
          .doc(userId)
          .update(updates);

      // Return updated profile
      final updatedProfile = await getUserProfile(userId);
      if (updatedProfile == null) {
        throw UserProfileException('Failed to retrieve updated profile');
      }

      return updatedProfile;
    } catch (e) {
      throw UserProfileException('Failed to update profile fields: $e');
    }
  }

  // Helper method to check if profile exists
  Future<bool> profileExists(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Helper method to get profiles by user type
  Future<List<UserProfile>> getProfilesByUserType(String userType) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userType', isEqualTo: userType)
          .get();

      return querySnapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Helper method to search profiles by display name or business name
  Future<List<UserProfile>> searchProfiles(String searchTerm) async {
    try {
      if (searchTerm.isEmpty) return [];

      final searchLower = searchTerm.toLowerCase();
      
      // Get all profiles and filter client-side since Firestore doesn't support
      // case-insensitive or contains queries natively
      final querySnapshot = await _firestore.collection(_collection).get();
      
      final profiles = querySnapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .where((profile) {
            final displayName = profile.displayName?.toLowerCase() ?? '';
            final businessName = profile.businessName?.toLowerCase() ?? '';
            final email = profile.email.toLowerCase();
            
            return displayName.contains(searchLower) ||
                   businessName.contains(searchLower) ||
                   email.contains(searchLower);
          })
          .toList();

      return profiles;
    } catch (e) {
      return [];
    }
  }

  // Helper method to get vendor profiles with categories
  Future<List<UserProfile>> getVendorsByCategory(String category) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userType', isEqualTo: 'vendor')
          .where('categories', arrayContains: category)
          .get();

      return querySnapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Helper method to migrate existing user to profile system
  Future<UserProfile?> migrateUserToProfile(User user, String userType) async {
    try {
      // Check if profile already exists
      final existingProfile = await getUserProfile(user.uid);
      if (existingProfile != null) {
        return existingProfile;
      }

      // Create new profile from Firebase Auth user
      return await createUserProfile(
        userId: user.uid,
        userType: userType,
        email: user.email ?? '',
        displayName: user.displayName,
      );
    } catch (e) {
      return null;
    }
  }

  // Administrative function to fix market organizer associations
  Future<void> fixMarketOrganizerAssociations() async {
    try {
      
      // First, check if any markets exist
      final marketsSnapshot = await _firestore.collection('markets').get();
      
      String marketId;
      
      // Check if user already has a market based on their email/name
      String? existingUserMarketId;
      final user = _auth.currentUser;
      
      if (user != null) {
        // Look for a market that might belong to this user
        for (final marketDoc in marketsSnapshot.docs) {
          final marketData = marketDoc.data();
          final marketName = marketData['name'] as String? ?? '';
          final userEmail = user.email ?? '';
          
          // Check if market name contains user's name or email prefix
          final emailPrefix = userEmail.split('@').first.toLowerCase();
          if (marketName.toLowerCase().contains('jozo') || 
              marketName.toLowerCase().contains(emailPrefix)) {
            existingUserMarketId = marketDoc.id;
            break;
          }
        }
      }
      
      if (existingUserMarketId != null) {
        marketId = existingUserMarketId;
      } else {
        // Create a personalized market for this user
        final user = _auth.currentUser;
        final userEmail = user?.email ?? 'organizer@example.com';
        final emailPrefix = userEmail.split('@').first;
        final marketName = emailPrefix.contains('jozo') ? 'JOZO Market' : '${emailPrefix.toUpperCase()} Market';
        
        
        final marketData = {
          'name': marketName,
          'address': '123 Market Street',
          'city': 'Atlanta',
          'state': 'GA',
          'latitude': 33.7490,
          'longitude': -84.3880,
          'operatingDays': {
            'saturday': '8:00 AM - 2:00 PM',
            'sunday': '10:00 AM - 4:00 PM',
          },
          'description': 'Local farmers market featuring fresh, quality vendors and artisan goods.',
          'isActive': true,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        };
        
        final docRef = await _firestore.collection('markets').add(marketData);
        marketId = docRef.id;
        
        // Update the market with its ID
        await docRef.update({'id': marketId});
        
      }
      
      
      // Find users with userType = 'market_organizer' but no managedMarketIds
      final usersSnapshot = await _firestore
          .collection(_collection)
          .where('userType', isEqualTo: 'market_organizer')
          .get();
      
      
      int updatedCount = 0;
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userId = userDoc.id;
        final displayName = userData['displayName'] ?? userData['organizationName'] ?? 'Unknown User';
        final managedMarketIds = List<String>.from(userData['managedMarketIds'] ?? []);
        
        if (managedMarketIds.isEmpty) {
          
          // Update the user profile to include the market
          await _firestore.collection(_collection).doc(userId).update({
            'managedMarketIds': [marketId],
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
          
          updatedCount++;
        } else {
        }
      }
      
    } catch (e) {
      throw UserProfileException('Failed to fix market associations: $e');
    }
  }

  // Helper method to get current user ID
  Future<String?> getCurrentUserId() async {
    final user = _auth.currentUser;
    return user?.uid;
  }

  // Helper method to get current user profile
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    return await getUserProfile(user.uid);
  }

  // Helper method to create missing organizer profile
  Future<UserProfile> createMissingOrganizerProfile(String userId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw UserProfileException('No authenticated user');
      }

      
      return await createUserProfile(
        userId: userId,
        userType: 'market_organizer',
        email: user.email ?? '',
        displayName: user.displayName ?? 'Market Organizer',
      );
    } catch (e) {
      throw UserProfileException('Failed to create missing organizer profile: $e');
    }
  }

  // Helper method to fix existing managed vendors with old placeholder IDs
  Future<void> fixExistingManagedVendors() async {
    try {
      
      final user = _auth.currentUser;
      if (user == null) {
        throw UserProfileException('No authenticated user');
      }

      // Get the current user's profile to find their real market ID
      final userProfile = await getUserProfile(user.uid);
      if (userProfile == null || !userProfile.isMarketOrganizer || userProfile.managedMarketIds.isEmpty) {
        return;
      }

      final realMarketId = userProfile.managedMarketIds.first;
      final realOrganizerId = user.uid;


      // Find managed vendors with placeholder IDs OR belonging to this user
      final tempMarketVendors = await _firestore
          .collection('managed_vendors')
          .where('marketId', isEqualTo: 'temp_market_id')
          .get();

      final placeholderOrganizerVendors = await _firestore
          .collection('managed_vendors')
          .where('organizerId', isEqualTo: 'current_organizer_id')
          .get();

      final userEmailVendors = await _firestore
          .collection('managed_vendors')
          .where('email', isEqualTo: user.email)
          .get();

      // Combine all potential vendors
      final allVendorDocs = <QueryDocumentSnapshot>[];
      allVendorDocs.addAll(tempMarketVendors.docs);
      allVendorDocs.addAll(placeholderOrganizerVendors.docs);
      allVendorDocs.addAll(userEmailVendors.docs);

      // Remove duplicates
      final uniqueVendorDocs = <String, QueryDocumentSnapshot>{};
      for (final doc in allVendorDocs) {
        uniqueVendorDocs[doc.id] = doc;
      }


      int updatedCount = 0;
      for (final vendorDoc in uniqueVendorDocs.values) {
        final vendorData = vendorDoc.data() as Map<String, dynamic>;
        final vendorId = vendorDoc.id;
        final businessName = vendorData['businessName'] ?? 'Unknown Vendor';

        // Check if this vendor belongs to the current user (by organizer ID or email)
        final vendorOrganizerId = vendorData['organizerId'];
        final vendorEmail = vendorData['email'];
        
        if (vendorOrganizerId == 'current_organizer_id' || 
            vendorOrganizerId == realOrganizerId ||
            vendorEmail == user.email) {
          
          
          // Update the vendor with real IDs
          await _firestore.collection('managed_vendors').doc(vendorId).update({
            'marketId': realMarketId,
            'organizerId': realOrganizerId,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
          
          updatedCount++;
        }
      }

    } catch (e) {
      throw UserProfileException('Failed to fix existing managed vendors: $e');
    }
  }

  /// Upgrade user to premium subscription
  Future<UserProfile> upgradeToPremium({
    required String userId,
    required String stripeCustomerId,
    required String stripeSubscriptionId,
    required String stripePriceId,
  }) async {
    try {
      
      final profile = await getUserProfile(userId);
      if (profile == null) {
        throw UserProfileException('User profile not found for userId: $userId');
      }
      

      final upgradedProfile = profile.copyWith(
        isPremium: true,
        stripeCustomerId: stripeCustomerId,
        stripeSubscriptionId: stripeSubscriptionId,
        stripePriceId: stripePriceId,
        subscriptionStartDate: DateTime.now(),
        subscriptionStatus: 'active',
        updatedAt: DateTime.now(),
      );

      
      await _firestore
          .collection(_collection)
          .doc(userId)
          .update(upgradedProfile.toFirestore());

      
      return upgradedProfile;
    } catch (e) {
      throw UserProfileException('Failed to upgrade to premium: $e');
    }
  }

  /// Check if user has premium access
  Future<bool> hasPremiumAccess(String userId) async {
    try {
      final profile = await getUserProfile(userId);
      return profile?.isPremium == true;
    } catch (e) {
      return false;
    }
  }
}

class UserProfileException implements Exception {
  final String message;
  
  UserProfileException(this.message);
  
  @override
  String toString() => 'UserProfileException: $message';
}