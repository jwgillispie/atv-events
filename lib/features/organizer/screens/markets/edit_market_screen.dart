import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/market/models/market.dart';
import 'package:atv_events/features/market/services/market_service.dart';
import 'package:atv_events/features/premium/services/subscription_service.dart';
import 'package:atv_events/features/shared/services/location/places_service.dart';
import 'package:atv_events/features/shared/services/location/location_data_service.dart';
import 'package:atv_events/features/shared/services/utilities/photo_service.dart';
import 'package:atv_events/features/shared/widgets/common/unified_location_search.dart';
import 'package:atv_events/features/shared/widgets/common/photo_upload_widget.dart';
import 'package:atv_events/features/vendor/models/managed_vendor.dart';
import 'package:atv_events/features/vendor/models/unified_vendor.dart';
import 'package:atv_events/features/vendor/models/vendor_application.dart';
import 'package:atv_events/features/vendor/services/markets/vendor_application_service.dart';
import 'package:atv_events/features/vendor/services/core/managed_vendor_service.dart';
import 'package:atv_events/features/organizer/models/organizer_vendor_post.dart';
import 'package:atv_events/features/organizer/services/vendor_management/vendor_post_service.dart';

class EditMarketScreen extends StatefulWidget {
  final String marketId;
  
  const EditMarketScreen({
    super.key, 
    required this.marketId,
  });

  @override
  State<EditMarketScreen> createState() => _EditMarketScreenState();
}

class _EditMarketScreenState extends State<EditMarketScreen> {
  // Form data
  final Map<String, dynamic> _formData = {};
  final Map<String, bool> _completedFields = {};
  Market? _originalMarket;
  
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
  final TextEditingController _applicationFeeController = TextEditingController();
  final TextEditingController _dailyBoothFeeController = TextEditingController();
  final TextEditingController _vendorSpotsController = TextEditingController();
  final TextEditingController _vendorRequirementsController = TextEditingController();
  
  // Vendor management
  List<VendorApplication> _approvedApplications = [];
  List<ManagedVendor> _existingManagedVendors = [];
  List<UnifiedVendor> _unifiedVendors = [];
  List<String> _selectedVendorIds = [];
  bool _isLoadingVendors = false;
  
  // Flyer management
  List<File> _selectedFlyers = [];
  List<String> _existingFlyerUrls = [];
  
  // UI State
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isFlyerUploading = false;
  bool _isPremium = false;
  bool _hasChanges = false;
  
  PlaceDetails? _selectedPlace;

  @override
  void initState() {
    super.initState();
    _loadMarket();
    _checkPremiumStatus();
    _setupControllerListeners();
  }
  
  void _setupControllerListeners() {
    _nameController.addListener(_onFormChanged);
    _descriptionController.addListener(_onFormChanged);
    _instagramController.addListener(_onFormChanged);
    _websiteController.addListener(_onFormChanged);
    _applicationUrlController.addListener(_onFormChanged);
    _applicationFeeController.addListener(_onFormChanged);
    _dailyBoothFeeController.addListener(_onFormChanged);
    _vendorSpotsController.addListener(_onFormChanged);
    _vendorRequirementsController.addListener(_onFormChanged);
  }
  
  void _onFormChanged() {
    setState(() {
      _hasChanges = true;
      _updateFormData();
      _updateCompletedFields();
    });
  }
  
  void _updateFormData() {
    _formData['name'] = _nameController.text;
    _formData['description'] = _descriptionController.text;
    _formData['instagram'] = _instagramController.text;
    _formData['website'] = _websiteController.text;
    _formData['applicationUrl'] = _applicationUrlController.text;
    _formData['applicationFee'] = double.tryParse(_applicationFeeController.text) ?? 0;
    _formData['dailyBoothFee'] = double.tryParse(_dailyBoothFeeController.text) ?? 0;
    _formData['vendorSpotsTotal'] = int.tryParse(_vendorSpotsController.text);
    _formData['vendorRequirements'] = _vendorRequirementsController.text;
  }
  
  void _updateCompletedFields() {
    _completedFields['name'] = _nameController.text.trim().isNotEmpty;
    _completedFields['location'] = _selectedPlace != null;
    _completedFields['marketDate'] = _formData['marketDate'] != null;
    _completedFields['operatingHours'] = _formData['startTime'] != null && _formData['endTime'] != null;
  }
  
