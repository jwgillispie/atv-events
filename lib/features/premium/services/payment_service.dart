import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:atv_events/features/shared/services/utilities/remote_config_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:atv_events/core/constants/payment_constants.dart';
import '../models/user_subscription.dart';

// Web-safe platform detection using kIsWeb and defaultTargetPlatform
bool get isWebPlatform => kIsWeb;

// Safe mobile platform detection using defaultTargetPlatform
bool get isIOSPlatform => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

bool get isAndroidPlatform => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Enhanced payment service that handles in-app Stripe payments with CardField
class PaymentService {
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static bool _isInitialized = false;

  /// Initialize Stripe with publishable key
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if Stripe is already initialized from main.dart
      if (Stripe.publishableKey.isNotEmpty) {
        _isInitialized = true;
        return;
      }

      // Use platform-specific initialization
      if (isWebPlatform) {
        await _initializeForWeb();
      } else {
        await _initializeForMobile();
      }

      _isInitialized = true;
    } catch (e) {
      
      // Try web fallback initialization if primary method fails
      if (!isWebPlatform && !_isInitialized) {
        try {
          await _initializeForWeb();
          _isInitialized = true;
          return;
        } catch (fallbackError) {
        }
      }
      
      rethrow;
    }
  }

  /// Initialize Stripe for web platform
  static Future<void> _initializeForWeb() async {
    
    // Try Remote Config first (following the pattern of other working functions)
    String publishableKey = await RemoteConfigService.getStripePublishableKey();
    
    // If Remote Config fails, use hardcoded fallback
    if (publishableKey.isEmpty) {
      // Fallback - This is your live publishable key - safe to expose
      publishableKey = 'pk_live_51RsQNrC8FCSHt0iKEEfaV2Kd98wwFHAw0d6rcvLR7kxGzvfWuOxhaOvYOD2GRvODOR5eAQnFC7p622ech7BDGddy00IP3xtXun';
    } else {
    }
    
    if (publishableKey.isEmpty) {
      throw Exception('Stripe publishable key not found');
    }

    Stripe.publishableKey = publishableKey;
  }

  /// Initialize Stripe for mobile platforms (iOS/Android)
  static Future<void> _initializeForMobile() async {
    final publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
    if (publishableKey == null || publishableKey.isEmpty) {
      throw Exception('Stripe publishable key not found in environment');
    }

    Stripe.publishableKey = publishableKey;
    
    // Set merchant identifier for Apple Pay (iOS only)
    if (isIOSPlatform) {
      try {
        Stripe.merchantIdentifier = dotenv.env['STRIPE_MERCHANT_IDENTIFIER'] ?? 'merchant.com.hipop';
      } catch (e) {
        // Continue without merchant identifier - not critical
      }
    } else if (isAndroidPlatform) {
    } else {
    }
  }

  /// Create payment intent for subscription
  static Future<String> createPaymentIntent({
    required String priceId,
    required String customerEmail,
    required String userId,
    required String userType,
    String? promoCode,
  }) async {
    try {

      final callable = FirebaseFunctions.instance.httpsCallable('createPaymentIntent');
      final result = await callable.call({
        'priceId': priceId,
        'customerEmail': customerEmail,
        'userId': userId,
        'userType': userType,
        'promoCode': promoCode,
        'environment': dotenv.env['ENVIRONMENT'] ?? 'staging',
      }).timeout(_defaultTimeout);

      final data = result.data as Map<String, dynamic>;
      final clientSecret = data['client_secret'] as String?;
      
      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Invalid payment intent response from server');
      }

      return clientSecret;
    } catch (e) {
      
      if (e is FirebaseFunctionsException) {
        switch (e.code) {
          case 'invalid-argument':
            throw PaymentException('Invalid payment information provided');
          case 'permission-denied':
            throw PaymentException('Not authorized to create payment');
          case 'unavailable':
            throw PaymentException('Payment service temporarily unavailable');
          case 'failed-precondition':
            throw PaymentException('Invalid promo code or payment configuration');
          default:
            throw PaymentException('Unable to process payment request');
        }
      }
      
      throw PaymentException('Payment processing failed: ${e.toString()}');
    }
  }

  /// Initialize Payment Sheet for mobile platforms
  static Future<void> initPaymentSheet({
    required String clientSecret,
    required String customerEmail,
    String? merchantDisplayName,
  }) async {
    if (isWebPlatform) {
      print('🔴 [PAYMENT_SERVICE] Cannot use Payment Sheet on web');
      throw PaymentException('Payment Sheet is not supported on web. Use checkout redirect instead.');
    }

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantDisplayName ?? 'HiPop',
          customerEphemeralKeySecret: null, // Not needed for payment intents
          style: ThemeMode.system,
          billingDetails: BillingDetails(
            email: customerEmail,
          ),
          appearance: PaymentSheetAppearance(
            primaryButton: PaymentSheetPrimaryButtonAppearance(
              colors: PaymentSheetPrimaryButtonTheme(
                light: PaymentSheetPrimaryButtonThemeColors(
                  background: const Color(0xFF6366F1), // Indigo color
                  text: const Color(0xFFFFFFFF),
                  border: const Color(0xFF6366F1),
                ),
                dark: PaymentSheetPrimaryButtonThemeColors(
                  background: const Color(0xFF6366F1),
                  text: const Color(0xFFFFFFFF),
                  border: const Color(0xFF6366F1),
                ),
              ),
            ),
          ),
        ),
      );

    } catch (e) {
      print('🔴 [PAYMENT_SERVICE] Failed to initialize Payment Sheet: $e');
      print('🔴 [PAYMENT_SERVICE] Error type: ${e.runtimeType}');

      if (e is StripeException) {
        print('🔴 [PAYMENT_SERVICE] Stripe Error Code: ${e.error.code}');
        print('🔴 [PAYMENT_SERVICE] Stripe Error Message: ${e.error.message}');
        print('🔴 [PAYMENT_SERVICE] Stripe Error Localized: ${e.error.localizedMessage}');

        final errorMessage = e.error.localizedMessage ?? e.error.message ?? 'Failed to initialize payment';
        throw PaymentException(errorMessage);
      }

      throw PaymentException('Failed to initialize payment: ${e.toString()}');
    }
  }

  /// Present Payment Sheet for mobile payment
  static Future<void> presentPaymentSheet() async {
    if (isWebPlatform) {
      print('🔴 [PAYMENT_SERVICE] Cannot use Payment Sheet on web');
      throw PaymentException('Payment Sheet is not supported on web. Use checkout redirect instead.');
    }

    try {
      await Stripe.instance.presentPaymentSheet();

    } catch (e) {
      print('🔴 [PAYMENT_SERVICE] Payment Sheet failed: $e');
      print('🔴 [PAYMENT_SERVICE] Error type: ${e.runtimeType}');

      if (e is StripeException) {
        final errorCode = e.error.code.name;
        final errorMessage = e.error.localizedMessage ?? e.error.message ?? 'Payment failed';

        print('🔴 [PAYMENT_SERVICE] Stripe Error Code: $errorCode');
        print('🔴 [PAYMENT_SERVICE] Stripe Error Message: $errorMessage');

        // Handle user cancellation
        if (errorCode.contains('canceled') || errorCode.contains('cancelled')) {
          print('⚠️ [PAYMENT_SERVICE] Payment was cancelled by user');
          throw PaymentException('Payment was cancelled');
        }

        // Handle common error types
        if (errorCode.contains('card_declined') || errorCode.contains('generic_decline')) {
          throw PaymentException('Your card was declined. Please try a different card.');
        } else if (errorCode.contains('expired_card')) {
          throw PaymentException('Your card has expired. Please use a different card.');
        } else if (errorCode.contains('incorrect_cvc')) {
          throw PaymentException('Your card\'s security code is incorrect.');
        } else if (errorCode.contains('incorrect_number') || errorCode.contains('invalid_number')) {
          throw PaymentException('Your card number is incorrect.');
        } else {
          throw PaymentException(errorMessage);
        }
      }

      throw PaymentException('Payment failed: ${e.toString()}');
    }
  }

  /// Complete payment flow using Payment Sheet (mobile only)
  static Future<void> processPaymentWithSheet({
    required String priceId,
    required String customerEmail,
    required String userId,
    required String userType,
    String? promoCode,
    String? merchantDisplayName,
  }) async {
    if (isWebPlatform) {
      throw PaymentException('Payment Sheet is not supported on web. Use checkout redirect instead.');
    }

    try {

      // Step 1: Create payment intent
      final clientSecret = await createPaymentIntent(
        priceId: priceId,
        customerEmail: customerEmail,
        userId: userId,
        userType: userType,
        promoCode: promoCode,
      );

      // Step 2: Initialize Payment Sheet
      await initPaymentSheet(
        clientSecret: clientSecret,
        customerEmail: customerEmail,
        merchantDisplayName: merchantDisplayName,
      );

      // Step 3: Present Payment Sheet
      await presentPaymentSheet();

    } catch (e) {
      rethrow;
    }
  }

  /// Confirm payment with card details (legacy method for CardField)
  /// @deprecated Use Payment Sheet instead for better UX
  static Future<PaymentIntent> confirmPayment({
    required String clientSecret,
    required PaymentMethodData paymentMethodData,
  }) async {
    try {

      final paymentIntent = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: PaymentMethodParams.card(paymentMethodData: paymentMethodData),
      );

      if (paymentIntent.status == PaymentIntentsStatus.Succeeded) {
        return paymentIntent;
      } else if (paymentIntent.status == PaymentIntentsStatus.RequiresAction) {
        // Handle 3D Secure or other authentication
        throw PaymentException('Payment requires additional authentication');
      } else {
        throw PaymentException('Payment failed. Please try again.');
      }
    } catch (e) {
      
      if (e is StripeException) {
        final errorCode = e.error.code.name;
        final errorMessage = e.error.localizedMessage ?? e.error.message ?? 'Payment failed. Please try again.';
        
        // Handle common error types
        if (errorCode.contains('card_declined') || errorCode.contains('generic_decline')) {
          throw PaymentException('Your card was declined. Please try a different card.');
        } else if (errorCode.contains('expired_card')) {
          throw PaymentException('Your card has expired. Please use a different card.');
        } else if (errorCode.contains('incorrect_cvc')) {
          throw PaymentException('Your card\'s security code is incorrect.');
        } else if (errorCode.contains('incorrect_number') || errorCode.contains('invalid_number')) {
          throw PaymentException('Your card number is incorrect.');
        } else {
          throw PaymentException(errorMessage);
        }
      }
      
      if (e is PaymentException) {
        rethrow;
      }
      
      throw PaymentException('Payment processing failed: ${e.toString()}');
    }
  }

  /// Validate promo code
  static Future<PromoCodeValidation> validatePromoCode(String promoCode) async {
    try {

      final callable = FirebaseFunctions.instance.httpsCallable('validatePromoCode');
      final result = await callable.call({
        'promoCode': promoCode,
      }).timeout(_defaultTimeout);

      final data = result.data as Map<String, dynamic>;
      
      // Validate numeric values from server response
      final rawDiscountPercent = (data['discount_percent'] as num?)?.toDouble();
      final rawDiscountAmount = (data['discount_amount'] as num?)?.toDouble();
      
      // Ensure no NaN or invalid values are passed through
      final validDiscountPercent = (rawDiscountPercent != null && 
          !rawDiscountPercent.isNaN && 
          !rawDiscountPercent.isInfinite && 
          rawDiscountPercent >= 0 && 
          rawDiscountPercent <= 100) ? rawDiscountPercent : null;
          
      final validDiscountAmount = (rawDiscountAmount != null && 
          !rawDiscountAmount.isNaN && 
          !rawDiscountAmount.isInfinite && 
          rawDiscountAmount >= 0) ? rawDiscountAmount : null;

      return PromoCodeValidation(
        isValid: data['valid'] as bool? ?? false,
        discountPercent: validDiscountPercent,
        discountAmount: validDiscountAmount,
        description: data['description'] as String?,
        errorMessage: data['error'] as String?,
      );
    } catch (e) {
      return PromoCodeValidation(
        isValid: false,
        errorMessage: 'Unable to validate promo code. Please try again.',
      );
    }
  }

  /// Check if Apple Pay is available (disabled for now)
  static Future<bool> isApplePaySupported() async {
    // Apple Pay not available on web
    if (kIsWeb) return false;
    // Apple Pay integration disabled temporarily due to API changes
    return false;
  }

  /// Check if Google Pay is available (disabled for now)
  static Future<bool> isGooglePaySupported() async {
    // Google Pay not available on web
    if (kIsWeb) return false;
    // Google Pay integration disabled temporarily due to API changes
    return false;
  }

  /// Create payment method with Apple Pay (temporarily disabled)
  static Future<PaymentMethod> createApplePayPaymentMethod({
    required double amount,
    required String currency,
    required String countryCode,
  }) async {
    throw PaymentException('Apple Pay is temporarily unavailable. Please use a card instead.');
  }

  /// Create payment method with Google Pay (temporarily disabled)
  static Future<PaymentMethod> createGooglePayPaymentMethod({
    required double amount,
    required String currency,
    required String countryCode,
  }) async {
    throw PaymentException('Google Pay is temporarily unavailable. Please use a card instead.');
  }

  /// Get subscription pricing for user type
  static SubscriptionPricing getPricingForUserType(String userType) {
    
    try {
    } catch (e) {
    }
    
    switch (userType) {
      case 'vendor':
        return SubscriptionPricing(
          priceId: dotenv.env['STRIPE_PRICE_VENDOR_PREMIUM'] ?? '',
          amount: 29.00,
          currency: 'USD',
          interval: 'month',
          name: 'Vendor Pro',
          description: 'Advanced analytics and market management tools',
          features: [
            'Unlimited market applications',
            'Advanced analytics dashboard',
            'Multi-market management',
            'Priority customer support',
          ],
        );
      case 'market_organizer':
        return SubscriptionPricing(
          priceId: dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM'] ?? '',
          amount: 69.00,
          currency: 'USD',
          interval: 'month',
          name: 'Market Organizer Premium',
          description: 'Complete market management and vendor recruitment suite',
          features: [
            'Unlimited vendor posts',
            'Advanced vendor recruitment',
            'Market performance analytics',
            'Priority customer support',
          ],
        );
      case 'shopper':
        return SubscriptionPricing(
          priceId: dotenv.env['STRIPE_PRICE_SHOPPER_PREMIUM'] ?? '',
          amount: 4.00,
          currency: 'USD',
          interval: 'month',
          name: 'Shopper Premium',
          description: 'Enhanced discovery and personalized recommendations',
          features: [
            'Follow unlimited vendors',
            'Advanced search filters',
            'Personalized recommendations',
            'Vendor appearance predictions',
          ],
        );
      default:
        throw ArgumentError('Unsupported user type: $userType');
    }
  }

  // REMOVED: SubscriptionTier enum not defined - method commented out
  // /// Get subscription tier from user type
  // static SubscriptionTier getSubscriptionTierForUserType(String userType) {
  //   switch (userType) {
  //     case 'vendor':
  //       return SubscriptionTier.vendorPremium;
  //     case 'market_organizer':
  //       return SubscriptionTier.marketOrganizerPremium;
  //     case 'shopper':
  //       return SubscriptionTier.free;
  //     default:
  //       throw ArgumentError('Unsupported user type: $userType');
  //   }
  // }

  /// Calculate final amount after applying promo code with NaN protection
  static double calculateFinalAmount(double originalAmount, PromoCodeValidation? promoValidation) {
    // Validate original amount first
    if (originalAmount.isNaN || originalAmount.isInfinite || originalAmount <= 0) {
      return 0.0;
    }

    if (promoValidation == null || !promoValidation.isValid) {
      return originalAmount;
    }

    if (promoValidation.discountAmount != null) {
      final discountAmount = promoValidation.discountAmount!;
      // Validate discount amount
      if (discountAmount.isNaN || discountAmount.isInfinite || discountAmount < 0) {
        return originalAmount;
      }
      final result = (originalAmount - discountAmount).clamp(0.0, originalAmount);
      // Validate final result
      if (result.isNaN || result.isInfinite) {
        return originalAmount;
      }
      return result;
    }

    if (promoValidation.discountPercent != null) {
      final discountPercent = promoValidation.discountPercent!;
      // Validate discount percent
      if (discountPercent.isNaN || discountPercent.isInfinite || discountPercent < 0 || discountPercent > 100) {
        return originalAmount;
      }
      final discount = originalAmount * (discountPercent / 100);
      // Validate discount calculation
      if (discount.isNaN || discount.isInfinite) {
        return originalAmount;
      }
      final result = (originalAmount - discount).clamp(0.0, originalAmount);
      // Validate final result
      if (result.isNaN || result.isInfinite) {
        return originalAmount;
      }
      return result;
    }

    return originalAmount;
  }

  /// Create payment intent for product purchase
  static Future<String> createProductPaymentIntent({
    required ProductPaymentConfig config,
    required String customerEmail,
    required String userId,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createProductPaymentIntent');

      final requestData = {
        'config': config.toJson(),
        'customerEmail': customerEmail,
        'userId': userId,
        'environment': dotenv.env['ENVIRONMENT'] ?? 'staging',
      };

      final result = await callable.call(requestData).timeout(_defaultTimeout);

      final data = result.data as Map<String, dynamic>;
      final clientSecret = data['client_secret'] as String?;

      if (clientSecret == null || clientSecret.isEmpty) {
        print('🔴 [PAYMENT_SERVICE] No client secret in response');
        throw Exception('Invalid payment intent response from server');
      }

      return clientSecret;
    } catch (e) {
      print('🔴 [PAYMENT_SERVICE] Error creating payment intent: $e');
      print('🔴 [PAYMENT_SERVICE] Error type: ${e.runtimeType}');

      if (e is FirebaseFunctionsException) {
        print('🔴 [PAYMENT_SERVICE] Firebase Function Error Code: ${e.code}');
        print('🔴 [PAYMENT_SERVICE] Firebase Function Error Message: ${e.message}');
        print('🔴 [PAYMENT_SERVICE] Firebase Function Error Details: ${e.details}');

        switch (e.code) {
          case 'invalid-argument':
            throw PaymentException('Invalid product payment information');
          case 'permission-denied':
            throw PaymentException('Not authorized to make payment');
          case 'unavailable':
            throw PaymentException('Payment service temporarily unavailable');
          default:
            throw PaymentException('Unable to process product payment');
        }
      }
      throw PaymentException('Product payment failed: ${e.toString()}');
    }
  }

  /// Create payment intent for event ticket purchase
  static Future<String> createTicketPaymentIntent({
    required TicketPaymentConfig config,
    required String customerEmail,
    required String userId,
  }) async {
    try {

      final callable = FirebaseFunctions.instance.httpsCallable('createTicketPaymentIntent');
      final result = await callable.call({
        'config': config.toJson(),
        'customerEmail': customerEmail,
        'userId': userId,
        'environment': dotenv.env['ENVIRONMENT'] ?? 'staging',
      }).timeout(_defaultTimeout);

      final data = result.data as Map<String, dynamic>;
      final clientSecret = data['client_secret'] as String?;

      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Invalid payment intent response from server');
      }

      return clientSecret;
    } catch (e) {
      if (e is FirebaseFunctionsException) {
        switch (e.code) {
          case 'invalid-argument':
            throw PaymentException('Invalid ticket purchase information');
          case 'permission-denied':
            throw PaymentException('Not authorized to purchase tickets');
          case 'unavailable':
            throw PaymentException('Ticket service temporarily unavailable');
          case 'sold-out':
            throw PaymentException('Tickets are sold out');
          default:
            throw PaymentException('Unable to process ticket purchase');
        }
      }
      throw PaymentException('Ticket purchase failed: ${e.toString()}');
    }
  }

  /// Process product payment with Payment Sheet
  static Future<void> processProductPaymentWithSheet({
    required ProductPaymentConfig config,
    required String customerEmail,
    required String userId,
  }) async {
    if (isWebPlatform) {
      print('🔴 [PAYMENT_SERVICE] Cannot use Payment Sheet on web');
      throw PaymentException('Payment Sheet is not supported on web. Use checkout redirect instead.');
    }

    try {
      // Step 1: Create product payment intent
      final clientSecret = await createProductPaymentIntent(
        config: config,
        customerEmail: customerEmail,
        userId: userId,
      );

      // Step 2: Initialize Payment Sheet
      await initPaymentSheet(
        clientSecret: clientSecret,
        customerEmail: customerEmail,
        merchantDisplayName: 'HiPop Markets',
      );

      // Step 3: Present Payment Sheet
      await presentPaymentSheet();

    } catch (e) {
      print('🔴 [PAYMENT_SERVICE] ===== PRODUCT PAYMENT FLOW FAILED =====');
      print('🔴 [PAYMENT_SERVICE] Error: $e');
      rethrow;
    }
  }

  /// Process product payment with Stripe Checkout (Web only)
  static Future<Map<String, dynamic>> processProductPaymentWeb({
    required ProductPaymentConfig config,
    required String customerEmail,
    required String userId,
    required String successUrl,
    required String cancelUrl,
  }) async {
    if (!isWebPlatform) {
      throw PaymentException('Checkout Sessions are only supported on web. Use Payment Sheet for mobile.');
    }

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('createProductCheckoutSession');

      final result = await callable.call({
        'config': config.toJson(),
        'customerEmail': customerEmail,
        'userId': userId,
        'successUrl': successUrl,
        'cancelUrl': cancelUrl,
        'environment': dotenv.env['ENVIRONMENT'] ?? 'staging',
      }).timeout(_defaultTimeout);

      final data = result.data as Map<String, dynamic>;
      final checkoutUrl = data['url'] as String?;
      final sessionId = data['sessionId'] as String?;
      final orderId = data['orderId'] as String?;

      if (checkoutUrl == null) {
        throw PaymentException('No checkout URL returned');
      }

      // Launch Stripe Checkout in the browser
      final uri = Uri.parse(checkoutUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw PaymentException('Could not launch checkout URL');
      }

      return {
        'sessionId': sessionId,
        'orderId': orderId,
        'url': checkoutUrl,
      };
    } catch (e) {
      if (e is PaymentException) {
        rethrow;
      }
      throw PaymentException('Failed to create checkout session: ${e.toString()}');
    }
  }

  /// Process ticket payment with Payment Sheet
  static Future<void> processTicketPaymentWithSheet({
    required TicketPaymentConfig config,
    required String customerEmail,
    required String userId,
  }) async {
    if (isWebPlatform) {
      throw PaymentException('Payment Sheet is not supported on web. Use checkout redirect instead.');
    }

    try {
      // Step 1: Create ticket payment intent
      final clientSecret = await createTicketPaymentIntent(
        config: config,
        customerEmail: customerEmail,
        userId: userId,
      );

      // Step 2: Initialize Payment Sheet
      await initPaymentSheet(
        clientSecret: clientSecret,
        customerEmail: customerEmail,
        merchantDisplayName: 'HiPop Markets',
      );

      // Step 3: Present Payment Sheet
      await presentPaymentSheet();

    } catch (e) {
      rethrow;
    }
  }

  /// Create payment intent for vendor application
  static Future<String> createVendorApplicationPaymentIntent({
    required VendorApplicationPaymentConfig config,
    required String customerEmail,
    required String userId,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createVendorApplicationPaymentIntent');

      final result = await callable.call({
        'config': config.toJson(),
        'customerEmail': customerEmail,
        'userId': userId,
        'environment': dotenv.env['ENVIRONMENT'] ?? 'staging',
      }).timeout(_defaultTimeout);

      final data = result.data as Map<String, dynamic>;
      final clientSecret = data['client_secret'] as String?;

      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Invalid payment intent response from server');
      }

      return clientSecret;
    } catch (e) {
      if (e is FirebaseFunctionsException) {
        switch (e.code) {
          case 'invalid-argument':
            throw PaymentException('Invalid application payment information');
          case 'permission-denied':
            throw PaymentException('Not authorized to make this payment');
          case 'unavailable':
            throw PaymentException('Payment service temporarily unavailable');
          case 'not-found':
            throw PaymentException('Application not found');
          case 'failed-precondition':
            throw PaymentException(e.message ?? 'Application is not ready for payment');
          default:
            throw PaymentException('Unable to process application payment');
        }
      }
      throw PaymentException('Application payment failed: ${e.toString()}');
    }
  }

  /// Create checkout session for vendor application (Web only)
  static Future<String> createVendorApplicationCheckoutSession({
    required VendorApplicationPaymentConfig config,
    required String customerEmail,
    required String userId,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'createVendorApplicationCheckoutSession'
      );

      // Create success/cancel URLs
      final successUrl = kIsWeb
          ? '${Uri.base.origin}/#/vendor/applications/payment-success?application_id=${config.applicationId}'
          : 'hipop://vendor/applications/payment-success?application_id=${config.applicationId}';

      final cancelUrl = kIsWeb
          ? '${Uri.base.origin}/#/vendor/applications/payment-cancel'
          : 'hipop://vendor/applications/payment-cancel';

      final result = await callable.call({
        'config': config.toJson(),
        'customerEmail': customerEmail,
        'userId': userId,
        'successUrl': successUrl,
        'cancelUrl': cancelUrl,
        'environment': dotenv.env['ENVIRONMENT'] ?? 'staging',
      }).timeout(_defaultTimeout);

      final data = result.data as Map<String, dynamic>;
      final checkoutUrl = data['url'] as String?;

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('Invalid checkout session response from server');
      }

      return checkoutUrl;
    } catch (e) {
      if (e is FirebaseFunctionsException) {
        switch (e.code) {
          case 'invalid-argument':
            throw PaymentException('Invalid application payment information');
          case 'permission-denied':
            throw PaymentException('Not authorized to make this payment');
          case 'unavailable':
            throw PaymentException('Payment service temporarily unavailable');
          case 'not-found':
            throw PaymentException('Application not found');
          case 'failed-precondition':
            throw PaymentException(e.message ?? 'Application is not ready for payment');
          default:
            throw PaymentException('Unable to create checkout session');
        }
      }
      rethrow;
    }
  }

  /// Process vendor application payment with Payment Sheet (Mobile only)
  static Future<void> processVendorApplicationPaymentWithSheet({
    required VendorApplicationPaymentConfig config,
    required String customerEmail,
    required String userId,
  }) async {
    if (isWebPlatform) {
      throw PaymentException('Payment Sheet is not supported on web. Use checkout redirect instead.');
    }

    try {
      // Step 1: Create vendor application payment intent
      final clientSecret = await createVendorApplicationPaymentIntent(
        config: config,
        customerEmail: customerEmail,
        userId: userId,
      );

      // Step 2: Initialize Payment Sheet
      await initPaymentSheet(
        clientSecret: clientSecret,
        customerEmail: customerEmail,
        merchantDisplayName: 'HiPop Markets',
      );

      // Step 3: Present Payment Sheet
      await presentPaymentSheet();

    } catch (e) {
      rethrow;
    }
  }

  /// Calculate platform fee (6% of subtotal) for preorders
  static double calculatePlatformFee(double subtotal) {
    return PaymentConstants.calculatePreorderPlatformFee(subtotal);
  }

  /// Calculate vendor payout (94% of subtotal) after platform fee
  static double calculateVendorPayout(double subtotal) {
    return subtotal - PaymentConstants.calculatePreorderPlatformFee(subtotal);
  }

  /// Calculate organizer platform fee (10% of total) for vendor applications
  static double calculateOrganizerPlatformFee(double total) {
    return PaymentConstants.calculateApplicationPlatformFee(total);
  }

  /// Calculate organizer payout (90% of total) for vendor applications
  static double calculateOrganizerPayout(double total) {
    return PaymentConstants.calculateApplicationOrganizerPayout(total);
  }
}

