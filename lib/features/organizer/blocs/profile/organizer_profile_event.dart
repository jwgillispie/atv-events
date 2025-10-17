import 'dart:io';
import 'package:equatable/equatable.dart';

/// Abstract base class for all organizer profile events
abstract class OrganizerProfileEvent extends Equatable {
  const OrganizerProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load an organizer's profile
/// 
/// If [userId] is not provided, loads the current user's profile.
/// This event triggers fetching the profile from the repository
/// and sets up a stream subscription for real-time updates.
class LoadOrganizerProfile extends OrganizerProfileEvent {
  final String? userId;

  const LoadOrganizerProfile({this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Event to refresh the organizer's profile data
/// 
/// Triggered when profile data changes are detected or
/// when manual refresh is requested by the user.
class RefreshOrganizerProfile extends OrganizerProfileEvent {
  const RefreshOrganizerProfile();
}

/// Event to update organizer profile information
/// 
/// All fields are optional - only provided fields will be updated.
/// This maintains existing data for fields not included in the update.
class UpdateOrganizerProfile extends OrganizerProfileEvent {
  final String? displayName;
  final String? businessName;
  final String? organizationName;
  final String? bio;
  final String? instagramHandle;
  final String? website;
  final String? phoneNumber;

  const UpdateOrganizerProfile({
    this.displayName,
    this.businessName,
    this.organizationName,
    this.bio,
    this.instagramHandle,
    this.website,
    this.phoneNumber,
  });

  @override
  List<Object?> get props => [
        displayName,
        businessName,
        organizationName,
        bio,
        instagramHandle,
        website,
        phoneNumber,
      ];
}

/// Event to upload a new profile photo
/// 
/// Takes a [File] containing the image to upload.
/// The photo will be compressed and uploaded to Firebase Storage,
/// and the profile will be updated with the new photo URL.
class UploadProfilePhoto extends OrganizerProfileEvent {
  final File photo;

  const UploadProfilePhoto(this.photo);

  @override
  List<Object?> get props => [photo];
}

/// Event to remove the current profile photo
/// 
/// Deletes the photo from Firebase Storage and removes
/// the photo URL from the user's profile.
class RemoveProfilePhoto extends OrganizerProfileEvent {
  const RemoveProfilePhoto();
}

/// Event to check the user's premium subscription status
/// 
/// Verifies if the user has an active premium subscription
/// and updates the state accordingly.
class CheckPremiumStatus extends OrganizerProfileEvent {
  const CheckPremiumStatus();
}

/// Event to validate a specific profile field
/// 
/// Used for real-time validation during form input.
/// [fieldName] identifies the field to validate.
/// [value] is the current value to validate.
class ValidateProfileField extends OrganizerProfileEvent {
  final String fieldName;
  final String value;

  const ValidateProfileField({
    required this.fieldName,
    required this.value,
  });

  @override
  List<Object?> get props => [fieldName, value];
}

/// Event to clear any error messages in the state
/// 
/// Used to reset error state after the user has acknowledged
/// or when navigating away from error conditions.
class ClearProfileError extends OrganizerProfileEvent {
  const ClearProfileError();
}

/// Event to ensure a profile exists for the current user
/// 
/// Creates a new profile if one doesn't exist, or returns
/// the existing profile. Used during onboarding flow.
class EnsureOrganizerProfile extends OrganizerProfileEvent {
  final String? displayName;

  const EnsureOrganizerProfile({this.displayName});

  @override
  List<Object?> get props => [displayName];
}