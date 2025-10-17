import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

// Data classes (simplified for script use)
class Market {
  final String id;
  final String name;
  final String address;
  final String city;
  final String state;
  final double latitude;
  final double longitude;
  final Map<String, String> operatingDays;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final List<String> scheduleIds;

  Market({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.latitude,
    required this.longitude,
    required this.operatingDays,
    this.description,
    this.isActive = true,
    required this.createdAt,
    this.scheduleIds = const [],
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'operatingDays': operatingDays,
      'description': description,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'scheduleIds': scheduleIds,
    };
  }
}

class MarketSchedule {
  final String id;
  final String marketId;
  final String type;
  final String startTime;
  final String endTime;
  final List<DateTime>? specificDates;
  final String? recurrencePattern;
  final List<int>? daysOfWeek;
  final DateTime? recurrenceStartDate;
  final DateTime? recurrenceEndDate;
  final int? intervalWeeks;

  MarketSchedule({
    required this.id,
    required this.marketId,
    required this.type,
    required this.startTime,
    required this.endTime,
    this.specificDates,
    this.recurrencePattern,
    this.daysOfWeek,
    this.recurrenceStartDate,
    this.recurrenceEndDate,
    this.intervalWeeks,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'marketId': marketId,
      'type': type,
      'startTime': startTime,
      'endTime': endTime,
      'specificDates': specificDates?.map((d) => Timestamp.fromDate(d)).toList(),
      'recurrencePattern': recurrencePattern,
      'daysOfWeek': daysOfWeek,
      'recurrenceStartDate': recurrenceStartDate != null ? Timestamp.fromDate(recurrenceStartDate!) : null,
      'recurrenceEndDate': recurrenceEndDate != null ? Timestamp.fromDate(recurrenceEndDate!) : null,
      'intervalWeeks': intervalWeeks,
    };
  }
}

class ManagedVendor {
  final String id;
  final String marketId;
  final String organizerId;
  final String businessName;
  final String contactName;
  final String description;
  final List<String> categories;
  final String email;
  final String phoneNumber;
  final String? website;
  final String? instagramHandle;
  final List<String> products;
  final bool isActive;
  final bool isFeatured;
  final List<String> operatingDays;
  final DateTime createdAt;
  final DateTime updatedAt;

