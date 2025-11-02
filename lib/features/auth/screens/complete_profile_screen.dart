import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import 'package:atv_events/features/shared/models/user_profile.dart';

/// Optional profile completion screen
/// Can be skipped and filled out later
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();

  List<String> _selectedCategories = [];
  bool _isLoading = false;
  String? _userType;

  @override
  void dispose() {
    _businessNameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(UserProfile userProfile) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_businessNameController.text.trim().isNotEmpty) {
        if (_userType == 'vendor') {
          updates['businessName'] = _businessNameController.text.trim();
        } else if (_userType == 'market_organizer') {
          updates['organizationName'] = _businessNameController.text.trim();
        }
      }

      if (_bioController.text.trim().isNotEmpty) {
        updates['bio'] = _bioController.text.trim();
      }

      if (_phoneController.text.trim().isNotEmpty) {
        updates['phoneNumber'] = _phoneController.text.trim();
      }

      if (_websiteController.text.trim().isNotEmpty) {
        updates['website'] = _websiteController.text.trim();
      }

      if (_selectedCategories.isNotEmpty && _userType == 'vendor') {
        updates['productCategories'] = _selectedCategories;
      }

      // Update user profile
      await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(userProfile.userId)
          .update(updates);

      if (mounted) {
        // Navigate to CEO verification pending screen
        context.go('/auth/verification-pending');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _skip() async {
    // Just navigate to CEO verification pending
    if (mounted) {
      context.go('/auth/verification-pending');
    }
  }

  Color _getAccentColor() {
    switch (_userType) {
      case 'vendor':
        return HiPopColors.vendorAccent;
      case 'market_organizer':
        return HiPopColors.organizerAccent;
      default:
        return HiPopColors.accentMauve;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated || state.userProfile == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userProfile = state.userProfile!;
        _userType = userProfile.userType;
        final colorScheme = _getAccentColor();
        final isVendor = _userType == 'vendor';
        final isOrganizer = _userType == 'market_organizer';

        return Scaffold(
          backgroundColor: HiPopColors.darkBackground,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              TextButton(
                onPressed: _skip,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 16,
                    color: HiPopColors.darkTextSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isVendor
                                ? Icons.store
                                : isOrganizer
                                    ? Icons.business
                                    : Icons.person,
                            color: colorScheme,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Complete Your Profile',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: HiPopColors.darkTextPrimary,
                                ),
                              ),
                              Text(
                                'Optional - you can do this later',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: HiPopColors.darkTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Form fields
                    _buildTextField(
                      controller: _businessNameController,
                      label: isVendor
                          ? 'Business Name'
                          : isOrganizer
                              ? 'Organization Name'
                              : 'Display Name',
                      hint: isVendor
                          ? 'e.g., Fresh Harvest Farms'
                          : isOrganizer
                              ? 'e.g., Downtown Markets Association'
                              : 'Your name',
                      icon: Icons.business_outlined,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _bioController,
                      label: 'About',
                      hint: isVendor
                          ? 'Tell shoppers about your products...'
                          : isOrganizer
                              ? 'Describe your markets and experience...'
                              : 'Tell us about yourself...',
                      icon: Icons.description_outlined,
                      colorScheme: colorScheme,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number (optional)',
                      hint: '(555) 123-4567',
                      icon: Icons.phone_outlined,
                      colorScheme: colorScheme,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _websiteController,
                      label: 'Website (optional)',
                      hint: 'https://yourwebsite.com',
                      icon: Icons.link,
                      colorScheme: colorScheme,
                      keyboardType: TextInputType.url,
                    ),

                    // Categories for vendors
                    if (isVendor) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Product Categories (optional)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => _showCategoryPicker(colorScheme),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: HiPopColors.darkSurfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: HiPopColors.darkBorder.withAlpha(125),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.category_outlined,
                                color: HiPopColors.darkTextSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedCategories.isEmpty
                                      ? 'Select categories'
                                      : _selectedCategories.join(', '),
                                  style: TextStyle(
                                    color: _selectedCategories.isEmpty
                                        ? HiPopColors.darkTextSecondary
                                            .withAlpha(125)
                                        : HiPopColors.darkTextPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: HiPopColors.darkTextSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.withAlpha(50),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: colorScheme,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You can update this information anytime in your profile settings',
                              style: const TextStyle(
                                fontSize: 13,
                                color: HiPopColors.darkTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _skip,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: HiPopColors.darkTextSecondary,
                              side: BorderSide(color: HiPopColors.darkBorder),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Skip for now'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _isLoading ? null : () => _saveProfile(userProfile),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Continue'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color colorScheme,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: HiPopColors.darkTextPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: HiPopColors.darkSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: HiPopColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: HiPopColors.darkBorder.withAlpha(125)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme, width: 2),
        ),
        labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
        hintStyle: TextStyle(
          color: HiPopColors.darkTextSecondary.withAlpha(125),
        ),
        prefixIconColor: HiPopColors.darkTextSecondary,
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }

  Future<void> _showCategoryPicker(Color colorScheme) async {
    final selected = await CategorySelectionDialog.show(
      context,
      selectedCategories: _selectedCategories,
    );

    if (selected != null) {
      setState(() {
        _selectedCategories = selected;
      });
    }
  }
}
