import 'package:flutter/material.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/core/constants/ui_constants.dart';
import 'package:atv_events/features/shared/widgets/common/favorite_button.dart';
import 'package:atv_events/features/shared/widgets/share_button.dart';
import 'package:atv_events/features/vendor/widgets/buttons/vendor_follow_button.dart';
import 'package:atv_events/features/shared/widgets/feed_map_preview.dart';
import 'package:atv_events/features/shared/widgets/common/vendor_items_widget.dart';
import 'package:atv_events/features/shared/widgets/reviews/review_indicator.dart';

/// Feed card types
enum FeedCardType { market, vendor, event }

/// A reusable feed card widget that eliminates code duplication
/// Supports markets, vendor posts, and events with consistent styling
class FeedCard extends StatelessWidget {
  // Common properties
  final String id;
  final FeedCardType type;
  final String title;
  final String subtitle;
  final String location;
  final String? description;
  final VoidCallback onTap;
  final VoidCallback? onLocationTap;
  final Future<String> Function()? onGetShareContent;
  
  // Optional properties
  final String? instagramHandle;
  final VoidCallback? onInstagramTap;
  final List<String>? tags;
  final List<String>? vendorItems;
  final FavoriteType? favoriteType;
  
  // Vendor-specific properties
  final String? vendorId;
  final String? vendorName;
  final List<String>? photoUrls;
  final double? latitude;
  final double? longitude;
  
  // Icon customization
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;

  // Review data
  final double? rating;
  final int? reviewCount;

  const FeedCard({
    super.key,
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.location,
    required this.onTap,
    this.description,
    this.onLocationTap,
    this.onGetShareContent,
    this.instagramHandle,
    this.onInstagramTap,
    this.tags,
    this.vendorItems,
    this.favoriteType,
    this.vendorId,
    this.vendorName,
    this.photoUrls,
    this.latitude,
    this.longitude,
    this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    this.rating,
    this.reviewCount,
  });

  /// Factory constructor for market cards
  factory FeedCard.market({
    Key? key,
    required String id,
    required String name,
    required String displayInfo,
    required String address,
    required VoidCallback onTap,
    String? description,
    String? instagramHandle,
    double? latitude,
    double? longitude,
    String? imageUrl,
    List<String>? flyerUrls,
    VoidCallback? onLocationTap,
    VoidCallback? onInstagramTap,
    Future<String> Function()? onGetShareContent,
    String? vendorId,
    double? rating,
    int? reviewCount,
  }) {
    return FeedCard(
      key: key,
      id: id,
      type: FeedCardType.market,
      title: name,
      subtitle: 'Market • $displayInfo',
      location: address,
      description: description,
      onTap: onTap,
      onLocationTap: onLocationTap,
      onInstagramTap: onInstagramTap,
      onGetShareContent: onGetShareContent,
      instagramHandle: instagramHandle,
      favoriteType: FavoriteType.market,
      vendorId: vendorId,
      vendorName: name,
      latitude: latitude,
      longitude: longitude,
      photoUrls: [...?flyerUrls, if (imageUrl != null) imageUrl],
      icon: Icons.store_mall_directory,
      iconColor: Colors.green,
      iconBackgroundColor: Colors.green.withOpacity( 0.1),
      rating: rating,
      reviewCount: reviewCount,
    );
  }

  /// Factory constructor for vendor post cards
  factory FeedCard.vendorPost({
    Key? key,
    required String id,
    required String vendorId,
    required String vendorName,
    required String dateTime,
    required String location,
    required String description,
    required VoidCallback onTap,
    List<String>? photoUrls,
    double? latitude,
    double? longitude,
    String? instagramHandle,
    List<String>? vendorItems,
    VoidCallback? onLocationTap,
    VoidCallback? onInstagramTap,
    Future<String> Function()? onGetShareContent,
    double? rating,
    int? reviewCount,
  }) {
    return FeedCard(
      key: key,
      id: id,
      type: FeedCardType.vendor,
      title: vendorName,
      subtitle: 'Pop-up • $dateTime',
      location: location,
      description: description,
      onTap: onTap,
      onLocationTap: onLocationTap,
      onInstagramTap: onInstagramTap,
      onGetShareContent: onGetShareContent,
      instagramHandle: instagramHandle,
      vendorItems: vendorItems,
      favoriteType: FavoriteType.post,
      vendorId: vendorId,
      vendorName: vendorName,
      photoUrls: photoUrls,
      latitude: latitude,
      longitude: longitude,
      icon: Icons.store,
      iconColor: Colors.blue,
      iconBackgroundColor: Colors.blue.withOpacity( 0.1),
      rating: rating,
      reviewCount: reviewCount,
    );
  }

