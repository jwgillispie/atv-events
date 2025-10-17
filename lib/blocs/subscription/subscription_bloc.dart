import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../features/premium/models/user_subscription.dart';
import '../../features/premium/services/subscription_service.dart';
import '../../features/premium/services/secure_subscription_service.dart';
import 'subscription_event.dart';
import 'subscription_state.dart';

/// Global BLoC for managing subscription state across the app
/// 
/// This bloc provides:
/// - Real-time subscription status updates via Firestore listeners
/// - Feature access validation with caching
/// - Usage limit tracking and enforcement
/// - Premium feature unlock animations and notifications
/// - Integration with Stripe billing and payment status
class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  // ignore: unused_field
  static const String _logPrefix = '🔔 SUBSCRIPTION_BLOC:';
  
  // Services removed as they are now accessed statically
  final FirebaseFirestore _firestore;
  
  // Real-time subscription stream
  StreamSubscription<UserSubscription?>? _subscriptionStreamSubscription;
  
  // Cache for feature access and limits
  final Map<String, bool> _featureAccessCache = {};
  final Map<String, int> _usageLimitsCache = {};
  final Map<String, dynamic> _currentUsageCache = {};
  
  // Expiration and billing issue timers
  Timer? _expirationCheckTimer;
  Timer? _billingIssueCheckTimer;
  
  String? _currentUserId;

  SubscriptionBloc({
    FirebaseFirestore? firestore,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        super(const SubscriptionInitial()) {

    // Register event handlers
    on<SubscriptionInitialized>(_onSubscriptionInitialized);
    on<SubscriptionChanged>(_onSubscriptionChanged);
    on<SubscriptionUpgraded>(_onSubscriptionUpgraded);
    on<SubscriptionCancelled>(_onSubscriptionCancelled);
    on<FeatureAccessRequested>(_onFeatureAccessRequested);
    on<UsageLimitRequested>(_onUsageLimitRequested);
    on<PaymentInfoUpdated>(_onPaymentInfoUpdated);
    on<SubscriptionRefreshed>(_onSubscriptionRefreshed);
    on<SubscriptionErrorOccurred>(_onSubscriptionErrorOccurred);
    on<SubscriptionErrorCleared>(_onSubscriptionErrorCleared);
    on<SubscriptionPreloaded>(_onSubscriptionPreloaded);
    on<UpgradeRecommendationsRequested>(_onUpgradeRecommendationsRequested);
    on<FeatureUsageTracked>(_onFeatureUsageTracked);
    on<SubscriptionIssuesRequested>(_onSubscriptionIssuesRequested);
  }

  /// Initialize subscription monitoring for a user
  Future<void> _onSubscriptionInitialized(
    SubscriptionInitialized event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      _currentUserId = event.userId;
      
      emit(const SubscriptionLoading(message: 'Loading subscription data...'));
      
      // Cancel any existing subscription
      await _subscriptionStreamSubscription?.cancel();
      
      // Set up real-time subscription listener
      _subscriptionStreamSubscription = SubscriptionService
          .streamUserSubscription(event.userId)
          .listen(
            (subscription) {
              add(SubscriptionChanged(subscription));
            },
            onError: (error) {
              add(SubscriptionErrorOccurred(error.toString()));
            },
          );

      // Start monitoring timers
      _startExpirationMonitoring();
      _startBillingIssueMonitoring();
      
      
    } catch (e) {
      emit(SubscriptionError(message: 'Failed to initialize subscription: $e'));
    }
  }

  /// Handle subscription data changes from Firestore
  Future<void> _onSubscriptionChanged(
    SubscriptionChanged event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      final subscription = event.subscription;
      
      if (subscription == null) {
        emit(const SubscriptionError(message: 'No subscription found'));
        return;
      }

      
      // Clear caches when subscription changes
      _clearCaches();
      
      // Load additional data for complete state
      final featureAccess = await _loadFeatureAccess(subscription);
      final usageLimits = await _loadUsageLimits(subscription);
      final currentUsage = await _loadCurrentUsage(subscription);
      
      // Check for subscription status issues
      await _checkSubscriptionIssues(subscription, emit);
      
      // Emit loaded state with all data
      emit(SubscriptionLoaded(
        subscription: subscription,
        featureAccess: featureAccess,
        usageLimits: usageLimits,
        currentUsage: currentUsage,
      ));
      
      
    } catch (e) {
      emit(SubscriptionError(
        message: 'Failed to process subscription change: $e',
        subscription: event.subscription,
      ));
    }
  }

  /// Handle subscription upgrade
  Future<void> _onSubscriptionUpgraded(
    SubscriptionUpgraded event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      if (_currentUserId == null) {
        emit(const SubscriptionError(message: 'No user ID available for upgrade'));
        return;
      }

      
      // Get current subscription for previous tier tracking
      final currentState = state;
      final currentSubscription = currentState is SubscriptionLoaded 
          ? currentState.subscription 
          : null;
      
      emit(SubscriptionUpgrading(
        targetTier: event.tier,
        currentSubscription: currentSubscription,
      ));

      // Perform the upgrade
      final upgradedSubscription = await SubscriptionService.upgradeToTier(
        _currentUserId!,
        event.tier,
        stripeCustomerId: event.stripeCustomerId,
        stripeSubscriptionId: event.stripeSubscriptionId,
        paymentMethodId: event.paymentMethodId,
        stripePriceId: event.stripePriceId,
      );

      // Clear security caches
      SecureSubscriptionService.invalidateCache(_currentUserId!);
      
      
      // Emit upgrade success state
      emit(SubscriptionUpgradedState(
        subscription: upgradedSubscription,
        previousTier: currentSubscription?.tier ?? SubscriptionTier.free,
      ));
      
      // The subscription stream will update the main state
      
    } catch (e) {
      emit(SubscriptionError(message: 'Failed to upgrade subscription: $e'));
    }
  }

  /// Handle subscription cancellation
  Future<void> _onSubscriptionCancelled(
    SubscriptionCancelled event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      if (_currentUserId == null) {
        emit(const SubscriptionError(message: 'No user ID available for cancellation'));
        return;
      }

      
      // Get current subscription
      final currentState = state;
      if (currentState is! SubscriptionLoaded) {
        emit(const SubscriptionError(message: 'No active subscription to cancel'));
        return;
      }
      
      emit(SubscriptionCancelling(currentState.subscription));

      // Perform the cancellation
      final cancelledSubscription = await SubscriptionService.cancelSubscription(_currentUserId!);
      
      // Clear security caches
      SecureSubscriptionService.invalidateCache(_currentUserId!);
      
      
      emit(SubscriptionCancelledState(
        subscription: cancelledSubscription,
        cancellationDate: DateTime.now(),
      ));
      
    } catch (e) {
      emit(SubscriptionError(message: 'Failed to cancel subscription: $e'));
    }
  }

  /// Handle feature access requests
  Future<void> _onFeatureAccessRequested(
    FeatureAccessRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      if (_currentUserId == null) {
        emit(const SubscriptionError(message: 'No user ID available for feature check'));
        return;
      }

      
      // Check cache first
      if (_featureAccessCache.containsKey(event.featureName)) {
        final hasAccess = _featureAccessCache[event.featureName]!;
        
        final currentState = state;
        if (currentState is SubscriptionLoaded) {
          emit(FeatureAccessResult(
            featureName: event.featureName,
            hasAccess: hasAccess,
            subscription: currentState.subscription,
          ));
          return;
        }
      }
      
      // Use secure validation service
      final hasAccess = await SecureSubscriptionService.validateFeatureAccess(
        _currentUserId!,
        event.featureName,
      );
      
      // Cache the result
      _featureAccessCache[event.featureName] = hasAccess;
      
      
      final currentState = state;
      if (currentState is SubscriptionLoaded) {
        emit(FeatureAccessResult(
          featureName: event.featureName,
          hasAccess: hasAccess,
          subscription: currentState.subscription,
        ));
      }
      
    } catch (e) {
      emit(SubscriptionError(message: 'Failed to check feature access: $e'));
    }
  }

  /// Handle usage limit requests
  Future<void> _onUsageLimitRequested(
    UsageLimitRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      if (_currentUserId == null) {
        emit(const SubscriptionError(message: 'No user ID available for limit check'));
        return;
      }

      
      // Use secure validation service for critical limits
      final withinLimit = await SecureSubscriptionService.validateUsageLimit(
        _currentUserId!,
        event.limitName,
        event.currentUsage,
      );
      
      // Get the actual limit value
      final limit = await SubscriptionService.getUserLimit(_currentUserId!, event.limitName);
      
      
      final currentState = state;
      if (currentState is SubscriptionLoaded) {
        emit(UsageLimitResult(
          limitName: event.limitName,
          currentUsage: event.currentUsage,
          limit: limit,
          withinLimit: withinLimit,
          subscription: currentState.subscription,
        ));
      }
      
    } catch (e) {
      emit(SubscriptionError(message: 'Failed to check usage limit: $e'));
    }
  }

  /// Handle payment info updates
  Future<void> _onPaymentInfoUpdated(
    PaymentInfoUpdated event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      if (_currentUserId == null) {
        emit(const SubscriptionError(message: 'No user ID available for payment update'));
        return;
      }

      
      final updatedSubscription = await SubscriptionService.updatePaymentInfo(
        _currentUserId!,
        paymentMethodId: event.paymentMethodId,
        stripeCustomerId: event.stripeCustomerId,
        stripeSubscriptionId: event.stripeSubscriptionId,
        nextPaymentDate: event.nextPaymentDate,
      );
      
      
      emit(PaymentInfoUpdatedState(updatedSubscription));
      
    } catch (e) {
      emit(SubscriptionError(message: 'Failed to update payment information: $e'));
    }
  }

  /// Handle subscription refresh requests
  Future<void> _onSubscriptionRefreshed(
    SubscriptionRefreshed event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      if (_currentUserId == null) return;

      
      if (event.forceRefresh) {
        _clearCaches();
        SecureSubscriptionService.invalidateCache(_currentUserId!);
      }
      
      // Re-initialize to trigger fresh data load
      add(SubscriptionInitialized(_currentUserId!));
      
    } catch (e) {
      emit(SubscriptionError(message: 'Failed to refresh subscription: $e'));
    }
  }

  /// Handle subscription errors
  Future<void> _onSubscriptionErrorOccurred(
    SubscriptionErrorOccurred event,
    Emitter<SubscriptionState> emit,
  ) async {
    
    // Try to preserve current subscription data if available
    final currentState = state;
    final currentSubscription = currentState is SubscriptionLoaded 
        ? currentState.subscription 
        : null;
    
    emit(SubscriptionError(
      message: event.error,
      subscription: currentSubscription,
    ));
  }

  /// Clear subscription errors
  Future<void> _onSubscriptionErrorCleared(
    SubscriptionErrorCleared event,
    Emitter<SubscriptionState> emit,
  ) async {
    
    // Return to previous valid state or re-initialize
    if (_currentUserId != null) {
      add(SubscriptionRefreshed());
    } else {
      emit(const SubscriptionInitial());
    }
  }

  /// Preload subscription for better UX
  Future<void> _onSubscriptionPreloaded(
    SubscriptionPreloaded event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      if (_currentUserId == null) return;

      
      // Preload via secure service
      await SecureSubscriptionService.preloadSubscription(_currentUserId!);
      
      
    } catch (e) {
      // Don't emit error for preloading failures
      debugPrint('Subscription preloading failed: $e');
    }
  }

  /// Get upgrade recommendations
  Future<void> _onUpgradeRecommendationsRequested(
    UpgradeRecommendationsRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      if (_currentUserId == null) return;

      
      final recommendations = await SubscriptionService.getUpgradeRecommendations(_currentUserId!);
      
      final currentState = state;
      if (currentState is SubscriptionLoaded) {
        emit(UpgradeRecommendationsLoaded(
          recommendations: recommendations,
          subscription: currentState.subscription,
        ));
      }
      
    } catch (e) {
      // Don't emit error for recommendations failures
      debugPrint('Failed to get upgrade recommendations: $e');
    }
  }

  /// Track feature usage for analytics
  Future<void> _onFeatureUsageTracked(
    FeatureUsageTracked event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      if (_currentUserId == null) return;

      
      // Update usage analytics in Firestore
      await _firestore
          .collection('subscription_feature_usage')
          .add({
            'userId': _currentUserId,
            'featureName': event.featureName,
            'timestamp': FieldValue.serverTimestamp(),
            'metadata': event.metadata ?? {},
          });
      
    } catch (e) {
      // Don't emit error for tracking failures
      debugPrint('Failed to track feature usage: $e');
    }
  }

  /// Load feature access for subscription
  Future<Map<String, bool>> _loadFeatureAccess(UserSubscription subscription) async {
    try {
      // Load commonly used features to cache them
      final commonFeatures = _getCommonFeatures(subscription.userType);
      final results = <String, bool>{};
      
      for (final feature in commonFeatures) {
        if (!_featureAccessCache.containsKey(feature)) {
          final hasAccess = await SecureSubscriptionService.validateFeatureAccess(
            subscription.userId,
            feature,
          );
          _featureAccessCache[feature] = hasAccess;
        }
        results[feature] = _featureAccessCache[feature]!;
      }
      
      return results;
    } catch (e) {
      debugPrint('Failed to load feature access/usage limits: $e');
      return {};
    }
  }

  /// Load usage limits for subscription
  Future<Map<String, int>> _loadUsageLimits(UserSubscription subscription) async {
    try {
      final commonLimits = _getCommonLimits(subscription.userType);
      final results = <String, int>{};
      
      for (final limitName in commonLimits) {
        if (!_usageLimitsCache.containsKey(limitName)) {
          final limit = await SubscriptionService.getUserLimit(subscription.userId, limitName);
          _usageLimitsCache[limitName] = limit;
        }
        results[limitName] = _usageLimitsCache[limitName]!;
      }
      
      return results;
    } catch (e) {
      debugPrint('Failed to load feature access/usage limits: $e');
      return {};
    }
  }

  /// Load current usage data
  Future<Map<String, dynamic>> _loadCurrentUsage(UserSubscription subscription) async {
    try {
      return await SubscriptionService.getCurrentUsage(subscription.userId);
    } catch (e) {
      debugPrint('Failed to load feature access/usage limits: $e');
      return {};
    }
  }

  /// Check for subscription issues (expiration, billing)
  Future<void> _checkSubscriptionIssues(
    UserSubscription subscription,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      // Check expiration warning with multiple thresholds
      if (subscription.isPremium && subscription.nextPaymentDate != null) {
        final timeUntilExpiration = subscription.nextPaymentDate!.difference(DateTime.now());
        final daysUntilExpiration = timeUntilExpiration.inDays;
        
        // Emit different warnings based on time remaining
        if (daysUntilExpiration <= 1 && daysUntilExpiration >= 0) {
          emit(SubscriptionExpirationWarning(
            subscription: subscription,
            timeUntilExpiration: timeUntilExpiration,
            severity: ExpirationSeverity.critical, // Expires within 24 hours
            message: 'Your subscription expires in ${timeUntilExpiration.inHours} hours!',
          ));
        } else if (daysUntilExpiration <= 3) {
          emit(SubscriptionExpirationWarning(
            subscription: subscription,
            timeUntilExpiration: timeUntilExpiration,
            severity: ExpirationSeverity.high, // Expires within 3 days
            message: 'Your subscription expires in $daysUntilExpiration days.',
          ));
        } else if (daysUntilExpiration <= 7) {
          emit(SubscriptionExpirationWarning(
            subscription: subscription,
            timeUntilExpiration: timeUntilExpiration,
            severity: ExpirationSeverity.medium, // Expires within 7 days
            message: 'Your subscription expires in $daysUntilExpiration days.',
          ));
        }
      }
      
      // Enhanced billing issue detection
      if (subscription.status == SubscriptionStatus.pastDue) {
        emit(BillingIssueDetected(
          subscription: subscription,
          issueType: 'payment_failed',
          issueMessage: 'Your last payment failed. Please update your payment method to continue using premium features.',
          severity: BillingIssueSeverity.high,
          actionRequired: true,
        ));
      } else if (subscription.status == SubscriptionStatus.pastDue) {
        emit(BillingIssueDetected(
          subscription: subscription,
          issueType: 'payment_incomplete',
          issueMessage: 'Your payment is incomplete. Please complete the payment process.',
          severity: BillingIssueSeverity.medium,
          actionRequired: true,
        ));
      }
      
      // Check for grace period expiration
      if (subscription.status == SubscriptionStatus.cancelled && 
          subscription.nextPaymentDate != null &&
          DateTime.now().isAfter(subscription.nextPaymentDate!)) {
        emit(SubscriptionGracePeriodExpired(
          subscription: subscription,
          expiredDate: subscription.nextPaymentDate!,
        ));
      }
      
    } catch (e) {
      debugPrint('Failed to sync subscription with RevenueCat: $e');
    }
  }

  /// Start monitoring for subscription expiration with dynamic intervals
  void _startExpirationMonitoring() {
    _expirationCheckTimer?.cancel();
    
    // More frequent checks as expiration approaches
    final checkInterval = _getExpirationCheckInterval();
    
    _expirationCheckTimer = Timer.periodic(
      checkInterval,
      (timer) {
        final currentState = state;
        if (currentState is SubscriptionLoaded) {
          add(SubscriptionIssuesRequested(currentState.subscription));
          
          // Adjust check frequency based on subscription status
          final newInterval = _getExpirationCheckInterval();
          if (newInterval != checkInterval) {
            _startExpirationMonitoring(); // Restart with new interval
          }
        }
      },
    );
  }
  
  /// Get dynamic check interval based on subscription status
  Duration _getExpirationCheckInterval() {
    final currentState = state;
    if (currentState is SubscriptionLoaded && 
        currentState.subscription.isPremium && 
        currentState.subscription.nextPaymentDate != null) {
      
      final timeUntilExpiration = currentState.subscription.nextPaymentDate!.difference(DateTime.now());
      final daysUntilExpiration = timeUntilExpiration.inDays;
      
      // More frequent checks as expiration approaches
      if (daysUntilExpiration <= 1) {
        return const Duration(hours: 1); // Check every hour in final day
      } else if (daysUntilExpiration <= 3) {
        return const Duration(hours: 6); // Check every 6 hours in final 3 days
      } else if (daysUntilExpiration <= 7) {
        return const Duration(hours: 12); // Check twice daily in final week
      }
    }
    
    return const Duration(hours: 24); // Daily checks for active subscriptions
  }

  /// Start monitoring for billing issues with enhanced webhook integration
  void _startBillingIssueMonitoring() {
    _billingIssueCheckTimer?.cancel();
    _billingIssueCheckTimer = Timer.periodic(
      const Duration(hours: 3), // More frequent billing checks
      (timer) {
        final currentState = state;
        if (currentState is SubscriptionLoaded) {
          add(SubscriptionIssuesRequested(currentState.subscription));
          _checkPaymentMethodExpiration(currentState.subscription);
        }
      },
    );
  }
  
  /// Check for payment method expiration
  Future<void> _checkPaymentMethodExpiration(UserSubscription subscription) async {
    try {
      if (subscription.isPremium && subscription.paymentMethodId != null) {
        // This would integrate with Stripe to check payment method status
        // For now, we'll implement a basic check
        
        final paymentMethodDoc = await _firestore
            .collection('payment_methods')
            .doc(subscription.paymentMethodId)
            .get();
            
        if (paymentMethodDoc.exists) {
          final data = paymentMethodDoc.data()!;
          final expiryMonth = data['exp_month'] as int?;
          final expiryYear = data['exp_year'] as int?;
          
          if (expiryMonth != null && expiryYear != null) {
            final expiryDate = DateTime(expiryYear, expiryMonth + 1, 0);
            final now = DateTime.now();
            
            // Warn if payment method expires within 30 days
            if (expiryDate.isBefore(now.add(const Duration(days: 30)))) {
              // Note: Payment method expiring soon
              // This should be handled by the event handler, not emitted directly
              debugPrint('Payment method expires on $expiryDate (${expiryDate.difference(now).inDays} days)');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to sync subscription with RevenueCat: $e');
    }
  }

  /// Clear all caches
  void _clearCaches() {
    _featureAccessCache.clear();
    _usageLimitsCache.clear();
    _currentUsageCache.clear();
  }

  /// Get common features for user type
  List<String> _getCommonFeatures(String userType) {
    switch (userType) {
      case 'vendor':
        return [
          'product_performance_analytics',
          'revenue_tracking',
          'market_discovery',
          'unlimited_markets',
        ];
      case 'market_organizer':
        return [
          'vendor_discovery',
          'bulk_messaging',
          'vendor_analytics_dashboard',
        ];
      case 'shopper':
        return [
          'enhanced_search',
          'vendor_following',
          'unlimited_favorites',
        ];
      default:
        return [];
    }
  }

  /// Get common limits for user type
  List<String> _getCommonLimits(String userType) {
    switch (userType) {
      case 'vendor':
        return [
          'global_products',
          'photo_uploads_per_post',
          'monthly_markets',
        ];
      case 'market_organizer':
        return [
          'markets_managed',
          'events_per_month',
        ];
      case 'shopper':
        return [
          'saved_favorites',
          'followed_vendors',
        ];
      default:
        return [];
    }
  }

  /// Handle subscription issues requests from timers
  Future<void> _onSubscriptionIssuesRequested(
    SubscriptionIssuesRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      await _checkSubscriptionIssues(event.subscription, emit);
    } catch (e) {
      debugPrint('Failed to sync subscription with RevenueCat: $e');
    }
  }

  @override
  Future<void> close() {
    
    _subscriptionStreamSubscription?.cancel();
    _expirationCheckTimer?.cancel();
    _billingIssueCheckTimer?.cancel();
    
    return super.close();
  }
}