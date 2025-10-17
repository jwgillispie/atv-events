import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/features/shared/services/data/event_service.dart';
import 'package:intl/intl.dart';
import '../../../../blocs/auth/auth_bloc.dart';
import '../../../../blocs/auth/auth_state.dart';
import '../../../shared/models/event.dart';
import '../../../market/models/market.dart';
import '../../../shared/widgets/common/simple_places_widget.dart';
import '../../../shared/widgets/common/photo_upload_widget.dart';
import '../../../shared/services/location/places_service.dart';
import '../../../shared/services/utilities/photo_service.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import '../../../shared/widgets/ai_flyer_upload_widget.dart';

class CreateEventScreen extends StatefulWidget {
  final Event? editingEvent;
  final VoidCallback? onEventCreated;
  
  const CreateEventScreen({
    super.key,
    this.editingEvent,
    this.onEventCreated,
  });

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  // Form data and completion tracking
  final Map<String, dynamic> _formData = {};
  final Map<String, bool> _completedFields = {};
  
  // Required fields
  final List<String> _requiredFields = [
    'name',
    'location',
    'startDateTime',
    'endDateTime',
  ];
  
  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final _eventWebsiteController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();

  // Ticketing controllers
  final _ticketPriceController = TextEditingController();
  final _maxAttendeesController = TextEditingController();
  final _ticketDescriptionController = TextEditingController();

  // Form state
  DateTime _startDateTime = DateTime.now().add(const Duration(days: 1));
  DateTime _endDateTime = DateTime.now().add(const Duration(days: 1, hours: 2));
  Market? _selectedMarket;
  bool _isLoading = false;

  // Ticketing state
  bool _hasTicketing = false;
  bool _enableQRScanning = true; // Default to enabled for better UX
  
  // Location selection with Google Places
  PlaceDetails? _selectedPlace;
  String _selectedAddress = '';
  
  // Photo management
  final List<File> _selectedPhotos = [];
  
  @override
  void initState() {
    super.initState();
    _initializeFormListeners();
    _loadMarkets();

    // Initialize with existing data if editing
    if (widget.editingEvent != null) {
      _initializeEditingData();
    }
  }
  
  void _initializeFormListeners() {
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
    
    _tagsController.addListener(() {
      setState(() {
        _formData['tags'] = _tagsController.text;
      });
    });
    
    _eventWebsiteController.addListener(() {
      setState(() {
        _formData['eventWebsite'] = _eventWebsiteController.text;
      });
    });
    
    _instagramController.addListener(() {
      setState(() {
        _formData['instagram'] = _instagramController.text;
      });
    });
    
    _facebookController.addListener(() {
      setState(() {
        _formData['facebook'] = _facebookController.text;
      });
    });
    
    // Ticketing listeners
    _ticketPriceController.addListener(() {
      setState(() {
        _formData['ticketPrice'] = _ticketPriceController.text;
      });
    });

    _maxAttendeesController.addListener(() {
      setState(() {
        _formData['maxAttendees'] = _maxAttendeesController.text;
      });
    });

    _ticketDescriptionController.addListener(() {
      setState(() {
        _formData['ticketDescription'] = _ticketDescriptionController.text;
      });
    });
  }
  
  void _initializeEditingData() {
    final event = widget.editingEvent!;
    _nameController.text = event.name;
    _descriptionController.text = event.description ?? '';
    _tagsController.text = event.tags?.join(', ') ?? '';
    _eventWebsiteController.text = event.eventWebsite ?? '';
    _instagramController.text = event.instagramUrl?.replaceAll('https://instagram.com/', '') ?? '';
    _facebookController.text = event.facebookUrl ?? '';
    _startDateTime = event.startDateTime;
    _endDateTime = event.endDateTime;
    _selectedAddress = event.location;

    // Initialize ticketing data
    _hasTicketing = event.hasTicketing;
    _enableQRScanning = event.enableQRScanning ?? true;
    if (event.ticketPrice != null) {
      _ticketPriceController.text = event.ticketPrice!.toStringAsFixed(2);
    }
    if (event.maxAttendees != null) {
      _maxAttendeesController.text = event.maxAttendees!.toString();
    }
    _ticketDescriptionController.text = event.ticketDescription ?? '';

    // Mark fields as completed
    _completedFields['name'] = true;
    _completedFields['location'] = true;
    _completedFields['startDateTime'] = true;
    _completedFields['endDateTime'] = true;
  }
  
  

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _eventWebsiteController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _ticketPriceController.dispose();
    _maxAttendeesController.dispose();
    _ticketDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadMarkets() async {
    // For now, we'll skip market loading since the association isn't implemented
    // This can be added later when market-organizer association is implemented
  }

