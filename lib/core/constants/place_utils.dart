import '../../features/shared/services/location/places_service.dart';

/// Utility class for handling place-related operations
class PlaceUtils {
  /// Extracts a clean city name from Google Places PlaceDetails
  static String extractCityFromPlace(PlaceDetails placeDetails) {
    // First try to extract city from the formatted address
    final addressParts = placeDetails.formattedAddress.split(', ');
    
    // For US addresses, the format is usually:
    // "Street Address, City, State ZIP" or "City, State" or "Neighborhood, City, State"
    if (addressParts.length >= 2) {
      // Look for the part that contains the city (before state)
      for (int i = 0; i < addressParts.length - 1; i++) {
        final part = addressParts[i].trim();
        // Skip if it looks like a street address (contains numbers at start)
        if (!RegExp(r'^\d').hasMatch(part)) {
          // Check if next part looks like a state (2 letters) or state + ZIP
          final nextPart = addressParts[i + 1].trim();
          if (RegExp(r'^[A-Z]{2}(\s+\d{5})?$').hasMatch(nextPart) || 
              RegExp(r'^(Georgia|Alabama|Florida|South Carolina|North Carolina|Tennessee)').hasMatch(nextPart)) {
            return _cleanCityName(part);
          }
        }
      }
    }
    
    // Try using the place name if it looks like a city
    String name = placeDetails.name;
    
    // If name is the same as formatted address, try to extract the first meaningful part
    if (name == placeDetails.formattedAddress && addressParts.isNotEmpty) {
      // Use the first part if it doesn't start with a number
      final firstPart = addressParts[0].trim();
      if (!RegExp(r'^\d').hasMatch(firstPart)) {
        name = firstPart;
      }
    }
    
    return _cleanCityName(name);
  }
  
  /// Cleans a city name by removing common suffixes
  static String _cleanCityName(String cityName) {
    // Remove common suffixes that aren't part of the city name
    String cleaned = cityName
        .replaceAll(RegExp(r',\s*(GA|Georgia|AL|Alabama|FL|Florida|SC|South Carolina|NC|North Carolina|TN|Tennessee)\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r',\s*USA\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+(County|Metro|Metropolitan|Area)\s*$', caseSensitive: false), '')
        .trim();
        
    return cleaned;
  }
}