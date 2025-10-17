import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'dart:math';

class DebugPlayDataGenerator extends StatefulWidget {
  const DebugPlayDataGenerator({super.key});

  @override
  State<DebugPlayDataGenerator> createState() => _DebugPlayDataGeneratorState();
}

class _DebugPlayDataGeneratorState extends State<DebugPlayDataGenerator> {
  bool _isGenerating = false;
  String? _result;
  final Random _random = Random();

  // Atlanta-specific market names
  final List<String> _marketNames = [
    'Ponce City Market Pop-Up',
    'BeltLine Artisan Market',
    'Grant Park Farmers Market',
    'Krog Street Tunnel Arts Fair',
    'Piedmont Park Green Market',
    'Little Five Points Vintage Bazaar',
    'West End Night Market',
    'Decatur Square Pop-Up',
    'Virginia-Highland Street Fair',
    'East Atlanta Village Market',
    'Inman Park Festival Market',
    'Old Fourth Ward Pop-Up',
    'Buckhead Farmers Market',
    'Midtown Arts & Crafts',
    'Cabbagetown Art Market',
    'Reynoldstown Rail Market',
    'Sweet Auburn Curb Market Pop-Up',
    'Atlantic Station Weekend Market',
    'Westside Provisions Market',
    'King Plow Arts Market'
  ];

  final List<String> _vendorBusinessNames = [
    'Peachtree Jewelry Co',
    'Georgia Grown Produce',
    'Southern Soap Works',
    'ATL Vintage Threads',
    'Octane Coffee Cart',
    'Highland Bakery Pop-Up',
    'Kudzu Crafts Collective',
    'Chattahoochee Herbs',
    'Georgia Honey Co',
    'Red Clay Pottery',
    'Southern Candle Works',
    'Magnolia Beauty Bar',
    'Fox Bros BBQ Cart',
    'Atlanta Leather Works',
    'Stone Mountain Crystals',
    'Dancing Goats Coffee',
    'King of Pops Cart',
    'Jeni\'s Ice Cream Pop-Up',
    'Revolution Doughnuts',
    'Bell Street Burritos',
    'Sublime Doughnuts',
    'Yeah! Burger Food Truck',
    'Buttermilk Kitchen Pop-Up',
    'The Varsity Express',
    'Mary Mac\'s Tea Room To-Go'
  ];

  final List<String> _vendorFirstNames = [
    'Sarah', 'Mike', 'Jessica', 'David', 'Emily', 'Chris', 'Amanda', 'Brian',
    'Rachel', 'Tom', 'Lisa', 'Kevin', 'Ashley', 'James', 'Megan'
  ];

  final List<String> _vendorLastNames = [
    'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis',
    'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson', 'Thomas'
  ];

  final List<String> _productCategories = [
    'jewelry', 'food', 'clothing', 'art', 'crafts', 'beauty', 'home decor',
    'plants', 'accessories', 'vintage', 'handmade', 'organic', 'beverages'
  ];

  // Atlanta neighborhoods and areas
  final List<String> _atlantaNeighborhoods = [
    'Midtown', 'Buckhead', 'Downtown', 'Little Five Points', 'Virginia-Highland',
    'Inman Park', 'Grant Park', 'East Atlanta Village', 'Decatur', 'Old Fourth Ward',
    'West End', 'Cabbagetown', 'Reynoldstown', 'Kirkwood', 'Candler Park',
    'Poncey-Highland', 'Ansley Park', 'Morningside', 'Druid Hills', 'Westside'
  ];

  // Atlanta-specific addresses
  final List<String> _atlantaStreets = [
    'Peachtree Street', 'Ponce de Leon Avenue', 'North Highland Avenue',
    'Moreland Avenue', 'Spring Street', 'Piedmont Avenue', 'Monroe Drive',
    'Boulevard', 'Memorial Drive', 'DeKalb Avenue', 'Marietta Street',
    'North Avenue', 'Edgewood Avenue', 'Auburn Avenue', 'Mitchell Street'
  ];

  final List<String> _cities = [
    'Atlanta', 'Decatur', 'Sandy Springs', 'Roswell', 'Alpharetta', 'Marietta'
  ];

  final List<String> _states = [
    'GA'
  ];

  // Image generation helpers
  String _getPlaceholderImage(String category, {int width = 800, int height = 600}) {
    // Using various placeholder services for different types
    final imageServices = {
      'market': 'https://source.unsplash.com/${width}x$height/?farmers-market,outdoor-market',
      'vendor': 'https://source.unsplash.com/${width}x$height/?craft,handmade,artisan',
      'product': 'https://source.unsplash.com/${width}x$height/?product,handcraft,jewelry',
      'food': 'https://source.unsplash.com/${width}x$height/?food,organic,fresh',
      'jewelry': 'https://source.unsplash.com/${width}x$height/?jewelry,necklace,handmade',
      'clothing': 'https://source.unsplash.com/${width}x$height/?fashion,clothing,vintage',
      'art': 'https://source.unsplash.com/${width}x$height/?art,painting,artwork',
      'crafts': 'https://source.unsplash.com/${width}x$height/?crafts,pottery,handmade',
      'plants': 'https://source.unsplash.com/${width}x$height/?plants,succulent,garden',
      'candles': 'https://source.unsplash.com/${width}x$height/?candles,aromatherapy',
      'soap': 'https://source.unsplash.com/${width}x$height/?soap,natural,organic',
      'avatar': 'https://i.pravatar.cc/$width?img=${_random.nextInt(70)}',
      'logo': 'https://ui-avatars.com/api/?name=${category}&size=$width&background=random',
    };

    return imageServices[category] ?? 'https://picsum.photos/$width/$height?random=${_random.nextInt(1000)}';
  }

