import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:atv_events/features/shared/services/location/location_data_service.dart';

/// Service to migrate existing posts and markets to use optimized LocationData
class LocationDataMigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Migrate vendor posts to include locationData field
  static Future<int> migrateVendorPosts({int batchSize = 100}) async {
    int migratedCount = 0;
    
    try {
      
      // Query posts without locationData field
      final postsQuery = await _firestore
          .collection('vendor_posts')
          .where('isActive', isEqualTo: true)
          .limit(batchSize)
          .get();
      
      final batch = _firestore.batch();
      
      for (final doc in postsQuery.docs) {
        final data = doc.data();
        
        // Skip if already has locationData
        if (data.containsKey('locationData') && data['locationData'] != null) {
          continue;
        }
        
        // Extract location information
        final location = data['location'] as String? ?? '';
        final latitude = data['latitude']?.toDouble();
        final longitude = data['longitude']?.toDouble();
        final placeId = data['placeId'] as String?;
        final locationName = data['locationName'] as String?;
        
        if (location.isNotEmpty) {
          // Create optimized location data
          final locationData = LocationDataService.createLocationData(
            locationString: location,
            latitude: latitude,
            longitude: longitude,
            placeId: placeId,
            locationName: locationName,
          );
          
          // Update the document
          batch.update(doc.reference, {
            'locationData': locationData.toFirestore(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          migratedCount++;
        }
      }
      
      if (migratedCount > 0) {
        await batch.commit();
      }
      
      return migratedCount;
    } catch (e) {
      rethrow;
    }
  }

  /// Migrate markets to include locationData field
  static Future<int> migrateMarkets({int batchSize = 100}) async {
    int migratedCount = 0;
    
    try {
      
      // Query markets without locationData field
      final marketsQuery = await _firestore
          .collection('markets')
          .where('isActive', isEqualTo: true)
          .limit(batchSize)
          .get();
      
      final batch = _firestore.batch();
      
      for (final doc in marketsQuery.docs) {
        final data = doc.data();
        
        // Skip if already has locationData
        if (data.containsKey('locationData') && data['locationData'] != null) {
          continue;
        }
        
        // Extract location information
        final address = data['address'] as String? ?? '';
        final city = data['city'] as String? ?? '';
        final state = data['state'] as String? ?? '';
        final latitude = data['latitude']?.toDouble();
        final longitude = data['longitude']?.toDouble();
        final placeId = data['placeId'] as String?;
        
        // Build full address string
        final fullAddress = [address, city, state]
            .where((part) => part.isNotEmpty)
            .join(', ');
        
        if (fullAddress.isNotEmpty) {
          // Create optimized location data
          final locationData = LocationDataService.createLocationData(
            locationString: fullAddress,
            latitude: latitude,
            longitude: longitude,
            placeId: placeId,
            locationName: data['name'] as String?,
          );
          
          // Update the document
          batch.update(doc.reference, {
            'locationData': locationData.toFirestore(),
          });
          
          migratedCount++;
        }
      }
      
      if (migratedCount > 0) {
        await batch.commit();
      }
      
      return migratedCount;
    } catch (e) {
      rethrow;
    }
  }

  /// Migrate events to include locationData field
  static Future<int> migrateEvents({int batchSize = 100}) async {
    int migratedCount = 0;
    
    try {
      
      // Query events without locationData field
      final eventsQuery = await _firestore
          .collection('events')
          .where('isActive', isEqualTo: true)
          .limit(batchSize)
          .get();
      
      final batch = _firestore.batch();
      
      for (final doc in eventsQuery.docs) {
        final data = doc.data();
        
        // Skip if already has locationData
        if (data.containsKey('locationData') && data['locationData'] != null) {
          continue;
        }
        
        // Extract location information
        final location = data['location'] as String? ?? '';
        final latitude = data['latitude']?.toDouble();
        final longitude = data['longitude']?.toDouble();
        final placeId = data['placeId'] as String?;
        
        if (location.isNotEmpty) {
          // Create optimized location data
          final locationData = LocationDataService.createLocationData(
            locationString: location,
            latitude: latitude,
            longitude: longitude,
            placeId: placeId,
            locationName: data['name'] as String?,
          );
          
          // Update the document
          batch.update(doc.reference, {
            'locationData': locationData.toFirestore(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          migratedCount++;
        }
      }
      
      if (migratedCount > 0) {
        await batch.commit();
      }
      
      return migratedCount;
    } catch (e) {
      rethrow;
    }
  }

  /// Run full migration for all content types
  static Future<Map<String, int>> runFullMigration() async {
    final results = <String, int>{};
    
    try {
      
      // Migrate vendor posts
      results['vendor_posts'] = await migrateVendorPosts();
      
      // Migrate markets
      results['markets'] = await migrateMarkets();
      
      // Migrate events
      results['events'] = await migrateEvents();
      
      final totalMigrated = results.values.fold(0, (accumulator, itemCount) => accumulator + itemCount);
      
      return results;
    } catch (e) {
      rethrow;
    }
  }

  /// Check how many documents need migration
  static Future<Map<String, int>> checkMigrationNeeded() async {
    final counts = <String, int>{};
    
    try {
      // Check vendor posts
      final postsQuery = await _firestore
          .collection('vendor_posts')
          .where('isActive', isEqualTo: true)
          .get();
      
      counts['vendor_posts'] = postsQuery.docs
          .where((doc) => 
              !doc.data().containsKey('locationData') || 
              doc.data()['locationData'] == null)
          .length;
      
      // Check markets
      final marketsQuery = await _firestore
          .collection('markets')
          .where('isActive', isEqualTo: true)
          .get();
      
      counts['markets'] = marketsQuery.docs
          .where((doc) => 
              !doc.data().containsKey('locationData') || 
              doc.data()['locationData'] == null)
          .length;
      
      // Check events
      final eventsQuery = await _firestore
          .collection('events')
          .where('isActive', isEqualTo: true)
          .get();
      
      counts['events'] = eventsQuery.docs
          .where((doc) => 
              !doc.data().containsKey('locationData') || 
              doc.data()['locationData'] == null)
          .length;
      
      final totalNeeded = counts.values.fold(0, (accumulator, itemCount) => accumulator + itemCount);
      
      return counts;
    } catch (e) {
      rethrow;
    }
  }
}