/// Custom exception for payment errors
class PaymentException implements Exception {
  final String message;
  
  const PaymentException(this.message);
  
  @override
  String toString() => 'PaymentException: $message';
}

/// Promo code validation result
class PromoCodeValidation {
  final bool isValid;
  final double? discountPercent;
  final double? discountAmount;
  final String? description;
  final String? errorMessage;

  const PromoCodeValidation({
    required this.isValid,
    this.discountPercent,
    this.discountAmount,
    this.description,
    this.errorMessage,
  });
}

/// Subscription pricing information
class SubscriptionPricing {
  final String priceId;
  final double amount;
  final String currency;
  final String interval;
  final String name;
  final String description;
  final List<String> features;

  const SubscriptionPricing({
    required this.priceId,
    required this.amount,
    required this.currency,
    required this.interval,
    required this.name,
    required this.description,
    required this.features,
  });

  String get formattedAmount => '\$${amount.toStringAsFixed(2)}';
  String get displayName => '$name - $formattedAmount/$interval';
}

/// Product payment configuration - Simplified for preorder-only
class ProductPaymentConfig {
  final String vendorId;
  final String vendorName;
  final List<String> productIds;
  final Map<String, int>? quantities; // Product ID to quantity mapping
  final Map<String, Map<String, dynamic>>? productDetails; // Product details for order items
  final double subtotal;
  final double platformFee; // 6% fee for preorders
  final double total;
  final String? orderId; // Order ID if created
  final String? marketId; // Optional for non-market popups
  final String? marketName; // Optional for non-market popups
  final String pickupLocation;
  final DateTime? pickupStartTime;
  final DateTime? pickupEndTime;
  final String? pickupTimeSlot; // Deprecated - use times instead
  final String? customerNotes;

