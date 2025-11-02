import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Stripe from 'stripe';

// Initialize Firestore (admin should already be initialized in main index.ts)
const db = admin.firestore();

// Initialize Stripe with secret key from environment
const stripe = new Stripe(functions.config().stripe.secret_key, {
  apiVersion: '2024-04-10',
});

// ====== INTERFACES ======

interface CreateTicketCheckoutSessionData {
  eventId: string;
  eventName: string;
  ticketId: string;
  ticketName: string;
  quantity: number;
  unitPrice: number;
  subtotal: number;
  platformFee: number;
  totalAmount: number;
  customerEmail: string;
  userId: string;
  userName: string;
  qrCode: string;
  metadata: Record<string, string>;
  successUrl: string;
  cancelUrl: string;
  environment: string;
}

interface ValidateTicketData {
  qrCode: string;
  eventId?: string; // Optional to maintain backward compatibility
  validatedBy?: string; // Made optional since scanner might not have this info
  validatedAt?: string;
}

interface EventTicketSummaryData {
  eventId: string;
}

interface CancelTicketPurchaseData {
  purchaseId: string;
  reason: string;
  cancelledAt: string;
}

// ====== CLOUD FUNCTIONS ======

/**
 * Create Stripe checkout session for ticket purchase
 */
export const createTicketCheckoutSession = functions.https.onCall(
  async (data: CreateTicketCheckoutSessionData, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to purchase tickets'
      );
    }

    // Verify user is purchasing for themselves
    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Can only purchase tickets for authenticated user'
      );
    }

    try {
      functions.logger.info('🎫 Creating ticket checkout session', {
        userId: data.userId,
        eventId: data.eventId,
        ticketId: data.ticketId,
        quantity: data.quantity,
      });

      // Get event to find organizer
      const eventDoc = await db.collection('events').doc(data.eventId).get();

      if (!eventDoc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Event not found'
        );
      }

      const eventData = eventDoc.data()!;
      const organizerId = eventData.organizerId;

      if (!organizerId) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Event organizer not found'
        );
      }

      // Get organizer's Stripe Connect account
      const organizerIntegrationDoc = await db
        .collection('organizer_integrations')
        .doc(organizerId)
        .get();

      if (!organizerIntegrationDoc.exists) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Organizer has not set up payment processing. Please contact the event organizer.'
        );
      }

      const stripeAccountId = organizerIntegrationDoc.data()?.stripe?.accountId;
      if (!stripeAccountId) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Organizer payment processing not configured. Please contact the event organizer.'
        );
      }

      // Verify Stripe Connect account is active and can receive payments
      const account = await stripe.accounts.retrieve(stripeAccountId);
      if (!account.charges_enabled) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Organizer payment processing is not fully set up. Please contact the event organizer.'
        );
      }

      functions.logger.info('✅ Organizer Stripe Connect verified', {
        organizerId,
        stripeAccountId,
        chargesEnabled: account.charges_enabled,
      });

      // Verify ticket availability
      const ticketRef = db
        .collection('events')
        .doc(data.eventId)
        .collection('tickets')
        .doc(data.ticketId);

      const ticketDoc = await ticketRef.get();

      if (!ticketDoc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Ticket type not found'
        );
      }

      const ticketData = ticketDoc.data()!;
      const remainingQuantity = ticketData.totalQuantity - (ticketData.soldQuantity || 0);

      if (remainingQuantity < data.quantity) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          `Only ${remainingQuantity} tickets remaining`
        );
      }

      // Get or create Stripe customer
      let customer: Stripe.Customer;
      const existingCustomers = await stripe.customers.list({
        email: data.customerEmail,
        limit: 1,
      });

      if (existingCustomers.data.length > 0) {
        customer = existingCustomers.data[0];
      } else {
        customer = await stripe.customers.create({
          email: data.customerEmail,
          metadata: {
            userId: data.userId,
            userName: data.userName,
          },
        });
      }

      // Create line items for checkout - ONLY the ticket price (total includes platform fee)
      const lineItems: Stripe.Checkout.SessionCreateParams.LineItem[] = [
        {
          price_data: {
            currency: 'usd',
            product_data: {
              name: `${data.ticketName} - ${data.eventName}`,
              description: `${data.quantity} ticket(s) for ${data.eventName}`,
              metadata: {
                eventId: data.eventId,
                ticketId: data.ticketId,
              },
            },
            unit_amount: Math.round(data.totalAmount * 100), // Total amount in cents (includes platform fee)
          },
          quantity: 1, // Single line item for total
        },
      ];

      // Create checkout session with Stripe Connect
      const session = await stripe.checkout.sessions.create({
        payment_method_types: ['card'],
        line_items: lineItems,
        mode: 'payment',
        customer: customer.id,
        success_url: data.successUrl,
        cancel_url: data.cancelUrl,
        metadata: data.metadata,
        payment_intent_data: {
          application_fee_amount: Math.round(data.platformFee * 100), // Hipop's 6% fee in cents
          transfer_data: {
            destination: stripeAccountId, // Organizer's Stripe Connect account
          },
          metadata: {
            ...data.metadata,
            organizerId,
            stripeAccountId,
            organizerPayout: data.subtotal.toString(),
            platformFee: data.platformFee.toString(),
          },
        },
      });

      // Create pending ticket purchase record
      await db.collection('ticketPurchases').doc(session.id).set({
        eventId: data.eventId,
        eventName: data.eventName,
        ticketId: data.ticketId,
        ticketName: data.ticketName,
        userId: data.userId,
        userEmail: data.customerEmail,
        userName: data.userName,
        quantity: data.quantity,
        unitPrice: data.unitPrice,
        subtotal: data.subtotal,
        platformFee: data.platformFee,
        totalAmount: data.totalAmount,
        stripeSessionId: session.id,
        qrCode: data.qrCode,
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      functions.logger.info('✅ Ticket checkout session created', {
        sessionId: session.id,
        checkoutUrl: session.url,
      });

      return {
        url: session.url,
        sessionId: session.id,
      };
    } catch (error) {
      functions.logger.error('❌ Error creating ticket checkout session', error);

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        'internal',
        'Failed to create checkout session'
      );
    }
  }
);