  List<String> _getProductImages(String category) {
    // Generate 1-3 product images
    final count = _random.nextInt(3) + 1;
    final images = <String>[];

    for (int i = 0; i < count; i++) {
      images.add(_getPlaceholderImage(category, width: 600, height: 600) + '&sig=${_random.nextInt(10000)}');
    }

    return images;
  }

  List<String> _getMarketFlyers() {
    // Generate 1-2 flyer images
    final count = _random.nextInt(2) + 1;
    final flyers = <String>[];

    for (int i = 0; i < count; i++) {
      flyers.add(_getPlaceholderImage('market', width: 800, height: 1200) + '&sig=${_random.nextInt(10000)}');
    }

    return flyers;
  }

  final List<String> _marketDescriptions = [
    'Atlanta\'s premier pop-up market featuring local artisans, Southern cuisine, and live music on the BeltLine.',
    'Experience the best of ATL creativity with handmade goods, Georgia-grown produce, and food trucks.',
    'Your weekend destination in the heart of Atlanta for unique finds and Southern hospitality.',
    'Connecting Atlanta makers with conscious consumers in a festive, family-friendly atmosphere.',
    'Discover one-of-a-kind treasures while supporting Atlanta\'s thriving small business community.',
    'A curated selection of Georgia\'s finest vendors, from Peachtree to Ponce.',
    'Where Atlanta culture meets commerce in a celebration of Southern creativity.',
    'Shop local Atlanta brands, eat from the city\'s best food trucks, and enjoy live jazz.',
    'The perfect blend of Southern tradition and Atlanta\'s modern pop-up culture.',
    'Supporting sustainable Atlanta businesses and bringing neighborhoods together from Buckhead to East Atlanta.'
  ];

