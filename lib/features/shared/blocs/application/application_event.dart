import 'package:equatable/equatable.dart';
import '../../models/vendor_application.dart';

/// Events for ApplicationBloc
/// Handles vendor application submission, payment, and organizer review actions
abstract class ApplicationEvent extends Equatable {
  const ApplicationEvent();

  @override
  List<Object?> get props => [];
}

// ============================================================================
// VENDOR EVENTS
// ============================================================================

/// Event to submit a new vendor application to a market
class SubmitApplicationEvent extends ApplicationEvent {
  final String marketId;
  final String description;
  final List<String> photoUrls;
  final Map<String, dynamic>? customResponses; // For custom form fields (Phase 2)

  const SubmitApplicationEvent({
    required this.marketId,
    required this.description,
    required this.photoUrls,
    this.customResponses,
  });

  @override
  List<Object?> get props => [marketId, description, photoUrls, customResponses];
}

/// Event to load all applications for a specific vendor
class LoadVendorApplicationsEvent extends ApplicationEvent {
  final String vendorId;

  const LoadVendorApplicationsEvent({required this.vendorId});

  @override
  List<Object?> get props => [vendorId];
}

/// Event to check if vendor has already applied to a market (duplicate prevention)
class CheckApplicationStatusEvent extends ApplicationEvent {
  final String vendorId;
  final String marketId;

  const CheckApplicationStatusEvent({
    required this.vendorId,
    required this.marketId,
  });

  @override
  List<Object?> get props => [vendorId, marketId];
}

/// Event to process payment for an approved application
class PayForApplicationEvent extends ApplicationEvent {
  final String applicationId;
  final String paymentIntentId;

  const PayForApplicationEvent({
    required this.applicationId,
    required this.paymentIntentId,
  });

  @override
  List<Object?> get props => [applicationId, paymentIntentId];
}

// ============================================================================
// ORGANIZER EVENTS
// ============================================================================

/// Event to load all applications for a specific market
class LoadMarketApplicationsEvent extends ApplicationEvent {
  final String marketId;
  final ApplicationStatus? filterStatus; // Optional filter by status

  const LoadMarketApplicationsEvent({
    required this.marketId,
    this.filterStatus,
  });

  @override
  List<Object?> get props => [marketId, filterStatus];
}

/// Event to approve a vendor application
class ApproveApplicationEvent extends ApplicationEvent {
  final String applicationId;

  const ApproveApplicationEvent({required this.applicationId});

  @override
  List<Object?> get props => [applicationId];
}

/// Event to deny a vendor application with optional note
class DenyApplicationEvent extends ApplicationEvent {
  final String applicationId;
  final String? denialNote;

  const DenyApplicationEvent({
    required this.applicationId,
    this.denialNote,
  });

  @override
  List<Object?> get props => [applicationId, denialNote];
}

// ============================================================================
// SYSTEM EVENTS
// ============================================================================

/// Event triggered when an application's status changes (from Firestore stream)
class ApplicationStatusChangedEvent extends ApplicationEvent {
  final VendorApplication application;

  const ApplicationStatusChangedEvent({required this.application});

  @override
  List<Object?> get props => [application];
}

/// Event triggered when an application payment window expires (24 hours)
class ApplicationExpiredEvent extends ApplicationEvent {
  final String applicationId;

  const ApplicationExpiredEvent({required this.applicationId});

  @override
  List<Object?> get props => [applicationId];
}

/// Event to refresh/reload current application data
class RefreshApplicationsEvent extends ApplicationEvent {
  const RefreshApplicationsEvent();
}
