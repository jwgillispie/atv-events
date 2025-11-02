import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:rxdart/rxdart.dart';
import '../../../../core/theme/atv_colors.dart';
import '../../../shared/widgets/common/loading_widget.dart';
import '../../../shared/widgets/common/error_widget.dart' as common_error;
import '../../../shared/models/order.dart' as app_order;
import '../../../../utils/firestore_error_logger.dart';

/// Shopper Orders History Screen
/// Shows all past and current orders for the authenticated shopper
/// Including both legacy orders and Stripe Connect preorders
class ShopperOrdersScreen extends StatefulWidget {
  const ShopperOrdersScreen({super.key});

  @override
  State<ShopperOrdersScreen> createState() => _ShopperOrdersScreenState();
}

class _ShopperOrdersScreenState extends State<ShopperOrdersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _customerId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (_customerId == null) {
      return Scaffold(
        backgroundColor: HiPopColors.darkBackground,
        appBar: AppBar(
          title: const Text('My Orders'),
          backgroundColor: HiPopColors.darkSurface,
          foregroundColor: HiPopColors.darkTextPrimary,
        ),
        body: Center(
          child: Text(
            'Please sign in to view orders',
            style: TextStyle(
              color: HiPopColors.darkTextPrimary,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: HiPopColors.darkSurface,
        foregroundColor: HiPopColors.darkTextPrimary,
        elevation: 0,
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: _getMergedOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingWidget());
          }

          if (snapshot.hasError) {
            return Center(
              child: common_error.ErrorDisplayWidget(
                title: 'Error',
                message: 'Failed to load orders',
                onRetry: () {
                  setState(() {});
                },
              ),
            );
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            color: HiPopColors.shopperAccent,
            backgroundColor: HiPopColors.darkSurface,
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final orderData = orders[index];

                // Check if it's a Stripe preorder or legacy order
                if (orderData is QueryDocumentSnapshot) {
                  // This is a preorder from the preorders collection
                  return _StripeOrderCard(
                    orderDoc: orderData,
                    onTap: () {
                      // Navigate to order details
                      context.push('/order/${orderData.id}');
                    },
                  );
                } else {
                  // This is a legacy order (already converted to Order model)
                  final order = orderData as app_order.Order;
                  return _OrderCard(
                    order: order,
                    onTap: () {
                      context.push('/order/${order.id}');
                    },
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  Stream<List<dynamic>> _getMergedOrdersStream() {
    // Stream for legacy orders with error logging
    final legacyOrdersStream = _firestore
        .collection('orders')
        .where('customerId', isEqualTo: _customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
          FirestoreErrorLogger.logError(
            error,
            'ShopperOrdersScreen._getMergedOrdersStream (legacy orders, customerId: $_customerId)'
          );
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => app_order.Order.fromFirestore(doc))
            .toList());

    // Stream for Stripe preorders with error logging
    final stripeOrdersStream = _firestore
        .collection('preorders')
        .where('customerId', isEqualTo: _customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
          FirestoreErrorLogger.logError(
            error,
            'ShopperOrdersScreen._getMergedOrdersStream (Stripe preorders, customerId: $_customerId)'
          );
        })
        .map((snapshot) => snapshot.docs);

    // Combine both streams
    return CombineLatestStream.combine2<List<app_order.Order>,
        List<QueryDocumentSnapshot>, List<dynamic>>(
      legacyOrdersStream,
      stripeOrdersStream,
      (legacy, stripe) {
        final combined = <dynamic>[...legacy, ...stripe];

        // Sort by createdAt descending
        combined.sort((a, b) {
          DateTime aTime;
          DateTime bTime;

          if (a is app_order.Order) {
            aTime = a.createdAt;
          } else {
            final data = (a as QueryDocumentSnapshot).data() as Map<String, dynamic>;
            aTime = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          }

          if (b is app_order.Order) {
            bTime = b.createdAt;
          } else {
            final data = (b as QueryDocumentSnapshot).data() as Map<String, dynamic>;
            bTime = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          }

          return bTime.compareTo(aTime);
        });

        return combined;
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: HiPopColors.darkTextTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No orders yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: HiPopColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your orders will appear here',
            style: TextStyle(
              fontSize: 14,
              color: HiPopColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/shopper'),
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.shopperAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.shopping_bag),
            label: const Text(
              'Start Shopping',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stripe Order Card Widget
class _StripeOrderCard extends StatelessWidget {
  final QueryDocumentSnapshot orderDoc;
  final VoidCallback onTap;

  const _StripeOrderCard({
    required this.orderDoc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final data = orderDoc.data() as Map<String, dynamic>;
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    // Extract order data
    final orderId = orderDoc.id;
    final vendorName = data['vendorName'] ?? 'Unknown Vendor';
    final marketName = data['marketName'] ?? 'Unknown Market';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final totalAmount = (data['totalAmount'] ?? 0.0).toDouble();
    final status = data['status'] ?? 'pending_payment';
    final paymentStatus = data['paymentStatus'];
    final transferId = data['transferId'];
    final items = data['items'] as List<dynamic>? ?? [];

    final statusColor = _getStripeStatusColor(status);
    final statusText = _getStripeStatusText(status, paymentStatus, transferId);

    // Calculate total items
    int totalItems = 0;
    for (var item in items) {
      totalItems += (item['quantity'] ?? 1) as int;
    }

    return Card(
      color: HiPopColors.darkSurface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFF635BFF).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Stripe badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Order #${orderId.substring(0, 8).toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HiPopColors.darkTextPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Stripe badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF635BFF),
                                    const Color(0xFF7B73FF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.bolt,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Stripe',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM d, y • h:mm a').format(createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: HiPopColors.darkTextSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Divider
              Divider(
                color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                height: 1,
              ),
              const SizedBox(height: 12),

              // Vendor & Market Info
              Row(
                children: [
                  const Icon(
                    Icons.store,
                    size: 16,
                    color: HiPopColors.shopperAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      vendorName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: HiPopColors.darkTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: HiPopColors.darkTextSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      marketName,
                      style: TextStyle(
                        fontSize: 13,
                        color: HiPopColors.darkTextSecondary.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Payment method indicator
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.credit_card,
                    size: 16,
                    color: const Color(0xFF635BFF),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Paid via Stripe',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF635BFF),
                    ),
                  ),
                  if (status == 'paid') ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: HiPopColors.successGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Complete',
                      style: TextStyle(
                        fontSize: 11,
                        color: HiPopColors.successGreen,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),

              // Items Summary + Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$totalItems ${totalItems == 1 ? 'item' : 'items'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: HiPopColors.darkTextSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    currencyFormat.format(totalAmount),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.shopperAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStripeStatusColor(String status) {
    switch (status) {
      case 'pending_payment':
        return HiPopColors.warningAmber;
      case 'paid':
        return HiPopColors.successGreen;
      case 'payment_failed':
        return HiPopColors.errorPlum;
      case 'refunded':
        return HiPopColors.errorPlum;
      default:
        return HiPopColors.darkTextSecondary;
    }
  }

  String _getStripeStatusText(String status, String? paymentStatus, String? transferId) {
    switch (status) {
      case 'pending_payment':
        return 'Processing Payment';
      case 'paid':
        // With instant split, status='paid' means payment and transfer both complete
        return 'Payment Complete';
      case 'payment_failed':
        return 'Payment Failed';
      case 'refunded':
        return 'Refunded';
      default:
        return 'Unknown';
    }
  }
}

/// Legacy Order Card Widget
class _OrderCard extends StatelessWidget {
  final app_order.Order order;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final statusColor = _getStatusColor(order.status);
    final statusText = _getStatusText(order.status);
    final isPastPickup = order.pickupDate.isBefore(DateTime.now());

    return Card(
      color: HiPopColors.darkSurface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: HiPopColors.darkBorder,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Order Number + Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Order #${order.orderNumber}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HiPopColors.darkTextPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Legacy badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: HiPopColors.darkTextTertiary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Legacy',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: HiPopColors.darkTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM d, y • h:mm a').format(order.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: HiPopColors.darkTextSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Divider
              Divider(
                color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                height: 1,
              ),
              const SizedBox(height: 12),

              // Vendor & Market Info
              Row(
                children: [
                  const Icon(
                    Icons.store,
                    size: 16,
                    color: HiPopColors.shopperAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.vendorName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: HiPopColors.darkTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: HiPopColors.darkTextSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.marketName,
                      style: TextStyle(
                        fontSize: 13,
                        color: HiPopColors.darkTextSecondary.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Payment method indicator
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.payments,
                    size: 16,
                    color: HiPopColors.darkTextTertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'In-Person Payment',
                    style: TextStyle(
                      fontSize: 13,
                      color: HiPopColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),

              // Pickup Date
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: isPastPickup
                        ? HiPopColors.darkTextTertiary
                        : HiPopColors.shopperAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatPickupDate(order.pickupDate),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isPastPickup ? FontWeight.normal : FontWeight.w600,
                      color: isPastPickup
                          ? HiPopColors.darkTextTertiary
                          : HiPopColors.shopperAccent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Items Summary + Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.totalItems} ${order.totalItems == 1 ? 'item' : 'items'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: HiPopColors.darkTextSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    currencyFormat.format(order.total),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.shopperAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(app_order.OrderStatus status) {
    switch (status) {
      case app_order.OrderStatus.pending:
        return HiPopColors.shopperAccent;
      case app_order.OrderStatus.paid:
      case app_order.OrderStatus.confirmed:
        return HiPopColors.successGreen;
      case app_order.OrderStatus.preparing:
        return HiPopColors.shopperAccent;
      case app_order.OrderStatus.readyForPickup:
        return HiPopColors.successGreen;
      case app_order.OrderStatus.pickedUp:
        return HiPopColors.darkTextTertiary;
      case app_order.OrderStatus.cancelled:
      case app_order.OrderStatus.refunded:
        return HiPopColors.errorPlum;
    }
  }

  String _getStatusText(app_order.OrderStatus status) {
    switch (status) {
      case app_order.OrderStatus.pending:
        return 'Pending';
      case app_order.OrderStatus.paid:
        return 'Paid';
      case app_order.OrderStatus.confirmed:
        return 'Confirmed';
      case app_order.OrderStatus.preparing:
        return 'Preparing';
      case app_order.OrderStatus.readyForPickup:
        return 'Ready';
      case app_order.OrderStatus.pickedUp:
        return 'Completed';
      case app_order.OrderStatus.cancelled:
        return 'Cancelled';
      case app_order.OrderStatus.refunded:
        return 'Refunded';
    }
  }

  String _formatPickupDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Pickup Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day + 1) {
      return 'Pickup Tomorrow';
    } else if (difference.inDays > 0 && difference.inDays <= 7) {
      return 'Pickup ${DateFormat('EEEE').format(date)}';
    } else if (date.isBefore(now)) {
      return DateFormat('MMM d, yyyy').format(date);
    } else {
      return 'Pickup ${DateFormat('MMM d').format(date)}';
    }
  }
}