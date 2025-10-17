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
exports.onApplicationUpdated = exports.onApplicationCreated = exports.expireApplicationsScheduled = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
/**
 * Scheduled function to expire approved applications after 24 hours
 * Runs every hour to check for expired approvals
 */
exports.expireApplicationsScheduled = functions.pubsub
    .schedule('every 1 hours')
    .onRun(async (context) => {
    console.log('🕐 Running scheduled application expiration check...');
    const now = admin.firestore.Timestamp.now();
    try {
        // Find all approved applications that have expired
        const expiredAppsSnapshot = await db
            .collection('vendor_applications')
            .where('status', '==', 'approved')
            .where('approvalExpiresAt', '<=', now)
            .get();
        if (expiredAppsSnapshot.empty) {
            console.log('✅ No expired applications found');
            return null;
        }
        console.log(`⚠️ Found ${expiredAppsSnapshot.docs.length} expired applications`);
        // Update all expired applications
        const batch = db.batch();
        const expiredApplications = [];
        for (const doc of expiredAppsSnapshot.docs) {
            const data = doc.data();
            // Update application status to expired
            batch.update(doc.ref, {
                status: 'expired',
                expiredAt: now,
            });
            expiredApplications.push({
                id: doc.id,
                vendorId: data.vendorId,
                marketId: data.marketId,
                marketName: data.marketName || 'Unknown Market',
                vendorName: data.vendorName || 'Unknown Vendor',
            });
            console.log(`   ❌ Expired: ${data.vendorName} → ${data.marketName}`);
        }
        // Commit the batch
        await batch.commit();
        // Send notifications to vendors (optional - implement if needed)
        for (const app of expiredApplications) {
            try {
                await sendExpirationNotification(app);
            }
            catch (notifError) {
                console.error(`Failed to send notification for ${app.id}:`, notifError);
            }
        }
        console.log(`✅ Successfully expired ${expiredApplications.length} applications`);
        return null;
    }
    catch (error) {
        console.error('❌ Error expiring applications:', error);
        throw error;
    }
});
/**
 * Triggered when a vendor application is created
 * Sends notification to organizer
 */
exports.onApplicationCreated = functions.firestore
    .document('vendor_applications/{applicationId}')
    .onCreate(async (snapshot, context) => {
    const application = snapshot.data();
    const applicationId = context.params.applicationId;
    console.log(`📝 New application created: ${applicationId}`);
    console.log(`   Vendor: ${application.vendorName}`);
    console.log(`   Market: ${application.marketName}`);
    try {
        // Send notification to organizer
        await sendNewApplicationNotification({
            organizerId: application.organizerId,
            vendorName: application.vendorName,
            marketName: application.marketName,
            applicationId: applicationId,
        });
        console.log(`✅ Notification sent to organizer`);
    }
    catch (error) {
        console.error('❌ Error sending notification:', error);
        // Don't throw - notification failure shouldn't fail the function
    }
    return null;
});
/**
 * Triggered when a vendor application is updated
 * Sends appropriate notifications based on status changes
 */
