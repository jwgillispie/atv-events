import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_event.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/market/models/market.dart';
import 'package:atv_events/features/market/services/market_service.dart';
import 'package:atv_events/features/premium/services/subscription_service.dart';
import 'package:atv_events/features/shared/services/location/places_service.dart';
import 'package:atv_events/features/shared/widgets/common/unified_location_search.dart';
import 'package:atv_events/features/shared/services/user/user_profile_service.dart';
import 'package:atv_events/features/shared/widgets/common/photo_upload_widget.dart';
import 'package:atv_events/features/shared/services/utilities/photo_service.dart';
import 'package:atv_events/features/shared/widgets/ai_flyer_upload_widget.dart';
import 'package:atv_events/features/organizer/models/organizer_vendor_post.dart';
import 'package:atv_events/features/organizer/services/vendor_management/vendor_post_service.dart';

class CreateMarketScreen extends StatefulWidget {
  const CreateMarketScreen({super.key});

  @override
  State<CreateMarketScreen> createState() => _CreateMarketScreenState();
}

class _CreateMarketScreenState extends State<CreateMarketScreen> {
  // Form data
  final Map<String, dynamic> _formData = {};
  final Map<String, bool> _completedFields = {};
  
  // Required fields
  final List<String> _requiredFields = [
    'name',
    'location',
    'marketDate',
    'operatingHours',
  ];
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _applicationUrlController = TextEditingController();
  final TextEditingController _boothFeeController = TextEditingController();
  
  // Premium fields
  final List<String> _premiumFields = [
    'lookingForVendors',
  ];
  
  // Photo management
  final List<File> _selectedPhotos = [];
  String? _uploadedImageUrl;
  
  bool _isLoading = false;
  final bool _hasAccess = true;
  bool _isPremium = false;
  bool _canCreateMoreMarkets = true; // REMOVED LIMITS - Always true

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    _checkMarketCreationLimit();
    
    // Initialize form data listeners
    _nameController.addListener(() {
      setState(() {
        _formData['name'] = _nameController.text;
        _completedFields['name'] = _nameController.text.trim().isNotEmpty;
      });
    });
    
    _descriptionController.addListener(() {
      setState(() {
        _formData['description'] = _descriptionController.text;
      });
    });
    
    _instagramController.addListener(() {
      setState(() {
        _formData['instagram'] = _instagramController.text;
      });
    });
    
    _websiteController.addListener(() {
      setState(() {
        _formData['website'] = _websiteController.text;
      });
    });

    _applicationUrlController.addListener(() {
      setState(() {
        _formData['applicationUrl'] = _applicationUrlController.text;
      });
    });

