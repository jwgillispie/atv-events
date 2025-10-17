import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

class DebugManagedVendorCreator extends StatefulWidget {
  const DebugManagedVendorCreator({super.key});

  @override
  State<DebugManagedVendorCreator> createState() => _DebugManagedVendorCreatorState();
}

class _DebugManagedVendorCreatorState extends State<DebugManagedVendorCreator> {
  bool _isCreating = false;
  String? _result;

  Future<void> _createGoldenHourLinksVendor() async {
    setState(() {
      _isCreating = true;
      _result = null;
    });

    try {
      // Create the exact managed_vendor document for Golden Hour Links
      final managedVendorData = {
        // Core identifiers
        'marketId': 'nITYBCLtYJgUJ5wJZijw', // A Day at Dairies market
        'userProfileId': 'RqSwqUB1G4YDam2twTZcS8NBBnS2', // Courtney's vendorId
        'organizerId': 'system_auto_creation', // System auto-created
        
        // Vendor info
        'vendorName': 'Courtney bell',
        'businessName': 'Golden Hour Links',
        'contactName': 'Courtney bell',
        
        // Description from the post
        'description': 'Golden Hour Links offers handmade jewelry rooted in bold self-expression, individuality, and accessible luxury. Our pieces range from gold and silver-toned charm chains to eccentric bolo ties, funky earrings, and beaded accents—designed to encourage people to stand out, express themselves, and feel empowered in what they wear.',
        
        // Categories based on jewelry business
        'categories': ['jewelry', 'accessories', 'handmade'],
        'products': ['Jewelry', 'Accessories', 'Custom Pieces'],
        'specialties': ['Handmade Jewelry', 'Custom Charm Bar', 'Statement Pieces'],
        
        // Contact (placeholder - update if you have real email)
        'email': 'goldenhourlinks@example.com',
        'phoneNumber': null,
        
        // Social
        'instagramHandle': null,
        'facebookHandle': null,
        'website': null,
        
        // Location
        'city': 'Atlanta',
        'state': 'GA',
        'address': null,
        'zipCode': null,
        
        // Features
        'isActive': true,
        'isFeatured': false,
        'acceptsOrders': false,
        'canDeliver': false,
        'isOrganic': false,
        'isLocallySourced': true, // Handmade implies local
        
        // Images
        'imageUrl': null,
        'imageUrls': [],
        'logoUrl': null,
        
        // Metadata tracking
        'metadata': {
          'autoCreated': true,
          'createdVia': 'vendor_post',
          'linkedUserProfileId': 'RqSwqUB1G4YDam2twTZcS8NBBnS2',
          'sourcePostType': 'market',
          'createdFromMarketPost': true,
          'debugCreated': true,
          'debugCreatedAt': DateTime.now().toIso8601String(),
        },
        
        // Timestamps
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        
        // Other fields
        'priceRange': null,
        'slogan': null,
        'story': null,
        'tags': ['jewelry', 'handmade', 'accessories', 'custom'],
        'operatingDays': [],
        'boothPreferences': null,
        'specialRequirements': null,
        'certifications': null,
        'deliveryNotes': null,
        'ccEmails': [],
        'specificProducts': null,
      };

      // Check if already exists
      final existingQuery = await FirebaseFirestore.instance
          .collection('managed_vendors')
          .where('marketId', isEqualTo: 'nITYBCLtYJgUJ5wJZijw')
          .where('userProfileId', isEqualTo: 'RqSwqUB1G4YDam2twTZcS8NBBnS2')
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        setState(() {
          _result = 'Managed vendor already exists! Doc ID: ${existingQuery.docs.first.id}';
          _isCreating = false;
        });
        return;
      }

      // Create the document
      final docRef = await FirebaseFirestore.instance
          .collection('managed_vendors')
          .add(managedVendorData);

      setState(() {
        _result = 'Success! Created managed_vendor with ID: ${docRef.id}';
        _isCreating = false;
      });

      // Also update the market's associatedVendorIds
      await FirebaseFirestore.instance
          .collection('markets')
          .doc('nITYBCLtYJgUJ5wJZijw')
          .update({
        'associatedVendorIds': FieldValue.arrayUnion(['RqSwqUB1G4YDam2twTZcS8NBBnS2']),
      });

    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isCreating = false;
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
          color: Colors.orange,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'DEBUG: Create Missing Managed Vendor',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Golden Hour Links @ A Day at Dairies',
            style: TextStyle(color: HiPopColors.darkTextSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _createGoldenHourLinksVendor,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: _isCreating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Create Managed Vendor'),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _result!.startsWith('Success')
                    ? Colors.green.withOpacity(0.2)
                    : _result!.startsWith('Managed vendor already')
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _result!,
                style: TextStyle(
                  color: _result!.startsWith('Success')
                      ? Colors.green
                      : _result!.startsWith('Managed vendor already')
                      ? Colors.blue
                      : Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}