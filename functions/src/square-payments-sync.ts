import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import fetch from 'node-fetch';

/**
 * Square Payments Sync Service
 * Automatically syncs Square payments to HiPop for vendor analytics
 */

interface SquarePayment {
  id: string;
  created_at: string;
  updated_at: string;
  amount_money: {
    amount: number;
    currency: string;
  };
  status: string;
  source_type: string;
  location_id?: string;
  order_id?: string;
}

interface SquareLineItem {
  uid?: string;
  name: string;
  quantity: string;
  base_price_money?: {
    amount: number;
    currency: string;
  };
  total_money?: {
    amount: number;
    currency: string;
  };
  variation_name?: string;
}

interface SquareOrder {
  id: string;
  line_items?: SquareLineItem[];
  total_money?: {
    amount: number;
    currency: string;
  };
}

interface VendorPopup {
  id: string;
  vendorId: string;
  marketId: string;
  marketName: string;
  location: string;
  organizerId: string;
  date: admin.firestore.Timestamp;
  startTime?: admin.firestore.Timestamp;
  endTime?: admin.firestore.Timestamp;
}

/**
 * Scheduled function to sync Square payments for all connected vendors
 * Runs every 15 minutes
 */
export const syncSquarePayments = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async () => {
    console.log('🟦 [Square Sync] Starting scheduled payment sync...');

    try {
      // Get all vendor integrations with Square connected
      const integrationsSnapshot = await admin.firestore()
        .collection('vendor_integrations')
        .where('square.accessToken', '!=', null)
        .get();

      console.log(`🟦 [Square Sync] Found ${integrationsSnapshot.size} vendors with Square connected`);

      if (integrationsSnapshot.empty) {
        console.log('✅ [Square Sync] No Square integrations to sync');
        return null;
      }

      let totalSynced = 0;
      let totalErrors = 0;

      // Sync payments for each vendor
      for (const doc of integrationsSnapshot.docs) {
        const vendorId = doc.id;
        const data = doc.data();
        const squareData = data.square;

        if (!squareData?.accessToken) {
          console.warn(`⚠️ [Square Sync] No access token for vendor ${vendorId}`);
          continue;
        }

        try {
          const synced = await syncVendorPayments(vendorId, squareData);
          totalSynced += synced;
        } catch (error) {
          console.error(`❌ [Square Sync] Error syncing vendor ${vendorId}:`, error);
          totalErrors++;
        }
      }

      console.log(`✅ [Square Sync] Complete: ${totalSynced} payments synced, ${totalErrors} errors`);
      return null;

    } catch (error) {
      console.error('❌ [Square Sync] Scheduled sync failed:', error);
      return null;
    }
  });

/**
 * Sync payments for a single vendor
 */
async function syncVendorPayments(vendorId: string, squareData: any): Promise<number> {
  console.log(`🟦 [Square Sync] Syncing payments for vendor ${vendorId}...`);

  try {
    const accessToken = squareData.accessToken;
    const merchantId = squareData.merchantId;

    // Get last sync timestamp for this vendor
    const lastSyncDoc = await admin.firestore()
      .collection('vendor_integrations')
      .doc(vendorId)
      .collection('sync_status')
      .doc('square_payments')
      .get();

    const lastSyncData = lastSyncDoc.data();
    const lastSyncTime = lastSyncData?.lastSyncAt?.toDate() || new Date(Date.now() - 24 * 60 * 60 * 1000); // Default: last 24 hours

    console.log(`🟦 [Square Sync] Last sync: ${lastSyncTime.toISOString()}`);

    // Fetch payments from Square API
    const payments = await fetchSquarePayments(accessToken, merchantId, lastSyncTime);
    console.log(`🟦 [Square Sync] Fetched ${payments.length} new payments from Square`);

    if (payments.length === 0) {
      // Update last sync time even if no new payments
      await lastSyncDoc.ref.set({
        lastSyncAt: admin.firestore.FieldValue.serverTimestamp(),
        lastPaymentCount: 0,
      }, { merge: true });
      return 0;
    }

    // Get vendor's popups for matching
    const popupsSnapshot = await admin.firestore()
      .collection('vendor_popups')
      .where('vendorId', '==', vendorId)
      .get();

    const popups: VendorPopup[] = popupsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    } as VendorPopup));

    console.log(`🟦 [Square Sync] Found ${popups.length} popups for vendor`);

    // Process each payment
    let syncedCount = 0;
    const batch = admin.firestore().batch();

    for (const payment of payments) {
      try {
        // Match payment to popup by timestamp
        const paymentDate = new Date(payment.created_at);
        const matchedPopup = findMatchingPopup(popups, paymentDate);

        if (!matchedPopup) {
          console.warn(`⚠️ [Square Sync] No matching popup for payment ${payment.id} at ${paymentDate.toISOString()}`);
          // Still save payment but mark as unassigned
        }

        // Fetch order details if order_id exists to get line items
        let lineItems: any[] = [];
        if (payment.order_id) {
          try {
            const order = await fetchSquareOrder(accessToken, payment.order_id);
            if (order?.line_items && order.line_items.length > 0) {
              lineItems = order.line_items.map(item => ({
                name: item.name,
                quantity: parseFloat(item.quantity) || 1,
                unitPrice: item.base_price_money ? item.base_price_money.amount / 100 : 0,
                totalPrice: item.total_money ? item.total_money.amount / 100 : 0,
                variationName: item.variation_name || null,
              }));
              console.log(`🟦 [Square Sync] Fetched ${lineItems.length} line items for order ${payment.order_id}`);
            }
          } catch (orderError) {
            console.warn(`⚠️ [Square Sync] Could not fetch order details for ${payment.order_id}:`, orderError);
          }
        }

        // Create sales record
        const salesRecord = {
          vendorId,
          paymentId: payment.id,
          source: 'square',
          amount: payment.amount_money.amount / 100, // Convert cents to dollars
          currency: payment.amount_money.currency,
          status: payment.status,
          paymentMethod: payment.source_type,
          timestamp: admin.firestore.Timestamp.fromDate(paymentDate),

          // Popup/market attribution
          popupId: matchedPopup?.id || null,
          marketId: matchedPopup?.marketId || null,
          marketName: matchedPopup?.marketName || null,
          location: matchedPopup?.location || null,
          organizerId: matchedPopup?.organizerId || null,

          // Product line items
          lineItems: lineItems.length > 0 ? lineItems : null,

          // Metadata
          squareOrderId: payment.order_id || null,
          squareLocationId: payment.location_id || null,
          isAssigned: !!matchedPopup,

          // Timestamps
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          syncedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        const salesRef = admin.firestore()
          .collection('vendor_sales')
          .doc(`${vendorId}_${payment.id}`);

        batch.set(salesRef, salesRecord, { merge: true });
        syncedCount++;

      } catch (error) {
        console.error(`❌ [Square Sync] Error processing payment ${payment.id}:`, error);
      }
    }

    // Commit batch write
    await batch.commit();

    // Update sync status
    await lastSyncDoc.ref.set({
      lastSyncAt: admin.firestore.FieldValue.serverTimestamp(),
      lastPaymentCount: syncedCount,
      totalPaymentsSynced: admin.firestore.FieldValue.increment(syncedCount),
    }, { merge: true });

    console.log(`✅ [Square Sync] Synced ${syncedCount} payments for vendor ${vendorId}`);
    return syncedCount;

  } catch (error: any) {
    console.error(`❌ [Square Sync] Error syncing vendor ${vendorId}:`, error);
    throw error;
  }
}

