import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/core/constants/ui_constants.dart';
import 'package:atv_events/features/shopper/models/product_feed_item.dart';
import 'package:atv_events/features/shopper/blocs/basket/basket_bloc.dart';
import 'package:atv_events/features/shopper/blocs/basket/basket_event.dart';
import 'package:atv_events/features/shopper/blocs/basket/basket_state.dart';
import 'package:atv_events/features/shared/services/waitlist_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Product Detail Screen for ATV shop
/// Shows product details with simple add to cart or join waitlist
class ProductDetailScreen extends StatefulWidget {
  final ProductFeedItem feedItem;

  const ProductDetailScreen({
    super.key,
    required this.feedItem,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final PageController _pageController = PageController();
  final WaitlistService _waitlistService = WaitlistService();
  int _currentImageIndex = 0;
  int _quantity = 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.feedItem.product;

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      body: CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: HiPopColors.darkSurface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  widget.feedItem.isFavorited ? Icons.favorite : Icons.favorite_border,
                  color: widget.feedItem.isFavorited ? HiPopColors.errorPlum : Colors.white,
                ),
                onPressed: _toggleFavorite,
              ),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: _shareProduct,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildImageCarousel(),
            ),
          ),

          // Product Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(UIConstants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name and Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: HiPopColors.darkTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: HiPopColors.darkSurface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: HiPopColors.darkBorder),
                              ),
                              child: Text(
                                product.category,
                                style: const TextStyle(
                                  color: HiPopColors.darkTextSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [HiPopColors.shopperAccent, HiPopColors.primaryDeepSage],
                          ),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Text(
                          product.formattedPrice,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: UIConstants.largeSpacing),

                  // Availability Status
                  _buildAvailabilityCard(),

                  const SizedBox(height: UIConstants.largeSpacing),

                  // Description
                  if (product.description != null && product.description!.isNotEmpty) ...[
                    Text(
                      'About This Product',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: HiPopColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: UIConstants.smallSpacing),
                    Text(
                      product.description!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: HiPopColors.darkTextSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: UIConstants.largeSpacing),
                  ],

                  // Tags
                  if (product.tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: product.tags.map((tag) => Chip(
                        label: Text(tag),
                        backgroundColor: HiPopColors.darkSurface,
                        labelStyle: const TextStyle(
                          color: HiPopColors.darkTextSecondary,
                          fontSize: 12,
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: UIConstants.largeSpacing),
                  ],

                  // Seller Section
                  _buildSellerSection(),

                  const SizedBox(height: UIConstants.largeSpacing),

                  // Quantity Selector (only if in stock)
                  if (product.isInStock) _buildQuantitySelector(),

                  const SizedBox(height: UIConstants.largeSpacing),

                  // Action Buttons
                  _buildActionButtons(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel() {
    final images = widget.feedItem.product.imageUrls;
    if (images.isEmpty) {
      return Container(
        color: HiPopColors.darkBorder,
        child: const Center(
          child: Icon(
            Icons.image_not_supported,
            size: 64,
            color: HiPopColors.darkTextTertiary,
          ),
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
          },
          itemCount: images.length,
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: images[index],
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: HiPopColors.darkBorder,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: HiPopColors.shopperAccent,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: HiPopColors.darkBorder,
                child: const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: HiPopColors.errorPlum,
                ),
              ),
            );
          },
        ),
        // Page Indicators
        if (images.length > 1)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentImageIndex == index ? 12 : 8,
                  height: _currentImageIndex == index ? 12 : 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvailabilityCard() {
    final product = widget.feedItem.product;
    final Color statusColor = product.isInStock
        ? HiPopColors.successGreen
        : (product.canJoinWaitlist ? HiPopColors.warningAmber : HiPopColors.errorPlum);

    return Card(
      color: statusColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(UIConstants.defaultPadding),
        child: Row(
          children: [
            Icon(
              product.isInStock ? Icons.check_circle : Icons.schedule,
              color: statusColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.availabilityStatus,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                  if (product.stockQuantity != null && product.isInStock) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${product.stockQuantity} units available',
                      style: const TextStyle(
                        color: HiPopColors.darkTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (!product.isInStock && product.waitlistCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${product.waitlistCount} people waiting',
                      style: const TextStyle(
                        color: HiPopColors.darkTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerSection() {
    final seller = widget.feedItem.sellerProfile;

    return Card(
      color: HiPopColors.darkSurface,
      child: InkWell(
        onTap: _navigateToSeller,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(UIConstants.defaultPadding),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: HiPopColors.vendorAccent,
                radius: 30,
                child: Icon(Icons.store, color: Colors.white, size: 30),
              ),
              const SizedBox(width: UIConstants.contentSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sold By',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.feedItem.sellerName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.darkTextPrimary,
                      ),
                    ),
                    if (seller.instagramHandle != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.camera_alt, size: 16, color: HiPopColors.infoBlueGray),
                          const SizedBox(width: 4),
                          Text(
                            '@${seller.instagramHandle}',
                            style: const TextStyle(
                              color: HiPopColors.infoBlueGray,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: HiPopColors.darkTextTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantitySelector() {
    final product = widget.feedItem.product;
    final maxQuantity = product.stockQuantity ?? 99;

    return Card(
      color: HiPopColors.darkSurface,
      child: Padding(
        padding: const EdgeInsets.all(UIConstants.defaultPadding),
        child: Row(
          children: [
            Text(
              'Quantity:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _quantity > 1
                  ? () => setState(() => _quantity--)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
              color: HiPopColors.shopperAccent,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: HiPopColors.darkBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_quantity',
                style: const TextStyle(
                  color: HiPopColors.darkTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: _quantity < maxQuantity
                  ? () => setState(() => _quantity++)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
              color: HiPopColors.shopperAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final product = widget.feedItem.product;

    if (!product.isInStock) {
      // Show join waitlist button if available
      if (product.canJoinWaitlist) {
        return _buildJoinWaitlistButton();
      } else {
        return _buildOutOfStockMessage();
      }
    }

    // Show add to cart button
    return _buildAddToCartButton();
  }

  Widget _buildAddToCartButton() {
    return BlocBuilder<BasketBloc, BasketState>(
      builder: (context, state) {
        final isInBasket = state is BasketLoaded && state.isProductInBasket(widget.feedItem.product.id);

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _handleAddToCart,
            style: ElevatedButton.styleFrom(
              backgroundColor: isInBasket ? HiPopColors.infoBlueGray : HiPopColors.shopperAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(
              isInBasket ? Icons.check_circle : Icons.shopping_cart,
              color: Colors.white,
            ),
            label: Text(
              isInBasket ? 'In Cart' : 'Add to Cart',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildJoinWaitlistButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _handleJoinWaitlist,
        style: ElevatedButton.styleFrom(
          backgroundColor: HiPopColors.warningAmber,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(
          Icons.list_alt,
          color: Colors.white,
        ),
        label: const Text(
          'Join Waitlist',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildOutOfStockMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.errorPlum.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HiPopColors.errorPlum.withOpacity(0.3)),
      ),
      child: const Column(
        children: [
          Icon(Icons.error_outline, color: HiPopColors.errorPlum, size: 32),
          SizedBox(height: 8),
          Text(
            'Out of Stock',
            style: TextStyle(
              color: HiPopColors.errorPlum,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Waitlist is full',
            style: TextStyle(
              color: HiPopColors.darkTextSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _handleAddToCart() {
    final basketBloc = context.read<BasketBloc>();
    basketBloc.add(AddToBasket(
      product: widget.feedItem.product,
      quantity: _quantity,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $_quantity ${_quantity > 1 ? "items" : "item"} to cart'),
        backgroundColor: HiPopColors.successGreen,
        action: SnackBarAction(
          label: 'View Cart',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to basket screen
            Navigator.of(context).pushNamed('/basket');
          },
        ),
      ),
    );

    // Reset quantity
    setState(() => _quantity = 1);
  }

  Future<void> _handleJoinWaitlist() async {
    try {
      await _waitlistService.joinWaitlist(
        productId: widget.feedItem.product.id,
        productName: widget.feedItem.product.name,
        productImageUrl: widget.feedItem.product.primaryImageUrl,
        sellerId: widget.feedItem.product.sellerId,
        sellerName: widget.feedItem.product.sellerName,
        quantityRequested: 1,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined waitlist! You\'ll be notified when available.'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join waitlist: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  void _toggleFavorite() {
    // TODO: Implement favorite toggle
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.feedItem.isFavorited
              ? 'Removed from favorites'
              : 'Added to favorites',
        ),
        backgroundColor: HiPopColors.shopperAccent,
      ),
    );
  }

  void _shareProduct() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sharing product...'),
        backgroundColor: HiPopColors.infoBlueGray,
      ),
    );
  }

  void _navigateToSeller() {
    // TODO: Navigate to seller profile
  }
}
