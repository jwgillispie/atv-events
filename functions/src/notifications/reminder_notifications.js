const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * Send 2-hour reminder notifications
 * Runs every 30 minutes to catch events starting in ~2 hours
 */
exports.sendTwoHourReminders = functions.pubsub
  .schedule('*/30 * * * *') // Every 30 minutes
  .timeZone('America/New_York') // Eastern Time
  .onRun(async (context) => {
    const now = new Date();
    const twoHoursLater = new Date(now.getTime() + 2 * 60 * 60 * 1000);
    const twoHoursThirtyLater = new Date(now.getTime() + 2.5 * 60 * 60 * 1000);
    
    console.log(`Checking for events between ${twoHoursLater.toLocaleTimeString()} and ${twoHoursThirtyLater.toLocaleTimeString()} ET`);
    
    try {
      // Find vendor posts starting in ~2 hours
      const upcomingPosts = await admin.firestore()
        .collection('vendor_posts')
        .where('popupDateTime', '>=', twoHoursLater)
        .where('popupDateTime', '<=', twoHoursThirtyLater)
        .where('isActive', '==', true)
        .where('reminderSent', '==', false) // Avoid duplicate reminders
        .get();
      
      console.log(`Found ${upcomingPosts.size} upcoming vendor popups`);
      
      const notifications = [];
      
      for (const postDoc of upcomingPosts.docs) {
        const post = postDoc.data();
        
        // Find users who favorited this vendor
        const favoritesSnapshot = await admin.firestore()
          .collection('user_favorites')
          .where('itemId', '==', post.vendorId)
          .where('type', '==', 'vendor')
          .get();
        
        for (const favoriteDoc of favoritesSnapshot.docs) {
          const favorite = favoriteDoc.data();
          
          // Get user preferences
          const userDoc = await admin.firestore()
            .collection('users')
            .doc(favorite.userId)
            .get();
          
          if (!userDoc.exists) continue;
          
          const user = userDoc.data();
          
          // Check if user wants 2-hour reminders
          if (!user.fcmToken || 
              !user.notificationPreferences?.enabled ||
              !user.notificationPreferences?.twoHourReminders) {
            continue;
          }
          
          // Check quiet hours
          if (isInQuietHours(user.notificationPreferences)) {
            continue;
          }
          
          // Create reminder notification
          notifications.push({
            token: user.fcmToken,
            notification: {
              title: `⏰ ${post.vendorName} starts in 2 hours!`,
              body: `At ${post.location} • Tap for directions`,
            },
            data: {
              type: 'popup_starting',
              vendorId: post.vendorId,
              postId: postDoc.id,
              notificationId: generateNotificationId(),
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
                channelId: 'reminders',
                color: '#FF8C42', // HiPop orange
                icon: 'ic_notification',
              }
            }
          });
        }
        
        // Mark reminder as sent
        await postDoc.ref.update({
          reminderSent: true,
          reminderSentAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }
      
      // Send all reminder notifications
      if (notifications.length > 0) {
        const results = await sendNotificationBatch(notifications);
        console.log(`✅ Sent ${results.success} reminder notifications`);
      }
      
      return null;
    } catch (error) {
      console.error('❌ Error in reminder notifications:', error);
      throw error;
    }
  });

/**
 * Send evening preview notifications at 6 PM Eastern
 * Shows tomorrow's favorites that have events
 */
exports.sendEveningPreview = functions.pubsub
  .schedule('0 18 * * *') // 6 PM
  .timeZone('America/New_York') // Eastern Time
  .onRun(async (context) => {
    console.log('Starting evening preview notifications at 6 PM ET');
    
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(0, 0, 0, 0);
    const dayAfter = new Date(tomorrow);
    dayAfter.setDate(dayAfter.getDate() + 1);
    
    try {
      // Get all users with evening preview enabled
      const usersSnapshot = await admin.firestore()
        .collection('users')
        .where('notificationPreferences.enabled', '==', true)
        .where('notificationPreferences.eveningPreview', '==', true)
        .get();
      
      console.log(`Found ${usersSnapshot.size} users with evening preview enabled`);
      
      const notifications = [];
      
      for (const userDoc of usersSnapshot.docs) {
        const user = userDoc.data();
        
        if (!user.fcmToken) continue;
        
        // Check quiet hours
        if (isInQuietHours(user.notificationPreferences)) {
          continue;
        }
        
        // Get user's favorites
        const favoritesSnapshot = await admin.firestore()
          .collection('user_favorites')
          .where('userId', '==', userDoc.id)
          .get();
        
        const vendorIds = [];
        const marketIds = [];
        
        favoritesSnapshot.docs.forEach(doc => {
          const fav = doc.data();
          if (fav.type === 'vendor') {
            vendorIds.push(fav.itemId);
          } else if (fav.type === 'market') {
            marketIds.push(fav.itemId);
          }
        });
        
        // Check for tomorrow's vendor popups
        let vendorCount = 0;
        if (vendorIds.length > 0) {
          // Firestore 'in' query limited to 10 items
          const vendorBatches = [];
          for (let i = 0; i < vendorIds.length; i += 10) {
            vendorBatches.push(vendorIds.slice(i, i + 10));
          }
          
          for (const batch of vendorBatches) {
            const postsSnapshot = await admin.firestore()
              .collection('vendor_posts')
              .where('vendorId', 'in', batch)
              .where('popupDate', '>=', tomorrow)
              .where('popupDate', '<', dayAfter)
              .where('isActive', '==', true)
              .get();
            
            vendorCount += postsSnapshot.size;
          }
        }
        
        // Check for tomorrow's markets
        let marketCount = 0;
        if (marketIds.length > 0) {
          const marketBatches = [];
          for (let i = 0; i < marketIds.length; i += 10) {
            marketBatches.push(marketIds.slice(i, i + 10));
          }
          
          for (const batch of marketBatches) {
            const marketsSnapshot = await admin.firestore()
              .collection('markets')
              .where(admin.firestore.FieldPath.documentId(), 'in', batch)
              .where('eventDate', '>=', tomorrow)
              .where('eventDate', '<', dayAfter)
              .where('isActive', '==', true)
              .get();
            
            marketCount += marketsSnapshot.size;
          }
        }
        
        // Send preview if there are events
        const totalCount = vendorCount + marketCount;
        if (totalCount > 0) {
          let title = '📅 Tomorrow: ';
          const parts = [];
          
          if (vendorCount > 0) {
            parts.push(`${vendorCount} vendor${vendorCount > 1 ? 's' : ''}`);
          }
          if (marketCount > 0) {
            parts.push(`${marketCount} market${marketCount > 1 ? 's' : ''}`);
          }
          
          title += parts.join(' and ') + ' you love!';
          
          notifications.push({
            token: user.fcmToken,
            notification: {
              title: title,
              body: 'Plan your day • Tap to see all',
            },
            data: {
              type: 'tomorrow_preview',
              vendorCount: vendorCount.toString(),
              marketCount: marketCount.toString(),
              notificationId: generateNotificationId(),
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
              priority: 'normal',
              notification: {
                channelId: 'daily_summary',
                color: '#4A7C59', // HiPop sage
                icon: 'ic_notification',
              }
            }
          });
        }
      }
      
      // Send all preview notifications
      if (notifications.length > 0) {
        const results = await sendNotificationBatch(notifications);
        console.log(`✅ Sent ${results.success} evening preview notifications`);
      }
      
      return null;
    } catch (error) {
      console.error('❌ Error in evening preview:', error);
      throw error;
    }
  });

// Shared helper functions (same as daily_notifications.js)
function generateNotificationId() {
  return admin.firestore().collection('notification_logs').doc().id;
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

async function sendNotificationBatch(notifications) {
  const batchSize = 500;
  let successCount = 0;
  let failCount = 0;
  
  for (let i = 0; i < notifications.length; i += batchSize) {
    const batch = notifications.slice(i, i + batchSize);
    
    try {
      const response = await admin.messaging().sendAll(batch);
      successCount += response.successCount;
      failCount += response.failureCount;
      
      // Handle failed notifications
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.error('Failed notification:', resp.error);
        }
      });
    } catch (error) {
      console.error('Batch send error:', error);
      failCount += batch.length;
    }
  }
  
  return { success: successCount, failed: failCount };
}