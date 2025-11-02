// Script to create a user profile for an existing Firebase Auth user
// Usage: node scripts/create_user_profile.js <userId> <email> <displayName> <userType>

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function createUserProfile(userId, email, displayName, userType = 'shopper') {
  try {
    console.log('👤 Creating user profile...');
    console.log(`User ID: ${userId}`);
    console.log(`Email: ${email}`);
    console.log(`Display Name: ${displayName}`);
    console.log(`User Type: ${userType}`);

    // Check if profile already exists
    const profileRef = db.collection('user_profiles').doc(userId);
    const profileDoc = await profileRef.get();

    if (profileDoc.exists) {
      console.log('✅ User profile already exists!');
      console.log('Profile data:', profileDoc.data());
      process.exit(0);
    }

    // Create the profile
    await profileRef.set({
      userId: userId,
      displayName: displayName,
      email: email,
      userType: userType,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      isPremium: false,
      subscriptionStatus: 'none',
    });

    console.log('✅ User profile created successfully!');
    console.log('🎉 User can now use the app normally');
    process.exit(0);

  } catch (error) {
    console.error('❌ Error creating user profile:', error);
    process.exit(1);
  }
}

// Get command line arguments
const args = process.argv.slice(2);

if (args.length < 3) {
  console.log('Usage: node scripts/create_user_profile.js <userId> <email> <displayName> [userType]');
  console.log('Example: node scripts/create_user_profile.js Rx3d19sh3uaPGhs2wEHzH37xs9o1 user@example.com "John Doe" shopper');
  process.exit(1);
}

const [userId, email, displayName, userType] = args;

createUserProfile(userId, email, displayName, userType);
