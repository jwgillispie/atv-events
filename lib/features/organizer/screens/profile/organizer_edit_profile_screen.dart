import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_event.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/shared/models/user_profile.dart';
import 'package:hipop/features/shared/services/user/user_profile_service.dart';
import 'package:hipop/features/shared/widgets/profile/profile_photo_upload_widget.dart';

class OrganizerEditProfileScreen extends StatefulWidget {
  const OrganizerEditProfileScreen({super.key});

  @override
  State<OrganizerEditProfileScreen> createState() => _OrganizerEditProfileScreenState();
}

class _OrganizerEditProfileScreenState extends State<OrganizerEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _instagramController = TextEditingController();
  final _websiteController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  
  final UserProfileService _profileService = UserProfileService();
  UserProfile? _currentProfile;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _displayNameController.dispose();
    _businessNameController.dispose();
    _bioController.dispose();
    _instagramController.dispose();
    _websiteController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Try to get existing profile
        UserProfile? profile = await _profileService.getUserProfile(user.uid);
        
        // If no profile exists, create one
        profile ??= await _profileService.ensureUserProfile(
            userType: 'market_organizer',
            displayName: user.displayName,
          );

        setState(() {
          _currentProfile = profile;
          _displayNameController.text = profile!.displayName ?? '';
          _businessNameController.text = profile.businessName ?? '';
          _bioController.text = profile.bio ?? '';
          _instagramController.text = profile.instagramHandle ?? '';
          _websiteController.text = profile.website ?? '';
          _phoneNumberController.text = profile.phoneNumber ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving || _currentProfile == null) return;
    
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Update the profile with new values
      final updatedProfile = _currentProfile!.copyWith(
        displayName: _displayNameController.text.trim().isEmpty 
            ? null 
            : _displayNameController.text.trim(),
        businessName: _businessNameController.text.trim().isEmpty 
            ? null 
            : _businessNameController.text.trim(),
        bio: _bioController.text.trim().isEmpty 
            ? null 
            : _bioController.text.trim(),
        instagramHandle: _instagramController.text.trim().isEmpty 
            ? null 
            : _instagramController.text.trim(),
        website: _websiteController.text.trim().isEmpty 
            ? null 
            : _websiteController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim().isEmpty 
            ? null 
            : _phoneNumberController.text.trim(),
      );

      // Save to Firestore (this will also update Firebase Auth display name)
      final savedProfile = await _profileService.updateUserProfile(updatedProfile);

      setState(() {
        _currentProfile = savedProfile;
        _successMessage = 'Profile updated successfully';
      });
      
      // Reload user to update auth state
      context.read<AuthBloc>().add(ReloadUserEvent());
      
      // Navigate back after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && context.mounted) {
          context.pop();
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update profile: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  String? _validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return null; // URL is optional
    }
    
    // Add https:// if no protocol is specified
    String url = value.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    
    // Basic URL validation
    final urlPattern = RegExp(
      r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
      caseSensitive: false,
    );
    
    if (!urlPattern.hasMatch(url)) {
      return 'Please enter a valid URL';
    }
    
    return null;
  }

  String? _validateInstagram(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Instagram is optional
    }
    
    // Remove @ if present at the start
    String handle = value.trim();
    if (handle.startsWith('@')) {
      handle = handle.substring(1);
    }
    
    // Basic Instagram handle validation
    final instagramPattern = RegExp(r'^[a-zA-Z0-9_.]+$');
    
    if (!instagramPattern.hasMatch(handle)) {
      return 'Please enter a valid Instagram handle';
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        backgroundColor: HiPopColors.darkSurface,
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        shape: Border(
          bottom: BorderSide(
            color: HiPopColors.darkBorder.withOpacity( 0.3),
            width: 1,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: HiPopColors.organizerAccent,
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  
                  // Profile Header Card
                  Card(
                    color: HiPopColors.darkSurface,
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: HiPopColors.darkBorder.withOpacity( 0.3),
                        width: 1,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            HiPopColors.organizerAccent.withOpacity( 0.1),
                            HiPopColors.organizerAccent.withOpacity( 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Profile Photo Upload at the top
                          if (_currentProfile != null) ...[
                            ProfilePhotoUploadWidget(
                              userProfile: _currentProfile,
                              userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                              userType: 'market_organizer',
                              onPhotoUpdated: () {
                                _loadUserData(); // Reload profile data
                              },
                            ),
                            const SizedBox(height: 20),
                          ] else ...[
                            CircleAvatar(
                              backgroundColor: HiPopColors.organizerAccent.withOpacity(0.2),
                              radius: 60,
                              child: Icon(
                                Icons.business,
                                color: HiPopColors.organizerAccent,
                                size: 50,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          Text(
                            'Market Organizer Profile',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: HiPopColors.darkTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Update your public information',
                            style: TextStyle(
                              color: HiPopColors.darkTextSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  if (_errorMessage != null)
                    Card(
                      color: HiPopColors.errorPlum.withOpacity( 0.1),
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: HiPopColors.errorPlum.withOpacity( 0.3),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: HiPopColors.errorPlum,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: HiPopColors.errorPlum,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  if (_successMessage != null)
                    Card(
                      color: HiPopColors.successGreen.withOpacity( 0.1),
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: HiPopColors.successGreen.withOpacity( 0.3),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: HiPopColors.successGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: TextStyle(
                                  color: HiPopColors.successGreen,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Form Section
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Basic Information Section
                        Card(
                          color: HiPopColors.darkSurface,
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: HiPopColors.darkBorder.withOpacity( 0.3),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Basic Information',
                                  style: TextStyle(
                                    color: HiPopColors.darkTextPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Display Name
                                TextFormField(
                                  controller: _displayNameController,
                                  style: TextStyle(color: HiPopColors.darkTextPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Username',
                                    labelStyle: TextStyle(color: HiPopColors.darkTextSecondary),
                                    hintText: 'Enter your display name',
                                    hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withOpacity( 0.5)),
                                    prefixIcon: Icon(Icons.person_outline, color: HiPopColors.darkTextSecondary),
                                    filled: true,
                                    fillColor: HiPopColors.darkSurfaceVariant,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.darkBorder),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.darkBorder),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.organizerAccent, width: 2),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.errorPlum),
                                    ),
                                    errorStyle: TextStyle(color: HiPopColors.errorPlum),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter a display name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Business Name
                                TextFormField(
                                  controller: _businessNameController,
                                  style: TextStyle(color: HiPopColors.darkTextPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Organization Name',
                                    labelStyle: TextStyle(color: HiPopColors.darkTextSecondary),
                                    hintText: 'Enter your market organization name',
                                    hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withOpacity( 0.5)),
                                    prefixIcon: Icon(Icons.business, color: HiPopColors.darkTextSecondary),
                                    filled: true,
                                    fillColor: HiPopColors.darkSurfaceVariant,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.darkBorder),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.darkBorder),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.organizerAccent, width: 2),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.errorPlum),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Bio/Description
                                TextFormField(
                                  controller: _bioController,
                                  style: TextStyle(color: HiPopColors.darkTextPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Business Description',
                                    labelStyle: TextStyle(color: HiPopColors.darkTextSecondary),
                                    hintText: 'Tell vendors and shoppers about your markets',
                                    hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withOpacity( 0.5)),
                                    prefixIcon: Icon(Icons.description_outlined, color: HiPopColors.darkTextSecondary),
                                    filled: true,
                                    fillColor: HiPopColors.darkSurfaceVariant,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.darkBorder),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.darkBorder),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.organizerAccent, width: 2),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.errorPlum),
                                    ),
                                    counterStyle: TextStyle(color: HiPopColors.darkTextSecondary),
                                  ),
                                  maxLines: 4,
                                  maxLength: 500,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Contact Information Section
                        Card(
                          color: HiPopColors.darkSurface,
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: HiPopColors.darkBorder.withOpacity( 0.3),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Contact & Social',
                                  style: TextStyle(
                                    color: HiPopColors.darkTextPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Instagram Handle
                                TextFormField(
                                  controller: _instagramController,
                                  style: TextStyle(color: HiPopColors.darkTextPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Instagram Handle',
                                    labelStyle: TextStyle(color: HiPopColors.darkTextSecondary),
                                    hintText: '@yourmarkethandle',
                                    hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withOpacity( 0.5)),
                                    prefixIcon: Icon(Icons.camera_alt_outlined, color: HiPopColors.darkTextSecondary),
                                    filled: true,
                                    fillColor: HiPopColors.darkSurfaceVariant,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.darkBorder),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.darkBorder),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.organizerAccent, width: 2),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.errorPlum),
                                    ),
                                    errorStyle: TextStyle(color: HiPopColors.errorPlum),
                                  ),
                                  validator: _validateInstagram,
                                ),
                                const SizedBox(height: 16),

                                // Website
                                TextFormField(
                                  controller: _websiteController,
                                  style: TextStyle(color: HiPopColors.darkTextPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Website',
                                    labelStyle: TextStyle(color: HiPopColors.darkTextSecondary),
                                    hintText: 'https://yourmarket.com',
                                    hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withOpacity( 0.5)),
                                    prefixIcon: Icon(Icons.language, color: HiPopColors.darkTextSecondary),
                                    filled: true,
                                    fillColor: HiPopColors.darkSurfaceVariant,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.darkBorder),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.darkBorder),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.organizerAccent, width: 2),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.errorPlum),
                                    ),
                                    errorStyle: TextStyle(color: HiPopColors.errorPlum),
                                  ),
                                  validator: _validateUrl,
                                ),
                                const SizedBox(height: 16),

                                // Phone Number
                                TextFormField(
                                  controller: _phoneNumberController,
                                  style: TextStyle(color: HiPopColors.darkTextPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Phone Number',
                                    labelStyle: TextStyle(color: HiPopColors.darkTextSecondary),
                                    hintText: '(555) 123-4567',
                                    hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withOpacity( 0.5)),
                                    prefixIcon: Icon(Icons.phone_outlined, color: HiPopColors.darkTextSecondary),
                                    filled: true,
                                    fillColor: HiPopColors.darkSurfaceVariant,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.darkBorder),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.darkBorder),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.organizerAccent, width: 2),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: HiPopColors.errorPlum),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Action Buttons
                        const SizedBox(height: 24),
                        
                        // Save button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: HiPopColors.organizerAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Save Profile',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Cancel button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => context.pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: HiPopColors.darkTextPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(
                                  color: HiPopColors.darkBorder,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: HiPopColors.darkTextSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}