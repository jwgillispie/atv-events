import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:atv_events/features/shared/models/location_data.dart';
import 'dart:math' as math;

/// Service for handling location data parsing, geohash generation, and search optimization
class LocationDataService {
  
  /// Creates optimized LocationData from raw location information
  static LocationData createLocationData({
    required String locationString,
    double? latitude,
    double? longitude,
    String? placeId,
    String? locationName,
  }) {
    try {
      final parsedAddress = _parseAddress(locationString);
      final metroArea = _detectMetroArea(parsedAddress['city']);
      final coordinates = (latitude != null && longitude != null) 
          ? GeoPoint(latitude, longitude) 
          : null;
      final geohash = coordinates != null 
          ? _generateGeohash(coordinates.latitude, coordinates.longitude) 
          : null;
      final searchKeywords = _generateSearchKeywords(
        locationString, parsedAddress, metroArea,
      );
      
      return LocationData(
        streetNumber: parsedAddress['streetNumber'],
        streetName: parsedAddress['streetName'],
        city: parsedAddress['city'],
        state: parsedAddress['state'],
        zipCode: parsedAddress['zipCode'],
        neighborhood: _detectNeighborhood(locationString, parsedAddress['city']),
        metroArea: metroArea,
        coordinates: coordinates,
        geohash: geohash,
        searchKeywords: searchKeywords,
        cityState: _buildCityState(parsedAddress['city'], parsedAddress['state']),
        shortAddress: _buildShortAddress(parsedAddress),
        originalLocationString: locationString,
      );
    } catch (e) {
      // Return minimal structure on error
      return LocationData(
        originalLocationString: locationString,
        searchKeywords: _generateBasicKeywords(locationString),
      );
    }
  }

  /// Parse address string into components
  static Map<String, String?> _parseAddress(String address) {
    final result = <String, String?>{
      'streetNumber': null,
      'streetName': null,
      'city': null,
      'state': null,
      'zipCode': null,
    };

    if (address.isEmpty) return result;

    // Clean up the address
    final cleanAddress = address.trim();
    
    // Split by commas to get main components
    final parts = cleanAddress.split(',').map((p) => p.trim()).toList();
    
    if (parts.isEmpty) return result;

    // Extract ZIP code (typically 5 digits, optionally followed by 4 more)
    final zipRegex = RegExp(r'\b(\d{5}(?:-\d{4})?)\b');
    final zipMatch = zipRegex.firstMatch(cleanAddress);
    if (zipMatch != null) {
      result['zipCode'] = zipMatch.group(1);
    }

    // Extract state (last part if it looks like a state)
    if (parts.length >= 2) {
      final lastPart = parts.last.replaceAll(RegExp(r'\d{5}(?:-\d{4})?'), '').trim();
      if (lastPart.length == 2 && lastPart.toUpperCase() == lastPart) {
        result['state'] = lastPart.toUpperCase();
      } else if (_isStateName(lastPart)) {
        result['state'] = _getStateAbbreviation(lastPart);
      }
    }

    // Extract city (second to last part, or before state info)
    if (parts.length >= 2) {
      String cityCandidate = parts[parts.length - 2].trim();
      // Remove any zip code that might be attached
      cityCandidate = cityCandidate.replaceAll(RegExp(r'\s*\d{5}(?:-\d{4})?\s*'), '').trim();
      if (cityCandidate.isNotEmpty) {
        result['city'] = _capitalizeWords(cityCandidate);
      }
    } else if (parts.length == 1) {
      // If only one part, it might just be a city
      final singlePart = parts.first.replaceAll(RegExp(r'\d{5}(?:-\d{4})?'), '').trim();
      if (singlePart.isNotEmpty && !_isStreetAddress(singlePart)) {
        result['city'] = _capitalizeWords(singlePart);
      }
    }

    // Extract street information from the first part
    if (parts.isNotEmpty) {
      final streetPart = parts.first.trim();
      final streetInfo = _parseStreetAddress(streetPart);
      result['streetNumber'] = streetInfo['number'];
      result['streetName'] = streetInfo['name'];
    }

    return result;
  }