  const ProductPaymentConfig({
    required this.vendorId,
    required this.vendorName,
    required this.productIds,
    this.quantities,
    this.productDetails,
    required this.subtotal,
    required this.platformFee,
    required this.total,
    this.orderId,
    this.marketId,
    this.marketName,
    required this.pickupLocation,
    this.pickupStartTime,
    this.pickupEndTime,
    this.pickupTimeSlot,
    this.customerNotes,
  });

  // Backward compatibility
  DateTime get pickupDate => pickupStartTime ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'vendorId': vendorId,
    'vendorName': vendorName,
    'productIds': productIds,
    'quantities': quantities,
    'productDetails': productDetails,
    'subtotal': subtotal,
    'platformFee': platformFee,
    'total': total,
    'orderId': orderId,
    'marketId': marketId,
    'marketName': marketName,
    'pickupLocation': pickupLocation,
    'pickupDate': pickupDate.toIso8601String(), // Backward compatibility
    'pickupStartTime': pickupStartTime?.toIso8601String(),
    'pickupEndTime': pickupEndTime?.toIso8601String(),
    'pickupTimeSlot': pickupTimeSlot,
    'customerNotes': customerNotes,
  };
}

/// Event ticket payment configuration
class TicketPaymentConfig {
  final String eventId;
  final String eventName;
  final String organizerId;
  final String organizerName;
  final int quantity;
  final double pricePerTicket;
  final double subtotal;
  final double platformFee; // 6% fee
  final double total;
  final DateTime eventDate;
  final String? ticketType;

