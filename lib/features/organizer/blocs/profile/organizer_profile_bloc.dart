import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../blocs/auth/auth_bloc.dart';
import '../../../../blocs/auth/auth_state.dart';
import '../../../../repositories/organizer/organizer_profile_repository.dart';
import '../../../shared/models/user_profile.dart';
import 'organizer_profile_event.dart';
import 'organizer_profile_state.dart';

/// BLoC for managing organizer profile state and operations
/// 
/// Handles loading, updating, and managing organizer profiles with
/// proper separation of concerns, caching, and error handling.
class OrganizerProfileBloc extends Bloc<OrganizerProfileEvent, OrganizerProfileState> {
  final IOrganizerProfileRepository _repository;
  final AuthBloc _authBloc;
  
  StreamSubscription<UserProfile?>? _profileSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  
  String? _currentUserId;

  OrganizerProfileBloc({
    required IOrganizerProfileRepository repository,
    required AuthBloc authBloc,
  })  : _repository = repository,
        _authBloc = authBloc,
        super(const OrganizerProfileState()) {
    
    // Register event handlers
    on<LoadOrganizerProfile>(_onLoadProfile);
    on<RefreshOrganizerProfile>(_onRefreshProfile);
    on<UpdateOrganizerProfile>(_onUpdateProfile);
    on<UploadProfilePhoto>(_onUploadPhoto);
    on<RemoveProfilePhoto>(_onRemovePhoto);
    on<CheckPremiumStatus>(_onCheckPremium);
    on<ValidateProfileField>(_onValidateField);
    on<ClearProfileError>(_onClearError);
    on<EnsureOrganizerProfile>(_onEnsureProfile);
    
    // Listen to auth state changes
    _authSubscription = _authBloc.stream.listen(_handleAuthStateChange);
    
    // Check initial auth state
    _handleAuthStateChange(_authBloc.state);
  }

  /// Handle auth state changes
  void _handleAuthStateChange(AuthState authState) {
    if (authState is Authenticated && authState.userType == 'market_organizer') {
      // Auto-load profile when authenticated as organizer
      if (_currentUserId != authState.user.uid) {
        _currentUserId = authState.user.uid;
        add(LoadOrganizerProfile(userId: authState.user.uid));
      }
    } else if (authState is Unauthenticated) {
      // Clear profile when logged out
      _currentUserId = null;
      _profileSubscription?.cancel();
      // Use add event to clear state instead of direct emit
      add(const ClearProfileError());
    }
  }

  /// Handler for LoadOrganizerProfile event
  Future<void> _onLoadProfile(
    LoadOrganizerProfile event,
    Emitter<OrganizerProfileState> emit,
  ) async {
    // Don't show loading if we already have data (refresh case)
    if (state.profile == null) {
      emit(state.copyWith(
        status: OrganizerProfileStatus.loading,
        clearError: true,
      ));
    }

    try {
      // Get user ID from event or current auth state
      final authState = _authBloc.state;
      if (authState is! Authenticated) {
        throw Exception('User not authenticated');
      }

      final userId = event.userId ?? authState.user.uid;
      _currentUserId = userId;

      // Load profile from repository
      final profile = await _repository.getUserProfile(userId);
      
      if (profile == null) {
        // Create profile if it doesn't exist for market organizers
        if (authState.userType == 'market_organizer') {
          final newProfile = await _repository.ensureUserProfile(
            userId: userId,
            userType: 'market_organizer',
          );
          
          emit(state.copyWith(
            status: OrganizerProfileStatus.loaded,
            profile: newProfile,
          ));
        } else {
          emit(state.copyWith(
            status: OrganizerProfileStatus.error,
            errorMessage: 'Profile not found',
          ));
        }
      } else {
        // Check premium status
        final hasPremium = await _repository.checkPremiumAccess(userId);
        
        emit(state.copyWith(
          status: OrganizerProfileStatus.loaded,
          profile: profile,
          hasPremiumAccess: hasPremium,
        ));
      }

      // Set up profile stream subscription for real-time updates
      _profileSubscription?.cancel();
      _profileSubscription = _repository.streamUserProfile(userId).listen(
        (updatedProfile) {
          if (updatedProfile != null && !isClosed) {
            // Only emit if profile has actually changed
            if (state.profile != updatedProfile) {
              emit(state.copyWith(
                profile: updatedProfile,
                status: OrganizerProfileStatus.loaded,
              ));
            }
          }
        },
        onError: (error) {
          if (!isClosed) {
            emit(state.copyWith(
              status: OrganizerProfileStatus.error,
              errorMessage: 'Failed to sync profile: ${error.toString()}',
            ));
          }
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: OrganizerProfileStatus.error,
        errorMessage: 'Failed to load profile: ${e.toString()}',
      ));
    }
  }

