import 'package:equatable/equatable.dart';

/// Model for organizer profile updates
/// 
/// Used to validate and structure profile update requests
/// before sending them to the BLoC or repository.
class OrganizerProfileUpdateModel extends Equatable {
  final String? displayName;
  final String? organizationName;
  final String? businessName;
  final String? bio;
  final String? instagramHandle;
  final String? website;
  final String? phoneNumber;

  const OrganizerProfileUpdateModel({
    this.displayName,
    this.organizationName,
    this.businessName,
    this.bio,
    this.instagramHandle,
    this.website,
    this.phoneNumber,
  });

  /// Create from form data (typically from TextEditingControllers)
  factory OrganizerProfileUpdateModel.fromFormData({
    String? displayName,
    String? organizationName,
    String? businessName,
    String? bio,
    String? instagramHandle,
    String? website,
    String? phoneNumber,
  }) {
    // Clean and normalize input data
    return OrganizerProfileUpdateModel(
      displayName: _cleanString(displayName),
      organizationName: _cleanString(organizationName),
      businessName: _cleanString(businessName),
      bio: _cleanString(bio),
      instagramHandle: _cleanInstagramHandle(instagramHandle),
      website: _cleanWebsite(website),
      phoneNumber: _cleanPhoneNumber(phoneNumber),
    );
  }

  /// Check if the model has any updates
  bool get hasUpdates {
    return displayName != null ||
        organizationName != null ||
        businessName != null ||
        bio != null ||
        instagramHandle != null ||
        website != null ||
        phoneNumber != null;
  }

  /// Get the count of fields to be updated
  int get updateCount {
    int count = 0;
    if (displayName != null) count++;
    if (organizationName != null) count++;
    if (businessName != null) count++;
    if (bio != null) count++;
    if (instagramHandle != null) count++;
    if (website != null) count++;
    if (phoneNumber != null) count++;
    return count;
  }

  /// Validate all fields and return errors
  Map<String, String> validate() {
    final errors = <String, String>{};

    // Validate display name
    if (displayName != null) {
      if (displayName!.isEmpty) {
        errors['displayName'] = 'Display name cannot be empty';
      } else if (displayName!.length < 2) {
        errors['displayName'] = 'Display name must be at least 2 characters';
      } else if (displayName!.length > 50) {
        errors['displayName'] = 'Display name must be less than 50 characters';
      }
    }

    // Validate organization name
    if (organizationName != null && organizationName!.isNotEmpty) {
      if (organizationName!.length < 2) {
        errors['organizationName'] = 'Organization name must be at least 2 characters';
      } else if (organizationName!.length > 100) {
        errors['organizationName'] = 'Organization name must be less than 100 characters';
      }
    }

    // Validate business name
    if (businessName != null && businessName!.isNotEmpty) {
      if (businessName!.length < 2) {
        errors['businessName'] = 'Business name must be at least 2 characters';
      } else if (businessName!.length > 100) {
        errors['businessName'] = 'Business name must be less than 100 characters';
      }
    }

    // Validate bio
    if (bio != null && bio!.length > 500) {
      errors['bio'] = 'Bio must be less than 500 characters';
    }

    // Validate Instagram handle
    if (instagramHandle != null && instagramHandle!.isNotEmpty) {
      if (!_isValidInstagramHandle(instagramHandle!)) {
        errors['instagramHandle'] = 'Please enter a valid Instagram handle';
      }
    }

    // Validate website
    if (website != null && website!.isNotEmpty) {
      if (!_isValidWebsite(website!)) {
        errors['website'] = 'Please enter a valid website URL';
      }
    }

    // Validate phone number
    if (phoneNumber != null && phoneNumber!.isNotEmpty) {
      if (!_isValidPhoneNumber(phoneNumber!)) {
        errors['phoneNumber'] = 'Please enter a valid phone number';
      }
    }

    return errors;
  }

  /// Check if all fields are valid
  bool get isValid => validate().isEmpty;

