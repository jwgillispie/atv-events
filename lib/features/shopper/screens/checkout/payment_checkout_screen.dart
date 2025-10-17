import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/premium/services/payment_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:atv_events/features/shopper/models/basket_item.dart';
import 'package:atv_events/features/shared/widgets/common/loading_overlay.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import 'package:go_router/go_router.dart';

/// Payment checkout screen for basket items
class PaymentCheckoutScreen extends StatefulWidget {
  final List<BasketItem> items;
  final String marketId;
  final String marketName;
  final String vendorId;
  final String vendorName;

  const PaymentCheckoutScreen({
    super.key,
    required this.items,
    required this.marketId,
    required this.marketName,
    required this.vendorId,
    required this.vendorName,
  });

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  bool _isProcessing = false;
  String? _selectedPickupSlot;
  final _notesController = TextEditingController();
  DateTime? _popupStartTime;
  DateTime? _popupEndTime;

  double get _subtotal {
    return widget.items.fold(
      0.0,
      (sum, item) => sum + (item.totalPrice ?? 0.0),
    );
  }

  double get _platformFee => _subtotal * 0.06; // 6% platform fee
  double get _total => _subtotal + _platformFee; // Subtotal + 6% service fee

  @override
  void initState() {
    super.initState();
    _loadPopupTimes();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPopupTimes() async {
    if (widget.items.isEmpty) return;

    // Get the vendor post ID from the first item
    final vendorPostId = widget.items.first.vendorPostId;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('vendor_posts')
          .doc(vendorPostId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _popupStartTime = (data['popUpStartDateTime'] as Timestamp).toDate();
          _popupEndTime = (data['popUpEndDateTime'] as Timestamp).toDate();
        });
      }
    } catch (e) {
      print('Error loading popup times: $e');
    }
  }

  List<Map<String, String>> _generateTimeSlots() {
    if (_popupStartTime == null || _popupEndTime == null) {
      // Fallback to default slots if times not loaded
      return [
        {'label': 'Morning', 'time': '9:00 AM - 12:00 PM'},
        {'label': 'Midday', 'time': '12:00 PM - 3:00 PM'},
        {'label': 'Afternoon', 'time': '3:00 PM - 6:00 PM'},
      ];
    }

    final List<Map<String, String>> slots = [];
    final duration = _popupEndTime!.difference(_popupStartTime!);
    final hoursTotal = duration.inHours;

    // Generate 1-hour time slots within popup hours
    DateTime slotStart = _popupStartTime!;
    while (slotStart.isBefore(_popupEndTime!)) {
      DateTime slotEnd = slotStart.add(const Duration(hours: 1));
      if (slotEnd.isAfter(_popupEndTime!)) {
        slotEnd = _popupEndTime!;
      }

      final startStr = DateFormat('h:mm a').format(slotStart);
      final endStr = DateFormat('h:mm a').format(slotEnd);

      slots.add({
        'label': startStr,
        'time': '$startStr - $endStr',
      });

      slotStart = slotEnd;
    }

    // If popup is less than 2 hours, just show one slot for the entire duration
    if (hoursTotal <= 2) {
      final startStr = DateFormat('h:mm a').format(_popupStartTime!);
      final endStr = DateFormat('h:mm a').format(_popupEndTime!);
      return [{
        'label': 'During Event',
        'time': '$startStr - $endStr',
      }];
    }

    return slots;
  }

  Future<void> _processPayment() async {
    final authState = context.read<AuthBloc>().state;

    if (authState is! Authenticated) {
      print('🔴 [PAYMENT] User not authenticated');
      _showErrorSnackBar('Please sign in to continue');
      return;
    }

    if (_selectedPickupSlot == null) {
      print('🔴 [PAYMENT] No pickup slot selected');
      _showErrorSnackBar('Please select a pickup time');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Check inventory availability first
      for (final item in widget.items) {
        if (item.product.id.isEmpty || item.vendorPostId == null) {
          print('⚠️ [PAYMENT] Skipping item with empty ID: ${item.product.name}');
          continue; // Skip if no valid IDs
        }


        final productDoc = await FirebaseFirestore.instance
            .collection('vendor_posts')
            .doc(item.vendorPostId)
            .collection('products')
            .doc(item.product.id)
            .get();

        if (productDoc.exists) {
          final available = productDoc.data()?['quantityAvailable'] as int?;

          // If quantityAvailable is set and insufficient
          if (available != null && available < item.quantity) {
            print('🔴 [PAYMENT] Insufficient inventory for ${item.product.name}. Available: $available, Requested: ${item.quantity}');
            _showErrorSnackBar(
              available == 0
                ? '${item.product.name} is sold out!'
                : 'Only $available ${item.product.name} left!'
            );
            setState(() => _isProcessing = false);
            return;
          }
        } else {
          print('⚠️ [PAYMENT] Product document not found for ${item.product.name}');
        }
      }


      // Get the first item's pickup date (all items should have same date)
      final pickupDate = widget.items.first.popupDateTime;

      // Create payment configuration with product details
      final Map<String, int> quantities = {};
      final Map<String, Map<String, dynamic>> productDetails = {};

      for (var item in widget.items) {
        quantities[item.product.id] = item.quantity;
        productDetails[item.product.id] = {
          'productName': item.product.name,
          'productImage': item.product.primaryImageUrl,
          'category': item.product.category,
          'pricePerUnit': item.product.price ?? 0.0,
          'quantity': item.quantity,
          'totalPrice': item.totalPrice ?? 0.0,
        };
      }


      // Initialize Stripe
      await PaymentService.initialize();

      // Prepare items for Stripe Connect
      final connectItems = widget.items.map((item) => {
        'productId': item.product.id,
        'productName': item.product.name ?? 'Product',
        'quantity': item.quantity,
        'unitPrice': item.product.price ?? 0,
        'totalPrice': item.totalPrice ?? 0,
      }).toList();

      final callable = FirebaseFunctions.instance.httpsCallable('createPreorderPaymentIntent');

      final result = await callable.call({
        'vendorId': widget.vendorId,
        'items': connectItems,
        'totalAmount': _subtotal, // Send subtotal, backend adds 6% fee
        'marketId': widget.marketId,
        'marketName': widget.marketName,
      });

      final data = result.data as Map<String, dynamic>;
      final clientSecret = data['clientSecret'] as String;


      // Confirm payment with Stripe
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );


      // Payment successful - navigate to confirmation
      if (mounted) {
        context.push('/order-confirmation', extra: {
          'orderId': data['orderId'],
          'items': widget.items,
          'paymentIntentId': data['paymentIntentId'],
        });
      }
    } catch (e) {
      print('🔴 [PAYMENT] Payment failed with error: $e');
      print('🔴 [PAYMENT] Error type: ${e.runtimeType}');

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
    } finally {
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        backgroundColor: HiPopColors.darkSurface,
        elevation: 0,
        title: const Text(
          'Checkout',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Order Summary Header
              SliverToBoxAdapter(
                child: Container(
                  color: HiPopColors.darkSurface,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Vendor Info
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: HiPopColors.vendorAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(
                              Icons.store,
                              color: HiPopColors.vendorAccent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.vendorName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  widget.marketName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 16),

                      // Items List
                      const Text(
                        'Order Items',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...widget.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Image
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: HiPopColors.darkSurfaceVariant,
                              ),
                              child: item.product.primaryImageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        item.product.primaryImageUrl!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.image,
                                      color: Colors.white38,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            // Product Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Qty: ${item.quantity}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Price
                            Text(
                              currencyFormat.format(item.totalPrice ?? 0),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),

              // Pickup Time Selection
              SliverToBoxAdapter(
                child: Container(
                  color: HiPopColors.darkSurface,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pickup Time',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _popupStartTime != null && _popupEndTime != null
                            ? '${DateFormat('EEEE, MMMM d').format(widget.items.first.popupDateTime)} • ${DateFormat('h:mm a').format(_popupStartTime!)} - ${DateFormat('h:mm a').format(_popupEndTime!)}'
                            : DateFormat('EEEE, MMMM d, y').format(widget.items.first.popupDateTime),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _generateTimeSlots().map((slot) {
                          final isSelected = _selectedPickupSlot == slot['time'];
                          return ChoiceChip(
                            label: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(slot['label']!),
                                Text(
                                  slot['time']!,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedPickupSlot = selected ? slot['time'] : null;
                              });
                            },
                            backgroundColor: HiPopColors.darkSurfaceVariant,
                            selectedColor: HiPopColors.primaryDeepSage.withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? HiPopColors.primaryDeepSage
                                  : Colors.white60,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              // Customer Notes
              SliverToBoxAdapter(
                child: Container(
                  color: HiPopColors.darkSurface,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Special Instructions (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Any special requests or dietary notes?',
                          hintStyle: const TextStyle(
                            color: Colors.white38,
                          ),
                          filled: true,
                          fillColor: HiPopColors.darkSurfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Payment Summary
              SliverToBoxAdapter(
                child: Container(
                  color: HiPopColors.darkSurface,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Subtotal
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Subtotal',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            currencyFormat.format(_subtotal),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Platform Fee
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Service Fee',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Tooltip(
                                message: 'HiPop charges a 6% service fee to support the platform and vendor payments',
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: HiPopColors.lightTextTertiary.withOpacity(0.2),
                                  ),
                                  child: const Icon(
                                    Icons.info_outline,
                                    size: 12,
                                    color: HiPopColors.lightTextTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            currencyFormat.format(_platformFee),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 12),

                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            currencyFormat.format(_total),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: HiPopColors.primaryDeepSage,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Payment Notice
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HiPopColors.infoBlueGray.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: HiPopColors.infoBlueGray.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 20,
                        color: HiPopColors.infoBlueGray.withOpacity(0.8),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Your payment is secure and processed by Stripe. The vendor receives 94% of the subtotal after the 6% platform fee.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom spacing for button
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),

          // Pay Button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: HiPopColors.darkSurface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HiPopColors.primaryDeepSage,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Pay ${currencyFormat.format(_total)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),

          // Loading overlay
          if (_isProcessing)
            LoadingOverlay(message: 'Processing payment...'),
        ],
      ),
    );
  }
}