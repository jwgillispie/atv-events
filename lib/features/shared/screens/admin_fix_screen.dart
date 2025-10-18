import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:atv_events/features/shared/services/user/user_profile_service.dart';
import '../../market/services/market_service.dart';
import '../../vendor/services/core/managed_vendor_service.dart';
import '../../market/models/market.dart';
import '../../vendor/models/managed_vendor.dart';

class AdminFixScreen extends StatefulWidget {
  const AdminFixScreen({super.key});

  @override
  State<AdminFixScreen> createState() => _AdminFixScreenState();
}

class _AdminFixScreenState extends State<AdminFixScreen> {
  final UserProfileService _userProfileService = UserProfileService();
  bool _isLoading = false;
  String _result = '';

  @override
  Widget build(BuildContext context) {
    // Only show this screen in debug mode
    if (!kDebugMode) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Not Available'),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.block,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'Admin Features Unavailable',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'This screen is only available in debug mode.',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Fix'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Market Organizer Association Fix',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will fix market organizer users who are missing market associations. It will:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text('• Check if any markets exist in the database'),
            const Text('• Create a default Atlanta market if none exist'),
            const Text('• Find market organizer users with no managed markets'),
            const Text('• Associate them with the market'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _runFix,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Running Fix...'),
                      ],
                    )
                  : const Text('Run Market Association Fix'),
            ),
            const SizedBox(height: 32),
            
            // Tucker's Market Creation Section
            const Divider(),
            const SizedBox(height: 24),
            const Text(
              'Demo Market Creation',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Create Tucker\'s Farmers Market for demo purposes:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text('• Creates a realistic market for Tucker, GA'),
            const Text('• Includes proper address and operating hours'),
            const Text('• Generates shareable vendor application link'),
            const Text('• Perfect for sales demos and testing'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _createTuckersMarket,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Create Tucker\'s Farmers Market'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _createAfterDarkBazaar,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Create After Dark Bazaar'),
            ),
            const SizedBox(height: 24),
            if (_result.isNotEmpty) ...[
              const Text(
                'Result:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Text(
                  _result,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _runFix() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      // First, let's diagnose the current state
      await _diagnoseProblem();
      
      // Then run the fixes
      await _userProfileService.fixMarketOrganizerAssociations();
      setState(() {
        _result += '\n\n🔧 FIXING EXISTING VENDORS:\n';
      });
      
      await _userProfileService.fixExistingManagedVendors();
      setState(() {
        _result += '\n\n✅ All fixes completed successfully!\n\nYour market organizer account should now have access to vendor and event management, and your existing JOZO vendor should now be properly associated with Tucker Farmers Market.';
      });
    } catch (e) {
      setState(() {
        _result += '\n\n❌ Error running fix:\n\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _diagnoseProblem() async {
    try {
      final currentUser = await _userProfileService.getCurrentUserProfile();
      final currentUserId = await _userProfileService.getCurrentUserId();
      
      String diagnosisResult = '🔍 DIAGNOSIS:\n\n';
      diagnosisResult += 'Current User ID: $currentUserId\n';
      
      if (currentUser != null) {
        diagnosisResult += 'User Profile Found: ✅\n';
        diagnosisResult += 'User Type: ${currentUser.userType}\n';
        diagnosisResult += 'Managed Markets: ${currentUser.managedMarketIds}\n';
        diagnosisResult += 'Is Market Organizer: ${currentUser.isMarketOrganizer}\n';
      } else {
        diagnosisResult += 'User Profile Found: ❌ MISSING!\n';
        diagnosisResult += 'This is the problem - creating profile now...\n';
        
        // Create the missing profile
        if (currentUserId != null) {
          try {
            await _userProfileService.createMissingOrganizerProfile(currentUserId);
            diagnosisResult += 'Created market organizer profile ✅\n';
          } catch (e) {
            diagnosisResult += 'Failed to create profile: $e\n';
          }
        }
      }
      
      setState(() {
        _result = diagnosisResult;
      });
      
    } catch (e) {
      setState(() {
        _result += 'Diagnosis error: $e\n';
      });
    }
  }

  Future<void> _createTuckersMarket() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      // Create Tucker's Farmers Market
      final tuckersMarket = Market(
        id: '', // Will be auto-generated
        name: 'Tucker\'s Farmers Market',
        address: '4796 LaVista Rd, Tucker, GA 30084',
        city: 'Tucker',
        state: 'GA',
        latitude: 33.8567,  // Approximate coordinates for Tucker, GA
        longitude: -84.2154,
        eventDate: DateTime.now().add(const Duration(days: 7)), // Next Saturday
        startTime: '8:00 AM',
        endTime: '1:00 PM',
        description: 'Tucker\'s premier farmers market featuring local vendors, fresh produce, artisanal goods, and community spirit. Operating since 2010, we support local farmers and makers while bringing the community together every weekend.',
        isActive: true,
        createdAt: DateTime.now(),
      );

      // Add to database
      final marketId = await MarketService.createMarket(tuckersMarket);

      // Add sample vendors to make the market visible to shoppers
      // TODO: Vendor features disabled for ATV Events
      // if (false) {
      //   await _addSampleVendors(marketId);
      // }
      
      String resultText = '🌟 TUCKER\'S FARMERS MARKET CREATED!\n\n';
      resultText += '📍 Market ID: $marketId\n';
      resultText += '📋 Name: ${tuckersMarket.name}\n';
      resultText += '🏠 Address: ${tuckersMarket.address}\n';
      resultText += '⏰ Hours: Saturday 8AM-1PM, Sunday 10AM-2PM\n\n';
      
      resultText += '🔗 SHAREABLE LINKS:\n';
      resultText += '• Production: https://hipop.app/apply/$marketId\n';
      if (kDebugMode) {
        resultText += '• Test: hipop://apply/$marketId\n';
      }
      resultText += '\n';
      
      resultText += '🎯 DEMO READY!\n';
      resultText += 'Use this market for your Tucker\'s Farmers Market demo.\n';
      resultText += 'Show them the vendor application form and management system.\n';
      resultText += 'Market organizers can claim this market by signing up.\n\n';
      
      resultText += '📱 NEXT STEPS:\n';
      resultText += '1. Go to Vendor Applications screen\n';
      resultText += '2. Click "Share Application Link"\n';
      resultText += '3. Copy and test the application form\n';
      resultText += '4. Show Tucker\'s how vendors can apply easily!';
      
      setState(() {
        _result = resultText;
      });

    } catch (e) {
      setState(() {
        _result = '❌ Error creating Tucker\'s Farmers Market:\n\n$e\n\n';
        _result += '🔧 Alternative: Add this data manually:\n';
        _result += '1. Sign in as a market organizer\n';
        _result += '2. Go to Market Management\n';
        _result += '3. Create new market with Tucker\'s details\n';
        _result += '4. Use the vendor application system to demo';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createAfterDarkBazaar() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      // Create After Dark Bazaar market
      final afterDarkMarket = Market(
        id: '', // Will be auto-generated
        name: 'After Dark Bazaar',
        address: '112 Krog Street NE, Atlanta, GA 30307',
        city: 'Atlanta',
        state: 'GA',
        latitude: 33.7557,  // Krog District coordinates
        longitude: -84.3640,
        eventDate: DateTime.now().add(const Duration(days: 5)), // Next Friday
        startTime: '6:00 PM',
        endTime: '10:00 PM',
        description: 'Evening market featuring local artisans, vintage finds, and live music in the heart of Krog District. A unique nighttime shopping experience with handmade goods and creative vibes.',
        isActive: true,
        createdAt: DateTime.now(),
      );

      // Add to database
      final marketId = await MarketService.createMarket(afterDarkMarket);

      // Add sample vendors for the June 13th event
      // TODO: Vendor features disabled for ATV Events
      // if (false) {
      //   await _addAfterDarkVendors(marketId);
      // }
      
      String resultText = '🌙 AFTER DARK BAZAAR CREATED!\\n\\n';
      resultText += '📍 Market ID: $marketId\\n';
      resultText += '📋 Name: ${afterDarkMarket.name}\\n';
      resultText += '🏠 Address: ${afterDarkMarket.address}\\n';
      resultText += '⏰ Hours: Friday 6PM-10PM\\n\\n';
      
      resultText += '🔗 SHAREABLE LINKS:\\n';
      resultText += '• Production: https://hipop.app/apply/$marketId\\n';
      if (kDebugMode) {
        resultText += '• Test: hipop://apply/$marketId\\n';
      }
      resultText += '\\n';
      
      resultText += '🎵 DEMO READY!\\n';
      resultText += 'Evening market with live music and local artisans.\\n';
      resultText += 'Perfect for showcasing unique vendor applications.\\n';
      resultText += 'Features vintage, crafts, and artisanal vendors.\\n\\n';
      
      resultText += '📱 NEXT STEPS:\\n';
      resultText += '1. Go to Vendor Applications screen\\n';
      resultText += '2. Click "Share Application Link"\\n';
      resultText += '3. Show how evening markets work\\n';
      resultText += '4. Demo the nighttime vendor vibe!';
      
      setState(() {
        _result = resultText;
      });

    } catch (e) {
      setState(() {
        _result = '❌ Error creating After Dark Bazaar:\\n\\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // TODO: Vendor features completely disabled for ATV Events
  /*
  Future<void> _addSampleVendors(String marketId) async {
    if (false) {
    try {
      // Create realistic sample vendors for Tucker's Farmers Market
      final sampleVendors = [
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Tucker Valley Farm',
          contactName: 'Sarah Johnson',
          description: 'Family-owned organic farm specializing in seasonal vegetables, herbs, and fresh eggs. We\'ve been serving the Tucker community for over 15 years with the freshest, locally-grown produce.',
          categories: [VendorCategory.produce, VendorCategory.spices],
          email: 'sarah@tuckervalleyfarm.com',
          phoneNumber: '+1-770-555-0123',
          products: ['Organic Tomatoes', 'Fresh Lettuce', 'Seasonal Herbs', 'Farm Eggs', 'Zucchini'],
          isActive: true,
          isFeatured: true,
          operatingDays: ['saturday', 'sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Artisan Bread Co.',
          contactName: 'Michael Chen',
          description: 'Traditional European-style bakery creating handcrafted breads, pastries, and seasonal treats using only natural ingredients and time-honored techniques.',
          categories: [VendorCategory.bakery, VendorCategory.prepared_foods],
          email: 'mike@artisanbreadco.com',
          phoneNumber: '+1-770-555-0456',
          website: 'www.artisanbreadco.com',
          instagramHandle: 'artisanbreadco',
          products: ['Sourdough Bread', 'Croissants', 'Seasonal Pastries', 'Gluten-Free Options'],
          isActive: true,
          isFeatured: false,
          operatingDays: ['saturday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Georgia Honey House',
          contactName: 'Emma Williams',
          description: 'Local beekeepers producing pure, raw honey and natural bee products from our Tucker-area apiaries. Taste the difference that local flowers make!',
          categories: [VendorCategory.honey, VendorCategory.preserves],
          email: 'emma@georgiahoney.com',
          phoneNumber: '+1-770-555-0789',
          products: ['Wildflower Honey', 'Clover Honey', 'Beeswax Candles', 'Honey Soap'],
          isActive: true,
          isFeatured: true,
          operatingDays: ['saturday', 'sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Tucker Craft Works',
          contactName: 'David Rodriguez',
          description: 'Handmade pottery, jewelry, and home decor items crafted by local Tucker artisans. Each piece is unique and made with love for your home.',
          categories: [VendorCategory.crafts, VendorCategory.art, VendorCategory.jewelry],
          email: 'david@tuckercrafts.com',
          instagramHandle: 'tuckercraftworks',
          products: ['Handmade Pottery', 'Silver Jewelry', 'Wooden Bowls', 'Canvas Art'],
          isActive: true,
          isFeatured: false,
          operatingDays: ['saturday', 'sunday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // Add each vendor to the database
      for (final vendor in sampleVendors) {
        await ManagedVendorService.createVendor(vendor);
      }

    } catch (e) {
      // Don't throw - we still want the market creation to succeed
    }
    } // End if (false)
  }
  */

  // TODO: Vendor features completely disabled for ATV Events
  /*
  Future<void> _addAfterDarkVendors(String marketId) async {
    if (false) {
    try {
      // Create vendors for After Dark Bazaar - June 13th event
      final afterDarkVendors = [
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Vintage Vibes ATL',
          contactName: 'Maya Thompson',
          description: 'Curated vintage clothing and accessories from the 70s through 90s. Each piece has been carefully selected for quality and style.',
          categories: [VendorCategory.clothing],
          email: 'maya@vintagevibesatl.com',
          phoneNumber: '+1-404-555-0234',
          instagramHandle: 'vintagevibesatl',
          products: ['Vintage Denim', 'Band T-Shirts', 'Retro Accessories', 'Leather Jackets'],
          isActive: true,
          isFeatured: true,
          operatingDays: ['friday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Midnight Metals',
          contactName: 'Alex Rivera',
          description: 'Handcrafted silver jewelry with gothic and bohemian influences. Each piece tells a story and captures the night market energy.',
          categories: [VendorCategory.jewelry],
          email: 'alex@midnightmetals.com',
          phoneNumber: '+1-404-555-0567',
          instagramHandle: 'midnightmetals',
          products: ['Silver Rings', 'Statement Necklaces', 'Ear Cuffs', 'Custom Pieces'],
          isActive: true,
          isFeatured: false,
          operatingDays: ['friday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Krog Creations',
          contactName: 'Sam Chen',
          description: 'Local artist creating canvas prints inspired by Atlanta street art and pottery pieces perfect for urban living.',
          categories: [VendorCategory.art, VendorCategory.crafts],
          email: 'sam@krogcreations.com',
          phoneNumber: '+1-404-555-0890',
          instagramHandle: 'krogcreations',
          website: 'www.krogcreations.com',
          products: ['Canvas Prints', 'Ceramic Mugs', 'Plant Pots', 'Original Paintings'],
          isActive: true,
          isFeatured: true,
          operatingDays: ['friday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Craft & Draft',
          contactName: 'Jordan Williams',
          description: 'Small-batch kombucha and artisanal beverages brewed locally. Perfect for sipping while browsing the night market.',
          categories: [VendorCategory.beverages],
          email: 'jordan@craftanddraft.com',
          phoneNumber: '+1-404-555-1234',
          instagramHandle: 'craftanddraft',
          products: ['Ginger Kombucha', 'Hibiscus Tea', 'Cold Brew Coffee', 'Fruit Shrubs'],
          isActive: true,
          isFeatured: false,
          operatingDays: ['friday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ManagedVendor(
          id: '',
          marketId: marketId,
          organizerId: 'demo-organizer',
          businessName: 'Night Market Eats',
          contactName: 'Priya Patel',
          description: 'Gourmet snacks and treats made for evening adventures. Sweet and savory options to fuel your night market browsing.',
          categories: [VendorCategory.prepared_foods],
          email: 'priya@nightmarketeats.com',
          phoneNumber: '+1-404-555-5678',
          products: ['Spiced Nuts', 'Dark Chocolate Truffles', 'Savory Hand Pies', 'Herbal Energy Bites'],
          isActive: true,
          isFeatured: false,
          operatingDays: ['friday'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // Add each vendor to the database
      for (final vendor in afterDarkVendors) {
        await ManagedVendorService.createVendor(vendor);
      }

    } catch (e) {
      // Don't throw - we still want the market creation to succeed
    }
    } // End if (false)
  }
  */
}