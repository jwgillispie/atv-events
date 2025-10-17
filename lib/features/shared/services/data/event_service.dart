import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hipop/features/organizer/services/market_management/market_tracking_service.dart';
import 'package:hipop/features/shared/models/event.dart';
import 'package:hipop/features/shared/services/analytics/real_time_analytics_service.dart';


class EventService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'events';


  /// Get all active events
  static Stream<List<Event>> getAllActiveEventsStream() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('endDateTime', isGreaterThan: DateTime.now())
        .orderBy('endDateTime')
        .orderBy('startDateTime')
        .snapshots()
        .handleError((error) {
          developer.log('Error loading all active events: $error', name: 'EventService');
          if (kIsWeb) {
            // ignore: avoid_print
          }
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => Event.fromFirestore(doc))
            .toList());
  }

  /// Get events by city
  static Stream<List<Event>> getEventsByCityStream(String city) {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('city', isEqualTo: city)
        .where('endDateTime', isGreaterThan: DateTime.now())
        .orderBy('endDateTime')
        .orderBy('startDateTime')
        .snapshots()
        .handleError((error) {
          developer.log('Error loading events by city ($city): $error', name: 'EventService');
          if (kIsWeb) {
            // ignore: avoid_print
          }
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => Event.fromFirestore(doc))
            .toList());
  }

  /// Get events by location search
  static Stream<List<Event>> searchEventsByLocation(String location) {
    // For now, search by city - could be enhanced with more sophisticated search
    return getEventsByCityStream(location);
  }

  /// Get a specific event by ID
  static Future<Event?> getEvent(String eventId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(eventId).get();
      if (doc.exists) {
        return Event.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Error getting event: $e');
    }
  }

  /// Create a new event with limit enforcement
  static Future<String> createEvent(Event event) async {
    try {
      // Check if organizer can create event (enforce limits)
      if (event.organizerId != null) {
        final canCreate = await MarketTrackingService.canCreateEvent(
          event.organizerId!
        );
        
        if (!canCreate) {
          // Track analytics for limit encounter
          RealTimeAnalyticsService.trackEvent(
            'event_creation_limit_encountered',
            {
              'organizer_id': event.organizerId,
              'monthly_limit': MarketTrackingService.freeTierMonthlyLimit,
              'is_premium': false,
              'source': 'event_service',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          
          throw EventLimitException(
            'You have reached your monthly event creation limit. '
            'Upgrade to premium for unlimited events!'
          );
        }
      }
      
      // Create the event
      final docRef = await _firestore.collection(_collection).add(event.toFirestore());
      final eventId = docRef.id;
      
      // Track event creation in monthly tracking
      if (event.organizerId != null) {
        await MarketTrackingService.incrementEventCount(
          event.organizerId!,
          eventId: eventId,
        );
        
        // Track successful creation
        RealTimeAnalyticsService.trackEvent(
          'event_created_successfully',
          {
            'organizer_id': event.organizerId,
            'event_id': eventId,
            'source': 'event_service',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }
      
      return eventId;
    } catch (e) {
      if (e is EventLimitException) {
        rethrow;
      }
      throw Exception('Error creating event: $e');
    }
  }
  
  /// Check if an organizer can create more events
  static Future<bool> canOrganizerCreateEvent(String organizerId) async {
    try {
      return await MarketTrackingService.canCreateEvent(organizerId);
    } catch (e) {
      return false;
    }
  }
  
  /// Get event usage summary for an organizer
  static Future<Map<String, dynamic>> getEventUsageSummary(String organizerId) async {
    try {
      return await MarketTrackingService.getEventUsageSummary(organizerId);
    } catch (e) {
      return {
        'error': true,
        'message': e.toString(),
      };
    }
  }

  /// Update an existing event
  static Future<void> updateEvent(String eventId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
      await _firestore.collection(_collection).doc(eventId).update(updates);
    } catch (e) {
      throw Exception('Error updating event: $e');
    }
  }

  /// Delete an event
  static Future<void> deleteEvent(String eventId) async {
    try {
      // Get event details before deletion to update tracking
      final eventDoc = await _firestore.collection(_collection).doc(eventId).get();
      if (eventDoc.exists) {
        final eventData = eventDoc.data() as Map<String, dynamic>;
        final organizerId = eventData['organizerId'] as String?;
        
        // Delete the event
        await _firestore.collection(_collection).doc(eventId).delete();
        
        // Update tracking if organizer exists
        if (organizerId != null) {
          await MarketTrackingService.decrementEventCount(
            organizerId,
            eventId: eventId,
          );
        }
      } else {
        // Event doesn't exist, just try to delete anyway
        await _firestore.collection(_collection).doc(eventId).delete();
      }
    } catch (e) {
      throw Exception('Error deleting event: $e');
    }
  }

  /// Get current and upcoming events
  static Stream<List<Event>> getCurrentAndUpcomingEventsStream() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('endDateTime', isGreaterThan: DateTime.now())
        .orderBy('endDateTime')
        .orderBy('startDateTime')
        .snapshots()
        .handleError((error) {
          developer.log('Error loading current and upcoming events: $error', name: 'EventService');
          if (kIsWeb) {
            // ignore: avoid_print
          }
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => Event.fromFirestore(doc))
            .toList());
  }

  /// Get events for a specific market
  static Stream<List<Event>> getEventsForMarketStream(String marketId) {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('marketId', isEqualTo: marketId)
        .where('endDateTime', isGreaterThan: DateTime.now())
        .orderBy('endDateTime')
        .orderBy('startDateTime')
        .snapshots()
        .handleError((error) {
          developer.log('Error loading events for market ($marketId): $error', name: 'EventService');
          if (kIsWeb) {
            // ignore: avoid_print
          }
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => Event.fromFirestore(doc))
            .toList());
  }

  /// Get events organized by a specific organizer
  static Stream<List<Event>> getEventsByOrganizerStream(String organizerId) {
    return _firestore
        .collection(_collection)
        .where('organizerId', isEqualTo: organizerId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .handleError((error) {
          developer.log('Error loading events by organizer ($organizerId): $error', name: 'EventService');
          if (kIsWeb) {
            // ignore: avoid_print
          }
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => Event.fromFirestore(doc))
            .toList());
  }

  /// Filter events that are currently active or upcoming
  static List<Event> filterCurrentAndUpcomingEvents(List<Event> events) {
    final now = DateTime.now();
    return events.where((event) => event.endDateTime.isAfter(now)).toList();
  }

  /// Search events by name or description
  static Stream<List<Event>> searchEventsByText(String searchText) {
    if (searchText.isEmpty) {
      return getAllActiveEventsStream();
    }
    
    // Note: Firestore doesn't have full-text search, so this is a basic implementation
    // For production, consider using Algolia or similar search service
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('endDateTime', isGreaterThan: DateTime.now())
        .orderBy('endDateTime')
        .orderBy('startDateTime')
        .snapshots()
        .handleError((error) {
          developer.log('Error searching events by text ($searchText): $error', name: 'EventService');
          if (kIsWeb) {
            // ignore: avoid_print
          }
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => Event.fromFirestore(doc))
            .where((event) => 
                event.name.toLowerCase().contains(searchText.toLowerCase()) ||
                event.description.toLowerCase().contains(searchText.toLowerCase()) ||
                event.location.toLowerCase().contains(searchText.toLowerCase()))
            .toList());
  }
}

/// Exception thrown when event creation limit is reached
class EventLimitException implements Exception {
  final String message;
  EventLimitException(this.message);
  
  @override
  String toString() => message;
}