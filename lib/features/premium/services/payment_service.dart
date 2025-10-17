// TODO: Removed for ATV Events demo - Premium/subscription features disabled
// This is a stub to maintain compilation

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  Future<void> initialize() async {
    // Do nothing - payment features disabled
  }

  Future<Map<String, dynamic>?> createPaymentIntent({
    required double amount,
    required String currency,
    required String userId,
  }) async {
    // Return null - payment features disabled
    return null;
  }

  Future<bool> processPayment({
    required String paymentMethodId,
    required double amount,
  }) async {
    // Return false - payment features disabled
    return false;
  }
}