  /// Create a copy with updated fields
  OrganizerProfileUpdateModel copyWith({
    String? displayName,
    String? organizationName,
    String? businessName,
    String? bio,
    String? instagramHandle,
    String? website,
    String? phoneNumber,
  }) {
    return OrganizerProfileUpdateModel(
      displayName: displayName ?? this.displayName,
      organizationName: organizationName ?? this.organizationName,
      businessName: businessName ?? this.businessName,
      bio: bio ?? this.bio,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      website: website ?? this.website,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  /// Convert to a map for easy serialization
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    
    if (displayName != null) map['displayName'] = displayName;
    if (organizationName != null) map['organizationName'] = organizationName;
    if (businessName != null) map['businessName'] = businessName;
    if (bio != null) map['bio'] = bio;
    if (instagramHandle != null) map['instagramHandle'] = instagramHandle;
    if (website != null) map['website'] = website;
    if (phoneNumber != null) map['phoneNumber'] = phoneNumber;
    
    return map;
  }

  @override
  List<Object?> get props => [
        displayName,
        organizationName,
        businessName,
        bio,
        instagramHandle,
        website,
        phoneNumber,
      ];

  // Private helper methods

  /// Clean and trim a string, returning null if empty
  static String? _cleanString(String? value) {
    if (value == null) return null;
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  /// Clean and format Instagram handle
  static String? _cleanInstagramHandle(String? value) {
    if (value == null) return null;
    var cleaned = value.trim();
    if (cleaned.isEmpty) return null;
    
    // Remove @ if present at the start
    if (cleaned.startsWith('@')) {
      cleaned = cleaned.substring(1);
    }
    
    // Remove instagram.com URL if pasted
    if (cleaned.contains('instagram.com/')) {
      final parts = cleaned.split('instagram.com/');
      if (parts.length > 1) {
        cleaned = parts[1].split('/')[0].split('?')[0];
      }
    }
    
    return cleaned.isEmpty ? null : cleaned;
  }

  /// Clean and format website URL
  static String? _cleanWebsite(String? value) {
    if (value == null) return null;
    var cleaned = value.trim();
    if (cleaned.isEmpty) return null;
    
    // Add https:// if no protocol specified
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      cleaned = 'https://$cleaned';
    }
    
    return cleaned;
  }

  /// Clean and format phone number
  static String? _cleanPhoneNumber(String? value) {
    if (value == null) return null;
    final cleaned = value.trim();
    if (cleaned.isEmpty) return null;
    
    // Keep the original format but validate it
    return cleaned;
  }

  /// Validate Instagram handle format
  static bool _isValidInstagramHandle(String handle) {
    // Instagram handles: 1-30 characters, letters, numbers, periods, underscores
    final regex = RegExp(r'^[a-zA-Z0-9_.]{1,30}$');
    return regex.hasMatch(handle);
  }

  /// Validate website URL format
  static bool _isValidWebsite(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Validate phone number format (US/International)
  static bool _isValidPhoneNumber(String phone) {
    // Remove all non-digit characters except +
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Check for valid patterns:
    // US: 10 digits, optionally with country code
    // International: 7-15 digits, optionally with +
    final regex = RegExp(r'^\+?[1-9]\d{6,14}$');
    return regex.hasMatch(digitsOnly);
  }
}

/// Extension methods for validation
extension ValidationExtensions on String {
  /// Check if the string is a valid email
  bool get isValidEmail {
    final regex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return regex.hasMatch(this);
  }

  /// Check if the string contains only letters and spaces
  bool get isAlphaWithSpaces {
    final regex = RegExp(r'^[a-zA-Z\s]+$');
    return regex.hasMatch(this);
  }

  /// Check if the string is a valid URL
  bool get isValidUrl {
    try {
      final uri = Uri.parse(this);
      return uri.isAbsolute;
    } catch (e) {
      return false;
    }
  }

  /// Sanitize string for display
  String get sanitized {
    return trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}