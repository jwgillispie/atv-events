import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'dart:math';

enum DataVolume { quick, standard, full }

class DebugMasterDataGenerator extends StatefulWidget {
  const DebugMasterDataGenerator({super.key});

  @override
  State<DebugMasterDataGenerator> createState() => _DebugMasterDataGeneratorState();
}

class _DebugMasterDataGeneratorState extends State<DebugMasterDataGenerator> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  bool _isGenerating = false;
  String _status = '';
  String _detailedLog = '';
  DataVolume _selectedVolume = DataVolume.standard;

  // Track created IDs for relationships
  List<String> _createdMarketIds = [];
  List<String> _createdVendorIds = [];
  List<String> _createdPostIds = [];
  List<String> _createdProductIds = [];
  List<String> _createdProductListIds = [];
  Map<String, List<String>> _marketVendorMap = {}; // marketId -> vendorIds
  Map<String, List<String>> _vendorProductMap = {}; // vendorId -> productIds
  Map<String, List<String>> _vendorProductListMap = {}; // vendorId -> productListIds

  // Get current user (market organizer)
  String get _organizerId => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Data volumes
  Map<DataVolume, Map<String, int>> _volumes = {
    DataVolume.quick: {
      'markets': 2,
      'vendorsPerMarket': 3,
      'postsPerVendor': 2,
      'eventsPerMarket': 1,
      'reviewsPerMarket': 3,
      'reviewsPerVendor': 2,
      'favorites': 10,
      'views': 50,
    },
    DataVolume.standard: {
      'markets': 5,
      'vendorsPerMarket': 5,
      'postsPerVendor': 3,
      'eventsPerMarket': 2,
      'reviewsPerMarket': 5,
      'reviewsPerVendor': 3,
      'favorites': 25,
      'views': 150,
    },
    DataVolume.full: {
      'markets': 10,
      'vendorsPerMarket': 8,
      'postsPerVendor': 5,
      'eventsPerMarket': 3,
      'reviewsPerMarket': 10,
      'reviewsPerVendor': 5,
      'favorites': 50,
      'views': 300,
    },
  };

  // Atlanta-specific data
  final List<Map<String, dynamic>> _atlantaMarkets = [
    {
      'name': 'Ponce City Market Weekend Pop-Up',
      'address': '675 Ponce de Leon Ave NE',
      'neighborhood': 'Old Fourth Ward',
      'type': 'popup',
      'description': 'Curated weekend market featuring local artisans and food vendors in the heart of Atlanta.',
    },
    {
      'name': 'Grant Park Farmers Market',
      'address': '600 Cherokee Ave SE',
      'neighborhood': 'Grant Park',
      'type': 'farmers',
      'description': 'Fresh, locally grown produce and artisanal goods every Sunday morning.',
    },
    {
      'name': 'Krog Street Night Market',
      'address': '99 Krog Street NE',
      'neighborhood': 'Inman Park',
      'type': 'night',
      'description': 'Evening market with food trucks, craft vendors, and live music under the lights.',
    },
    {
      'name': 'BeltLine Artisan Market',
      'address': 'Atlanta BeltLine Eastside Trail',
      'neighborhood': 'Virginia-Highland',
      'type': 'art',
      'description': 'Art and crafts market along the scenic BeltLine trail.',
    },
    {
      'name': 'Little Five Points Vintage Bazaar',
      'address': 'Findley Plaza, Little Five Points',
      'neighborhood': 'Little Five Points',
      'type': 'vintage',
      'description': 'Eclectic mix of vintage clothing, vinyl records, and unique handmade items.',
    },
    {
      'name': 'Piedmont Park Green Market',
      'address': 'Piedmont Park, 12th Street Entrance',
      'neighborhood': 'Midtown',
      'type': 'green',
      'description': 'Sustainable and eco-friendly vendors in Atlanta\'s favorite park.',
    },
    {
      'name': 'West End Arts & Eats Market',
      'address': 'Lee Street & Ralph David Abernathy Blvd',
      'neighborhood': 'West End',
      'type': 'community',
      'description': 'Community-focused market celebrating local culture, food, and art.',
    },
    {
      'name': 'Decatur Square Saturday Market',
      'address': '101 E Court Square',
      'neighborhood': 'Decatur',
      'type': 'traditional',
      'description': 'Traditional market with farm-fresh produce and local crafts in historic Decatur.',
    },
    {
      'name': 'Atlantic Station Holiday Market',
      'address': '1380 Atlantic Dr NW',
      'neighborhood': 'Atlantic Station',
      'type': 'holiday',
      'description': 'Seasonal market with holiday crafts, gifts, and festive treats.',
    },
    {
      'name': 'East Atlanta Village Pop-Up',
      'address': '469 Flat Shoals Ave SE',
      'neighborhood': 'East Atlanta Village',
      'type': 'popup',
      'description': 'Hip neighborhood market with indie vendors and food trucks.',
    },
  ];

  final List<Map<String, dynamic>> _vendorProfiles = [
    {
      'business': 'Peachtree Jewelry Co',
      'name': 'Sarah Mitchell',
      'category': 'jewelry',
      'products': ['Handmade necklaces', 'Silver rings', 'Custom bracelets', 'Earrings'],
      'description': 'Handcrafted jewelry inspired by Southern charm and modern elegance.',
      'tags': ['handmade', 'local', 'woman-owned'],
    },
    {
      'business': 'Georgia Grown Produce',
      'name': 'Mike Thompson',
      'category': 'produce',
      'products': ['Organic vegetables', 'Fresh fruits', 'Herbs', 'Honey'],
      'description': 'Farm-fresh produce from our family farm in North Georgia.',
      'tags': ['organic', 'local', 'sustainable'],
    },
    {
      'business': 'Southern Soap Works',
      'name': 'Jessica Lee',
      'category': 'beauty',
      'products': ['Natural soaps', 'Bath bombs', 'Body butter', 'Candles'],
      'description': 'All-natural bath and body products made with love in Atlanta.',
      'tags': ['natural', 'eco-friendly', 'handmade'],
    },
    {
      'business': 'ATL Vintage Threads',
      'name': 'David Brown',
      'category': 'clothing',
      'products': ['Vintage t-shirts', 'Retro jackets', 'Accessories', 'Hats'],
      'description': 'Curated vintage clothing from the 70s, 80s, and 90s.',
      'tags': ['vintage', 'sustainable', 'unique'],
    },
    {
      'business': 'Fox Bros BBQ Cart',
      'name': 'Brian Fox',
      'category': 'food',
      'products': ['BBQ sandwiches', 'Smoked meats', 'Sides', 'Sauces'],
      'description': 'Award-winning Texas-style BBQ with a Southern twist.',
      'tags': ['food', 'local-favorite', 'award-winning'],
    },
    {
      'business': 'Dancing Goats Coffee',
      'name': 'Emily Chen',
      'category': 'beverages',
      'products': ['Coffee beans', 'Cold brew', 'Espresso drinks', 'Pastries'],
      'description': 'Locally roasted coffee and artisanal pastries.',
      'tags': ['coffee', 'local', 'artisan'],
    },
    {
      'business': 'Red Clay Pottery',
      'name': 'Tom Wilson',
      'category': 'art',
      'products': ['Ceramic bowls', 'Mugs', 'Vases', 'Custom pieces'],
      'description': 'Handmade pottery using traditional Georgia red clay.',
      'tags': ['handmade', 'art', 'local'],
    },
    {
      'business': 'King of Pops Cart',
      'name': 'Steven Carse',
      'category': 'food',
      'products': ['Fruit pops', 'Cream pops', 'Seasonal flavors'],
      'description': 'Fresh fruit popsicles made with locally sourced ingredients.',
      'tags': ['dessert', 'local', 'summer-favorite'],
    },
  ];

  final List<String> _reviewTexts = [
    "Amazing market! Great variety of vendors and wonderful atmosphere.",
    "Love the selection here. Always find unique items you can't get anywhere else.",
    "Well organized, friendly vendors, and great products. Will definitely be back!",
    "The best farmers market in Atlanta! Fresh produce and great prices.",
    "Such a fun experience! Live music, good food, and amazing crafts.",
    "Perfect weekend activity. Kid-friendly and dog-friendly too!",
    "Outstanding quality from all vendors. You can tell everything is made with care.",
    "Great community vibe. Love supporting local businesses here.",
    "Always something new to discover. My favorite Saturday morning spot.",
    "Excellent variety of food trucks and craft vendors. Something for everyone!",
  ];

  final List<String> _eventTypes = [
    'Live Music Festival',
    'Food Truck Friday',
    'Artisan Showcase',
    'Holiday Special Market',
    'Kids Craft Day',
    'Wine & Art Night',
    'Vintage Pop-Up',
    'Farm to Table Dinner',
    'Maker Workshop',
    'Community Celebration',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity( 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Text(
                'MASTER DATA GENERATOR',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity( 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DEBUG ONLY',
                  style: TextStyle(color: Colors.red, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Volume selector
          Row(
            children: [
              const Text('Data Volume: ', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 8),
              ...DataVolume.values.map((volume) =>
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(volume.name.toUpperCase()),
                    selected: _selectedVolume == volume,
                    onSelected: _isGenerating ? null : (selected) {
                      if (selected) setState(() => _selectedVolume = volume);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Data summary
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getVolumeSummary(),
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateCompleteDemo,
                  icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.rocket_launch),
                  label: Text(_isGenerating ? 'Generating...' : 'GENERATE COMPLETE DEMO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isGenerating ? null : () => _showCleanupConfirmation(context),
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                tooltip: 'Delete All Data (Preserves 3 Test Accounts)',
              ),
            ],
          ),

          // Status display
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Text(
                  _status,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ],

          // Detailed log (expandable)
          if (_detailedLog.isNotEmpty) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Detailed Log', style: TextStyle(fontSize: 12)),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _detailedLog,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: Colors.white60,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getVolumeSummary() {
    final vol = _volumes[_selectedVolume]!;
    return 'Will create: ${vol['markets']} markets, '
           '${vol['markets']! * vol['vendorsPerMarket']!} vendors, '
           '${vol['markets']! * vol['vendorsPerMarket']! * vol['postsPerVendor']!} posts, '
           '${vol['markets']! * vol['eventsPerMarket']!} events, '
           '${vol['markets']! * vol['reviewsPerMarket']! + vol['markets']! * vol['vendorsPerMarket']! * vol['reviewsPerVendor']!} reviews';
  }

  void _updateStatus(String message, {bool isError = false}) {
    setState(() {
      _status = message;
      _detailedLog += '${DateTime.now().toLocal()}: $message\n';
      if (isError) {
        _status = '❌ $message';
      }
    });
  }

  Future<void> _generateCompleteDemo() async {
    if (_organizerId.isEmpty) {
      _updateStatus('Error: No user logged in!', isError: true);
      return;
    }

    setState(() {
      _isGenerating = true;
      _status = 'Starting generation...';
      _detailedLog = '';
      _createdMarketIds.clear();
      _createdVendorIds.clear();
      _createdPostIds.clear();
      _createdProductIds.clear();
      _createdProductListIds.clear();
      _marketVendorMap.clear();
      _vendorProductMap.clear();
      _vendorProductListMap.clear();
    });

    try {
      // 1. Create Markets
      _updateStatus('📍 Creating markets...');
      await _createMarkets();

      // 2. Create Managed Vendors
      _updateStatus('👥 Creating managed vendors...');
      await _createManagedVendors();

      // 3. Create Vendor Products
      _updateStatus('🛍️ Creating vendor products...');
      await _createVendorProducts();

      // 4. Create Product Lists
      _updateStatus('📋 Creating product lists...');
      await _createProductLists();

      // 5. Create Vendor Posts with product lists
      _updateStatus('📝 Creating vendor posts...');
      await _createVendorPosts();

      // 6. Create Events
      _updateStatus('🎉 Creating events...');
      await _createEvents();

      // 7. Create Reviews
      _updateStatus('⭐ Creating reviews...');
      await _createReviews();

      // 8. Create Engagement Data
      _updateStatus('❤️ Creating engagement data...');
      await _createEngagementData();

      // 9. Create Analytics Data
      _updateStatus('📊 Creating analytics data...');
      await _createAnalyticsData();

      _updateStatus('✅ COMPLETE! Demo data generated successfully.\n'
                   'Created: ${_createdMarketIds.length} markets, '
                   '${_createdVendorIds.length} vendors, '
                   '${_createdProductIds.length} products, '
                   '${_createdProductListIds.length} product lists, '
                   '${_createdPostIds.length} posts');

    } catch (e) {
      _updateStatus('Error: $e', isError: true);
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _createMarkets() async {
    final count = _volumes[_selectedVolume]!['markets']!;

    for (int i = 0; i < count && i < _atlantaMarkets.length; i++) {
      final marketData = _atlantaMarkets[i];
      final eventDate = _getRandomFutureDate();

      final docRef = await _firestore.collection('markets').add({
        'organizerId': _organizerId,
        'name': marketData['name'],
        'description': marketData['description'],
        'address': marketData['address'],
        'neighborhood': marketData['neighborhood'],
        'city': 'Atlanta',
        'state': 'GA',
        'latitude': 33.7490 + (_random.nextDouble() - 0.5) * 0.2,
        'longitude': -84.3880 + (_random.nextDouble() - 0.5) * 0.2,
        'eventDate': Timestamp.fromDate(eventDate),
        'startTime': '${8 + _random.nextInt(4)}:00 AM',
        'endTime': '${2 + _random.nextInt(5)}:00 PM',
        'marketType': marketData['type'],
        'isActive': true,
        'isVerified': true,
        'isFeatured': i < 2, // First 2 are featured

        // Vendor recruitment
        'isLookingForVendors': true,
        'vendorSpotsTotal': 20 + _random.nextInt(30),
        'vendorSpotsAvailable': 5 + _random.nextInt(15),
        'dailyBoothFee': 25.0 + _random.nextDouble() * 75,
        'applicationDeadline': Timestamp.fromDate(eventDate.subtract(const Duration(days: 7))),
        'vendorRequirements': 'Valid permits, insurance, and professional setup required.',

        // Images
        'imageUrl': 'https://picsum.photos/400/300?random=${_random.nextInt(1000)}',
        'flyerUrls': List.generate(2, (j) => 'https://picsum.photos/400/600?random=${_random.nextInt(1000)}'),

        // Social
        'instagramHandle': '@${marketData['name'].replaceAll(' ', '').toLowerCase()}',
        'websiteUrl': 'https://hipopmarkets.com/markets/${marketData['name'].replaceAll(' ', '-').toLowerCase()}',

        // Metadata
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'viewCount': 50 + _random.nextInt(200),
        'favoriteCount': 5 + _random.nextInt(20),
        'debugGenerated': true,
        'generatedAt': DateTime.now().toIso8601String(),
      });

      _createdMarketIds.add(docRef.id);
      _marketVendorMap[docRef.id] = [];
      _updateStatus('Created market: ${marketData['name']}');
    }
  }

  Future<void> _createManagedVendors() async {
    final vendorsPerMarket = _volumes[_selectedVolume]!['vendorsPerMarket']!;

    for (String marketId in _createdMarketIds) {
      for (int i = 0; i < vendorsPerMarket && i < _vendorProfiles.length; i++) {
        final vendorProfile = _vendorProfiles[_random.nextInt(_vendorProfiles.length)];

        // Create vendor user profile first
        final vendorDocRef = await _firestore.collection('user_profiles').add({
          'userType': 'vendor',
          'displayName': vendorProfile['name'],
          'businessName': vendorProfile['business'],
          'email': '${vendorProfile['name'].replaceAll(' ', '.').toLowerCase()}@demo.com',
          'phoneNumber': '555-${1000 + _random.nextInt(9000)}',
          'isVendor': true,
          'isManaged': true,
          'managedByOrganizerId': _organizerId,
          'createdAt': FieldValue.serverTimestamp(),
          'debugGenerated': true,
        });

        _createdVendorIds.add(vendorDocRef.id);
        _marketVendorMap[marketId]?.add(vendorDocRef.id);

        // Create managed vendor relationship
        await _firestore.collection('managed_vendors').add({
          'marketId': marketId,
          'vendorId': vendorDocRef.id,
          'organizerId': _organizerId,
          'vendorName': vendorProfile['name'],
          'businessName': vendorProfile['business'],
          'contactName': vendorProfile['name'],
          'email': '${vendorProfile['name'].replaceAll(' ', '.').toLowerCase()}@demo.com',
          'description': vendorProfile['description'],
          'categories': [vendorProfile['category']],
          'products': vendorProfile['products'],
          'tags': vendorProfile['tags'],
          'status': 'approved',
          'isActive': true,
          'instagramHandle': '@${vendorProfile['business'].replaceAll(' ', '').toLowerCase()}',
          'rating': 4.0 + _random.nextDouble(),
          'reviewCount': _random.nextInt(20),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'debugGenerated': true,
        });

        _updateStatus('Created vendor: ${vendorProfile['business']} for market $marketId');
      }
    }
  }

  Future<void> _createVendorProducts() async {
    final categories = [
      'Handmade Jewelry', 'Artisan Foods', 'Vintage Clothing',
      'Home Decor', 'Art & Prints', 'Bath & Body',
      'Candles & Fragrance', 'Pottery & Ceramics',
      'Leather Goods', 'Plants & Garden'
    ];

    final productNames = {
      'Handmade Jewelry': [
        'Silver Moon Necklace', 'Crystal Stud Earrings', 'Boho Bracelet Set',
        'Gold Leaf Pendant', 'Gemstone Ring Collection'
      ],
      'Artisan Foods': [
        'Organic Honey', 'Small Batch Jam', 'Artisan Bread',
        'Gourmet Hot Sauce', 'Handmade Pasta'
      ],
      'Vintage Clothing': [
        '70s Denim Jacket', 'Vintage Band Tee', 'Retro Sundress',
        'Classic Leather Boots', 'Antique Silk Scarf'
      ],
      'Home Decor': [
        'Macrame Wall Hanging', 'Hand-painted Vase', 'Rustic Picture Frame',
        'Woven Throw Pillow', 'Reclaimed Wood Shelf'
      ],
      'Art & Prints': [
        'Abstract Canvas Print', 'Botanical Illustration', 'City Skyline Art',
        'Watercolor Landscape', 'Digital Portrait'
      ],
    };

    for (String vendorId in _createdVendorIds) {
      final vendorProducts = <String>[];
      final numProducts = 5 + _random.nextInt(6); // 5-10 products per vendor
      final vendorCategory = categories[_random.nextInt(categories.length)];

      for (int i = 0; i < numProducts; i++) {
        final category = i < 3 ? vendorCategory : categories[_random.nextInt(categories.length)];
        final names = productNames[category] ?? ['Custom Product ${i + 1}'];
        final productName = names[_random.nextInt(names.length)];

        final productRef = await _firestore.collection('vendor_products').add({
          'vendorId': vendorId,
          'name': productName,
          'category': category,
          'description': 'High-quality $productName. Handcrafted with care and attention to detail. '
                        'Perfect for gifts or treating yourself!',
          'basePrice': (5 + _random.nextDouble() * 495).roundToDouble(), // $5-$500
          'photoUrls': List.generate(1 + _random.nextInt(3),
            (j) => 'https://picsum.photos/400/400?random=product${_random.nextInt(100000)}'),
          'tags': [category.toLowerCase(), 'handmade', 'local'],
          'isActive': true,
          'stockQuantity': _random.nextInt(50) + 1,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'debugGenerated': true,
        });

        vendorProducts.add(productRef.id);
        _createdProductIds.add(productRef.id);
      }

      _vendorProductMap[vendorId] = vendorProducts;
      _updateStatus('Created ${vendorProducts.length} products for vendor $vendorId');
    }
  }

  Future<void> _createProductLists() async {
    final listNames = [
      'Best Sellers', 'New Arrivals', 'Summer Collection',
      'Gift Ideas', 'Sale Items', 'Premium Selection',
      'Market Specials', 'Customer Favorites'
    ];

    for (String vendorId in _createdVendorIds) {
      final vendorProducts = _vendorProductMap[vendorId] ?? [];
      if (vendorProducts.isEmpty) continue;

      final vendorLists = <String>[];
      final numLists = 2 + _random.nextInt(2); // 2-3 lists per vendor

      for (int i = 0; i < numLists; i++) {
        final listName = listNames[_random.nextInt(listNames.length)];

        // Select random products for this list (30-70% of vendor's products)
        final productsForList = <String>[];
        final numProductsInList = (vendorProducts.length * (0.3 + _random.nextDouble() * 0.4)).round();

        final shuffled = List<String>.from(vendorProducts)..shuffle(_random);
        productsForList.addAll(shuffled.take(numProductsInList));

        final listRef = await _firestore.collection('vendor_product_lists').add({
          'vendorId': vendorId,
          'name': listName,
          'description': 'Curated collection of our $listName',
          'productIds': productsForList,
          'color': [
            '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4',
            '#FFEAA7', '#DDA0DD', '#98D8C8', '#F7DC6F'
          ][_random.nextInt(8)],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'debugGenerated': true,
        });

        vendorLists.add(listRef.id);
        _createdProductListIds.add(listRef.id);
      }

      _vendorProductListMap[vendorId] = vendorLists;
      _updateStatus('Created ${vendorLists.length} product lists for vendor $vendorId');
    }
  }

  Future<void> _createVendorPosts() async {
    final postsPerVendor = _volumes[_selectedVolume]!['postsPerVendor']!;

    final postTypes = ['sale', 'newProduct', 'special', 'announcement', 'popup'];
    final postTitles = [
      '🎉 Weekend Special - 20% Off!',
      '✨ New Arrivals Just In!',
      '🔥 Flash Sale Today Only!',
      '📍 Find Us This Saturday!',
      '🎨 Custom Orders Now Open',
      '☀️ Summer Collection Launch',
      '🍂 Fall Favorites Available',
      '💝 Perfect Gifts for Any Occasion',
    ];

    // Atlanta coordinates for different areas
    final atlantaCoordinates = {
      '675 Ponce de Leon Ave NE': {'lat': 33.7726, 'lng': -84.3656}, // Ponce City Market
      '600 Cherokee Ave SE': {'lat': 33.7396, 'lng': -84.3690}, // Grant Park
      '99 Krog Street NE': {'lat': 33.7564, 'lng': -84.3635}, // Krog Street
      'Atlanta BeltLine Eastside Trail': {'lat': 33.7604, 'lng': -84.3500}, // BeltLine
      'Findley Plaza, Little Five Points': {'lat': 33.7644, 'lng': -84.3496}, // L5P
      'Piedmont Park, 12th Street Entrance': {'lat': 33.7855, 'lng': -84.3742}, // Piedmont
      'Lee Street & Ralph David Abernathy Blvd': {'lat': 33.7317, 'lng': -84.4182}, // West End
      '101 E Court Square': {'lat': 33.7748, 'lng': -84.2963}, // Decatur
    };

    for (String vendorId in _createdVendorIds) {
      // Get vendor's product lists
      final vendorProductLists = _vendorProductListMap[vendorId] ?? [];

      // Get vendor's profile to get the business name
      final vendorDoc = await _firestore.collection('user_profiles').doc(vendorId).get();
      final vendorData = vendorDoc.data() ?? {};
      final vendorBusinessName = vendorData['businessName'] ?? 'Local Vendor';

      for (int i = 0; i < postsPerVendor; i++) {
        final isMarketPost = _random.nextBool();
        final postDate = _getRandomFutureDate();
        final marketLocation = _atlantaMarkets[_random.nextInt(_atlantaMarkets.length)];
        final coordinates = atlantaCoordinates[marketLocation['address']] ??
                          {'lat': 33.7490 + (_random.nextDouble() - 0.5) * 0.1,
                           'lng': -84.3880 + (_random.nextDouble() - 0.5) * 0.1};

        final postData = {
          'vendorId': vendorId,
          'vendorName': vendorBusinessName,
          'postType': postTypes[_random.nextInt(postTypes.length)],
          'title': postTitles[_random.nextInt(postTitles.length)],
          'description': 'Join us for amazing deals and new products! '
                        'We\'ll have special offers, product demos, and more. '
                        'Don\'t miss out on this exclusive opportunity!',
          'location': marketLocation['address'],
          'locationName': marketLocation['name'],
          'latitude': coordinates['lat'],
          'longitude': coordinates['lng'],
          'popUpStartDateTime': Timestamp.fromDate(postDate),
          'popUpEndDateTime': Timestamp.fromDate(postDate.add(Duration(hours: 4 + _random.nextInt(4)))),
          'isActive': postDate.isAfter(DateTime.now()),
          'photoUrls': List.generate(2 + _random.nextInt(2),  // 2-3 photos per post
            (j) => 'https://picsum.photos/600/400?random=${_random.nextInt(100000)}'),
          'productListIds': vendorProductLists.isNotEmpty && _random.nextBool()
            ? [vendorProductLists[_random.nextInt(vendorProductLists.length)]]
            : [], // Add product list 50% of the time
          'tags': ['special', 'limitedTime', 'exclusive'],
          'viewCount': _random.nextInt(100),
          'interestedCount': _random.nextInt(30),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'debugGenerated': true,
        };

        // Add market association if it's a market post
        if (isMarketPost && _marketVendorMap.isNotEmpty) {
          for (var entry in _marketVendorMap.entries) {
            if (entry.value.contains(vendorId)) {
              postData['marketId'] = entry.key;
              postData['postType'] = 'market';
              break;
            }
          }
        } else {
          postData['postType'] = 'independent';
        }

        final docRef = await _firestore.collection('vendor_posts').add(postData);
        _createdPostIds.add(docRef.id);
        _updateStatus('Created post for vendor: $vendorId');
      }
    }
  }

  Future<void> _createEvents() async {
    final eventsPerMarket = _volumes[_selectedVolume]!['eventsPerMarket']!;

    for (String marketId in _createdMarketIds) {
      for (int i = 0; i < eventsPerMarket; i++) {
        final eventDate = _getRandomFutureDate();
        final eventType = _eventTypes[_random.nextInt(_eventTypes.length)];

        await _firestore.collection('events').add({
          'marketId': marketId,
          'organizerId': _organizerId,
          'title': eventType,
          'description': 'Join us for our $eventType! Special activities, '
                        'entertainment, and exclusive vendor offerings.',
          'eventDate': Timestamp.fromDate(eventDate),
          'startTime': '${10 + _random.nextInt(4)}:00 AM',
          'endTime': '${4 + _random.nextInt(4)}:00 PM',
          'eventType': eventType.toLowerCase().replaceAll(' ', '_'),
          'isActive': true,
          'isFeatured': _random.nextBool(),
          'imageUrl': 'https://picsum.photos/600/400?random=${_random.nextInt(10000)}',
          'ticketPrice': _random.nextBool() ? 0 : 5.0 + _random.nextDouble() * 20,
          'maxAttendees': 100 + _random.nextInt(400),
          'currentAttendees': _random.nextInt(50),
          'tags': ['familyFriendly', 'liveMusic', 'foodAndDrink'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'debugGenerated': true,
        });

        _updateStatus('Created event: $eventType for market $marketId');
      }
    }
  }

  Future<void> _createReviews() async {
    final reviewsPerMarket = _volumes[_selectedVolume]!['reviewsPerMarket']!;
    final reviewsPerVendor = _volumes[_selectedVolume]!['reviewsPerVendor']!;

    final reviewerNames = [
      'John D.', 'Sarah M.', 'Mike T.', 'Jessica L.', 'David B.',
      'Emily C.', 'Tom W.', 'Lisa K.', 'Chris R.', 'Amanda S.'
    ];

    // Create market reviews
    for (String marketId in _createdMarketIds) {
      for (int i = 0; i < reviewsPerMarket; i++) {
        await _firestore.collection('reviews').add({
          'targetId': marketId,
          'targetType': 'market',
          'reviewerId': 'user_${_random.nextInt(10000)}',
          'reviewerName': reviewerNames[_random.nextInt(reviewerNames.length)],
          'rating': 3.5 + _random.nextDouble() * 1.5, // 3.5 to 5 stars
          'reviewText': _reviewTexts[_random.nextInt(_reviewTexts.length)],
          'isVerifiedPurchase': _random.nextBool(),
          'createdAt': FieldValue.serverTimestamp(),
          'helpful': _random.nextInt(20),
          'debugGenerated': true,
        });
      }
      _updateStatus('Created $reviewsPerMarket reviews for market $marketId');
    }

    // Create vendor reviews
    for (String vendorId in _createdVendorIds) {
      for (int i = 0; i < reviewsPerVendor; i++) {
        await _firestore.collection('reviews').add({
          'targetId': vendorId,
          'targetType': 'vendor',
          'reviewerId': 'user_${_random.nextInt(10000)}',
          'reviewerName': reviewerNames[_random.nextInt(reviewerNames.length)],
          'rating': 3.5 + _random.nextDouble() * 1.5,
          'reviewText': _reviewTexts[_random.nextInt(_reviewTexts.length)],
          'isVerifiedPurchase': true,
          'productPurchased': 'Sample Product',
          'createdAt': FieldValue.serverTimestamp(),
          'helpful': _random.nextInt(15),
          'debugGenerated': true,
        });
      }
      _updateStatus('Created $reviewsPerVendor reviews for vendor $vendorId');
    }
  }

  Future<void> _createEngagementData() async {
    final favorites = _volumes[_selectedVolume]!['favorites']!;
    final views = _volumes[_selectedVolume]!['views']!;

    // Create favorites
    for (int i = 0; i < favorites; i++) {
      final isMarketFavorite = _random.nextBool();
      final targetId = isMarketFavorite
        ? _createdMarketIds[_random.nextInt(_createdMarketIds.length)]
        : _createdVendorIds.isNotEmpty
          ? _createdVendorIds[_random.nextInt(_createdVendorIds.length)]
          : null;

      if (targetId != null) {
        await _firestore.collection('user_favorites').add({
          'userId': 'user_${_random.nextInt(10000)}',
          'targetId': targetId,
          'targetType': isMarketFavorite ? 'market' : 'vendor',
          'createdAt': FieldValue.serverTimestamp(),
          'debugGenerated': true,
        });
      }
    }
    _updateStatus('Created $favorites favorites');

    // Create view analytics
    for (int i = 0; i < views; i++) {
      final viewType = ['market', 'vendor', 'post'][_random.nextInt(3)];
      String? targetId;

      switch (viewType) {
        case 'market':
          targetId = _createdMarketIds.isNotEmpty
            ? _createdMarketIds[_random.nextInt(_createdMarketIds.length)]
            : null;
          break;
        case 'vendor':
          targetId = _createdVendorIds.isNotEmpty
            ? _createdVendorIds[_random.nextInt(_createdVendorIds.length)]
            : null;
          break;
        case 'post':
          targetId = _createdPostIds.isNotEmpty
            ? _createdPostIds[_random.nextInt(_createdPostIds.length)]
            : null;
          break;
      }

      if (targetId != null) {
        await _firestore.collection('analytics_views').add({
          'targetId': targetId,
          'targetType': viewType,
          'viewerId': 'user_${_random.nextInt(10000)}',
          'viewDuration': _random.nextInt(300), // seconds
          'source': ['discovery', 'search', 'direct', 'social'][_random.nextInt(4)],
          'timestamp': FieldValue.serverTimestamp(),
          'debugGenerated': true,
        });
      }
    }
    _updateStatus('Created $views view events');

    // Create some vendor applications for markets
    for (String marketId in _createdMarketIds) {
      final applicationCount = _random.nextInt(5) + 1;
      for (int i = 0; i < applicationCount; i++) {
        await _firestore.collection('vendor_applications').add({
          'marketId': marketId,
          'vendorId': 'vendor_${_random.nextInt(10000)}',
          'vendorName': 'Applicant Business ${_random.nextInt(100)}',
          'status': ['pending', 'approved', 'rejected'][_random.nextInt(3)],
          'applicationDate': FieldValue.serverTimestamp(),
          'message': 'I would love to be part of this market!',
          'debugGenerated': true,
        });
      }
      _updateStatus('Created $applicationCount applications for market $marketId');
    }
  }

  Future<void> _createAnalyticsData() async {
    // Create sales data for vendors
    for (String vendorId in _createdVendorIds) {
      final salesDays = 7 + _random.nextInt(14); // 1-3 weeks of data

      for (int i = 0; i < salesDays; i++) {
        final saleDate = DateTime.now().subtract(Duration(days: i));
        final dailySales = 3 + _random.nextInt(12); // 3-15 sales per day

        await _firestore.collection('vendor_sales').add({
          'vendorId': vendorId,
          'date': Timestamp.fromDate(saleDate),
          'totalSales': dailySales,
          'totalRevenue': dailySales * (15.0 + _random.nextDouble() * 35),
          'averageOrderValue': 15.0 + _random.nextDouble() * 35,
          'topProducts': ['Product A', 'Product B', 'Product C'],
          'customerCount': dailySales,
          'debugGenerated': true,
        });
      }
      _updateStatus('Created sales data for vendor $vendorId');
    }

    // Create market attendance data
    for (String marketId in _createdMarketIds) {
      await _firestore.collection('market_analytics').add({
        'marketId': marketId,
        'date': FieldValue.serverTimestamp(),
        'attendance': 100 + _random.nextInt(400),
        'vendorCount': _marketVendorMap[marketId]?.length ?? 0,
        'totalRevenue': 1000.0 + _random.nextDouble() * 4000,
        'averageSpendPerCustomer': 20.0 + _random.nextDouble() * 30,
        'peakHours': ['10-11 AM', '1-2 PM'],
        'popularCategories': ['food', 'crafts', 'art'],
        'weatherCondition': ['sunny', 'cloudy', 'partly cloudy'][_random.nextInt(3)],
        'temperature': 65 + _random.nextInt(25),
        'debugGenerated': true,
      });
      _updateStatus('Created analytics for market $marketId');
    }
  }

  void _showCleanupConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete All Data', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will DELETE ALL DATA from your database except:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('✓ test.shopper@example.com'),
            Text('✓ test.vendor@example.com'),
            Text('✓ test.organizer@example.com'),
            SizedBox(height: 12),
            Text(
              'Everything else will be permanently deleted:',
              style: TextStyle(color: Colors.orange),
            ),
            Text('• All markets'),
            Text('• All vendors (except test)'),
            Text('• All products'),
            Text('• All posts'),
            Text('• All reviews'),
            Text('• All analytics'),
            SizedBox(height: 16),
            Text(
              'This action cannot be undone!',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _cleanupDebugData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }

  Future<void> _cleanupDebugData() async {
    setState(() {
      _isGenerating = true;
      _status = 'Cleaning up ALL data (preserving 3 test accounts)...';
    });

    try {
      // Account emails to preserve (the 3 test accounts)
      final preservedEmails = [
        'test.shopper@example.com',
        'test.vendor@example.com',
        'test.organizer@example.com'
      ];

      // Collections to clean completely
      final collectionsToClean = [
        'markets', 'managed_vendors', 'vendor_posts',
        'vendor_products', 'vendor_product_lists', 'product_reservations',
        'events', 'reviews', 'user_favorites', 'analytics_views',
        'vendor_applications', 'vendor_sales', 'market_analytics',
        'vendor_relationships', 'vendor_following', 'notifications'
      ];

      int totalDeleted = 0;

      // Clean user_profiles but preserve the 3 test accounts
      _updateStatus('Cleaning user profiles...');
      final userSnapshot = await _firestore.collection('user_profiles').get();
      for (var doc in userSnapshot.docs) {
        final data = doc.data();
        final email = data['email']?.toString() ?? '';

        // Delete if NOT one of the preserved accounts
        if (!preservedEmails.contains(email)) {
          await doc.reference.delete();
          totalDeleted++;
        }
      }
      _updateStatus('Preserved 3 test accounts, deleted ${userSnapshot.docs.length - 3} user profiles');

      // Clean all other collections completely
      for (String collection in collectionsToClean) {
        final snapshot = await _firestore.collection(collection).get();

        for (var doc in snapshot.docs) {
          await doc.reference.delete();
          totalDeleted++;
        }

        if (snapshot.docs.isNotEmpty) {
          _updateStatus('Deleted ${snapshot.docs.length} documents from $collection');
        }
      }

      _updateStatus('✅ Cleanup complete! Deleted $totalDeleted debug documents.');

      // Clear tracking lists
      _createdMarketIds.clear();
      _createdVendorIds.clear();
      _createdPostIds.clear();
      _createdProductIds.clear();
      _createdProductListIds.clear();
      _marketVendorMap.clear();
      _vendorProductMap.clear();
      _vendorProductListMap.clear();

    } catch (e) {
      _updateStatus('Error during cleanup: $e', isError: true);
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  DateTime _getRandomFutureDate() {
    final daysInFuture = _random.nextInt(30) + 1; // 1-30 days from now
    return DateTime.now().add(Duration(days: daysInFuture));
  }
}