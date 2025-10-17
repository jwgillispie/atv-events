const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * Send daily popup notifications at 8 AM Eastern Time
 * Checks user_favorites collection and sends notifications for today's events
 */
exports.sendDailyPopupNotifications = functions.pubsub
  .schedule('0 8 * * *')
  .timeZone('America/New_York') // Eastern Time
  .onRun(async (context) => {
    console.log('Starting daily notification job at 8 AM Eastern');
    
    // Get today's date range in Eastern Time
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    
    try {
      // Process vendor popups
      const vendorNotifications = await processVendorPopups(today, tomorrow);
      
      // Process market reminders
      const marketNotifications = await processMarketReminders(today, tomorrow);
      
      // Send all notifications in batches
      const results = await sendNotificationBatch([
        ...vendorNotifications,
        ...marketNotifications
      ]);
      
      console.log(`✅ Sent ${results.success} notifications, ${results.failed} failed`);
      return null;
    } catch (error) {
      console.error('❌ Error in daily notification job:', error);
      throw error;
    }
  });

/**
 * Process vendor popup notifications for users who favorited vendors
 */
async function processVendorPopups(today, tomorrow) {
  const notifications = [];
  
  // Get all vendor posts for today
  const postsSnapshot = await admin.firestore()
    .collection('vendor_posts')
    .where('popupDate', '>=', today)
    .where('popupDate', '<', tomorrow)
    .where('isActive', '==', true)
    .get();
  
  console.log(`Found ${postsSnapshot.size} vendor popups for today`);
  
  for (const postDoc of postsSnapshot.docs) {
    const post = postDoc.data();
    
    // Find users who favorited this vendor (using user_favorites, not vendor_follows)
    const favoritesSnapshot = await admin.firestore()
      .collection('user_favorites')
      .where('itemId', '==', post.vendorId)
      .where('type', '==', 'vendor')
      .get();
    
    console.log(`Found ${favoritesSnapshot.size} users who favorited ${post.vendorName}`);
    
    for (const favoriteDoc of favoritesSnapshot.docs) {
      const favorite = favoriteDoc.data();
      
      // Get user preferences and token
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(favorite.userId)
        .get();
      
      if (!userDoc.exists) continue;
      
      const user = userDoc.data();
      
      // Check if user wants vendor notifications
      if (!user.fcmToken || 
          !user.notificationPreferences?.enabled ||
          !user.notificationPreferences?.vendorPopups) {
        continue;
      }
      
      // Check quiet hours (Eastern Time)
      if (isInQuietHours(user.notificationPreferences)) {
        continue;
      }
      
      // Create notification
      const notificationId = generateNotificationId();
      notifications.push({
        token: user.fcmToken,
        notification: {
          title: `❤️ ${post.vendorName} has a popup today!`,
          body: `${formatTime(post.popupTime)} at ${post.location}`,
        },
        data: {
          type: 'vendor_popup',
          vendorId: post.vendorId,
          postId: postDoc.id,
          notificationId: notificationId,
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              'mutable-content': 1,
            }
          }
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'vendor_popups',
            color: '#4A7C59', // HiPop sage
            icon: 'ic_notification',
          }
        }
      });
      
      // Log notification
      await logNotification({
        notificationId,
        userId: favorite.userId,
        type: 'vendor_popup',
        itemId: post.vendorId,
        itemName: post.vendorName,
      });
    }
  }
  
  return notifications;
}

/**
 * Process market reminder notifications for users who favorited markets
 */
async function processMarketReminders(today, tomorrow) {
  const notifications = [];
  
  // Get all markets for today
  const marketsSnapshot = await admin.firestore()
    .collection('markets')
    .where('eventDate', '>=', today)
    .where('eventDate', '<', tomorrow)
    .where('isActive', '==', true)
    .get();
  
  console.log(`Found ${marketsSnapshot.size} markets for today`);
  
  for (const marketDoc of marketsSnapshot.docs) {
    const market = marketDoc.data();
    
    // Find users who favorited this market
    const favoritesSnapshot = await admin.firestore()
      .collection('user_favorites')
      .where('itemId', '==', marketDoc.id)
      .where('type', '==', 'market')
      .get();
    
    console.log(`Found ${favoritesSnapshot.size} users who favorited ${market.name}`);
    
    // Get vendor count for this market
    const vendorCount = await getMarketVendorCount(marketDoc.id);
    
    for (const favoriteDoc of favoritesSnapshot.docs) {
      const favorite = favoriteDoc.data();
      
      // Get user preferences and token
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(favorite.userId)
        .get();
      
      if (!userDoc.exists) continue;
      
      const user = userDoc.data();
      
      // Check if user wants market notifications
      if (!user.fcmToken || 
          !user.notificationPreferences?.enabled ||
          !user.notificationPreferences?.marketReminders) {
        continue;
      }
      
      // Check quiet hours (Eastern Time)
      if (isInQuietHours(user.notificationPreferences)) {
        continue;
      }
      
      // Create notification
      const notificationId = generateNotificationId();
      notifications.push({
        token: user.fcmToken,
        notification: {
          title: `🛍️ ${market.name} is happening today!`,
          body: `Starting at ${formatTime(market.startTime)} ET • ${vendorCount} vendors`,
        },
        data: {
          type: 'market_today',
          marketId: marketDoc.id,
          notificationId: notificationId,
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            }
          }
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'market_reminders',
            color: '#4A7C59', // HiPop sage
            icon: 'ic_notification',
          }
        }
      });
      
      // Log notification
      await logNotification({
        notificationId,
        userId: favorite.userId,
        type: 'market_reminder',
        itemId: marketDoc.id,
        itemName: market.name,
      });
    }
  }
  
  return notifications;
}

