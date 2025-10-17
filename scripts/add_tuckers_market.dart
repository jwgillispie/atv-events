import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

// Mock classes for script execution
class Market {
  final String id;
  final String name;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final double latitude;
  final double longitude;
  final String? description;
  final Map<String, String> operatingDays;
  final bool isActive;
  final String? organizerId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Market({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.latitude,
    required this.longitude,
    this.description,
    this.operatingDays = const {},
    this.isActive = true,
    this.organizerId,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'operatingDays': operatingDays,
      'isActive': isActive,
      'organizerId': organizerId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : Timestamp.fromDate(createdAt),
    };
  }
}

Future<void> main() async {
  print('🌟 Adding Tucker\'s Farmers Market to HiPop Database...\n');

  try {
    // Initialize Firebase (you'll need to configure this for your project)
    await Firebase.initializeApp();
    
    final firestore = FirebaseFirestore.instance;
    final marketsCollection = firestore.collection('markets');

    // Create Tucker's Farmers Market data
    final tuckersMarket = Market(
      id: '', // Will be auto-generated
      name: 'Tucker\'s Farmers Market',
      address: '4796 LaVista Rd, Tucker, GA 30084',
      city: 'Tucker',
      state: 'GA',
      zipCode: '30084',
      latitude: 33.8567,  // Approximate coordinates for Tucker, GA
      longitude: -84.2154,
      description: 'Tucker\'s premier farmers market featuring local vendors, fresh produce, artisanal goods, and community spirit. Operating since 2010, we support local farmers and makers while bringing the community together every weekend.',
      operatingDays: {
        'saturday': '8:00 AM - 1:00 PM',
        'sunday': '10:00 AM - 2:00 PM',
      },
      isActive: true,
      organizerId: null, // Will be set when market organizer signs up
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Add to Firestore
    final docRef = await marketsCollection.add(tuckersMarket.toFirestore());
    
    print('✅ Successfully added Tucker\'s Farmers Market!');
    print('📍 Market ID: ${docRef.id}');
    print('🔗 Vendor Application Link: https://hipop.app/apply/${docRef.id}');
    print('🔗 Test Link: hipop://apply/${docRef.id}');
    
    print('\n📋 Market Details:');
    print('   Name: ${tuckersMarket.name}');
    print('   Address: ${tuckersMarket.address}');
    print('   Hours: Saturday 8AM-1PM, Sunday 10AM-2PM');
    print('   Description: ${tuckersMarket.description}');
    
    print('\n🎯 Demo Ready!');
    print('   Use this market for your Tucker\'s Farmers Market demo');
    print('   Show them the vendor application form and management system');
    print('   Market organizers can claim this market by signing up');

  } catch (e) {
    print('❌ Error adding Tucker\'s Farmers Market: $e');
    print('\n🔧 Alternative: Add this data manually through the app:');
    print('   1. Sign in as a market organizer');
    print('   2. Go to Market Management');
    print('   3. Create new market with the details above');
  }
}