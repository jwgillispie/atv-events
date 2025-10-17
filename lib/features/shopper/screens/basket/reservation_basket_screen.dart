import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/core/constants/ui_constants.dart';
import 'package:atv_events/features/shopper/blocs/basket/basket_bloc.dart';
import 'package:atv_events/features/shopper/blocs/basket/basket_event.dart';
import 'package:atv_events/features/shopper/blocs/basket/basket_state.dart';
import 'package:atv_events/features/shopper/models/basket_item.dart';

/// Simplified reservation basket screen showing grouped items by popup
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
          'Your Basket',
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
          // Clear basket button (only shows when basket has items)
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

          if (state is BasketReservationSuccess) {
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
    final groups = state.groupedItems;
    final totalAmount = state.totalAmount ?? 0.0;

    return Stack(
      children: [
        // Main content with padding for sticky bottom
        Padding(
          padding: EdgeInsets.only(
            bottom: totalAmount > 0 ? 100 : 0,
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(UIConstants.defaultPadding),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return _buildPopupGroup(context, group, state);
            },
          ),
        ),

        // Sticky bottom checkout button
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
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '\$${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to checkout with all items from all groups
                          final allItems = <BasketItem>[];
                          for (final group in groups) {
                            allItems.addAll(group.items);
                          }

                          if (allItems.isNotEmpty) {
                            final firstGroup = groups.first;
                            context.push('/shopper/checkout', extra: {
                              'items': allItems,
                              'marketId': firstGroup.marketId.isNotEmpty ? firstGroup.marketId : 'direct-purchase',
                              'marketName': firstGroup.marketName.isNotEmpty ? firstGroup.marketName : 'Direct Purchase',
                              'vendorId': allItems.first.product.vendorId,
                              'vendorName': allItems.first.product.vendorName,
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HiPopColors.shopperAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Checkout • \$${totalAmount.toStringAsFixed(2)}',
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

  Widget _buildPopupGroup(BuildContext context, BasketGroup group, BasketLoaded state) {
    final groupTotal = group.totalAmount ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: UIConstants.defaultPadding),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: HiPopColors.shopperAccent.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header with vendor/market info
          Container(
            padding: const EdgeInsets.all(UIConstants.defaultPadding),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vendor name
                Row(
                  children: [
                    const Icon(
                      Icons.store,
                      color: HiPopColors.shopperAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        group.items.isNotEmpty ? group.items.first.product.vendorName : 'Vendor',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Location
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        group.popupLocation,
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
                const SizedBox(height: 4),
                // Date
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatPopupDate(group.popupDateTime),
                      style: TextStyle(
                        color: _isUpcoming(group.popupDateTime)
                            ? HiPopColors.shopperAccent
                            : HiPopColors.errorPlum,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Items list - always visible
          ...group.items.map((item) => _buildBasketItem(context, item)),

          // Group subtotal and actions
          Container(
            padding: const EdgeInsets.all(UIConstants.defaultPadding),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Column(
              children: [
                // Subtotal
                if (groupTotal > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal (${group.totalItems} items):',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '\$${groupTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: HiPopColors.shopperAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Action buttons
                Row(
                  children: [
                    // Remove all button
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _confirmRemoveGroup(context, group.vendorPostId),
                        icon: const Icon(Icons.delete_outline, color: HiPopColors.errorPlum, size: 20),
                        label: const Text(
                          'Remove All',
                          style: TextStyle(color: HiPopColors.errorPlum, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Checkout this group button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          context.push('/shopper/checkout', extra: {
                            'items': group.items,
                            'marketId': group.marketId.isNotEmpty ? group.marketId : 'direct-purchase',
                            'marketName': group.marketName.isNotEmpty ? group.marketName : 'Direct Purchase',
                            'vendorId': group.items.first.product.vendorId,
                            'vendorName': group.items.first.product.vendorName,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HiPopColors.successGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Checkout • \$${groupTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasketItem(BuildContext context, BasketItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: UIConstants.defaultPadding,
        vertical: UIConstants.smallSpacing,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Product image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.product.imageUrls.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.product.imageUrls.first,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: HiPopColors.darkSurfaceVariant,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: HiPopColors.shopperAccent,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 60,
                      height: 60,
                      color: HiPopColors.darkSurfaceVariant,
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.white30,
                      ),
                    ),
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: HiPopColors.darkSurfaceVariant,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item.product.vendorName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      item.displayPrice,
                      style: const TextStyle(
                        color: HiPopColors.shopperAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.quantity > 1) ...[
                      const SizedBox(width: 4),
                      Text(
                        '× ${item.quantity}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '= \$${(item.product.price! * item.quantity).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: HiPopColors.shopperAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Quantity controls
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Decrease button
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
                      // Remove item if quantity would be 0
                      HapticFeedback.mediumImpact();
                      context.read<BasketBloc>().add(
                        RemoveFromBasket(item.id),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      item.quantity > 1 ? Icons.remove : Icons.delete_outline,
                      color: item.quantity > 1 ? HiPopColors.shopperAccent : HiPopColors.errorPlum,
                      size: 18,
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
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
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.add,
                      color: HiPopColors.shopperAccent,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_basket_outlined,
            size: 80,
            color: Colors.white.withValues(alpha:  0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your basket is empty',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Reserve products for pickup at upcoming popups',
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
              'Start Shopping',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, BasketError state) {
    return Center(
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
    );
  }

  Widget _buildSuccessState(BuildContext context, BasketReservationSuccess state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: HiPopColors.successGreen.withValues(alpha:  0.2),
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
            'Reservations Confirmed!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${state.itemCount} items reserved for pickup',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/shopper/reservations',
                (route) => route.isFirst,
              );
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
              'View Reservations',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPopupDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.isNegative) {
      return 'Past event';
    } else if (difference.inDays == 0) {
      return 'Today at ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow at ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE, h:mm a').format(date);
    } else {
      return DateFormat('MMM d, h:mm a').format(date);
    }
  }

  bool _isUpcoming(DateTime date) {
    return date.isAfter(DateTime.now());
  }


  void _confirmRemoveGroup(BuildContext context, String vendorPostId) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: HiPopColors.darkSurfaceVariant,
          title: const Text(
            'Remove Items?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Remove all items for this vendor from your cart?',
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
                context.read<BasketBloc>().add(RemovePopupItems(vendorPostId));
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Remove',
                style: TextStyle(color: HiPopColors.errorPlum),
              ),
            ),
          ],
        );
      },
    );
  }



  void _showClearBasketDialog(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: HiPopColors.darkSurfaceVariant,
          title: const Text(
            'Clear Cart?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Remove all items from your basket?',
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