/**
 * Send notifications in batches (FCM limit: 500 per batch)
 */
async function sendNotificationBatch(notifications) {
  const batchSize = 500;
  let successCount = 0;
  let failCount = 0;
  
  console.log(`Sending ${notifications.length} notifications in batches...`);
  
  for (let i = 0; i < notifications.length; i += batchSize) {
    const batch = notifications.slice(i, i + batchSize);
    
    try {
      const response = await admin.messaging().sendAll(batch);
      successCount += response.successCount;
      failCount += response.failureCount;
      
      // Handle failed notifications
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          handleFailedNotification(batch[idx], resp.error);
        }
      });
    } catch (error) {
      console.error('Batch send error:', error);
      failCount += batch.length;
    }
  }
  
  return { success: successCount, failed: failCount };
}

// Helper functions
function generateNotificationId() {
  return admin.firestore().collection('notification_logs').doc().id;
}

function formatTime(date) {
  if (!date) return '';
  const d = date.toDate ? date.toDate() : new Date(date);
  return d.toLocaleTimeString('en-US', { 
    hour: 'numeric', 
    minute: '2-digit',
    hour12: true,
    timeZone: 'America/New_York'
  });
}

function isInQuietHours(preferences) {
  if (!preferences?.quietHoursStart || !preferences?.quietHoursEnd) {
    return false;
  }
  
  // Get current time in Eastern Time
  const now = new Date();
  const easternTime = new Date(now.toLocaleString("en-US", {timeZone: "America/New_York"}));
  const currentHour = easternTime.getHours();
  const currentMinute = easternTime.getMinutes();
  const currentTime = currentHour * 60 + currentMinute;
  
  const [startHour, startMin] = preferences.quietHoursStart.split(':').map(Number);
  const [endHour, endMin] = preferences.quietHoursEnd.split(':').map(Number);
  
  const startTime = startHour * 60 + startMin;
  const endTime = endHour * 60 + endMin;
  
  if (startTime <= endTime) {
    return currentTime >= startTime && currentTime <= endTime;
  } else {
    return currentTime >= startTime || currentTime <= endTime;
  }
}

async function logNotification(data) {
  await admin.firestore()
    .collection('notification_logs')
    .doc(data.notificationId)
    .set({
      ...data,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      opened: false,
      openedAt: null,
    });
}

async function handleFailedNotification(notification, error) {
  console.error('Failed to send notification:', error);
  
  // Log the error
  if (notification.data?.notificationId) {
    await admin.firestore()
      .collection('notification_logs')
      .doc(notification.data.notificationId)
      .update({
        error: error.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  }
  
  // If invalid token, remove it
  if (error.code === 'messaging/invalid-registration-token' ||
      error.code === 'messaging/registration-token-not-registered') {
    // Find user with this token and clear it
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .where('fcmToken', '==', notification.token)
      .limit(1)
      .get();
    
    if (!usersSnapshot.empty) {
      await usersSnapshot.docs[0].ref.update({
        fcmToken: admin.firestore.FieldValue.delete(),
        lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`Removed invalid token for user ${usersSnapshot.docs[0].id}`);
    }
  }
}

async function getMarketVendorCount(marketId) {
  // Try to get from vendor_markets collection
  try {
    const snapshot = await admin.firestore()
      .collection('vendor_markets')
      .where('marketId', '==', marketId)
      .where('status', '==', 'approved')
      .count()
      .get();
    
    return snapshot.data().count || 0;
  } catch (error) {
    // Fallback to managed_vendors if vendor_markets doesn't exist
    try {
      const marketDoc = await admin.firestore()
        .collection('markets')
        .doc(marketId)
        .get();
      
      const vendorIds = marketDoc.data()?.vendorIds || [];
      return vendorIds.length;
    } catch (e) {
      return 0;
    }
  }
}