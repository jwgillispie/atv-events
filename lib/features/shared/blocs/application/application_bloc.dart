import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'application_event.dart';
import 'application_state.dart';
import '../../models/vendor_application.dart';
import '../../services/applications/vendor_application_service.dart';
import '../../services/applications/application_payment_service.dart';

/// BLoC for managing vendor applications
/// Handles submission, review, payment, and real-time updates
class ApplicationBloc extends Bloc<ApplicationEvent, ApplicationState> {
  final VendorApplicationService _applicationService;
  final ApplicationPaymentService _paymentService;

  // Stream subscriptions for real-time updates
  StreamSubscription<List<VendorApplication>>? _applicationsSubscription;

  ApplicationBloc({
    required VendorApplicationService applicationService,
    required ApplicationPaymentService paymentService,
  })  : _applicationService = applicationService,
        _paymentService = paymentService,
        super(const ApplicationInitial()) {
    // Register event handlers
    on<SubmitApplicationEvent>(_onSubmitApplication);
    on<LoadVendorApplicationsEvent>(_onLoadVendorApplications);
    on<CheckApplicationStatusEvent>(_onCheckApplicationStatus);
    on<PayForApplicationEvent>(_onPayForApplication);
    on<LoadMarketApplicationsEvent>(_onLoadMarketApplications);
    on<ApproveApplicationEvent>(_onApproveApplication);
    on<DenyApplicationEvent>(_onDenyApplication);
    on<ApplicationStatusChangedEvent>(_onApplicationStatusChanged);
    on<ApplicationExpiredEvent>(_onApplicationExpired);
    on<RefreshApplicationsEvent>(_onRefreshApplications);
  }

  // ==========================================================================
  // VENDOR EVENT HANDLERS
  // ==========================================================================

  /// Handle vendor submitting an application
  Future<void> _onSubmitApplication(
    SubmitApplicationEvent event,
    Emitter<ApplicationState> emit,
  ) async {
    emit(const ApplicationSubmitting());

    try {
      // Check for duplicate application first
      final existingApp = await _applicationService.getExistingApplication(
        event.marketId,
        event.marketId, // TODO: Get vendorId from auth
      );

      if (existingApp != null) {
        emit(ApplicationAlreadyExists(existingApplication: existingApp));
        return;
      }

      // Submit new application
      final applicationId = await _applicationService.submitApplication(
        marketId: event.marketId,
        description: event.description,
        photoUrls: event.photoUrls,
        customResponses: event.customResponses,
      );

      // Get the created application
      final application = await _applicationService.getApplication(applicationId);

      if (application != null) {
        emit(ApplicationSubmitted(
          applicationId: applicationId,
          application: application,
        ));
      } else {
        emit(const ApplicationSubmitError(
          error: 'Application submitted but could not be retrieved',
        ));
      }
    } catch (e) {
      emit(ApplicationSubmitError(error: e.toString()));
    }
  }

  /// Handle loading vendor's applications with real-time updates
  Future<void> _onLoadVendorApplications(
    LoadVendorApplicationsEvent event,
    Emitter<ApplicationState> emit,
  ) async {
    emit(const ApplicationLoading());

    try {
      // Cancel previous subscription
      await _applicationsSubscription?.cancel();

      // Use emit.forEach for proper stream handling in BLoC
      await emit.forEach<List<VendorApplication>>(
        _applicationService.getVendorApplications(event.vendorId),
        onData: (applications) {
          // Count by status
          final pendingCount =
              applications.where((a) => a.status == ApplicationStatus.pending).length;
          final approvedCount =
              applications.where((a) => a.status == ApplicationStatus.approved).length;
          final confirmedCount =
              applications.where((a) => a.status == ApplicationStatus.confirmed).length;
          final deniedCount =
              applications.where((a) => a.status == ApplicationStatus.denied).length;

          return VendorApplicationsLoaded(
            applications: applications,
            pendingCount: pendingCount,
            approvedCount: approvedCount,
            confirmedCount: confirmedCount,
            deniedCount: deniedCount,
          );
        },
        onError: (error, stackTrace) {
          return ApplicationSubmitError(
            error: 'Failed to load applications: ${error.toString()}',
          );
        },
      );
    } catch (e) {
      emit(ApplicationSubmitError(error: 'Failed to load applications: ${e.toString()}'));
    }
  }

  /// Handle checking if vendor has already applied (duplicate prevention)
  Future<void> _onCheckApplicationStatus(
    CheckApplicationStatusEvent event,
    Emitter<ApplicationState> emit,
  ) async {
    emit(const ApplicationLoading());

    try {
      final existingApp = await _applicationService.getExistingApplication(
        event.vendorId,
        event.marketId,
      );

      if (existingApp != null) {
        emit(ApplicationAlreadyExists(existingApplication: existingApp));
      } else {
        emit(const ApplicationInitial());
      }
    } catch (e) {
      emit(ApplicationSubmitError(error: e.toString()));
    }
  }