exports.onApplicationUpdated = functions.firestore
    .document('vendor_applications/{applicationId}')
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const applicationId = context.params.applicationId;
    // Check if status changed
    if (before.status === after.status) {
        return null; // No status change, exit early
    }
    console.log(`🔄 Application ${applicationId} status changed: ${before.status} → ${after.status}`);
    try {
        // Handle different status transitions
        switch (after.status) {
            case 'approved':
                await handleApplicationApproved({
                    applicationId,
                    vendorId: after.vendorId,
                    vendorName: after.vendorName,
                    marketName: after.marketName,
                    approvalExpiresAt: after.approvalExpiresAt,
                    totalFee: after.totalFee,
                });
                break;
            case 'denied':
                await handleApplicationDenied({
                    applicationId,
                    vendorId: after.vendorId,
                    vendorName: after.vendorName,
                    marketName: after.marketName,
                    denialNote: after.denialNote,
                });
                break;
            case 'confirmed':
                await handleApplicationConfirmed({
                    applicationId,
                    vendorId: after.vendorId,
                    organizerId: after.organizerId,
                    vendorName: after.vendorName,
                    marketName: after.marketName,
                    marketId: after.marketId,
                    totalFee: after.totalFee,
                });
                break;
            case 'expired':
                await handleApplicationExpired({
                    applicationId,
                    vendorId: after.vendorId,
                    organizerId: after.organizerId,
                    vendorName: after.vendorName,
                    marketName: after.marketName,
                });
                break;
        }
        console.log(`✅ Handled ${after.status} notification`);
    }
    catch (error) {
        console.error(`❌ Error handling status change to ${after.status}:`, error);
        // Don't throw - notification failure shouldn't fail the function
    }
    return null;
});
// ============================================================================
// NOTIFICATION HANDLERS
// ============================================================================
async function sendNewApplicationNotification(data) {
    console.log(`📧 Sending new application notification to organizer ${data.organizerId}`);
    // Get organizer's FCM token
    const organizerDoc = await db.collection('user_profiles').doc(data.organizerId).get();
    const fcmToken = organizerDoc.data()?.fcmToken;
    if (!fcmToken) {
        console.log('⚠️ No FCM token found for organizer');
        return;
    }
    // Send push notification
    await admin.messaging().send({
        token: fcmToken,
        notification: {
            title: '🆕 New Vendor Application',
            body: `${data.vendorName} applied to ${data.marketName}`,
        },
        data: {
            type: 'vendor_application',
            applicationId: data.applicationId,
            action: 'review',
        },
    });
    // Create in-app notification
    await db.collection('notifications').add({
        userId: data.organizerId,
        type: 'vendor_application_new',
        title: 'New Vendor Application',
        message: `${data.vendorName} has applied to your market: ${data.marketName}`,
        data: {
            applicationId: data.applicationId,
        },
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}
async function handleApplicationApproved(data) {
    console.log(`✅ Sending approval notification to vendor ${data.vendorId}`);
    const vendorDoc = await db.collection('user_profiles').doc(data.vendorId).get();
    const fcmToken = vendorDoc.data()?.fcmToken;
    if (fcmToken) {
        await admin.messaging().send({
            token: fcmToken,
            notification: {
                title: '🎉 Application Approved!',
                body: `Your application to ${data.marketName} was approved. Pay within 24 hours to secure your spot.`,
            },
            data: {
                type: 'vendor_application_approved',
                applicationId: data.applicationId,
                action: 'pay',
            },
        });
    }
    // Create in-app notification with payment link
    await db.collection('notifications').add({
        userId: data.vendorId,
        type: 'vendor_application_approved',
        title: 'Application Approved!',
        message: `Congratulations! Your application to ${data.marketName} has been approved. Complete payment of $${data.totalFee.toFixed(2)} within 24 hours to secure your spot.`,
        data: {
            applicationId: data.applicationId,
            actionUrl: `/vendor/applications/${data.applicationId}/payment`,
            expiresAt: data.approvalExpiresAt.toDate().toISOString(),
        },
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}
async function handleApplicationDenied(data) {
    console.log(`❌ Sending denial notification to vendor ${data.vendorId}`);
    const vendorDoc = await db.collection('user_profiles').doc(data.vendorId).get();
    const fcmToken = vendorDoc.data()?.fcmToken;
    if (fcmToken) {
        await admin.messaging().send({
            token: fcmToken,
            notification: {
                title: 'Application Update',
                body: `Your application to ${data.marketName} was not accepted this time.`,
            },
            data: {
                type: 'vendor_application_denied',
                applicationId: data.applicationId,
            },
        });
    }
    // Create in-app notification
    await db.collection('notifications').add({
        userId: data.vendorId,
        type: 'vendor_application_denied',
        title: 'Application Update',
        message: data.denialNote
            ? `Your application to ${data.marketName} was not accepted. Reason: ${data.denialNote}`
            : `Your application to ${data.marketName} was not accepted this time. Keep looking for other opportunities!`,
        data: {
            applicationId: data.applicationId,
        },
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}
async function handleApplicationConfirmed(data) {
    console.log(`💰 Sending confirmation notifications for ${data.applicationId}`);
    // Notify vendor
    const vendorDoc = await db.collection('user_profiles').doc(data.vendorId).get();
    const vendorFcmToken = vendorDoc.data()?.fcmToken;
    if (vendorFcmToken) {
        await admin.messaging().send({
            token: vendorFcmToken,
            notification: {
                title: '✅ Spot Confirmed!',
                body: `Payment received! Your spot at ${data.marketName} is confirmed.`,
            },
            data: {
                type: 'vendor_application_confirmed',
                applicationId: data.applicationId,
                marketId: data.marketId,
            },
        });
    }
    await db.collection('notifications').add({
        userId: data.vendorId,
        type: 'vendor_application_confirmed',
        title: 'Spot Confirmed!',
        message: `🎉 Your payment of $${data.totalFee.toFixed(2)} was successful. Your vendor spot at ${data.marketName} is confirmed! You can now create popups and manage your presence.`,
        data: {
            applicationId: data.applicationId,
            marketId: data.marketId,
            actionUrl: `/vendor/markets/${data.marketId}`,
        },
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Notify organizer
    const organizerDoc = await db.collection('user_profiles').doc(data.organizerId).get();
    const organizerFcmToken = organizerDoc.data()?.fcmToken;
    if (organizerFcmToken) {
        await admin.messaging().send({
            token: organizerFcmToken,
            notification: {
                title: '💰 Payment Received',
                body: `${data.vendorName} completed payment for ${data.marketName}`,
            },
            data: {
                type: 'vendor_payment_confirmed',
                applicationId: data.applicationId,
                marketId: data.marketId,
            },
        });
    }
    await db.collection('notifications').add({
        userId: data.organizerId,
        type: 'vendor_payment_confirmed',
        title: 'Vendor Payment Confirmed',
        message: `${data.vendorName} has paid $${data.totalFee.toFixed(2)} and secured their spot at ${data.marketName}.`,
        data: {
            applicationId: data.applicationId,
            marketId: data.marketId,
        },
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}
async function handleApplicationExpired(data) {
    console.log(`⏰ Sending expiration notifications for ${data.applicationId}`);
    // Notify vendor
    const vendorDoc = await db.collection('user_profiles').doc(data.vendorId).get();
    const vendorFcmToken = vendorDoc.data()?.fcmToken;
    if (vendorFcmToken) {
        await admin.messaging().send({
            token: vendorFcmToken,
            notification: {
                title: 'Application Expired',
                body: `Your 24-hour payment window for ${data.marketName} has closed.`,
            },
            data: {
                type: 'vendor_application_expired',
                applicationId: data.applicationId,
            },
        });
    }
    await db.collection('notifications').add({
        userId: data.vendorId,
        type: 'vendor_application_expired',
        title: 'Application Expired',
        message: `Your approval for ${data.marketName} has expired. The 24-hour payment window has closed. You can apply again if spots are still available.`,
        data: {
            applicationId: data.applicationId,
        },
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Notify organizer
    const organizerDoc = await db.collection('user_profiles').doc(data.organizerId).get();
    const organizerFcmToken = organizerDoc.data()?.fcmToken;
    if (organizerFcmToken) {
        await admin.messaging().send({
            token: organizerFcmToken,
            notification: {
                title: 'Application Expired',
                body: `${data.vendorName}'s approval for ${data.marketName} expired (no payment).`,
            },
            data: {
                type: 'vendor_application_expired_organizer',
                applicationId: data.applicationId,
            },
        });
    }
    await db.collection('notifications').add({
        userId: data.organizerId,
        type: 'vendor_application_expired_organizer',
        title: 'Vendor Application Expired',
        message: `${data.vendorName}'s approval expired without payment. The spot is now available again.`,
        data: {
            applicationId: data.applicationId,
        },
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}
async function sendExpirationNotification(data) {
    await handleApplicationExpired({
        applicationId: data.id,
        vendorId: data.vendorId,
        organizerId: '',
        vendorName: data.vendorName,
        marketName: data.marketName,
    });
}
//# sourceMappingURL=applications.js.map