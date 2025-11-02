import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../lib/firebase_options.dart';

Future<void> main() async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;

    // Get current user
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      print('❌ No user is currently logged in');
      print('Please run this script after logging in');
      return;
    }

    print('👤 Current user: ${currentUser.uid}');
    print('📧 Email: ${currentUser.email}');
    print('📝 Display name: ${currentUser.displayName}');

    // Check if user profile already exists
    final userProfileDoc = await firestore
        .collection('user_profiles')
        .doc(currentUser.uid)
        .get();

    if (userProfileDoc.exists) {
      print('✅ User profile already exists!');
      print('Profile data: ${userProfileDoc.data()}');
      return;
    }

    // Create user profile
    print('📝 Creating user profile...');
    await firestore.collection('user_profiles').doc(currentUser.uid).set({
      'userId': currentUser.uid,
      'displayName': currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'Attendee',
      'email': currentUser.email ?? '',
      'userType': 'shopper', // Default to shopper (attendee)
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isPremium': false,
      'subscriptionStatus': 'none',
    });

    print('✅ User profile created successfully!');
    print('🎉 You can now use the app normally');

  } catch (e) {
    print('❌ Error: $e');
  }
}
