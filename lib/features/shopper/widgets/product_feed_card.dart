import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/core/constants/ui_constants.dart';
import 'package:atv_events/features/shopper/models/product_feed_item.dart';
import 'package:atv_events/features/shared/services/utilities/url_launcher_service.dart';
import 'package:share_plus/share_plus.dart';

/// Product Feed Card Widget
/// Displays a product with vendor info, availability, and action buttons
class ProductFeedCard extends StatefulWidget {
  final ProductFeedItem feedItem;
  final VoidCallback? onTap;
  final VoidCallback? onVendorTap;
  final VoidCallback? onReserveTap;
  final VoidCallback? onFavoriteTap;

  const ProductFeedCard({
    super.key,
    required this.feedItem,
    this.onTap,
    this.onVendorTap,
    this.onReserveTap,
    this.onFavoriteTap,
  });

  @override
  State<ProductFeedCard> createState() => _ProductFeedCardState();
}

class _ProductFeedCardState extends State<ProductFeedCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.feedItem.product;
    final hasMultipleImages = product.photoUrls.length > 1;

    return Card(
      margin: const EdgeInsets.only(bottom: UIConstants.defaultPadding),
      color: HiPopColors.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image Carousel
            _buildImageCarousel(hasMultipleImages),

            // Product Details
            Padding(
              padding: const EdgeInsets.all(UIConstants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name and Price Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: HiPopColors.darkTextPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product.category,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: HiPopColors.darkTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: UIConstants.contentSpacing),
                      // Price Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: HiPopColors.shopperAccent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          product.displayPrice,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (product.description != null && product.description!.isNotEmpty) ...[
                    const SizedBox(height: UIConstants.smallSpacing),
                    Text(
                      product.description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: HiPopColors.darkTextSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: UIConstants.contentSpacing),

                  // Vendor Info
                  _buildVendorInfo(context),

                  const SizedBox(height: UIConstants.contentSpacing),

                  // Availability Info
                  _buildAvailabilityInfo(context),

                  const SizedBox(height: UIConstants.defaultPadding),

                  // Action Buttons
                  _buildActionButtons(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCarousel(bool hasMultipleImages) {
    final product = widget.feedItem.product;
    final images = product.photoUrls.isNotEmpty
        ? product.photoUrls
        : [product.imageUrl ?? ''];

    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: SizedBox(
            height: 300,
            width: double.infinity,
            child: hasMultipleImages
                ? PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return _buildImage(images[index]);
                    },
                  )
                : _buildImage(images.first),
          ),
        ),

        // Favorite Button
        Positioned(
          top: 12,
          right: 12,
          child: _buildFavoriteButton(),
        ),

        // Availability Badge
        if (widget.feedItem.isAvailableNow)
          Positioned(
            top: 12,
            left: 12,
            child: _buildAvailabilityBadge(),
          ),

        // Page Indicator
        if (hasMultipleImages)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity( 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    images.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: _currentPage == index ? 8 : 6,
                      height: _currentPage == index ? 8 : 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? Colors.white
                            : Colors.white.withOpacity( 0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImage(String imageUrl) {
    if (imageUrl.isEmpty) {
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

    return CachedNetworkImage(
      imageUrl: imageUrl,
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
        child: const Center(
          child: Icon(
            Icons.error_outline,
            size: 64,
            color: HiPopColors.errorPlum,
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteButton() {
    return Container(
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface.withOpacity( 0.9),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          widget.feedItem.isFavorited ? Icons.favorite : Icons.favorite_border,
          color: widget.feedItem.isFavorited ? HiPopColors.errorPlum : HiPopColors.darkTextPrimary,
        ),
        onPressed: widget.onFavoriteTap,
      ),
    );
  }

  Widget _buildAvailabilityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: HiPopColors.successGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 16),
          SizedBox(width: 4),
          Text(
            'Available Now',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorInfo(BuildContext context) {
    return InkWell(
      onTap: widget.onVendorTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              HiPopColors.vendorAccent.withOpacity( 0.08),
              HiPopColors.vendorAccent.withOpacity( 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: HiPopColors.vendorAccent.withOpacity( 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [HiPopColors.vendorAccent, HiPopColors.vendorAccentLight],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: HiPopColors.vendorAccent.withOpacity( 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.storefront, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.feedItem.vendorName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: HiPopColors.darkTextPrimary,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: HiPopColors.successGreen.withOpacity( 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'VERIFIED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: HiPopColors.successGreen,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.feedItem.vendorInstagramHandle != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.alternate_email,
                          size: 12,
                          color: HiPopColors.infoBlueGray.withOpacity( 0.8),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          widget.feedItem.vendorInstagramHandle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: HiPopColors.infoBlueGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: HiPopColors.darkBackground.withOpacity( 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: HiPopColors.vendorAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityInfo(BuildContext context) {
    final availabilityColor = _getAvailabilityColor();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: availabilityColor.withOpacity( 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: availabilityColor.withOpacity( 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: availabilityColor),
              const SizedBox(width: 8),
              Text(
                'Next Availability',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: availabilityColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.feedItem.nextAvailabilityText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: HiPopColors.darkTextPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.feedItem.nextLocation != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: HiPopColors.darkTextSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.feedItem.nextLocation!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: HiPopColors.darkTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.feedItem.distanceText.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: HiPopColors.darkBorder,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.feedItem.distanceText,
                      style: const TextStyle(
                        fontSize: 11,
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        // Map Navigation Button - Primary action for finding the market
        if (widget.feedItem.hasLocationData)
          Expanded(
            child: _ActionButton(
              icon: Icons.map_outlined,
              label: 'Navigate',
              color: HiPopColors.infoBlueGray,
              onTap: () => _launchMaps(context),
              tooltip: 'Navigate to market',
            ),
          ),

        if (widget.feedItem.hasLocationData)
          const SizedBox(width: 8),

        // Share Button - Social engagement
        Expanded(
          child: _ActionButton(
            icon: Icons.ios_share,
            label: 'Share',
            color: HiPopColors.darkTextSecondary,
            onTap: () => _shareProduct(context),
            tooltip: 'Share product',
          ),
        ),

        const SizedBox(width: 8),

        // Reserve for Pickup Button - Primary CTA
        Expanded(
          flex: 2,
          child: _ActionButton(
            icon: Icons.shopping_bag_outlined,
            label: 'Reserve',
            color: HiPopColors.shopperAccent,
            filled: true,
            onTap: widget.onReserveTap,
            tooltip: 'Reserve for market pickup',
          ),
        ),
      ],
    );
  }

  Color _getAvailabilityColor() {
    switch (widget.feedItem.availabilityStatus) {
      case 'now':
        return HiPopColors.successGreen;
      case 'today':
        return HiPopColors.warningAmber;
      case 'tomorrow':
      case 'this_week':
        return HiPopColors.infoBlueGray;
      default:
        return HiPopColors.darkTextSecondary;
    }
  }

  Future<void> _launchMaps(BuildContext context) async {
    final location = widget.feedItem.nextLocation;
    if (location == null) return;

    try {
      await UrlLauncherService.launchMaps(location, context: context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open maps: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  Future<void> _shareProduct(BuildContext context) async {
    final product = widget.feedItem.product;
    final vendor = widget.feedItem.vendorName;

    final buffer = StringBuffer();
    buffer.writeln('🛍️ Amazing Local Find!');
    buffer.writeln();
    buffer.writeln('📦 ${product.name}');
    buffer.writeln('👨‍🌾 By: $vendor');
    buffer.writeln('💰 Price: ${product.displayPrice}');

    if (product.description != null && product.description!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(product.description);
    }

    buffer.writeln();
    if (widget.feedItem.isAvailableNow) {
      buffer.writeln('🟢 AVAILABLE NOW!');
    } else {
      buffer.writeln('📅 Next available: ${widget.feedItem.nextAvailabilityText}');
    }

    if (widget.feedItem.nextLocation != null) {
      buffer.writeln('📍 ${widget.feedItem.nextLocation}');
    }

    if (widget.feedItem.vendorInstagramHandle != null) {
      buffer.writeln();
      buffer.writeln('Instagram: @${widget.feedItem.vendorInstagramHandle}');
    }

    buffer.writeln();
    buffer.writeln('━━━━━━━━━━━━━━━');
    buffer.writeln('Discover amazing local products and vendors!');
    buffer.writeln('Download ATV Events today');
    buffer.writeln('🔗 atv-events.com');

    await Share.share(buffer.toString());

    // Haptic feedback for share action
    if (context.mounted) {
      HapticFeedback.lightImpact();
    }
  }
}

/// Reusable Action Button Widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;
  final String? tooltip;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.filled = false,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = filled ? _buildFilledButton() : _buildOutlinedButton();

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }
    return button;
  }

  Widget _buildFilledButton() {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: color.withOpacity( 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
      ),
    );
  }

  Widget _buildOutlinedButton() {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity( 0.4), width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      ),
    );
  }
}