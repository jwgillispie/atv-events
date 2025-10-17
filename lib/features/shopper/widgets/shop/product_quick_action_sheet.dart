import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/shared/models/product.dart';
import 'package:hipop/features/shopper/blocs/basket/basket_bloc.dart';
import 'package:hipop/features/shopper/blocs/basket/basket_event.dart';

/// Bottom sheet for quick product actions (Add to Cart, Buy Now)
/// Clean Amazon/Etsy-style product action modal
class ProductQuickActionSheet extends StatefulWidget {
  final Product product;

  const ProductQuickActionSheet({
    super.key,
    required this.product,
  });

  @override
  State<ProductQuickActionSheet> createState() => _ProductQuickActionSheetState();
}

class _ProductQuickActionSheetState extends State<ProductQuickActionSheet> {
  int _quantity = 1;

  void _addToCart(BuildContext context) {
    HapticFeedback.mediumImpact();

    if (widget.product.eventId == null || widget.product.eventId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot add to basket: Event information missing'),
          backgroundColor: HiPopColors.errorPlum,
        ),
      );
      return;
    }

    context.read<BasketBloc>().add(
          AddToBasket(
            product: widget.product,
            vendorPostId: widget.product.eventId!,
            marketId: widget.product.marketId ?? 'direct-purchase',
            marketName: widget.product.marketName ?? widget.product.location ?? 'Popup Market',
            popupDateTime: widget.product.eventDate ?? DateTime.now(),
            popupLocation: widget.product.location ?? widget.product.marketName ?? 'Pickup Location',
            quantity: _quantity,
            isPaymentItem: false,
          ),
        );

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Added ${_quantity}x "${widget.product.name}" to basket'),
            ),
          ],
        ),
        backgroundColor: HiPopColors.successGreen,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'VIEW BASKET',
          textColor: Colors.white,
          onPressed: () {
            context.go('/shopper', extra: {'selectedTab': 2});
          },
        ),
      ),
    );
  }

  void _buyNow(BuildContext context) {
    HapticFeedback.heavyImpact();

    if (widget.product.eventId == null || widget.product.eventId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot proceed: Event information missing'),
          backgroundColor: HiPopColors.errorPlum,
        ),
      );
      return;
    }

    Navigator.pop(context);

    // Navigate directly to checkout with this single product
    context.push('/shopper/checkout', extra: {
      'product': widget.product,
      'vendorId': widget.product.vendorId,
      'vendorName': widget.product.vendorName,
      'popupId': widget.product.eventId!,
      'popupLocation': widget.product.location ?? widget.product.marketName ?? 'Pickup Location',
      'popupStartTime': widget.product.eventDate,
      'popupEndTime': widget.product.popupEndTime,
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasStock = widget.product.stockQuantity == null ||
        widget.product.stockQuantity! > 0;
    final maxQuantity = widget.product.stockQuantity ?? 10;

    return Container(
      decoration: const BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Product preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: widget.product.primaryImageUrl != null
                        ? Image.network(
                            widget.product.primaryImageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.shopping_bag_outlined,
                                size: 32,
                                color: Colors.grey,
                              );
                            },
                          )
                        : const Icon(
                            Icons.shopping_bag_outlined,
                            size: 32,
                            color: Colors.grey,
                          ),
                  ),
                ),
                const SizedBox(width: 16),

                // Product info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: HiPopColors.darkTextPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.product.vendorName,
                        style: TextStyle(
                          fontSize: 14,
                          color: HiPopColors.darkTextSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${widget.product.price?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.shopperAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: HiPopColors.darkBorder, height: 1),

          // Quantity selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Text(
                  'Quantity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
                const Spacer(),

                // Quantity controls
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: HiPopColors.darkBorder),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _quantity > 1
                            ? () {
                                setState(() {
                                  _quantity--;
                                });
                                HapticFeedback.selectionClick();
                              }
                            : null,
                        icon: const Icon(Icons.remove),
                        color: HiPopColors.darkTextPrimary,
                        disabledColor: HiPopColors.darkTextTertiary,
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 40),
                        alignment: Alignment.center,
                        child: Text(
                          _quantity.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: HiPopColors.darkTextPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _quantity < maxQuantity
                            ? () {
                                setState(() {
                                  _quantity++;
                                });
                                HapticFeedback.selectionClick();
                              }
                            : null,
                        icon: const Icon(Icons.add),
                        color: HiPopColors.darkTextPrimary,
                        disabledColor: HiPopColors.darkTextTertiary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stock indicator
          if (!hasStock)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HiPopColors.errorPlum.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: HiPopColors.errorPlum.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: HiPopColors.errorPlum,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Out of stock',
                      style: TextStyle(
                        color: HiPopColors.errorPlum,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Add to Basket button
                Expanded(
                  child: OutlinedButton(
                    onPressed: hasStock ? () => _addToCart(context) : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HiPopColors.shopperAccent,
                      side: const BorderSide(
                        color: HiPopColors.shopperAccent,
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_basket_outlined, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Add to Basket',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Buy Now button
                Expanded(
                  child: ElevatedButton(
                    onPressed: hasStock ? () => _buyNow(context) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HiPopColors.shopperAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.flash_on, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Buy Now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