  /// Handler for RefreshOrganizerProfile event
  Future<void> _onRefreshProfile(
    RefreshOrganizerProfile event,
    Emitter<OrganizerProfileState> emit,
  ) async {
    if (_currentUserId != null) {
      // Force reload from repository (bypasses cache)
      await _repository.invalidateCache(_currentUserId!);
      add(LoadOrganizerProfile(userId: _currentUserId));
    }
  }

  /// Handler for UpdateOrganizerProfile event
  Future<void> _onUpdateProfile(
    UpdateOrganizerProfile event,
    Emitter<OrganizerProfileState> emit,
  ) async {
    if (state.profile == null) {
      emit(state.copyWith(
        status: OrganizerProfileStatus.error,
        errorMessage: 'No profile loaded',
      ));
      return;
    }

    emit(state.copyWith(
      status: OrganizerProfileStatus.updating,
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    ));

    try {
      // Validate fields before updating
      final fieldErrors = _validateProfileUpdate(event);
      if (fieldErrors.isNotEmpty) {
        emit(state.copyWith(
          status: OrganizerProfileStatus.loaded,
          fieldErrors: fieldErrors,
          isSaving: false,
        ));
        return;
      }

      // Create updated profile with only changed fields
      UserProfile updatedProfile = state.profile!;
      
      if (event.displayName != null) {
        updatedProfile = updatedProfile.copyWith(displayName: event.displayName);
      }
      if (event.organizationName != null) {
        updatedProfile = updatedProfile.copyWith(organizationName: event.organizationName);
      }
      if (event.businessName != null) {
        updatedProfile = updatedProfile.copyWith(businessName: event.businessName);
      }
      if (event.bio != null) {
        updatedProfile = updatedProfile.copyWith(bio: event.bio);
      }
      if (event.instagramHandle != null) {
        updatedProfile = updatedProfile.copyWith(instagramHandle: event.instagramHandle);
      }
      if (event.website != null) {
        updatedProfile = updatedProfile.copyWith(website: event.website);
      }
      if (event.phoneNumber != null) {
        updatedProfile = updatedProfile.copyWith(phoneNumber: event.phoneNumber);
      }

      // Save to repository
      final savedProfile = await _repository.updateUserProfile(updatedProfile);

      emit(state.copyWith(
        status: OrganizerProfileStatus.loaded,
        profile: savedProfile,
        isSaving: false,
        successMessage: 'Profile updated successfully',
        fieldErrors: const {},
      ));
    } catch (e) {
      emit(state.copyWith(
        status: OrganizerProfileStatus.error,
        errorMessage: 'Failed to update profile: ${e.toString()}',
        isSaving: false,
      ));
    }
  }

  /// Handler for UploadProfilePhoto event
  Future<void> _onUploadPhoto(
    UploadProfilePhoto event,
    Emitter<OrganizerProfileState> emit,
  ) async {
    if (state.profile == null) {
      emit(state.copyWith(
        status: OrganizerProfileStatus.error,
        errorMessage: 'No profile loaded',
      ));
      return;
    }

    emit(state.copyWith(
      status: OrganizerProfileStatus.photoUploading,
      uploadProgress: 0.0,
      clearError: true,
    ));

    try {
      // Upload photo and get URL
      await _repository.uploadProfilePhoto(
        state.profile!.userId,
        event.photo,
        onProgress: (progress) {
          if (!isClosed) {
            emit(state.copyWith(
              uploadProgress: progress,
            ));
          }
        },
      );

      // The photo URL is automatically updated in the profile via the repository
      // The stream subscription will receive the updated profile
      
      emit(state.copyWith(
        status: OrganizerProfileStatus.loaded,
        uploadProgress: null,
        successMessage: 'Photo uploaded successfully',
      ));
      
      // Refresh profile to get updated data
      add(const RefreshOrganizerProfile());
    } catch (e) {
      emit(state.copyWith(
        status: OrganizerProfileStatus.error,
        errorMessage: 'Failed to upload photo: ${e.toString()}',
        uploadProgress: null,
      ));
    }
  }

  /// Handler for RemoveProfilePhoto event
  Future<void> _onRemovePhoto(
    RemoveProfilePhoto event,
    Emitter<OrganizerProfileState> emit,
  ) async {
    if (state.profile == null) {
      emit(state.copyWith(
        status: OrganizerProfileStatus.error,
        errorMessage: 'No profile loaded',
      ));
      return;
    }

    emit(state.copyWith(
      status: OrganizerProfileStatus.updating,
      clearError: true,
    ));

    try {
      await _repository.deleteProfilePhoto(state.profile!.userId);
      
      emit(state.copyWith(
        status: OrganizerProfileStatus.loaded,
        successMessage: 'Photo removed successfully',
      ));
      
      // Refresh profile to get updated data
      add(const RefreshOrganizerProfile());
    } catch (e) {
      emit(state.copyWith(
        status: OrganizerProfileStatus.error,
        errorMessage: 'Failed to remove photo: ${e.toString()}',
      ));
    }
  }

