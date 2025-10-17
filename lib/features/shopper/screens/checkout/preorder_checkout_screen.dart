import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/core/constants/ui_constants.dart';
import 'package:hipop/features/premium/services/payment_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:hipop/features/shared/models/product.dart';
import 'package:hipop/features/shared/widgets/common/loading_overlay.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Simplified checkout screen for single product preorders
class PreorderCheckoutScreen extends StatefulWidget {
  final Product product;
  final String vendorId;
  final String vendorName;
  final String? popupId;
  final String? popupLocation;
  final DateTime? popupStartTime;
  final DateTime? popupEndTime;

  const PreorderCheckoutScreen({
    super.key,
    required this.product,
    required this.vendorId,
    required this.vendorName,
    this.popupId,
    this.popupLocation,
    this.popupStartTime,
    this.popupEndTime,
  });

  @override
  State<PreorderCheckoutScreen> createState() => _PreorderCheckoutScreenState();
}

class _PreorderCheckoutScreenState extends State<PreorderCheckoutScreen> {
  bool _isProcessing = false;
  int _quantity = 1;
  final _notesController = TextEditingController();
  String? _orderId;
  bool _paymentComplete = false;

  double get _subtotal => (widget.product.price ?? 0) * _quantity;
  double get _platformFee => _subtotal * 0.06; // 6% platform fee
  double get _total => _subtotal + _platformFee; // Subtotal + 6% service fee

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    final authState = context.read<AuthBloc>().state;

    if (authState is! Authenticated) {
      _showErrorSnackBar('Please sign in to continue');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Create order document in Firestore first
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();
      _orderId = orderRef.id;

      final orderData = {
        'id': _orderId,
        'userId': authState.user.uid,
        'userEmail': authState.user.email,
        'vendorId': widget.vendorId,
        'vendorName': widget.vendorName,
        'marketId': widget.product.marketId ?? widget.popupId ?? 'direct-purchase',
        'marketName': widget.product.marketName ?? widget.popupLocation ?? 'Direct Purchase',
        'marketLocation': widget.popupLocation ?? 'Location TBD',
        'productId': widget.product.id,
        'productName': widget.product.name,
        'productImage': widget.product.primaryImageUrl,
        'quantity': _quantity,
        'unitPrice': widget.product.price,
        'subtotal': _subtotal,
        'platformFee': _platformFee,
        'total': _total,
        'popupId': widget.popupId,
        'popupLocation': widget.popupLocation ?? 'Location TBD',
        'popupStartTime': widget.popupStartTime != null
            ? Timestamp.fromDate(widget.popupStartTime!)
            : null,
        'popupEndTime': widget.popupEndTime != null
            ? Timestamp.fromDate(widget.popupEndTime!)
            : null,
        'customerNotes': _notesController.text.trim(),
        'status': 'pending_payment',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await orderRef.set(orderData);

      // Initialize Stripe
      await PaymentService.initialize();

      // Create Stripe Connect payment intent via Cloud Function
      debugPrint('🟣 [Checkout] Creating Stripe Connect payment intent...');
      final callable = FirebaseFunctions.instance.httpsCallable('createPreorderPaymentIntent');

      final result = await callable.call({
        'vendorId': widget.vendorId,
        'items': [
          {
            'productId': widget.product.id,
            'productName': widget.product.name ?? 'Product',
            'quantity': _quantity,
            'unitPrice': widget.product.price ?? 0,
            'totalPrice': _subtotal,
          }
        ],
        'totalAmount': _subtotal, // Send subtotal, backend adds 6% fee
        'marketId': widget.popupId,
        'marketName': widget.popupLocation,
      });

      final data = result.data as Map<String, dynamic>;
      final clientSecret = data['clientSecret'] as String;
      final connectOrderId = data['orderId'] as String;

      debugPrint('✅ [Checkout] Payment intent created: ${data['paymentIntentId']}');
      debugPrint('💰 [Checkout] Platform fee: \$${data['platformFee']}');
      debugPrint('💰 [Checkout] Vendor payout: \$${data['vendorPayout']}');

      // Confirm payment with Stripe
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );

      debugPrint('✅ [Checkout] Payment confirmed successfully');

      // Update our local order with Connect payment details
      await orderRef.update({
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'stripePaymentIntentId': data['paymentIntentId'],
        'stripeConnectOrderId': connectOrderId,
        'platformFeeActual': data['platformFee'],
        'vendorPayoutActual': data['vendorPayout'],
      });

      // Show success state
      if (mounted) {
        setState(() {
          _paymentComplete = true;
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [Checkout] Payment failed: $e');

      // If payment fails, delete the order
      if (_orderId != null) {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(_orderId)
            .delete();
      }

      // Better error messages
      String errorMessage = e.toString();
      if (errorMessage.contains('not connected Stripe')) {
        errorMessage = 'This vendor hasn\'t set up payment processing yet. Please contact them or try a different vendor.';
      } else if (errorMessage.contains('not fully verified')) {
        errorMessage = 'This vendor is still completing their payment setup. Please try again in a few hours.';
      } else if (errorMessage.contains('StripeException')) {
        errorMessage = 'Payment failed. Please check your card details and try again.';
      } else {
        errorMessage = errorMessage
            .replaceAll('PaymentException: ', '')
            .replaceAll('Exception: ', '')
            .replaceAll('[firebase_functions/internal]', '');
      }

      _showErrorSnackBar(errorMessage);
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: HiPopColors.errorPlum,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_paymentComplete) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        backgroundColor: HiPopColors.darkSurface,
        elevation: 0,
        title: const Text(
          'Complete Preorder',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Card
                _buildProductCard(),

                // Pickup Info
                _buildPickupInfo(),

                // Quantity Selector
                _buildQuantitySelector(),

                // Price Breakdown
                _buildPriceBreakdown(),

                // Customer Notes
                _buildNotesSection(),
              ],
            ),
          ),

          // Bottom Payment Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildPaymentButton(),
          ),

