import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

/// Debug widget to import Community Market ATL markets from CSV
class DebugCsvMarketImporter extends StatefulWidget {
  const DebugCsvMarketImporter({super.key});

  @override
  State<DebugCsvMarketImporter> createState() => _DebugCsvMarketImporterState();
}

class _DebugCsvMarketImporterState extends State<DebugCsvMarketImporter> {
  bool _isImporting = false;
  String _status = '';
  int _importedCount = 0;
  final List<String> _logs = [];

  // Hardcoded Community Market ATL organizer ID
  final String _organizerId = 'PE4unHA9RzcaTDh8JCidnHUMMy22';
  final String _organizerName = 'Community Market ATL';

  // Venue address mapping
  final Map<String, Map<String, dynamic>> _venueData = {
    'BROAD ST BOARDWALK': {
      'address': '54 Broad St NW',
      'city': 'Atlanta',
      'state': 'GA',
      'zipCode': '30303',
      'latitude': 33.7569,
      'longitude': -84.3879,
      'neighborhood': 'Downtown',
    },
    'El tesoro': {
      'address': '1374 Arkwright Pl SE',
      'city': 'Atlanta',
      'state': 'GA',
      'zipCode': '30317',
      'latitude': 33.7494,
      'longitude': -84.3426,
      'neighborhood': 'Edgewood',
    },
    'Liminal Space ': {
      'address': '483 Moreland Ave NE',
      'city': 'Atlanta',
      'state': 'GA',
      'zipCode': '30307',
      'latitude': 33.7630,
      'longitude': -84.3503,
      'neighborhood': 'Little 5 Points',
    },
    'Collective Liberation ; ATL Radical Art': {
      'address': '675 Metropolitan Parkway SW',
      'city': 'Atlanta',
      'state': 'GA',
      'zipCode': '30310',
      'latitude': 33.7320,
      'longitude': -84.4087,
      'neighborhood': null,
    },
    'Finca to Filter': {
      'address': '652 Angier Ave NE',
      'city': 'Atlanta',
      'state': 'GA',
      'zipCode': '30308',
      'latitude': 33.7697,
      'longitude': -84.3628,
      'neighborhood': 'Old Fourth Ward',
    },
    'KROG DISTRICT - STOVE WORKS': {
      'address': '112 Krog St NE',
      'city': 'Atlanta',
      'state': 'GA',
      'zipCode': '30307',
      'latitude': 33.7560,
      'longitude': -84.3595,
      'neighborhood': 'Inman Park',
    },
  };

