/// Centralized payment and fee constants for the Hipop platform
///
/// This class contains all platform fees, processing fees, and helper methods
/// for consistent fee calculations across the application.
///
/// IMPORTANT: Keep in sync with functions/src/constants/payment-constants.ts
class PaymentConstants {
  // Prevent instantiation
  PaymentConstants._();

  // ========== PLATFORM FEES (as decimal percentages) ==========

  /// Platform fee for event tickets (6%)
  /// Applied on top of ticket price - customer pays this
  static const double ticketPlatformFeePercent = 0.06;

  /// Platform fee for vendor preorders (6%)
  /// Applied on top of product subtotal - customer pays this
  static const double preorderPlatformFeePercent = 0.06;

  /// Platform fee for vendor application fees (10%)
  /// Deducted from total fee - Hipop keeps 10%, organizer gets 90%
  static const double applicationPlatformFeePercent = 0.10;

  // ========== STRIPE PROCESSING FEES ==========

  /// Stripe processing percentage (2.9%)
  /// This is approximate - actual varies by card type and country
  static const double stripeProcessingPercent = 0.029;

  /// Stripe fixed fee per transaction ($0.30)
  static const double stripeFixedFee = 0.30;

  // ========== MARKET FEES ==========

  /// Default market fee percentage (10%)
  /// What organizers typically charge vendors at markets
  static const double defaultMarketFeePercent = 0.10;

  // ========== HELPER METHODS ==========

  /// Calculate platform fee for tickets
  ///
  /// Example: $100 ticket → $6 platform fee
  static double calculateTicketPlatformFee(double subtotal) {
    return subtotal * ticketPlatformFeePercent;
  }

  /// Calculate total ticket charge (subtotal + platform fee)
  ///
  /// Example: $100 ticket → $106 total charge
  static double calculateTicketTotal(double subtotal) {
    return subtotal + calculateTicketPlatformFee(subtotal);
  }

  /// Calculate platform fee for preorders
  ///
  /// Example: $100 products → $6 platform fee
  static double calculatePreorderPlatformFee(double subtotal) {
    return subtotal * preorderPlatformFeePercent;
  }

  /// Calculate total preorder charge (subtotal + platform fee)
  ///
  /// Example: $100 products → $106 total charge
  static double calculatePreorderTotal(double subtotal) {
    return subtotal + calculatePreorderPlatformFee(subtotal);
  }

  /// Calculate platform fee for vendor applications
  ///
  /// Example: $100 application fee → $10 goes to Hipop
  static double calculateApplicationPlatformFee(double totalFee) {
    return totalFee * applicationPlatformFeePercent;
  }

  /// Calculate organizer payout for vendor applications
  ///
  /// Example: $100 application fee → $90 goes to organizer
  static double calculateApplicationOrganizerPayout(double totalFee) {
    return totalFee * (1 - applicationPlatformFeePercent);
  }

  /// Calculate Stripe processing fee for a transaction
  ///
  /// Example: $106 charge → ~$3.37 Stripe fee
  static double calculateStripeProcessingFee(double totalAmount) {
    return (totalAmount * stripeProcessingPercent) + stripeFixedFee;
  }

  /// Calculate Hipop's net revenue after Stripe fees
  ///
  /// Example: $6 platform fee on $106 charge → $6 - $3.37 = $2.63 net
  static double calculateHipopNetRevenue(double platformFee, double totalAmount) {
    return platformFee - calculateStripeProcessingFee(totalAmount);
  }

  /// Calculate market fee on vendor sales
  ///
  /// Example: $1000 sales at 10% → $100 market fee
  static double calculateMarketFee(double revenue, [double? customFeePercent]) {
    final feePercent = customFeePercent ?? defaultMarketFeePercent;
    return revenue * feePercent;
  }
}