/**
 * Validate and use a ticket (mark as used)
 */
export const validateTicket = functions.https.onCall(
  async (data: ValidateTicketData, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to validate tickets'
      );
    }

    try {
      functions.logger.info('🔍 Validating ticket', {
        qrCode: data.qrCode,
        eventId: data.eventId,
        validatedBy: data.validatedBy || context.auth.uid,
      });

      // Find ticket by QR code
      const ticketSnapshot = await db
        .collection('ticketPurchases')
        .where('qrCode', '==', data.qrCode)
        .where('status', '==', 'completed')
        .limit(1)
        .get();

      if (ticketSnapshot.empty) {
        throw new functions.https.HttpsError(
          'not-found',
          'Ticket not found or invalid'
        );
      }

      const ticketDoc = ticketSnapshot.docs[0];
      const ticketData = ticketDoc.data();

      // If eventId is provided, verify ticket belongs to this event
      if (data.eventId && ticketData.eventId !== data.eventId) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'This ticket is for a different event'
        );
      }

      // Check if ticket has already been used
      if (ticketData.usedAt) {
        throw new functions.https.HttpsError(
          'already-exists',
          `Ticket already used on ${new Date(ticketData.usedAt.toDate()).toLocaleString()}`
        );
      }

      // Check if event has passed
      if (ticketData.eventEndDate && ticketData.eventEndDate.toDate() < new Date()) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Event has already ended'
        );
      }

      // Mark ticket as used and update event attendance
      const batch = db.batch();

      // Update ticket document
      batch.update(ticketDoc.ref, {
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
        usedBy: data.validatedBy || context.auth.uid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update event attendance and revenue tracking
      const eventRef = db.collection('events').doc(ticketData.eventId);
      batch.update(eventRef, {
        totalAttendees: admin.firestore.FieldValue.increment(ticketData.quantity || 1),
        actualRevenue: admin.firestore.FieldValue.increment(ticketData.amount || 0),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await batch.commit();

      functions.logger.info('✅ Ticket validated successfully', {
        ticketId: ticketDoc.id,
        eventName: ticketData.eventName,
        quantity: ticketData.quantity,
        revenue: ticketData.amount,
      });

      return {
        success: true,
        message: 'Ticket validated successfully',
        userName: ticketData.userName,
        ticketType: ticketData.ticketName,
        quantity: ticketData.quantity,
        purchasedAt: ticketData.purchasedAt,
        ticketInfo: {
          eventName: ticketData.eventName,
          ticketName: ticketData.ticketName,
          userName: ticketData.userName,
          quantity: ticketData.quantity,
          userEmail: ticketData.userEmail,
        },
      };
    } catch (error) {
      functions.logger.error('❌ Error validating ticket', error);

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        'internal',
        'Failed to validate ticket'
      );
    }
  }
);

