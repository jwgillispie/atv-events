import 'dart:io';
import 'package:flutter/material.dart';
import 'package:atv_events/features/shared/services/data/event_service.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/event.dart';
import '../../../market/models/market.dart';
import '../../../shared/widgets/common/photo_upload_widget.dart';
import '../../../shared/services/utilities/photo_service.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import '../../../shared/widgets/common/simple_places_widget.dart';
import '../../../shared/services/location/places_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/auth/auth_bloc.dart';
import '../../../../blocs/auth/auth_state.dart';

class EditEventScreen extends StatefulWidget {
  final Event event;
  
  const EditEventScreen({super.key, required this.event});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _tagsController;
  
  // Form state
  late DateTime _startDateTime;
  late DateTime _endDateTime;
  Market? _selectedMarket;
  final List<Market> _availableMarkets = [];
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;
  
  // Photo management
  final List<File> _selectedPhotos = [];
  final List<String> _existingPhotos = [];
  
  // Social media and links
  late final TextEditingController _eventWebsiteController;
  late final TextEditingController _instagramController;
  late final TextEditingController _facebookController;
  late final TextEditingController _ticketUrlController;

  // Location selection
  PlaceDetails? _selectedPlace;
  String _selectedAddress = '';

  // Ticket configuration (simple, matching create event)
  bool _hasTicketing = false;
  bool _enableQRScanning = true;
  late final TextEditingController _ticketPriceController;
  late final TextEditingController _maxAttendeesController;
  late final TextEditingController _ticketDescriptionController;
  late final TextEditingController _earlyBirdPriceController;
  bool _hasEarlyBirdPricing = false;
  DateTime? _earlyBirdDeadline;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadMarkets();
  }

  void _initializeForm() {
    _nameController = TextEditingController(text: widget.event.name);
    _descriptionController = TextEditingController(text: widget.event.description);
    _addressController = TextEditingController(text: widget.event.address);
    _cityController = TextEditingController(text: widget.event.city);
    _stateController = TextEditingController(text: widget.event.state);
    _tagsController = TextEditingController(text: widget.event.tags.join(', '));
    
    // Initialize social media controllers
    _eventWebsiteController = TextEditingController(text: widget.event.eventWebsite ?? '');
    _instagramController = TextEditingController(
      text: widget.event.instagramUrl?.replaceAll('https://instagram.com/', '') ?? '',
    );
    _facebookController = TextEditingController(text: widget.event.facebookUrl ?? '');
    _ticketUrlController = TextEditingController(text: widget.event.ticketUrl ?? '');
    
    _startDateTime = widget.event.startDateTime;
    _endDateTime = widget.event.endDateTime;
    _latitude = widget.event.latitude;
    _longitude = widget.event.longitude;
    
    // Initialize location with existing data
    _selectedAddress = widget.event.location;

    // Initialize ticketing settings
    _hasTicketing = widget.event.hasTicketing ?? false;
    _enableQRScanning = widget.event.enableQRScanning ?? true;
    _ticketPriceController = TextEditingController(
      text: widget.event.ticketPrice != null ? widget.event.ticketPrice!.toStringAsFixed(2) : '',
    );
    _maxAttendeesController = TextEditingController(
      text: widget.event.maxAttendees != null ? widget.event.maxAttendees.toString() : '',
    );
    _ticketDescriptionController = TextEditingController(
      text: widget.event.ticketDescription ?? '',
    );
    _earlyBirdPriceController = TextEditingController(
      text: widget.event.earlyBirdPrice != null ? widget.event.earlyBirdPrice!.toStringAsFixed(2) : '',
    );
    _hasEarlyBirdPricing = widget.event.earlyBirdPrice != null;
    _earlyBirdDeadline = widget.event.earlyBirdDeadline;

    // Initialize existing photo if available
    if (widget.event.imageUrl?.isNotEmpty ?? false) {
      _existingPhotos.add(widget.event.imageUrl!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _tagsController.dispose();
    _eventWebsiteController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _ticketUrlController.dispose();
    _ticketPriceController.dispose();
    _maxAttendeesController.dispose();
    _ticketDescriptionController.dispose();
    _earlyBirdPriceController.dispose();
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
      _addressController.text = place.formattedAddress.split(',').first;
      _latitude = place.latitude;
      _longitude = place.longitude;
      
      // Parse city and state from formatted address
      final parts = place.formattedAddress.split(', ');
      if (parts.length >= 3) {
        _cityController.text = parts[1];
        final stateZip = parts[2].split(' ');
        if (stateZip.isNotEmpty) {
          _stateController.text = stateZip[0];
        }
      }
    });
  }

  void _onAddressCleared() {
    setState(() {
      _selectedPlace = null;
      _selectedAddress = '';
      _addressController.clear();
      _cityController.clear();
      _stateController.clear();
      _latitude = null;
      _longitude = null;
    });
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
            // Ensure end date is after start date
            if (_endDateTime.isBefore(_startDateTime)) {
              _endDateTime = _startDateTime.add(const Duration(hours: 2));
            }
          } else {
            _endDateTime = newDateTime;
          }
        });
      }
    }
  }

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Upload new photo if selected
      String imageUrl = widget.event.imageUrl ?? '';
      if (_selectedPhotos.isNotEmpty) {
        try {
          final authState = context.read<AuthBloc>().state;
          if (authState is Authenticated) {
            imageUrl = await PhotoService.uploadPhoto(
              _selectedPhotos.first,
              'events',
              widget.event.id,
              customFileName: 'event_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            
            // Delete old photo if exists and different from new one
            if ((widget.event.imageUrl?.isNotEmpty ?? false) && widget.event.imageUrl != imageUrl) {
              try {
                await PhotoService.deletePhoto(widget.event.imageUrl!);
              } catch (e) {
                // Continue even if deletion fails
                debugPrint('Failed to delete old photo: $e');
              }
            }
          }
        } catch (e) {
          // Continue without photo if upload fails
          debugPrint('Photo upload failed: $e');
        }
      } else if (_existingPhotos.isEmpty && (widget.event.imageUrl?.isNotEmpty ?? false)) {
        // Photo was removed
        try {
          await PhotoService.deletePhoto(widget.event.imageUrl!);
          imageUrl = '';
        } catch (e) {
          debugPrint('Failed to delete photo: $e');
        }
      }

      if (!mounted) return;

      final updatedData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _selectedPlace?.formattedAddress ?? _addressController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'startDateTime': _startDateTime,
        'endDateTime': _endDateTime,
        'marketId': _selectedMarket?.id,
        'tags': _tagsController.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(),
        'imageUrl': imageUrl,
        'eventWebsite': _eventWebsiteController.text.trim().isNotEmpty
            ? _eventWebsiteController.text.trim()
            : null,
        'instagramUrl': _instagramController.text.trim().isNotEmpty
            ? 'https://instagram.com/${_instagramController.text.replaceAll('@', '').trim()}'
            : null,
        'facebookUrl': _facebookController.text.trim().isNotEmpty
            ? _facebookController.text.trim()
            : null,
        'ticketUrl': _ticketUrlController.text.trim().isNotEmpty
            ? _ticketUrlController.text.trim()
            : null,
        'hasTicketing': _hasTicketing,
        'requiresTicket': _hasTicketing,
        'enableQRScanning': _hasTicketing ? _enableQRScanning : null,
        'ticketPrice': _hasTicketing && _ticketPriceController.text.isNotEmpty
            ? double.tryParse(_ticketPriceController.text)
            : null,
        'maxAttendees': _hasTicketing && _maxAttendeesController.text.isNotEmpty
            ? int.tryParse(_maxAttendeesController.text)
            : null,
        'earlyBirdPrice': _hasTicketing && _hasEarlyBirdPricing && _earlyBirdPriceController.text.isNotEmpty
            ? double.tryParse(_earlyBirdPriceController.text)
            : null,
        'earlyBirdDeadline': _hasTicketing && _hasEarlyBirdPricing ? _earlyBirdDeadline : null,
        'ticketDescription': _hasTicketing && _ticketDescriptionController.text.isNotEmpty
            ? _ticketDescriptionController.text.trim()
            : null,
        'updatedAt': DateTime.now(),
      };

      await EventService.updateEvent(widget.event.id, updatedData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating event: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? HiPopColors.darkBackground : HiPopColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDarkMode ? HiPopColors.darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Event',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _updateEvent,
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildEventInformationCard(),
              const SizedBox(height: 16),
              _buildDateTimeCard(),
              const SizedBox(height: 16),
              _buildLocationSelectionCard(),
              const SizedBox(height: 16),
              _buildPhotoUploadCard(),
              const SizedBox(height: 16),
              if (_availableMarkets.isNotEmpty) ...[
                _buildMarketAssociationCard(),
                const SizedBox(height: 16),
              ],
              _buildAdditionalDetailsCard(),
              const SizedBox(height: 16),
              _buildSocialMediaCard(),
              const SizedBox(height: 16),
              _buildTicketingSection(),
              const SizedBox(height: 80), // Bottom padding for FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketingSection() {
    return Card(
      color: HiPopColors.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: HiPopColors.darkBorder.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ticketing & QR Codes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            // Ticketing Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _hasTicketing
                    ? HiPopColors.primaryDeepSage.withValues(alpha: 0.05)
                    : HiPopColors.darkBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasTicketing
                      ? HiPopColors.primaryDeepSage.withValues(alpha: 0.3)
                      : HiPopColors.darkBorder,
                ),
              ),
              child: Column(
                children: [
                  Row(
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
                      Switch(
                        value: _hasTicketing,
                        onChanged: (value) {
                          setState(() {
                            _hasTicketing = value;
                          });
                        },
                        activeThumbColor: HiPopColors.primaryDeepSage,
                        activeTrackColor: HiPopColors.primaryDeepSage.withValues(alpha: 0.3),
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
                            activeThumbColor: HiPopColors.successGreen,
                            activeTrackColor: HiPopColors.successGreen.withValues(alpha: 0.3),
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
              // Ticket Price, Max Attendees, Description - Simple text fields
              Text(
                'Ticket Price',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _ticketPriceController,
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              Text(
                'Maximum Attendees',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _maxAttendeesController,
                decoration: InputDecoration(
                  hintText: 'e.g., 100',
                  prefixIcon: const Icon(Icons.people),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Text(
                'What\'s Included',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _ticketDescriptionController,
                decoration: InputDecoration(
                  hintText: 'Describe what ticket holders will receive...',
                  prefixIcon: const Icon(Icons.receipt_long),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventInformationCard() {
    return Card(
      color: HiPopColors.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: HiPopColors.darkBorder.withOpacity( 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: HiPopColors.primaryDeepSage,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Event Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Event Name *',
                labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                hintText: 'e.g., Summer Food Festival',
                hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withOpacity( 0.5)),
                prefixIcon: const Icon(Icons.event, color: HiPopColors.darkTextSecondary),
                filled: true,
                fillColor: HiPopColors.darkSurfaceVariant,
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
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: HiPopColors.errorPlum),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Event name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: HiPopColors.darkTextPrimary),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Event Description',
                labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                hintText: 'Describe what makes your event special...',
                hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withOpacity( 0.5)),
                prefixIcon: const Icon(Icons.description, color: HiPopColors.darkTextSecondary),
                filled: true,
                fillColor: HiPopColors.darkSurfaceVariant,
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
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeCard() {
    return Card(
      color: HiPopColors.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: HiPopColors.darkBorder.withOpacity( 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.schedule,
                  color: HiPopColors.primaryDeepSage,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Date & Time',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Material(
              color: HiPopColors.darkSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _selectDateTime(context, true),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HiPopColors.darkBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: HiPopColors.darkTextSecondary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Start Date & Time',
                              style: TextStyle(
                                color: HiPopColors.darkTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM d, yyyy - h:mm a').format(_startDateTime),
                              style: const TextStyle(
                                color: HiPopColors.darkTextPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: HiPopColors.darkTextSecondary, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: HiPopColors.darkSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _selectDateTime(context, false),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HiPopColors.darkBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: HiPopColors.darkTextSecondary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'End Date & Time',
                              style: TextStyle(
                                color: HiPopColors.darkTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM d, yyyy - h:mm a').format(_endDateTime),
                              style: const TextStyle(
                                color: HiPopColors.darkTextPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: HiPopColors.darkTextSecondary, size: 16),
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

  Widget _buildLocationSelectionCard() {
    return Card(
      color: HiPopColors.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: HiPopColors.darkBorder.withOpacity( 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: HiPopColors.primaryDeepSage,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Update where your event will take place',
              style: TextStyle(
                fontSize: 13,
                color: HiPopColors.darkTextSecondary.withOpacity( 0.8),
              ),
            ),
            const SizedBox(height: 20),
            Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: HiPopColors.darkSurfaceVariant,
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
                        'Location updated: ${_selectedPlace!.formattedAddress}',
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
        ),
      ),
    );
  }

  Widget _buildPhotoUploadCard() {
    return Card(
      color: HiPopColors.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: HiPopColors.darkBorder.withOpacity( 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.photo_library,
                  color: HiPopColors.primaryDeepSage,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Event Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Update your event photo to attract more attendees',
              style: TextStyle(
                fontSize: 13,
                color: HiPopColors.darkTextSecondary.withOpacity( 0.8),
              ),
            ),
            const SizedBox(height: 20),
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
                onExistingPhotosChanged: (photos) {
                  setState(() {
                    _existingPhotos.clear();
                    _existingPhotos.addAll(photos);
                  });
                },
                initialImagePaths: _existingPhotos,
                maxPhotos: null, // Unlimited photos for events
                userId: context.read<AuthBloc>().state is Authenticated
                    ? (context.read<AuthBloc>().state as Authenticated).user.uid
                    : null,
                userType: 'organizer',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketAssociationCard() {
    return Card(
      color: HiPopColors.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: HiPopColors.darkBorder.withOpacity( 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.store,
                  color: HiPopColors.primaryDeepSage,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Market Association',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<Market>(
              value: _selectedMarket,
              dropdownColor: HiPopColors.darkSurfaceVariant,
              style: const TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Select Market (Optional)',
                labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                prefixIcon: const Icon(Icons.business, color: HiPopColors.darkTextSecondary),
                filled: true,
                fillColor: HiPopColors.darkSurfaceVariant,
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
              ),
              items: [
                const DropdownMenuItem<Market>(
                  value: null,
                  child: Text('No market association'),
                ),
                ..._availableMarkets.map((market) => DropdownMenuItem(
                  value: market,
                  child: Text(market.name),
                )),
              ],
              onChanged: (Market? value) {
                setState(() {
                  _selectedMarket = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalDetailsCard() {
    return Card(
      color: HiPopColors.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: HiPopColors.darkBorder.withOpacity( 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.tag,
                  color: HiPopColors.primaryDeepSage,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Additional Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _tagsController,
              style: const TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Event Tags',
                labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                hintText: 'e.g., festival, food, community',
                hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withOpacity( 0.5)),
                prefixIcon: const Icon(Icons.local_offer, color: HiPopColors.darkTextSecondary),
                helperText: 'Separate tags with commas',
                helperStyle: TextStyle(color: HiPopColors.darkTextSecondary.withOpacity( 0.7)),
                filled: true,
                fillColor: HiPopColors.darkSurfaceVariant,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialMediaCard() {
    return Card(
      color: HiPopColors.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: HiPopColors.darkBorder.withOpacity( 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.link,
                  color: HiPopColors.primaryDeepSage,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Event Links & Social Media',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Help vendors and shoppers learn more',
              style: TextStyle(
                fontSize: 13,
                color: HiPopColors.darkTextSecondary.withOpacity( 0.8),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _eventWebsiteController,
              style: const TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Event Website',
                labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                hintText: 'https://yourevent.com',
                hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withOpacity( 0.5)),
                prefixIcon: const Icon(Icons.language, color: HiPopColors.darkTextSecondary),
                filled: true,
                fillColor: HiPopColors.darkSurfaceVariant,
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
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _instagramController,
              style: const TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Instagram Handle',
                labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                hintText: 'yourevent',
                hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withOpacity( 0.5)),
                prefixIcon: const Icon(Icons.camera_alt, color: HiPopColors.darkTextSecondary),
                prefixText: '@',
                prefixStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                filled: true,
                fillColor: HiPopColors.darkSurfaceVariant,
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
              ),
              onChanged: (value) {
                if (value.startsWith('@')) {
                  _instagramController.text = value.substring(1);
                  _instagramController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _instagramController.text.length),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _facebookController,
              style: const TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Facebook Event URL',
                labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                hintText: 'https://facebook.com/events/...',
                hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withOpacity( 0.5)),
                prefixIcon: const Icon(Icons.facebook, color: HiPopColors.darkTextSecondary),
                filled: true,
                fillColor: HiPopColors.darkSurfaceVariant,
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
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ticketUrlController,
              style: const TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Ticket/Registration Link',
                labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                hintText: 'https://eventbrite.com/...',
                hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withOpacity( 0.5)),
                prefixIcon: const Icon(Icons.confirmation_number, color: HiPopColors.darkTextSecondary),
                helperText: 'Link for ticket purchase or event registration',
                helperStyle: TextStyle(color: HiPopColors.darkTextSecondary.withOpacity( 0.7)),
                filled: true,
                fillColor: HiPopColors.darkSurfaceVariant,
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
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
      ),
    );
  }

}