  /// Handler for CheckPremiumStatus event
  Future<void> _onCheckPremium(
    CheckPremiumStatus event,
    Emitter<OrganizerProfileState> emit,
  ) async {
    if (state.profile == null) return;

    try {
      final hasPremium = await _repository.checkPremiumAccess(state.profile!.userId);
      
      emit(state.copyWith(
        hasPremiumAccess: hasPremium,
      ));
    } catch (e) {
      // Silently fail - premium status is not critical
    }
  }

  /// Handler for ValidateProfileField event
  Future<void> _onValidateField(
    ValidateProfileField event,
    Emitter<OrganizerProfileState> emit,
  ) async {
    final fieldErrors = Map<String, String>.from(state.fieldErrors);
    
    // Validate the specific field
    final error = _validateField(event.fieldName, event.value);
    
    if (error != null) {
      fieldErrors[event.fieldName] = error;
    } else {
      fieldErrors.remove(event.fieldName);
    }
    
    emit(state.copyWith(
      fieldErrors: fieldErrors,
    ));
  }

  /// Handler for ClearProfileError event
  Future<void> _onClearError(
    ClearProfileError event,
    Emitter<OrganizerProfileState> emit,
  ) async {
    emit(state.copyWith(
      clearError: true,
      clearSuccess: true,
      fieldErrors: const {},
    ));
  }

  /// Handler for EnsureOrganizerProfile event
  Future<void> _onEnsureProfile(
    EnsureOrganizerProfile event,
    Emitter<OrganizerProfileState> emit,
  ) async {
    emit(state.copyWith(
      status: OrganizerProfileStatus.loading,
      clearError: true,
    ));

    try {
      final authState = _authBloc.state;
      if (authState is! Authenticated) {
        throw Exception('User not authenticated');
      }

      final profile = await _repository.ensureUserProfile(
        userId: authState.user.uid,
        userType: 'market_organizer',
        displayName: event.displayName,
      );

      emit(state.copyWith(
        status: OrganizerProfileStatus.loaded,
        profile: profile,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: OrganizerProfileStatus.error,
        errorMessage: 'Failed to ensure profile: ${e.toString()}',
      ));
    }
  }

  /// Validate profile update fields
  Map<String, String> _validateProfileUpdate(UpdateOrganizerProfile event) {
    final errors = <String, String>{};
    
    if (event.displayName != null) {
      final error = _validateField('displayName', event.displayName!);
      if (error != null) errors['displayName'] = error;
    }
    
    if (event.organizationName != null) {
      final error = _validateField('organizationName', event.organizationName!);
      if (error != null) errors['organizationName'] = error;
    }
    
    if (event.website != null) {
      final error = _validateField('website', event.website!);
      if (error != null) errors['website'] = error;
    }
    
    if (event.phoneNumber != null) {
      final error = _validateField('phoneNumber', event.phoneNumber!);
      if (error != null) errors['phoneNumber'] = error;
    }
    
    if (event.instagramHandle != null) {
      final error = _validateField('instagramHandle', event.instagramHandle!);
      if (error != null) errors['instagramHandle'] = error;
    }
    
    return errors;
  }

  /// Validate a single field
  String? _validateField(String fieldName, String value) {
    switch (fieldName) {
      case 'displayName':
        if (value.trim().isEmpty) {
          return 'Display name is required';
        }
        if (value.trim().length < 2) {
          return 'Display name must be at least 2 characters';
        }
        if (value.trim().length > 50) {
          return 'Display name must be less than 50 characters';
        }
        break;
        
      case 'organizationName':
        if (value.trim().isNotEmpty && value.trim().length < 2) {
          return 'Organization name must be at least 2 characters';
        }
        if (value.trim().length > 100) {
          return 'Organization name must be less than 100 characters';
        }
        break;
        
      case 'website':
        if (value.trim().isNotEmpty) {
          // Basic URL validation
          final urlPattern = RegExp(
            r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
            caseSensitive: false,
          );
          if (!urlPattern.hasMatch(value.trim())) {
            return 'Please enter a valid website URL';
          }
        }
        break;
        
      case 'phoneNumber':
        if (value.trim().isNotEmpty) {
          // Basic phone validation (US format)
          final phonePattern = RegExp(r'^\+?1?\d{10,14}$');
          final cleaned = value.replaceAll(RegExp(r'[^\d+]'), '');
          if (!phonePattern.hasMatch(cleaned)) {
            return 'Please enter a valid phone number';
          }
        }
        break;
        
      case 'instagramHandle':
        if (value.trim().isNotEmpty) {
          // Instagram handle validation
          final handlePattern = RegExp(r'^@?[a-zA-Z0-9_.]{1,30}$');
          if (!handlePattern.hasMatch(value.trim())) {
            return 'Please enter a valid Instagram handle';
          }
        }
        break;
        
      case 'bio':
        if (value.length > 500) {
          return 'Bio must be less than 500 characters';
        }
        break;
    }
    
    return null;
  }

  @override
  Future<void> close() {
    _profileSubscription?.cancel();
    _authSubscription?.cancel();
    return super.close();
  }
}