  Future<void> _generateMarkets(int count) async {
    setState(() {
      _isGenerating = true;
      _result = null;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      int successCount = 0;
      for (int i = 0; i < count; i++) {
        final neighborhood = _atlantaNeighborhoods[_random.nextInt(_atlantaNeighborhoods.length)];
        final street = _atlantaStreets[_random.nextInt(_atlantaStreets.length)];
        final cityIndex = _random.nextInt(_cities.length);
        final eventDate = DateTime.now().add(Duration(days: _random.nextInt(60) - 10));

        // Atlanta-specific coordinates (roughly within city limits)
        final latitude = 33.7490 + (_random.nextDouble() * 0.15 - 0.075);
        final longitude = -84.3880 + (_random.nextDouble() * 0.15 - 0.075);

        final marketData = {
          'name': _marketNames[_random.nextInt(_marketNames.length)],
          'description': _marketDescriptions[_random.nextInt(_marketDescriptions.length)],
          'organizerId': userId,
          'organizerName': 'Atlanta Market Organizer',
          'address': '${_random.nextInt(9999) + 1} $street',
          'neighborhood': neighborhood,
          'city': _cities[cityIndex],
          'state': 'GA',
          'latitude': latitude,
          'longitude': longitude,
          'placeId': 'test_place_${_random.nextInt(10000)}',
          'eventDate': Timestamp.fromDate(eventDate),
          'startTime': '${_random.nextInt(3) + 8}:00 AM',
          'endTime': '${_random.nextInt(4) + 2}:00 PM',
          'imageUrl': _getPlaceholderImage('market'),
          'flyerUrls': _getMarketFlyers(),
          'instagramHandle': '@atl_market_${_random.nextInt(1000)}',
          'isActive': true,
          'associatedVendorIds': [],
          'createdAt': FieldValue.serverTimestamp(),
          // Vendor recruitment fields
          'isLookingForVendors': _random.nextBool(),
          'isRecruitmentOnly': false,
          'applicationUrl': _random.nextBool() ? 'https://forms.example.com/apply' : null,
          'applicationFee': _random.nextBool() ? _random.nextDouble() * 50 : null,
          'dailyBoothFee': 25.0 + _random.nextDouble() * 75,
          'vendorSpotsAvailable': _random.nextInt(30) + 10,
          'vendorSpotsTotal': _random.nextInt(50) + 20,
          'applicationDeadline': _random.nextBool() ?
              Timestamp.fromDate(eventDate.subtract(Duration(days: 7))) : null,
          'vendorRequirements': _random.nextBool() ?
              'Must have valid permits and insurance. Setup by 7 AM.' : null,
          'marketType': ['farmers', 'popup', 'vegan', 'art', 'craft', 'night', 'holiday'][_random.nextInt(7)],
          'metadata': {
            'debugGenerated': true,
            'generatedAt': DateTime.now().toIso8601String(),
          }
        };

        await FirebaseFirestore.instance.collection('markets').add(marketData);
        successCount++;
      }

      setState(() {
        _result = 'Success! Generated $successCount markets';
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isGenerating = false;
      });
    }
  }

  Future<void> _generateVendors(int count) async {
    setState(() {
      _isGenerating = true;
      _result = null;
    });

    try {
      int successCount = 0;

      // Get some market IDs to associate vendors with
      final marketsSnapshot = await FirebaseFirestore.instance
          .collection('markets')
          .limit(10)
          .get();

      final marketIds = marketsSnapshot.docs.map((doc) => doc.id).toList();

      for (int i = 0; i < count; i++) {
        final firstName = _vendorFirstNames[_random.nextInt(_vendorFirstNames.length)];
        final lastName = _vendorLastNames[_random.nextInt(_vendorLastNames.length)];
        final businessName = '${_vendorBusinessNames[_random.nextInt(_vendorBusinessNames.length)]} ${_random.nextInt(100)}';

        final vendorData = {
          'vendorName': '$firstName $lastName',
          'businessName': businessName,
          'contactName': '$firstName $lastName',
          'email': '${firstName.toLowerCase()}.${lastName.toLowerCase()}${_random.nextInt(100)}@example.com',
          'phoneNumber': '555-${_random.nextInt(900) + 100}-${_random.nextInt(9000) + 1000}',
          'description': 'We specialize in high-quality, locally-sourced products with a focus on sustainability and community.',
          'categories': _getRandomSublist(_productCategories, 2, 4),
          'products': _getRandomSublist([
            'Handmade Items', 'Fresh Produce', 'Baked Goods', 'Jewelry', 'Clothing',
            'Art Prints', 'Candles', 'Soap', 'Pottery', 'Plants', 'Honey', 'Coffee'
          ], 3, 6),
          'city': _cities[_random.nextInt(_cities.length)],
          'state': _states[_random.nextInt(_states.length)],
          'marketId': marketIds.isNotEmpty ? marketIds[_random.nextInt(marketIds.length)] : null,
          'isActive': true,
          'isFeatured': _random.nextBool(),
          'acceptsOrders': _random.nextBool(),
          'canDeliver': _random.nextBool(),
          'isOrganic': _random.nextBool(),
          'isLocallySourced': true,
          'rating': 3.5 + _random.nextDouble() * 1.5,
          'reviewCount': _random.nextInt(50),
          'instagramHandle': '@${businessName.replaceAll(' ', '_').replaceAll('\'', '').toLowerCase()}_atl',
          'profileImageUrl': _getPlaceholderImage('avatar'),
          'coverImageUrl': _getPlaceholderImage('vendor'),
          'tags': _getRandomSublist([
            'eco-friendly', 'handmade', 'local', 'organic', 'sustainable',
            'artisan', 'small-batch', 'family-owned', 'woman-owned', 'veteran-owned'
          ], 2, 4),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'metadata': {
            'debugGenerated': true,
            'generatedAt': DateTime.now().toIso8601String(),
          }
        };

        await FirebaseFirestore.instance.collection('managed_vendors').add(vendorData);
        successCount++;
      }

      setState(() {
        _result = 'Success! Generated $successCount vendors';
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isGenerating = false;
      });
    }
  }

  Future<void> _generateProducts(int count) async {
    setState(() {
      _isGenerating = true;
      _result = null;
    });

    try {
      // Get some vendor IDs
      final vendorsSnapshot = await FirebaseFirestore.instance
          .collection('managed_vendors')
          .limit(10)
          .get();

      if (vendorsSnapshot.docs.isEmpty) {
        throw Exception('No vendors found. Generate vendors first!');
      }

      int successCount = 0;

      final productNames = [
        'Georgia Peach Jam', 'Atlanta Skyline Print', 'BeltLine Photography', 'Varsity Hot Dog Sauce',
        'Braves Vintage Tee', 'Hawks Championship Mug', 'ATL United Scarf', 'Fox Theatre Poster',
        'Piedmont Park Candle', 'Sweet Auburn Honey', 'Ponce City Market Tote', 'King of Pops Holder',
        'Highland Bakery Bread', 'Sublime Donut Mix', 'Dancing Goats Coffee', 'Stone Mountain Crystal',
        'Little Five Points Pin', 'East Atlanta Vinyl', 'Cabbagetown Art', 'Grant Park Succulent'
      ];

      for (int i = 0; i < count; i++) {
        final vendor = vendorsSnapshot.docs[_random.nextInt(vendorsSnapshot.docs.length)];
        final vendorData = vendor.data();

        final productData = {
          'vendorId': vendor.id,
          'vendorName': vendorData['vendorName'] ?? 'Unknown Vendor',
          'name': productNames[_random.nextInt(productNames.length)],
          'description': 'Authentic Atlanta-made product crafted with Southern charm and local pride. Perfect for ATL locals and visitors alike.',
          'category': _productCategories[_random.nextInt(_productCategories.length)],
          'price': 5.0 + _random.nextDouble() * 95, // $5-100
          'images': _getProductImages(_productCategories[_random.nextInt(_productCategories.length)]),
          'photoUrls': _getProductImages(_productCategories[_random.nextInt(_productCategories.length)]),
          'tags': _getRandomSublist(['handmade', 'organic', 'local', 'sustainable', 'artisan'], 2, 3),
          'isPreOrder': _random.nextBool(),
          'preOrderAvailableDate': _random.nextBool() ?
              Timestamp.fromDate(DateTime.now().add(Duration(days: _random.nextInt(30)))) : null,
          'preOrderQuantityLimit': _random.nextBool() ? _random.nextInt(50) + 10 : null,
          'stockQuantity': _random.nextInt(100),
          'isActive': true,
          'isFeatured': _random.nextBool(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'metadata': {
            'debugGenerated': true,
            'generatedAt': DateTime.now().toIso8601String(),
          }
        };

        await FirebaseFirestore.instance.collection('vendor_products').add(productData);
        successCount++;
      }

      setState(() {
        _result = 'Success! Generated $successCount products';
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isGenerating = false;
      });
    }
  }

  Future<void> _generateUserProfiles(int count) async {
    setState(() {
      _isGenerating = true;
      _result = null;
    });

    try {
      int successCount = 0;

      for (int i = 0; i < count; i++) {
        final userTypes = ['shopper', 'vendor', 'market_organizer'];
        final userType = userTypes[_random.nextInt(userTypes.length)];
        final firstName = _vendorFirstNames[_random.nextInt(_vendorFirstNames.length)];
        final lastName = _vendorLastNames[_random.nextInt(_vendorLastNames.length)];
        final userId = 'test_${userType}_${_random.nextInt(100000)}';

        final neighborhood = _atlantaNeighborhoods[_random.nextInt(_atlantaNeighborhoods.length)];

        final profileData = {
          'userId': userId,
          'userType': userType,
          'email': '${firstName.toLowerCase()}.${lastName.toLowerCase()}@atlanta.com',
          'displayName': '$firstName $lastName',
          'businessName': userType == 'vendor' ? _vendorBusinessNames[_random.nextInt(_vendorBusinessNames.length)] : null,
          'organizationName': userType == 'market_organizer' ? '${_marketNames[_random.nextInt(_marketNames.length)]} Organization' : null,
          'managedMarketIds': userType == 'market_organizer' ? [] : [],
          'bio': userType == 'vendor'
              ? 'Atlanta-based artisan creating quality handmade products in $neighborhood. Supporting local markets across Metro Atlanta.'
              : userType == 'market_organizer'
              ? 'Organizing Atlanta\'s best pop-up markets. Bringing together local vendors from $neighborhood and beyond.'
              : 'ATL native who loves supporting local businesses at markets in $neighborhood and around the city.',
          'instagramHandle': '@${firstName.toLowerCase()}_atl_${_random.nextInt(1000)}',
          'phoneNumber': '404-${_random.nextInt(900) + 100}-${_random.nextInt(9000) + 1000}',
          'location': '$neighborhood, Atlanta, GA',
          'website': userType != 'shopper' && _random.nextBool() ? 'https://www.example.com/${firstName.toLowerCase()}' : null,
          'profileImageUrl': _getPlaceholderImage('avatar'),
          'bannerImageUrl': userType != 'shopper' ? _getPlaceholderImage(userType == 'vendor' ? 'vendor' : 'market') : null,
          'categories': userType == 'vendor' ? _getRandomSublist(_productCategories, 2, 4) : [],
          'preferences': {
            'notifications': true,
            'emailUpdates': _random.nextBool(),
            'textAlerts': _random.nextBool(),
          },
          'verificationStatus': userType != 'shopper' ? 'approved' : 'pending',
          'profileSubmitted': true,
          'isPremium': _random.nextDouble() < 0.3, // 30% premium
          'subscriptionStatus': _random.nextDouble() < 0.3 ? 'active' : 'free',
          'fcmToken': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'metadata': {
            'debugGenerated': true,
            'generatedAt': DateTime.now().toIso8601String(),
          }
        };

        await FirebaseFirestore.instance.collection('user_profiles').add(profileData);
        successCount++;
      }

      setState(() {
        _result = 'Success! Generated $successCount user profiles';
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isGenerating = false;
      });
    }
  }

  Future<void> _generateFavorites(int count) async {
    setState(() {
      _isGenerating = true;
      _result = null;
    });

    try {
      // Get some vendors and markets
      final vendorsSnapshot = await FirebaseFirestore.instance
          .collection('managed_vendors')
          .limit(20)
          .get();

      final marketsSnapshot = await FirebaseFirestore.instance
          .collection('markets')
          .limit(20)
          .get();

      if (vendorsSnapshot.docs.isEmpty || marketsSnapshot.docs.isEmpty) {
        throw Exception('Generate vendors and markets first!');
      }

      int successCount = 0;

      for (int i = 0; i < count; i++) {
        final userId = 'test_shopper_${_random.nextInt(10000)}';
        final favoriteType = _random.nextBool() ? 'vendor' : 'market';

        final favoriteData = {
          'userId': userId,
          'favoriteType': favoriteType,
          'favoriteId': favoriteType == 'vendor'
              ? vendorsSnapshot.docs[_random.nextInt(vendorsSnapshot.docs.length)].id
              : marketsSnapshot.docs[_random.nextInt(marketsSnapshot.docs.length)].id,
          'favoriteName': favoriteType == 'vendor'
              ? _vendorBusinessNames[_random.nextInt(_vendorBusinessNames.length)]
              : _marketNames[_random.nextInt(_marketNames.length)],
          'addedAt': FieldValue.serverTimestamp(),
          'metadata': {
            'debugGenerated': true,
            'generatedAt': DateTime.now().toIso8601String(),
          }
        };

        await FirebaseFirestore.instance.collection('favorites').add(favoriteData);
        successCount++;
      }

      setState(() {
        _result = 'Success! Generated $successCount favorites';
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isGenerating = false;
      });
    }
  }

  Future<void> _generateNotifications(int count) async {
    setState(() {
      _isGenerating = true;
      _result = null;
    });

    try {
      int successCount = 0;

      final notificationTypes = [
        {
          'type': 'market_reminder',
          'title': 'Market Tomorrow!',
          'body': 'Don\'t forget about the Sunset Farmers Market tomorrow at 9 AM',
          'icon': 'calendar',
        },
        {
          'type': 'vendor_update',
          'title': 'New Products Available',
          'body': 'Your favorite vendor just added new items',
          'icon': 'shopping_bag',
        },
        {
          'type': 'review_request',
          'title': 'How was your experience?',
          'body': 'Rate your recent visit to help others',
          'icon': 'star',
        },
        {
          'type': 'application_approved',
          'title': 'Application Approved!',
          'body': 'You\'re confirmed for the upcoming market',
          'icon': 'check_circle',
        },
        {
          'type': 'new_message',
          'title': 'New Message',
          'body': 'You have a new message from a market organizer',
          'icon': 'message',
        },
      ];

      for (int i = 0; i < count; i++) {
        final notification = notificationTypes[_random.nextInt(notificationTypes.length)];
        final userId = 'test_user_${_random.nextInt(10000)}';

        final notificationData = {
          'userId': userId,
          'type': notification['type'],
          'title': notification['title'],
          'body': notification['body'],
          'icon': notification['icon'],
          'read': _random.nextBool(),
          'actionUrl': '/market/${_random.nextInt(100)}',
          'sentAt': FieldValue.serverTimestamp(),
          'metadata': {
            'debugGenerated': true,
            'generatedAt': DateTime.now().toIso8601String(),
          }
        };

        await FirebaseFirestore.instance.collection('notifications').add(notificationData);
        successCount++;
      }

      setState(() {
        _result = 'Success! Generated $successCount notifications';
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isGenerating = false;
      });
    }
  }

  Future<void> _generateVendorApplications(int count) async {
    setState(() {
      _isGenerating = true;
      _result = null;
    });

    try {
      // Get markets and vendors
      final marketsSnapshot = await FirebaseFirestore.instance
          .collection('markets')
          .where('isLookingForVendors', isEqualTo: true)
          .limit(10)
          .get();

      if (marketsSnapshot.docs.isEmpty) {
        throw Exception('No markets looking for vendors. Generate markets first!');
      }

      int successCount = 0;

      for (int i = 0; i < count; i++) {
        final market = marketsSnapshot.docs[_random.nextInt(marketsSnapshot.docs.length)];
        final marketData = market.data();

        final applicationData = {
          'marketId': market.id,
          'marketName': marketData['name'] ?? 'Unknown Market',
          'vendorId': 'test_vendor_${_random.nextInt(10000)}',
          'vendorName': '${_vendorFirstNames[_random.nextInt(_vendorFirstNames.length)]} ${_vendorLastNames[_random.nextInt(_vendorLastNames.length)]}',
          'businessName': _vendorBusinessNames[_random.nextInt(_vendorBusinessNames.length)],
          'status': ['pending', 'approved', 'rejected', 'waitlisted'][_random.nextInt(4)],
          'applicationDate': FieldValue.serverTimestamp(),
          'eventDate': marketData['eventDate'],
          'boothPreference': 'Standard ${_random.nextInt(50) + 1}',
          'productsDescription': 'Handmade items including jewelry, soaps, and candles',
          'setupRequirements': '10x10 tent with table',
          'insuranceVerified': _random.nextBool(),
          'permitVerified': _random.nextBool(),
          'applicationFee': marketData['applicationFee'],
          'feePaid': _random.nextBool(),
          'notes': _random.nextBool() ? 'Looking forward to participating!' : null,
          'metadata': {
            'debugGenerated': true,
            'generatedAt': DateTime.now().toIso8601String(),
          }
        };

        await FirebaseFirestore.instance.collection('vendor_applications').add(applicationData);
        successCount++;
      }

      setState(() {
        _result = 'Success! Generated $successCount vendor applications';
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isGenerating = false;
      });
    }
  }

  Future<void> _generateVendorPosts(int count) async {
    setState(() {
      _isGenerating = true;
      _result = null;
    });

    try {
      // Get markets AND vendors to create realistic posts
      final marketsSnapshot = await FirebaseFirestore.instance
          .collection('markets')
          .limit(10)
          .get();

      final vendorsSnapshot = await FirebaseFirestore.instance
          .collection('managed_vendors')
          .limit(10)
          .get();

      if (marketsSnapshot.docs.isEmpty) {
        throw Exception('No markets found. Generate markets first!');
      }

      if (vendorsSnapshot.docs.isEmpty) {
        throw Exception('No vendors found. Generate vendors first!');
      }

      int successCount = 0;

      // Atlanta-specific post descriptions
      final postDescriptions = [
        'Y\'all come see us this weekend! We\'re bringing the best of Atlanta to ',
        'Excited to be back at ',
        'Don\'t miss us at ',
        'Atlanta! We\'ll be set up at ',
        'Bringing Southern hospitality and amazing products to ',
        'Can\'t wait to see our ATL family at ',
        'Fresh from our Atlanta workshop, find us at ',
      ];

      final specialOffers = [
        'BOGO on all Georgia-made products!',
        'Free King of Pops with purchase over \$25',
        'Atlanta locals get 15% off with ID',
        'Early bird special - First 20 customers get a free tote',
        'Buy 2 get 1 free on all BeltLine prints',
        'Special Braves game day discount - 20% off',
        'Peach season special - All peach products 25% off',
      ];

      for (int i = 0; i < count; i++) {
        final market = marketsSnapshot.docs[_random.nextInt(marketsSnapshot.docs.length)];
        final vendor = vendorsSnapshot.docs[_random.nextInt(vendorsSnapshot.docs.length)];
        final marketData = market.data();
        final vendorData = vendor.data();

        final postData = {
          'marketId': market.id,
          'marketName': marketData['name'] ?? 'Unknown Market',
          'vendorId': vendor.id,  // Use actual vendor doc ID
          'vendorName': vendorData['vendorName'] ?? 'Unknown Vendor',
          'businessName': vendorData['businessName'] ?? 'Unknown Business',
          'description': '${postDescriptions[_random.nextInt(postDescriptions.length)]}${marketData['name']}! ${marketData['neighborhood'] != null ? 'See you in ${marketData['neighborhood']}!' : ''}',
          'categories': _getRandomSublist(_productCategories, 2, 3),
          'products': _getRandomSublist([
            'Atlanta Exclusives', 'BeltLine Collection', 'Peachtree Specials', 'ATL United Gear',
            'Georgia Grown', 'Southern Classics', 'Midtown Must-Haves', 'Buckhead Best'
          ], 2, 4),
          'specialOffers': _random.nextBool() ? specialOffers[_random.nextInt(specialOffers.length)] : null,
          'boothNumber': _random.nextBool() ? 'Booth ${_random.nextInt(50) + 1}' : null,
          'eventDate': Timestamp.fromDate(
            DateTime.now().add(Duration(days: _random.nextInt(30)))
          ),
          'status': 'approved',
          'isActive': true,
          'imageUrls': [_getPlaceholderImage('vendor'), _getPlaceholderImage('product')],
          'photoUrls': [_getPlaceholderImage('vendor'), _getPlaceholderImage('product')],
          'contactEmail': vendorData['email'] ?? '${vendorData['vendorName']?.toLowerCase()?.replaceAll(' ', '.')}@atlvendor.com',
          'phoneNumber': vendorData['phoneNumber'] ?? '404-${_random.nextInt(900) + 100}-${_random.nextInt(9000) + 1000}',
          'instagramHandle': vendorData['instagramHandle'] ?? '@${vendorData['businessName']?.replaceAll(' ', '_')?.replaceAll('\'', '')?.toLowerCase() ?? 'vendor'}_atl',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'metadata': {
            'debugGenerated': true,
            'generatedAt': DateTime.now().toIso8601String(),
          }
        };

        await FirebaseFirestore.instance.collection('vendor_posts').add(postData);
        successCount++;
      }

      setState(() {
        _result = 'Success! Generated $successCount vendor posts';
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isGenerating = false;
      });
    }
  }

  Future<void> _generateUniversalReviews(int count) async {
    setState(() {
      _isGenerating = true;
      _result = null;
    });

    try {
      // Get some markets to rate
      final marketsSnapshot = await FirebaseFirestore.instance
          .collection('markets')
          .limit(10)
          .get();

      if (marketsSnapshot.docs.isEmpty) {
        throw Exception('No markets found. Generate markets first!');
      }

      int successCount = 0;

      // Get some vendors to review
      final vendorsSnapshot = await FirebaseFirestore.instance
          .collection('managed_vendors')
          .limit(10)
          .get();

      for (int i = 0; i < count; i++) {
        final market = marketsSnapshot.docs[_random.nextInt(marketsSnapshot.docs.length)];
        final marketData = market.data();

        // Determine review type
        final reviewTypes = ['shopper_to_vendor', 'vendor_to_market', 'shopper_to_market', 'organizer_to_vendor'];
        final reviewType = reviewTypes[_random.nextInt(reviewTypes.length)];

        String reviewerId, reviewerName, reviewerType, reviewedId, reviewedName, reviewedType;

        switch (reviewType) {
          case 'shopper_to_vendor':
            reviewerId = 'test_shopper_${_random.nextInt(10000)}';
            reviewerName = _vendorFirstNames[_random.nextInt(_vendorFirstNames.length)];
            reviewerType = 'shopper';
            reviewedId = vendorsSnapshot.docs.isNotEmpty ?
                vendorsSnapshot.docs[_random.nextInt(vendorsSnapshot.docs.length)].id :
                'test_vendor_${_random.nextInt(10000)}';
            reviewedName = _vendorBusinessNames[_random.nextInt(_vendorBusinessNames.length)];
            reviewedType = 'vendor';
            break;
          case 'vendor_to_market':
            reviewerId = 'test_vendor_${_random.nextInt(10000)}';
            reviewerName = _vendorBusinessNames[_random.nextInt(_vendorBusinessNames.length)];
            reviewerType = 'vendor';
            reviewedId = market.id;
            reviewedName = marketData['name'] ?? 'Unknown Market';
            reviewedType = 'market';
            break;
          case 'shopper_to_market':
            reviewerId = 'test_shopper_${_random.nextInt(10000)}';
            reviewerName = _vendorFirstNames[_random.nextInt(_vendorFirstNames.length)];
            reviewerType = 'shopper';
            reviewedId = market.id;
            reviewedName = marketData['name'] ?? 'Unknown Market';
            reviewedType = 'market';
            break;
          default: // organizer_to_vendor
            reviewerId = marketData['organizerId'] ?? 'test_organizer_${_random.nextInt(10000)}';
            reviewerName = marketData['organizerName'] ?? 'Market Organizer';
            reviewerType = 'organizer';
            reviewedId = vendorsSnapshot.docs.isNotEmpty ?
                vendorsSnapshot.docs[_random.nextInt(vendorsSnapshot.docs.length)].id :
                'test_vendor_${_random.nextInt(10000)}';
            reviewedName = _vendorBusinessNames[_random.nextInt(_vendorBusinessNames.length)];
            reviewedType = 'vendor';
            break;
        }

        final reviewData = {
          'reviewerId': reviewerId,
          'reviewerName': reviewerName,
          'reviewerType': reviewerType,
          'reviewedId': reviewedId,
          'reviewedName': reviewedName,
          'reviewedType': reviewedType,
          'eventId': market.id,
          'eventName': marketData['name'] ?? 'Unknown Market',
          'eventDate': Timestamp.fromDate(DateTime.now().subtract(Duration(days: _random.nextInt(30)))),
          'overallRating': 3.0 + _random.nextDouble() * 2, // 3-5 stars
          'reviewText': _getRandomReview(),
          'aspectRatings': _getAspectRatings(reviewerType, reviewedType),
          'tags': _getRandomSublist([
            'Great selection', 'Fair prices', 'Friendly service', 'High quality',
            'Well organized', 'Good location', 'Clean setup', 'Professional'
          ], 2, 4),
          'isVerified': _random.nextBool(),
          'verificationMethod': _random.nextBool() ? 'gps' : 'registration',
          'isAnonymous': false,
          'helpfulCount': _random.nextInt(20),
          'helpfulVoters': [],
          'createdAt': FieldValue.serverTimestamp(),
          'metadata': {
            'debugGenerated': true,
            'generatedAt': DateTime.now().toIso8601String(),
          }
        };

        await FirebaseFirestore.instance.collection('universal_reviews').add(reviewData);
        successCount++;
      }

      setState(() {
        _result = 'Success! Generated $successCount universal reviews';
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isGenerating = false;
      });
    }
  }

  String _getRandomReview() {
    final reviews = [
      'Great market with excellent foot traffic! The organizers are very helpful.',
      'Love the community vibe here. Good mix of vendors and customers.',
      'Well-organized market with clear signage and good facilities.',
      'The location is perfect and draws a good crowd every weekend.',
      'Friendly atmosphere and the organizers really support their vendors.',
      'Could use more parking but overall a great experience.',
      'One of the best markets in the area. Highly recommend!',
      'Good variety of customers and steady traffic throughout the day.',
      'The setup process is smooth and communication is excellent.',
      'Love being a vendor here! Great community support.'
    ];
    return reviews[_random.nextInt(reviews.length)];
  }

  Map<String, double> _getAspectRatings(String reviewerType, String reviewedType) {
    final Map<String, double> ratings = {};

    // Based on the reviewer and reviewed type, generate appropriate aspect ratings
    if (reviewerType == 'shopper' && reviewedType == 'vendor') {
      ratings['productQuality'] = 3.0 + _random.nextDouble() * 2;
      ratings['customerService'] = 3.0 + _random.nextDouble() * 2;
      ratings['priceValue'] = 3.0 + _random.nextDouble() * 2;
      ratings['selection'] = 3.0 + _random.nextDouble() * 2;
    } else if (reviewerType == 'vendor' && reviewedType == 'market') {
      ratings['organization'] = 3.0 + _random.nextDouble() * 2;
      ratings['footTraffic'] = 3.0 + _random.nextDouble() * 2;
      ratings['facilities'] = 3.0 + _random.nextDouble() * 2;
      ratings['vendorSupport'] = 3.0 + _random.nextDouble() * 2;
    } else if (reviewerType == 'shopper' && reviewedType == 'market') {
      ratings['atmosphere'] = 3.0 + _random.nextDouble() * 2;
      ratings['vendorVariety'] = 3.0 + _random.nextDouble() * 2;
      ratings['location'] = 3.0 + _random.nextDouble() * 2;
      ratings['amenities'] = 3.0 + _random.nextDouble() * 2;
    } else if (reviewerType == 'organizer' && reviewedType == 'vendor') {
      ratings['professionalism'] = 3.0 + _random.nextDouble() * 2;
      ratings['setupCompliance'] = 3.0 + _random.nextDouble() * 2;
      ratings['customerInteraction'] = 3.0 + _random.nextDouble() * 2;
      ratings['productPresentation'] = 3.0 + _random.nextDouble() * 2;
    }

    return ratings;
  }

  List<String> _getRandomSublist(List<String> source, int minCount, int maxCount) {
    final count = _random.nextInt(maxCount - minCount + 1) + minCount;
    final shuffled = List<String>.from(source)..shuffle(_random);
    return shuffled.take(min(count, source.length)).toList();
  }

  Future<void> _addImagesToExistingData() async {
    setState(() {
      _isGenerating = true;
      _result = null;
    });

    try {
      int updatedCount = 0;

      // Update markets without images
      final marketsWithoutImages = await FirebaseFirestore.instance
          .collection('markets')
          .where('imageUrl', isEqualTo: null)
          .limit(20)
          .get();

      for (var doc in marketsWithoutImages.docs) {
        await doc.reference.update({
          'imageUrl': _getPlaceholderImage('market'),
          'flyerUrls': _getMarketFlyers(),
        });
        updatedCount++;
      }

      // Update vendors without images
      final vendorsWithoutImages = await FirebaseFirestore.instance
          .collection('managed_vendors')
          .limit(20)
          .get();

      for (var doc in vendorsWithoutImages.docs) {
        final data = doc.data();
        if (data['profileImageUrl'] == null) {
          await doc.reference.update({
            'profileImageUrl': _getPlaceholderImage('avatar'),
            'coverImageUrl': _getPlaceholderImage('vendor'),
          });
          updatedCount++;
        }
      }

      // Update products without images
      final productsWithoutImages = await FirebaseFirestore.instance
          .collection('vendor_products')
          .limit(30)
          .get();

      for (var doc in productsWithoutImages.docs) {
        final data = doc.data();
        if (data['images'] == null || (data['images'] as List).isEmpty) {
          final category = data['category'] ?? 'product';
          await doc.reference.update({
            'images': _getProductImages(category),
            'photoUrls': _getProductImages(category),
          });
          updatedCount++;
        }
      }

      // Update vendor posts without images
      final postsWithoutImages = await FirebaseFirestore.instance
          .collection('vendor_posts')
          .limit(20)
          .get();

      for (var doc in postsWithoutImages.docs) {
        final data = doc.data();
        if (data['imageUrls'] == null || (data['imageUrls'] as List).isEmpty) {
          await doc.reference.update({
            'imageUrls': [_getPlaceholderImage('vendor'), _getPlaceholderImage('product')],
            'photoUrls': [_getPlaceholderImage('vendor'), _getPlaceholderImage('product')],
          });
          updatedCount++;
        }
      }

      setState(() {
        _result = 'Success! Added images to $updatedCount items';
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error adding images: $e';
        _isGenerating = false;
      });
    }
  }

  Future<void> _generateCompleteDataset() async {
    setState(() {
      _isGenerating = true;
      _result = null;
    });

    try {
      // Generate a complete dataset in order
      await _generateMarkets(5);
      await _generateVendors(10);
      await _generateProducts(30);
      await _generateVendorPosts(15);
      await _generateUserProfiles(15);
      await _generateUniversalReviews(25);
      await _generateFavorites(20);
      await _generateNotifications(15);
      await _generateVendorApplications(10);

      setState(() {
        _result = 'Success! Generated complete dataset with 145+ items';
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error generating complete dataset: $e';
        _isGenerating = false;
      });
    }
  }

  Future<void> _clearAllDebugData() async {
    setState(() {
      _isGenerating = true;
      _result = null;
    });

    try {
      int totalDeleted = 0;

      // Clear debug markets
      final debugMarkets = await FirebaseFirestore.instance
          .collection('markets')
          .where('metadata.debugGenerated', isEqualTo: true)
          .get();

      for (var doc in debugMarkets.docs) {
        await doc.reference.delete();
        totalDeleted++;
      }

      // Clear debug vendors
      final debugVendors = await FirebaseFirestore.instance
          .collection('managed_vendors')
          .where('metadata.debugGenerated', isEqualTo: true)
          .get();

      for (var doc in debugVendors.docs) {
        await doc.reference.delete();
        totalDeleted++;
      }

      // Clear debug vendor posts
      final debugPosts = await FirebaseFirestore.instance
          .collection('vendor_posts')
          .where('metadata.debugGenerated', isEqualTo: true)
          .get();

      for (var doc in debugPosts.docs) {
        await doc.reference.delete();
        totalDeleted++;
      }

      // Clear debug products
      final debugProducts = await FirebaseFirestore.instance
          .collection('vendor_products')
          .where('metadata.debugGenerated', isEqualTo: true)
          .get();

      for (var doc in debugProducts.docs) {
        await doc.reference.delete();
        totalDeleted++;
      }

      // Clear debug universal reviews
      final debugReviews = await FirebaseFirestore.instance
          .collection('universal_reviews')
          .where('metadata.debugGenerated', isEqualTo: true)
          .get();

      for (var doc in debugReviews.docs) {
        await doc.reference.delete();
        totalDeleted++;
      }

      // Clear old market ratings if any
      final debugRatings = await FirebaseFirestore.instance
          .collection('market_ratings')
          .where('metadata.debugGenerated', isEqualTo: true)
          .get();

      for (var doc in debugRatings.docs) {
        await doc.reference.delete();
        totalDeleted++;
      }

      // Clear debug user profiles
      final debugProfiles = await FirebaseFirestore.instance
          .collection('user_profiles')
          .where('metadata.debugGenerated', isEqualTo: true)
          .get();

      for (var doc in debugProfiles.docs) {
        await doc.reference.delete();
        totalDeleted++;
      }

      // Clear debug favorites
      final debugFavorites = await FirebaseFirestore.instance
          .collection('favorites')
          .where('metadata.debugGenerated', isEqualTo: true)
          .get();

      for (var doc in debugFavorites.docs) {
        await doc.reference.delete();
        totalDeleted++;
      }

      // Clear debug notifications
      final debugNotifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('metadata.debugGenerated', isEqualTo: true)
          .get();

      for (var doc in debugNotifications.docs) {
        await doc.reference.delete();
        totalDeleted++;
      }

      // Clear debug vendor applications
      final debugApplications = await FirebaseFirestore.instance
          .collection('vendor_applications')
          .where('metadata.debugGenerated', isEqualTo: true)
          .get();

      for (var doc in debugApplications.docs) {
        await doc.reference.delete();
        totalDeleted++;
      }

      setState(() {
        _result = 'Cleared $totalDeleted debug documents from all collections';
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.deepOrange,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.science, color: Colors.deepOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'DEBUG: Play Data Generator',
                  style: TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Generate test data for staging environment',
            style: TextStyle(color: HiPopColors.darkTextSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Generation buttons section 1 - Core Data
          Text(
            'Core Data',
            style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionButton(
                '5 Markets',
                Colors.blue,
                () => _generateMarkets(5),
              ),
              _buildActionButton(
                '10 Vendors',
                Colors.green,
                () => _generateVendors(10),
              ),
              _buildActionButton(
                '20 Products',
                Colors.teal,
                () => _generateProducts(20),
              ),
              _buildActionButton(
                '15 Posts',
                Colors.purple,
                () => _generateVendorPosts(15),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Generation buttons section 2 - User Data
          Text(
            'User Data',
            style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionButton(
                '10 Profiles',
                Colors.indigo,
                () => _generateUserProfiles(10),
              ),
              _buildActionButton(
                '20 Favorites',
                Colors.pink,
                () => _generateFavorites(20),
              ),
              _buildActionButton(
                '15 Reviews',
                Colors.orange,
                () => _generateUniversalReviews(15),
              ),
              _buildActionButton(
                '10 Notifications',
                Colors.cyan,
                () => _generateNotifications(10),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Generation buttons section 3 - Activity Data
          Text(
            'Activity Data',
            style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionButton(
                '10 Applications',
                Colors.amber,
                () => _generateVendorApplications(10),
              ),
              _buildActionButton(
                'Add Images',
                Colors.deepPurple,
                _addImagesToExistingData,
                icon: Icons.image,
              ),
              _buildActionButton(
                'Generate All',
                Colors.deepOrange,
                _generateCompleteDataset,
                icon: Icons.rocket_launch,
              ),
              _buildActionButton(
                'Clear All',
                Colors.red,
                _clearAllDebugData,
                icon: Icons.delete_forever,
              ),
            ],
          ),

          if (_isGenerating) ...[
            const SizedBox(height: 16),
            const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
              ),
            ),
          ],

          if (_result != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _result!.startsWith('Success')
                    ? Colors.green.withOpacity( 0.2)
                    : _result!.startsWith('Cleared')
                    ? Colors.blue.withOpacity( 0.2)
                    : Colors.red.withOpacity( 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _result!.startsWith('Success')
                      ? Colors.green
                      : _result!.startsWith('Cleared')
                      ? Colors.blue
                      : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _result!.startsWith('Success') || _result!.startsWith('Cleared')
                        ? Icons.check_circle
                        : Icons.error,
                    color: _result!.startsWith('Success')
                        ? Colors.green
                        : _result!.startsWith('Cleared')
                        ? Colors.blue
                        : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _result!,
                      style: TextStyle(
                        color: _result!.startsWith('Success')
                            ? Colors.green
                            : _result!.startsWith('Cleared')
                            ? Colors.blue
                            : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed, {IconData? icon}) {
    return ElevatedButton.icon(
      onPressed: _isGenerating ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      icon: Icon(icon ?? Icons.add, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}