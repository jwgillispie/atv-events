import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../models/event_ticket.dart';
import '../models/ticket_purchase.dart';
import '../../shared/models/event.dart';
import '../../premium/services/stripe_service.dart';
import '../../premium/services/payment_service.dart';
import '../../../core/utils/url_helper.dart';
import '../../../utils/firestore_error_logger.dart';
import '../../../core/constants/payment_constants.dart';
import 'dart:math';
import 'ticket_service.dart';

/// Service for handling event ticket purchases using Stripe
class TicketPurchaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static const String _cacheKeyPrefix = 'cached_tickets_';
  static const Duration _cacheExpiry = Duration(hours: 24); // Cache for 24 hours

  /// Create checkout session for ticket purchase
  static Future<String> createTicketCheckoutSession({
    required Event event,
    required EventTicket ticket,
    required int quantity,
    required String customerEmail,
    required String userId,
    required String userName,
  }) async {
    try {
      // Validate ticket availability
      if (!ticket.isAvailable) {
        throw Exception('Tickets are no longer available');
      }

      if (ticket.remainingQuantity < quantity) {
        throw Exception('Only ${ticket.remainingQuantity} tickets remaining');
      }

      if (quantity > ticket.maxPerPurchase) {
        throw Exception('Maximum ${ticket.maxPerPurchase} tickets per purchase');
      }

      // Calculate pricing
      final subtotal = ticket.price * quantity;
      final platformFee = PaymentConstants.calculateTicketPlatformFee(subtotal);
      final totalAmount = subtotal + platformFee;

      // Generate unique QR code for this purchase
      final qrCode = _generateQRCode(userId, event.id, ticket.id);

      // Prepare metadata for Stripe
      final metadata = {
        'type': 'ticket_purchase',
        'event_id': event.id,
        'event_name': event.name,
        'ticket_id': ticket.id,
        'ticket_name': ticket.name,
        'quantity': quantity.toString(),
        'user_id': userId,
        'user_email': customerEmail,
        'user_name': userName,
        'qr_code': qrCode,
        'platform_fee': platformFee.toStringAsFixed(2),
        'subtotal': subtotal.toStringAsFixed(2),
      };

      // Create Stripe checkout session URLs
      final (successUrl, cancelUrl) = UrlHelper.getCheckoutUrls(
        'tickets',
        {
          'purchase_id': '{CHECKOUT_SESSION_ID}',
          'qr': qrCode,
        },
      );

      // Call Cloud Function to create checkout session
      final callable = _functions.httpsCallable('createTicketCheckoutSession');
      final result = await callable.call({
        'eventId': event.id,
        'eventName': event.name,
        'ticketId': ticket.id,
        'ticketName': ticket.name,
        'quantity': quantity,
        'unitPrice': ticket.price,
        'subtotal': subtotal,
        'platformFee': platformFee,
        'totalAmount': totalAmount,
        'customerEmail': customerEmail,
        'userId': userId,
        'userName': userName,
        'qrCode': qrCode,
        'metadata': metadata,
        'successUrl': successUrl,
        'cancelUrl': cancelUrl,
        'environment': dotenv.env['ENVIRONMENT'] ?? 'staging',
      });

      final checkoutUrl = result.data['url'] as String?;
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('Failed to create checkout session');
      }

      return checkoutUrl;
    } catch (e) {
      throw Exception('Failed to create ticket purchase: ${e.toString()}');
    }
  }

  /// Launch ticket checkout
  static Future<void> launchTicketCheckout({
    required Event event,
    required EventTicket ticket,
    required int quantity,
    required String customerEmail,
    required String userId,
    required String userName,
    BuildContext? context,
  }) async {
    try {
      // Check if ticket is free - claim directly without Stripe
      if (ticket.price == 0.0) {
        await _claimFreeAdvancedTicket(
          event: event,
          ticket: ticket,
          quantity: quantity,
          customerEmail: customerEmail,
          userId: userId,
          userName: userName,
          context: context,
        );
        return;
      }

      // Paid tickets - use Payment Sheet on mobile, Checkout on web
      if (kIsWeb) {
        // Web: Use Stripe Checkout redirect
        final checkoutUrl = await createTicketCheckoutSession(
          event: event,
          ticket: ticket,
          quantity: quantity,
          customerEmail: customerEmail,
          userId: userId,
          userName: userName,
        );

        // Launch checkout URL
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
          );
        } else {
          throw Exception('Could not launch checkout');
        }
      } else {
        // Mobile: Use Payment Sheet for in-app payment
        await _purchaseTicketWithPaymentSheet(
          event: event,
          ticket: ticket,
          quantity: quantity,
          customerEmail: customerEmail,
          userId: userId,
          userName: userName,
          context: context,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Purchase ticket with Payment Sheet (Mobile only)
  static Future<void> _purchaseTicketWithPaymentSheet({
    required Event event,
    required EventTicket ticket,
    required int quantity,
    required String customerEmail,
    required String userId,
    required String userName,
    BuildContext? context,
  }) async {
    try {
      // Calculate pricing
      final subtotal = ticket.price * quantity;
      final platformFee = PaymentConstants.calculateTicketPlatformFee(subtotal);
      final totalAmount = subtotal + platformFee;

      // Validate ticket availability
      if (!ticket.isAvailable) {
        throw Exception('Tickets are no longer available');
      }

      if (ticket.remainingQuantity < quantity) {
        throw Exception('Only ${ticket.remainingQuantity} tickets remaining');
      }

      if (quantity > ticket.maxPerPurchase) {
        throw Exception('Maximum ${ticket.maxPerPurchase} tickets per purchase');
      }

      // Initialize Stripe
      await PaymentService.initialize();

      // Create ticket payment configuration
      final config = TicketPaymentConfig(
        eventId: event.id,
        eventName: event.name,
        organizerId: event.organizerId ?? '',
        organizerName: event.organizerName ?? 'Event Organizer',
        quantity: quantity,
        pricePerTicket: ticket.price,
        subtotal: subtotal,
        platformFee: platformFee,
        total: totalAmount,
        eventDate: event.startDateTime ?? DateTime.now(),
        ticketType: ticket.name,
      );

      // Process payment with Payment Sheet
      await PaymentService.processTicketPaymentWithSheet(
        config: config,
        customerEmail: customerEmail,
        userId: userId,
      );

      // Payment successful - navigate to My Tickets and show success
      if (context != null && context.mounted) {
        context.go('/shopper/my-tickets');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully purchased ${quantity > 1 ? '$quantity tickets' : 'ticket'}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on PaymentException catch (e) {
      // Handle payment-specific errors
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      rethrow;
    } catch (e) {
      // Handle general errors
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to purchase ticket: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      rethrow;
    }
  }

  /// Claim a free advanced ticket (without Stripe checkout)
  static Future<String> _claimFreeAdvancedTicket({
    required Event event,
    required EventTicket ticket,
    required int quantity,
    required String customerEmail,
    required String userId,
    required String userName,
    BuildContext? context,
  }) async {
    try {
      final now = DateTime.now();

      // Validate ticket availability
      if (!ticket.isAvailable) {
        throw Exception('Tickets are no longer available');
      }

      if (ticket.remainingQuantity < quantity) {
        throw Exception('Only ${ticket.remainingQuantity} tickets remaining');
      }

      if (quantity > ticket.maxPerPurchase) {
        throw Exception('Maximum ${ticket.maxPerPurchase} tickets per purchase');
      }

      // Generate unique QR code for this purchase
      final qrCode = _generateQRCode(userId, event.id, ticket.id);

      // Create ticket purchase document in Firestore
      final ticketPurchaseData = {
        'eventId': event.id,
        'eventName': event.name,
        'ticketId': ticket.id,
        'ticketName': ticket.name,
        'userId': userId,
        'userEmail': customerEmail,
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
        'eventStartDate': event.startDateTime != null ? Timestamp.fromDate(event.startDateTime) : null,
        'eventEndDate': event.endDateTime != null ? Timestamp.fromDate(event.endDateTime) : null,
        'eventLocation': event.location,
        'eventAddress': event.address,
        'eventImageUrl': event.imageUrl,
      };

      final ticketPurchaseRef = await _firestore
          .collection('ticketPurchases')
          .add(ticketPurchaseData);

      // Update ticket sold quantity using TicketService
      await TicketService.updateTicketSoldQuantity(
        eventId: event.id,
        ticketId: ticket.id,
        quantitySold: quantity,
      );

      // Navigate to My Tickets and show success message if context provided
      if (context != null && context.mounted) {
        context.go('/shopper/my-tickets');

        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully claimed ${quantity > 1 ? '$quantity free tickets' : 'free ticket'}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return ticketPurchaseRef.id;
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to claim ticket: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      throw Exception('Failed to claim free ticket: ${e.toString()}');
    }
  }

  /// Get tickets for an event
  static Stream<List<EventTicket>> getEventTickets(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('tickets')
        .where('isActive', isEqualTo: true)
        .orderBy('price')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EventTicket.fromFirestore(doc))
            .toList());
  }

  /// Get user's purchased tickets with caching support
  static Stream<List<TicketPurchase>> getUserTickets(String userId) async* {
    // First, yield cached data if available
    final cachedTickets = await getCachedTickets(userId);
    if (cachedTickets.isNotEmpty) {
      yield cachedTickets;
    }

    // Then yield real-time data from Firestore with error logging
    yield* _firestore
        .collection('ticketPurchases')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: TicketPurchaseStatus.completed.value)
        .orderBy('purchasedAt', descending: true)
        .snapshots()
        .handleError((error) {
          FirestoreErrorLogger.logError(
            error,
            'TicketPurchaseService.getUserTickets(userId: $userId)'
          );
        })
        .map((snapshot) {
          final tickets = snapshot.docs
              .map((doc) => TicketPurchase.fromFirestore(doc))
              .toList();
          // Cache the tickets for offline access
          _cacheTickets(userId, tickets);
          return tickets;
        });
  }

  /// Get user's upcoming event tickets with caching support
  static Stream<List<TicketPurchase>> getUserUpcomingTickets(String userId) async* {
    final now = DateTime.now();

    // First, yield cached upcoming tickets if available
    final cachedTickets = await getCachedTickets(userId);
    final upcomingCached = cachedTickets.where((ticket) {
      return ticket.status == TicketPurchaseStatus.completed &&
             ticket.eventEndDate != null &&
             ticket.eventEndDate!.isAfter(now);
    }).toList();

    if (upcomingCached.isNotEmpty) {
      yield upcomingCached;
    }

    // Then yield real-time data from Firestore with error logging
    yield* _firestore
        .collection('ticketPurchases')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: TicketPurchaseStatus.completed.value)
        .where('eventEndDate', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('eventEndDate')
        .snapshots()
        .handleError((error) {
          FirestoreErrorLogger.logError(
            error,
            'TicketPurchaseService.getUserUpcomingTickets(userId: $userId)'
          );
        })
        .map((snapshot) {
          final tickets = snapshot.docs
              .map((doc) => TicketPurchase.fromFirestore(doc))
              .toList();
          // Sort by event start date for proper display order
          tickets.sort((a, b) {
            final aStart = a.eventStartDate ?? a.eventEndDate;
            final bStart = b.eventStartDate ?? b.eventEndDate;
            if (aStart == null || bStart == null) return 0;
            return aStart.compareTo(bStart);
          });
          // Update cache with latest data
          _cacheTickets(userId, tickets, isUpcoming: true);
          return tickets;
        });
  }

  /// Get ticket purchase by ID
  static Future<TicketPurchase?> getTicketPurchase(String purchaseId) async {
    try {
      final doc = await _firestore
          .collection('ticketPurchases')
          .doc(purchaseId)
          .get();

      if (doc.exists) {
        return TicketPurchase.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get ticket purchase by QR code
  static Future<TicketPurchase?> getTicketByQRCode(String qrCode) async {
    try {
      final snapshot = await _firestore
          .collection('ticketPurchases')
          .where('qrCode', isEqualTo: qrCode)
          .where('status', isEqualTo: TicketPurchaseStatus.completed.value)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return TicketPurchase.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Validate ticket (mark as used)
  static Future<bool> validateTicket({
    required String qrCode,
    required String validatedBy,
  }) async {
    try {
      final callable = _functions.httpsCallable('validateTicket');
      final result = await callable.call({
        'qrCode': qrCode,
        'validatedBy': validatedBy,
        'validatedAt': DateTime.now().toIso8601String(),
      });

      return result.data['success'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get event ticket sales summary
  static Future<Map<String, dynamic>> getEventTicketSummary(String eventId) async {
    try {
      final callable = _functions.httpsCallable('getEventTicketSummary');
      final result = await callable.call({
        'eventId': eventId,
      });

      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      return {
        'totalSold': 0,
        'totalRevenue': 0.0,
        'platformFees': 0.0,
        'ticketTypes': [],
      };
    }
  }

  /// Cancel ticket purchase (admin only)
  static Future<bool> cancelTicketPurchase({
    required String purchaseId,
    required String reason,
  }) async {
    try {
      final callable = _functions.httpsCallable('cancelTicketPurchase');
      final result = await callable.call({
        'purchaseId': purchaseId,
        'reason': reason,
        'cancelledAt': DateTime.now().toIso8601String(),
      });

      return result.data['success'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Generate unique QR code for ticket
  static String _generateQRCode(String userId, String eventId, String ticketId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'HIP-$eventId-$ticketId-$timestamp-$random';
  }

  /// Check if user has already purchased tickets for an event
  static Future<bool> hasUserPurchasedTickets(String userId, String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('ticketPurchases')
          .where('userId', isEqualTo: userId)
          .where('eventId', isEqualTo: eventId)
          .where('status', isEqualTo: TicketPurchaseStatus.completed.value)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get total tickets purchased by user for an event
  static Future<int> getUserTicketCountForEvent(String userId, String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('ticketPurchases')
          .where('userId', isEqualTo: userId)
          .where('eventId', isEqualTo: eventId)
          .where('status', isEqualTo: TicketPurchaseStatus.completed.value)
          .get();

      int totalQuantity = 0;
      for (final doc in snapshot.docs) {
        final purchase = TicketPurchase.fromFirestore(doc);
        totalQuantity += purchase.quantity;
      }

      return totalQuantity;
    } catch (e) {
      return 0;
    }
  }

  // ============= Caching Methods =============

  /// Cache tickets to local storage
  static Future<void> _cacheTickets(
    String userId,
    List<TicketPurchase> tickets, {
    bool isUpcoming = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = isUpcoming
          ? '${_cacheKeyPrefix}upcoming_$userId'
          : '$_cacheKeyPrefix$userId';

      // Convert tickets to JSON
      final ticketsJson = tickets.map((ticket) => {
        'id': ticket.id,
        'eventId': ticket.eventId,
        'eventName': ticket.eventName,
        'ticketId': ticket.ticketId,
        'ticketName': ticket.ticketName,
        'userId': ticket.userId,
        'userEmail': ticket.userEmail,
        'userName': ticket.userName,
        'quantity': ticket.quantity,
        'unitPrice': ticket.unitPrice,
        'subtotal': ticket.subtotal,
        'platformFee': ticket.platformFee,
        'totalAmount': ticket.totalAmount,
        'stripeSessionId': ticket.stripeSessionId,
        'stripePaymentIntentId': ticket.stripePaymentIntentId,
        'qrCode': ticket.qrCode,
        'status': ticket.status.value,
        'usedAt': ticket.usedAt?.toIso8601String(),
        'usedBy': ticket.usedBy,
        'metadata': ticket.metadata,
        'purchasedAt': ticket.purchasedAt.toIso8601String(),
        'updatedAt': ticket.updatedAt.toIso8601String(),
        'eventStartDate': ticket.eventStartDate?.toIso8601String(),
        'eventEndDate': ticket.eventEndDate?.toIso8601String(),
        'eventLocation': ticket.eventLocation,
        'eventAddress': ticket.eventAddress,
        'eventImageUrl': ticket.eventImageUrl,
      }).toList();

      // Store with timestamp
      final cacheData = {
        'timestamp': DateTime.now().toIso8601String(),
        'tickets': ticketsJson,
      };

      await prefs.setString(key, jsonEncode(cacheData));
    } catch (e) {
      // Silently fail - caching is not critical
      debugPrint('Failed to cache tickets: $e');
    }
  }

  /// Get cached tickets from local storage
  static Future<List<TicketPurchase>> getCachedTickets(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cacheKeyPrefix$userId';
      final cacheString = prefs.getString(key);

      if (cacheString == null) {
        return [];
      }

      final cacheData = jsonDecode(cacheString) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cacheData['timestamp'] as String);

      // Check if cache is expired
      if (DateTime.now().difference(timestamp) > _cacheExpiry) {
        // Cache expired, but still return it as fallback
        debugPrint('Ticket cache expired but returning as fallback');
      }

      final ticketsJson = cacheData['tickets'] as List<dynamic>;
      return ticketsJson
          .map((json) => TicketPurchase.fromMap(
                json as Map<String, dynamic>,
                json['id'] as String,
              ))
          .toList();
    } catch (e) {
      debugPrint('Failed to get cached tickets: $e');
      return [];
    }
  }

  /// Clear cached tickets for a user
  static Future<void> clearCachedTickets(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cacheKeyPrefix$userId');
      await prefs.remove('${_cacheKeyPrefix}upcoming_$userId');
    } catch (e) {
      debugPrint('Failed to clear cached tickets: $e');
    }
  }

  /// Get upcoming ticket count from cache for quick display
  static Future<int> getCachedUpcomingTicketCount(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_cacheKeyPrefix}upcoming_$userId';
      final cacheString = prefs.getString(key);

      if (cacheString == null) {
        return 0;
      }

      final cacheData = jsonDecode(cacheString) as Map<String, dynamic>;
      final ticketsJson = cacheData['tickets'] as List<dynamic>;

      // Count only valid upcoming tickets
      final now = DateTime.now();
      int count = 0;
      for (final json in ticketsJson) {
        final eventEndDate = json['eventEndDate'] as String?;
        if (eventEndDate != null) {
          final endDate = DateTime.parse(eventEndDate);
          if (endDate.isAfter(now)) {
            count++;
          }
        }
      }
      return count;
    } catch (e) {
      debugPrint('Failed to get cached ticket count: $e');
      return 0;
    }
  }
}