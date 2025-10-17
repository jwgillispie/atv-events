import 'package:equatable/equatable.dart';
import '../../features/premium/models/user_subscription.dart';

/// Events for the subscription bloc
abstract class SubscriptionEvent extends Equatable {
  const SubscriptionEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize subscription monitoring
class SubscriptionInitialized extends SubscriptionEvent {
  final String userId;
  
  const SubscriptionInitialized(this.userId);
  
  @override
  List<Object> get props => [userId];
}

/// Subscription data changed (from Firestore listener)
class SubscriptionChanged extends SubscriptionEvent {
  final UserSubscription? subscription;
  
  const SubscriptionChanged(this.subscription);
  
  @override
  List<Object?> get props => [subscription];
}

/// User upgraded their subscription
class SubscriptionUpgraded extends SubscriptionEvent {
  final SubscriptionTier tier;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final String? paymentMethodId;
  final String? stripePriceId;
  
  const SubscriptionUpgraded({
    required this.tier,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.paymentMethodId,
    this.stripePriceId,
  });
  
  @override
  List<Object?> get props => [
    tier,
    stripeCustomerId,
    stripeSubscriptionId,
    paymentMethodId,
    stripePriceId,
  ];
}

/// User cancelled their subscription
class SubscriptionCancelled extends SubscriptionEvent {
  const SubscriptionCancelled();
}

/// Check feature access
class FeatureAccessRequested extends SubscriptionEvent {
  final String featureName;
  
  const FeatureAccessRequested(this.featureName);
  
  @override
  List<Object> get props => [featureName];
}

/// Check usage limits
class UsageLimitRequested extends SubscriptionEvent {
  final String limitName;
  final int currentUsage;
  
  const UsageLimitRequested(this.limitName, this.currentUsage);
  
  @override
  List<Object> get props => [limitName, currentUsage];
}

/// Update payment information
class PaymentInfoUpdated extends SubscriptionEvent {
  final String? paymentMethodId;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final DateTime? nextPaymentDate;
  
  const PaymentInfoUpdated({
    this.paymentMethodId,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.nextPaymentDate,
  });
  
  @override
  List<Object?> get props => [
    paymentMethodId,
    stripeCustomerId,
    stripeSubscriptionId,
    nextPaymentDate,
  ];
}

/// Refresh subscription from server
class SubscriptionRefreshed extends SubscriptionEvent {
  final bool forceRefresh;
  
  const SubscriptionRefreshed({this.forceRefresh = false});
  
  @override
  List<Object> get props => [forceRefresh];
}

/// Handle subscription error
class SubscriptionErrorOccurred extends SubscriptionEvent {
  final String error;
  
  const SubscriptionErrorOccurred(this.error);
  
  @override
  List<Object> get props => [error];
}

/// Clear subscription error
class SubscriptionErrorCleared extends SubscriptionEvent {
  const SubscriptionErrorCleared();
}

/// Preload subscription for better UX
class SubscriptionPreloaded extends SubscriptionEvent {
  const SubscriptionPreloaded();
}

/// Get upgrade recommendations
class UpgradeRecommendationsRequested extends SubscriptionEvent {
  const UpgradeRecommendationsRequested();
}

/// Track feature usage
class FeatureUsageTracked extends SubscriptionEvent {
  final String featureName;
  final Map<String, dynamic>? metadata;
  
  const FeatureUsageTracked(this.featureName, {this.metadata});
  
  @override
  List<Object?> get props => [featureName, metadata];
}

/// Check subscription issues (for timer callbacks)
class SubscriptionIssuesRequested extends SubscriptionEvent {
  final UserSubscription subscription;
  
  const SubscriptionIssuesRequested(this.subscription);
  
  @override
  List<Object> get props => [subscription];
}