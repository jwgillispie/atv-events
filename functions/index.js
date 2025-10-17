const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

// Import notification functions
const { sendDailyPopupNotifications } = require('./src/notifications/daily_notifications');
const { sendTwoHourReminders, sendEveningPreview } = require('./src/notifications/reminder_notifications');

// Export notification functions
exports.sendDailyPopupNotifications = sendDailyPopupNotifications;
exports.sendTwoHourReminders = sendTwoHourReminders;
exports.sendEveningPreview = sendEveningPreview;

// Test function to manually trigger notifications (for development)
exports.testNotification = functions.https.onRequest(async (req, res) => {
  try {
    const { userId, type } = req.query;
    
    if (!userId) {
      return res.status(400).send('Missing userId parameter');
    }
    
    // Get user data
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();
    
    if (!userDoc.exists || !userDoc.data().fcmToken) {
      return res.status(404).send('User not found or no FCM token');
    }
    
    const user = userDoc.data();
    
    // Send test notification
    const message = {
      token: user.fcmToken,
      notification: {
        title: '🧪 Test Notification',
        body: type === 'vendor' 
          ? '❤️ Sarah\'s Bakery has a popup today at 10 AM!'
          : '🛍️ Grant Park Market is happening today!',
      },
      data: {
        type: type || 'test',
        timestamp: new Date().toISOString(),
      },
    };
    
    const response = await admin.messaging().send(message);
    console.log('Test notification sent:', response);
    
    res.status(200).json({
      success: true,
      messageId: response,
      user: userId,
      token: user.fcmToken.substring(0, 10) + '...',
    });
  } catch (error) {
    console.error('Error sending test notification:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

// Cleanup function to remove old notification logs (runs weekly)
exports.cleanupNotificationLogs = functions.pubsub
  .schedule('every monday 00:00')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    try {
      const oldLogs = await admin.firestore()
        .collection('notification_logs')
        .where('sentAt', '<', thirtyDaysAgo)
        .get();
      
      const batch = admin.firestore().batch();
      let count = 0;
      
      oldLogs.docs.forEach(doc => {
        batch.delete(doc.ref);
        count++;
      });
      
      if (count > 0) {
        await batch.commit();
        console.log(`Deleted ${count} old notification logs`);
      }
      
      return null;
    } catch (error) {
      console.error('Error cleaning up logs:', error);
      throw error;
    }
  });