import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import 'package:atv_events/features/vendor/models/managed_vendor.dart';
import 'package:atv_events/features/vendor/models/unified_vendor.dart';
import 'package:atv_events/features/vendor/models/vendor_application.dart';
import '../../market/models/market.dart';
import '../../market/services/market_service.dart';
import '../../premium/services/subscription_service.dart';
import '../../shared/services/location/places_service.dart';
import '../../shared/services/analytics/real_time_analytics_service.dart';
import '../../shared/services/location/location_data_service.dart';
import '../../shared/services/utilities/photo_service.dart';
import '../../shared/services/user/user_profile_service.dart';
import '../../vendor/services/markets/vendor_application_service.dart';
import '../../vendor/services/core/managed_vendor_service.dart';
import '../../shared/widgets/common/simple_places_widget.dart';
import '../../shared/widgets/common/photo_upload_widget.dart';
import '../../../core/constants/ui_utils.dart';
import '../../../core/constants/constants.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'market_vendor_recruitment_form.dart';

class MarketFormDialog extends StatefulWidget {
  final Market? market;

  const MarketFormDialog({super.key, this.market});

  @override
  State<MarketFormDialog> createState() => _MarketFormDialogState();
}

class _MarketFormDialogState extends State<MarketFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _eventWebsiteController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _ticketUrlController = TextEditingController();

  // Address search using Google Places
  PlaceDetails? _selectedPlace;
  String _selectedAddress = '';

  // Event date and time
  DateTime? _selectedEventDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 14, minute: 0);
  
  // Vendor management
  List<VendorApplication> _approvedApplications = [];
  List<ManagedVendor> _existingManagedVendors = [];
  List<UnifiedVendor> _unifiedVendors = [];
  List<String> _selectedVendorIds = [];
  bool _isLoadingVendors = false;
  
  // Flyer upload
  List<File> _selectedFlyers = [];
  List<String> _existingFlyerUrls = [];
  bool _isFlyerUploading = false;
  
  bool _isLoading = false;
  bool get _isEditing => widget.market != null;
  
  // Vendor Recruitment Fields
  bool _isLookingForVendors = false;
  Map<String, dynamic> _recruitmentData = {};

  @override
  void initState() {
    super.initState();
    
    // If editing, populate fields
    if (_isEditing) {
      final market = widget.market!;
      _nameController.text = market.name;
      _selectedAddress = '${market.address}, ${market.city}, ${market.state}';
      _descriptionController.text = market.description ?? '';
      _selectedVendorIds = List.from(market.associatedVendorIds);
      _existingFlyerUrls = List.from(market.flyerUrls);
      _selectedEventDate = market.eventDate;
      _isLookingForVendors = market.isLookingForVendors;
      
      // Populate Instagram handle
      _instagramController.text = market.instagramHandle ?? '';
      _recruitmentData = {
        'isLookingForVendors': market.isLookingForVendors,
        'applicationUrl': market.applicationUrl,
        'applicationFee': market.applicationFee,
        'dailyBoothFee': market.dailyBoothFee,
        'vendorSpotsTotal': market.vendorSpotsTotal,
        'vendorSpotsAvailable': market.vendorSpotsAvailable,
        'applicationDeadline': market.applicationDeadline,
        'vendorRequirements': market.vendorRequirements,
      };
      
      // Parse existing times
      _parseTime(market.startTime, true);
      _parseTime(market.endTime, false);
      
      // Create a PlaceDetails object from existing market data
      _selectedPlace = PlaceDetails(
        placeId: 'existing_${market.id}',
        name: market.address,
        formattedAddress: '${market.address}, ${market.city}, ${market.state}',
        latitude: market.latitude,
        longitude: market.longitude,
      );
    }
    
    // Load vendor data
    _loadVendorData();
  }
  
  void _parseTime(String timeString, bool isStart) {
    // Parse time strings like "9:00 AM" or "2:00 PM"
    final regex = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false);
    final match = regex.firstMatch(timeString);
    
    if (match != null) {
      int hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3)!.toUpperCase();
      
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      
      final time = TimeOfDay(hour: hour, minute: minute);
      setState(() {
        if (isStart) {
          _startTime = time;
        } else {
          _endTime = time;
        }
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
  
  
  Future<void> _loadVendorData() async {
    setState(() => _isLoadingVendors = true);
    
    try {
      // Load approved vendor applications for the current market if editing
      if (_isEditing) {
        _approvedApplications = await VendorApplicationService.getApprovedApplicationsForMarket(widget.market!.id);
        _existingManagedVendors = await ManagedVendorService.getVendorsForMarketAsync(widget.market!.id);
        
        // Create unified, deduplicated list
        _unifiedVendors = _createUnifiedVendorList(_approvedApplications, _existingManagedVendors);
      }
    } finally {
      setState(() => _isLoadingVendors = false);
    }
  }

  List<UnifiedVendor> _createUnifiedVendorList(
    List<VendorApplication> applications,
    List<ManagedVendor> managedVendors,
  ) {
    final Map<String, UnifiedVendor> vendorMap = {};
    
    // Add managed vendors first (they're the "canonical" record)
    for (final vendor in managedVendors) {
      final vendorUserId = vendor.metadata['vendorUserId'] as String? ?? vendor.id;
      vendorMap[vendorUserId] = UnifiedVendor.fromManagedVendor(vendor);
    }
    
    // Add applications that don't already exist as managed vendors
    for (final application in applications) {
      if (!vendorMap.containsKey(application.vendorId)) {
        vendorMap[application.vendorId] = UnifiedVendor.fromApplication(application);
      }
    }
    
    return vendorMap.values.toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _eventWebsiteController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _ticketUrlController.dispose();
    super.dispose();
  }

  void _onFlyersSelected(List<File> flyers) {
    setState(() {
      _selectedFlyers = flyers;
    });
  }

  void _onExistingFlyersChanged(List<String> existingUrls) {
    setState(() {
      _existingFlyerUrls = existingUrls;
    });
  }

  Future<List<String>> _uploadFlyers() async {
    if (_selectedFlyers.isEmpty) return _existingFlyerUrls;
    
    setState(() {
      _isFlyerUploading = true;
    });
    
    try {
      final uploadedUrls = <String>[];
      
      // Get current user ID
      final authState = context.read<AuthBloc>().state;
      final userId = authState is Authenticated ? authState.userProfile?.userId ?? 'anonymous' : 'anonymous';
      
      for (final flyer in _selectedFlyers) {
        final url = await PhotoService.uploadPhoto(flyer, 'market_flyers', userId);
        uploadedUrls.add(url);
      }
      
      // Combine existing URLs (which may have been modified) with new uploaded URLs
      return [..._existingFlyerUrls, ...uploadedUrls];
    } catch (e) {
      throw Exception('Failed to upload flyers: $e');
    } finally {
      setState(() {
        _isFlyerUploading = false;
      });
    }
  }

  void _onPlaceSelected(PlaceDetails place) {
    setState(() {
      _selectedPlace = place;
      _selectedAddress = place.formattedAddress;
    });
  }

  void _onAddressCleared() {
    setState(() {
      _selectedPlace = null;
      _selectedAddress = '';
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlace == null) {
      UIUtils.showErrorSnackBar(context, 'Please select a location for the market');
      return;
    }
    if (_selectedEventDate == null) {
      UIUtils.showErrorSnackBar(context, 'Please select an event date');
      return;
    }

    // Check market creation limits for new markets only
    if (!_isEditing) {
      final authState = context.read<AuthBloc>().state;
      if (authState is Authenticated && authState.userProfile != null) {
        final userId = authState.userProfile!.userId;
        final canCreate = await SubscriptionService.canCreateMarket(userId);
        
        if (!canCreate) {
          // Track analytics for limit encounter
          RealTimeAnalyticsService.trackEvent(
            'market_creation_limit_encountered',
            {
              'user_type': 'market_organizer',
              'monthly_limit': 2,
              'is_premium': false,
              'source': 'market_form_dialog',
            },
            userId: userId,
          );
          
          if (mounted) {
            _showMarketLimitDialog();
          }
          return;
        }
      }
    }

    setState(() => _isLoading = true);

    try {
      // Upload flyers first if any
      final flyerUrls = await _uploadFlyers();
      
      if (_isEditing) {
        // Update existing market
        await _updateMarketWithSchedules(flyerUrls);
      } else {
        // Create new market
        await _createMarketWithSchedules(flyerUrls);
      }
    } catch (e) {
      if (mounted) {
        UIUtils.showErrorSnackBar(context, 'Error ${_isEditing ? 'updating' : 'creating'} market: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _createMarketWithSchedules(List<String> flyerUrls) async {
    // Parse address components from selected place
    final addressComponents = _parseAddressComponents(_selectedPlace!.formattedAddress);
    
    // Create optimized location data for new markets
    final locationData = LocationDataService.createLocationData(
      locationString: _selectedPlace!.formattedAddress,
      latitude: _selectedPlace!.latitude,
      longitude: _selectedPlace!.longitude,
      placeId: _selectedPlace!.placeId,
      locationName: _selectedPlace!.name,
    );
    
    // Get auth state and fetch user profile to auto-populate Instagram handle
    final authState = context.read<AuthBloc>().state;
    final userId = authState is Authenticated ? authState.userProfile?.userId : null;
    String? instagramHandle;
    
    if (userId != null) {
      try {
        final userProfileService = UserProfileService();
        final userProfile = await userProfileService.getUserProfile(userId);
        instagramHandle = userProfile?.instagramHandle;
        if (instagramHandle?.isNotEmpty ?? false) {
        }
      } catch (e) {
        // Continue without Instagram handle if there's an error
      }
    }
    
    // Create the market with simple date/time
    final market = Market(
      id: '',
      name: _nameController.text.trim(),
      address: addressComponents['address'] ?? _selectedPlace!.formattedAddress,
      city: addressComponents['city'] ?? '',
      state: addressComponents['state'] ?? '',
      latitude: _selectedPlace!.latitude,
      longitude: _selectedPlace!.longitude,
      eventDate: _selectedEventDate!,
      startTime: _formatTimeOfDay(_startTime),
      endTime: _formatTimeOfDay(_endTime),
      description: _descriptionController.text.trim().isNotEmpty 
          ? _descriptionController.text.trim() 
          : null,
      flyerUrls: flyerUrls,
      associatedVendorIds: _selectedVendorIds,
      createdAt: DateTime.now(),
      instagramHandle: _instagramController.text.trim().isNotEmpty 
          ? _instagramController.text.replaceAll('@', '').trim() 
          : null,
      // Vendor Recruitment Fields
      isLookingForVendors: _recruitmentData['isLookingForVendors'] ?? false,
      applicationUrl: _recruitmentData['applicationUrl'],
      applicationFee: _recruitmentData['applicationFee'],
      dailyBoothFee: _recruitmentData['dailyBoothFee'],
      vendorSpotsTotal: _recruitmentData['vendorSpotsTotal'],
      vendorSpotsAvailable: _recruitmentData['vendorSpotsAvailable'],
      applicationDeadline: _recruitmentData['applicationDeadline'],
      vendorRequirements: _recruitmentData['vendorRequirements'],
      // Optimized Location Data
      locationData: locationData,
    );
    
    final createdMarketId = await MarketService.createMarket(market);
    
    // Increment monthly market count for free tier tracking
    if (userId != null) {
      await SubscriptionService.incrementMarketCount(userId);
    }
    
    final updatedMarket = market.copyWith(id: createdMarketId);
    
    if (mounted) {
      Navigator.pop(context, updatedMarket);
    }
  }
  
  Future<void> _updateMarketWithSchedules(List<String> flyerUrls) async {
    final market = widget.market!;
    
    // Parse address components from selected place
    final addressComponents = _parseAddressComponents(_selectedPlace!.formattedAddress);
    
    // Create optimized location data for updated market
    final locationData = LocationDataService.createLocationData(
      locationString: _selectedPlace!.formattedAddress,
      latitude: _selectedPlace!.latitude,
      longitude: _selectedPlace!.longitude,
      placeId: _selectedPlace!.placeId,
      locationName: _selectedPlace!.name,
    );
    
    // Get auth state and fetch user profile to potentially update Instagram handle
    final authState = context.read<AuthBloc>().state;
    final userId = authState is Authenticated ? authState.userProfile?.userId : null;
    String? instagramHandle = market.instagramHandle; // Keep existing handle by default
    
    // Only update Instagram handle if the market doesn't have one or if user's profile has changed
    if ((market.instagramHandle == null || market.instagramHandle!.isEmpty) && userId != null) {
      try {
        final userProfileService = UserProfileService();
        final userProfile = await userProfileService.getUserProfile(userId);
        if (userProfile?.instagramHandle != null && userProfile!.instagramHandle!.isNotEmpty) {
          instagramHandle = userProfile.instagramHandle;
        }
      } catch (e) {
        // Continue without Instagram handle if there's an error
      }
    }
    
    // Update market with simple date/time
    final updatedMarket = market.copyWith(
      name: _nameController.text.trim(),
      address: addressComponents['address'] ?? _selectedPlace!.formattedAddress,
      city: addressComponents['city'] ?? market.city,
      state: addressComponents['state'] ?? market.state,
      latitude: _selectedPlace!.latitude,
      longitude: _selectedPlace!.longitude,
      eventDate: _selectedEventDate ?? market.eventDate,
      startTime: _formatTimeOfDay(_startTime),
      endTime: _formatTimeOfDay(_endTime),
      description: _descriptionController.text.trim().isNotEmpty 
          ? _descriptionController.text.trim() 
          : null,
      flyerUrls: flyerUrls,
      associatedVendorIds: _selectedVendorIds,
      instagramHandle: _instagramController.text.trim().isNotEmpty 
          ? _instagramController.text.replaceAll('@', '').trim() 
          : market.instagramHandle,
      // Vendor Recruitment Fields
      isLookingForVendors: _recruitmentData['isLookingForVendors'] ?? false,
      applicationUrl: _recruitmentData['applicationUrl'],
      applicationFee: _recruitmentData['applicationFee'],
      dailyBoothFee: _recruitmentData['dailyBoothFee'],
      vendorSpotsTotal: _recruitmentData['vendorSpotsTotal'],
      vendorSpotsAvailable: _recruitmentData['vendorSpotsAvailable'],
      applicationDeadline: _recruitmentData['applicationDeadline'],
      vendorRequirements: _recruitmentData['vendorRequirements'],
      // Optimized Location Data
      locationData: locationData,
    );
    
    await MarketService.updateMarket(market.id, updatedMarket.toFirestore());
    
    if (mounted) {
      Navigator.pop(context, updatedMarket);
    }
  }
  

  Widget _buildEventDateTimeForm() {
    return Card(
      color: HiPopColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: HiPopColors.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, color: HiPopColors.accentMauve),
                const SizedBox(width: 8),
                Text(
                  'Event Date & Time',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Event Date Picker
            Text(
              'Event Date',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: HiPopColors.darkSurfaceVariant,
                border: Border.all(color: HiPopColors.darkBorder),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                title: Text(
                  _selectedEventDate != null 
                      ? '${_selectedEventDate!.month}/${_selectedEventDate!.day}/${_selectedEventDate!.year}'
                      : 'Select event date',
                  style: TextStyle(color: HiPopColors.darkTextPrimary),
                ),
                leading: Icon(Icons.calendar_today, color: HiPopColors.darkTextTertiary),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedEventDate ?? DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: HiPopColors.primaryDeepSage,
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
                            todayForegroundColor: WidgetStateProperty.all(HiPopColors.primaryDeepSage),
                            dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return HiPopColors.primaryDeepSage;
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
                                return HiPopColors.primaryDeepSage;
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
                              foregroundColor: HiPopColors.primaryDeepSage,
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
                      _selectedEventDate = date;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 16),

            // Time selection
            Text(
              'Operating Hours',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: Text('Start Time', style: TextStyle(color: HiPopColors.darkTextPrimary)),
                    subtitle: Text(_formatTimeOfDay(_startTime), style: TextStyle(color: HiPopColors.darkTextSecondary)),
                    leading: Icon(Icons.access_time, color: HiPopColors.darkTextTertiary),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (time != null) {
                        setState(() {
                          _startTime = time;
                        });
                      }
                    },
                    dense: true,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: Text('End Time', style: TextStyle(color: HiPopColors.darkTextPrimary)),
                    subtitle: Text(_formatTimeOfDay(_endTime), style: TextStyle(color: HiPopColors.darkTextSecondary)),
                    leading: Icon(Icons.access_time_filled, color: HiPopColors.darkTextTertiary),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (time != null) {
                        setState(() {
                          _endTime = time;
                        });
                      }
                    },
                    dense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Event Preview
            if (_selectedEventDate != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HiPopColors.darkSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: HiPopColors.successGreen.withOpacity( 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: HiPopColors.successGreen),
                        const SizedBox(width: 8),
                        Text(
                          'Event Preview',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: HiPopColors.darkTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Date: ${_selectedEventDate!.month}/${_selectedEventDate!.day}/${_selectedEventDate!.year}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Time: ${_formatTimeOfDay(_startTime)} - ${_formatTimeOfDay(_endTime)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Map<String, String> _parseAddressComponents(String formattedAddress) {
    // Simple parsing of formatted address
    // Expected format: "Street Address, City, State ZIP, Country"
    final parts = formattedAddress.split(', ');
    
    if (parts.length >= 3) {
      final address = parts[0];
      final city = parts[1];
      final stateZip = parts[2].split(' ');
      final state = stateZip.isNotEmpty ? stateZip[0] : '';
      
      return {
        'address': address,
        'city': city,
        'state': state,
      };
    }
    
    // Fallback: use the full formatted address as address
    return {
      'address': formattedAddress,
      'city': '',
      'state': '',
    };
  }

  Widget _buildFlyerUploadSection() {
    return Card(
      color: HiPopColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: HiPopColors.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, color: HiPopColors.accentMauve),
                const SizedBox(width: 8),
                Text(
                  'Market Flyer (Optional)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Upload a flyer to showcase your market event',
              style: TextStyle(
                fontSize: 14,
                color: HiPopColors.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            PhotoUploadWidget(
              onPhotosSelected: _onFlyersSelected,
              onExistingPhotosChanged: _onExistingFlyersChanged,
              initialImagePaths: _existingFlyerUrls.isNotEmpty ? _existingFlyerUrls : null,
              userId: FirebaseAuth.instance.currentUser?.uid,
              userType: 'market_organizer',
            ),
          ],
        ),
      ),
    );
  }

  void _showMarketLimitDialog() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated || authState.userProfile == null) return;

    final currentMarketCount = authState.userProfile!.managedMarketIds.length;
    final usageSummary = await SubscriptionService.getMarketUsageSummary(
      authState.userProfile!.userId, 
      currentMarketCount,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkBackground,
        title: Row(
          children: [
            Icon(Icons.lock, color: HiPopColors.warningAmber),
            SizedBox(width: 8),
            Text('Market Creation Limit Reached', style: TextStyle(color: HiPopColors.darkTextPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have reached your free tier limit of ${usageSummary['markets_limit']} markets.',
              style: TextStyle(fontSize: 16, color: HiPopColors.darkTextPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HiPopColors.primaryDeepSage.withOpacity( 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HiPopColors.primaryDeepSage.withOpacity( 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Usage: ${usageSummary['markets_used']} of ${usageSummary['markets_limit']} markets',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.primaryDeepSageDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Upgrade to Market Organizer Pro for unlimited markets!',
                    style: TextStyle(color: HiPopColors.primaryDeepSage),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pro Features:',
              style: TextStyle(fontWeight: FontWeight.bold, color: HiPopColors.darkTextPrimary),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• Unlimited markets', style: TextStyle(color: HiPopColors.darkTextSecondary)),
                Text('• Advanced analytics', style: TextStyle(color: HiPopColors.darkTextSecondary)),
                Text('• Vendor recruitment tools', style: TextStyle(color: HiPopColors.darkTextSecondary)),
                Text('• Priority support', style: TextStyle(color: HiPopColors.darkTextSecondary)),
                Text('• Revenue optimization', style: TextStyle(color: HiPopColors.darkTextSecondary)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: HiPopColors.darkTextSecondary,
            ),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to upgrade screen
              // This would typically navigate to subscription management
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.primaryDeepSage,
              foregroundColor: HiPopColors.darkTextPrimary,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }


  Widget _buildVendorManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Associate Vendors',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: HiPopColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select vendors to associate with this market',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: HiPopColors.darkTextTertiary,
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingVendors)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          // Unified vendor list
          if (_unifiedVendors.isNotEmpty) ...[
            Text(
              'Associated Vendors',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: HiPopColors.primaryDeepSageDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...(_unifiedVendors.map((vendor) => _buildUnifiedVendorTile(vendor))),
            const SizedBox(height: 16),
          ],
        ],
      ],
    );
  }

  Widget _buildVendorApplicationTile(VendorApplication application) {
    final isSelected = _selectedVendorIds.contains(application.vendorId);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (bool? value) {
          setState(() {
            if (value == true) {
              _selectedVendorIds.add(application.vendorId);
            } else {
              _selectedVendorIds.remove(application.vendorId);
            }
          });
        },
        title: Text(application.vendorBusinessName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact: ${application.vendorDisplayName}'),
            if (application.vendorCategories.isNotEmpty)
              Text('Categories: ${application.vendorCategories.join(', ')}'),
          ],
        ),
        secondary: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: HiPopColors.darkSurfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HiPopColors.successGreen.withOpacity( 0.3)),
          ),
          child: Text(
            'APPROVED',
            style: TextStyle(
              color: HiPopColors.successGreenDark,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManagedVendorTile(ManagedVendor vendor) {
    final isSelected = _selectedVendorIds.contains(vendor.id);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (bool? value) {
          setState(() {
            if (value == true) {
              _selectedVendorIds.add(vendor.id);
            } else {
              _selectedVendorIds.remove(vendor.id);
            }
          });
        },
        title: Text(vendor.businessName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact: ${vendor.contactName}'),
            if (vendor.categories.isNotEmpty)
              Text('Categories: ${vendor.categoriesDisplay}'),
          ],
        ),
        secondary: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: HiPopColors.darkSurfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HiPopColors.primaryDeepSage.withOpacity( 0.3)),
          ),
          child: Text(
            'MANAGED',
            style: TextStyle(
              color: HiPopColors.primaryDeepSageDark,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedVendorTile(UnifiedVendor vendor) {
    final isSelected = _selectedVendorIds.contains(vendor.id);
    
    return Card(
      elevation: isSelected ? 3 : 1,
      color: isSelected ? HiPopColors.darkSurfaceVariant : HiPopColors.darkSurface,
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        title: Text(vendor.businessName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vendor.email),
            const SizedBox(height: 4),
            // Show source with appropriate icon/color
            Row(
              children: [
                _getSourceIcon(vendor.source),
                const SizedBox(width: 4),
                Text(
                  _getSourceLabel(vendor.source),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getSourceColor(vendor.source),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        value: isSelected,
        onChanged: (bool? value) {
          setState(() {
            if (value == true) {
              _selectedVendorIds.add(vendor.id);
            } else {
              _selectedVendorIds.remove(vendor.id);
            }
          });
        },
      ),
    );
  }

  Widget _getSourceIcon(VendorSource source) {
    switch (source) {
      case VendorSource.permissionRequest:
        return Icon(Icons.verified_user, size: 16, color: HiPopColors.successGreen);
      case VendorSource.eventApplication:
        return Icon(Icons.event, size: 16, color: HiPopColors.warningAmber);
      case VendorSource.manuallyCreated:
        return Icon(Icons.person_add, size: 16, color: HiPopColors.primaryDeepSage);
      case VendorSource.marketInvitation:
        return Icon(Icons.mail, size: 16, color: HiPopColors.accentMauve);
    }
  }

  String _getSourceLabel(VendorSource source) {
    switch (source) {
      case VendorSource.permissionRequest:
        return 'Permission-Based';
      case VendorSource.eventApplication:
        return 'Event Application';
      case VendorSource.manuallyCreated:
        return 'Manually Added';
      case VendorSource.marketInvitation:
        return 'Market Invitation';
    }
  }

  Color _getSourceColor(VendorSource source) {
    switch (source) {
      case VendorSource.permissionRequest:
        return HiPopColors.successGreen;
      case VendorSource.eventApplication:
        return HiPopColors.warningAmber;
      case VendorSource.manuallyCreated:
        return HiPopColors.primaryDeepSage;
      case VendorSource.marketInvitation:
        return HiPopColors.accentMauve;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: HiPopColors.darkBackground,
      child: Container(
        width: MediaQuery.of(context).size.width * AppConstants.dialogWidthRatio,
        height: MediaQuery.of(context).size.height * AppConstants.dialogHeightRatio,
        padding: const EdgeInsets.all(AppConstants.dialogPadding),
        decoration: BoxDecoration(
          color: HiPopColors.darkBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.storefront,
                  color: HiPopColors.primaryDeepSage,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditing ? 'Edit Market' : 'Create New Market',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HiPopColors.darkTextPrimary),
                      ),
                      // Add trust-based system message for new markets
                      if (!_isEditing)
                        Text(
                          'Your market will be immediately visible to all vendors and shoppers!',
                          style: TextStyle(
                            fontSize: 12,
                            color: HiPopColors.successGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      // Show remaining markets for free tier users when creating
                      if (!_isEditing)
                        FutureBuilder<int>(
                          future: () async {
                            final authState = context.read<AuthBloc>().state;
                            if (authState is Authenticated && authState.userProfile != null) {
                              return SubscriptionService.getRemainingMonthlyMarkets(authState.userProfile!.userId);
                            }
                            return -1;
                          }(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data! >= 0) {
                              final remaining = snapshot.data!;
                              return Text(
                                'You have $remaining of 2 markets remaining this month',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: remaining > 0 ? HiPopColors.darkTextSecondary : HiPopColors.warningAmber,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: HiPopColors.darkTextSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trust-Based System Info Card (only for new markets)
                      if (!_isEditing) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: HiPopColors.successGreen.withOpacity( 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: HiPopColors.successGreen.withOpacity( 0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.verified_user,
                                color: HiPopColors.successGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Trust-Based System Active',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: HiPopColors.successGreen,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Your market will be active immediately. All vendor posts are auto-approved to foster trust and community growth.',
                                      style: TextStyle(
                                        color: HiPopColors.darkTextSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: HiPopColors.darkTextPrimary),
                        decoration: InputDecoration(
                          labelText: 'Market Name *',
                          labelStyle: TextStyle(color: HiPopColors.darkTextSecondary),
                          prefixIcon: Icon(Icons.storefront, color: HiPopColors.darkTextSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: HiPopColors.darkBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: HiPopColors.darkBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: HiPopColors.primaryDeepSage),
                          ),
                          filled: true,
                          fillColor: HiPopColors.darkSurface,
                          helperText: 'e.g., "Downtown Farmers Market"',
                          helperStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the market name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Market Location *',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: HiPopColors.darkTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SimplePlacesWidget(
                            initialLocation: _selectedAddress,
                            onLocationSelected: (PlaceDetails? place) {
                              if (place != null) {
                                _onPlaceSelected(place);
                              } else {
                                _onAddressCleared();
                              }
                            },
                          ),
                          if (_selectedPlace != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: HiPopColors.darkSurfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: HiPopColors.successGreen.withOpacity( 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: HiPopColors.successGreenDark, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Location selected: ${_selectedPlace!.formattedAddress}',
                                      style: TextStyle(
                                        color: HiPopColors.successGreenDark,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        style: TextStyle(color: HiPopColors.darkTextPrimary),
                        decoration: InputDecoration(
                          labelText: 'Description (Optional)',
                          labelStyle: TextStyle(color: HiPopColors.darkTextSecondary),
                          prefixIcon: Icon(Icons.description, color: HiPopColors.darkTextSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: HiPopColors.darkBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: HiPopColors.darkBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: HiPopColors.primaryDeepSage),
                          ),
                          filled: true,
                          fillColor: HiPopColors.darkSurface,
                          helperText: 'Brief description of your market',
                          helperStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 16),
                      // Instagram Handle
                      TextFormField(
                        controller: _instagramController,
                        style: TextStyle(color: HiPopColors.darkTextPrimary),
                        decoration: InputDecoration(
                          labelText: 'Instagram Handle (Optional)',
                          labelStyle: TextStyle(color: HiPopColors.darkTextSecondary),
                          prefixIcon: Container(
                            padding: const EdgeInsets.all(12),
                            child: Image.asset(
                              'assets/icons/instagram.png',
                              width: 24,
                              height: 24,
                              color: HiPopColors.darkTextSecondary,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.camera_alt, color: HiPopColors.darkTextSecondary, size: 24);
                              },
                            ),
                          ),
                          prefixText: '@',
                          prefixStyle: TextStyle(color: HiPopColors.darkTextSecondary),
                          hintText: 'yourmarket',
                          hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: HiPopColors.darkBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: HiPopColors.darkBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: HiPopColors.primaryDeepSage),
                          ),
                          filled: true,
                          fillColor: HiPopColors.darkSurface,
                          helperText: 'Your market\'s Instagram username',
                          helperStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            // Remove @ if user included it
                            value = value.replaceAll('@', '');
                            if (value.contains(' ')) {
                              return 'Instagram handle cannot contain spaces';
                            }
                            if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(value)) {
                              return 'Invalid Instagram handle format';
                            }
                          }
                          return null;
                        },
                        onChanged: (value) {
                          // Remove @ symbol if user types it
                          if (value.startsWith('@')) {
                            _instagramController.text = value.substring(1);
                            _instagramController.selection = TextSelection.fromPosition(
                              TextPosition(offset: _instagramController.text.length),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      // Flyer Upload Section
                      _buildFlyerUploadSection(),
                      const SizedBox(height: 24),
                      // Event Date and Time Form
                      _buildEventDateTimeForm(),
                      const SizedBox(height: 24),
                      // Vendor Recruitment Section
                      MarketVendorRecruitmentForm(
                        market: widget.market,
                        isLookingForVendors: _isLookingForVendors,
                        onRecruitmentDataChanged: (data) {
                          setState(() {
                            _recruitmentData = data;
                            _isLookingForVendors = data['isLookingForVendors'] ?? false;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      // Vendor Management Section
                      _buildVendorManagementSection(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: HiPopColors.darkBorder),
                      foregroundColor: HiPopColors.darkTextSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isFlyerUploading) ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HiPopColors.primaryDeepSage,
                      foregroundColor: HiPopColors.darkTextPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: (_isLoading || _isFlyerUploading)
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: HiPopColors.darkTextPrimary,
                            ),
                          )
                        : Text(_isFlyerUploading ? 'Uploading...' : (_isEditing ? 'Update Market' : 'Create Market')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}