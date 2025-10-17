import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/market/widgets/market_vendor_recruitment_form.dart';
import 'package:atv_events/features/shared/widgets/common/loading_widget.dart';
import 'package:atv_events/features/shared/services/location/places_service.dart';
import 'package:atv_events/features/shared/widgets/common/simple_places_widget.dart';
import 'package:atv_events/features/shared/services/user/user_profile_service.dart';

/// Screen for creating vendor recruitment posts from the premium dashboard
/// Uses the same form as traditional market creation but without creating a public market
class CreateVendorRecruitmentPostScreen extends StatefulWidget {
  const CreateVendorRecruitmentPostScreen({super.key});

  @override
  State<CreateVendorRecruitmentPostScreen> createState() => _CreateVendorRecruitmentPostScreenState();
}

class _CreateVendorRecruitmentPostScreenState extends State<CreateVendorRecruitmentPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // Address search using Google Places
  PlaceDetails? _selectedPlace;
  String _selectedAddress = '';
  
  // Event date and time
  DateTime? _selectedEventDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 14, minute: 0);
  
  // Vendor Recruitment Fields
  Map<String, dynamic> _recruitmentData = {
    'isLookingForVendors': true, // Always true for this flow
  };
  
  bool _isLoading = false;
  bool _hasCheckedPremium = false;
  
  @override
  void initState() {
    super.initState();
    _checkPremiumAccess();
  }
  
  Future<void> _checkPremiumAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }

    // Fetch organizer profile to auto-populate fields
    try {
      final userProfile = await UserProfileService().getUserProfile(user.uid);
      if (userProfile != null && mounted) {
        // Auto-populate organizer name in the event name field
        final organizerName = userProfile.organizationName ??
                              userProfile.displayName ??
                              'My Market';
        _nameController.text = '$organizerName Event';

        debugPrint('✅ Auto-populated organizer name: $organizerName');
      }
    } catch (e) {
      debugPrint('Error fetching organizer profile: $e');
    }

    // Vendor recruitment posts are now free for all organizers
    setState(() {
      _hasCheckedPremium = true;
    });
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _createRecruitmentPost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selectedPlace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a location'),
          backgroundColor: HiPopColors.errorPlum,
        ),
      );
      return;
    }
    
    if (_selectedEventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select an event date'),
          backgroundColor: HiPopColors.errorPlum,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');
      
      // Create a recruitment post that appears in vendor discovery
      // but is NOT a full public market
      final recruitmentPost = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'organizerId': user.uid,
        'organizerEmail': user.email,
        
        // Location data
        'address': _selectedPlace!.formattedAddress ?? _selectedPlace!.name,
        'city': _extractCity(_selectedPlace!.formattedAddress ?? ''),
        'state': _extractState(_selectedPlace!.formattedAddress ?? ''),
        'latitude': _selectedPlace!.latitude,
        'longitude': _selectedPlace!.longitude,
        
        // Event timing
        'eventDate': Timestamp.fromDate(_selectedEventDate!),
        'startTime': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        'endTime': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        
        // Recruitment data
        'isLookingForVendors': true,
        'isRecruitmentOnly': true, // Flag to indicate this is not a public market
        'applicationUrl': _recruitmentData['applicationUrl'],
        'applicationFee': _recruitmentData['applicationFee'],
        'dailyBoothFee': _recruitmentData['dailyBoothFee'],
        'vendorSpotsTotal': _recruitmentData['vendorSpotsTotal'],
        'vendorSpotsAvailable': _recruitmentData['vendorSpotsAvailable'] ?? _recruitmentData['vendorSpotsTotal'],
        'applicationDeadline': _recruitmentData['applicationDeadline'] != null 
          ? Timestamp.fromDate(_recruitmentData['applicationDeadline'])
          : null,
        'vendorRequirements': _recruitmentData['vendorRequirements'],
        'targetCategories': _recruitmentData['targetCategories'],

        // Metadata
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'associatedVendorIds': [],
        
        // Premium tracking
        'createdFromPremiumDashboard': true,
      };
      
      // Save to markets collection (will appear in vendor discovery)
      await FirebaseFirestore.instance
          .collection('markets')
          .add(recruitmentPost);
      
      // Track premium usage (feature usage tracking could be added here)
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vendor recruitment post created successfully!'),
          backgroundColor: HiPopColors.successGreen,
        ),
      );
      
      // Navigate back to vendor discovery
      context.go('/organizer/vendor-discovery');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating recruitment post: $e'),
          backgroundColor: HiPopColors.errorPlum,
        ),
      );
    }
  }
  
  String _extractCity(String address) {
    final parts = address.split(',');
    if (parts.length >= 2) {
      return parts[parts.length - 2].trim();
    }
    return '';
  }
  
  String _extractState(String address) {
    final parts = address.split(',');
    if (parts.isNotEmpty) {
      final lastPart = parts.last.trim();
      final stateParts = lastPart.split(' ');
      if (stateParts.length >= 2) {
        return stateParts[0];
      }
    }
    return '';
  }
  
  Future<void> _selectEventDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedEventDate ?? DateTime.now().add(const Duration(days: 7)),
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
              secondary: HiPopColors.accentMauve,
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
    
    if (picked != null && picked != _selectedEventDate) {
      setState(() {
        _selectedEventDate = picked;
      });
    }
  }
  
  Future<void> _selectTime(bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
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
              secondary: HiPopColors.accentMauve,
              onSecondary: HiPopColors.darkTextPrimary,
              outline: HiPopColors.darkBorder,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: HiPopColors.darkSurface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: HiPopColors.darkSurface,
              hourMinuteColor: HiPopColors.darkSurfaceVariant,
              hourMinuteTextColor: HiPopColors.darkTextPrimary,
              dayPeriodTextColor: HiPopColors.darkTextPrimary,
              dayPeriodColor: HiPopColors.darkSurfaceVariant,
              dialBackgroundColor: HiPopColors.darkSurfaceVariant,
              dialHandColor: HiPopColors.organizerAccent,
              dialTextColor: HiPopColors.darkTextPrimary,
              entryModeIconColor: HiPopColors.darkTextSecondary,
              helpTextStyle: TextStyle(color: HiPopColors.darkTextSecondary),
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
    
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_hasCheckedPremium) {
      return const Scaffold(
        body: Center(
          child: LoadingWidget(message: 'Checking premium access...'),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text('Create Vendor Recruitment Post'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                HiPopColors.organizerAccent,
                HiPopColors.primaryDeepSage,
              ],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: HiPopColors.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: HiPopColors.premiumGold.withOpacity( 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: HiPopColors.premiumGold,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This post will appear in vendor discovery feeds to help you find qualified vendors',
                        style: TextStyle(
                          color: HiPopColors.darkTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Market Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Market/Event Name',
                  hintText: 'e.g., Summer Farmers Market',
                  prefixIcon: Icon(Icons.storefront, color: HiPopColors.organizerAccent),
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a market name';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe your market and what vendors you\'re looking for',
                  prefixIcon: Icon(Icons.description, color: HiPopColors.organizerAccent),
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Location Selection
              SimplePlacesWidget(
                onLocationSelected: (place) {
                  if (place != null) {
                    setState(() {
                      _selectedPlace = place;
                      _selectedAddress = place.formattedAddress ?? place.name;
                    });
                  }
                },
              ),
              
              const SizedBox(height: 16),
              
              // Event Date
              InkWell(
                onTap: _selectEventDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HiPopColors.darkBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: HiPopColors.organizerAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedEventDate != null
                              ? 'Event Date: ${_selectedEventDate!.month}/${_selectedEventDate!.day}/${_selectedEventDate!.year}'
                              : 'Select Event Date',
                          style: TextStyle(
                            color: _selectedEventDate != null 
                              ? HiPopColors.darkTextPrimary 
                              : HiPopColors.darkTextTertiary,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: HiPopColors.darkTextTertiary),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Time Selection
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(true),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: HiPopColors.darkSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: HiPopColors.darkBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, color: HiPopColors.organizerAccent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Start: ${_startTime.format(context)}',
                                style: TextStyle(color: HiPopColors.darkTextPrimary, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(false),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: HiPopColors.darkSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: HiPopColors.darkBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, color: HiPopColors.organizerAccent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'End: ${_endTime.format(context)}',
                                style: TextStyle(color: HiPopColors.darkTextPrimary, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Vendor Recruitment Form (always enabled for premium users)
              MarketVendorRecruitmentForm(
                isLookingForVendors: true,
                onRecruitmentDataChanged: (data) {
                  setState(() {
                    _recruitmentData = data;
                  });
                },
              ),
              
              const SizedBox(height: 32),
              
              // Create Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createRecruitmentPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HiPopColors.organizerAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: HiPopColors.darkTextTertiary,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Create Recruitment Post',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}