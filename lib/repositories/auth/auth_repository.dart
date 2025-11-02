import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class IAuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<UserCredential> signInWithEmailAndPassword(String email, String password);
  Future<UserCredential> createUserWithEmailAndPassword(String email, String password);
  Future<void> signOut();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification();
  Future<void> reloadUser();
  Future<void> updateDisplayName(String displayName);
}

class AuthRepository implements IAuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update last login timestamp in user_profiles
      if (userCredential.user != null) {
        await updateLastLogin(userCredential.user!.uid);
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      throw AuthException('An unexpected error occurred. Please try again.');
    }
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      throw AuthException('An unexpected error occurred. Please try again.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw AuthException('Failed to sign out. Please try again.');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      throw AuthException('Failed to send password reset email. Please try again.');
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      throw AuthException('Failed to send verification email. Please try again.');
    }
  }

  @override
  Future<void> reloadUser() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.reload();
      }
    } catch (e) {
      throw AuthException('Failed to reload user. Please try again.');
    }
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.reload();
      }
    } catch (e) {
      throw AuthException('Failed to update display name. Please try again.');
    }
  }

  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
    required String userType,
  }) async {
    try {
      // Check if user is from Atlanta Tech Village
      final isAtlantaTechVillage = email.toLowerCase().endsWith('@atlantatechvillage.com');

      // Base profile data
      final profileData = <String, dynamic>{
        'userId': uid,
        'displayName': name,
        'email': email,
        'userType': userType,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'managedMarketIds': userType == 'market_organizer' ? [] : null,
        'categories': userType == 'vendor' ? [] : null,
        'ccEmails': userType == 'market_organizer' ? [] : null,
      };

      // Auto-grant full permissions for Atlanta Tech Village users
      if (isAtlantaTechVillage) {
        profileData.addAll({
          'organization': 'atlanta_tech_village',
          'organizationDomain': 'atlantatechvillage.com',
          'canPostEvents': true,
          'canPostProducts': true,
          'canCollectPayments': true,
          'isAdmin': false,
          'verificationStatus': 'approved', // Auto-approve ATV users
          'autoApproved': true,
          'permissionsGrantedBy': 'system',
          'permissionsGrantedAt': FieldValue.serverTimestamp(),
          'verifiedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Default permissions for non-ATV users
        profileData.addAll({
          'canPostEvents': false,
          'canPostProducts': false,
          'canCollectPayments': false,
          'isAdmin': false,
        });
      }

      // Create user profile in the user_profiles collection
      await _firestore.collection('user_profiles').doc(uid).set(
        profileData,
        SetOptions(merge: true),
      );
    } catch (e) {
      if (e is FirebaseException) {
        throw AuthException('Firebase error: ${e.message ?? 'Unknown Firebase error'}');
      }
      throw AuthException('Failed to create user profile: $e');
    }
  }
  
  Future<void> updateLastLogin(String uid) async {
    try {
      await _firestore.collection('user_profiles').doc(uid).update({
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently handle errors when updating last login
    }
  }

  // Phone Authentication Methods
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) codeSent,
    required Function(PhoneAuthCredential credential) verificationCompleted,
    required Function(FirebaseAuthException e) verificationFailed,
    required Function(String verificationId) codeAutoRetrievalTimeout,
    int? resendToken,
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
    );
  }

  Future<UserCredential> signInWithPhoneCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await _firebaseAuth.signInWithCredential(credential);

      // Update or create user profile for phone auth users
      if (userCredential.user != null) {
        final uid = userCredential.user!.uid;
        final userDoc = await _firestore.collection('user_profiles').doc(uid).get();

        if (!userDoc.exists) {
          // Create minimal profile for phone users
          await _firestore.collection('user_profiles').doc(uid).set({
            'uid': uid,
            'phoneNumber': userCredential.user!.phoneNumber ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'userType': 'shopper', // Default to shopper, can be updated later
          });
        } else {
          // Update last login
          await updateLastLogin(uid);
        }
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  Future<void> linkPhoneNumber(PhoneAuthCredential credential) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw AuthException('No user logged in');
      }
      
      await user.linkWithCredential(credential);
      
      // Update user profile with phone number
      await _firestore.collection('user_profiles').doc(user.uid).update({
        'phoneNumber': user.phoneNumber ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        throw AuthException('A phone number is already linked to this account');
      } else if (e.code == 'credential-already-in-use') {
        throw AuthException('This phone number is already associated with another account');
      }
      throw _mapFirebaseAuthException(e);
    }
  }

  AuthException _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return AuthException('No user found with this email address.');
      case 'wrong-password':
        return AuthException('Incorrect password. Please try again.');
      case 'email-already-in-use':
        return AuthException('An account already exists with this email address.');
      case 'weak-password':
        return AuthException('Password is too weak. Please choose a stronger password.');
      case 'invalid-email':
        return AuthException('Please enter a valid email address.');
      case 'user-disabled':
        return AuthException('This account has been disabled. Please contact support.');
      case 'too-many-requests':
        return AuthException('Too many failed attempts. Please try again later.');
      case 'network-request-failed':
        return AuthException('Network error. Please check your connection and try again.');
      case 'invalid-credential':
        return AuthException('Invalid email or password. Please try again.');
      default:
        return AuthException('Authentication failed: ${e.message}');
    }
  }
}

class AuthException implements Exception {
  final String message;
  
  AuthException(this.message);
  
  @override
  String toString() => message;
}