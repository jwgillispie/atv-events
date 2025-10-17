import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

// Mock classes for script execution
class Market {
  final String name;
  final String address;
  final String city;
  final String state;
  final double latitude;
  final double longitude;
  final String? placeId;
  final Map<String, String> operatingDays;
  final String? description;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;

  const Market({
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.operatingDays = const {},
    this.description,
    this.imageUrl,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'placeId': placeId,
      'operatingDays': operatingDays,
      'description': description,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

enum VendorCategory {
  produce,
  dairy,
  meat,
  bakery,
  prepared_foods,
  beverages,
  flowers,
  crafts,
  skincare,
  clothing,
  jewelry,
  art,
  plants,
  honey,
  preserves,
  spices,
  other,
}

class ManagedVendor {
  final String marketId;
  final String organizerId;
  final String businessName;
  final String contactName;
  final String description;
  final List<VendorCategory> categories;
  final String? imageUrl;
  final List<String> imageUrls;
  final String? logoUrl;
  final String? email;
  final String? phoneNumber;
  final String? website;
  final String? instagramHandle;
  final String? facebookHandle;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final bool canDeliver;
  final bool acceptsOrders;
  final String? deliveryNotes;
  final List<String> products;
  final List<String> specialties;
  final String? priceRange;
  final bool isOrganic;
  final bool isLocallySourced;
  final String? certifications;
  final bool isActive;
  final bool isFeatured;
  final List<String> operatingDays;
  final String? boothPreferences;
  final String? specialRequirements;
  final String? story;
  final List<String> tags;
  final String? slogan;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  const ManagedVendor({
    required this.marketId,
    required this.organizerId,
    required this.businessName,
    required this.contactName,
    required this.description,
    this.categories = const [],
    this.imageUrl,
    this.imageUrls = const [],
    this.logoUrl,
    this.email,
    this.phoneNumber,
    this.website,
    this.instagramHandle,
    this.facebookHandle,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.canDeliver = false,
    this.acceptsOrders = false,
    this.deliveryNotes,
    this.products = const [],
    this.specialties = const [],
    this.priceRange,
    this.isOrganic = false,
    this.isLocallySourced = false,
    this.certifications,
    this.isActive = true,
    this.isFeatured = false,
    this.operatingDays = const [],
    this.boothPreferences,
    this.specialRequirements,
    this.story,
    this.tags = const [],
    this.slogan,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toFirestore() {
    return {
      'marketId': marketId,
      'organizerId': organizerId,
      'businessName': businessName,
      'contactName': contactName,
      'description': description,
      'categories': categories.map((cat) => cat.name).toList(),
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'logoUrl': logoUrl,
      'email': email,
      'phoneNumber': phoneNumber,
      'website': website,
      'instagramHandle': instagramHandle,
      'facebookHandle': facebookHandle,
      'address': address,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'canDeliver': canDeliver,
      'acceptsOrders': acceptsOrders,
      'deliveryNotes': deliveryNotes,
      'products': products,
      'specialties': specialties,
      'priceRange': priceRange,
      'isOrganic': isOrganic,
      'isLocallySourced': isLocallySourced,
      'certifications': certifications,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'operatingDays': operatingDays,
      'boothPreferences': boothPreferences,
      'specialRequirements': specialRequirements,
      'story': story,
      'tags': tags,
      'slogan': slogan,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'metadata': metadata,
    };
  }
}

class VendorPost {
  final String vendorId;
  final String vendorName;
  final String description;
  final String location;
  final List<String> locationKeywords;
  final double? latitude;
  final double? longitude;
  final String? placeId;
  final String? locationName;
  final String? marketId;
  final DateTime popUpStartDateTime;
  final DateTime popUpEndDateTime;
  final String? instagramHandle;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const VendorPost({
    required this.vendorId,
    required this.vendorName,
    required this.description,
    required this.location,
    this.locationKeywords = const [],
    this.latitude,
    this.longitude,
    this.placeId,
    this.locationName,
    this.marketId,
    required this.popUpStartDateTime,
    required this.popUpEndDateTime,
    this.instagramHandle,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'vendorName': vendorName,
      'description': description,
      'location': location,
      'locationKeywords': locationKeywords,
      'latitude': latitude,
      'longitude': longitude,
      'placeId': placeId,
      'locationName': locationName,
      'marketId': marketId,
      'popUpStartDateTime': Timestamp.fromDate(popUpStartDateTime),
      'popUpEndDateTime': Timestamp.fromDate(popUpEndDateTime),
      'instagramHandle': instagramHandle,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }
}

Future<void> main() async {
  print('🌱 Adding Little 5 Points Markets for Bien Vegano to HiPop Database...\n');

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    
    final firestore = FirebaseFirestore.instance;

    // Create Little 5 Points Market for July 13th, 2025
    final market1 = Market(
      name: 'Little 5 Points Community Market at Liminal Space - July 13th',
      address: '483 Moreland Ave NE, Atlanta, GA 30307',
      city: 'Atlanta',
      state: 'GA',
      latitude: 33.7656,
      longitude: -84.3477,
      placeId: 'ChIJX8XLpTwE9YgRBvtEHCwPl8k',
      operatingDays: {
        'sunday': '1:00 PM - 5:00 PM',
      },
      description: 'A vibrant plant-based market in the heart of Little 5 Points featuring vegan vendors, handmade crafts, and community energy. Free and open to all!',
      imageUrl: 'https://example.com/little5points_market_july13.jpg',
      isActive: true,
      createdAt: DateTime.now(),
    );

    // Create Little 5 Points Market for July 20th, 2025
    final market2 = Market(
      name: 'Little 5 Points Community Market at Liminal Space - July 20th',
      address: '483 Moreland Ave NE, Atlanta, GA 30307',
      city: 'Atlanta',
      state: 'GA',
      latitude: 33.7656,
      longitude: -84.3477,
      placeId: 'ChIJX8XLpTwE9YgRBvtEHCwPl8k',
      operatingDays: {
        'sunday': '1:00 PM - 5:00 PM',
      },
      description: 'A vibrant plant-based market in the heart of Little 5 Points featuring vegan vendors, handmade crafts, and community energy. Free and open to all!',
      imageUrl: 'https://example.com/little5points_market_july20.jpg',
      isActive: true,
      createdAt: DateTime.now(),
    );

    // Save markets to Firestore
    final market1Ref = await firestore.collection('markets').add(market1.toFirestore());
    final market2Ref = await firestore.collection('markets').add(market2.toFirestore());

    print('✅ Successfully added Little 5 Points Markets!');
    print('📍 July 13th Market ID: ${market1Ref.id}');
    print('📍 July 20th Market ID: ${market2Ref.id}');

    // Create sample vegan vendors
    final vendors = [
      ManagedVendor(
        marketId: market1Ref.id,
        organizerId: 'liminal_space_organizer',
        businessName: 'Bien Vegano',
        contactName: 'Bien Vegano Team',
        email: 'hello@bienvegano.com',
        phoneNumber: '(404) 555-0123',
        address: 'Atlanta, GA',
        city: 'Atlanta',
        state: 'GA',
        zipCode: '30307',
        categories: [VendorCategory.prepared_foods, VendorCategory.beverages, VendorCategory.other],
        products: [
          'Plant-based meals',
          'Vegan desserts',
          'Cold-pressed juices',
          'Organic smoothies',
          'Raw treats'
        ],
        specialties: [
          'Handcrafted vegan cuisine',
          'Locally sourced ingredients',
          'Sustainable packaging'
        ],
        description: 'Bringing plant-based goodness and community energy to Atlanta markets. We specialize in handmade vegan foods that nourish both body and soul.',
        story: 'Born from a passion for plant-based living and community connection, Bien Vegano creates delicious vegan foods that bring people together.',
        slogan: 'Plant-based goodness, handmade magic & community energy',
        instagramHandle: 'bienvegano',
        website: 'https://bienvegano.com',
        isOrganic: true,
        isLocallySourced: true,
        certifications: 'Organic, Plant-based certified',
        operatingDays: ['sunday'],
        canDeliver: false,
        acceptsOrders: true,
        imageUrl: 'https://example.com/bien_vegano_logo.jpg',
        logoUrl: 'https://example.com/bien_vegano_logo.jpg',
        tags: ['vegan', 'organic', 'plant-based', 'handmade'],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ManagedVendor(
        marketId: market1Ref.id,
        organizerId: 'liminal_space_organizer',
        businessName: 'Green Goddess Kitchen',
        contactName: 'Maya Patel',
        email: 'maya@greengoddeskitchen.com',
        phoneNumber: '(404) 555-0456',
        address: 'Decatur, GA',
        city: 'Decatur',
        state: 'GA',
        zipCode: '30030',
        categories: [VendorCategory.prepared_foods, VendorCategory.bakery],
        products: [
          'Vegan pastries',
          'Gluten-free breads',
          'Raw energy balls',
          'Nut-based cheeses',
          'Herbal teas'
        ],
        specialties: [
          'Gluten-free vegan baking',
          'Raw food preparation',
          'Artisan nut cheeses'
        ],
        description: 'Handcrafted vegan baked goods and raw treats made with love and the finest organic ingredients.',
        instagramHandle: 'greengoddeskitchen',
        isOrganic: true,
        isLocallySourced: true,
        operatingDays: ['sunday'],
        canDeliver: true,
        acceptsOrders: true,
        imageUrl: 'https://example.com/green_goddess_logo.jpg',
        tags: ['vegan', 'gluten-free', 'raw', 'bakery'],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    // Save vendors to Firestore
    final vendorRefs = <String>[];
    for (final vendor in vendors) {
      final vendorRef = await firestore.collection('managed_vendors').add(vendor.toFirestore());
      vendorRefs.add(vendorRef.id);
    }

    // Create vendor posts for Instagram announcement
    final vendorPosts = [
      VendorPost(
        vendorId: vendorRefs[0],
        vendorName: 'Bien Vegano',
        description: 'Bien Vegano is headed to Little 5 Points this July for TWO back-to-back cozy markets! We\'re bringing all the plant-based goodness, handmade magic & community energy to this iconic ATL spot — and you don\'t want to miss it!',
        location: '483 Moreland Ave NE, Atlanta, GA 30307',
        locationKeywords: ['little 5 points', 'little five points', 'l5p', 'atlanta', 'atl', 'moreland ave', 'liminal space'],
        latitude: 33.7656,
        longitude: -84.3477,
        placeId: 'ChIJX8XLpTwE9YgRBvtEHCwPl8k',
        locationName: 'Liminal Space ATL',
        popUpStartDateTime: DateTime(2025, 7, 13, 13, 0), // July 13th, 1PM
        popUpEndDateTime: DateTime(2025, 7, 13, 17, 0),   // July 13th, 5PM
        instagramHandle: 'bienvegano',
        marketId: market1Ref.id,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      VendorPost(
        vendorId: vendorRefs[0],
        vendorName: 'Bien Vegano',
        description: 'Bien Vegano is headed to Little 5 Points this July for TWO back-to-back cozy markets! We\'re bringing all the plant-based goodness, handmade magic & community energy to this iconic ATL spot — and you don\'t want to miss it!',
        location: '483 Moreland Ave NE, Atlanta, GA 30307',
        locationKeywords: ['little 5 points', 'little five points', 'l5p', 'atlanta', 'atl', 'moreland ave', 'liminal space'],
        latitude: 33.7656,
        longitude: -84.3477,
        placeId: 'ChIJX8XLpTwE9YgRBvtEHCwPl8k',
        locationName: 'Liminal Space ATL',
        popUpStartDateTime: DateTime(2025, 7, 20, 13, 0), // July 20th, 1PM
        popUpEndDateTime: DateTime(2025, 7, 20, 17, 0),   // July 20th, 5PM
        instagramHandle: 'bienvegano',
        marketId: market2Ref.id,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    // Save vendor posts
    for (final post in vendorPosts) {
      await firestore.collection('vendor_posts').add(post.toFirestore());
    }

    print('\n🎯 Successfully added Little 5 Points market data:');
    print('   📅 2 markets (July 13th & 20th, 2025)');
    print('   🏪 ${vendors.length} vegan vendors');
    print('   📱 ${vendorPosts.length} Instagram post announcements');
    
    print('\n📋 Market Details:');
    print('   📍 Location: 483 Moreland Ave NE, Atlanta, GA 30307');
    print('   ⏰ Time: 1:00 PM - 5:00 PM both days');
    print('   🌱 Focus: Plant-based vendors & community energy');
    print('   💰 Entry: Free & open to all');

    print('\n🌟 Bien Vegano Instagram Post Data Created!');
    print('   Use these market IDs to showcase the vendor experience');
    print('   Perfect for demonstrating the community market features');

  } catch (e) {
    print('❌ Error adding Little 5 Points markets: $e');
    print('\n🔧 Alternative: Add this data manually through the app');
  }
}