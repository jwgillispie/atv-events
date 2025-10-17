import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Stripe from 'stripe';

const stripe = new Stripe(functions.config().stripe.secret_key, {
  apiVersion: '2024-04-10',
});

/**
 * Stripe Connect Preorder Payment Processing
 * Handles payment intents with automatic vendor transfers
 */

interface PreorderItem {
  productId: string;
  productName: string;
  quantity: number;
  unitPrice: number;
  totalPrice: number;
}

interface CreatePreorderPaymentData {
  vendorId: string;
  items: PreorderItem[];
  totalAmount: number; // in dollars
  marketId?: string;
  marketName?: string;
}

/**
 * Create payment intent for preorder with vendor transfer
 * This charges the buyer and sets up automatic transfer to vendor
 */
export const createPreorderPaymentIntent = functions.https.onCall(
  async (data: CreatePreorderPaymentData, context): Promise<{
    clientSecret: string;
    paymentIntentId: string;
    orderId: string;
    platformFee: number;
    vendorPayout: number;
  }> => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const customerId = context.auth.uid;
    const { vendorId, items, totalAmount, marketId, marketName } = data;

    try {
      console.log(`💳 [Stripe Preorder] Creating payment for vendor ${vendorId}, amount: $${totalAmount}`);

      // Validate inputs
      if (!vendorId || !items || items.length === 0 || !totalAmount || totalAmount <= 0) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid payment data');
      }

      // Get vendor's Stripe Connect account
      const integrationDoc = await admin.firestore()
        .collection('vendor_integrations')
        .doc(vendorId)
        .get();

      const stripeAccountId = integrationDoc.data()?.stripe?.accountId;

      if (!stripeAccountId) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Vendor has not connected Stripe. Please ask vendor to connect their Stripe account in settings.'
        );
      }

      // Check if vendor is fully verified
      const chargesEnabled = integrationDoc.data()?.stripe?.chargesEnabled;
      if (!chargesEnabled) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Vendor Stripe account is not fully verified yet. Please try again later.'
        );
      }

      // Get vendor premium status (currently not used for fee differentiation)
      const vendorDoc = await admin.firestore().collection('users').doc(vendorId).get();
      const isPremium = vendorDoc.data()?.isPremium || false;

      // Calculate fees: totalAmount is the subtotal (product prices)
      // We add 6% platform fee on top, so shopper pays subtotal + 6%
      const platformFeePercent = 0.06;
      const subtotalCents = Math.round(totalAmount * 100); // This is products total
      const platformFeeCents = Math.round(subtotalCents * platformFeePercent); // 6% of subtotal
      const shopperTotalCents = subtotalCents + platformFeeCents; // What shopper actually pays
      const vendorPayoutCents = subtotalCents; // Vendor gets 100% of subtotal (we keep the fee)

      console.log(`💳 [Stripe Preorder] Subtotal: $${subtotalCents / 100}`);
      console.log(`💳 [Stripe Preorder] Platform fee (6%): $${platformFeeCents / 100}`);
      console.log(`💳 [Stripe Preorder] Shopper pays: $${shopperTotalCents / 100}`);
      console.log(`💳 [Stripe Preorder] Vendor gets: $${vendorPayoutCents / 100}`);

      // Create Payment Intent (charges buyer → platform account)
      const paymentIntent = await stripe.paymentIntents.create({
        amount: shopperTotalCents, // Charge shopper subtotal + 6% fee
        currency: 'usd',
        automatic_payment_methods: {
          enabled: true,
        },
        metadata: {
          vendorId,
          customerId,
          platform: 'hipop',
          orderType: 'preorder',
          platformFee: platformFeeCents.toString(),
          vendorPayout: vendorPayoutCents.toString(),
          isPremium: isPremium.toString(),
          marketId: marketId || 'none',
          marketName: marketName || 'none',
        },
      });

      // Create order in Firestore (transfer happens after payment succeeds in webhook)
      const orderRef = await admin.firestore().collection('preorders').add({
        vendorId,
        customerId,
        items,

        // Amounts
        subtotal: subtotalCents / 100, // Product prices total
        platformFee: platformFeeCents / 100, // 6% fee
        totalAmount: shopperTotalCents / 100, // What shopper pays (subtotal + fee)
        vendorPayout: vendorPayoutCents / 100, // What vendor receives (subtotal - Stripe's cut)
        platformFeePercent,

        // Stripe info
        stripeAccountId,
        paymentIntentId: paymentIntent.id,

        // Market info
        marketId: marketId || null,
        marketName: marketName || null,

        // Status
        status: 'pending_payment',
        isPremium,

        // Timestamps
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update payment intent metadata with orderId
      await stripe.paymentIntents.update(paymentIntent.id, {
        metadata: {
          ...paymentIntent.metadata,
          orderId: orderRef.id,
        },
      });

      console.log(`✅ [Stripe Preorder] Payment intent created: ${paymentIntent.id}`);
      console.log(`✅ [Stripe Preorder] Order created: ${orderRef.id}`);

      return {
        clientSecret: paymentIntent.client_secret!,
        paymentIntentId: paymentIntent.id,
        orderId: orderRef.id,
        platformFee: platformFeeCents / 100,
        vendorPayout: vendorPayoutCents / 100,
      };

    } catch (error: any) {
      console.error('❌ [Stripe Preorder] Error creating payment:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  }
);

/**
 * Get preorder payment status
 * Used by customer to check order status
 */
export const getPreorderPaymentStatus = functions.https.onCall(
  async (data: { orderId: string }, context): Promise<{
    status: string;
    paymentStatus?: string;
    transferStatus?: string;
  }> => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { orderId } = data;

    try {
      const orderDoc = await admin.firestore().collection('preorders').doc(orderId).get();

      if (!orderDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Order not found');
      }

      const orderData = orderDoc.data()!;

      // Check if user has access to this order
      if (orderData.customerId !== context.auth.uid && orderData.vendorId !== context.auth.uid) {
        throw new functions.https.HttpsError('permission-denied', 'Access denied');
      }

      return {
        status: orderData.status,
        paymentStatus: orderData.paymentStatus || 'unknown',
        transferStatus: orderData.transferId ? 'transferred' : 'pending',
      };

    } catch (error: any) {
      console.error('❌ [Stripe Preorder] Error getting status:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  }
);

/**
 * Cancel preorder payment (refund)
 * Only available before transfer is made
 */
export const cancelPreorderPayment = functions.https.onCall(
  async (data: { orderId: string }, context): Promise<{ success: boolean; refundId?: string }> => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { orderId } = data;

    try {
      const orderDoc = await admin.firestore().collection('preorders').doc(orderId).get();

      if (!orderDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Order not found');
      }

      const orderData = orderDoc.data()!;

      // Check if vendor is requesting cancellation
      if (orderData.vendorId !== context.auth.uid) {
        throw new functions.https.HttpsError('permission-denied', 'Only vendor can cancel orders');
      }

      // Check if transfer already happened
      if (orderData.transferId) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Cannot cancel - funds already transferred to vendor'
        );
      }

      // Check if payment succeeded
      if (orderData.status !== 'paid' && orderData.status !== 'pending_payment') {
        throw new functions.https.HttpsError(
          'failed-precondition',
          `Cannot cancel order with status: ${orderData.status}`
        );
      }

      console.log(`💳 [Stripe Preorder] Cancelling order ${orderId}`);

      // Create refund
      const refund = await stripe.refunds.create({
        payment_intent: orderData.paymentIntentId,
        reason: 'requested_by_customer',
      });

      // Update order status
      await admin.firestore().collection('preorders').doc(orderId).update({
        status: 'refunded',
        refundId: refund.id,
        refundedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ [Stripe Preorder] Order cancelled and refunded: ${refund.id}`);

      return {
        success: true,
        refundId: refund.id,
      };

    } catch (error: any) {
      console.error('❌ [Stripe Preorder] Error cancelling payment:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  }
);