  /// Parse street address into number and name
  static Map<String, String?> _parseStreetAddress(String street) {
    final Map<String, String?> result = {'number': null, 'name': null};
    
    if (street.isEmpty) return result;
    
    // Look for number at the beginning
    final streetRegex = RegExp(r'^(\d+[A-Z]?)\s+(.+)$', caseSensitive: false);
    final match = streetRegex.firstMatch(street);
    
    if (match != null) {
      result['number'] = match.group(1);
      result['name'] = _capitalizeWords(match.group(2)!);
    } else if (!_isStreetAddress(street)) {
      // If it doesn't look like a street address, it might be a venue name
      result['name'] = _capitalizeWords(street);
    }
    
    return result;
  }

  /// Check if a string looks like a street address
  static bool _isStreetAddress(String text) {
    return RegExp(r'^\d+\s+\w+', caseSensitive: false).hasMatch(text) ||
           text.toLowerCase().contains(RegExp(r'\b(street|st|avenue|ave|road|rd|drive|dr|lane|ln|boulevard|blvd|way|court|ct|place|pl|circle|cir)\b'));
  }

  /// Detect neighborhood from location string and city
  static String? _detectNeighborhood(String locationString, String? city) {
    if (city == null) return null;
    
    final location = locationString.toLowerCase();
    final cityLower = city.toLowerCase();
    
    // Atlanta neighborhoods
    if (cityLower.contains('atlanta')) {
      final atlantaNeighborhoods = {
        'midtown': ['midtown', 'mid town', 'mid-town'],
        'buckhead': ['buckhead', 'buck head'],
        'virginia-highland': ['virginia highland', 'virginia-highland', 'vahi'],
        'little five points': ['little five points', 'little 5 points', 'l5p'],
        'old fourth ward': ['old fourth ward', 'old 4th ward', 'o4w'],
        'grant park': ['grant park'],
        'cabbagetown': ['cabbagetown', 'cabbage town'],
        'inman park': ['inman park'],
        'piedmont park': ['piedmont park'],
        'atlantic station': ['atlantic station'],
        'west end': ['west end'],
        'east atlanta': ['east atlanta', 'eav'],
        'decatur': ['decatur'],
        'druid hills': ['druid hills'],
        'morningside': ['morningside'],
        'candler park': ['candler park'],
        'reynoldstown': ['reynoldstown'],
        'summerhill': ['summerhill'],
        'downtown': ['downtown', 'dtl'],
      };
      
      for (final entry in atlantaNeighborhoods.entries) {
        for (final alias in entry.value) {
          if (location.contains(alias)) {
            return entry.key;
          }
        }
      }
    }
    
    return null;
  }

  /// Detect metro area from city
  static String? _detectMetroArea(String? city) {
    if (city == null) return null;
    
    final cityLower = city.toLowerCase();
    
    // Georgia metro areas
    final metroAreas = {
      'Atlanta Metro': [
        'atlanta', 'decatur', 'marietta', 'alpharetta', 'roswell', 
        'sandy springs', 'dunwoody', 'brookhaven', 'chamblee', 
        'doraville', 'smyrna', 'vinings', 'buckhead', 'midtown',
        'norcross', 'duluth', 'suwanee', 'johns creek', 'cumming',
        'kennesaw', 'acworth', 'woodstock', 'canton', 'ball ground',
        'lawrenceville', 'snellville', 'lilburn', 'tucker', 'clarkston',
        'stone mountain', 'lithonia', 'conyers', 'covington', 'loganville',
        'powder springs', 'austell', 'mableton', 'douglasville', 'villa rica',
        'carrollton', 'newnan', 'peachtree city', 'fayetteville', 'stockbridge',
        'mcdonough', 'locust grove', 'hampton', 'forest park', 'jonesboro',
        'riverdale', 'morrow', 'rex', 'ellenwood', 'college park',
      ],
      'Athens Metro': ['athens', 'commerce', 'jefferson', 'madison'],
      'Augusta Metro': ['augusta', 'evans', 'martinez', 'grovetown'],
      'Savannah Metro': ['savannah', 'richmond hill', 'pooler', 'tybee island'],
      'Columbus Metro': ['columbus', 'phenix city'],
      'Macon Metro': ['macon', 'warner robins', 'centerville', 'byron'],
    };
    
    for (final entry in metroAreas.entries) {
      for (final metroCity in entry.value) {
        if (cityLower.contains(metroCity) || metroCity.contains(cityLower)) {
          return entry.key;
        }
      }
    }
    
    // Default to city if no metro area detected
    return '${_capitalizeWords(city)} Area';
  }