    _boothFeeController.addListener(() {
      setState(() {
        _formData['boothFee'] = double.tryParse(_boothFeeController.text) ?? 0;
      });
    });
  }
  
  Future<void> _checkPremiumStatus() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      final subscription = await SubscriptionService.getUserSubscription(authState.user.uid);
      setState(() {
        _isPremium = subscription != null && subscription.isActive;
      });
    }
  }
  
  Future<void> _checkMarketCreationLimit() async {
    // REMOVED LIMITS - All users can create unlimited markets
    if (mounted) {
      setState(() {
        _canCreateMoreMarkets = true; // Always allow market creation
      });
    }
  }

  /// Handle extracted flyer data and pre-fill form fields
  void _handleFlyerDataExtracted(Map<String, dynamic> data) {
    setState(() {
      // Pre-fill name/title
      if (data['title'] != null) {
        _nameController.text = data['title'];
      }

      // Pre-fill description
      if (data['description'] != null) {
        _descriptionController.text = data['description'];
      }

      // Pre-fill location (will need manual verification)
      if (data['location'] != null) {
        // Store for manual address selection
        // Can't auto-fill location without geocoding
      }

      // Show date/time info in snackbar for manual entry
      if (data['date'] != null || data['time'] != null) {
        String info = 'Extracted from flyer:\n';
        if (data['date'] != null) info += 'Date: ${data['date']}\n';
        if (data['time'] != null) info += 'Time: ${data['time']}';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(info),
            backgroundColor: HiPopColors.organizerAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });
  }
  
  void _showMarketLimitReachedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        title: Row(
          children: [
            Icon(Icons.warning, color: HiPopColors.warningAmber),
            const SizedBox(width: 8),
            Text(
              'Market Limit Reached',
              style: TextStyle(color: HiPopColors.darkTextPrimary),
            ),
          ],
        ),
        content: Text(
          'You have reached your monthly limit of 2 markets on the free tier. Upgrade to premium to create unlimited markets!',
          style: TextStyle(color: HiPopColors.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final authState = context.read<AuthBloc>().state;
              final user = authState is Authenticated ? authState.user : null;
              if (user != null) {
                context.go('/premium/upgrade?tier=marketOrganizerPremium&userId=${user.uid}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.premiumGold,
              foregroundColor: HiPopColors.darkBackground,
            ),
            child: const Text('Upgrade to Premium'),
          ),
        ],
      ),
    );
  }
  
  int get _completedRequiredCount {
    return _requiredFields.where((field) => _completedFields[field] == true).length;
  }
  
  bool get _canCreateMarket {
    // REMOVED LIMITS - Only check required fields completion
    return _requiredFields.every((field) => _completedFields[field] == true);
  }
  
  String _getProgressText() {
    return '$_completedRequiredCount of ${_requiredFields.length} required fields completed';
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: HiPopColors.darkTextTertiary,
        ),
      ),
    );
  }
  
  
  void _showPremiumDialog() {
    final authState = context.read<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        title: Text(
          '💎 Premium Feature',
          style: TextStyle(color: HiPopColors.darkTextPrimary),
        ),
        content: Text(
          'This feature is available for premium users. Upgrade to unlock vendor recruitment tools and more!',
          style: TextStyle(color: HiPopColors.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (user != null) {
                context.go('/premium/upgrade?tier=marketOrganizerPremium&userId=${user.uid}');
              } else {
                context.push('/premium/onboarding');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.premiumGold,
              foregroundColor: HiPopColors.darkBackground,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }
  
  
  
  
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
  
  Widget _buildInlineTextField({
    required String fieldKey,
    required String label,
    required TextEditingController controller,
    required String hintText,
    bool isRequired = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: HiPopColors.errorPlum,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: TextStyle(color: HiPopColors.darkTextPrimary),
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
            filled: true,
            fillColor: HiPopColors.darkSurface,
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
          ),
        ),
      ],
    );
  }
  
  Widget _buildDateField() {
    final selectedDate = _formData['marketDate'] as DateTime?;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Market Date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                color: HiPopColors.errorPlum,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: HiPopColors.organizerAccent,
                      onPrimary: HiPopColors.darkTextPrimary,
                      surface: HiPopColors.darkSurface,
                      onSurface: HiPopColors.darkTextPrimary,
                      surfaceContainerHighest: HiPopColors.darkSurfaceVariant,
                      onSurfaceVariant: HiPopColors.darkTextSecondary,
                      secondary: HiPopColors.organizerAccent,
                      onSecondary: HiPopColors.darkTextPrimary,
                      error: HiPopColors.errorPlum,
                      onError: HiPopColors.darkTextPrimary,
                      outline: HiPopColors.darkBorder,
                      shadow: HiPopColors.darkShadow,
                    ),
                    dialogTheme: DialogThemeData(
                      backgroundColor: HiPopColors.darkSurface,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    datePickerTheme: DatePickerThemeData(
                      backgroundColor: HiPopColors.darkSurface,
                      surfaceTintColor: Colors.transparent,
                      headerBackgroundColor: HiPopColors.darkSurfaceVariant,
                      headerForegroundColor: HiPopColors.darkTextPrimary,
                      weekdayStyle: TextStyle(color: HiPopColors.darkTextSecondary),
                      dayStyle: TextStyle(color: HiPopColors.darkTextPrimary),
                      yearStyle: TextStyle(color: HiPopColors.darkTextPrimary),
                      todayBackgroundColor: WidgetStateProperty.all(HiPopColors.darkSurfaceElevated),
                      todayForegroundColor: WidgetStateProperty.all(HiPopColors.organizerAccent),
                      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return HiPopColors.organizerAccent;
                        }
                        return null;
                      }),
                      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return HiPopColors.darkTextPrimary;
                        }
                        if (states.contains(WidgetState.disabled)) {
                          return HiPopColors.darkTextDisabled;
                        }
                        return HiPopColors.darkTextPrimary;
                      }),
                      yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return HiPopColors.organizerAccent;
                        }
                        return null;
                      }),
                      yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return HiPopColors.darkTextPrimary;
                        }
                        if (states.contains(WidgetState.disabled)) {
                          return HiPopColors.darkTextDisabled;
                        }
                        return HiPopColors.darkTextPrimary;
                      }),
                      confirmButtonStyle: TextButton.styleFrom(
                        foregroundColor: HiPopColors.organizerAccent,
                      ),
                      cancelButtonStyle: TextButton.styleFrom(
                        foregroundColor: HiPopColors.darkTextSecondary,
                      ),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              setState(() {
                _formData['marketDate'] = date;
                _completedFields['marketDate'] = true;
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: HiPopColors.darkSurface,
              border: Border.all(color: HiPopColors.darkBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: HiPopColors.organizerAccent),
                const SizedBox(width: 12),
                Text(
                  selectedDate != null 
                    ? '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}'
                    : 'Select market date',
                  style: TextStyle(
                    color: selectedDate != null 
                      ? HiPopColors.darkTextPrimary
                      : HiPopColors.darkTextTertiary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildTimeFields() {
    final startTime = _formData['startTime'] as TimeOfDay? ?? const TimeOfDay(hour: 9, minute: 0);
    final endTime = _formData['endTime'] as TimeOfDay? ?? const TimeOfDay(hour: 14, minute: 0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Operating Hours',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                color: HiPopColors.errorPlum,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Start Time
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: startTime,
                  );
                  if (time != null) {
                    setState(() {
                      _formData['startTime'] = time;
                      _updateOperatingHoursCompletion();
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurface,
                    border: Border.all(color: HiPopColors.darkBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: HiPopColors.organizerAccent),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimeOfDay(startTime),
                        style: TextStyle(
                          color: HiPopColors.darkTextPrimary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'to',
              style: TextStyle(
                color: HiPopColors.darkTextSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 16),
            // End Time
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: endTime,
                  );
                  if (time != null) {
                    setState(() {
                      _formData['endTime'] = time;
                      _updateOperatingHoursCompletion();
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurface,
                    border: Border.all(color: HiPopColors.darkBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: HiPopColors.organizerAccent),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimeOfDay(endTime),
                        style: TextStyle(
                          color: HiPopColors.darkTextPrimary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  void _updateOperatingHoursCompletion() {
    final hasStartTime = _formData['startTime'] != null;
    final hasEndTime = _formData['endTime'] != null;
    _completedFields['operatingHours'] = hasStartTime && hasEndTime;
    
    if (hasStartTime && hasEndTime) {
      _formData['operatingHours'] = '${_formatTimeOfDay(_formData['startTime'])} - ${_formatTimeOfDay(_formData['endTime'])}';
    }
  }
  
  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Location',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                color: HiPopColors.errorPlum,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        UnifiedLocationSearch(
          hintText: 'Search for market location...',
          initialLocation: _formData['address'],
          textStyle: TextStyle(
            color: HiPopColors.darkTextPrimary,
            fontSize: 16,
          ),
          onPlaceSelected: (placeDetails) {
            setState(() {
              _formData['location'] = placeDetails;
              _formData['address'] = placeDetails.formattedAddress;
              _completedFields['location'] = true;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search for market location...',
            hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
            filled: true,
            fillColor: HiPopColors.darkSurface,
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
          ),
        ),
      ],
    );
  }
  
  Widget _buildVendorToggle() {
    final isEnabled = _formData['lookingForVendors'] ?? false;

    return Card(
      color: HiPopColors.darkSurface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: HiPopColors.darkBorder.withOpacity( 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HiPopColors.premiumGold.withOpacity( 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.campaign,
                color: HiPopColors.premiumGold,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recruit Vendors',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEnabled ? 'Vendor recruitment enabled' : 'Enable vendor recruitment',
                    style: TextStyle(
                      fontSize: 14,
                      color: isEnabled
                        ? HiPopColors.successGreen
                        : HiPopColors.darkTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isEnabled,
              activeColor: HiPopColors.premiumGold,
              onChanged: (value) {
                if (!_isPremium) {
                  _showPremiumDialog();
                  return;
                }
                setState(() {
                  _formData['lookingForVendors'] = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationSettings() {
    final isLookingForVendors = _formData['lookingForVendors'] ?? false;
    final enableInAppApplications = _formData['enableInAppApplications'] ?? false;

    if (!isLookingForVendors) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // In-app applications toggle
        Card(
          color: HiPopColors.darkSurface,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: HiPopColors.darkBorder.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HiPopColors.organizerAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.app_registration,
                    color: HiPopColors.organizerAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'In-App Applications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        enableInAppApplications
                          ? 'Vendors apply within the app'
                          : 'Use external application link',
                        style: TextStyle(
                          fontSize: 14,
                          color: enableInAppApplications
                            ? HiPopColors.successGreen
                            : HiPopColors.darkTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enableInAppApplications,
                  activeColor: HiPopColors.organizerAccent,
                  onChanged: (value) {
                    setState(() {
                      _formData['enableInAppApplications'] = value;
                      if (!value) {
                        // Clear in-app application fields when disabled
                        _boothFeeController.clear();
                        _formData['boothFee'] = 0;
                        _formData['applicationDeadline'] = null;
                      } else {
                        // Clear external URL when enabling in-app
                        _applicationUrlController.clear();
                        _formData['applicationUrl'] = null;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        // Show external URL field if in-app applications disabled
        if (!enableInAppApplications) ...[
          const SizedBox(height: 16),
          _buildInlineTextField(
            fieldKey: 'applicationUrl',
            label: 'Application URL',
            controller: _applicationUrlController,
            hintText: 'https://yourwebsite.com/apply',
            keyboardType: TextInputType.url,
          ),
        ],

        // Show in-app application settings if enabled
        if (enableInAppApplications) ...[
          const SizedBox(height: 16),
          _buildInlineTextField(
            fieldKey: 'boothFee',
            label: 'Booth Fee',
            controller: _boothFeeController,
            hintText: '\$0.00',
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          _buildApplicationDeadlineField(),
        ],
      ],
    );
  }

  Widget _buildApplicationDeadlineField() {
    final selectedDate = _formData['applicationDeadline'] as DateTime?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Application Deadline',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: HiPopColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: HiPopColors.organizerAccent,
                      onPrimary: HiPopColors.darkTextPrimary,
                      surface: HiPopColors.darkSurface,
                      onSurface: HiPopColors.darkTextPrimary,
                      surfaceContainerHighest: HiPopColors.darkSurfaceVariant,
                      onSurfaceVariant: HiPopColors.darkTextSecondary,
                      secondary: HiPopColors.organizerAccent,
                      onSecondary: HiPopColors.darkTextPrimary,
                      error: HiPopColors.errorPlum,
                      onError: HiPopColors.darkTextPrimary,
                      outline: HiPopColors.darkBorder,
                      shadow: HiPopColors.darkShadow,
                    ),
                    dialogTheme: DialogThemeData(
                      backgroundColor: HiPopColors.darkSurface,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    datePickerTheme: DatePickerThemeData(
                      backgroundColor: HiPopColors.darkSurface,
                      surfaceTintColor: Colors.transparent,
                      headerBackgroundColor: HiPopColors.darkSurfaceVariant,
                      headerForegroundColor: HiPopColors.darkTextPrimary,
                      weekdayStyle: TextStyle(color: HiPopColors.darkTextSecondary),
                      dayStyle: TextStyle(color: HiPopColors.darkTextPrimary),
                      yearStyle: TextStyle(color: HiPopColors.darkTextPrimary),
                      todayBackgroundColor: WidgetStateProperty.all(HiPopColors.darkSurfaceElevated),
                      todayForegroundColor: WidgetStateProperty.all(HiPopColors.organizerAccent),
                      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return HiPopColors.organizerAccent;
                        }
                        return null;
                      }),
                      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return HiPopColors.darkTextPrimary;
                        }
                        if (states.contains(WidgetState.disabled)) {
                          return HiPopColors.darkTextDisabled;
                        }
                        return HiPopColors.darkTextPrimary;
                      }),
                      yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return HiPopColors.organizerAccent;
                        }
                        return null;
                      }),
                      yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return HiPopColors.darkTextPrimary;
                        }
                        if (states.contains(WidgetState.disabled)) {
                          return HiPopColors.darkTextDisabled;
                        }
                        return HiPopColors.darkTextPrimary;
                      }),
                      confirmButtonStyle: TextButton.styleFrom(
                        foregroundColor: HiPopColors.organizerAccent,
                      ),
                      cancelButtonStyle: TextButton.styleFrom(
                        foregroundColor: HiPopColors.darkTextSecondary,
                      ),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              setState(() {
                _formData['applicationDeadline'] = date;
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: HiPopColors.darkSurface,
              border: Border.all(color: HiPopColors.darkBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: HiPopColors.organizerAccent),
                const SizedBox(width: 12),
                Text(
                  selectedDate != null
                    ? '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}'
                    : 'Select application deadline (optional)',
                  style: TextStyle(
                    color: selectedDate != null
                      ? HiPopColors.darkTextPrimary
                      : HiPopColors.darkTextTertiary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  
  Future<void> _createMarket() async {
    // Capture auth state before async operations
    final authState = context.read<AuthBloc>().state;
    
    // Double-check the limit before creating
    if (authState is Authenticated) {
      final canCreate = await SubscriptionService.canCreateMarket(authState.user.uid);
      if (!canCreate) {
        if (mounted) {
          _showMarketLimitReachedDialog();
        }
        return;
      }
    }
    
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      if (authState is! Authenticated) {
        throw Exception('User not authenticated');
      }
      
      final location = _formData['location'] as PlaceDetails?;
      if (location == null) {
        throw Exception('Location is required');
      }
      
      // Upload photos if selected (up to 2)
      List<String> imageUrls = [];
      if (_selectedPhotos.isNotEmpty) {
        for (int i = 0; i < _selectedPhotos.length && i < 2; i++) {
          if (_selectedPhotos[i].existsSync()) {
            try {
              final imageUrl = await PhotoService.uploadPhoto(
                _selectedPhotos[i],
                'markets',
                authState.user.uid,
                customFileName: 'market_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
              );
              imageUrls.add(imageUrl);
            } catch (e) {
              // Continue without photo if upload fails
              // Log error silently and proceed without image
            }
          }
        }
      }
      
      // Parse address components
      final addressComponents = location.formattedAddress.split(', ');
      final address = addressComponents[0];
      final city = addressComponents.length > 1 ? addressComponents[1] : '';
      final stateAndZip = addressComponents.length > 2 ? addressComponents[2] : '';
      final state = stateAndZip.split(' ')[0];
      
      // Create market object with image URL if available
      final market = Market(
        id: '',
        name: _formData['name'] ?? 'New Market',
        address: address,
        city: city,
        state: state,
        latitude: location.latitude,
        longitude: location.longitude,
        description: _formData['description'],
        eventDate: _formData['marketDate'] ?? DateTime.now(),
        startTime: _formatTimeOfDay(_formData['startTime'] ?? const TimeOfDay(hour: 9, minute: 0)),
        endTime: _formatTimeOfDay(_formData['endTime'] ?? const TimeOfDay(hour: 14, minute: 0)),
        createdAt: DateTime.now(),
        associatedVendorIds: const [],
        flyerUrls: imageUrls.isNotEmpty ? imageUrls : const [],
        isActive: true,
        isLookingForVendors: _formData['lookingForVendors'] ?? false,
        applicationFee: 0, // Removed vendor fees
        dailyBoothFee: 0, // Removed vendor fees
        vendorSpotsTotal: null, // Removed vendor cap
        vendorSpotsAvailable: null, // Removed vendor cap
        instagramHandle: _formData['instagram'],
        organizerId: authState.user.uid,
        organizerName: authState.userProfile?.displayName ?? authState.userProfile?.businessName,
        // Application settings
        enableInAppApplications: _formData['enableInAppApplications'] ?? false,
        applicationUrl: _formData['applicationUrl'],
        boothFee: _formData['boothFee'] ?? 0,
        applicationDeadline: _formData['applicationDeadline'],
      );
      
      // Create market in Firestore
      final marketId = await MarketService.createMarket(market);

      // Increment monthly market count for free tier tracking
      await SubscriptionService.incrementMarketCount(authState.user.uid);

      // Associate market with user
      final userProfileService = UserProfileService();
      final updatedProfile = authState.userProfile!.addManagedMarket(marketId);
      await userProfileService.updateUserProfile(updatedProfile);

      // Create recruitment post if looking for vendors
      if (_formData['lookingForVendors'] == true) {
        try {
          final organizerEmail = authState.userProfile?.email ?? authState.user.email ?? '';
          final enableInAppApplications = _formData['enableInAppApplications'] ?? false;

          final recruitmentPost = OrganizerVendorPost(
            id: '', // Will be set by Firestore
            marketId: marketId,
            organizerId: authState.user.uid,
            title: _formData['name'] ?? 'New Market',
            description: _formData['description'] ?? '',
            categories: const [], // Can be added later based on market target categories
            requirements: VendorRequirements(
              experienceLevel: ExperienceLevel.beginner,
              applicationDeadline: _formData['applicationDeadline'],
              startDate: _formData['marketDate'],
              endDate: _formData['marketDate'],
              boothFee: _formData['boothFee']?.toDouble() ?? 0,
            ),
            contactInfo: ContactInfo(
              preferredMethod: enableInAppApplications
                  ? ContactMethod.form
                  : (_formData['applicationUrl'] != null && (_formData['applicationUrl'] as String).isNotEmpty
                      ? ContactMethod.form
                      : ContactMethod.email),
              email: organizerEmail,
              formUrl: _formData['applicationUrl'],
            ),
            status: PostStatus.active,
            visibility: PostVisibility.public,
            analytics: const PostAnalytics(),
            metadata: const PostMetadata(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            expiresAt: _formData['applicationDeadline'],
          );

          final postId = await OrganizerVendorPostService.createVendorPost(recruitmentPost);
          print('✅ Created recruitment post $postId for market $marketId');
        } catch (e) {
          print('⚠️ Failed to create recruitment post: $e');
          // Don't fail the market creation if recruitment post fails
        }
      }

      // Refresh AuthBloc
      if (mounted) {
        context.read<AuthBloc>().add(ReloadUserEvent());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Market created successfully!'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );

        // Return true to indicate successful creation
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating market: $e'),
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

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _instagramController.dispose();
    _websiteController.dispose();
    _applicationUrlController.dispose();
    _boothFeeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: HiPopColors.darkBackground,
        appBar: AppBar(
        backgroundColor: HiPopColors.darkSurface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: HiPopColors.darkTextPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Create New Market',
          style: TextStyle(
            color: HiPopColors.darkTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: HiPopColors.darkBorder.withOpacity( 0.3)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: _completedRequiredCount / _requiredFields.length,
                    backgroundColor: HiPopColors.darkBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      HiPopColors.successGreen,
                    ),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _getProgressText(),
                  style: TextStyle(
                    fontSize: 12,
                    color: HiPopColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 140, top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI Flyer Upload Widget
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AIFlyerUploadWidget(
                    onDataExtracted: _handleFlyerDataExtracted,
                    accentColor: HiPopColors.organizerAccent,
                  ),
                ),
                _buildSectionHeader('BASIC INFORMATION'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildInlineTextField(
                        fieldKey: 'name',
                        label: 'Market Name',
                        controller: _nameController,
                        hintText: 'e.g., Downtown Farmers Market',
                        isRequired: true,
                      ),
                      const SizedBox(height: 20),
                      _buildLocationField(),
                      const SizedBox(height: 20),
                      _buildInlineTextField(
                        fieldKey: 'description',
                        label: 'Description',
                        controller: _descriptionController,
                        hintText: 'Describe your market...',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                
                _buildSectionHeader('SCHEDULE & TIMING'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildDateField(),
                      const SizedBox(height: 20),
                      _buildTimeFields(),
                    ],
                  ),
                ),
                
                _buildSectionHeader('VENDOR MANAGEMENT'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildVendorToggle(),
                      _buildApplicationSettings(),
                    ],
                  ),
                ),
                
                _buildSectionHeader('MARKETING & MEDIA'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Photo Upload Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: HiPopColors.darkSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: HiPopColors.darkBorder.withOpacity( 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.photo_camera,
                                  color: HiPopColors.primaryDeepSage,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Market Photo',
                                  style: TextStyle(
                                    color: HiPopColors.darkTextPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Add a photo to showcase your market',
                              style: TextStyle(
                                color: HiPopColors.darkTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            PhotoUploadWidget(
                              onPhotosSelected: (photos) {
                                setState(() {
                                  _selectedPhotos.clear();
                                  _selectedPhotos.addAll(photos);
                                });
                              },
                              userId: (context.read<AuthBloc>().state as Authenticated).user.uid,
                              userType: 'market_organizer',
                              maxPhotos: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildInlineTextField(
                        fieldKey: 'website',
                        label: 'Website',
                        controller: _websiteController,
                        hintText: 'https://example.com',
                      ),
                      const SizedBox(height: 20),
                      _buildInlineTextField(
                        fieldKey: 'instagram',
                        label: 'Instagram',
                        controller: _instagramController,
                        hintText: '@yourmarket',
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom action bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HiPopColors.darkSurface,
                border: Border(
                  top: BorderSide(color: HiPopColors.darkBorder.withOpacity( 0.3)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity( 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getProgressText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _canCreateMarket && !_isLoading ? _createMarket : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HiPopColors.organizerAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: HiPopColors.darkBorder,
                          disabledForegroundColor: HiPopColors.darkTextTertiary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Create Market', // REMOVED LIMITS
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}