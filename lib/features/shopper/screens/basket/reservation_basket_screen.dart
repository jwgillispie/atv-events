import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/core/constants/ui_constants.dart';
import 'package:atv_events/features/shopper/blocs/basket/basket_bloc.dart';
import 'package:atv_events/features/shopper/blocs/basket/basket_event.dart';
import 'package:atv_events/features/shopper/blocs/basket/basket_state.dart';
import 'package:atv_events/features/shopper/models/basket_item.dart';

/// Shopping basket screen for ATV shop
/// Shows cart items with simple checkout flow
class ReservationBasketScreen extends StatelessWidget {
  const ReservationBasketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        backgroundColor: HiPopColors.darkSurfaceVariant,
        elevation: 0,
        title: const Text(
          'Shopping Cart',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          // Past Orders button
          IconButton(
            icon: const Icon(Icons.receipt_long, color: HiPopColors.shopperAccent),
            onPressed: () => context.push('/orders'),
            tooltip: 'View Past Orders',
          ),
          // Clear basket button
          BlocBuilder<BasketBloc, BasketState>(
            builder: (context, state) {
              if (state is BasketLoaded && state.items.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.delete_sweep, color: HiPopColors.errorPlum),
                  onPressed: () => _showClearBasketDialog(context),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<BasketBloc, BasketState>(
        builder: (context, state) {
          if (state is BasketLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: HiPopColors.shopperAccent,
              ),
            );
          }

          if (state is BasketError) {
            return _buildErrorState(context, state);
          }

          if (state is BasketCheckoutSuccess) {
            return _buildSuccessState(context, state);
          }

          if (state is BasketLoaded) {
            if (state.items.isEmpty) {
              return _buildEmptyState(context);
            }

            return _buildBasketContent(context, state);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildBasketContent(BuildContext context, BasketLoaded state) {
    final totalAmount = state.totalAmount ?? 0.0;

    return Stack(
      children: [
        // Main content with padding for sticky bottom
        Padding(
          padding: EdgeInsets.only(
            bottom: totalAmount > 0 ? 180 : 0,
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(UIConstants.defaultPadding),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final item = state.items[index];
              return _buildBasketItem(context, item);
            },
          ),
        ),

        // Sticky bottom summary and checkout
        if (totalAmount > 0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: HiPopColors.darkSurfaceVariant,
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(UIConstants.defaultPadding),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Items:',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${state.totalItems}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Sellers:',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${state.uniqueSellerCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24, color: Colors.white24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '\$${totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: HiPopColors.shopperAccent,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Checkout button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: state.isSubmitting
                            ? null
                            : () => _handleCheckout(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HiPopColors.shopperAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: HiPopColors.shopperAccent.withOpacity(0.5),
                        ),
                        icon: state.isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.shopping_cart_checkout),
                        label: Text(
                          state.isSubmitting
                              ? 'Processing...'
                              : 'Proceed to Checkout',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBasketItem(BuildContext context, BasketItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: UIConstants.defaultPadding),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: HiPopColors.shopperAccent.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.product.imageUrls.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.product.imageUrls.first,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: HiPopColors.darkSurface,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: HiPopColors.shopperAccent,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 80,
                        height: 80,
                        color: HiPopColors.darkSurface,
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.white30,
                        ),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: HiPopColors.darkSurface,
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.white30,
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.store, size: 14, color: Colors.white60),
                      const SizedBox(width: 4),
                      Text(
                        item.product.sellerName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        item.product.formattedPrice,
                        style: const TextStyle(
                          color: HiPopColors.shopperAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item.quantity > 1) ...[
                        const SizedBox(width: 8),
                        Text(
                          '× ${item.quantity}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '= ${item.displayPrice}',
                          style: const TextStyle(
                            color: HiPopColors.shopperAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.notes != null && item.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.note,
                            size: 14,
                            color: Colors.white60,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.notes!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Quantity controls
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Increase button
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.read<BasketBloc>().add(
                        UpdateBasketItemQuantity(
                          itemId: item.id,
                          quantity: item.quantity + 1,
                        ),
                      );
                    },
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.add,
                        color: HiPopColors.shopperAccent,
                        size: 20,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Decrease/Delete button
                  InkWell(
                    onTap: () {
                      if (item.quantity > 1) {
                        HapticFeedback.lightImpact();
                        context.read<BasketBloc>().add(
                          UpdateBasketItemQuantity(
                            itemId: item.id,
                            quantity: item.quantity - 1,
                          ),
                        );
                      } else {
                        HapticFeedback.mediumImpact();
                        context.read<BasketBloc>().add(
                          RemoveFromBasket(item.id),
                        );
                      }
                    },
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        item.quantity > 1 ? Icons.remove : Icons.delete_outline,
                        color: item.quantity > 1 ? HiPopColors.shopperAccent : HiPopColors.errorPlum,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add products from the shop to get started',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
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
              'Browse Products',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, BasketError state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: HiPopColors.errorPlum,
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.read<BasketBloc>().add(LoadBasket());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.shopperAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context, BasketCheckoutSuccess state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: HiPopColors.successGreen.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 80,
              color: HiPopColors.successGreen,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Order Placed!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${state.itemCount} ${state.itemCount > 1 ? "items" : "item"} ordered',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              context.push('/orders');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.shopperAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.receipt_long),
            label: const Text(
              'View Orders',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _handleCheckout(BuildContext context) {
    // TODO: Show phone number input dialog before checkout
    // For now, use a placeholder
    _showPhoneDialog(context);
  }

  void _showPhoneDialog(BuildContext context) {
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: HiPopColors.darkSurfaceVariant,
        title: const Text(
          'Contact Information',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide your phone number for order updates:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '(555) 123-4567',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.black.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final phone = phoneController.text.trim();
              if (phone.isNotEmpty) {
                Navigator.pop(dialogContext);
                context.read<BasketBloc>().add(CheckoutBasket(
                  customerPhone: phone,
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.shopperAccent,
            ),
            child: const Text('Place Order'),
          ),
        ],
      ),
    );
  }

  void _showClearBasketDialog(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: HiPopColors.darkSurfaceVariant,
          title: const Text(
            'Clear Cart?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Remove all items from your cart?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                context.read<BasketBloc>().add(ClearBasket());
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Clear All',
                style: TextStyle(color: HiPopColors.errorPlum),
              ),
            ),
          ],
        );
      },
    );
  }
}
