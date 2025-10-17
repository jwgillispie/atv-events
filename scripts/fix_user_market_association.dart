import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hipop/features/market/models/market.dart';


// Script to fix market association for existing users
void main() async {
  await Firebase.initializeApp();
  final firestore = FirebaseFirestore.instance;
  
  print('🔍 Checking existing markets...');
  
  // First, check if any markets exist
  final marketsSnapshot = await firestore.collection('markets').get();
  print('Found ${marketsSnapshot.docs.length} existing markets');
  
  String marketId;
  
  if (marketsSnapshot.docs.isEmpty) {
    print('📍 No markets found. Creating a default Atlanta market...');
    
    // Create a default Atlanta market
    final newMarket = Market(
      id: '',
      name: 'Atlanta Farmers Market',
      address: '100 Peachtree Street NW',
      city: 'Atlanta',
      state: 'GA',
      latitude: 33.7490,
      longitude: -84.3880,
      eventDate: DateTime.now().add(const Duration(days: 7)), // Next week
      startTime: '8:00 AM',
      endTime: '2:00 PM',
      description: 'Premier farmers market in downtown Atlanta featuring local vendors, fresh produce, and artisan goods.',
      isActive: true,
      createdAt: DateTime.now(),
    );
    
    final docRef = await firestore.collection('markets').add(newMarket.toFirestore());
    marketId = docRef.id;
    
    // Update the market with its ID
    await docRef.update({'id': marketId});
    
    print('✅ Created market: ${newMarket.name} with ID: $marketId');
  } else {
    // Use the first existing market
    marketId = marketsSnapshot.docs.first.id;
    final marketData = marketsSnapshot.docs.first.data();
    print('✅ Using existing market: ${marketData['name']} with ID: $marketId');
  }
  
  print('\n👤 Looking for market organizer users to update...');
  
  // Find users with isMarketOrganizer = true but no managedMarketIds
  final usersSnapshot = await firestore
      .collection('user_profiles')
      .where('isMarketOrganizer', isEqualTo: true)
      .get();
  
  print('Found ${usersSnapshot.docs.length} market organizer users');
  
  for (final userDoc in usersSnapshot.docs) {
    final userData = userDoc.data();
    final userId = userDoc.id;
    final displayName = userData['displayName'] ?? 'Unknown User';
    final managedMarketIds = userData['managedMarketIds'] as List<dynamic>? ?? [];
    
    if (managedMarketIds.isEmpty) {
      print('🔧 Updating user: $displayName (ID: $userId)');
      
      // Update the user profile to include the market
      await firestore.collection('user_profiles').doc(userId).update({
        'managedMarketIds': [marketId],
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      print('✅ Added market $marketId to user $displayName');
    } else {
      print('⏭️  User $displayName already has markets: $managedMarketIds');
    }
  }
  
  print('\n🎉 Market association fix completed!');
  print('Your market organizer users can now access vendor and event management.');
}