/**
 * Fetch payments from Square API
 */
async function fetchSquarePayments(
  accessToken: string,
  merchantId: string,
  since: Date
): Promise<SquarePayment[]> {
  try {
    const response = await fetch('https://connect.squareup.com/v2/payments', {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Square-Version': '2024-10-17',
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Square API error: ${response.status} - ${errorText}`);
    }

    const data: any = await response.json();
    const payments: SquarePayment[] = data.payments || [];

    // Filter payments by date (Square API doesn't have a direct date filter for list endpoint)
    return payments.filter((payment: SquarePayment) => {
      const paymentDate = new Date(payment.created_at);
      return paymentDate >= since && payment.status === 'COMPLETED';
    });

  } catch (error) {
    console.error('❌ [Square Sync] Error fetching Square payments:', error);
    throw error;
  }
}

/**
 * Fetch order details from Square API to get line items
 */
async function fetchSquareOrder(
  accessToken: string,
  orderId: string
): Promise<SquareOrder | null> {
  try {
    const response = await fetch(`https://connect.squareup.com/v2/orders/${orderId}`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Square-Version': '2024-10-17',
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Square Orders API error: ${response.status} - ${errorText}`);
    }

    const data: any = await response.json();
    return data.order || null;

  } catch (error) {
    console.error(`❌ [Square Sync] Error fetching order ${orderId}:`, error);
    throw error;
  }
}

/**
 * Find matching popup for a payment timestamp
 */
function findMatchingPopup(popups: VendorPopup[], paymentDate: Date): VendorPopup | null {
  // Check if payment date matches any popup's date
  for (const popup of popups) {
    const popupDate = popup.date.toDate();

    // Check if same day
    if (
      popupDate.getFullYear() === paymentDate.getFullYear() &&
      popupDate.getMonth() === paymentDate.getMonth() &&
      popupDate.getDate() === paymentDate.getDate()
    ) {
      // If popup has start/end times, check if payment is within window
      if (popup.startTime && popup.endTime) {
        const startTime = popup.startTime.toDate();
        const endTime = popup.endTime.toDate();

        if (paymentDate >= startTime && paymentDate <= endTime) {
          return popup;
        }
      } else {
        // No specific time window, just match by date
        return popup;
      }
    }
  }

  return null;
}

/**
 * Manual trigger to force sync for a specific vendor
 * Callable function for testing or manual sync
 */
export const triggerSquareSync = functions.https.onCall(async (data, context) => {
  console.log('🟦 [Square Sync] Manual sync triggered');

  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const vendorId = data.vendorId || context.auth.uid;

  try {
    // Get vendor's Square integration
    const integrationDoc = await admin.firestore()
      .collection('vendor_integrations')
      .doc(vendorId)
      .get();

    if (!integrationDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'No Square integration found');
    }

    const squareData = integrationDoc.data()?.square;
    if (!squareData?.accessToken) {
      throw new functions.https.HttpsError('failed-precondition', 'Square not connected');
    }

    // Sync payments
    const syncedCount = await syncVendorPayments(vendorId, squareData);

    return {
      success: true,
      paymentsSynced: syncedCount,
      message: `Synced ${syncedCount} payments successfully`,
    };

  } catch (error: any) {
    console.error('❌ [Square Sync] Manual sync failed:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