          // Loading overlay
          if (_isProcessing)
            LoadingOverlay(
              message: 'Processing payment...',
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          if (widget.product.primaryImageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: CachedNetworkImage(
                imageUrl: widget.product.primaryImageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: HiPopColors.darkSurfaceVariant,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: HiPopColors.shopperAccent,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: HiPopColors.darkSurfaceVariant,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'by ${widget.vendorName}',
                  style: TextStyle(
                    color: HiPopColors.shopperAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.product.description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.product.description!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupInfo() {
    if (widget.popupStartTime == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            HiPopColors.shopperAccent.withOpacity(0.2),
            HiPopColors.shopperAccent.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HiPopColors.shopperAccent.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            color: HiPopColors.shopperAccent,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pickup Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.popupLocation ?? 'Location TBD',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.popupStartTime != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('MMM d, h:mm a').format(widget.popupStartTime!)} - ${DateFormat('h:mm a').format(widget.popupEndTime ?? widget.popupStartTime!.add(const Duration(hours: 4)))}',
                    style: TextStyle(
                      color: HiPopColors.shopperAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Quantity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: HiPopColors.shopperAccent,
                disabledColor: Colors.white30,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: HiPopColors.darkSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_quantity',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _quantity++),
                icon: const Icon(Icons.add_circle_outline),
                color: HiPopColors.shopperAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildPriceRow(
            'Subtotal ($_quantity item${_quantity > 1 ? 's' : ''})',
            currencyFormat.format(_subtotal),
            isSubtle: true,
          ),
          const SizedBox(height: 8),
          _buildPriceRow(
            'Platform Fee',
            currencyFormat.format(_platformFee),
            isSubtle: true,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Colors.white24),
          ),
          _buildPriceRow(
            'Total',
            currencyFormat.format(_total),
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isSubtle = false, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isSubtle ? Colors.white70 : Colors.white,
            fontSize: isSubtle ? 14 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isBold ? HiPopColors.shopperAccent : Colors.white,
            fontSize: isBold ? 18 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Special Instructions (Optional)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Any special requests or notes for the vendor...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: HiPopColors.darkSurfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isProcessing ? null : _processPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: HiPopColors.shopperAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pay ${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(_total)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: HiPopColors.successGreen.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: HiPopColors.successGreen,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 24),

                // Success Message
                const Text(
                  'Order Confirmed!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Order #${_orderId?.substring(0, 8).toUpperCase() ?? 'XXXXX'}',
                  style: TextStyle(
                    color: HiPopColors.shopperAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),

                // QR Code for pickup
                if (_orderId != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: _orderId!,
                      version: QrVersions.auto,
                      size: 200,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Show this QR code at pickup',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Pickup Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: HiPopColors.shopperAccent.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: HiPopColors.shopperAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.popupLocation ?? 'Location TBD',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.popupStartTime != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              color: HiPopColors.shopperAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormat('EEEE, MMM d, h:mm a').format(widget.popupStartTime!),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // Navigate to order details
                          context.go('/orders/$_orderId');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HiPopColors.shopperAccent,
                          side: BorderSide(color: HiPopColors.shopperAccent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('View Order'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Go back to feed
                          context.go('/');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HiPopColors.shopperAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Continue Shopping'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}