  void _onPlaceSelected(PlaceDetails place) {
    setState(() {
      _selectedPlace = place;
      _selectedAddress = place.formattedAddress;
      _formData['location'] = place;
      _completedFields['location'] = true;
    });
  }

  void _onAddressCleared() {
    setState(() {
      _selectedPlace = null;
      _selectedAddress = '';
      _formData['location'] = null;
      _completedFields['location'] = false;
    });
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
  
  int get _completedRequiredCount {
    return _requiredFields.where((field) => _completedFields[field] == true).length;
  }
  
  bool get _canCreateEvent {
    // Check required fields completion
    bool baseFieldsValid = _requiredFields.every((field) => _completedFields[field] == true);

    // If ticketing is enabled, validate ticket fields
    if (_hasTicketing) {
      bool hasValidPrice = _ticketPriceController.text.isNotEmpty &&
                          double.tryParse(_ticketPriceController.text) != null &&
                          double.tryParse(_ticketPriceController.text)! >= 0;
      bool hasValidAttendees = _maxAttendeesController.text.isNotEmpty &&
                              int.tryParse(_maxAttendeesController.text) != null &&
                              int.tryParse(_maxAttendeesController.text)! > 0;

      return baseFieldsValid && hasValidPrice && hasValidAttendees;
    }

    return baseFieldsValid;
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

  Future<void> _selectDateTime(BuildContext context, bool isStartDate) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDateTime : _endDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: HiPopColors.primaryDeepSage,
              onPrimary: Colors.white,
              surface: HiPopColors.darkSurface,
              onSurface: HiPopColors.darkTextPrimary,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: HiPopColors.darkSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedDate != null && mounted) {
      if (!context.mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStartDate ? _startDateTime : _endDateTime),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: HiPopColors.primaryDeepSage,
                onPrimary: Colors.white,
                surface: HiPopColors.darkSurface,
                onSurface: HiPopColors.darkTextPrimary,
              ),
              dialogTheme: const DialogThemeData(
                backgroundColor: HiPopColors.darkSurface,
              ),
              timePickerTheme: const TimePickerThemeData(
                backgroundColor: HiPopColors.darkSurface,
                dialBackgroundColor: HiPopColors.darkSurfaceVariant,
                hourMinuteColor: HiPopColors.darkSurfaceVariant,
                hourMinuteTextColor: HiPopColors.darkTextPrimary,
                dialHandColor: HiPopColors.primaryDeepSage,
                dialTextColor: HiPopColors.darkTextPrimary,
                entryModeIconColor: HiPopColors.darkTextSecondary,
                dayPeriodBorderSide: BorderSide(color: HiPopColors.darkBorder),
                dayPeriodTextColor: HiPopColors.darkTextPrimary,
              ),
            ),
            child: child!,
          );
        },
      );
      
      if (pickedTime != null && mounted) {
        setState(() {
          final newDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          
          if (isStartDate) {
            _startDateTime = newDateTime;
            _formData['startDateTime'] = _startDateTime;
            _completedFields['startDateTime'] = true;
            // Ensure end date is after start date
            if (_endDateTime.isBefore(_startDateTime)) {
              _endDateTime = _startDateTime.add(const Duration(hours: 2));
              _formData['endDateTime'] = _endDateTime;
              _completedFields['endDateTime'] = true;
            }
          } else {
            _endDateTime = newDateTime;
            _formData['endDateTime'] = _endDateTime;
            _completedFields['endDateTime'] = true;
          }
        });
      }
    }
  }

  Future<void> _createEvent() async {
    if (!_canCreateEvent) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_selectedPlace == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a location for the event'),
              backgroundColor: HiPopColors.errorPlum,
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      // Upload photo if selected
      String imageUrl = '';
      if (_selectedPhotos.isNotEmpty) {
        try {
          // Generate a temporary event ID for photo storage
          final tempEventId = 'event_${authState.user.uid}_${DateTime.now().millisecondsSinceEpoch}';
          imageUrl = await PhotoService.uploadPhoto(
            _selectedPhotos.first,
            'events',
            tempEventId,
            customFileName: 'event_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        } catch (e) {
          // Continue without photo if upload fails
          debugPrint('Photo upload failed: $e');
        }
      }

      if (!mounted) return;

      final addressComponents = _parseAddressComponents(_selectedPlace!.formattedAddress);

      // Parse ticketing values
      double? ticketPrice;
      int? maxAttendees;

      if (_hasTicketing) {
        if (_ticketPriceController.text.isNotEmpty) {
          ticketPrice = double.tryParse(_ticketPriceController.text);
        }
        if (_maxAttendeesController.text.isNotEmpty) {
          maxAttendees = int.tryParse(_maxAttendeesController.text);
        }
      }

      final event = Event(
        id: widget.editingEvent?.id ?? '', // Will be set by Firestore for new events
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _selectedPlace!.formattedAddress,
        address: addressComponents['address'] ?? _selectedPlace!.formattedAddress,
        city: addressComponents['city'] ?? '',
        state: addressComponents['state'] ?? '',
        latitude: _selectedPlace!.latitude,
        longitude: _selectedPlace!.longitude,
        startDateTime: _startDateTime,
        endDateTime: _endDateTime,
        organizerId: authState.user.uid,
        organizerName: authState.userProfile?.businessName ??
                     authState.userProfile?.organizationName ??
                     authState.user.email ?? 'Unknown',
        marketId: _selectedMarket?.id,
        tags: _tagsController.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(),
        imageUrl: imageUrl.isNotEmpty ? imageUrl : widget.editingEvent?.imageUrl,
        links: const [],
        eventWebsite: _eventWebsiteController.text.trim().isNotEmpty
            ? _eventWebsiteController.text.trim()
            : null,
        instagramUrl: _instagramController.text.trim().isNotEmpty
            ? 'https://instagram.com/${_instagramController.text.replaceAll('@', '').trim()}'
            : null,
        facebookUrl: _facebookController.text.trim().isNotEmpty
            ? _facebookController.text.trim()
            : null,
        additionalLinks: null,
        isActive: true,
        createdAt: widget.editingEvent?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        // Ticketing fields
        hasTicketing: _hasTicketing,
        requiresTicket: _hasTicketing,
        ticketPrice: ticketPrice,
        maxAttendees: maxAttendees,
        earlyBirdPrice: null,
        earlyBirdDeadline: null,
        enableQRScanning: _hasTicketing ? _enableQRScanning : null,
        ticketDescription: _hasTicketing && _ticketDescriptionController.text.isNotEmpty
            ? _ticketDescriptionController.text.trim()
            : null,
      );

      if (widget.editingEvent != null) {
        final eventId = widget.editingEvent?.id ?? '';
        await EventService.updateEvent(eventId, event.toFirestore());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully!')),
        );
      } else {
        await EventService.createEvent(event);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully!')),
        );
      }
      
      widget.onEventCreated?.call();
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating event: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  
  Widget _buildInlineTextField({
    required String fieldKey,
    required String label,
    required TextEditingController controller,
    required String hintText,
    bool isRequired = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    IconData? prefixIcon,
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
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: HiPopColors.darkTextSecondary) : null,
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
              borderSide: BorderSide(color: HiPopColors.primaryDeepSage, width: 2),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Event Schedule',
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
        const SizedBox(height: 16),
        // Start Date & Time
        GestureDetector(
          onTap: () => _selectDateTime(context, true),
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
                Icon(Icons.event, color: HiPopColors.primaryDeepSage),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Date & Time',
                        style: TextStyle(
                          color: HiPopColors.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, yyyy - h:mm a').format(_startDateTime),
                        style: TextStyle(
                          color: HiPopColors.darkTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: HiPopColors.darkTextSecondary, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // End Date & Time
        GestureDetector(
          onTap: () => _selectDateTime(context, false),
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
                Icon(Icons.event, color: HiPopColors.primaryDeepSage),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End Date & Time',
                        style: TextStyle(
                          color: HiPopColors.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, yyyy - h:mm a').format(_endDateTime),
                        style: TextStyle(
                          color: HiPopColors.darkTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: HiPopColors.darkTextSecondary, size: 16),
              ],
            ),
          ),
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
        Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: HiPopColors.darkSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: HiPopColors.darkBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: HiPopColors.darkBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: HiPopColors.primaryDeepSage, width: 2),
              ),
              labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
              hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withOpacity( 0.5)),
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: HiPopColors.darkTextPrimary),
            ),
          ),
          child: SimplePlacesWidget(
            initialLocation: _selectedAddress,
            onLocationSelected: (PlaceDetails? place) {
              if (place != null) {
                _onPlaceSelected(place);
              } else {
                _onAddressCleared();
              }
            },
          ),
        ),
        if (_selectedPlace != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HiPopColors.successGreen.withOpacity( 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HiPopColors.successGreen.withOpacity( 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: HiPopColors.successGreenDark, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location confirmed: ${_selectedPlace!.formattedAddress}',
                    style: const TextStyle(
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
    );
  }
  
  Widget _buildPhotoUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Event Photo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: HiPopColors.primaryDeepSage.withOpacity( 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: HiPopColors.primaryDeepSage.withOpacity( 0.3),
                ),
              ),
              child: const Text(
                'Optional',
                style: TextStyle(
                  fontSize: 12,
                  color: HiPopColors.primaryDeepSage,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Add a photo to make your event more attractive',
          style: TextStyle(
            fontSize: 14,
            color: HiPopColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: HiPopColors.primaryDeepSage,
              surface: HiPopColors.darkSurfaceVariant,
            ),
          ),
          child: PhotoUploadWidget(
            onPhotosSelected: (photos) {
              setState(() {
                _selectedPhotos.clear();
                _selectedPhotos.addAll(photos);
              });
            },
            maxPhotos: null, // Unlimited photos for events
            userId: context.read<AuthBloc>().state is Authenticated
                ? (context.read<AuthBloc>().state as Authenticated).user.uid
                : null,
            userType: 'organizer',
          ),
        ),
      ],
    );
  }
  
  Widget _buildTicketingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ticketing Toggle with Premium Badge
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hasTicketing
                ? HiPopColors.primaryDeepSage.withOpacity(0.05)
                : HiPopColors.darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hasTicketing
                  ? HiPopColors.primaryDeepSage.withOpacity(0.3)
                  : HiPopColors.darkBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.qr_code_2,
                          color: _hasTicketing
                              ? HiPopColors.primaryDeepSage
                              : HiPopColors.darkTextSecondary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enable Ticketing',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: HiPopColors.darkTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sell tickets with QR codes',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: HiPopColors.darkTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _hasTicketing,
                    onChanged: (value) {
                      setState(() {
                        _hasTicketing = value;
                      });
                    },
                    activeColor: HiPopColors.primaryDeepSage,
                    activeTrackColor: HiPopColors.primaryDeepSage.withOpacity(0.3),
                    inactiveThumbColor: HiPopColors.darkTextTertiary,
                    inactiveTrackColor: HiPopColors.darkBorder,
                  ),
                ],
              ),
              if (_hasTicketing) ...[
                const SizedBox(height: 20),
                // QR Scanning Toggle
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HiPopColors.darkBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        color: _enableQRScanning
                            ? HiPopColors.successGreen
                            : HiPopColors.darkTextTertiary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'QR Code Check-In',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: HiPopColors.darkTextPrimary,
                              ),
                            ),
                            Text(
                              'Scan tickets for fast entry',
                              style: TextStyle(
                                fontSize: 12,
                                color: HiPopColors.darkTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _enableQRScanning,
                        onChanged: (value) {
                          setState(() {
                            _enableQRScanning = value;
                          });
                        },
                        activeColor: HiPopColors.successGreen,
                        activeTrackColor: HiPopColors.successGreen.withOpacity(0.3),
                        inactiveThumbColor: HiPopColors.darkTextTertiary,
                        inactiveTrackColor: HiPopColors.darkBorder,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_hasTicketing) ...[
          const SizedBox(height: 20),
          // Ticket Price
          _buildInlineTextField(
            fieldKey: 'ticketPrice',
            label: 'Ticket Price',
            controller: _ticketPriceController,
            hintText: '0.00',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: Icons.attach_money,
            isRequired: _hasTicketing,
          ),
          const SizedBox(height: 20),
          // Max Attendees
          _buildInlineTextField(
            fieldKey: 'maxAttendees',
            label: 'Maximum Attendees',
            controller: _maxAttendeesController,
            hintText: 'e.g., 100',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.people,
            isRequired: _hasTicketing,
          ),
          const SizedBox(height: 20),
          // Ticket Description
          _buildInlineTextField(
            fieldKey: 'ticketDescription',
            label: 'What\'s Included',
            controller: _ticketDescriptionController,
            hintText: 'Describe what ticket holders will receive...',
            maxLines: 3,
            prefixIcon: Icons.receipt_long,
          ),
        ],
      ],
    );
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
          widget.editingEvent != null ? 'Edit Event' : 'Create New Event',
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

                // Basic Information Section
                _buildSectionHeader('BASIC INFORMATION'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildInlineTextField(
                        fieldKey: 'name',
                        label: 'Event Name',
                        controller: _nameController,
                        hintText: 'e.g., Summer Food Festival',
                        isRequired: true,
                        prefixIcon: Icons.event,
                      ),
                      const SizedBox(height: 20),
                      _buildInlineTextField(
                        fieldKey: 'description',
                        label: 'Description',
                        controller: _descriptionController,
                        hintText: 'Describe what makes your event special...',
                        maxLines: 3,
                        prefixIcon: Icons.description,
                      ),
                    ],
                  ),
                ),
                
                // Schedule & Timing Section
                _buildSectionHeader('SCHEDULE & TIMING'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildDateTimeSection(),
                ),
                
                // Location Section
                _buildSectionHeader('LOCATION'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildLocationField(),
                ),
                
                // Event Details Section
                _buildSectionHeader('EVENT DETAILS'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildInlineTextField(
                        fieldKey: 'tags',
                        label: 'Event Tags',
                        controller: _tagsController,
                        hintText: 'e.g., festival, food, community (comma-separated)',
                        prefixIcon: Icons.local_offer,
                      ),
                      const SizedBox(height: 20),
                      _buildPhotoUploadSection(),
                    ],
                  ),
                ),

                // Ticketing Section
                _buildSectionHeader('TICKETING & QR CODES'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTicketingSection(),
                ),
                
                // Links & Social Media Section
                _buildSectionHeader('LINKS & SOCIAL MEDIA'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildInlineTextField(
                        fieldKey: 'eventWebsite',
                        label: 'Event Website',
                        controller: _eventWebsiteController,
                        hintText: 'https://yourevent.com',
                        keyboardType: TextInputType.url,
                        prefixIcon: Icons.language,
                      ),
                      const SizedBox(height: 20),
                      _buildInlineTextField(
                        fieldKey: 'instagram',
                        label: 'Instagram Handle',
                        controller: _instagramController,
                        hintText: '@yourevent',
                        prefixIcon: Icons.camera_alt,
                      ),
                      const SizedBox(height: 20),
                      _buildInlineTextField(
                        fieldKey: 'facebook',
                        label: 'Facebook Event URL',
                        controller: _facebookController,
                        hintText: 'https://facebook.com/events/...',
                        keyboardType: TextInputType.url,
                        prefixIcon: Icons.facebook,
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
                        onPressed: _canCreateEvent && !_isLoading ? _createEvent : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HiPopColors.primaryDeepSage,
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
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.editingEvent != null ? Icons.save : Icons.check,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.editingEvent != null
                                    ? 'Update Event'
                                    : 'Create Event',
                                  style: TextStyle(
                                    fontSize: 16,
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
        ],
      ),
      ),
    );
  }
}