  /// Factory constructor for event cards
  factory FeedCard.event({
    Key? key,
    required String id,
    required String name,
    required String dateTime,
    required String location,
    required VoidCallback onTap,
    String? description,
    List<String>? tags,
    double? latitude,
    double? longitude,
    String? imageUrl,
    VoidCallback? onLocationTap,
    Future<String> Function()? onGetShareContent,
  }) {
    return FeedCard(
      key: key,
      id: id,
      type: FeedCardType.event,
      title: name,
      subtitle: 'Event • $dateTime',
      location: location,
      description: description,
      onTap: onTap,
      onLocationTap: onLocationTap,
      onGetShareContent: onGetShareContent,
      tags: tags,
      favoriteType: FavoriteType.event,
      latitude: latitude,
      longitude: longitude,
      photoUrls: imageUrl != null ? [imageUrl] : null,
      icon: Icons.event,
      iconColor: Colors.purple,
      iconBackgroundColor: Colors.purple.withOpacity( 0.1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: HiPopColors.darkSurface,
      margin: const EdgeInsets.symmetric(
        horizontal: 0,
        vertical: UIConstants.smallSpacing,
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(UIConstants.cardBorderRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo/Map preview for all post types
            if ((photoUrls?.isNotEmpty ?? false) || 
                (latitude != null && longitude != null))
              FeedMapPreview(
                latitude: latitude,
                longitude: longitude,
                location: location,
                photoUrls: photoUrls ?? [],
                onPhotoTap: onTap,
                height: 200,
                borderRadius: UIConstants.cardBorderRadius,
              ),
            
            Padding(
              padding: const EdgeInsets.all(UIConstants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: UIConstants.contentSpacing),
                  _buildLocation(context),
                  if (description != null && description!.isNotEmpty) ...[
                    const SizedBox(height: UIConstants.smallSpacing),
                    _buildDescription(context),
                  ],
                  if (instagramHandle != null && instagramHandle!.isNotEmpty) ...[
                    const SizedBox(height: UIConstants.smallSpacing),
                    _buildInstagramHandle(context),
                  ],
                  if (vendorItems != null && vendorItems!.isNotEmpty) ...[
                    const SizedBox(height: UIConstants.smallSpacing),
                    _buildVendorItems(context),
                  ],
                  if (tags != null && tags!.isNotEmpty) ...[
                    const SizedBox(height: UIConstants.smallSpacing),
                    _buildTags(context),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // Icon container
        Container(
          padding: const EdgeInsets.all(UIConstants.smallSpacing),
          decoration: BoxDecoration(
            color: iconBackgroundColor,
            borderRadius: BorderRadius.circular(UIConstants.smallBorderRadius),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: UIConstants.iconSizeMedium,
          ),
        ),
        const SizedBox(width: UIConstants.contentSpacing),
        // Title and subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                  ),
                  if (rating != null || reviewCount != null) ...[
                    const SizedBox(width: 8),
                    ReviewIndicator(
                      rating: rating,
                      reviewCount: reviewCount ?? 0,
                      variant: ReviewIndicatorVariant.compact,
                      entityType: type == FeedCardType.vendor
                          ? ReviewEntityType.vendor
                          : type == FeedCardType.market
                              ? ReviewEntityType.market
                              : ReviewEntityType.post,
                      entityId: type == FeedCardType.vendor && vendorId != null
                          ? vendorId!
                          : id,
                      entityName: title,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        // Action buttons
        Row(
          children: [
            if (onGetShareContent != null) ...[
              ShareButton(
                onGetShareContent: onGetShareContent!,
                style: ShareButtonStyle.icon,
                size: ShareButtonSize.small,
              ),
              const SizedBox(width: UIConstants.smallSpacing),
            ],
            if (type == FeedCardType.vendor && vendorId != null && vendorName != null) ...[
              VendorFollowButton(
                vendorId: vendorId!,
                vendorName: vendorName!,
                isCompact: true,
              ),
              const SizedBox(width: UIConstants.smallSpacing),
            ],
            if (type == FeedCardType.market && vendorId != null && vendorName != null) ...[
              VendorFollowButton(
                vendorId: vendorId!,
                vendorName: vendorName!,
                isCompact: true,
              ),
              const SizedBox(width: UIConstants.smallSpacing),
            ],
            if (favoriteType != null)
              FavoriteButton(
                itemId: id,
                type: favoriteType!,
                size: 20,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocation(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.location_on,
          size: UIConstants.iconSizeSmall,
          color: HiPopColors.darkTextTertiary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: InkWell(
            onTap: onLocationTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                location,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue[700],
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Text(
      description!,
      style: const TextStyle(
        fontSize: 13,
        color: HiPopColors.darkTextSecondary,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildInstagramHandle(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.camera_alt,
          size: 14,
          color: HiPopColors.darkTextSecondary,
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: onInstagramTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              instagramHandle!.startsWith('@')
                ? instagramHandle!
                : '@$instagramHandle',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[700],
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVendorItems(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.local_grocery_store,
              size: 14,
              color: Colors.green[600],
            ),
            const SizedBox(width: 4),
            Text(
              'Available items:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.green[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        VendorItemsWidget.compact(items: vendorItems!),
      ],
    );
  }

  Widget _buildTags(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: tags!.take(3).map((tag) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: UIConstants.smallSpacing,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity( 0.1),
          borderRadius: BorderRadius.circular(UIConstants.tagBorderRadius),
        ),
        child: Text(
          tag,
          style: TextStyle(
            fontSize: 10,
            color: Colors.purple[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      )).toList(),
    );
  }
}