  const TicketPaymentConfig({
    required this.eventId,
    required this.eventName,
    required this.organizerId,
    required this.organizerName,
    required this.quantity,
    required this.pricePerTicket,
    required this.subtotal,
    required this.platformFee,
    required this.total,
    required this.eventDate,
    this.ticketType,
  });

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'eventName': eventName,
    'organizerId': organizerId,
    'organizerName': organizerName,
    'quantity': quantity,
    'pricePerTicket': pricePerTicket,
    'subtotal': subtotal,
    'platformFee': platformFee,
    'total': total,
    'eventDate': eventDate.toIso8601String(),
    'ticketType': ticketType,
  };
}

/// Vendor application payment configuration
class VendorApplicationPaymentConfig {
  final String applicationId;
  final String vendorId;
  final String marketId;
  final String marketName;
  final String organizerId;
  final double applicationFee;
  final double boothFee;
  final double total;
  final double platformFee;
  final double organizerPayout;

  const VendorApplicationPaymentConfig({
    required this.applicationId,
    required this.vendorId,
    required this.marketId,
    required this.marketName,
    required this.organizerId,
    required this.applicationFee,
    required this.boothFee,
    required this.total,
    required this.platformFee,
    required this.organizerPayout,
  });

  Map<String, dynamic> toJson() => {
    'applicationId': applicationId,
    'vendorId': vendorId,
    'marketId': marketId,
    'marketName': marketName,
    'organizerId': organizerId,
    'applicationFee': applicationFee,
    'boothFee': boothFee,
    'total': total,
    'platformFee': platformFee,
    'organizerPayout': organizerPayout,
  };
}