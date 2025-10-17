import 'package:equatable/equatable.dart';
import '../../../shared/models/user_profile.dart';

/// Status enum for tracking the state of profile operations
enum OrganizerProfileStatus {
  /// Initial state before any data is loaded
  initial,
  
  /// Currently loading profile data from repository
  loading,
  
  /// Profile data successfully loaded and ready
  loaded,
  
  /// Currently updating profile data
  updating,
  
  /// An error occurred during profile operations
  error,
  
  /// Currently uploading a profile photo
  photoUploading,
}

/// State class for the Organizer Profile BLoC
/// 
/// Contains all data needed to render the organizer profile UI,
/// including the profile data, loading states, error messages,
/// and validation feedback.
class OrganizerProfileState extends Equatable {
  /// Current status of profile operations
  final OrganizerProfileStatus status;
  
  /// The loaded user profile data
  final UserProfile? profile;
  
  /// Whether the user has premium access
  final bool hasPremiumAccess;
  
  /// Error message for general errors
  final String? errorMessage;
  
  /// Field-specific validation errors
  /// Key: field name, Value: error message
  final Map<String, String> fieldErrors;
  
  /// Whether a save operation is in progress
  final bool isSaving;
  
  /// Progress of photo upload (0.0 to 1.0)
  final double? uploadProgress;
  
  /// Success message to display after operations
  final String? successMessage;

  const OrganizerProfileState({
    this.status = OrganizerProfileStatus.initial,
    this.profile,
    this.hasPremiumAccess = false,
    this.errorMessage,
    this.fieldErrors = const {},
    this.isSaving = false,
    this.uploadProgress,
    this.successMessage,
  });

  /// Creates a copy of the state with updated fields
  /// 
  /// Only provided fields are updated, others retain their current values.
  /// Note: [errorMessage] and [successMessage] are explicitly nullable
  /// to allow clearing these messages by passing null.
  OrganizerProfileState copyWith({
    OrganizerProfileStatus? status,
    UserProfile? profile,
    bool? hasPremiumAccess,
    String? errorMessage,
    Map<String, String>? fieldErrors,
    bool? isSaving,
    double? uploadProgress,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return OrganizerProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      hasPremiumAccess: hasPremiumAccess ?? this.hasPremiumAccess,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      fieldErrors: fieldErrors ?? this.fieldErrors,
      isSaving: isSaving ?? this.isSaving,
      uploadProgress: uploadProgress,
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  /// Helper method to check if profile is being loaded for the first time
  bool get isInitialLoading => status == OrganizerProfileStatus.loading && profile == null;
  
  /// Helper method to check if data is being refreshed
  bool get isRefreshing => status == OrganizerProfileStatus.loading && profile != null;
  
  /// Helper method to check if any operation is in progress
  bool get isProcessing => 
      status == OrganizerProfileStatus.loading ||
      status == OrganizerProfileStatus.updating ||
      status == OrganizerProfileStatus.photoUploading ||
      isSaving;
  
  /// Helper method to check if profile is ready for display
  bool get isReady => status == OrganizerProfileStatus.loaded && profile != null;
  
  /// Helper method to check if there are any field validation errors
  bool get hasFieldErrors => fieldErrors.isNotEmpty;
  
  /// Helper method to get error message for a specific field
  String? getFieldError(String fieldName) => fieldErrors[fieldName];
  
  /// Helper method to check if a specific field has an error
  bool hasFieldError(String fieldName) => fieldErrors.containsKey(fieldName);

  @override
  List<Object?> get props => [
        status,
        profile,
        hasPremiumAccess,
        errorMessage,
        fieldErrors,
        isSaving,
        uploadProgress,
        successMessage,
      ];

  @override
  String toString() {
    return '''OrganizerProfileState(
      status: $status, 
      hasProfile: ${profile != null},
      hasPremiumAccess: $hasPremiumAccess, 
      hasError: ${errorMessage != null},
      fieldErrorCount: ${fieldErrors.length},
      isSaving: $isSaving,
      uploadProgress: $uploadProgress
    )''';
  }
}