  /// Generate comprehensive search keywords
  static List<String> _generateSearchKeywords(
    String originalLocation, 
    Map<String, String?> parsedAddress,
    String? metroArea,
  ) {
    final keywords = <String>{};
    
    // Add original location variants
    final normalizedLocation = originalLocation.toLowerCase().trim();
    keywords.add(normalizedLocation);
    
    // Add parsed components
    [
      parsedAddress['city'],
      parsedAddress['state'],
      parsedAddress['streetName'],
      parsedAddress['neighborhood'],
      metroArea,
    ].whereType<String>().forEach((component) {
      final normalized = component.toLowerCase().trim();
      keywords.add(normalized);
      
      // Add word fragments for partial matching
      final words = normalized.split(RegExp(r'[,\s\-]+'));
      for (final word in words) {
        if (word.length > 2) {
          keywords.add(word);
          // Add progressively shorter prefixes for autocomplete
          for (int i = 3; i <= word.length; i++) {
            keywords.add(word.substring(0, i));
          }
        }
      }
    });
    
    // Add city-state combinations
    if (parsedAddress['city'] != null && parsedAddress['state'] != null) {
      final cityState = '${parsedAddress['city']!.toLowerCase()} ${parsedAddress['state']!.toLowerCase()}';
      keywords.add(cityState);
      keywords.add('${parsedAddress['city']!.toLowerCase()}, ${parsedAddress['state']!.toLowerCase()}');
    }
    
    // Add common abbreviations and synonyms
    _addLocationSynonyms(keywords, parsedAddress['city']);
    
    // Clean up and filter keywords
    return keywords
        .where((k) => k.isNotEmpty && k.length >= 2)
        .toList()
        ..sort();
  }

  /// Generate basic keywords when detailed parsing fails
  static List<String> _generateBasicKeywords(String location) {
    final keywords = <String>{};
    final normalized = location.toLowerCase().trim();
    keywords.add(normalized);
    
    final words = normalized.split(RegExp(r'[,\s]+'));
    for (final word in words) {
      if (word.isNotEmpty && word.length >= 2) {
        keywords.add(word);
      }
    }
    
    return keywords.toList()..sort();
  }

  /// Add location-specific synonyms and abbreviations
  static void _addLocationSynonyms(Set<String> keywords, String? city) {
    if (city == null) return;
    
    final cityLower = city.toLowerCase();
    final synonyms = <String, List<String>>{
      'atlanta': ['atl', 'hotlanta', 'the a', 'atlien'],
      'decatur': ['dec'],
      'marietta': ['mary-etta'],
      'alpharetta': ['alph', 'alpharetta ga'],
      'virginia highland': ['vahi', 'va-hi'],
      'little five points': ['l5p', 'little 5 points'],
      'old fourth ward': ['o4w', 'old 4th ward'],
      'east atlanta village': ['eav'],
      'midtown atlanta': ['midtown atl', 'mid atlanta'],
    };
    
    for (final entry in synonyms.entries) {
      if (cityLower.contains(entry.key) || entry.key.contains(cityLower)) {
        keywords.addAll(entry.value);
      }
    }
  }

  /// Generate geohash for proximity searches
  static String _generateGeohash(double latitude, double longitude, {int precision = 9}) {
    // Simple geohash implementation for proximity searches
    // Using base32 encoding: 0123456789bcdefghjkmnpqrstuvwxyz
    const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
    
    double minLat = -90.0, maxLat = 90.0;
    double minLon = -180.0, maxLon = 180.0;
    
    String geohash = '';
    int bits = 0;
    int bitCount = 0;
    bool evenBit = true;
    
    while (geohash.length < precision) {
      double mid;
      if (evenBit) {
        // longitude
        mid = (minLon + maxLon) / 2;
        if (longitude > mid) {
          bits = (bits << 1) + 1;
          minLon = mid;
        } else {
          bits = bits << 1;
          maxLon = mid;
        }
      } else {
        // latitude
        mid = (minLat + maxLat) / 2;
        if (latitude > mid) {
          bits = (bits << 1) + 1;
          minLat = mid;
        } else {
          bits = bits << 1;
          maxLat = mid;
        }
      }
      
      evenBit = !evenBit;
      bitCount++;
      
      if (bitCount == 5) {
        geohash += base32[bits];
        bits = 0;
        bitCount = 0;
      }
    }
    
    return geohash;
  }

