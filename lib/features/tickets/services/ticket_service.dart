import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_ticket.dart';

/// Service for managing event tickets
class TicketService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new ticket type for an event
  static Future<String> createEventTicket({
    required String eventId,
    required String name,
    required String description,
    required double price,
    required int totalQuantity,
    int maxPerPurchase = 10,
    DateTime? salesStartDate,
    DateTime? salesEndDate,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final now = DateTime.now();

      final ticketData = {
        'eventId': eventId,
        'name': name,
        'description': description,
        'price': price,
        'totalQuantity': totalQuantity,
        'soldQuantity': 0,
        'maxPerPurchase': maxPerPurchase,
        'salesStartDate': salesStartDate != null
            ? Timestamp.fromDate(salesStartDate)
            : null,
        'salesEndDate': salesEndDate != null
            ? Timestamp.fromDate(salesEndDate)
            : null,
        'isActive': true,
        'metadata': metadata,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final docRef = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('tickets')
          .add(ticketData);

      // Update event to indicate it has ticketing
      await _firestore
          .collection('events')
          .doc(eventId)
          .update({
        'hasTicketing': true,
        'updatedAt': Timestamp.fromDate(now),
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create ticket: ${e.toString()}');
    }
  }

  /// Update an existing ticket
  static Future<void> updateEventTicket({
    required String eventId,
    required String ticketId,
    String? name,
    String? description,
    double? price,
    int? totalQuantity,
    int? maxPerPurchase,
    DateTime? salesStartDate,
    DateTime? salesEndDate,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (price != null) updates['price'] = price;
      if (totalQuantity != null) updates['totalQuantity'] = totalQuantity;
      if (maxPerPurchase != null) updates['maxPerPurchase'] = maxPerPurchase;
      if (salesStartDate != null) {
        updates['salesStartDate'] = Timestamp.fromDate(salesStartDate);
      }
      if (salesEndDate != null) {
        updates['salesEndDate'] = Timestamp.fromDate(salesEndDate);
      }
      if (isActive != null) updates['isActive'] = isActive;
      if (metadata != null) updates['metadata'] = metadata;

      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('tickets')
          .doc(ticketId)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to update ticket: ${e.toString()}');
    }
  }

  /// Delete a ticket (soft delete - sets isActive to false)
  static Future<void> deleteEventTicket({
    required String eventId,
    required String ticketId,
  }) async {
    try {
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('tickets')
          .doc(ticketId)
          .update({
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Check if event still has active tickets
      final activeTickets = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('tickets')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (activeTickets.docs.isEmpty) {
        // No more active tickets, update event
        await _firestore
            .collection('events')
            .doc(eventId)
            .update({
          'hasTicketing': false,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      throw Exception('Failed to delete ticket: ${e.toString()}');
    }
  }

  /// Get all tickets for an event
  static Future<List<EventTicket>> getEventTickets(String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('tickets')
          .orderBy('price')
          .get();

      return snapshot.docs
          .map((doc) => EventTicket.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get active tickets for an event
  static Future<List<EventTicket>> getActiveEventTickets(String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('tickets')
          .where('isActive', isEqualTo: true)
          .orderBy('price')
          .get();

      return snapshot.docs
          .map((doc) => EventTicket.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get a specific ticket
  static Future<EventTicket?> getTicket({
    required String eventId,
    required String ticketId,
  }) async {
    try {
      final doc = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('tickets')
          .doc(ticketId)
          .get();

      if (doc.exists) {
        return EventTicket.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update ticket sold quantity (called after successful purchase)
  static Future<void> updateTicketSoldQuantity({
    required String eventId,
    required String ticketId,
    required int quantitySold,
  }) async {
    try {
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('tickets')
          .doc(ticketId)
          .update({
        'soldQuantity': FieldValue.increment(quantitySold),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update ticket quantity: ${e.toString()}');
    }
  }

  /// Check ticket availability
  static Future<bool> checkTicketAvailability({
    required String eventId,
    required String ticketId,
    required int requestedQuantity,
  }) async {
    try {
      final ticket = await getTicket(eventId: eventId, ticketId: ticketId);

      if (ticket == null) return false;
      if (!ticket.isActive) return false;
      if (!ticket.isAvailable) return false;
      if (ticket.remainingQuantity < requestedQuantity) return false;
      if (requestedQuantity > ticket.maxPerPurchase) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get ticket sales statistics for an event
  static Future<Map<String, dynamic>> getEventTicketStats(String eventId) async {
    try {
      final tickets = await getEventTickets(eventId);

      int totalTicketsAvailable = 0;
      int totalTicketsSold = 0;
      double totalRevenue = 0;
      double averageTicketPrice = 0;

      for (final ticket in tickets) {
        totalTicketsAvailable += ticket.totalQuantity;
        totalTicketsSold += ticket.soldQuantity;
        totalRevenue += ticket.soldQuantity * ticket.price;
      }

      if (tickets.isNotEmpty) {
        averageTicketPrice = tickets
            .map((t) => t.price)
            .reduce((a, b) => a + b) / tickets.length;
      }

      return {
        'totalTicketTypes': tickets.length,
        'totalTicketsAvailable': totalTicketsAvailable,
        'totalTicketsSold': totalTicketsSold,
        'totalRevenue': totalRevenue,
        'averageTicketPrice': averageTicketPrice,
        'sellThroughRate': totalTicketsAvailable > 0
            ? (totalTicketsSold / totalTicketsAvailable * 100)
            : 0,
      };
    } catch (e) {
      return {
        'totalTicketTypes': 0,
        'totalTicketsAvailable': 0,
        'totalTicketsSold': 0,
        'totalRevenue': 0.0,
        'averageTicketPrice': 0.0,
        'sellThroughRate': 0.0,
      };
    }
  }

  /// Batch create multiple ticket types for an event
  static Future<void> batchCreateEventTickets({
    required String eventId,
    required List<Map<String, dynamic>> ticketTypes,
  }) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();

      for (final ticketData in ticketTypes) {
        final docRef = _firestore
            .collection('events')
            .doc(eventId)
            .collection('tickets')
            .doc();

        batch.set(docRef, {
          'eventId': eventId,
          'name': ticketData['name'],
          'description': ticketData['description'],
          'price': ticketData['price'],
          'totalQuantity': ticketData['totalQuantity'],
          'soldQuantity': 0,
          'maxPerPurchase': ticketData['maxPerPurchase'] ?? 10,
          'salesStartDate': ticketData['salesStartDate'] != null
              ? Timestamp.fromDate(ticketData['salesStartDate'])
              : null,
          'salesEndDate': ticketData['salesEndDate'] != null
              ? Timestamp.fromDate(ticketData['salesEndDate'])
              : null,
          'isActive': true,
          'metadata': ticketData['metadata'],
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      // Update event to indicate it has ticketing
      final eventRef = _firestore.collection('events').doc(eventId);
      batch.update(eventRef, {
        'hasTicketing': true,
        'updatedAt': Timestamp.fromDate(now),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to create tickets: ${e.toString()}');
    }
  }

  /// Claim a free ticket for an event (simple ticketing)
  Future<String> claimFreeTicket({
    required String eventId,
    required String userId,
    required int quantity,
  }) async {
    try {
      final now = DateTime.now();

      // Get event details
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) {
        throw Exception('Event not found');
      }

      final eventData = eventDoc.data() as Map<String, dynamic>;
      final ticketPrice = (eventData['ticketPrice'] as num?)?.toDouble();

      if (ticketPrice == null || ticketPrice != 0) {
        throw Exception('This event does not have free tickets');
      }

      // Check capacity
      final maxAttendees = eventData['maxAttendees'] as int?;
      final totalTicketsSold = (eventData['totalTicketsSold'] as int?) ?? 0;

      if (maxAttendees != null && (totalTicketsSold + quantity) > maxAttendees) {
        throw Exception('Not enough tickets available');
      }

      // Get user details
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userEmail = userData?['email'] as String? ?? '';
      final userName = userData?['displayName'] as String? ?? 'Unknown User';

      // Generate QR code
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final qrCode = 'HIP-$eventId-FREE-$timestamp-$userId';

      // Create ticket purchase document with all required fields
      final ticketPurchaseData = {
        'eventId': eventId,
        'eventName': eventData['name'] ?? 'Unknown Event',
        'ticketId': 'free-ticket',
        'ticketName': 'Free Entry',
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'quantity': quantity,
        'unitPrice': 0.0,
        'subtotal': 0.0,
        'platformFee': 0.0,
        'totalAmount': 0.0,
        'qrCode': qrCode,
        'status': 'completed',
        'paymentMethod': 'free',
        'usedAt': null,
        'usedBy': null,
        'purchasedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        // Event details for display
        'eventStartDate': eventData['startDateTime'] as Timestamp?,
        'eventEndDate': eventData['endDateTime'] as Timestamp?,
        'eventLocation': eventData['location'] as String?,
        'eventAddress': eventData['address'] as String?,
        'eventImageUrl': eventData['imageUrl'] as String?,
      };

      final ticketPurchaseRef = await _firestore
          .collection('ticketPurchases')
          .add(ticketPurchaseData);

      // Update event ticket count using batch
      final batch = _firestore.batch();

      batch.update(_firestore.collection('events').doc(eventId), {
        'totalTicketsSold': FieldValue.increment(quantity),
        'totalRevenue': FieldValue.increment(0),
        'updatedAt': Timestamp.fromDate(now),
      });

      await batch.commit();

      return ticketPurchaseRef.id;
    } catch (e) {
      throw Exception('Failed to claim free ticket: ${e.toString()}');
    }
  }

  /// Create Stripe checkout session for paid tickets (simple ticketing)
  Future<String> createCheckoutSession({
    required String eventId,
    required String eventName,
    required double ticketPrice,
    required int quantity,
  }) async {
    try {
      // This would typically call your Firebase Cloud Function to create a Stripe checkout session
      // For now, returning a placeholder URL
      // You'll need to implement the actual Stripe integration
      throw UnimplementedError('Stripe checkout not yet implemented for simple ticketing');
    } catch (e) {
      throw Exception('Failed to create checkout session: ${e.toString()}');
    }
  }
}