/**
 * Get event ticket sales summary
 */
export const getEventTicketSummary = functions.https.onCall(
  async (data: EventTicketSummaryData, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to view ticket summary'
      );
    }

    try {
      // Verify user is event organizer
      const eventDoc = await db.collection('events').doc(data.eventId).get();

      if (!eventDoc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Event not found'
        );
      }

      const eventData = eventDoc.data()!;

      if (eventData.organizerId !== context.auth.uid) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'Only event organizer can view ticket summary'
        );
      }

      // Get all ticket purchases for this event
      const purchasesSnapshot = await db
        .collection('ticketPurchases')
        .where('eventId', '==', data.eventId)
        .where('status', '==', 'completed')
        .get();

      let totalSold = 0;
      let totalRevenue = 0;
      let platformFees = 0;
      const ticketTypeSummary: Record<string, any> = {};

      purchasesSnapshot.docs.forEach((doc) => {
        const purchase = doc.data();
        totalSold += purchase.quantity;
        totalRevenue += purchase.totalAmount;
        platformFees += purchase.platformFee;

        // Aggregate by ticket type
        if (!ticketTypeSummary[purchase.ticketId]) {
          ticketTypeSummary[purchase.ticketId] = {
            name: purchase.ticketName,
            quantitySold: 0,
            revenue: 0,
          };
        }
        ticketTypeSummary[purchase.ticketId].quantitySold += purchase.quantity;
        ticketTypeSummary[purchase.ticketId].revenue += purchase.subtotal;
      });

      return {
        totalSold,
        totalRevenue,
        platformFees,
        netRevenue: totalRevenue - platformFees,
        ticketTypes: Object.values(ticketTypeSummary),
      };
    } catch (error) {
      functions.logger.error('❌ Error getting ticket summary', error);

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        'internal',
        'Failed to get ticket summary'
      );
    }
  }
);

/**
 * Cancel ticket purchase (admin/organizer only)
 */
