import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/shared/services/utilities/photo_service.dart';
import 'package:atv_events/features/shared/models/user_profile.dart';
import 'package:atv_events/features/shared/services/user/user_profile_service.dart';

class ProfilePhotoUploadWidget extends StatefulWidget {
  final UserProfile? userProfile;
  final String userId;
  final String userType; // 'vendor' or 'market_organizer'
  final VoidCallback? onPhotoUpdated;

  const ProfilePhotoUploadWidget({
    super.key,
    required this.userProfile,
    required this.userId,
    required this.userType,
    this.onPhotoUpdated,
  });

  @override
  State<ProfilePhotoUploadWidget> createState() => _ProfilePhotoUploadWidgetState();
}

class _ProfilePhotoUploadWidgetState extends State<ProfilePhotoUploadWidget> {
  final ImagePicker _picker = ImagePicker();
  final UserProfileService _profileService = UserProfileService();
  bool _isUploading = false;
  String? _currentPhotoUrl;

  @override
  void initState() {
    super.initState();
    _currentPhotoUrl = widget.userProfile?.profilePhotoUrl;
  }

  Future<void> _pickAndUploadImage() async {
    if (_isUploading) return;

    try {
      // Pick image from gallery
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512, // Optimize for profile photos
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
      });

      // Upload to Firebase Storage
      final File imageFile = File(image.path);
      final String downloadUrl = await PhotoService.uploadProfilePhoto(
        widget.userId,
        imageFile,
      );

      // Update user profile in Firestore
      if (widget.userProfile != null) {
        final updatedProfile = widget.userProfile!.copyWith(
          profilePhotoUrl: downloadUrl,
        );
        await _profileService.updateUserProfile(updatedProfile);
      }

      setState(() {
        _currentPhotoUrl = downloadUrl;
        _isUploading = false;
      });

      // Notify parent widget
      widget.onPhotoUpdated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.userType == 'vendor'
                ? 'Business logo updated successfully'
                : 'Organization logo updated successfully',
            ),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: ${e.toString()}'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: HiPopColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose Photo Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: widget.userType == 'vendor'
                        ? HiPopColors.vendorAccent.withOpacity(0.2)
                        : HiPopColors.organizerAccent.withOpacity(0.2),
                    child: Icon(
                      Icons.photo_library,
                      color: widget.userType == 'vendor'
                          ? HiPopColors.vendorAccent
                          : HiPopColors.organizerAccent,
                    ),
                  ),
                  title: Text(
                    'Choose from Gallery',
                    style: TextStyle(color: HiPopColors.darkTextPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage();
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: widget.userType == 'vendor'
                        ? HiPopColors.vendorAccent.withOpacity(0.2)
                        : HiPopColors.organizerAccent.withOpacity(0.2),
                    child: Icon(
                      Icons.camera_alt,
                      color: widget.userType == 'vendor'
                          ? HiPopColors.vendorAccent
                          : HiPopColors.organizerAccent,
                    ),
                  ),
                  title: Text(
                    'Take a Photo',
                    style: TextStyle(color: HiPopColors.darkTextPrimary),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? photo = await _picker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 512,
                      maxHeight: 512,
                      imageQuality: 85,
                    );
                    if (photo != null) {
                      setState(() {
                        _isUploading = true;
                      });

                      try {
                        final File imageFile = File(photo.path);
                        final String downloadUrl = await PhotoService.uploadProfilePhoto(
                          widget.userId,
                          imageFile,
                        );

                        if (widget.userProfile != null) {
                          final updatedProfile = widget.userProfile!.copyWith(
                            profilePhotoUrl: downloadUrl,
                          );
                          await _profileService.updateUserProfile(updatedProfile);
                        }

                        setState(() {
                          _currentPhotoUrl = downloadUrl;
                          _isUploading = false;
                        });

                        widget.onPhotoUpdated?.call();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                widget.userType == 'vendor'
                                  ? 'Business logo updated successfully'
                                  : 'Organization logo updated successfully',
                              ),
                              backgroundColor: HiPopColors.successGreen,
                            ),
                          );
                        }
                      } catch (e) {
                        setState(() {
                          _isUploading = false;
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to upload photo: ${e.toString()}'),
                              backgroundColor: HiPopColors.errorPlum,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
                if (_currentPhotoUrl != null)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: HiPopColors.errorPlum.withOpacity(0.2),
                      child: Icon(
                        Icons.delete,
                        color: HiPopColors.errorPlum,
                      ),
                    ),
                    title: Text(
                      'Remove Photo',
                      style: TextStyle(color: HiPopColors.errorPlum),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      // Confirm deletion
                      final bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: HiPopColors.darkSurface,
                          title: Text(
                            'Remove Profile Photo?',
                            style: TextStyle(color: HiPopColors.darkTextPrimary),
                          ),
                          content: Text(
                            'This will remove your current profile photo.',
                            style: TextStyle(color: HiPopColors.darkTextSecondary),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: HiPopColors.errorPlum,
                              ),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        setState(() {
                          _isUploading = true;
                        });

                        try {
                          if (widget.userProfile != null) {
                            final updatedProfile = widget.userProfile!.copyWith(
                              profilePhotoUrl: null,
                            );
                            await _profileService.updateUserProfile(updatedProfile);
                          }

                          setState(() {
                            _currentPhotoUrl = null;
                            _isUploading = false;
                          });

                          widget.onPhotoUpdated?.call();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profile photo removed'),
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() {
                            _isUploading = false;
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to remove photo: ${e.toString()}'),
                                backgroundColor: HiPopColors.errorPlum,
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = widget.userType == 'vendor'
        ? HiPopColors.vendorAccent
        : HiPopColors.organizerAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.userType == 'vendor' ? 'Business Logo' : 'Organization Logo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: HiPopColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 75,
                  backgroundColor: accentColor.withOpacity(0.1),
                  backgroundImage: _currentPhotoUrl != null
                      ? CachedNetworkImageProvider(_currentPhotoUrl!)
                      : null,
                  child: _currentPhotoUrl == null
                      ? Icon(
                          widget.userType == 'vendor'
                            ? Icons.store
                            : Icons.business,
                          size: 50,
                          color: accentColor,
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: HiPopColors.darkBackground,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                    onPressed: _isUploading ? null : _showImageSourceDialog,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _isUploading
                ? 'Uploading...'
                : 'Tap to ${_currentPhotoUrl != null ? 'change' : 'add'} photo',
            style: TextStyle(
              fontSize: 12,
              color: HiPopColors.darkTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}