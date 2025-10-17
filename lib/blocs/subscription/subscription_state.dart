import 'package:equatable/equatable.dart';
import '../../features/premium/models/user_subscription.dart';

/// Severity levels for expiration warnings
enum ExpirationSeverity {
  low,    // 7+ days
  medium, // 3-7 days
  high,   // 1-3 days
  critical // < 24 hours
}

/// Severity levels for billing issues
enum BillingIssueSeverity {
  low,
  medium,
  high,
  critical
}

/// States for the subscription bloc
abstract class SubscriptionState extends Equatable {
  const SubscriptionState();

  @override
  List<Object?> get props => [];
}

/// Initial subscription state
class SubscriptionInitial extends SubscriptionState {
  const SubscriptionInitial();
}

/// Loading subscription data
class SubscriptionLoading extends SubscriptionState {
  final String? message;
  
  const SubscriptionLoading({this.message});
  
  @override
  List<Object?> get props => [message];
}

/// Subscription data loaded successfully
class SubscriptionLoaded extends SubscriptionState {
  final UserSubscription subscription;
  final Map<String, bool> featureAccess;
  final Map<String, int> usageLimits;
  final Map<String, dynamic>? currentUsage;
  final Map<String, dynamic>? recommendations;
  
  const SubscriptionLoaded({
    required this.subscription,
    this.featureAccess = const {},
    this.usageLimits = const {},
    this.currentUsage,
    this.recommendations,
  });
  
  @override
  List<Object?> get props => [
    subscription,
    featureAccess,
    usageLimits,
    currentUsage,
    recommendations,
  ];
  
  /// Convenient getters
  bool get isPremium => subscription.isPremium;
  bool get isActive => subscription.isActive;
  bool get isFree => subscription.isFree;
  SubscriptionTier get tier => subscription.tier;
  String get userType => subscription.userType;
  
  /// Check if user has access to a specific feature
  bool hasFeature(String featureName) {
    return featureAccess[featureName] ?? subscription.hasFeature(featureName);
  }
  
  /// Check if user is within usage limits
  bool isWithinLimit(String limitName, int currentUsage) {
    final limit = usageLimits[limitName] ?? subscription.getLimit(limitName);
    return limit == -1 || currentUsage < limit;
  }
  
  /// Get utilization percentage for a limit
  double getUtilizationPercentage(String limitName) {
    final usage = currentUsage?[limitName] as int? ?? 0;
    final limit = usageLimits[limitName] ?? subscription.getLimit(limitName);
    
    if (limit == -1) return 0.0; // Unlimited
    if (limit == 0) return 100.0; // No limit available
    
    return (usage / limit * 100).clamp(0.0, 100.0);
  }
  
  /// Copy state with new values
  SubscriptionLoaded copyWith({
    UserSubscription? subscription,
    Map<String, bool>? featureAccess,
    Map<String, int>? usageLimits,
    Map<String, dynamic>? currentUsage,
    Map<String, dynamic>? recommendations,
  }) {
    return SubscriptionLoaded(
      subscription: subscription ?? this.subscription,
      featureAccess: featureAccess ?? this.featureAccess,
      usageLimits: usageLimits ?? this.usageLimits,
      currentUsage: currentUsage ?? this.currentUsage,
      recommendations: recommendations ?? this.recommendations,
    );
  }
}

/// Subscription error state
class SubscriptionError extends SubscriptionState {
  final String message;
  final UserSubscription? subscription; // Keep subscription data if available
  
  const SubscriptionError({
    required this.message,
    this.subscription,
  });
  
  @override
  List<Object?> get props => [message, subscription];
}

/// Subscription upgrade in progress
class SubscriptionUpgrading extends SubscriptionState {
  final SubscriptionTier targetTier;
  final UserSubscription? currentSubscription;
  
  const SubscriptionUpgrading({
    required this.targetTier,
    this.currentSubscription,
  });
  
  @override
  List<Object?> get props => [targetTier, currentSubscription];
}

/// Subscription successfully upgraded
class SubscriptionUpgradedState extends SubscriptionState {
  final UserSubscription subscription;
  final SubscriptionTier previousTier;
  
  const SubscriptionUpgradedState({
    required this.subscription,
    required this.previousTier,
  });
  
  @override
  List<Object?> get props => [subscription, previousTier];
}

/// Subscription cancellation in progress
class SubscriptionCancelling extends SubscriptionState {
  final UserSubscription currentSubscription;
  
  const SubscriptionCancelling(this.currentSubscription);
  
  @override
  List<Object?> get props => [currentSubscription];
}

/// Subscription successfully cancelled
class SubscriptionCancelledState extends SubscriptionState {
  final UserSubscription subscription;
  final DateTime cancellationDate;
  
  const SubscriptionCancelledState({
    required this.subscription,
    required this.cancellationDate,
  });
  
  @override
  List<Object?> get props => [subscription, cancellationDate];
}

/// Feature access check result
class FeatureAccessResult extends SubscriptionState {
  final String featureName;
  final bool hasAccess;
  final UserSubscription subscription;
  
