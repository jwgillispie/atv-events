import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Optimized location data structure for fast searching and indexing
/// This model breaks down addresses into searchable components and includes
/// computed fields for efficient queries.
class LocationData extends Equatable {
  // Parsed address components
  final String? streetNumber;
  final String? streetName;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? neighborhood;
  final String? metroArea;
  
  // Geographic data
  final GeoPoint? coordinates;
  final String? geohash; // For proximity searches
  
  // Search optimization
  final List<String> searchKeywords;
  
  // Display helpers
  final String? cityState; // "Atlanta, GA"
  final String? shortAddress; // "123 Main St, Atlanta"
  
  // Original data for backward compatibility
  final String originalLocationString;

  const LocationData({
    this.streetNumber,
    this.streetName,
    this.city,
    this.state,
    this.zipCode,
    this.neighborhood,
    this.metroArea,
    this.coordinates,
    this.geohash,
    this.searchKeywords = const [],
    this.cityState,
    this.shortAddress,
    required this.originalLocationString,
  });

  factory LocationData.fromFirestore(Map<String, dynamic> data) {
    try {
      return LocationData(
        streetNumber: data['streetNumber'],
        streetName: data['streetName'],
        city: data['city'],
        state: data['state'],
        zipCode: data['zipCode'],
        neighborhood: data['neighborhood'],
        metroArea: data['metroArea'],
        coordinates: data['coordinates'] as GeoPoint?,
        geohash: data['geohash'],
        searchKeywords: data['searchKeywords'] != null
            ? List<String>.from(data['searchKeywords'])
            : [],
        cityState: data['cityState'],
        shortAddress: data['shortAddress'],
        originalLocationString: data['originalLocationString'] ?? '',
      );
    } catch (e) {
      // If parsing fails, return minimal data with original location
      return LocationData(
        originalLocationString: data['originalLocationString'] ?? '',
        searchKeywords: data['searchKeywords'] != null
            ? List<String>.from(data['searchKeywords'])
            : [],
      );
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'streetNumber': streetNumber,
      'streetName': streetName,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'neighborhood': neighborhood,
      'metroArea': metroArea,
      'coordinates': coordinates,
      'geohash': geohash,
      'searchKeywords': searchKeywords,
      'cityState': cityState,
      'shortAddress': shortAddress,
      'originalLocationString': originalLocationString,
    };
  }

  LocationData copyWith({
    String? streetNumber,
    String? streetName,
    String? city,
    String? state,
    String? zipCode,
    String? neighborhood,
    String? metroArea,
    GeoPoint? coordinates,
    String? geohash,
    List<String>? searchKeywords,
    String? cityState,
    String? shortAddress,
    String? originalLocationString,
  }) {
    return LocationData(
      streetNumber: streetNumber ?? this.streetNumber,
      streetName: streetName ?? this.streetName,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      neighborhood: neighborhood ?? this.neighborhood,
      metroArea: metroArea ?? this.metroArea,
      coordinates: coordinates ?? this.coordinates,
      geohash: geohash ?? this.geohash,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      cityState: cityState ?? this.cityState,
      shortAddress: shortAddress ?? this.shortAddress,
      originalLocationString: originalLocationString ?? this.originalLocationString,
    );
  }

  // Convenience getters
  String get displayCity => city ?? 'Unknown City';
  String get displayState => state ?? '';
  String get displayCityState => cityState ?? (city != null && state != null ? '$city, $state' : originalLocationString);
  String get displayShortAddress => shortAddress ?? originalLocationString;
  
  bool get hasCoordinates => coordinates != null;
  bool get hasDetailedAddress => streetNumber != null && streetName != null;
  bool get hasGeohash => geohash != null && geohash!.isNotEmpty;
  
  // Search helpers
  bool matchesCity(String searchCity) {
    if (city == null) return false;
    final normalizedSearch = searchCity.toLowerCase().trim();
    final normalizedCity = city!.toLowerCase().trim();
    
    // Exact match
    if (normalizedCity == normalizedSearch) return true;
    
    // Check search keywords for city matches
    return searchKeywords.any((keyword) => 
        keyword.toLowerCase().contains(normalizedSearch) ||
        normalizedSearch.contains(keyword.toLowerCase()));
  }
  
  bool matchesMetroArea(String searchArea) {
    if (metroArea == null) return false;
    final normalizedSearch = searchArea.toLowerCase().trim();
    final normalizedMetro = metroArea!.toLowerCase().trim();
    
    return normalizedMetro.contains(normalizedSearch) ||
           normalizedSearch.contains(normalizedMetro);
  }

  @override
  List<Object?> get props => [
        streetNumber,
        streetName,
        city,
        state,
        zipCode,
        neighborhood,
        metroArea,
        coordinates,
        geohash,
        searchKeywords,
        cityState,
        shortAddress,
        originalLocationString,
      ];
}