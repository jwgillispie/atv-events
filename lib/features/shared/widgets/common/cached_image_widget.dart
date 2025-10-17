import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'loading_widget.dart';

class CachedImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? backgroundColor;

  const CachedImageWidget({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? _buildLoadingPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _buildErrorPlaceholder(),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    if (backgroundColor != null) {
      imageWidget = Container(
        width: width,
        height: height,
        color: backgroundColor,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.image,
        size: (width != null && height != null) 
            ? (width! < height! ? width! * 0.3 : height! * 0.3)
            : 48,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: (width != null && height != null) 
                ? (width! < height! ? width! * 0.2 : height! * 0.2)
                : 32,
            color: Colors.grey[400],
          ),
          if (width != null && width! > 100) ...[
            const SizedBox(height: 4),
            Text(
              'Image not available',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class CircularCachedImage extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Widget? placeholder;

  const CircularCachedImage({
    super.key,
    this.imageUrl,
    required this.radius,
    this.backgroundColor,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey[200],
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                placeholder: (context, url) => placeholder ?? 
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                errorWidget: (context, url, error) => Icon(
                  Icons.person,
                  size: radius * 0.8,
                  color: Colors.grey[400],
                ),
              ),
            )
          : placeholder ?? Icon(
              Icons.person,
              size: radius * 0.8,
              color: Colors.grey[400],
            ),
    );
  }
}

class VendorPostImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final VoidCallback? onTap;

  const VendorPostImageWidget({
    super.key,
    this.imageUrl,
    this.height = 200,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity( 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: CachedImageWidget(
          imageUrl: imageUrl,
          height: height,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(8),
          placeholder: ShimmerLoading(
            width: double.infinity,
            height: height,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}