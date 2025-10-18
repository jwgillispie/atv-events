import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../premium/models/user_subscription.dart';
import '../../../premium/services/subscription_service.dart';
import '../../../premium/widgets/upgrade_prompt_widget.dart';

class PhotoUploadWidget extends StatefulWidget {
  final Function(List<File>) onPhotosSelected;
  final Function(List<String>)? onExistingPhotosChanged;
  final List<String>? initialImagePaths;
  final String? userId;
  final String? userType;
  final int? maxPhotos; // Optional max photos override

  const PhotoUploadWidget({
    super.key,
    required this.onPhotosSelected,
    this.onExistingPhotosChanged,
    this.initialImagePaths,
    this.userId,
    this.userType,
    this.maxPhotos, // Default will be 4 for popups, 3 for products
  });

  @override
  State<PhotoUploadWidget> createState() => _PhotoUploadWidgetState();
}

class _PhotoUploadWidgetState extends State<PhotoUploadWidget> {
  final List<File> _selectedImages = [];
  final List<XFile> _selectedWebImages = []; // For web platform
  final List<String> _existingImageUrls = [];
  final ImagePicker _picker = ImagePicker();
  UserSubscription? _subscription;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePaths != null) {
      // Separate URLs from local file paths
      for (String path in widget.initialImagePaths!) {
        if (path.startsWith('http') || path.startsWith('https')) {
          _existingImageUrls.add(path);
        } else {
          _selectedImages.add(File(path));
        }
      }
    }
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    if (widget.userId != null) {
      try {
        final subscription = await SubscriptionService.getUserSubscription(widget.userId!);
        setState(() {
          _subscription = subscription;
        });
      } catch (e) {
      }
    }
  }

  Future<void> _handleAddPhoto() async {
    if (_isLoading) return;

    final currentCount = (kIsWeb ? _selectedWebImages.length : _selectedImages.length) + _existingImageUrls.length;
    final limit = _getPhotoLimit();

    // Check photo limit
    if (currentCount >= limit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You can add up to $limit photos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          // For web, keep XFile reference
          setState(() {
            _selectedWebImages.add(image);
          });
          // Convert XFile to File for callback (this will work differently on web)
          // On web, File(path) won't work the same way, but the path can still be used
          widget.onPhotosSelected([File(image.path)]);
        } else {
          // For mobile platforms, convert to File
          final file = File(image.path);
          setState(() {
            _selectedImages.add(file);
          });
          widget.onPhotosSelected(_selectedImages);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removePhoto(int index) {
    final totalExisting = _existingImageUrls.length;
    
    setState(() {
      if (index < totalExisting) {
        // Removing an existing URL
        _existingImageUrls.removeAt(index);
        widget.onExistingPhotosChanged?.call(_existingImageUrls);
      } else {
        // Removing a newly selected file
        if (kIsWeb) {
          _selectedWebImages.removeAt(index - totalExisting);
        } else {
          _selectedImages.removeAt(index - totalExisting);
        }
      }
    });
    
    if (kIsWeb) {
      // For web, convert XFiles to Files for callback
      widget.onPhotosSelected(_selectedWebImages.map((xFile) => File(xFile.path)).toList());
    } else {
      widget.onPhotosSelected(_selectedImages);
    }
  }

  int _getPhotoLimit() {
    // Use the maxPhotos parameter if provided, otherwise default to 4
    // No paywall - all users get the same limit
    return widget.maxPhotos ?? 4;
  }

  void _showUpgradePrompt() {
    // TODO: Removed for ATV Events demo - Premium features disabled
    // ContextualUpgradePrompts.showLimitReachedPrompt(
    //   context,
    //   userId: widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '',
    //   userType: widget.userType ?? 'vendor',
    //   limitName: 'photos per post',
    //   currentUsage: (kIsWeb ? _selectedWebImages.length : _selectedImages.length) + _existingImageUrls.length,
    //   limit: 3,
    // );
  }

  void _showUpgradePromptWithoutLimitCheck() {
    // TODO: Removed for ATV Events demo - Premium features disabled
    // Show upgrade prompt without the "limit reached" message
    // This is called when user clicks "upgrade for unlimited photos" button
    // ContextualUpgradePrompts.showFeatureLockedPrompt(
    //   context,
    //   userId: widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '',
    //   userType: widget.userType ?? 'vendor',
    //   featureName: 'unlimited_photos',
    //   featureDisplayName: 'Unlimited Photos',
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        if ((kIsWeb ? _selectedWebImages.isNotEmpty : _selectedImages.isNotEmpty) || _existingImageUrls.isNotEmpty) _buildPhotoGrid(),
        _buildAddPhotoSection(),
      ],
    );
  }

  Widget _buildNewImageWidget(int index) {
    if (kIsWeb) {
      // For web, we need to handle XFile differently
      final xFile = _selectedWebImages[index];
      return FutureBuilder<Uint8List>(
        future: xFile.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            );
          } else {
            return Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
        },
      );
    } else {
      // For mobile platforms, use Image.file
      return Image.file(
        _selectedImages[index],
        width: 120,
        height: 120,
        fit: BoxFit.cover,
      );
    }
  }

  Widget _buildHeader() {
    final limit = _getPhotoLimit();
    final count = (kIsWeb ? _selectedWebImages.length : _selectedImages.length) + _existingImageUrls.length;

    return Row(
      children: [
        Text(
          'Photos',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const Spacer(),
        Text(
          '$count/$limit photos',
          style: TextStyle(
            fontSize: 14,
            color: count >= limit 
                ? Colors.red[600] 
                : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoGrid() {
    final totalCount = _existingImageUrls.length + 
        (kIsWeb ? _selectedWebImages.length : _selectedImages.length);
    
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: totalCount,
        itemBuilder: (context, index) {
          final isExisting = index < _existingImageUrls.length;
          
          return Container(
            margin: const EdgeInsets.only(right: 12),
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: isExisting
                      ? CachedNetworkImage(
                          imageUrl: _existingImageUrls[index],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.error),
                          ),
                        )
                      : _buildNewImageWidget(index - _existingImageUrls.length),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                      onPressed: () => _removePhoto(index),
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddPhotoSection() {
    final limit = _getPhotoLimit();
    final count = (kIsWeb ? _selectedWebImages.length : _selectedImages.length) + _existingImageUrls.length;
    final canAddMore = count < limit;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: _isLoading ? null : (canAddMore ? _handleAddPhoto : null),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(
              color: canAddMore ? const Color(0xFF6F9686) : Colors.grey.shade300, // Soft Sage for active
              style: BorderStyle.solid,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
            color: canAddMore ? const Color(0xFFF3D2E1).withOpacity( 0.3) : Colors.grey.shade50, // Pale Pink background
          ),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      canAddMore ? Icons.add_photo_alternate : Icons.photo_library,
                      size: 32,
                      color: canAddMore ? const Color(0xFF558B6E) : Colors.grey[400], // Deep Sage
                    ),
                    const SizedBox(height: 8),
                    Text(
                      canAddMore 
                          ? 'Add Photo' 
                          : 'Photo limit reached',
                      style: TextStyle(
                        fontSize: 14,
                        color: canAddMore ? const Color(0xFF558B6E) : Colors.grey[500], // Deep Sage
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Legacy single photo upload widget for backward compatibility
class SinglePhotoUploadWidget extends StatefulWidget {
  final Function(File) onPhotoSelected;
  final String? initialImagePath;

  const SinglePhotoUploadWidget({
    super.key,
    required this.onPhotoSelected,
    this.initialImagePath,
  });

  @override
  State<SinglePhotoUploadWidget> createState() => _SinglePhotoUploadWidgetState();
}

class _SinglePhotoUploadWidgetState extends State<SinglePhotoUploadWidget> {
  @override
  Widget build(BuildContext context) {
    return PhotoUploadWidget(
      onPhotosSelected: (photos) {
        if (photos.isNotEmpty) {
          widget.onPhotoSelected(photos.first);
        }
      },
      initialImagePaths: widget.initialImagePath != null ? [widget.initialImagePath!] : null,
    );
  }
}