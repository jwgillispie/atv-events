import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/core/constants/ui_constants.dart';
import 'package:hipop/features/shopper/models/product_feed_item.dart';
import 'package:hipop/features/shopper/models/basket_item.dart';
import 'package:hipop/features/shopper/blocs/basket/basket_bloc.dart';
import 'package:hipop/features/shopper/blocs/basket/basket_event.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hipop/features/shared/services/utilities/url_launcher_service.dart';

/// Product Detail Screen
/// Shows detailed information about a product including all photos,
/// full description, vendor info, and availability schedule
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
  int _currentImageIndex = 0;

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
                          product.displayPrice,
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

                  // Vendor Section
                  _buildVendorSection(),

                  const SizedBox(height: UIConstants.largeSpacing),

                  // Availability Section
                  _buildAvailabilitySection(),

                  const SizedBox(height: UIConstants.largeSpacing),

                  // Upcoming Popups
                  if (widget.feedItem.upcomingAvailabilities.isNotEmpty) ...[
                    _buildUpcomingPopupsSection(),
                    const SizedBox(height: UIConstants.largeSpacing),
                  ],

                  // Action Buttons based on payment configuration
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
    final images = widget.feedItem.product.allImageUrls;
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
                        : Colors.white.withOpacity( 0.5),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVendorSection() {
    final vendor = widget.feedItem.vendorProfile;

    return Card(
      color: HiPopColors.darkSurface,
      child: InkWell(
        onTap: _navigateToVendor,
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
                      widget.feedItem.vendorName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.darkTextPrimary,
                      ),
                    ),
                    if (vendor.instagramHandle != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.camera_alt, size: 16, color: HiPopColors.infoBlueGray),
                          const SizedBox(width: 4),
                          Text(
                            '@${vendor.instagramHandle}',
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

  Widget _buildAvailabilitySection() {
    final availability = widget.feedItem.nextAvailability;
    if (availability == null) {
      return Card(
        color: HiPopColors.darkSurface,
        child: Padding(
          padding: const EdgeInsets.all(UIConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, color: HiPopColors.darkTextSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Availability',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'No upcoming popups scheduled',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: HiPopColors.darkTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final Color statusColor = widget.feedItem.isAvailableNow
        ? HiPopColors.successGreen
        : HiPopColors.warningAmber;

    return Card(
      color: statusColor.withOpacity( 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity( 0.3)),
      ),
      child: InkWell(
        onTap: (availability.latitude != null && availability.longitude != null)
            ? () => _launchMaps()
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(UIConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, color: statusColor),
                  const SizedBox(width: 8),
                  Text(
                    widget.feedItem.isAvailableNow ? 'Available Now!' : 'Next Availability',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                availability.formattedTimeRange,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: HiPopColors.darkTextSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      availability.locationName ?? availability.location,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                  ),
                  if (widget.feedItem.distanceText.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: HiPopColors.darkBorder,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.feedItem.distanceText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingPopupsSection() {
    final upcomingPosts = widget.feedItem.upcomingAvailabilities
        .where((post) => post.isUpcoming)
        .take(3)
        .toList();

    if (upcomingPosts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming Popups',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: HiPopColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: UIConstants.smallSpacing),
        ...upcomingPosts.map((post) => Card(
          color: HiPopColors.darkSurface,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.event, color: HiPopColors.shopperAccent),
            title: Text(
              post.formattedDateTime,
              style: const TextStyle(color: HiPopColors.darkTextPrimary),
            ),
            subtitle: Text(
              post.locationName ?? post.location,
              style: const TextStyle(color: HiPopColors.darkTextSecondary),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: HiPopColors.darkTextTertiary,
            ),
            onTap: () {
              // Navigate to popup detail
            },
          ),
        )),
      ],
    );
  }

  void _toggleFavorite() {
    // Implement favorite toggle
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
    // Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sharing product...'),
        backgroundColor: HiPopColors.infoBlueGray,
      ),
    );
  }

  void _navigateToVendor() {
    // Navigate to vendor profile
    // context.pushNamed('vendorDetail', pathParameters: {'vendorId': widget.feedItem.vendorProfile.userId});
  }

  void _launchMaps() async {
    final location = widget.feedItem.nextLocation;
    if (location == null) return;

    try {
      await UrlLauncherService.launchMaps(location, context: context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open maps: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  void _handleReservation() {
    // Add to basket as reservation
    _addToBasket(isPayment: false);
  }

  void _handleBuyNow() {
    // Add to basket for payment
    _addToBasket(isPayment: true);
  }

  void _addToBasket({required bool isPayment}) {
    // TODO: Implement actual basket addition logic
    // This will need to access the basket bloc and add the item
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPayment
            ? 'Added to cart for payment: \${widget.feedItem.product.displayPrice}'
            : 'Reserved for pickup',
        ),
        backgroundColor: isPayment ? HiPopColors.successGreen : HiPopColors.shopperAccent,
      ),
    );
  }

  Widget _buildActionButtons() {
    // Since everything is now preorder-only, we only show the reserve button
    return _buildReserveButton();
  }

  Widget _buildBuyNowButton() {
    final product = widget.feedItem.product;
    final hasPrice = product.basePrice != null && product.basePrice! > 0;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _handleBuyNow,
        style: ElevatedButton.styleFrom(
          backgroundColor: HiPopColors.successGreen,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(
          Icons.shopping_cart,
          color: Colors.white,
        ),
        label: Text(
          hasPrice
            ? 'Buy Now - \${product.displayPrice}'
            : 'Buy Now',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildReserveButton({bool isSecondary = false}) {
    return SizedBox(
      width: double.infinity,
      child: isSecondary
        ? OutlinedButton.icon(
            onPressed: _handleReservation,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(
                color: HiPopColors.shopperAccent,
                width: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(
              Icons.bookmark_outline,
              color: HiPopColors.shopperAccent,
            ),
            label: const Text(
              'Reserve for Pickup',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: HiPopColors.shopperAccent,
              ),
            ),
          )
        : ElevatedButton.icon(
            onPressed: _handleReservation,
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.shopperAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(
              Icons.bookmark_outline,
              color: Colors.white,
            ),
            label: const Text(
              'Reserve This Product',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
    );
  }
}