export const cancelTicketPurchase = functions.https.onCall(
  async (data: CancelTicketPurchaseData, context) => {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to cancel tickets'
      );
    }

    try {
      // Get ticket purchase
      const purchaseDoc = await db
        .collection('ticketPurchases')
        .doc(data.purchaseId)
        .get();

      if (!purchaseDoc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Ticket purchase not found'
        );
      }

      const purchaseData = purchaseDoc.data()!;

      // Verify user is event organizer or ticket owner
      const eventDoc = await db.collection('events').doc(purchaseData.eventId).get();
      const eventData = eventDoc.data()!;

      if (context.auth.uid !== eventData.organizerId &&
          context.auth.uid !== purchaseData.userId) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'Only event organizer or ticket owner can cancel tickets'
        );
      }

      // Check if ticket has been used
      if (purchaseData.usedAt) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Cannot cancel used tickets'
        );
      }

      // Create refund in Stripe
      if (purchaseData.stripePaymentIntentId) {
        try {
          await stripe.refunds.create({
            payment_intent: purchaseData.stripePaymentIntentId,
            reason: 'requested_by_customer',
          });
        } catch (stripeError) {
          functions.logger.error('Stripe refund failed', stripeError);
          throw new functions.https.HttpsError(
            'internal',
            'Failed to process refund'
          );
        }
      }

      // Update ticket purchase status
      await purchaseDoc.ref.update({
        status: 'cancelled',
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelledBy: context.auth.uid,
        cancelReason: data.reason,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update ticket inventory (restore quantity)
      const ticketRef = db
        .collection('events')
        .doc(purchaseData.eventId)
        .collection('tickets')
        .doc(purchaseData.ticketId);

      await ticketRef.update({
        soldQuantity: admin.firestore.FieldValue.increment(-purchaseData.quantity),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update event totals
      await eventDoc.ref.update({
        totalTicketsSold: admin.firestore.FieldValue.increment(-purchaseData.quantity),
        totalRevenue: admin.firestore.FieldValue.increment(-purchaseData.totalAmount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      functions.logger.info('✅ Ticket purchase cancelled', {
        purchaseId: data.purchaseId,
        reason: data.reason,
      });

      return {
        success: true,
        message: 'Ticket purchase cancelled and refunded',
      };
    } catch (error) {
      functions.logger.error('❌ Error cancelling ticket purchase', error);

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        'internal',
        'Failed to cancel ticket purchase'
      );
    }
  }
);

/**
 * Webhook handler for ticket purchase completion
 * This should be called when a Stripe payment succeeds
 */
export const handleTicketPaymentSuccess = async (
  session: Stripe.Checkout.Session
) => {
  try {
    // Check if this is a ticket purchase
    if (session.metadata?.type !== 'ticket_purchase') {
      return;
    }

    functions.logger.info('🎫 Processing successful ticket purchase', {
      sessionId: session.id,
      eventId: session.metadata.event_id,
    });

    const batch = db.batch();

    // Update ticket purchase record
    const purchaseRef = db.collection('ticketPurchases').doc(session.id);
    batch.update(purchaseRef, {
      status: 'completed',
      stripePaymentIntentId: session.payment_intent,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Get purchase data to update event details
    const purchaseDoc = await purchaseRef.get();
    const purchaseData = purchaseDoc.data()!;

    // Add event details to purchase for display
    const eventDoc = await db.collection('events').doc(purchaseData.eventId).get();
    if (eventDoc.exists) {
      const eventData = eventDoc.data()!;
      batch.update(purchaseRef, {
        eventStartDate: eventData.startDateTime,
        eventEndDate: eventData.endDateTime,
        eventLocation: eventData.location,
        eventAddress: eventData.address,
        eventImageUrl: eventData.imageUrl,
      });
    }

    // Update ticket sold quantity
    const ticketRef = db
      .collection('events')
      .doc(session.metadata.event_id)
      .collection('tickets')
      .doc(session.metadata.ticket_id);

    batch.update(ticketRef, {
      soldQuantity: admin.firestore.FieldValue.increment(
        parseInt(session.metadata.quantity, 10)
      ),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update event totals
    const eventRef = db.collection('events').doc(session.metadata.event_id);
    batch.update(eventRef, {
      totalTicketsSold: admin.firestore.FieldValue.increment(
        parseInt(session.metadata.quantity, 10)
      ),
      totalRevenue: admin.firestore.FieldValue.increment(
        session.amount_total ? session.amount_total / 100 : 0
      ),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Commit all updates
    await batch.commit();

    // Send confirmation email (you can implement this separately)
    // await sendTicketConfirmationEmail(purchaseData);

    functions.logger.info('✅ Ticket purchase processed successfully', {
      sessionId: session.id,
      quantity: session.metadata.quantity,
    });
  } catch (error) {
    functions.logger.error('❌ Error processing ticket payment success', error);
    throw error;
  }
};