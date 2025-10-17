import 'package:equatable/equatable.dart';
import '../../models/vendor_application.dart';

/// States for ApplicationBloc
/// Represents all possible states during vendor application lifecycle
abstract class ApplicationState extends Equatable {
  const ApplicationState();

  @override
  List<Object?> get props => [];
}

// ============================================================================
// INITIAL & LOADING STATES
// ============================================================================

/// Initial state when bloc is created
class ApplicationInitial extends ApplicationState {
  const ApplicationInitial();
}

/// Generic loading state
class ApplicationLoading extends ApplicationState {
  const ApplicationLoading();
}

// ============================================================================
// VENDOR STATES - Application Submission
// ============================================================================

/// State while submitting an application
class ApplicationSubmitting extends ApplicationState {
  const ApplicationSubmitting();
}

/// State after successfully submitting an application
class ApplicationSubmitted extends ApplicationState {
  final String applicationId;
  final VendorApplication application;

  const ApplicationSubmitted({
    required this.applicationId,
    required this.application,
  });

  @override
  List<Object?> get props => [applicationId, application];
}

/// State when application submission fails
class ApplicationSubmitError extends ApplicationState {
  final String error;

  const ApplicationSubmitError({required this.error});

  @override
  List<Object?> get props => [error];
}

/// State when vendor has already applied to this market (duplicate detected)
class ApplicationAlreadyExists extends ApplicationState {
  final VendorApplication existingApplication;

  const ApplicationAlreadyExists({required this.existingApplication});

  @override
  List<Object?> get props => [existingApplication];
}

// ============================================================================
// VENDOR STATES - Applications List
// ============================================================================

/// State with loaded vendor applications
class VendorApplicationsLoaded extends ApplicationState {
  final List<VendorApplication> applications;
  final int pendingCount;
  final int approvedCount;
  final int confirmedCount;
  final int deniedCount;

  const VendorApplicationsLoaded({
    required this.applications,
    required this.pendingCount,
    required this.approvedCount,
    required this.confirmedCount,
    required this.deniedCount,
  });

  @override
  List<Object?> get props => [
        applications,
        pendingCount,
        approvedCount,
        confirmedCount,
        deniedCount,
      ];

  /// Helper getters for filtered lists
  List<VendorApplication> get pendingApplications =>
      applications.where((a) => a.status == ApplicationStatus.pending).toList();

  List<VendorApplication> get approvedApplications =>
      applications.where((a) => a.status == ApplicationStatus.approved).toList();

  List<VendorApplication> get confirmedApplications =>
      applications.where((a) => a.status == ApplicationStatus.confirmed).toList();

  List<VendorApplication> get deniedApplications =>
      applications.where((a) => a.status == ApplicationStatus.denied).toList();

  /// Check if any applications need payment (approved but not paid)
  bool get hasPaymentRequired => approvedCount > 0;
}

// ============================================================================
// VENDOR STATES - Payment
// ============================================================================

/// State while processing payment for an application
class ApplicationPaymentProcessing extends ApplicationState {
  const ApplicationPaymentProcessing();
}

/// State after successful payment
class ApplicationPaymentSuccess extends ApplicationState {
  final VendorApplication application;

  const ApplicationPaymentSuccess({required this.application});

  @override
  List<Object?> get props => [application];
}

/// State when payment fails
class ApplicationPaymentError extends ApplicationState {
  final String error;
  final String? applicationId;

  const ApplicationPaymentError({
    required this.error,
    this.applicationId,
  });

  @override
  List<Object?> get props => [error, applicationId];
}

// ============================================================================
// ORGANIZER STATES - Applications Review
// ============================================================================

/// State with loaded market applications (for organizers)
class MarketApplicationsLoaded extends ApplicationState {
  final String marketId;
  final List<VendorApplication> applications;
  final int pendingCount;
  final int approvedCount;
  final int confirmedCount;
  final int deniedCount;
  final int spotsTotal;
  final int spotsRemaining;

  const MarketApplicationsLoaded({
    required this.marketId,
    required this.applications,
    required this.pendingCount,
    required this.approvedCount,
    required this.confirmedCount,
    required this.deniedCount,
    required this.spotsTotal,
    required this.spotsRemaining,
  });

  @override
  List<Object?> get props => [
        marketId,
        applications,
        pendingCount,
        approvedCount,
        confirmedCount,
        deniedCount,
        spotsTotal,
        spotsRemaining,
      ];

  /// Calculate fill percentage
  double get fillPercentage =>
      spotsTotal > 0 ? (spotsTotal - spotsRemaining) / spotsTotal : 0.0;

  /// Check if market is full
  bool get isFull => spotsRemaining <= 0;

  /// Helper getters for filtered lists
  List<VendorApplication> get pendingApplications =>
      applications.where((a) => a.status == ApplicationStatus.pending).toList();

  List<VendorApplication> get approvedApplications =>
      applications.where((a) => a.status == ApplicationStatus.approved).toList();

  List<VendorApplication> get confirmedApplications =>
      applications.where((a) => a.status == ApplicationStatus.confirmed).toList();

  List<VendorApplication> get deniedApplications =>
      applications.where((a) => a.status == ApplicationStatus.denied).toList();
}

// ============================================================================
// ORGANIZER STATES - Approval Actions
// ============================================================================

/// State while approving an application
class ApplicationApproving extends ApplicationState {
  const ApplicationApproving();
}

/// State after successfully approving an application
class ApplicationApproved extends ApplicationState {
  final VendorApplication application;

  const ApplicationApproved({required this.application});

  @override
  List<Object?> get props => [application];
}

/// State while denying an application
class ApplicationDenying extends ApplicationState {
  const ApplicationDenying();
}

/// State after successfully denying an application
class ApplicationDenied extends ApplicationState {
  final VendorApplication application;

  const ApplicationDenied({required this.application});

  @override
  List<Object?> get props => [application];
}

/// State when approve/deny action fails
class ApplicationActionError extends ApplicationState {
  final String error;
  final String? applicationId;

  const ApplicationActionError({
    required this.error,
    this.applicationId,
  });

  @override
  List<Object?> get props => [error, applicationId];
}

// ============================================================================
// REAL-TIME UPDATE STATES
// ============================================================================

/// State when an application's status is updated in real-time
class ApplicationStatusUpdated extends ApplicationState {
  final VendorApplication application;
  final ApplicationStatus oldStatus;
  final ApplicationStatus newStatus;

  const ApplicationStatusUpdated({
    required this.application,
    required this.oldStatus,
    required this.newStatus,
  });

  @override
  List<Object?> get props => [application, oldStatus, newStatus];
}

/// State when an application expires (24hr payment window passed)
class ApplicationExpired extends ApplicationState {
  final String applicationId;
  final VendorApplication? application;

  const ApplicationExpired({
    required this.applicationId,
    this.application,
  });

  @override
  List<Object?> get props => [applicationId, application];
}