  /// Handle vendor paying for approved application
  Future<void> _onPayForApplication(
    PayForApplicationEvent event,
    Emitter<ApplicationState> emit,
  ) async {
    emit(const ApplicationPaymentProcessing());

    try {
      // Validate payment eligibility first
      final validation = await _paymentService.validatePaymentEligibility(
        applicationId: event.applicationId,
      );

      if (validation['canPay'] != true) {
        emit(ApplicationPaymentError(
          error: validation['error'] ?? 'Payment not allowed',
          applicationId: event.applicationId,
        ));
        return;
      }

      // Confirm payment (this updates Firestore)
      await _paymentService.confirmApplicationPayment(
        applicationId: event.applicationId,
        paymentIntentId: event.paymentIntentId,
      );

      // Get updated application
      final application = await _applicationService.getApplication(event.applicationId);

      if (application != null) {
        emit(ApplicationPaymentSuccess(application: application));
      } else {
        emit(const ApplicationPaymentError(
          error: 'Payment processed but application not found',
        ));
      }
    } catch (e) {
      emit(ApplicationPaymentError(
        error: e.toString(),
        applicationId: event.applicationId,
      ));
    }
  }

  // ==========================================================================
  // ORGANIZER EVENT HANDLERS
  // ==========================================================================

  /// Handle loading market applications with real-time updates
  Future<void> _onLoadMarketApplications(
    LoadMarketApplicationsEvent event,
    Emitter<ApplicationState> emit,
  ) async {
    emit(const ApplicationLoading());

    try {
      // Cancel previous subscription
      await _applicationsSubscription?.cancel();

      // Get market details for spots info
      final marketDoc =
          await FirebaseFirestore.instance.collection('markets').doc(event.marketId).get();

      final marketData = marketDoc.data() ?? {};
      final spotsTotal = marketData['vendorSpotsTotal'] as int? ?? 0;
      final spotsAvailable = marketData['vendorSpotsAvailable'] as int? ?? 0;

      // Use emit.forEach for proper stream handling in BLoC
      await emit.forEach<List<VendorApplication>>(
        _applicationService.getMarketApplications(event.marketId, filterStatus: event.filterStatus),
        onData: (applications) {
          // Count by status
          final pendingCount =
              applications.where((a) => a.status == ApplicationStatus.pending).length;
          final approvedCount =
              applications.where((a) => a.status == ApplicationStatus.approved).length;
          final confirmedCount =
              applications.where((a) => a.status == ApplicationStatus.confirmed).length;
          final deniedCount =
              applications.where((a) => a.status == ApplicationStatus.denied).length;

          return MarketApplicationsLoaded(
            marketId: event.marketId,
            applications: applications,
            pendingCount: pendingCount,
            approvedCount: approvedCount,
            confirmedCount: confirmedCount,
            deniedCount: deniedCount,
            spotsTotal: spotsTotal,
            spotsRemaining: spotsAvailable,
          );
        },
        onError: (error, stackTrace) {
          return ApplicationActionError(
            error: 'Failed to load applications: ${error.toString()}',
          );
        },
      );
    } catch (e) {
      emit(ApplicationActionError(error: 'Failed to load applications: ${e.toString()}'));
    }
  }

  /// Handle organizer approving an application
  Future<void> _onApproveApplication(
    ApproveApplicationEvent event,
    Emitter<ApplicationState> emit,
  ) async {
    emit(const ApplicationApproving());

    try {
      await _applicationService.approveApplication(event.applicationId);

      // Get updated application
      final application = await _applicationService.getApplication(event.applicationId);

      if (application != null) {
        emit(ApplicationApproved(application: application));
      } else {
        emit(const ApplicationActionError(
          error: 'Application approved but could not be retrieved',
        ));
      }
    } catch (e) {
      emit(ApplicationActionError(
        error: e.toString(),
        applicationId: event.applicationId,
      ));
    }
  }

  /// Handle organizer denying an application
  Future<void> _onDenyApplication(
    DenyApplicationEvent event,
    Emitter<ApplicationState> emit,
  ) async {
    emit(const ApplicationDenying());

    try {
      await _applicationService.denyApplication(
        event.applicationId,
        event.denialNote,
      );

      // Get updated application
      final application = await _applicationService.getApplication(event.applicationId);

      if (application != null) {
        emit(ApplicationDenied(application: application));
      } else {
        emit(const ApplicationActionError(
          error: 'Application denied but could not be retrieved',
        ));
      }
    } catch (e) {
      emit(ApplicationActionError(
        error: e.toString(),
        applicationId: event.applicationId,
      ));
    }
  }

  // ==========================================================================
  // SYSTEM EVENT HANDLERS
  // ==========================================================================

  /// Handle real-time application status changes
  Future<void> _onApplicationStatusChanged(
    ApplicationStatusChangedEvent event,
    Emitter<ApplicationState> emit,
  ) async {
    // This can be used to trigger specific UI responses to status changes
    // For now, the real-time stream handlers above will automatically emit new states
  }

  /// Handle application expiration (24hr window passed)
  Future<void> _onApplicationExpired(
    ApplicationExpiredEvent event,
    Emitter<ApplicationState> emit,
  ) async {
    try {
      await _applicationService.expireApplication(event.applicationId);

      final application = await _applicationService.getApplication(event.applicationId);

      emit(ApplicationExpired(
        applicationId: event.applicationId,
        application: application,
      ));
    } catch (e) {
      emit(ApplicationActionError(
        error: 'Failed to expire application: ${e.toString()}',
        applicationId: event.applicationId,
      ));
    }
  }

  /// Handle manual refresh of applications
  Future<void> _onRefreshApplications(
    RefreshApplicationsEvent event,
    Emitter<ApplicationState> emit,
  ) async {
    // Streams automatically refresh, but this can force a reload if needed
    emit(const ApplicationLoading());
  }

  // ==========================================================================
  // CLEANUP
  // ==========================================================================

  @override
  Future<void> close() {
    _applicationsSubscription?.cancel();
    return super.close();
  }
}
