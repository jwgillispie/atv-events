import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import 'package:atv_events/blocs/auth/auth_event.dart';
import 'package:atv_events/core/services/premium_access_service.dart';

/// Debug widget to activate premium for testing
/// Only shows in debug mode and for debug accounts
class DebugPremiumActivator extends StatefulWidget {
  const DebugPremiumActivator({super.key});

  @override
  State<DebugPremiumActivator> createState() => _DebugPremiumActivatorState();
}

class _DebugPremiumActivatorState extends State<DebugPremiumActivator> {
  bool _isActivating = false;

  Future<void> _activatePremium(String userId, String userType) async {
    setState(() => _isActivating = true);

    try {
      debugPrint('🔵 [DEBUG PREMIUM] Starting activation...');
      debugPrint('🔵 [DEBUG PREMIUM] userId: $userId');
      debugPrint('🔵 [DEBUG PREMIUM] userType: $userType');

      final firestore = FirebaseFirestore.instance;

      // Determine tier based on user type
      String tier;
      Map<String, dynamic> features;

      if (userType == 'vendor') {
        tier = 'vendorPremium';
        features = {
          // Vendor Premium Features
          'market_discovery': true,
          'full_vendor_analytics': true,
          'product_performance_analytics': true,
          'customer_acquisition_analysis': true,
          'sales_forecasting': true,
          'pricing_recommendations': true,
          'profit_optimization': true,
          'market_expansion_recommendations': true,
          'seasonal_business_planning': true,
          'weather_correlation_data': true,
        };
      } else if (userType == 'market_organizer') {
        tier = 'marketOrganizerPremium';
        features = {
          // Market Organizer Premium Features
          'vendor_discovery': true,
          'vendor_directory': true, // ← CRITICAL FOR PAYWALL
          'vendor_recruitment': true, // ← CRITICAL FOR PAYWALL
          'multi_market_management': true,
          'vendor_analytics_dashboard': true,
          'vendor_communication_suite': true,
          'bulk_messaging': true,
          'message_templates': true,
          'communication_analytics': true,
          'financial_reporting': true,
          'vendor_performance_ranking': true,
          'automated_recruitment': true,
          'budget_planning_tools': true,
          'financial_forecasting': true,
          'advanced_market_intelligence': true,
          'vendor_post_creation': true,
          'vendor_post_analytics': true,
          'unlimited_vendor_posts': true,
          'priority_vendor_matching': true,
          'advanced_response_management': true,
          'vendor_recruitment_insights': true,
          'post_performance_tracking': true,
          'vendor_discovery_integration': true,
        };
      } else {
        tier = 'shopperPremium';
        features = {
          'unlimited_favorites': true,
          'advanced_search': true,
          'vendor_messaging': true,
          'exclusive_deals': true,
          'ad_free_experience': true,
          'advanced_filtering': true,
          'market_alerts': true,
          'seasonal_insights': true,
          'recipe_integration': true,
        };
      }

      debugPrint('🔵 [DEBUG PREMIUM] Tier: $tier');
      debugPrint('🔵 [DEBUG PREMIUM] Features: $features');

      // Unlimited limits for premium
      final limits = {
        'market_applications_per_month': -1,
        'photo_uploads_per_post': -1,
        'monthly_posts': -1,
        'monthly_markets': -1,
        'monthly_events': -1,
      };

      // Create/update subscription document - MATCHES EXACTLY what RevenueCat creates
      final subscriptionData = {
        'userId': userId,
        'userType': userType, // CRITICAL: Must include userType
        'tier': tier,
        'status': 'active', // String status
        'isActive': true, // Boolean flag
        'features': features,
        'limits': limits,
        'updatedAt': FieldValue.serverTimestamp(),
        'debugActivated': true, // Mark as debug activation
        'productIdentifier': 'debug_$tier',
        'expirationDate': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
      };

      debugPrint('🔵 [DEBUG PREMIUM] Subscription data: $subscriptionData');

      // Find existing subscription or create new
      debugPrint('🔵 [DEBUG PREMIUM] Querying user_subscriptions collection...');
      final subscriptionQuery = await firestore
          .collection('user_subscriptions')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (subscriptionQuery.docs.isNotEmpty) {
        debugPrint('🔵 [DEBUG PREMIUM] Found existing subscription, updating...');
        final docRef = subscriptionQuery.docs.first.reference;
        await docRef.update(subscriptionData);
        debugPrint('🔵 [DEBUG PREMIUM] Updated subscription doc: ${docRef.id}');
      } else {
        debugPrint('🔵 [DEBUG PREMIUM] No existing subscription, creating new...');
        final docRef = await firestore.collection('user_subscriptions').add({
          ...subscriptionData,
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint('🔵 [DEBUG PREMIUM] Created new subscription doc: ${docRef.id}');
      }

      // Also update subscriptions collection (different path) - for backward compatibility
      debugPrint('🔵 [DEBUG PREMIUM] Updating subscriptions collection...');
      await firestore.collection('subscriptions').doc(userId).set({
        ...subscriptionData,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🔵 [DEBUG PREMIUM] Updated subscriptions/${userId}');

      // Update user profile
      debugPrint('🔵 [DEBUG PREMIUM] Updating user_profiles...');
      await firestore.collection('user_profiles').doc(userId).set({
        'isPremium': true,
        'subscriptionStatus': tier,
        'subscriptionStartDate': FieldValue.serverTimestamp(),
        'subscriptionEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 365))),
        'paymentProvider': 'debug',
        'debugPremium': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('🔵 [DEBUG PREMIUM] Updated user_profiles/${userId}');

      // Clear premium access cache
      debugPrint('🔵 [DEBUG PREMIUM] Clearing cache...');
      PremiumAccessService.clearCache(userId);

      // Reload user to refresh auth state
      debugPrint('🔵 [DEBUG PREMIUM] Reloading auth state...');
      if (mounted) {
        context.read<AuthBloc>().add(ReloadUserEvent());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Premium activated: $tier\n🔄 Refreshing... Check console logs'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Wait for auth reload
      debugPrint('🔵 [DEBUG PREMIUM] Waiting for reload...');
      await Future.delayed(const Duration(seconds: 2));
      debugPrint('🔵 [DEBUG PREMIUM] ✅ ACTIVATION COMPLETE');

      // Verify the data was written
      debugPrint('🔵 [DEBUG PREMIUM] Verifying written data...');
      final verifyQuery = await firestore
          .collection('user_subscriptions')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (verifyQuery.docs.isNotEmpty) {
        final doc = verifyQuery.docs.first;
        debugPrint('🔵 [DEBUG PREMIUM] ✅ Verified user_subscriptions doc exists');
        debugPrint('🔵 [DEBUG PREMIUM] Doc data: ${doc.data()}');
        debugPrint('🔵 [DEBUG PREMIUM] Has vendor_directory: ${doc.data()['features']?['vendor_directory']}');
        debugPrint('🔵 [DEBUG PREMIUM] Has vendor_recruitment: ${doc.data()['features']?['vendor_recruitment']}');
      } else {
        debugPrint('🔵 [DEBUG PREMIUM] ❌ ERROR: Could not verify subscription doc!');
      }
    } catch (e, stackTrace) {
      debugPrint('🔴 [DEBUG PREMIUM] ❌ ERROR: $e');
      debugPrint('🔴 [DEBUG PREMIUM] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to activate premium: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActivating = false);
      }
    }
  }

  Future<void> _deactivatePremium(String userId) async {
    debugPrint('🟠 [DEBUG PREMIUM] DEACTIVATE button pressed - userId: $userId');
    setState(() => _isActivating = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // Update subscription documents
      final subscriptionQuery = await firestore
          .collection('user_subscriptions')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (subscriptionQuery.docs.isNotEmpty) {
        await subscriptionQuery.docs.first.reference.update({
          'tier': 'free',
          'status': 'cancelled',
          'isActive': false,
          'features': {},
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update subscriptions collection
      await firestore.collection('subscriptions').doc(userId).set({
        'tier': 'free',
        'status': 'cancelled',
        'isActive': false,
        'features': {},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update user profile
      await firestore.collection('user_profiles').doc(userId).set({
        'isPremium': false,
        'subscriptionStatus': 'free',
        'subscriptionStartDate': null,
        'subscriptionEndDate': null,
        'paymentProvider': null,
        'debugPremium': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Clear premium access cache
      PremiumAccessService.clearCache(userId);

      // Reload user to refresh auth state
      if (mounted) {
        context.read<AuthBloc>().add(ReloadUserEvent());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Premium deactivated\n🔄 Refreshing...'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Wait for auth reload
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to deactivate: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActivating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode (running via Xcode/Android Studio)
    if (!kDebugMode) return const SizedBox.shrink();

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        debugPrint('🟣 [DEBUG PREMIUM WIDGET] build() called - State type: ${state.runtimeType}');

        // Only show if logged in
        if (state is! Authenticated) {
          debugPrint('🟣 [DEBUG PREMIUM WIDGET] Not authenticated, hiding widget');
          return const SizedBox.shrink();
        }

        final userId = state.user.uid;
        final userType = state.userProfile?.userType ?? 'shopper';
        final isPremium = state.userProfile?.isPremium ?? false;

        debugPrint('🟣 [DEBUG PREMIUM WIDGET] userId: $userId');
        debugPrint('🟣 [DEBUG PREMIUM WIDGET] userType: $userType');
        debugPrint('🟣 [DEBUG PREMIUM WIDGET] isPremium: $isPremium');
        debugPrint('🟣 [DEBUG PREMIUM WIDGET] userProfile: ${state.userProfile}');

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            color: Colors.amber.shade50,
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.diamond, color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'DEBUG: Premium Controls',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current Status: ${isPremium ? "Premium ✓" : "Free"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    'User Type: $userType',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isActivating
                              ? null
                              : () => _activatePremium(userId, userType),
                          icon: _isActivating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.star, size: 18),
                          label: const Text('Activate Premium'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isActivating
                              ? null
                              : () => _deactivatePremium(userId),
                          icon: const Icon(Icons.remove_circle, size: 18),
                          label: const Text('Deactivate'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