  Future<void> _loadMarket() async {
    setState(() => _isLoading = true);
    
    try {
      final market = await MarketService.getMarket(widget.marketId);
      if (market == null) {
        throw Exception('Market not found');
      }
      
      _originalMarket = market;
      
      // Populate controllers
      _nameController.text = market.name;
      _descriptionController.text = market.description ?? '';
      _instagramController.text = market.instagramHandle ?? '';
      _applicationUrlController.text = market.applicationUrl ?? '';
      _applicationFeeController.text = market.applicationFee?.toString() ?? '';
      _dailyBoothFeeController.text = market.dailyBoothFee?.toString() ?? '';
      _vendorSpotsController.text = market.vendorSpotsTotal?.toString() ?? '';
      if (market.vendorRequirements?.isNotEmpty ?? false) {
        _vendorRequirementsController.text = market.vendorRequirements ?? '';
      }
      
      // Set form data
      _formData['marketDate'] = market.eventDate;
      _formData['startTime'] = _parseTimeOfDay(market.startTime, true);
      _formData['endTime'] = _parseTimeOfDay(market.endTime, false);
      _formData['lookingForVendors'] = market.isLookingForVendors;
      _formData['applicationDeadline'] = market.applicationDeadline;
      
      // Set location
      _selectedPlace = PlaceDetails(
        placeId: 'existing_${market.id}',
        name: market.address,
        formattedAddress: '${market.address}, ${market.city}, ${market.state}',
        latitude: market.latitude,
        longitude: market.longitude,
      );
      
      // Set existing data
      _selectedVendorIds = List.from(market.associatedVendorIds);
      _existingFlyerUrls = List.from(market.flyerUrls);
      
      // Update completed fields
      _updateCompletedFields();
      
      // Load vendor data
      await _loadVendorData();
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading market: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
        context.pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _loadVendorData() async {
    setState(() => _isLoadingVendors = true);
    
    try {
      _approvedApplications = await VendorApplicationService.getApprovedApplicationsForMarket(widget.marketId);
      _existingManagedVendors = await ManagedVendorService.getVendorsForMarketAsync(widget.marketId);
      
      // Create unified list
      _unifiedVendors = _createUnifiedVendorList(_approvedApplications, _existingManagedVendors);
    } finally {
      setState(() => _isLoadingVendors = false);
    }
  }
  
  List<UnifiedVendor> _createUnifiedVendorList(
    List<VendorApplication> applications,
    List<ManagedVendor> managedVendors,
  ) {
    final Map<String, UnifiedVendor> vendorMap = {};
    
    for (final vendor in managedVendors) {
      final vendorUserId = vendor.metadata['vendorUserId'] as String? ?? vendor.id;
      vendorMap[vendorUserId] = UnifiedVendor.fromManagedVendor(vendor);
    }
    
    for (final application in applications) {
      if (!vendorMap.containsKey(application.vendorId)) {
        vendorMap[application.vendorId] = UnifiedVendor.fromApplication(application);
      }
    }
    
    return vendorMap.values.toList();
  }
  
  TimeOfDay? _parseTimeOfDay(String timeString, bool isStart) {
    final regex = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false);
    final match = regex.firstMatch(timeString);
    
    if (match != null) {
      int hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3)!.toUpperCase();
      
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      
      return TimeOfDay(hour: hour, minute: minute);
    }
    return isStart ? const TimeOfDay(hour: 9, minute: 0) : const TimeOfDay(hour: 14, minute: 0);
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
  
  int get _completedRequiredCount {
    return _requiredFields.where((field) => _completedFields[field] == true).length;
  }
  
  bool get _canSaveMarket {
    return _requiredFields.every((field) => _completedFields[field] == true) && _hasChanges;
  }
  
  String _getProgressText() {
    return '$_completedRequiredCount of ${_requiredFields.length} required fields completed';
  }
  
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
  
  Future<List<String>> _uploadFlyers() async {
    if (_selectedFlyers.isEmpty) return _existingFlyerUrls;
    
    setState(() => _isFlyerUploading = true);
    
    try {
      final uploadedUrls = <String>[];
      final authState = context.read<AuthBloc>().state;
      final userId = authState is Authenticated ? authState.userProfile?.userId ?? 'anonymous' : 'anonymous';
      
      for (final flyer in _selectedFlyers) {
        final url = await PhotoService.uploadPhoto(flyer, 'market_flyers', userId);
        uploadedUrls.add(url);
      }
      
      return [..._existingFlyerUrls, ...uploadedUrls];
    } catch (e) {
      throw Exception('Failed to upload flyers: $e');
    } finally {
      setState(() => _isFlyerUploading = false);
    }
  }
  
  Future<void> _saveMarket() async {
    if (!_canSaveMarket) return;
    
    setState(() => _isSaving = true);
    
    try {
      // Upload flyers if any
      final flyerUrls = await _uploadFlyers();
      
      // Parse address components
      final addressComponents = _selectedPlace!.formattedAddress.split(', ');
      final address = addressComponents[0];
      final city = addressComponents.length > 1 ? addressComponents[1] : '';
      final stateAndZip = addressComponents.length > 2 ? addressComponents[2] : '';
      final state = stateAndZip.split(' ')[0];
      
      // Create location data
      final locationData = LocationDataService.createLocationData(
        locationString: _selectedPlace!.formattedAddress,
        latitude: _selectedPlace!.latitude,
        longitude: _selectedPlace!.longitude,
        placeId: _selectedPlace!.placeId,
        locationName: _selectedPlace!.name,
      );
      
      // Update market
      final updatedMarket = _originalMarket!.copyWith(
        name: _formData['name'],
        address: address,
        city: city,
        state: state,
        latitude: _selectedPlace!.latitude,
        longitude: _selectedPlace!.longitude,
        eventDate: _formData['marketDate'],
        startTime: _formatTimeOfDay(_formData['startTime'] ?? const TimeOfDay(hour: 9, minute: 0)),
        endTime: _formatTimeOfDay(_formData['endTime'] ?? const TimeOfDay(hour: 14, minute: 0)),
        description: _formData['description']?.trim().isNotEmpty == true ? _formData['description'] : null,
        flyerUrls: flyerUrls,
        associatedVendorIds: _selectedVendorIds,
        instagramHandle: _formData['instagram']?.trim().isNotEmpty == true 
            ? (_formData['instagram'] as String).replaceAll('@', '').trim() 
            : null,
        isLookingForVendors: _formData['lookingForVendors'] ?? false,
        applicationUrl: _formData['applicationUrl'],
        applicationFee: _formData['applicationFee'],
        dailyBoothFee: _formData['dailyBoothFee'],
        vendorSpotsTotal: _formData['vendorSpotsTotal'],
        vendorSpotsAvailable: _formData['vendorSpotsAvailable'],
        applicationDeadline: _formData['applicationDeadline'],
        vendorRequirements: _formData['vendorRequirements'],
        locationData: locationData,
      );
      
      await MarketService.updateMarket(widget.marketId, updatedMarket.toFirestore());

      // Handle recruitment post if looking for vendors
      if (_formData['lookingForVendors'] == true) {
        try {
          final authState = context.read<AuthBloc>().state;
          final organizerEmail = authState is Authenticated
              ? (authState.userProfile?.email ?? authState.user.email ?? '')
              : '';

          // Check if recruitment post exists
          final existingPosts = await OrganizerVendorPostService.getOrganizerPosts(
            updatedMarket.organizerId ?? '',
            marketId: widget.marketId,
          );

          if (existingPosts.isNotEmpty) {
            // Update existing post
            final existingPost = existingPosts.first;
            final updates = {
              'title': _formData['name'],
              'description': _formData['description'] ?? '',
              'requirements': VendorRequirements(
                experienceLevel: ExperienceLevel.beginner,
                applicationDeadline: _formData['applicationDeadline'],
                startDate: _formData['marketDate'],
                endDate: _formData['marketDate'],
                boothFee: _formData['dailyBoothFee']?.toDouble() ?? 0,
              ).toMap(),
              'contactInfo': ContactInfo(
                preferredMethod: _formData['applicationUrl'] != null && (_formData['applicationUrl'] as String).isNotEmpty
                    ? ContactMethod.form
                    : ContactMethod.email,
                email: organizerEmail.isNotEmpty ? organizerEmail : 'noreply@hipop.com',
                formUrl: _formData['applicationUrl'],
              ).toMap(),
              'expiresAt': _formData['applicationDeadline'],
            };
            await OrganizerVendorPostService.updateVendorPost(existingPost.id, updates);
            debugPrint('✅ Updated recruitment post ${existingPost.id} for market ${widget.marketId}');
          } else {
            // Create new post
            final recruitmentPost = OrganizerVendorPost(
              id: '', // Will be set by Firestore
              marketId: widget.marketId,
              organizerId: updatedMarket.organizerId ?? '',
              title: _formData['name'] ?? 'Market',
              description: _formData['description'] ?? '',
              categories: const [],
              requirements: VendorRequirements(
                experienceLevel: ExperienceLevel.beginner,
                applicationDeadline: _formData['applicationDeadline'],
                startDate: _formData['marketDate'],
                endDate: _formData['marketDate'],
                boothFee: _formData['dailyBoothFee']?.toDouble() ?? 0,
              ),
              contactInfo: ContactInfo(
                preferredMethod: _formData['applicationUrl'] != null && (_formData['applicationUrl'] as String).isNotEmpty
                    ? ContactMethod.form
                    : ContactMethod.email,
                email: organizerEmail.isNotEmpty ? organizerEmail : 'noreply@hipop.com',
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
            debugPrint('✅ Created recruitment post $postId for market ${widget.marketId}');
          }
        } catch (e) {
          debugPrint('⚠️ Failed to update/create recruitment post: $e');
          // Don't fail the market update if recruitment post fails
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Market updated successfully!'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );

        context.pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating market: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
  
  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        title: Text(
          'Discard Changes?',
          style: TextStyle(color: HiPopColors.darkTextPrimary),
        ),
        content: Text(
          'You have unsaved changes. Are you sure you want to leave?',
          style: TextStyle(color: HiPopColors.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: HiPopColors.darkTextSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: HiPopColors.errorPlum),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    
    return result ?? false;
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
  
  Widget _buildInlineTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    bool isRequired = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Widget? prefixIcon,
    String? prefixText,
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
            prefixIcon: prefixIcon,
            prefixText: prefixText,
            prefixStyle: TextStyle(color: HiPopColors.darkTextSecondary),
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
                _hasChanges = true;
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
                      _updateCompletedFields();
                      _hasChanges = true;
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
                      _updateCompletedFields();
                      _hasChanges = true;
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
          initialLocation: _selectedPlace?.formattedAddress,
          textStyle: TextStyle(
            color: HiPopColors.darkTextPrimary,
            fontSize: 16,
          ),
          onPlaceSelected: (placeDetails) {
            setState(() {
              _selectedPlace = placeDetails;
              _completedFields['location'] = true;
              _hasChanges = true;
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
  
  Widget _buildFlyerUploadSection() {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, color: HiPopColors.organizerAccent),
                const SizedBox(width: 8),
                Text(
                  'Market Flyers',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Upload flyers to showcase your market event',
              style: TextStyle(
                fontSize: 14,
                color: HiPopColors.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            PhotoUploadWidget(
              onPhotosSelected: (files) {
                setState(() {
                  _selectedFlyers = files;
                  _hasChanges = true;
                });
              },
              onExistingPhotosChanged: (urls) {
                setState(() {
                  _existingFlyerUrls = urls;
                  _hasChanges = true;
                });
              },
              initialImagePaths: _existingFlyerUrls.isNotEmpty ? _existingFlyerUrls : null,
              userId: FirebaseAuth.instance.currentUser?.uid,
              userType: 'market_organizer',
            ),
          ],
        ),
      ),
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
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HiPopColors.organizerAccent.withOpacity( 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.campaign,
                    color: HiPopColors.organizerAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Looking for Vendors',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: HiPopColors.darkTextPrimary,
                            ),
                          ),
                        ],
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
                  activeColor: HiPopColors.organizerAccent,
                  onChanged: (value) {
                    setState(() {
                      _formData['lookingForVendors'] = value;
                      _hasChanges = true;
                    });
                  },
                ),
              ],
            ),
            if (isEnabled) ...[
              const SizedBox(height: 16),
              _buildInlineTextField(
                label: 'Application URL',
                controller: _applicationUrlController,
                hintText: 'https://your-application-form.com',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInlineTextField(
                      label: 'Application Fee',
                      controller: _applicationFeeController,
                      hintText: '0.00',
                      keyboardType: TextInputType.number,
                      prefixText: '\$',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInlineTextField(
                      label: 'Daily Booth Fee',
                      controller: _dailyBoothFeeController,
                      hintText: '0.00',
                      keyboardType: TextInputType.number,
                      prefixText: '\$',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildInlineTextField(
                label: 'Total Vendor Spots',
                controller: _vendorSpotsController,
                hintText: 'e.g., 50',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildInlineTextField(
                label: 'Vendor Requirements',
                controller: _vendorRequirementsController,
                hintText: 'Enter each requirement on a new line',
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildVendorManagementSection() {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: HiPopColors.organizerAccent),
                const SizedBox(width: 8),
                Text(
                  'Associated Vendors',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: HiPopColors.organizerAccent.withOpacity( 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedVendorIds.length}',
                    style: TextStyle(
                      color: HiPopColors.organizerAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingVendors)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_unifiedVendors.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.group_off,
                        size: 48,
                        color: HiPopColors.darkTextTertiary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No vendors available',
                        style: TextStyle(
                          color: HiPopColors.darkTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _unifiedVendors.length,
                  itemBuilder: (context, index) {
                    final vendor = _unifiedVendors[index];
                    final isSelected = _selectedVendorIds.contains(vendor.id);
                    
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedVendorIds.add(vendor.id);
                          } else {
                            _selectedVendorIds.remove(vendor.id);
                          }
                          _hasChanges = true;
                        });
                      },
                      title: Text(
                        vendor.businessName,
                        style: TextStyle(color: HiPopColors.darkTextPrimary),
                      ),
                      subtitle: Text(
                        vendor.email,
                        style: TextStyle(color: HiPopColors.darkTextSecondary),
                      ),
                      activeColor: HiPopColors.organizerAccent,
                      checkColor: Colors.white,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _instagramController.dispose();
    _websiteController.dispose();
    _applicationUrlController.dispose();
    _applicationFeeController.dispose();
    _dailyBoothFeeController.dispose();
    _vendorSpotsController.dispose();
    _vendorRequirementsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: HiPopColors.darkBackground,
        body: Center(
          child: CircularProgressIndicator(
            color: HiPopColors.organizerAccent,
          ),
        ),
      );
    }
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: HiPopColors.darkBackground,
        appBar: AppBar(
          backgroundColor: HiPopColors.darkSurface,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: HiPopColors.darkTextPrimary),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                context.pop();
              }
            },
          ),
          title: Text(
            'Edit Market',
            style: TextStyle(
              color: HiPopColors.darkTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (_hasChanges)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text(
                    'Unsaved',
                    style: TextStyle(
                      fontSize: 12,
                      color: HiPopColors.warningAmber,
                    ),
                  ),
                  backgroundColor: HiPopColors.warningAmber.withOpacity( 0.1),
                  side: BorderSide(
                    color: HiPopColors.warningAmber.withOpacity( 0.3),
                  ),
                ),
              ),
          ],
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
                  _buildSectionHeader('BASIC INFORMATION'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildInlineTextField(
                          label: 'Market Name',
                          controller: _nameController,
                          hintText: 'e.g., Downtown Farmers Market',
                          isRequired: true,
                        ),
                        const SizedBox(height: 20),
                        _buildLocationField(),
                        const SizedBox(height: 20),
                        _buildInlineTextField(
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
                  
                  _buildSectionHeader('MARKETING & MEDIA'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildInlineTextField(
                          label: 'Instagram',
                          controller: _instagramController,
                          hintText: '@yourmarket',
                          prefixText: '@',
                        ),
                        const SizedBox(height: 20),
                        _buildFlyerUploadSection(),
                      ],
                    ),
                  ),
                  
                  _buildSectionHeader('VENDOR MANAGEMENT'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildVendorToggle(),
                        const SizedBox(height: 16),
                        _buildVendorManagementSection(),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
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
                      if (_hasChanges)
                        Text(
                          'You have unsaved changes',
                          style: TextStyle(
                            fontSize: 12,
                            color: HiPopColors.warningAmber,
                          ),
                        )
                      else
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
                          onPressed: _canSaveMarket && !_isSaving ? _saveMarket : null,
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
                          child: _isSaving
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Save Changes',
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