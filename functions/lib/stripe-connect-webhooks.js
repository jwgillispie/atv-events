"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.testStripeWebhook = exports.stripeConnectWebhook = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const stripe_1 = __importDefault(require("stripe"));
const stripe = new stripe_1.default(functions.config().stripe.secret_key, {
    apiVersion: '2024-04-10',
});
// Use separate webhook secret for Connect (different from subscription webhook)
const webhookSecret = functions.config().stripe?.connect_webhook_secret || '';
/**
 * Stripe Connect Webhook Handler
 * Handles payment success, transfers, and account updates
 */
exports.stripeConnectWebhook = functions.https.onRequest(async (req, res) => {
    const sig = req.headers['stripe-signature'];
    let event;
    try {
        // Verify webhook signature
        if (webhookSecret) {
            event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
        }
        else {
            // For development - skip signature verification (NOT recommended for production)
            console.warn('⚠️ [Stripe Webhook] No webhook secret configured - skipping signature verification');
            event = JSON.parse(req.body);
        }
    }
    catch (err) {
        console.error('❌ [Stripe Webhook] Signature verification failed:', err.message);
        res.status(400).send(`Webhook Error: ${err.message}`);
        return;
    }
    console.log(`🔔 [Stripe Webhook] Received event: ${event.type}`);
    try {
        switch (event.type) {
            case 'payment_intent.succeeded':
                await handlePaymentSuccess(event.data.object);
                break;
            case 'payment_intent.payment_failed':
                await handlePaymentFailed(event.data.object);
                break;
            case 'transfer.created':
                console.log(`✅ [Stripe Webhook] Transfer created: ${event.data.object.id}`);
                break;
            case 'account.updated':
                await handleAccountUpdated(event.data.object);
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
    }
    catch (error) {
        console.error('❌ [Stripe Webhook] Error handling webhook:', error);
        res.status(500).send('Webhook handler failed');
    }
});
/**
 * Handle successful payment → create transfer to vendor
 */
async function handlePaymentSuccess(paymentIntent) {
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
        const orderData = orderDoc.data();
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
    }
    catch (error) {
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
async function handlePaymentFailed(paymentIntent) {
    const orderId = paymentIntent.metadata.orderId;
    if (!orderId)
        return;
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
async function handleAccountUpdated(account) {
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
    }
    catch (error) {
        console.error('❌ [Stripe Webhook] Error updating vendor integration:', error);
    }
}
/**
 * Test webhook endpoint (for development)
 * Returns webhook configuration status
 */
exports.testStripeWebhook = functions.https.onRequest(async (req, res) => {
    res.json({
        status: 'ok',
        webhookSecretConfigured: !!webhookSecret,
        stripeApiVersion: '2024-04-10',
        message: 'Stripe Connect webhook endpoint is ready',
    });
});
//# sourceMappingURL=stripe-connect-webhooks.js.map