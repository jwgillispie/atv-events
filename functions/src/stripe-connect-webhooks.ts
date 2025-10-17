import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Stripe from 'stripe';

const stripe = new Stripe(functions.config().stripe.secret_key, {
  apiVersion: '2024-04-10',
});

// Use separate webhook secret for Connect (different from subscription webhook)
const webhookSecret = functions.config().stripe?.connect_webhook_secret || '';

/**
 * Stripe Connect Webhook Handler
 * Handles payment success, transfers, and account updates
 */

export const stripeConnectWebhook = functions.https.onRequest(async (req, res): Promise<void> => {
  const sig = req.headers['stripe-signature'] as string;

  let event: Stripe.Event;

  try {
    // Verify webhook signature
    if (webhookSecret) {
      event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
    } else {
      // For development - skip signature verification (NOT recommended for production)
      console.warn('⚠️ [Stripe Webhook] No webhook secret configured - skipping signature verification');
      event = JSON.parse(req.body);
    }
  } catch (err: any) {
    console.error('❌ [Stripe Webhook] Signature verification failed:', err.message);
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  console.log(`🔔 [Stripe Webhook] Received event: ${event.type}`);

  try {
    switch (event.type) {
      case 'payment_intent.succeeded':
        await handlePaymentSuccess(event.data.object as Stripe.PaymentIntent);
        break;

      case 'payment_intent.payment_failed':
        await handlePaymentFailed(event.data.object as Stripe.PaymentIntent);
        break;

      case 'transfer.created':
        console.log(`✅ [Stripe Webhook] Transfer created: ${event.data.object.id}`);
        break;

      case 'account.updated':
        await handleAccountUpdated(event.data.object as Stripe.Account);
        break;

      case 'payout.paid':
        console.log(`✅ [Stripe Webhook] Payout completed: ${event.data.object.id}`);
        break;

      case 'payout.failed':
        console.log(`❌ [Stripe Webhook] Payout failed: ${event.data.object.id}`);
        break;

      default:
        console.log(`ℹ️ [Stripe Webhook] Unhandled event type: ${event.type}`);
    }

    res.json({ received: true });
  } catch (error: any) {
    console.error('❌ [Stripe Webhook] Error handling webhook:', error);
    res.status(500).send('Webhook handler failed');
  }
});

/**
 * Handle successful payment → create transfer to vendor
 */
async function handlePaymentSuccess(paymentIntent: Stripe.PaymentIntent) {
  const orderId = paymentIntent.metadata.orderId;
  const vendorId = paymentIntent.metadata.vendorId;

  if (!orderId) {
    console.error('❌ [Stripe Webhook] No orderId in payment intent metadata');
    return;
  }

  console.log(`💳 [Stripe Webhook] Payment succeeded for order ${orderId}`);

  try {
    // Get order details
    const orderDoc = await admin.firestore().collection('preorders').doc(orderId).get();

    if (!orderDoc.exists) {
      console.error(`❌ [Stripe Webhook] Order ${orderId} not found`);
      return;
    }

    const orderData = orderDoc.data()!;
    const vendorPayoutCents = Math.round(orderData.vendorPayout * 100);
    const stripeAccountId = orderData.stripeAccountId;

    console.log(`💸 [Stripe Webhook] Creating transfer of $${vendorPayoutCents / 100} to ${stripeAccountId}`);

    // Create transfer to vendor's Connect account
    const transfer = await stripe.transfers.create({
      amount: vendorPayoutCents,
      currency: 'usd',
      destination: stripeAccountId,
      transfer_group: paymentIntent.id,
      metadata: {
        orderId,
        vendorId,
        platform: 'hipop',
        orderType: 'preorder',
      },
    });

    console.log(`✅ [Stripe Webhook] Transfer created: ${transfer.id}`);

    // Update order with transfer details
    await admin.firestore().collection('preorders').doc(orderId).update({
      status: 'paid',
      paymentStatus: 'succeeded',
      transferId: transfer.id,
      transferredAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentSucceededAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ [Stripe Webhook] Order ${orderId} marked as paid with transfer ${transfer.id}`);

    // TODO: Send notification to vendor and customer
    // await sendOrderConfirmationNotifications(orderId, vendorId, orderData.customerId);

  } catch (error: any) {
    console.error('❌ [Stripe Webhook] Error creating transfer:', error);

    // Update order with error
    await admin.firestore().collection('preorders').doc(orderId).update({
      status: 'payment_succeeded_transfer_failed',
      transferError: error.message,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

/**
 * Handle payment failure
 */
async function handlePaymentFailed(paymentIntent: Stripe.PaymentIntent) {
  const orderId = paymentIntent.metadata.orderId;

  if (!orderId) return;

  console.log(`❌ [Stripe Webhook] Payment failed for order ${orderId}`);

  await admin.firestore().collection('preorders').doc(orderId).update({
    status: 'payment_failed',
    paymentStatus: 'failed',
    paymentFailureReason: paymentIntent.last_payment_error?.message || 'Unknown error',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}


/**
 * Handle Connect account updates (verification progress)
 */
async function handleAccountUpdated(account: Stripe.Account) {
  const vendorId = account.metadata?.vendorId;

  if (!vendorId) {
    console.log('ℹ️ [Stripe Webhook] Account update has no vendorId in metadata');
    return;
  }

  const isFullyVerified = account.charges_enabled && account.payouts_enabled;

  console.log(`🔔 [Stripe Webhook] Account ${account.id} updated - Verified: ${isFullyVerified}`);

  try {
    await admin.firestore()
      .collection('vendor_integrations')
      .doc(vendorId)
      .update({
        'stripe.status': isFullyVerified ? 'active' : 'pending',
        'stripe.chargesEnabled': account.charges_enabled,
        'stripe.payoutsEnabled': account.payouts_enabled,
        'stripe.detailsSubmitted': account.details_submitted,
        'stripe.businessName': account.business_profile?.name || null,
        'stripe.currentRequirements': account.requirements?.currently_due || [],
        'stripe.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
      });

    console.log(`✅ [Stripe Webhook] Vendor ${vendorId} integration updated`);

    // If newly verified, send notification to vendor
    if (isFullyVerified) {
      console.log(`🎉 [Stripe Webhook] Vendor ${vendorId} is now fully verified!`);
      // TODO: Send push notification to vendor
    }

  } catch (error: any) {
    console.error('❌ [Stripe Webhook] Error updating vendor integration:', error);
  }
}

/**
 * Test webhook endpoint (for development)
 * Returns webhook configuration status
 */
export const testStripeWebhook = functions.https.onRequest(async (req, res): Promise<void> => {
  res.json({
    status: 'ok',
    webhookSecretConfigured: !!webhookSecret,
    stripeApiVersion: '2024-04-10',
    message: 'Stripe Connect webhook endpoint is ready',
  });
});
