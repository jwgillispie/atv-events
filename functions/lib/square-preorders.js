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
exports.fetchSquareCatalog = exports.handleSquareOrderWebhook = exports.createSquarePreorderCheckout = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const node_fetch_1 = __importDefault(require("node-fetch"));
const db = admin.firestore();
/**
 * Create Square checkout for preorder with pickup details
 */
exports.createSquarePreorderCheckout = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { vendorId, popupId, items } = data;
    // Get vendor's Square integration
    const squareDoc = await db.collection('squareIntegrations').doc(vendorId).get();
    if (!squareDoc.exists) {
        throw new functions.https.HttpsError('failed-precondition', 'Vendor has not connected Square');
    }
    const squareData = squareDoc.data();
    // Get popup details for pickup info
    const popupDoc = await db.collection('vendorPosts').doc(popupId).get();
    if (!popupDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Popup not found');
    }
    const popup = popupDoc.data();
    // Create Square order with pickup fulfillment
    const orderResponse = await (0, node_fetch_1.default)('https://connect.squareup.com/v2/orders', {
        method: 'POST',
        headers: {
            'Square-Version': '2025-01-16',
            'Authorization': `Bearer ${squareData.accessToken}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            idempotency_key: `${context.auth.uid}_${Date.now()}`,
            order: {
                location_id: squareData.locationId,
                line_items: items.map((item) => ({
                    catalog_object_id: item.squareCatalogId,
                    quantity: item.quantity.toString(),
                })),
                fulfillments: [
                    {
                        type: 'PICKUP',
                        state: 'PROPOSED',
                        pickup_details: {
                            recipient: {
                                display_name: context.auth.token.name || 'Customer',
                                email_address: context.auth.token.email,
                            },
                            pickup_at: popup.popUpStartDateTime.toDate().toISOString(),
                            note: `🎪 Pickup at ${popup.locationName}\n📍 ${popup.location}\n📅 ${new Date(popup.popUpStartDateTime.toDate()).toLocaleDateString()}`,
                        },
                    },
                ],
                metadata: {
                    hipop_popup_id: popupId,
                    hipop_vendor_id: vendorId,
                    hipop_customer_id: context.auth.uid,
                    pickup_location_name: popup.locationName,
                    pickup_location_address: popup.location,
                },
            },
        }),
    });
    if (!orderResponse.ok) {
        const error = await orderResponse.json();
        console.error('Square order creation failed:', error);
        throw new functions.https.HttpsError('internal', 'Failed to create Square order');
    }
    const orderData = await orderResponse.json();
    const order = orderData.order;
    // Create payment link for the order
    const checkoutResponse = await (0, node_fetch_1.default)('https://connect.squareup.com/v2/online-checkout/payment-links', {
        method: 'POST',
        headers: {
            'Square-Version': '2025-01-16',
            'Authorization': `Bearer ${squareData.accessToken}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            idempotency_key: `checkout_${order.id}`,
            order_id: order.id,
            checkout_options: {
                redirect_url: `https://hipop.app/order-confirmation?orderId=${order.id}`,
                ask_for_shipping_address: false,
            },
        }),
    });
    if (!checkoutResponse.ok) {
        const error = await checkoutResponse.json();
        console.error('Square checkout creation failed:', error);
        throw new functions.https.HttpsError('internal', 'Failed to create checkout link');
    }
    const checkoutData = await checkoutResponse.json();
    // Store order reference in Firestore
    await db.collection('preorders').add({
        orderId: order.id,
        vendorId: vendorId,
        popupId: popupId,
        customerId: context.auth.uid,
        provider: 'square',
        status: 'pending_payment',
        checkoutUrl: checkoutData.payment_link.url,
        pickupLocation: popup.locationName,
        pickupDate: popup.popUpStartDateTime,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {
        checkoutUrl: checkoutData.payment_link.url,
        orderId: order.id,
    };
});
/**
 * Webhook handler for Square order updates
 */
exports.handleSquareOrderWebhook = functions.https.onRequest(async (req, res) => {
    const signature = req.headers['x-square-signature'];
    // Verify webhook signature (implement signature verification)
    // ...
    const event = req.body;
    if (event.type === 'order.updated') {
        const order = event.data.object.order;
        // Update preorder status in Firestore
        const preorderQuery = await db.collection('preorders')
            .where('orderId', '==', order.id)
            .limit(1)
            .get();
        if (!preorderQuery.empty) {
            const preorderDoc = preorderQuery.docs[0];
            let status = 'pending_payment';
            if (order.state === 'COMPLETED') {
                status = 'paid';
            }
            else if (order.state === 'CANCELED') {
                status = 'canceled';
            }
            await preorderDoc.ref.update({
                status: status,
                squareOrderData: order,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            // If order is completed, create sale record for analytics
            if (status === 'paid') {
                const preorderData = preorderDoc.data();
                await db.collection('vendorSales').add({
                    vendorId: preorderData.vendorId,
                    popupId: preorderData.popupId,
                    orderId: order.id,
                    provider: 'square',
                    totalAmount: order.total_money.amount / 100,
                    currency: order.total_money.currency,
                    items: order.line_items.map((item) => ({
                        name: item.name,
                        quantity: parseInt(item.quantity),
                        price: item.base_price_money.amount / 100,
                    })),
                    saleDate: admin.firestore.FieldValue.serverTimestamp(),
                    saleType: 'preorder',
                    pickupDate: preorderData.pickupDate,
                    locationName: preorderData.pickupLocation,
                });
            }
        }
    }
    res.status(200).send({ received: true });
});
/**
 * Fetch vendor's Square catalog items for display in Hipop
 */
exports.fetchSquareCatalog = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { vendorId } = data;
    // Verify user owns this vendor account
    const vendorDoc = await db.collection('vendors').doc(vendorId).get();
    if (!vendorDoc.exists || vendorDoc.data().userId !== context.auth.uid) {
        throw new functions.https.HttpsError('permission-denied', 'Not authorized');
    }
    const squareDoc = await db.collection('squareIntegrations').doc(vendorId).get();
    if (!squareDoc.exists) {
        throw new functions.https.HttpsError('failed-precondition', 'Square not connected');
    }
    const squareData = squareDoc.data();
    // Fetch catalog items from Square
    const catalogResponse = await (0, node_fetch_1.default)('https://connect.squareup.com/v2/catalog/list?types=ITEM', {
        method: 'GET',
        headers: {
            'Square-Version': '2025-01-16',
            'Authorization': `Bearer ${squareData.accessToken}`,
        },
    });
    if (!catalogResponse.ok) {
        throw new functions.https.HttpsError('internal', 'Failed to fetch Square catalog');
    }
    const catalogData = await catalogResponse.json();
    // Transform Square items to Hipop format
    const products = catalogData.objects
        ?.filter((obj) => obj.type === 'ITEM' && obj.item_data.is_archived === false)
        .map((item) => ({
        id: item.id,
        name: item.item_data.name,
        description: item.item_data.description || '',
        price: item.item_data.variations?.[0]?.item_variation_data?.price_money?.amount / 100 || 0,
        imageUrl: item.item_data.image_ids?.[0] ? `square-image-${item.item_data.image_ids[0]}` : null,
        squareCatalogId: item.id,
        inStock: true, // Square handles inventory
    })) || [];
    return { products };
});
//# sourceMappingURL=square-preorders.js.map