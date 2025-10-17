import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/shared/services/utilities/remote_config_service.dart';
import 'package:atv_events/features/shared/services/utilities/url_launcher_service.dart';

/// A Strava-style preview widget that shows a map and photos
/// in a horizontal layout for all types of feed cards (markets, events, vendors)
class FeedMapPreview extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final String location;
  final List<String> photoUrls;
  final VoidCallback onPhotoTap;
  final double height;
  final double borderRadius;

  const FeedMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.location,
    required this.photoUrls,
    required this.onPhotoTap,
    this.height = 200,
    this.borderRadius = 12,
  });

  Future<String> _buildMapUrl() async {
    final apiKey = await RemoteConfigService.getGoogleMapsApiKey();
    if (latitude == null || longitude == null) {
      // Return a placeholder map if coordinates are not available
      return 'https://maps.googleapis.com/maps/api/staticmap?'
          'center=United+States'
          '&zoom=4'
          '&size=400x400'
          '&maptype=roadmap'
          '&style=feature:all|element:labels|visibility:off'
          '&style=feature:water|element:geometry|color:0x9CA5B3'
          '&style=feature:landscape|element:geometry|color:0x1F2937'
          '&key=$apiKey';
    }
    
    // Build proper Google Maps Static API URL with dark mode styling
    return 'https://maps.googleapis.com/maps/api/staticmap?'
        'center=$latitude,$longitude'
        '&zoom=15'
        '&size=400x400'
        '&maptype=roadmap'
        '&markers=color:0xFF6366F1%7Csize:mid%7C$latitude,$longitude'
        '&style=feature:all|element:geometry|color:0x242f3e'
        '&style=feature:all|element:labels.text.stroke|color:0x242f3e'
        '&style=feature:all|element:labels.text.fill|color:0x746855'
        '&style=feature:administrative.locality|element:labels.text.fill|color:0xd59563'
        '&style=feature:poi|element:labels.text.fill|color:0xd59563'
        '&style=feature:poi.park|element:geometry|color:0x263c3f'
        '&style=feature:poi.park|element:labels.text.fill|color:0x6b9a76'
        '&style=feature:road|element:geometry|color:0x38414e'
        '&style=feature:road|element:geometry.stroke|color:0x212a37'
        '&style=feature:road|element:labels.text.fill|color:0x9ca5b3'
        '&style=feature:road.highway|element:geometry|color:0x746855'
        '&style=feature:road.highway|element:geometry.stroke|color:0x1f2835'
        '&style=feature:road.highway|element:labels.text.fill|color:0xf3d19c'
        '&style=feature:transit|element:geometry|color:0x2f3948'
        '&style=feature:transit.station|element:labels.text.fill|color:0xd59563'
        '&style=feature:water|element:geometry|color:0x17263c'
        '&style=feature:water|element:labels.text.fill|color:0x515c6d'
        '&style=feature:water|element:labels.text.stroke|color:0x17263c'
        '&key=$apiKey';
  }

  void _launchMaps(BuildContext context) {
    if (latitude != null && longitude != null) {
      // Use coordinates for more precise location
      final coordinateString = '$latitude,$longitude';
      UrlLauncherService.launchMaps(coordinateString, context: context);
    } else {
      UrlLauncherService.launchMaps(location, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (photoUrls.isEmpty && latitude == null && longitude == null) {
      // Don't show preview if no content available
      return const SizedBox.shrink();
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        children: [
          // Left side - Map (50%)
          if (latitude != null && longitude != null)
            Expanded(
              child: GestureDetector(
                onTap: () => _launchMaps(context),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(borderRadius),
                      bottomLeft: Radius.circular(borderRadius),
                      topRight: photoUrls.isEmpty ? Radius.circular(borderRadius) : Radius.zero,
                      bottomRight: photoUrls.isEmpty ? Radius.circular(borderRadius) : Radius.zero,
                    ),
                    color: HiPopColors.darkSurface,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(borderRadius),
                      bottomLeft: Radius.circular(borderRadius),
                      topRight: photoUrls.isEmpty ? Radius.circular(borderRadius) : Radius.zero,
                      bottomRight: photoUrls.isEmpty ? Radius.circular(borderRadius) : Radius.zero,
                    ),
                    child: FutureBuilder<String>(
                      future: _buildMapUrl(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: snapshot.data!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: HiPopColors.darkSurface,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        HiPopColors.shopperAccent,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: HiPopColors.darkSurface,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: HiPopColors.darkTextSecondary,
                                        size: 32,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap to open maps',
                                        style: TextStyle(
                                          color: HiPopColors.darkTextSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Map overlay gradient for better visibility
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity( 0.2),
                                    ],
                                  ),
                                ),
                              ),
                              // Location icon overlay
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity( 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'View Map',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return Container(
                          color: HiPopColors.darkSurface,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                HiPopColors.shopperAccent,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          
          // Spacer between map and photo
          if (photoUrls.isNotEmpty && (latitude != null && longitude != null))
            const SizedBox(width: 4),
          
          // Right side - Photo(s) (50%)
          if (photoUrls.isNotEmpty)
            Expanded(
              child: GestureDetector(
                onTap: onPhotoTap,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: (latitude == null || longitude == null) 
                          ? Radius.circular(borderRadius) 
                          : Radius.zero,
                      bottomLeft: (latitude == null || longitude == null) 
                          ? Radius.circular(borderRadius) 
                          : Radius.zero,
                      topRight: Radius.circular(borderRadius),
                      bottomRight: Radius.circular(borderRadius),
                    ),
                    color: HiPopColors.darkSurface,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: (latitude == null || longitude == null) 
                          ? Radius.circular(borderRadius) 
                          : Radius.zero,
                      bottomLeft: (latitude == null || longitude == null) 
                          ? Radius.circular(borderRadius) 
                          : Radius.zero,
                      topRight: Radius.circular(borderRadius),
                      bottomRight: Radius.circular(borderRadius),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: photoUrls.first,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: HiPopColors.darkSurface,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  HiPopColors.shopperAccent,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: HiPopColors.darkSurface,
                            child: Icon(
                              Icons.image_not_supported,
                              color: HiPopColors.darkTextSecondary,
                              size: 32,
                            ),
                          ),
                        ),
                        // Photo count overlay if multiple photos
                        if (photoUrls.length > 1)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity( 0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.photo_library,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+${photoUrls.length - 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}