  /// Build city, state display string
  static String? _buildCityState(String? city, String? state) {
    if (city == null) return null;
    if (state == null) return city;
    return '$city, $state';
  }

  /// Build short address for display
  static String? _buildShortAddress(Map<String, String?> parsedAddress) {
    final parts = <String>[];
    
    if (parsedAddress['streetNumber'] != null && parsedAddress['streetName'] != null) {
      parts.add('${parsedAddress['streetNumber']} ${parsedAddress['streetName']}');
    } else if (parsedAddress['streetName'] != null) {
      parts.add(parsedAddress['streetName']!);
    }
    
    if (parsedAddress['city'] != null) {
      parts.add(parsedAddress['city']!);
    }
    
    return parts.isNotEmpty ? parts.join(', ') : null;
  }

  /// Check if text is a state name
  static bool _isStateName(String text) {
    final stateNames = {
      'alabama', 'alaska', 'arizona', 'arkansas', 'california', 'colorado',
      'connecticut', 'delaware', 'florida', 'georgia', 'hawaii', 'idaho',
      'illinois', 'indiana', 'iowa', 'kansas', 'kentucky', 'louisiana',
      'maine', 'maryland', 'massachusetts', 'michigan', 'minnesota',
      'mississippi', 'missouri', 'montana', 'nebraska', 'nevada',
      'new hampshire', 'new jersey', 'new mexico', 'new york',
      'north carolina', 'north dakota', 'ohio', 'oklahoma', 'oregon',
      'pennsylvania', 'rhode island', 'south carolina', 'south dakota',
      'tennessee', 'texas', 'utah', 'vermont', 'virginia', 'washington',
      'west virginia', 'wisconsin', 'wyoming'
    };
    
    return stateNames.contains(text.toLowerCase());
  }

  /// Get state abbreviation from full name
  static String _getStateAbbreviation(String stateName) {
    final stateMap = {
      'alabama': 'AL', 'alaska': 'AK', 'arizona': 'AZ', 'arkansas': 'AR',
      'california': 'CA', 'colorado': 'CO', 'connecticut': 'CT', 'delaware': 'DE',
      'florida': 'FL', 'georgia': 'GA', 'hawaii': 'HI', 'idaho': 'ID',
      'illinois': 'IL', 'indiana': 'IN', 'iowa': 'IA', 'kansas': 'KS',
      'kentucky': 'KY', 'louisiana': 'LA', 'maine': 'ME', 'maryland': 'MD',
      'massachusetts': 'MA', 'michigan': 'MI', 'minnesota': 'MN',
      'mississippi': 'MS', 'missouri': 'MO', 'montana': 'MT', 'nebraska': 'NE',
      'nevada': 'NV', 'new hampshire': 'NH', 'new jersey': 'NJ', 'new mexico': 'NM',
      'new york': 'NY', 'north carolina': 'NC', 'north dakota': 'ND', 'ohio': 'OH',
      'oklahoma': 'OK', 'oregon': 'OR', 'pennsylvania': 'PA', 'rhode island': 'RI',
      'south carolina': 'SC', 'south dakota': 'SD', 'tennessee': 'TN', 'texas': 'TX',
      'utah': 'UT', 'vermont': 'VT', 'virginia': 'VA', 'washington': 'WA',
      'west virginia': 'WV', 'wisconsin': 'WI', 'wyoming': 'WY'
    };
    
    return stateMap[stateName.toLowerCase()] ?? stateName.toUpperCase();
  }

  /// Capitalize words in a string
  static String _capitalizeWords(String text) {
    return text
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : word)
        .join(' ');
  }

  /// Get geohash neighbors for proximity searches
  static List<String> getGeohashNeighbors(String geohash) {
    if (geohash.isEmpty) return [];
    
    // Return the geohash and its neighbors for expanded proximity search
    // This is a simplified implementation - in production you might want
    // to use a more sophisticated geohash neighbor algorithm
    final neighbors = <String>[geohash];
    
    // Add shorter geohashes for broader search
    for (int i = geohash.length - 1; i >= math.max(4, geohash.length - 2); i--) {
      neighbors.add(geohash.substring(0, i));
    }
    
    return neighbors;
  }
}