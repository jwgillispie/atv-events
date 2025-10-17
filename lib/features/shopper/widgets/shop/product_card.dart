import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/shared/models/product.dart';
import 'package:atv_events/features/shopper/widgets/shop/product_quick_action_sheet.dart';
import 'package:atv_events/features/shared/widgets/waitlist/waitlist_button.dart';

/// Compact Amazon/Etsy-style product card for grid layout
/// Clean design with white background image and clear pricing
class ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback? onLike;
  final VoidCallback? onShare;
  final VoidCallback? onPreOrder;
  final VoidCallback? onVendorTap;
  final VoidCallback? onLocationTap;

  const ProductCard({
    super.key,
    required this.product,
    this.onLike,
    this.onShare,
    this.onPreOrder,
    this.onVendorTap,
    this.onLocationTap,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isFavorited = false;

  void _showQuickActionSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductQuickActionSheet(
        product: widget.product,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine if product is new (within last 7 days)
    final isNew = DateTime.now().difference(widget.product.createdAt).inDays <= 7;

    // Check preorder availability
    final isPreorder = widget.product.isPreOrder || widget.product.preOrderQuantityLimit != null;
    final remainingQty = widget.product.remainingPreOrderQuantity;
    final isSoldOut = isPreorder && remainingQty != null && remainingQty <= 0;

    final hasStock = !isSoldOut && (widget.product.stockQuantity == null ||
        widget.product.stockQuantity! > 0);

    final stockText = isSoldOut
        ? 'Sold Out'
        : (remainingQty != null
            ? '$remainingQty left'
            : (widget.product.stockQuantity != null
                ? '${widget.product.stockQuantity} left'
                : null));

    return GestureDetector(
      onTap: () => _showQuickActionSheet(context),
      child: Container(
        decoration: BoxDecoration(
          color: HiPopColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: HiPopColors.darkBorder.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section with white background
            Stack(
              children: [
                // White background image container
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: widget.product.primaryImageUrl != null
                        ? Image.network(
                            widget.product.primaryImageUrl!,
                            fit: BoxFit.contain, // Full image visible, no cropping
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                ),
                // Sold Out badge with Waitlist button (top-left)
                if (isSoldOut)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: HiPopColors.errorPlum,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'SOLD OUT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Add Waitlist Button for sold out items
                        WaitlistButton(
                          productId: widget.product.id ?? '',
                          productName: widget.product.name,
                          productImageUrl: widget.product.imageUrls.isNotEmpty ? widget.product.imageUrls.first : null,
                          vendorId: widget.product.vendorId ?? '',
                          vendorName: widget.product.vendorName ?? '',
                          popupId: widget.product.popupId ?? '',
                          marketId: widget.product.marketId ?? '',
                          marketName: widget.product.marketName ?? 'Market',
                          popupDate: widget.product.popupStartTime ?? DateTime.now(),
                          price: widget.product.price,
                          isCompact: true,
                        ),
                      ],
                    ),
                  )
                else if (isNew)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: HiPopColors.successGreen,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Favorite heart (top-right)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isFavorited = !_isFavorited;
                      });
                      widget.onLike?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isFavorited ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorited
                            ? HiPopColors.errorPlum
                            : Colors.grey[700],
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Product info section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price - BIG & BOLD
                    Text(
                      '\$${widget.product.price?.toStringAsFixed(2) ?? '0.00'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Title - 2 lines max
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        fontSize: 13,
                        color: HiPopColors.darkTextPrimary,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Brand • Category
                    Text(
                      '${widget.product.vendorName} • ${widget.product.category}',
                      style: TextStyle(
                        fontSize: 11,
                        color: HiPopColors.darkTextSecondary.withValues(alpha: 0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Rating • Stock
                    Row(
                      children: [
                        // Rating
                        if (widget.product.productRating != null &&
                            widget.product.productRating! > 0) ...[
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            widget.product.productRating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: HiPopColors.darkTextPrimary,
                            ),
                          ),
                          if (widget.product.productReviewCount != null &&
                              widget.product.productReviewCount! > 0) ...[
                            const SizedBox(width: 2),
                            Text(
                              '(${widget.product.productReviewCount})',
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    HiPopColors.darkTextSecondary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                        // Stock
                        if (stockText != null) ...[
                          if (widget.product.productRating != null &&
                              widget.product.productRating! > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                '•',
                                style: TextStyle(
                                  color: HiPopColors.darkTextSecondary
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          Text(
                            stockText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: hasStock
                                  ? HiPopColors.successGreen
                                  : HiPopColors.errorPlum,
                            ),
                          ),
                        ],
                      ],
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
}
