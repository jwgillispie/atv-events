import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/shopper/models/basket_item.dart';
import 'package:hipop/features/shared/models/order.dart' as app_order;
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Order confirmation screen with QR code
class OrderConfirmationScreen extends StatefulWidget {
  final String orderId;
  final List<BasketItem>? items;

  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
    this.items,
  });

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  app_order.Order? _order;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    _loadOrder();
    _animationController.forward();

    // Haptic feedback for success
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _order = app_order.Order.fromFirestore(doc);
          _isLoading = false;
        });
      }
    } catch (e) {
      // If we can't load from Firestore, create a mock order from items
      if (widget.items != null && mounted) {
        setState(() {
          _order = _createMockOrder();
          _isLoading = false;
        });
      }
    }
  }

  app_order.Order _createMockOrder() {
    final items = widget.items!;
    final subtotal = items.fold(0.0, (sum, item) => sum + (item.totalPrice ?? 0.0));
    final platformFee = subtotal * 0.06;
    final total = subtotal + platformFee;

    return app_order.Order(
      id: widget.orderId,
      orderNumber: app_order.Order.generateOrderNumber(),
      status: app_order.OrderStatus.paid,
      customerId: 'current_user',
      customerEmail: 'user@example.com',
      customerName: 'Customer',
      vendorId: items.first.product.vendorId,
      vendorName: items.first.product.vendorName,
      marketId: items.first.marketId,
      marketName: items.first.marketName,
      marketLocation: items.first.popupLocation,
      items: items.map((item) => app_order.OrderItem(
        productId: item.product.id,
        productName: item.product.name,
        productImage: item.product.primaryImageUrl,
        category: item.product.category,
        quantity: item.quantity,
        pricePerUnit: item.product.price ?? 0,
        totalPrice: item.totalPrice ?? 0,
      )).toList(),
      totalItems: items.length,
      subtotal: subtotal,
      platformFee: platformFee,
      total: total,
      pickupDate: items.first.popupDateTime,
      pickupTimeSlot: items.first.selectedPickupSlot?.label,
      qrCode: app_order.Order.generateQRCode(widget.orderId),
      paidAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  void _shareOrder() {
    if (_order == null) return;

    final message = '''
🛍️ HiPop Order Confirmation

Order #${_order!.orderNumber}
Vendor: ${_order!.vendorName}
Market: ${_order!.marketName}
Pickup: ${DateFormat('MMM d, y').format(_order!.pickupDate)}
${_order!.pickupTimeSlot != null ? 'Time: ${_order!.pickupTimeSlot}' : ''}
Total: \$${_order!.total.toStringAsFixed(2)}

Show this QR code at pickup!
''';

    Share.share(message, subject: 'HiPop Order #${_order!.orderNumber}');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_order == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: HiPopColors.errorPlum,
              ),
              const SizedBox(height: 16),
              const Text(
                'Order not found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      backgroundColor: HiPopColors.lightBackground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Success Header
            SliverToBoxAdapter(
              child: Container(
                color: HiPopColors.successGreen,
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 48,
                          color: HiPopColors.successGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Order Confirmed!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Order #${_order!.orderNumber}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // QR Code Section
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Show this at pickup',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: HiPopColors.lightBorder,
                          width: 2,
                        ),
                      ),
                      child: QrImageView(
                        data: _order!.qrCode,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _order!.orderNumber,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: HiPopColors.lightTextSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pickup Details
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pickup Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Vendor
                    _buildDetailRow(
                      icon: Icons.store,
                      label: 'Vendor',
                      value: _order!.vendorName,
                    ),
                    const SizedBox(height: 12),

                    // Market
                    _buildDetailRow(
                      icon: Icons.location_on,
                      label: 'Market',
                      value: _order!.marketName,
                    ),
                    const SizedBox(height: 12),

                    // Date
                    _buildDetailRow(
                      icon: Icons.calendar_today,
                      label: 'Date',
                      value: DateFormat('EEEE, MMMM d, y').format(_order!.pickupDate),
                    ),

                    // Time Slot
                    if (_order!.pickupTimeSlot != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.access_time,
                        label: 'Time',
                        value: _order!.pickupTimeSlot!,
                      ),
                    ],

                    // Location
                    if (_order!.marketLocation.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.map,
                        label: 'Location',
                        value: _order!.marketLocation,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Order Summary
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Items
                    ..._order!.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.quantity}x ${item.productName}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: HiPopColors.darkTextPrimary,
                              ),
                            ),
                          ),
                          Text(
                            currencyFormat.format(item.totalPrice),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: HiPopColors.darkTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    )),

                    const Divider(),
                    const SizedBox(height: 8),

                    // Subtotal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Subtotal',
                          style: TextStyle(
                            fontSize: 14,
                            color: HiPopColors.lightTextSecondary,
                          ),
                        ),
                        Text(
                          currencyFormat.format(_order!.subtotal),
                          style: const TextStyle(
                            fontSize: 14,
                            color: HiPopColors.darkTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Service Fee
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Service Fee',
                          style: TextStyle(
                            fontSize: 14,
                            color: HiPopColors.lightTextSecondary,
                          ),
                        ),
                        Text(
                          currencyFormat.format(_order!.platformFee),
                          style: const TextStyle(
                            fontSize: 14,
                            color: HiPopColors.darkTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Paid',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: HiPopColors.darkTextPrimary,
                          ),
                        ),
                        Text(
                          currencyFormat.format(_order!.total),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: HiPopColors.successGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Share Button
                    OutlinedButton.icon(
                      onPressed: _shareOrder,
                      icon: const Icon(Icons.share),
                      label: const Text('Share Order'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // View Orders Button
                    ElevatedButton.icon(
                      onPressed: () => context.go('/orders'),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('View My Orders'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: HiPopColors.primaryDeepSage,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Continue Shopping Button
                    TextButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Continue Shopping'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: HiPopColors.lightTextTertiary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: HiPopColors.lightTextTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}