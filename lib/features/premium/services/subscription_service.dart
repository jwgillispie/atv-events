// TODO: Removed for ATV Events demo - Premium/subscription features disabled
// This is a stub to maintain compilation

import '../models/user_subscription.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  Future<void> initialize() async {
    // Do nothing - premium features disabled
  }

  Future<UserSubscription?> getUserSubscription(String userId) async {
    // Return null - premium features disabled
    return null;
  }

  Stream<UserSubscription?> getUserSubscriptionStream(String userId) {
    // Return empty stream - premium features disabled
    return Stream.value(null);
  }

  Future<bool> hasActiveSubscription(String userId) async {
    // Return false - premium features disabled
    return false;
  }

  Future<void> subscribe(String userId, String planId) async {
    // Do nothing - premium features disabled
  }

  Future<void> cancelSubscription(String userId) async {
    // Do nothing - premium features disabled
  }
}