  const FeatureAccessResult({
    required this.featureName,
    required this.hasAccess,
    required this.subscription,
  });
  
  @override
  List<Object?> get props => [featureName, hasAccess, subscription];
}

/// Usage limit check result
class UsageLimitResult extends SubscriptionState {
  final String limitName;
  final int currentUsage;
  final int limit;
  final bool withinLimit;
  final UserSubscription subscription;
  
  const UsageLimitResult({
    required this.limitName,
    required this.currentUsage,
    required this.limit,
    required this.withinLimit,
    required this.subscription,
  });
  
  @override
  List<Object?> get props => [limitName, currentUsage, limit, withinLimit, subscription];
}

/// Payment information updated
class PaymentInfoUpdatedState extends SubscriptionState {
  final UserSubscription subscription;
  
  const PaymentInfoUpdatedState(this.subscription);
  
  @override
  List<Object?> get props => [subscription];
}

/// Upgrade recommendations loaded
class UpgradeRecommendationsLoaded extends SubscriptionState {
  final Map<String, dynamic> recommendations;
  final UserSubscription subscription;
  
  const UpgradeRecommendationsLoaded({
    required this.recommendations,
    required this.subscription,
  });
  
  @override
  List<Object?> get props => [recommendations, subscription];
}

/// Enhanced subscription expiration warning with severity levels
class SubscriptionExpirationWarning extends SubscriptionState {
  final UserSubscription subscription;
  final Duration timeUntilExpiration;
  final ExpirationSeverity severity;
  final String message;
  
  const SubscriptionExpirationWarning({
    required this.subscription,
    required this.timeUntilExpiration,
    required this.severity,
    required this.message,
  });
  
  @override
  List<Object?> get props => [subscription, timeUntilExpiration, severity, message];
  
  /// Get color based on severity
  String get severityColor {
    switch (severity) {
      case ExpirationSeverity.critical:
        return '#F44336'; // Red
      case ExpirationSeverity.high:
        return '#FF9800'; // Orange
      case ExpirationSeverity.medium:
        return '#FFC107'; // Amber
      case ExpirationSeverity.low:
        return '#4CAF50'; // Green
    }
  }
}

/// Enhanced billing issue notification with severity and actions
class BillingIssueDetected extends SubscriptionState {
  final UserSubscription subscription;
  final String issueType;
  final String issueMessage;
  final BillingIssueSeverity severity;
  final bool actionRequired;
  
  const BillingIssueDetected({
    required this.subscription,
    required this.issueType,
    required this.issueMessage,
    required this.severity,
    this.actionRequired = false,
  });
  
  @override
  List<Object?> get props => [subscription, issueType, issueMessage, severity, actionRequired];
  
  /// Get color based on severity
  String get severityColor {
    switch (severity) {
      case BillingIssueSeverity.critical:
        return '#F44336'; // Red
      case BillingIssueSeverity.high:
        return '#FF5722'; // Deep Orange
      case BillingIssueSeverity.medium:
        return '#FF9800'; // Orange
      case BillingIssueSeverity.low:
        return '#FFC107'; // Amber
    }
  }
}

/// Subscription status synchronized with remote
class SubscriptionSynchronized extends SubscriptionState {
  final UserSubscription subscription;
  final DateTime lastSyncTime;
  
  const SubscriptionSynchronized({
    required this.subscription,
    required this.lastSyncTime,
  });
  
  @override
  List<Object?> get props => [subscription, lastSyncTime];
}

/// Subscription grace period has expired
class SubscriptionGracePeriodExpired extends SubscriptionState {
  final UserSubscription subscription;
  final DateTime expiredDate;
  
  const SubscriptionGracePeriodExpired({
    required this.subscription,
    required this.expiredDate,
  });
  
  @override
  List<Object?> get props => [subscription, expiredDate];
}

/// Payment method expiration warning
class PaymentMethodExpirationWarning extends SubscriptionState {
  final UserSubscription subscription;
  final DateTime expiryDate;
  final Duration timeUntilExpiration;
  
  const PaymentMethodExpirationWarning({
    required this.subscription,
    required this.expiryDate,
    required this.timeUntilExpiration,
  });
  
  @override
  List<Object?> get props => [subscription, expiryDate, timeUntilExpiration];
}

/// Real-time analytics data updated
class AnalyticsDataUpdated extends SubscriptionState {
  final UserSubscription subscription;
  final Map<String, dynamic> analyticsData;
  final DateTime lastUpdated;
  
  const AnalyticsDataUpdated({
    required this.subscription,
    required this.analyticsData,
    required this.lastUpdated,
  });
  
  @override
  List<Object?> get props => [subscription, analyticsData, lastUpdated];
}

/// Subscription tier changed successfully
class SubscriptionTierChanged extends SubscriptionState {
  final UserSubscription subscription;
  final SubscriptionTier previousTier;
  final SubscriptionTier newTier;
  final DateTime changeDate;
  
  const SubscriptionTierChanged({
    required this.subscription,
    required this.previousTier,
    required this.newTier,
    required this.changeDate,
  });
  
  @override
  List<Object?> get props => [subscription, previousTier, newTier, changeDate];
}