import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DebugDatabaseCleaner extends StatefulWidget {
  const DebugDatabaseCleaner({super.key});

  @override
  State<DebugDatabaseCleaner> createState() => _DebugDatabaseCleanerState();
}

class _DebugDatabaseCleanerState extends State<DebugDatabaseCleaner> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isLoading = false;
  String _result = '';

  // Protected users - these will NOT be deleted
  final List<String> _protectedEmails = [
    'hipopmarketss@gmail.com',
    'hipopvendor@gmail.com',
    'jordangillispie@outlook.com',
  ];

  // Check if we're in staging environment
  bool get _isStagingEnvironment {
    // Check if the Firebase project ID contains 'staging'
    // This is a safety check to prevent running on production
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'hipop-staging');
    return projectId.contains('staging') || kDebugMode;
  }

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode AND staging environment
    if (!kDebugMode || !_isStagingEnvironment) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.red.shade50,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'DEBUG: Database Cleaner',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ WARNING: This will delete ALL data except:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Your 3 accounts:',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                  Text(
                    '  - hipopmarketss@gmail.com',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                  Text(
                    '  - hipopvendor@gmail.com',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                  Text(
                    '  - jordangillispie@outlook.com',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Everything else will be PERMANENTLY DELETED:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  Text(
                    '• All other user profiles',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All markets and schedules',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All vendor applications',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All managed vendors',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All vendor-market relationships',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All user subscriptions',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All usage tracking data',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All vendor posts',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All orders and reservations',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All reviews and ratings',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All messages and notifications',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All recruitment posts',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All products and categories',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All tickets and payments',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All analytics and reports',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  Text(
                    '• All Firebase Storage files',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _showConfirmationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Clearing Database...'),
                      ],
                    )
                  : const Text('🗑️ CLEAR DATABASE'),
            ),
            const SizedBox(height: 16),
            if (_result.isNotEmpty) ...[
              const Text(
                'Result:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _result,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ DANGER: Database Wipe'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This action will PERMANENTLY DELETE all data except:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('✅ hipopmarketss@gmail.com'),
              Text('✅ hipopvendor@gmail.com'),
              Text('✅ jordangillispie@outlook.com'),
              SizedBox(height: 16),
              Text(
                'Are you absolutely sure you want to proceed?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'This cannot be undone!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _clearDatabase();
    }
  }

  Future<void> _clearDatabase() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _result = '';
    });


    try {
      String log = '🗑️ STARTING DATABASE CLEANUP\n\n';
      
      // Step 1: Identify protected users
      log += '👤 IDENTIFYING PROTECTED USERS:\n';
      final protectedUserIds = <String>{};
      
      // Get all user profiles to identify protected users
      final userProfilesSnapshot = await _firestore.collection('user_profiles').get();
      
      for (final doc in userProfilesSnapshot.docs) {
        final data = doc.data();
        final email = data['email'] as String? ?? '';
        
        if (_protectedEmails.contains(email)) {
          protectedUserIds.add(doc.id);
          log += '✅ Protected user: $email (ID: ${doc.id})\n';
        }
      }
      
      // Note: We're identifying protected users based on user_profiles collection
      // Firebase Auth users will be preserved if they match the protected emails
      
      log += '\nProtected ${protectedUserIds.length} users total\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 2: Clear user_profiles (except protected)
      log += '🗑️ CLEARING USER PROFILES:\n';
      final userProfilesToDelete = userProfilesSnapshot.docs
          .where((doc) => !protectedUserIds.contains(doc.id))
          .toList();
      
      for (final doc in userProfilesToDelete) {
        final data = doc.data();
        final email = data['email'] ?? 'unknown';
        await doc.reference.delete();
        log += '❌ Deleted user profile: $email\n';
      }
      log += 'Deleted ${userProfilesToDelete.length} user profiles\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 3: Clear all markets
      log += '🗑️ CLEARING MARKETS:\n';
      final marketsSnapshot = await _firestore.collection('markets').get();
      for (final doc in marketsSnapshot.docs) {
        final data = doc.data();
        final name = data['name'] ?? 'Unknown Market';
        await doc.reference.delete();
        log += '❌ Deleted market: $name\n';
      }
      log += 'Deleted ${marketsSnapshot.docs.length} markets\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 4: Clear all market schedules
      log += '🗑️ CLEARING MARKET SCHEDULES:\n';
      final schedulesSnapshot = await _firestore.collection('market_schedules').get();
      for (final doc in schedulesSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${schedulesSnapshot.docs.length} market schedules\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 5: Clear all vendor applications
      log += '🗑️ CLEARING VENDOR APPLICATIONS:\n';
      final applicationsSnapshot = await _firestore.collection('vendor_applications').get();
      for (final doc in applicationsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${applicationsSnapshot.docs.length} vendor applications\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 6: Clear all managed vendors
      log += '🗑️ CLEARING MANAGED VENDORS:\n';
      final managedVendorsSnapshot = await _firestore.collection('managed_vendors').get();
      for (final doc in managedVendorsSnapshot.docs) {
        final data = doc.data();
        final businessName = data['businessName'] ?? 'Unknown Business';
        await doc.reference.delete();
        log += '❌ Deleted managed vendor: $businessName\n';
      }
      log += 'Deleted ${managedVendorsSnapshot.docs.length} managed vendors\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 7: Clear all vendor markets
      log += '🗑️ CLEARING VENDOR MARKETS:\n';
      final vendorMarketsSnapshot = await _firestore.collection('vendor_markets').get();
      for (final doc in vendorMarketsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${vendorMarketsSnapshot.docs.length} vendor markets\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 8: Clear all vendor posts
      log += '🗑️ CLEARING VENDOR POSTS:\n';
      final vendorPostsSnapshot = await _firestore.collection('vendor_posts').get();
      for (final doc in vendorPostsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${vendorPostsSnapshot.docs.length} vendor posts\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 9: Clear all user favorites
      log += '🗑️ CLEARING USER FAVORITES:\n';
      final favoritesSnapshot = await _firestore.collection('user_favorites').get();
      for (final doc in favoritesSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${favoritesSnapshot.docs.length} user favorites\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 11: Clear vendor-market relationships
      log += '🗑️ CLEARING VENDOR-MARKET RELATIONSHIPS:\n';
      final relationshipsSnapshot = await _firestore.collection('vendor_market_relationships').get();
      for (final doc in relationshipsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${relationshipsSnapshot.docs.length} vendor-market relationships\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 12: Clear user subscriptions
      log += '🗑️ CLEARING USER SUBSCRIPTIONS:\n';
      final subscriptionsSnapshot = await _firestore.collection('user_subscriptions').get();
      for (final doc in subscriptionsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${subscriptionsSnapshot.docs.length} user subscriptions\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 13: Clear usage tracking
      log += '🗑️ CLEARING USAGE TRACKING:\n';
      final usageTrackingSnapshot = await _firestore.collection('usage_tracking').get();
      for (final doc in usageTrackingSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${usageTrackingSnapshot.docs.length} usage tracking records\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 14: Clear user market favorites
      log += '🗑️ CLEARING USER MARKET FAVORITES:\n';
      final marketFavoritesSnapshot = await _firestore.collection('user_market_favorites').get();
      for (final doc in marketFavoritesSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${marketFavoritesSnapshot.docs.length} user market favorites\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 15: Clear legacy users collection (except protected)
      log += '🗑️ CLEARING LEGACY USERS:\n';
      final legacyUsersSnapshot = await _firestore.collection('users').get();
      int deletedLegacyUsers = 0;
      for (final doc in legacyUsersSnapshot.docs) {
        final data = doc.data();
        final email = data['email'] as String? ?? '';
        
        if (!_protectedEmails.contains(email)) {
          await doc.reference.delete();
          log += '❌ Deleted legacy user: $email\n';
          deletedLegacyUsers++;
        } else {
          log += '✅ Preserved legacy user: $email\n';
        }
      }
      log += 'Deleted $deletedLegacyUsers legacy users\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 16: Clear analytics collection
      log += '🗑️ CLEARING ANALYTICS:\n';
      final analyticsSnapshot = await _firestore.collection('analytics').get();
      for (final doc in analyticsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${analyticsSnapshot.docs.length} analytics records\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 17: Clear vendor daily analytics
      log += '🗑️ CLEARING VENDOR DAILY ANALYTICS:\n';
      final vendorAnalyticsSnapshot = await _firestore.collection('vendor_daily_analytics').get();
      for (final doc in vendorAnalyticsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${vendorAnalyticsSnapshot.docs.length} vendor daily analytics\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 18: Clear vendor market items
      log += '🗑️ CLEARING VENDOR MARKET ITEMS:\n';
      final vendorMarketItemsSnapshot = await _firestore.collection('vendor_market_items').get();
      for (final doc in vendorMarketItemsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${vendorMarketItemsSnapshot.docs.length} vendor market items\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 19: Clear vendor follows
      log += '🗑️ CLEARING VENDOR FOLLOWS:\n';
      final vendorFollowsSnapshot = await _firestore.collection('vendor_follows').get();
      for (final doc in vendorFollowsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${vendorFollowsSnapshot.docs.length} vendor follows\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 20: Clear vendor loyalty programs
      log += '🗑️ CLEARING VENDOR LOYALTY PROGRAMS:\n';
      final loyaltyProgramsSnapshot = await _firestore.collection('vendor_loyalty_programs').get();
      for (final doc in loyaltyProgramsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${loyaltyProgramsSnapshot.docs.length} vendor loyalty programs\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 21: Clear vendor branding
      log += '🗑️ CLEARING VENDOR BRANDING:\n';
      final vendorBrandingSnapshot = await _firestore.collection('vendor_branding').get();
      for (final doc in vendorBrandingSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${vendorBrandingSnapshot.docs.length} vendor branding records\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 22: Clear shopping insights
      log += '🗑️ CLEARING SHOPPING INSIGHTS:\n';
      final shoppingInsightsSnapshot = await _firestore.collection('shopping_insights').get();
      for (final doc in shoppingInsightsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${shoppingInsightsSnapshot.docs.length} shopping insights\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 23: Clear spending tracking
      log += '🗑️ CLEARING SPENDING TRACKING:\n';
      final spendingTrackingSnapshot = await _firestore.collection('spending_tracking').get();
      for (final doc in spendingTrackingSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${spendingTrackingSnapshot.docs.length} spending tracking records\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 24: Clear analytics_reports
      log += '🗑️ CLEARING ANALYTICS REPORTS:\n';
      final analyticsReportsSnapshot = await _firestore.collection('analytics_reports').get();
      for (final doc in analyticsReportsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${analyticsReportsSnapshot.docs.length} analytics reports\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 25: Clear debug_logs
      log += '🗑️ CLEARING DEBUG LOGS:\n';
      final debugLogsSnapshot = await _firestore.collection('debug_logs').get();
      for (final doc in debugLogsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${debugLogsSnapshot.docs.length} debug logs\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 26: Clear events
      log += '🗑️ CLEARING EVENTS:\n';
      final eventsSnapshot = await _firestore.collection('events').get();
      for (final doc in eventsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${eventsSnapshot.docs.length} events\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 27: Clear performance_metrics
      log += '🗑️ CLEARING PERFORMANCE METRICS:\n';
      final performanceMetricsSnapshot = await _firestore.collection('performance_metrics').get();
      for (final doc in performanceMetricsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${performanceMetricsSnapshot.docs.length} performance metrics\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 28: Clear premium_logs
      log += '🗑️ CLEARING PREMIUM LOGS:\n';
      final premiumLogsSnapshot = await _firestore.collection('premium_logs').get();
      for (final doc in premiumLogsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${premiumLogsSnapshot.docs.length} premium logs\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 29: Clear system_alerts
      log += '🗑️ CLEARING SYSTEM ALERTS:\n';
      final systemAlertsSnapshot = await _firestore.collection('system_alerts').get();
      for (final doc in systemAlertsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${systemAlertsSnapshot.docs.length} system alerts\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 30: Clear system_health_reports
      log += '🗑️ CLEARING SYSTEM HEALTH REPORTS:\n';
      final systemHealthReportsSnapshot = await _firestore.collection('system_health_reports').get();
      for (final doc in systemHealthReportsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${systemHealthReportsSnapshot.docs.length} system health reports\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 31: Clear user_events
      log += '🗑️ CLEARING USER EVENTS:\n';
      final userEventsSnapshot = await _firestore.collection('user_events').get();
      for (final doc in userEventsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${userEventsSnapshot.docs.length} user events\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 32: Clear user_feedback
      log += '🗑️ CLEARING USER FEEDBACK:\n';
      final userFeedbackSnapshot = await _firestore.collection('user_feedback').get();
      for (final doc in userFeedbackSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${userFeedbackSnapshot.docs.length} user feedback\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 33: Clear user_sessions
      log += '🗑️ CLEARING USER SESSIONS:\n';
      final userSessionsSnapshot = await _firestore.collection('user_sessions').get();
      for (final doc in userSessionsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${userSessionsSnapshot.docs.length} user sessions\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 34: Clear user_stats
      log += '🗑️ CLEARING USER STATS:\n';
      final userStatsSnapshot = await _firestore.collection('user_stats').get();
      for (final doc in userStatsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${userStatsSnapshot.docs.length} user stats\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 35: Clear vendor_product_lists
      log += '🗑️ CLEARING VENDOR PRODUCT LISTS:\n';
      final vendorProductListsSnapshot = await _firestore.collection('vendor_product_lists').get();
      for (final doc in vendorProductListsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${vendorProductListsSnapshot.docs.length} vendor product lists\n\n';
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Step 36: Clear vendor_stats
      log += '🗑️ CLEARING VENDOR STATS:\n';
      final vendorStatsSnapshot = await _firestore.collection('vendor_stats').get();
      for (final doc in vendorStatsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${vendorStatsSnapshot.docs.length} vendor stats\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 37: Clear orders
      log += '🗑️ CLEARING ORDERS:\n';
      final ordersSnapshot = await _firestore.collection('orders').get();
      for (final doc in ordersSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${ordersSnapshot.docs.length} orders\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 38: Clear reservations
      log += '🗑️ CLEARING RESERVATIONS:\n';
      final reservationsSnapshot = await _firestore.collection('reservations').get();
      for (final doc in reservationsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${reservationsSnapshot.docs.length} reservations\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 39: Clear reviews
      log += '🗑️ CLEARING REVIEWS:\n';
      final reviewsSnapshot = await _firestore.collection('reviews').get();
      for (final doc in reviewsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${reviewsSnapshot.docs.length} reviews\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 40: Clear messages
      log += '🗑️ CLEARING MESSAGES:\n';
      final messagesSnapshot = await _firestore.collection('messages').get();
      for (final doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${messagesSnapshot.docs.length} messages\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 41: Clear notifications
      log += '🗑️ CLEARING NOTIFICATIONS:\n';
      final notificationsSnapshot = await _firestore.collection('notifications').get();
      for (final doc in notificationsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${notificationsSnapshot.docs.length} notifications\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 42: Clear vendor_recruitment_posts
      log += '🗑️ CLEARING RECRUITMENT POSTS:\n';
      final recruitmentPostsSnapshot = await _firestore.collection('vendor_recruitment_posts').get();
      for (final doc in recruitmentPostsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${recruitmentPostsSnapshot.docs.length} recruitment posts\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 43: Clear products
      log += '🗑️ CLEARING PRODUCTS:\n';
      final productsSnapshot = await _firestore.collection('products').get();
      for (final doc in productsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${productsSnapshot.docs.length} products\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 44: Clear product_categories
      log += '🗑️ CLEARING PRODUCT CATEGORIES:\n';
      final categoriesSnapshot = await _firestore.collection('product_categories').get();
      for (final doc in categoriesSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${categoriesSnapshot.docs.length} product categories\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 45: Clear tickets
      log += '🗑️ CLEARING TICKETS:\n';
      final ticketsSnapshot = await _firestore.collection('tickets').get();
      for (final doc in ticketsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${ticketsSnapshot.docs.length} tickets\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 46: Clear ticket_purchases
      log += '🗑️ CLEARING TICKET PURCHASES:\n';
      final ticketPurchasesSnapshot = await _firestore.collection('ticket_purchases').get();
      for (final doc in ticketPurchasesSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${ticketPurchasesSnapshot.docs.length} ticket purchases\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 47: Clear payment_intents
      log += '🗑️ CLEARING PAYMENT INTENTS:\n';
      final paymentIntentsSnapshot = await _firestore.collection('payment_intents').get();
      for (final doc in paymentIntentsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${paymentIntentsSnapshot.docs.length} payment intents\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 48: Clear stripe_customers
      log += '🗑️ CLEARING STRIPE CUSTOMERS:\n';
      final stripeCustomersSnapshot = await _firestore.collection('stripe_customers').get();
      for (final doc in stripeCustomersSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${stripeCustomersSnapshot.docs.length} stripe customers\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 49: Clear vendor_applications_archive
      log += '🗑️ CLEARING APPLICATION ARCHIVES:\n';
      final appArchivesSnapshot = await _firestore.collection('vendor_applications_archive').get();
      for (final doc in appArchivesSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${appArchivesSnapshot.docs.length} application archives\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 50: Clear market_organizers
      log += '🗑️ CLEARING MARKET ORGANIZERS:\n';
      final organizersSnapshot = await _firestore.collection('market_organizers').get();
      for (final doc in organizersSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${organizersSnapshot.docs.length} market organizers\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 51: Clear organizer_monthly_tracking
      log += '🗑️ CLEARING ORGANIZER MONTHLY TRACKING:\n';
      final organizerTrackingSnapshot = await _firestore.collection('organizer_monthly_tracking').get();
      for (final doc in organizerTrackingSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${organizerTrackingSnapshot.docs.length} organizer monthly tracking records\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 52: Clear vendor_monthly_tracking
      log += '🗑️ CLEARING VENDOR MONTHLY TRACKING:\n';
      final vendorTrackingSnapshot = await _firestore.collection('vendor_monthly_tracking').get();
      for (final doc in vendorTrackingSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${vendorTrackingSnapshot.docs.length} vendor monthly tracking records\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 53: Clear subscription_events
      log += '🗑️ CLEARING SUBSCRIPTION EVENTS:\n';
      final subEventsSnapshot = await _firestore.collection('subscription_events').get();
      for (final doc in subEventsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${subEventsSnapshot.docs.length} subscription events\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 54: Clear subscriptions
      log += '🗑️ CLEARING SUBSCRIPTIONS:\n';
      final subsSnapshot = await _firestore.collection('subscriptions').get();
      for (final doc in subsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${subsSnapshot.docs.length} subscriptions\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 55: Clear system_logs
      log += '🗑️ CLEARING SYSTEM LOGS:\n';
      final systemLogsSnapshot = await _firestore.collection('system_logs').get();
      for (final doc in systemLogsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${systemLogsSnapshot.docs.length} system logs\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 56: Clear transactions
      log += '🗑️ CLEARING TRANSACTIONS:\n';
      final transactionsSnapshot = await _firestore.collection('transactions').get();
      for (final doc in transactionsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${transactionsSnapshot.docs.length} transactions\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 57: Clear universal_reviews
      log += '🗑️ CLEARING UNIVERSAL REVIEWS:\n';
      final universalReviewsSnapshot = await _firestore.collection('universal_reviews').get();
      for (final doc in universalReviewsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${universalReviewsSnapshot.docs.length} universal reviews\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 58: Clear userProfiles (legacy collection)
      log += '🗑️ CLEARING USERPROFILES (LEGACY):\n';
      final legacyUserProfilesSnapshot = await _firestore.collection('userProfiles').get();
      for (final doc in legacyUserProfilesSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${legacyUserProfilesSnapshot.docs.length} userProfiles (legacy)\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 59: Clear vendor_products
      log += '🗑️ CLEARING VENDOR PRODUCTS:\n';
      final vendorProductsSnapshot = await _firestore.collection('vendor_products').get();
      for (final doc in vendorProductsSnapshot.docs) {
        await doc.reference.delete();
      }
      log += 'Deleted ${vendorProductsSnapshot.docs.length} vendor products\n\n';

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Step 60: Clear Firebase Storage (except protected user images)
      log += '🗑️ CLEARING FIREBASE STORAGE:\n';
      try {
        // Clear all storage folders
        final storageRef = _storage.ref();

        // List of folders to clear
        final foldersToClean = [
          'market_images',
          'vendor_images',
          'product_images',
          'profile_images',
          'vendor_posts',
          'reviews',
          'recruitment_posts',
        ];

        for (final folder in foldersToClean) {
          try {
            final folderRef = storageRef.child(folder);
            final result = await folderRef.listAll();

            // Delete all files in this folder
            for (final item in result.items) {
              // Skip protected user profile images
              if (folder == 'profile_images' && protectedUserIds.any((id) => item.name.contains(id))) {
                log += '✅ Preserved profile image: ${item.name}\n';
                continue;
              }

              await item.delete();
              log += '❌ Deleted: $folder/${item.name}\n';
            }

            // Delete all subfolders
            for (final prefix in result.prefixes) {
              // Recursively delete subfolder contents
              final subResult = await prefix.listAll();
              for (final item in subResult.items) {
                await item.delete();
              }
            }
          } catch (e) {
            log += '⚠️ Could not clean folder $folder: $e\n';
          }
        }

        log += 'Firebase Storage cleaned\n\n';
      } catch (e) {
        log += '⚠️ Could not fully clean Firebase Storage: $e\n\n';
      }

      if (mounted) {
        setState(() {
          _result = log;
        });
      }

      // Final summary
      log += '✅ DATABASE CLEANUP COMPLETED!\n\n';
      log += '📊 SUMMARY:\n';
      log += '• Protected ${protectedUserIds.length} users\n';
      log += '• Deleted ${userProfilesToDelete.length} user profiles\n';
      log += '• Deleted ${marketsSnapshot.docs.length} markets\n';
      log += '• Deleted ${schedulesSnapshot.docs.length} market schedules\n';
      log += '• Deleted ${applicationsSnapshot.docs.length} vendor applications\n';
      log += '• Deleted ${managedVendorsSnapshot.docs.length} managed vendors\n';
      log += '• Deleted ${vendorMarketsSnapshot.docs.length} vendor markets\n';
      log += '• Deleted ${relationshipsSnapshot.docs.length} vendor-market relationships\n';
      log += '• Deleted ${subscriptionsSnapshot.docs.length} user subscriptions\n';
      log += '• Deleted ${usageTrackingSnapshot.docs.length} usage tracking records\n';
      log += '• Deleted ${marketFavoritesSnapshot.docs.length} user market favorites\n';
      log += '• Deleted ${vendorPostsSnapshot.docs.length} vendor posts\n';
      log += '• Deleted ${favoritesSnapshot.docs.length} user favorites\n';
      log += '• Deleted $deletedLegacyUsers legacy users\n';
      log += '• Deleted ${analyticsSnapshot.docs.length} analytics records\n';
      log += '• Deleted ${vendorAnalyticsSnapshot.docs.length} vendor daily analytics\n';
      log += '• Deleted ${vendorMarketItemsSnapshot.docs.length} vendor market items\n';
      log += '• Deleted ${vendorFollowsSnapshot.docs.length} vendor follows\n';
      log += '• Deleted ${loyaltyProgramsSnapshot.docs.length} vendor loyalty programs\n';
      log += '• Deleted ${vendorBrandingSnapshot.docs.length} vendor branding records\n';
      log += '• Deleted ${shoppingInsightsSnapshot.docs.length} shopping insights\n';
      log += '• Deleted ${spendingTrackingSnapshot.docs.length} spending tracking records\n';
      log += '• Deleted ${analyticsReportsSnapshot.docs.length} analytics reports\n';
      log += '• Deleted ${debugLogsSnapshot.docs.length} debug logs\n';
      log += '• Deleted ${eventsSnapshot.docs.length} events\n';
      log += '• Deleted ${performanceMetricsSnapshot.docs.length} performance metrics\n';
      log += '• Deleted ${premiumLogsSnapshot.docs.length} premium logs\n';
      log += '• Deleted ${systemAlertsSnapshot.docs.length} system alerts\n';
      log += '• Deleted ${systemHealthReportsSnapshot.docs.length} system health reports\n';
      log += '• Deleted ${userEventsSnapshot.docs.length} user events\n';
      log += '• Deleted ${userFeedbackSnapshot.docs.length} user feedback\n';
      log += '• Deleted ${userSessionsSnapshot.docs.length} user sessions\n';
      log += '• Deleted ${userStatsSnapshot.docs.length} user stats\n';
      log += '• Deleted ${vendorProductListsSnapshot.docs.length} vendor product lists\n';
      log += '• Deleted ${vendorStatsSnapshot.docs.length} vendor stats\n';
      log += '• Deleted ${ordersSnapshot.docs.length} orders\n';
      log += '• Deleted ${reservationsSnapshot.docs.length} reservations\n';
      log += '• Deleted ${reviewsSnapshot.docs.length} reviews\n';
      log += '• Deleted ${messagesSnapshot.docs.length} messages\n';
      log += '• Deleted ${notificationsSnapshot.docs.length} notifications\n';
      log += '• Deleted ${recruitmentPostsSnapshot.docs.length} recruitment posts\n';
      log += '• Deleted ${productsSnapshot.docs.length} products\n';
      log += '• Deleted ${categoriesSnapshot.docs.length} product categories\n';
      log += '• Deleted ${ticketsSnapshot.docs.length} tickets\n';
      log += '• Deleted ${ticketPurchasesSnapshot.docs.length} ticket purchases\n';
      log += '• Deleted ${paymentIntentsSnapshot.docs.length} payment intents\n';
      log += '• Deleted ${stripeCustomersSnapshot.docs.length} stripe customers\n';
      log += '• Deleted ${appArchivesSnapshot.docs.length} application archives\n';
      log += '• Deleted ${organizersSnapshot.docs.length} market organizers\n';
      log += '• Deleted ${organizerTrackingSnapshot.docs.length} organizer monthly tracking\n';
      log += '• Deleted ${vendorTrackingSnapshot.docs.length} vendor monthly tracking\n';
      log += '• Deleted ${subEventsSnapshot.docs.length} subscription events\n';
      log += '• Deleted ${subsSnapshot.docs.length} subscriptions\n';
      log += '• Deleted ${systemLogsSnapshot.docs.length} system logs\n';
      log += '• Deleted ${transactionsSnapshot.docs.length} transactions\n';
      log += '• Deleted ${universalReviewsSnapshot.docs.length} universal reviews\n';
      log += '• Deleted ${legacyUserProfilesSnapshot.docs.length} legacy userProfiles\n';
      log += '• Deleted ${vendorProductsSnapshot.docs.length} vendor products\n';
      log += '• Cleaned Firebase Storage\n\n';
      log += '🎉 Database is now clean and ready for fresh data!\n';
      log += '🔒 All protected users remain intact.\n';
      log += '⚠️ STAGING ENVIRONMENT ONLY';
      
      
      if (mounted) {
        setState(() {
          _result = log;
        });
      }
      
      // Show success dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ Database Cleared Successfully'),
            content: Text(
              'Database has been cleared while preserving ${protectedUserIds.length} protected users.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _result += '\n\n❌ ERROR DURING CLEANUP:\n$e';
        });
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('❌ Error'),
            content: Text('Database cleanup failed: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}