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
Object.defineProperty(exports, "__esModule", { value: true });
exports.getVendorSalesSummary = exports.backfillStripePreordersToSales = exports.syncStripePreorderToSales = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
/**
 * Firestore trigger: Sync preorder to vendor_sales when payment succeeds
 * Triggers on preorder status change to 'paid'
 */
exports.syncStripePreorderToSales = functions.firestore
    .document('preorders/{orderId}')
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const orderId = context.params.orderId;
    // Only sync when status changes to 'paid' (payment succeeded)
    if (before.status !== 'paid' && after.status === 'paid') {
        console.log(`💳 [Stripe Sync] Syncing preorder ${orderId} to vendor_sales`);
        try {
            await syncPreorderToVendorSales(orderId, after);
            console.log(`✅ [Stripe Sync] Successfully synced preorder ${orderId} to vendor_sales`);
        }
        catch (error) {
            console.error(`❌ [Stripe Sync] Error syncing preorder ${orderId}:`, error);
            // Don't throw - we don't want to fail the payment update
        }
    }
    return null;
});
/**
 * Sync a preorder to vendor_sales collection
 */
async function syncPreorderToVendorSales(orderId, preorder) {
    const { vendorId, customerId, items, totalAmount, marketId, marketName, paymentSucceededAt, createdAt } = preorder;
    // Get vendor details for location info if needed
    let location = null;
    let organizerId = null;
    // If market associated, get market details
    if (marketId) {
        try {
            const marketDoc = await admin.firestore().collection('markets').doc(marketId).get();
            if (marketDoc.exists) {
                const marketData = marketDoc.data();
                location = marketData?.location || null;
                organizerId = marketData?.organizerId || null;
            }
        }
        catch (error) {
            console.warn(`⚠️ [Stripe Sync] Could not fetch market details for ${marketId}:`, error);
        }
    }
    // Convert items to line items format (matching Square sync structure)
    const lineItems = items.map(item => ({
        name: item.productName,
        productId: item.productId,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        totalPrice: item.totalPrice,
    }));
    // Create sales record matching Square sync format
    const salesRecord = {
        vendorId,
        paymentId: preorder.paymentIntentId,
        orderId,
        source: 'stripe',
        amount: totalAmount,
        currency: 'usd',
        status: 'COMPLETED',
        paymentMethod: 'card',
        // Use payment success time if available, otherwise order creation time
        timestamp: paymentSucceededAt || createdAt,
        // Customer info
        customerId: customerId,
        // Market/popup attribution (preorders don't have specific popup, just market)
        popupId: null,
        marketId: marketId || null,
        marketName: marketName || null,
        location: location,
        organizerId: organizerId,
        // Product line items
        lineItems: lineItems,
        // Metadata
        stripeTransferId: preorder.transferId || null,
        stripeAccountId: preorder.stripeAccountId,
        isPreorder: true,
        isAssigned: !!marketId,
        // Timestamps
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        syncedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    // Use consistent ID format: vendorId_paymentIntentId
    const salesRef = admin.firestore()
        .collection('vendor_sales')
        .doc(`${vendorId}_${preorder.paymentIntentId}`);
    await salesRef.set(salesRecord, { merge: true });
    console.log(`✅ [Stripe Sync] Created vendor_sales record: ${salesRef.id}`);
}
/**
 * Manual backfill function to sync existing paid preorders to vendor_sales
 * Callable function for one-time migration or testing
 */
exports.backfillStripePreordersToSales = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    // Optional: Restrict to admin users
    // const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    // if (userDoc.data()?.role !== 'ceo') {
    //   throw new functions.https.HttpsError('permission-denied', 'Only admins can run backfill');
    // }
    console.log('💳 [Stripe Sync] Starting manual backfill of preorders to vendor_sales...');
    try {
        // Get all paid preorders that haven't been synced yet
        const preordersSnapshot = await admin.firestore()
            .collection('preorders')
            .where('status', '==', 'paid')
            .get();
        console.log(`💳 [Stripe Sync] Found ${preordersSnapshot.size} paid preorders`);
        let syncedCount = 0;
        let errorCount = 0;
        // Process each preorder
        for (const doc of preordersSnapshot.docs) {
            const preorder = doc.data();
            const orderId = doc.id;
            try {
                // Check if already synced
                const salesDocId = `${preorder.vendorId}_${preorder.paymentIntentId}`;
                const existingDoc = await admin.firestore()
                    .collection('vendor_sales')
                    .doc(salesDocId)
                    .get();
                if (existingDoc.exists) {
                    console.log(`ℹ️ [Stripe Sync] Preorder ${orderId} already synced, skipping`);
                    continue;
                }
                // Sync to vendor_sales
                await syncPreorderToVendorSales(orderId, preorder);
                syncedCount++;
                console.log(`✅ [Stripe Sync] Backfilled preorder ${orderId}`);
            }
            catch (error) {
                console.error(`❌ [Stripe Sync] Error backfilling preorder ${orderId}:`, error);
                errorCount++;
            }
        }
        const message = `Backfill complete: ${syncedCount} preorders synced, ${errorCount} errors`;
        console.log(`✅ [Stripe Sync] ${message}`);
        return {
            success: true,
            syncedCount,
            errorCount,
            message,
        };
    }
    catch (error) {
        console.error('❌ [Stripe Sync] Backfill failed:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});
/**
 * Get vendor sales summary from vendor_sales collection
 * Aggregates both Square and Stripe payments for unified analytics
 */
exports.getVendorSalesSummary = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const vendorId = data.vendorId || context.auth.uid;
    // Verify user can access this vendor's data
    if (vendorId !== context.auth.uid) {
        const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
        if (userDoc.data()?.role !== 'ceo') {
            throw new functions.https.HttpsError('permission-denied', 'Access denied');
        }
    }
    try {
        console.log(`💳 [Stripe Sync] Getting sales summary for vendor ${vendorId}`);
        let query = admin.firestore()
            .collection('vendor_sales')
            .where('vendorId', '==', vendorId);
        // Apply date filters if provided
        if (data.startDate) {
            const startTimestamp = admin.firestore.Timestamp.fromDate(new Date(data.startDate));
            query = query.where('timestamp', '>=', startTimestamp);
        }
        if (data.endDate) {
            const endTimestamp = admin.firestore.Timestamp.fromDate(new Date(data.endDate));
            query = query.where('timestamp', '<=', endTimestamp);
        }
        const salesSnapshot = await query.get();
        console.log(`💳 [Stripe Sync] Found ${salesSnapshot.size} sales records`);
        // Aggregate data
        let totalRevenue = 0;
        let stripeRevenue = 0;
        let squareRevenue = 0;
        let stripeSales = 0;
        let squareSales = 0;
        const salesByMarket = {};
        salesSnapshot.docs.forEach(doc => {
            const sale = doc.data();
            const amount = sale.amount || 0;
            totalRevenue += amount;
            if (sale.source === 'stripe') {
                stripeRevenue += amount;
                stripeSales++;
            }
            else if (sale.source === 'square') {
                squareRevenue += amount;
                squareSales++;
            }
            // Group by market
            const marketKey = sale.marketName || 'Unassigned';
            if (!salesByMarket[marketKey]) {
                salesByMarket[marketKey] = { count: 0, revenue: 0 };
            }
            salesByMarket[marketKey].count++;
            salesByMarket[marketKey].revenue += amount;
        });
        return {
            totalRevenue: Math.round(totalRevenue * 100) / 100,
            totalSales: salesSnapshot.size,
            stripeSales,
            squareSales,
            stripeRevenue: Math.round(stripeRevenue * 100) / 100,
            squareRevenue: Math.round(squareRevenue * 100) / 100,
            salesByMarket,
        };
    }
    catch (error) {
        console.error('❌ [Stripe Sync] Error getting sales summary:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});
//# sourceMappingURL=stripe-payments-sync.js.map