  void _addLog(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
      _status = message;
    });
  }

  Future<void> _importMarkets() async {
    // Prevent duplicate imports
    if (_isImporting) {
      _addLog('⚠️ Import already in progress');
      return;
    }

    // Check if user is logged in
    if (_organizerId.isEmpty) {
      setState(() {
        _status = '❌ Error: No user logged in';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ You must be logged in to import markets'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
      return;
    }

    setState(() {
      _isImporting = true;
      _importedCount = 0;
      _logs.clear();
      _status = 'Starting import...';
    });

    try {
      _addLog('Loading CSV from assets...');
      _addLog('Importing as: $_organizerName (ID: $_organizerId)');

      // Load CSV from assets
      final csvString = await rootBundle.loadString('assets/FALL 2025 - CM Market Schedule.csv');

      _addLog('Parsing CSV data...');

      // Parse CSV
      final List<List<dynamic>> csvData = const CsvToListConverter().convert(csvString);

      // Skip header rows and get market data
      final List<Map<String, dynamic>> markets = [];

      for (int i = 2; i < csvData.length; i++) {
        final row = csvData[i];

        // Skip empty rows or rows with "Various"
        if (row.length < 4 || row[0].toString().isEmpty || row[1].toString() == 'Various') {
          continue;
        }

        final month = row[0].toString();
        final venue = row[1].toString();
        final dateStr = row[2].toString();
        final timeStr = row[3].toString();

        // Skip if missing critical data
        if (month.isEmpty || venue.isEmpty || dateStr.isEmpty) {
          continue;
        }

        // Get venue data
        final venueInfo = _venueData[venue];
        if (venueInfo == null) {
          _addLog('⚠️ Unknown venue: $venue');
          continue;
        }

        // Parse date
        final DateTime? eventDate = _parseDate(dateStr, month);
        if (eventDate == null) {
          _addLog('⚠️ Could not parse date: $dateStr');
          continue;
        }

        // Parse time
        final times = _parseTime(timeStr);

        markets.add({
          'venue': venue,
          'venueInfo': venueInfo,
          'eventDate': eventDate,
          'startTime': times['start'],
          'endTime': times['end'],
          'dateStr': dateStr,
          'timeStr': timeStr,
        });
      }

      _addLog('Found ${markets.length} markets to import');

      // Import markets to Firestore
      final firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();
      int batchCount = 0;

      for (final market in markets) {
        final venueInfo = market['venueInfo'] as Map<String, dynamic>;
        final eventDate = market['eventDate'] as DateTime;

        // Create market document
        final marketRef = firestore.collection('markets').doc();

        // Generate search keywords
        final keywords = _generateSearchKeywords(
          venueInfo['address'],
          venueInfo['city'],
          venueInfo['state'],
          market['venue'],
        );

        final marketData = {
          'address': venueInfo['address'],
          'applicationDeadline': null,
          'applicationFee': 0,
          'applicationUrl': '',
          'associatedVendorIds': [],
          'city': venueInfo['city'],
          'createdAt': FieldValue.serverTimestamp(),
          'dailyBoothFee': 0,
          'description': 'Community Market Atlanta is a space of support and kindness for LGBTQIA2S+ and Strong Ally creatives looking to expand their business, find community and celebrate Queer joy. Created by artists to gain income, share skills and help each other grow year round! WE PRIORITIZE LGBTQIA2S+ VENDORS AT ALL EVENTS FIRST.',
          'endTime': market['endTime'],
          'eventDate': Timestamp.fromDate(eventDate),
          'flyerUrls': [],
          'imageUrl': null,
          'instagramHandle': '@communitymarketatl',
          'isActive': true,
          'isLookingForVendors': false,
          'isRecruitmentOnly': false,
          'latitude': venueInfo['latitude'],
          'longitude': venueInfo['longitude'],
          'locationData': {
            'city': venueInfo['city'],
            'cityState': '${venueInfo['city']}, ${venueInfo['state']}',
            'coordinates': GeoPoint(venueInfo['latitude'], venueInfo['longitude']),
            'geohash': _generateGeohash(venueInfo['latitude'], venueInfo['longitude']),
            'metroArea': 'Atlanta Metro',
            'neighborhood': venueInfo['neighborhood'],
            'originalLocationString': '${venueInfo['address']}, ${venueInfo['city']}, ${venueInfo['state']}',
            'searchKeywords': keywords,
            'shortAddress': '${venueInfo['address']}, ${venueInfo['city']}',
            'state': venueInfo['state'],
            'streetName': _extractStreetName(venueInfo['address']),
            'streetNumber': _extractStreetNumber(venueInfo['address']),
            'zipCode': venueInfo['zipCode'],
          },
          'marketType': 'community',
          'name': 'Community Market ATL @ ${market['venue']}',
          'organizerId': _organizerId,
          'organizerName': _organizerName,
          'placeId': null,
          'startTime': market['startTime'],
          'state': venueInfo['state'],
          'targetCategories': null,
          'vendorRequirements': '',
          'vendorSpotsAvailable': null,
          'vendorSpotsTotal': null,
        };

        batch.set(marketRef, marketData);
        batchCount++;

        // Firestore batch limit is 500, commit if we reach it
        if (batchCount >= 500) {
          await batch.commit();
          _addLog('Committed batch of $batchCount markets');
          batch = firestore.batch(); // Create new batch
          batchCount = 0;
        }

        _importedCount++;
        _addLog('✓ ${market['venue']} on ${market['dateStr']}');
      }

      // Commit remaining batch
      if (batchCount > 0) {
        await batch.commit();
        _addLog('Committed final batch of $batchCount markets');
      }

      _addLog('✅ Successfully imported $_importedCount markets!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully imported $_importedCount markets!'),
            backgroundColor: HiPopColors.successGreen,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      _addLog('❌ Error: $e');
      print('Import error: $e');
      print(stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Import failed: $e'),
            backgroundColor: HiPopColors.errorPlum,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  DateTime? _parseDate(String dateStr, String month) {
    try {
      // Format: "Thursday October 2" or "Saturday October 4"
      final parts = dateStr.split(' ');
      if (parts.length < 3) return null;

      final monthName = parts[1];
      final day = int.parse(parts[2]);

      // Map month name to number
      final monthMap = {
        'October': 10,
        'November': 11,
        'December': 12,
      };

      final monthNum = monthMap[monthName];
      if (monthNum == null) return null;

      return DateTime(2025, monthNum, day);
    } catch (e) {
      return null;
    }
  }

  Map<String, String> _parseTime(String timeStr) {
    try {
      // Format: "11 - 2:30pm" or "12-5pm" or "10-3pm"
      if (timeStr.isEmpty) {
        return {'start': '10:00 AM', 'end': '5:00 PM'};
      }

      // Remove spaces and split by dash
      final cleaned = timeStr.replaceAll(' ', '');
      final parts = cleaned.split('-');

      if (parts.length != 2) {
        return {'start': '10:00 AM', 'end': '5:00 PM'};
      }

      String startTime = _formatTime(parts[0]);
      String endTime = _formatTime(parts[1]);

      return {'start': startTime, 'end': endTime};
    } catch (e) {
      return {'start': '10:00 AM', 'end': '5:00 PM'};
    }
  }

  String _formatTime(String time) {
    // Remove any remaining spaces
    time = time.trim();

    // Check if it has AM/PM
    final hasAmPm = time.toLowerCase().contains('am') || time.toLowerCase().contains('pm');
    String period = 'PM'; // Default to PM for markets

    if (hasAmPm) {
      period = time.toLowerCase().contains('am') ? 'AM' : 'PM';
      time = time.replaceAll(RegExp(r'[ap]m', caseSensitive: false), '');
    }

    // Parse the time
    final parts = time.split(':');
    int hour = int.parse(parts[0]);
    int minute = parts.length > 1 ? int.parse(parts[1]) : 0;

    // Convert to 12-hour format if needed
    if (hour > 12) {
      hour -= 12;
      period = 'PM';
    } else if (hour == 0) {
      hour = 12;
      period = 'AM';
    }

    return '$hour:${minute.toString().padLeft(2, '0')} $period';
  }

  List<String> _generateSearchKeywords(String address, String city, String state, String venue) {
    final keywords = <String>{};

    // Add full strings
    keywords.add(address.toLowerCase());
    keywords.add('$city, $state'.toLowerCase());
    keywords.add(city.toLowerCase());
    keywords.add(state.toLowerCase());
    keywords.add(venue.toLowerCase());
    keywords.add('atlanta metro');
    keywords.add('community market atl');
    keywords.add('lgbtq');
    keywords.add('lgbtqia');

    // Add progressive substrings for each word
    final words = [
      ...address.toLowerCase().split(' '),
      ...city.toLowerCase().split(' '),
      venue.toLowerCase(),
    ];

    for (final word in words) {
      if (word.isEmpty) continue;
      for (int i = 3; i <= word.length; i++) {
        keywords.add(word.substring(0, i));
      }
    }

    return keywords.toList()..sort();
  }

  String _generateGeohash(double lat, double lng) {
    // Simple geohash generation (7 chars precision)
    const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

    double minLat = -90.0, maxLat = 90.0;
    double minLng = -180.0, maxLng = 180.0;

    String geohash = '';
    int idx = 0;
    int bit = 0;
    bool evenBit = true;

    while (geohash.length < 9) {
      if (evenBit) {
        // Longitude
        final mid = (minLng + maxLng) / 2;
        if (lng > mid) {
          idx = (idx << 1) + 1;
          minLng = mid;
        } else {
          idx = idx << 1;
          maxLng = mid;
        }
      } else {
        // Latitude
        final mid = (minLat + maxLat) / 2;
        if (lat > mid) {
          idx = (idx << 1) + 1;
          minLat = mid;
        } else {
          idx = idx << 1;
          maxLat = mid;
        }
      }

      evenBit = !evenBit;

      if (bit < 4) {
        bit++;
      } else {
        geohash += base32[idx];
        bit = 0;
        idx = 0;
      }
    }

    return geohash;
  }

  String _extractStreetNumber(String address) {
    final parts = address.split(' ');
    return parts.isNotEmpty ? parts[0] : '';
  }

  String _extractStreetName(String address) {
    final parts = address.split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  Future<void> _importOct4ElTesoro() async {
    // Prevent duplicate imports
    if (_isImporting) {
      _addLog('⚠️ Import already in progress');
      return;
    }

    setState(() {
      _isImporting = true;
      _logs.clear();
      _status = 'Importing Oct 4 El tesoro...';
    });

    try {
      _addLog('Checking for existing Oct 4 El tesoro market...');

      final firestore = FirebaseFirestore.instance;

      // Check if market already exists
      final existingMarket = await firestore
          .collection('markets')
          .where('organizerId', isEqualTo: _organizerId)
          .where('eventDate', isEqualTo: Timestamp.fromDate(DateTime(2025, 10, 4)))
          .where('name', isEqualTo: 'Community Market ATL @ El tesoro')
          .limit(1)
          .get();

      if (existingMarket.docs.isNotEmpty) {
        _addLog('⚠️ Market already exists, skipping import');
        setState(() {
          _status = '⚠️ Oct 4 El tesoro market already exists';
          _isImporting = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Oct 4 El tesoro market already exists'),
              backgroundColor: HiPopColors.warningAmber,
            ),
          );
        }
        return;
      }

      _addLog('Creating Oct 4 El tesoro market...');

      // Get venue data
      final venueInfo = _venueData['El tesoro']!;
      final eventDate = DateTime(2025, 10, 4);

      // Create market document
      final marketRef = firestore.collection('markets').doc();

      // Generate search keywords
      final keywords = _generateSearchKeywords(
        venueInfo['address'],
        venueInfo['city'],
        venueInfo['state'],
        'El tesoro',
      );

      final marketData = {
        'address': venueInfo['address'],
        'applicationDeadline': null,
        'applicationFee': 0,
        'applicationUrl': '',
        'associatedVendorIds': [],
        'city': venueInfo['city'],
        'createdAt': FieldValue.serverTimestamp(),
        'dailyBoothFee': 0,
        'description': 'Community Market Atlanta is a space of support and kindness for LGBTQIA2S+ and Strong Ally creatives looking to expand their business, find community and celebrate Queer joy. Created by artists to gain income, share skills and help each other grow year round! WE PRIORITIZE LGBTQIA2S+ VENDORS AT ALL EVENTS FIRST.',
        'endTime': '5:00 PM',
        'eventDate': Timestamp.fromDate(eventDate),
        'flyerUrls': [],
        'imageUrl': null,
        'instagramHandle': '@communitymarketatl',
        'isActive': true,
        'isLookingForVendors': false,
        'isRecruitmentOnly': false,
        'latitude': venueInfo['latitude'],
        'longitude': venueInfo['longitude'],
        'locationData': {
          'city': venueInfo['city'],
          'cityState': '${venueInfo['city']}, ${venueInfo['state']}',
          'coordinates': GeoPoint(venueInfo['latitude'], venueInfo['longitude']),
          'geohash': _generateGeohash(venueInfo['latitude'], venueInfo['longitude']),
          'metroArea': 'Atlanta Metro',
          'neighborhood': venueInfo['neighborhood'],
          'originalLocationString': '${venueInfo['address']}, ${venueInfo['city']}, ${venueInfo['state']}',
          'searchKeywords': keywords,
          'shortAddress': '${venueInfo['address']}, ${venueInfo['city']}',
          'state': venueInfo['state'],
          'streetName': _extractStreetName(venueInfo['address']),
          'streetNumber': _extractStreetNumber(venueInfo['address']),
          'zipCode': venueInfo['zipCode'],
        },
        'marketType': 'community',
        'name': 'Community Market ATL @ El tesoro',
        'organizerId': _organizerId,
        'organizerName': _organizerName,
        'placeId': null,
        'startTime': '12:00 PM',
        'state': venueInfo['state'],
        'targetCategories': null,
        'vendorRequirements': '',
        'vendorSpotsAvailable': null,
        'vendorSpotsTotal': null,
      };

      await marketRef.set(marketData);

      _addLog('✅ Successfully imported Oct 4 El tesoro market!');
      setState(() {
        _importedCount = 1;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Successfully imported Oct 4 El tesoro market!'),
            backgroundColor: HiPopColors.successGreen,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      _addLog('❌ Error: $e');
      print('Import error: $e');
      print(stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Import failed: $e'),
            backgroundColor: HiPopColors.errorPlum,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: HiPopColors.darkSurface,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.upload_file,
                  color: HiPopColors.warningAmber,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CSV Market Importer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Import Community Market ATL Fall 2025 schedule',
                        style: TextStyle(
                          fontSize: 12,
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status
            if (_status.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HiPopColors.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (_isImporting)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(HiPopColors.primaryDeepSage),
                        ),
                      )
                    else
                      Icon(
                        _status.contains('✅') ? Icons.check_circle : Icons.info,
                        color: _status.contains('✅')
                          ? HiPopColors.successGreen
                          : HiPopColors.infoBlueGray,
                        size: 16,
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _status,
                        style: const TextStyle(
                          fontSize: 12,
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Import count
            if (_importedCount > 0) ...[
              Text(
                'Imported: $_importedCount markets',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: HiPopColors.successGreen,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Logs
            if (_logs.isNotEmpty) ...[
              Container(
                height: 200,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: HiPopColors.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: HiPopColors.darkBorder),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _logs[index],
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Import button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isImporting ? null : _importMarkets,
                icon: _isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.upload),
                label: Text(_isImporting ? 'Importing...' : 'Import Markets from CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isImporting
                    ? Colors.grey
                    : HiPopColors.warningAmber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 8),
            const Text(
              '⚠️ This will import 25+ markets for Community Market ATL',
              style: TextStyle(
                fontSize: 11,
                color: HiPopColors.warningAmber,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 16),
            const Divider(color: HiPopColors.darkBorder),
            const SizedBox(height: 16),

            // Single market import button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isImporting ? null : _importOct4ElTesoro,
                icon: _isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.add_location),
                label: Text(_isImporting ? 'Importing...' : 'Import Oct 4 El Tesoro Only'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isImporting
                    ? Colors.grey
                    : HiPopColors.primaryDeepSage,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 8),
            const Text(
              'Import only the missing October 4th El tesoro market',
              style: TextStyle(
                fontSize: 11,
                color: HiPopColors.darkTextSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