  ManagedVendor({
    required this.id,
    required this.marketId,
    required this.organizerId,
    required this.businessName,
    required this.contactName,
    required this.description,
    required this.categories,
    required this.email,
    required this.phoneNumber,
    this.website,
    this.instagramHandle,
    required this.products,
    this.isActive = true,
    this.isFeatured = false,
    required this.operatingDays,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'marketId': marketId,
      'organizerId': organizerId,
      'businessName': businessName,
      'contactName': contactName,
      'description': description,
      'categories': categories,
      'email': email,
      'phoneNumber': phoneNumber,
      'website': website,
      'instagramHandle': instagramHandle,
      'products': products,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'operatingDays': operatingDays,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

Future<void> main() async {
  print('🌱 Creating Mini Vegan Market...');
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  final firestore = FirebaseFirestore.instance;
  
  try {
    // Create the market
    final market = Market(
      id: '',
      name: 'Mini Vegan Market by Bien Vegano ATL',
      address: 'Liminal Space ATL (next to Sevananda), Little Five Points',
      city: 'Atlanta',
      state: 'GA',
      latitude: 33.7679, // Little Five Points coordinates
      longitude: -84.3513,
      operatingDays: {
        'sunday': '1:00 PM - 5:00 PM',
      },
      description: 'A curated pop-up full of flavor, art, and all things vegan right in the heart of Little 5 Points. Come vibe with us for an afternoon of community, creativity, and plant-based joy! 🌿',
      createdAt: DateTime.now(),
    );

    // Add market to Firestore
    final marketDoc = await firestore.collection('markets').add(market.toFirestore());
    final marketId = marketDoc.id;
    
    // Update market with its ID
    await marketDoc.update({'id': marketId});
    
    print('✅ Created market: ${market.name} (ID: $marketId)');

    // Create market schedule for specific date (July 13th, 2025)
    final schedule = MarketSchedule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      marketId: marketId,
      type: 'specificDates',
      startTime: '1:00 PM',
      endTime: '5:00 PM',
      specificDates: [DateTime(2025, 7, 13)], // Sunday, July 13th, 2025
    );

    // Add schedule to Firestore
    final scheduleDoc = await firestore.collection('market_schedules').add(schedule.toFirestore());
    final scheduleId = scheduleDoc.id;
    
    // Update schedule with its ID
    await scheduleDoc.update({'id': scheduleId});
    
    // Update market with schedule ID
    await marketDoc.update({
      'scheduleIds': [scheduleId]
    });
    
    print('✅ Created schedule for Sunday, July 13th, 2025 1-5 PM');

    // Create vendors from the post
    final vendors = [
      ManagedVendor(
        id: '',
        marketId: marketId,
        organizerId: 'demo-organizer',
        businessName: 'Mucho Amor Vegan',
        contactName: 'Mucho Amor Team',
        description: 'Irresistible vegan street tacos with bold, authentic flavor. Our plant-based tacos bring all the taste and soul of traditional Mexican street food.',
        categories: ['prepared_foods', 'mexican'],
        email: 'hello@muchoamor.vegan',
        phoneNumber: '+1-404-555-0001',
        instagramHandle: 'muchoamor.vegan',
        products: ['Vegan Street Tacos', 'Jackfruit Carnitas', 'Mushroom Al Pastor', 'Cashew Crema', 'Salsa Verde'],
        isFeatured: true,
        operatingDays: ['sunday'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ManagedVendor(
        id: '',
        marketId: marketId,
        organizerId: 'demo-organizer',
        businessName: 'The Creamy Spot',
        contactName: 'Creamy Spot Team',
        description: 'Small-batch, dairy-free ice cream made with love. We craft premium plant-based frozen treats using only the finest natural ingredients.',
        categories: ['desserts', 'ice_cream'],
        email: 'hello@thecreamyspot.com',
        phoneNumber: '+1-404-555-0002',
        instagramHandle: 'thecreamyspot',
        products: ['Vanilla Bean Ice Cream', 'Chocolate Fudge', 'Strawberry Coconut', 'Mint Chip', 'Salted Caramel'],
        isFeatured: true,
        operatingDays: ['sunday'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ManagedVendor(
        id: '',
        marketId: marketId,
        organizerId: 'demo-organizer',
        businessName: 'Pecan Milk',
        contactName: 'Pecan Milk Team',
        description: 'Creamy, refreshing plant-based milks made with clean, nourishing ingredients. Our locally-made nut milks are fresh, organic, and delicious.',
        categories: ['beverages', 'dairy_alternatives'],
        email: 'hello@pecanmilk.com',
        phoneNumber: '+1-404-555-0003',
        instagramHandle: 'pecanmilk',
        products: ['Fresh Pecan Milk', 'Almond Milk', 'Oat Milk', 'Cashew Milk', 'Vanilla Pecan Milk'],
        isFeatured: false,
        operatingDays: ['sunday'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ManagedVendor(
        id: '',
        marketId: marketId,
        organizerId: 'demo-organizer',
        businessName: 'Terra Nohpalli',
        contactName: 'Terra Artisan',
        description: 'Beautiful Mexican handmade jewelry & accessories full of culture and soul. Each piece tells a story and celebrates traditional craftsmanship.',
        categories: ['jewelry', 'crafts', 'accessories'],
        email: 'hello@terra.nohpalli',
        phoneNumber: '+1-404-555-0004',
        instagramHandle: 'terra.nohpalli',
        products: ['Silver Jewelry', 'Handmade Earrings', 'Cultural Accessories', 'Traditional Bracelets', 'Artisan Necklaces'],
        isFeatured: false,
        operatingDays: ['sunday'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ManagedVendor(
        id: '',
        marketId: marketId,
        organizerId: 'demo-organizer',
        businessName: 'Snoodie Bath Essentials',
        contactName: 'Snoodie Team',
        description: 'Luxe, cruelty-free bath & body goods for the perfect self-care moment. Our products are made with natural ingredients and lots of love.',
        categories: ['bath_body', 'self_care'],
        email: 'hello@snoodiebath.com',
        phoneNumber: '+1-404-555-0005',
        instagramHandle: 'snoodiebathessentials',
        products: ['Bath Bombs', 'Body Scrubs', 'Moisturizing Soap', 'Essential Oil Blends', 'Shower Steamers'],
        isFeatured: false,
        operatingDays: ['sunday'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ManagedVendor(
        id: '',
        marketId: marketId,
        organizerId: 'demo-organizer',
        businessName: "Let's Talk Food",
        contactName: 'Food Education Team',
        description: 'Inspiring vegan cookbooks & meal plans to elevate your kitchen game. We make plant-based cooking accessible, delicious, and fun for everyone.',
        categories: ['books', 'education', 'meal_plans'],
        email: 'hello@letstalkfood.com',
        phoneNumber: '+1-404-555-0006',
        instagramHandle: 'lets.talkfood',
        products: ['Vegan Cookbooks', 'Meal Planning Guides', 'Recipe Cards', 'Cooking Classes', 'Nutrition Guides'],
        isFeatured: false,
        operatingDays: ['sunday'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    // Add all vendors to Firestore
    for (final vendor in vendors) {
      final vendorDoc = await firestore.collection('managed_vendors').add(vendor.toFirestore());
      await vendorDoc.update({'id': vendorDoc.id});
      print('✅ Added vendor: ${vendor.businessName}');
    }

    print('\n🎉 Mini Vegan Market created successfully!');
    print('📍 Location: Little Five Points, Atlanta');
    print('📅 Date: Sunday, July 13th, 2025');
    print('🕐 Time: 1:00 PM - 5:00 PM');
    print('🌿 Vendors: ${vendors.length} awesome vegan businesses');
    print('\n💡 You can now demo this market in your app!');
    
  } catch (e) {
    print('❌ Error creating Mini Vegan Market: $e');
    exit(1);
  }
  
  exit(0);
}