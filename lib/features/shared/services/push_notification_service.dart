import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/timezone_utils.dart';

/// Service for managing push notifications across the app
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  StreamSubscription<String>? _tokenRefreshSubscription;
  static GoRouter? _router;
  
  /// Initialize the notification service
  Future<void> initialize({GoRouter? router}) async {
    try {
      // Initialize timezone utilities first
      await TimezoneUtils.initialize();
      
      // Store router reference for navigation
      _router = router;
      
      // Request permissions
      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        print('Push notification permissions denied');
      }
      
      // Initialize local notifications for foreground messages
      await _initializeLocalNotifications();
      
      // Get and save initial token
      await _setupToken();
      
      // Set up message handlers
      await _setupMessageHandlers();
      
      print('Push notification service initialized successfully');
    } catch (e) {
      print('Error initializing push notification service: $e');
    }
  }
  
  /// Request notification permissions (iOS specific)
  Future<bool> _requestPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
             settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }
  
  /// Initialize local notifications for foreground messages
  Future<void> _initializeLocalNotifications() async {
    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    
    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
    );
    
    // Create Android notification channel
    if (!kIsWeb && Platform.isAndroid) {
      await _createAndroidNotificationChannels();
    }
  }
  
  /// Create Android notification channels
  Future<void> _createAndroidNotificationChannels() async {
    const vendorChannel = AndroidNotificationChannel(
      'vendor_popups',
      'Vendor Popups',
      description: 'Notifications about your favorite vendor popups',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    const marketChannel = AndroidNotificationChannel(
      'market_reminders',
      'Market Reminders',
      description: 'Reminders about upcoming markets',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    const generalChannel = AndroidNotificationChannel(
      'general',
      'General',
      description: 'General app notifications',
      importance: Importance.defaultImportance,
      playSound: true,
    );
    
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(vendorChannel);
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(marketChannel);
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(generalChannel);
  }
  
  /// Get FCM token and save to user profile
  Future<void> _setupToken() async {
    try {
      // On iOS, add a delay to ensure APNS is registered first
      if (!kIsWeb && Platform.isIOS) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Get initial token with retry for iOS APNS
      String? token = await _getTokenWithRetry();
      if (token != null) {
        await _saveTokenToDatabase(token);
      }

      // Listen for token refresh
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
        _saveTokenToDatabase,
        onError: (error) {
          print('Error on token refresh: $error');
        },
      );
    } catch (e) {
      print('Error setting up FCM token: $e');
    }
  }

  /// Get FCM token with retry logic for iOS APNS
  Future<String?> _getTokenWithRetry({int maxRetries = 3}) async {
    // Skip retries on iOS Simulator since APNS is not available
    if (!kIsWeb && Platform.isIOS) {
      try {
        // Check if running on simulator (APNS not available)
        final token = await _messaging.getToken();
        return token;
      } catch (e) {
        // Silently fail on iOS Simulator APNS errors (expected behavior)
        if (e.toString().contains('APNS')) {
          // This is normal for iOS Simulator - don't spam the console
          return null;
        }
        print('FCM token error: $e');
        return null;
      }
    }

    // For Android and Web, use retry logic
    for (int i = 0; i < maxRetries; i++) {
      try {
        final token = await _messaging.getToken();
        if (token != null) {
          return token;
        }
      } catch (e) {
        if (i == maxRetries - 1) {
          print('Failed to get FCM token after $maxRetries attempts: $e');
        }
      }
    }
    return null;
  }
  
  /// Save FCM token to Firestore user profile
  Future<void> _saveTokenToDatabase(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user to save token for');
        return;
      }

      // Use set with merge:true to create document if it doesn't exist
      await _firestore.collection('user_profiles').doc(user.uid).set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android'),
        'userTimezone': DateTime.now().timeZoneName,
        'userTimezoneOffset': DateTime.now().timeZoneOffset.inHours,
        'notificationPreferences': {
          'enabled': true,
          'vendorPopups': true,
          'marketReminders': true,
          'popupReminders': true,  // NEW: Monday/Thursday popup reminders
          'organizerReminders': true,  // NEW: Market organizer reminders
          'morningTime': '08:00',  // Eastern Time
          'eveningPreview': true,
          'twoHourReminders': true,
          'quietHoursStart': '22:00',  // Eastern Time
          'quietHoursEnd': '07:00',  // Eastern Time
          'timezone': 'America/New_York',  // All times in Eastern
        }
      }, SetOptions(merge: true));

      print('FCM token saved successfully for user: ${user.uid}');
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }
  
  /// Set up message handlers for different app states
  Future<void> _setupMessageHandlers() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    
    // Check if app was opened from notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
    
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  
  /// Handle foreground messages with local notification
  void _handleForegroundMessage(RemoteMessage message) {
    print('Received foreground message: ${message.messageId}');
    
    // Show local notification
    _showLocalNotification(
      title: message.notification?.title ?? 'HiPop Markets',
      body: message.notification?.body ?? '',
      payload: message.data,
    );
  }
  
  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    try {
      // Determine channel based on notification type
      String channelId = 'general';
      if (payload?['type'] == 'vendor_popup') {
        channelId = 'vendor_popups';
      } else if (payload?['type'] == 'market_today' ||
                 payload?['type'] == 'market_reminder' ||
                 payload?['type'] == 'popup_reminder') {
        channelId = 'market_reminders';
      }
      
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == 'vendor_popups' ? 'Vendor Popups' : 
        channelId == 'market_reminders' ? 'Market Reminders' : 'General',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        color: const Color(0xFF558B6E), // HiPopColors.primaryDeepSage
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      // Generate unique notification ID
      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: payload != null ? _encodePayload(payload) : null,
      );
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }
  
  /// Handle notification tap navigation
  void _handleNotificationTap(RemoteMessage message) {
    print('Handling notification tap: ${message.data}');
    
    final data = message.data;
    
    // Log notification opened if tracking
    if (data['notificationId'] != null) {
      _logNotificationOpened(data['notificationId']);
    }
    
    // Navigate based on notification type
    _navigateFromNotification(data);
  }
  
  /// Handle local notification tap
  void _handleLocalNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final data = _decodePayload(response.payload!);
      _navigateFromNotification(data);
    }
  }
  
  /// Navigate based on notification data
  void _navigateFromNotification(Map<String, dynamic> data) {
    if (_router == null) {
      print('Router not available for navigation');
      return;
    }
    
    try {
      switch (data['type']) {
        case 'vendor_popup':
          if (data['vendorId'] != null) {
            _router!.goNamed('vendorDetail', pathParameters: {'vendorId': data['vendorId']});
          }
          break;
          
        case 'market_today':
        case 'market_reminder':
          if (data['marketId'] != null) {
            // For market detail, we need to fetch the market data first
            // For now, navigate to shopper home and show markets
            _router!.go('/');
          }
          break;

        case 'popup_reminder':
          // Navigate to vendor dashboard to create popup posts
          _router!.go('/vendor/dashboard');
          break;

        case 'popup_starting':
          if (data['postId'] != null) {
            // Navigate to vendor posts list - vendor post detail needs the object
            _router!.go('/');
          }
          break;

        case 'tomorrow_preview':
          _router!.goNamed('favorites');
          break;
          
        default:
          // Navigate to home for unknown types
          _router!.go('/');
      }
    } catch (e) {
      print('Error navigating from notification: $e');
    }
  }
  
  /// Log notification opened for analytics
  Future<void> _logNotificationOpened(String notificationId) async {
    try {
      await _firestore.collection('notification_logs').doc(notificationId).update({
        'opened': true,
        'openedAt': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android'),
      });
    } catch (e) {
      debugPrint('Error logging notification opened: $e');
    }
  }

  /// Log notification engagement for tracking
  Future<void> logNotificationEngagement({
    required String notificationId,
    required String userId,
    required String action, // 'opened', 'dismissed', 'clicked'
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('notification_engagement').add({
        'notificationId': notificationId,
        'userId': userId,
        'action': action,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android'),
        'appVersion': 'flutter', // Could be pulled from package_info
      });
    } catch (e) {
      debugPrint('Error logging notification engagement: $e');
    }
  }
  
  /// Update notification preferences
  Future<void> updatePreferences(Map<String, dynamic> preferences) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Use set with merge to ensure document exists
      await _firestore.collection('user_profiles').doc(user.uid).set({
        'notificationPreferences': preferences,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating notification preferences: $e');
    }
  }
  
  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
  
  /// Request to enable notifications if disabled
  Future<bool> requestEnableNotifications() async {
    return await _requestPermissions();
  }
  
  /// Clear token on logout
  Future<void> clearToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('user_profiles').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
          'lastTokenUpdate': FieldValue.delete(),
        });
      }
      
      // Delete token from FCM
      await _messaging.deleteToken();
      
      // Cancel token refresh subscription
      _tokenRefreshSubscription?.cancel();
    } catch (e) {
      debugPrint('Error clearing FCM token: $e');
    }
  }
  
  /// Subscribe to topic for batch notifications
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }
  
  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }
  
  /// Encode payload for local notifications
  String _encodePayload(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}:${e.value}').join('|');
  }
  
  /// Decode payload from local notifications
  Map<String, dynamic> _decodePayload(String payload) {
    final Map<String, dynamic> data = {};
    final parts = payload.split('|');
    for (final part in parts) {
      final keyValue = part.split(':');
      if (keyValue.length == 2) {
        data[keyValue[0]] = keyValue[1];
      }
    }
    return data;
  }
  
  /// Dispose of resources
  void dispose() {
    _tokenRefreshSubscription?.cancel();
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
  
  // Initialize Firebase if needed
  // Note: Don't initialize the full app here, just handle the message
  
  // You can store the message for later processing or show a notification
  // The actual navigation will happen when the user taps the notification
}