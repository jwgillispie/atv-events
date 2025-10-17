import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/hipop_colors.dart';

/// Centralized error handling and notification service for HiPop Markets
///
/// Provides consistent error messaging, success notifications, and user feedback
/// across the entire application. Replaces 300+ scattered SnackBar implementations
/// with a unified, branded experience that maintains visual consistency and
/// improves user trust through clear, actionable messaging.
class ErrorHandler {
  // Prevent instantiation
  ErrorHandler._();

  // ======= Core Display Methods =======

  /// Display success message with HiPop brand styling
  /// Used for: Successful operations, confirmations, completions
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    IconData icon = Icons.check_circle_rounded,
    VoidCallback? onDismissed,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: HiPopColors.successGreen,
      textColor: Colors.white,
      icon: icon,
      iconColor: Colors.white,
      duration: duration,
      onDismissed: onDismissed,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Display error message with appropriate severity styling
  /// Used for: Operation failures, validation errors, system errors
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 5),
    IconData icon = Icons.error_rounded,
    VoidCallback? onDismissed,
    String? actionLabel,
    VoidCallback? onAction,
    bool isRecoverable = true,
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: HiPopColors.errorPlum,
      textColor: Colors.white,
      icon: icon,
      iconColor: Colors.white,
      duration: duration,
      onDismissed: onDismissed,
      actionLabel: actionLabel ?? (isRecoverable ? 'Retry' : null),
      onAction: onAction,
    );

    // Log error for analytics
    _logError(message, isRecoverable: isRecoverable);
  }

  /// Display warning message for important but non-critical issues
  /// Used for: Warnings, cautions, important notices
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    IconData icon = Icons.warning_rounded,
    VoidCallback? onDismissed,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: HiPopColors.warningAmber,
      textColor: HiPopColors.darkBackground,
      icon: icon,
      iconColor: HiPopColors.darkBackground,
      duration: duration,
      onDismissed: onDismissed,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Display informational message
  /// Used for: Tips, hints, neutral information
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    IconData icon = Icons.info_rounded,
    VoidCallback? onDismissed,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: HiPopColors.infoBlueGray,
      textColor: Colors.white,
      icon: icon,
      iconColor: Colors.white,
      duration: duration,
      onDismissed: onDismissed,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  // ======= Specialized Error Handlers =======

  /// Handle network-related errors with appropriate messaging
  static void handleNetworkError(
    BuildContext context, {
    String? customMessage,
    VoidCallback? onRetry,
  }) {
    showError(
      context,
      customMessage ?? 'Connection issue. Please check your internet and try again.',
      icon: Icons.wifi_off_rounded,
      actionLabel: 'Retry',
      onAction: onRetry,
      duration: const Duration(seconds: 6),
    );
  }

  /// Handle permission-related errors
  static void handlePermissionError(
    BuildContext context,
    String permission, {
    VoidCallback? onSettings,
  }) {
    showError(
      context,
      'Permission required for $permission',
      icon: Icons.lock_rounded,
      actionLabel: 'Settings',
      onAction: onSettings ?? () => _openAppSettings(context),
      duration: const Duration(seconds: 6),
    );
  }

  /// Handle validation errors with field-specific messaging
  static void handleValidationError(
    BuildContext context,
    String field,
    String issue, {
    VoidCallback? onCorrect,
  }) {
    showError(
      context,
      '$field: $issue',
      icon: Icons.text_fields_rounded,
      actionLabel: 'Fix',
      onAction: onCorrect,
      duration: const Duration(seconds: 4),
    );
  }

  /// Handle premium feature access errors
  static void handlePremiumFeatureError(
    BuildContext context, {
    String? feature,
    VoidCallback? onUpgrade,
  }) {
    final message = feature != null
        ? '$feature requires a premium subscription'
        : 'This feature requires a premium subscription';

    showWarning(
      context,
      message,
      icon: Icons.workspace_premium_rounded,
      actionLabel: 'Upgrade',
      onAction: onUpgrade,
      duration: const Duration(seconds: 5),
    );
  }

  /// Handle authentication errors
  static void handleAuthError(
    BuildContext context,
    String errorCode, {
    VoidCallback? onSignIn,
  }) {
    final message = _getAuthErrorMessage(errorCode);
    showError(
      context,
      message,
      icon: Icons.account_circle_rounded,
      actionLabel: 'Sign In',
      onAction: onSignIn,
      duration: const Duration(seconds: 5),
    );
  }

  // ======= Marketplace-Specific Handlers =======

  /// Handle vendor application errors
  static void handleVendorApplicationError(
    BuildContext context,
    String reason, {
    VoidCallback? onReview,
  }) {
    showError(
      context,
      'Application issue: $reason',
      icon: Icons.store_rounded,
      actionLabel: 'Review',
      onAction: onReview,
      duration: const Duration(seconds: 5),
    );
  }

  /// Handle market operation errors
  static void handleMarketOperationError(
    BuildContext context,
    String operation, {
    VoidCallback? onRetry,
  }) {
    showError(
      context,
      'Unable to $operation. Please try again.',
      icon: Icons.storefront_rounded,
      actionLabel: 'Retry',
      onAction: onRetry,
      duration: const Duration(seconds: 5),
    );
  }

  /// Handle payment/transaction errors
  static void handlePaymentError(
    BuildContext context,
    String issue, {
    VoidCallback? onSupport,
  }) {
    showError(
      context,
      'Payment issue: $issue',
      icon: Icons.payment_rounded,
      actionLabel: 'Support',
      onAction: onSupport,
      duration: const Duration(seconds: 6),
      isRecoverable: false,
    );
  }

  // ======= Success Handlers =======

  /// Show success for data save operations
  static void showSaveSuccess(
    BuildContext context, {
    String? itemName,
  }) {
    final message = itemName != null
        ? '$itemName saved successfully'
        : 'Saved successfully';
    showSuccess(context, message);
  }

  /// Show success for deletion operations
  static void showDeleteSuccess(
    BuildContext context, {
    String? itemName,
    VoidCallback? onUndo,
  }) {
    final message = itemName != null
        ? '$itemName deleted'
        : 'Deleted successfully';
    showSuccess(
      context,
      message,
      icon: Icons.delete_rounded,
      actionLabel: 'Undo',
      onAction: onUndo,
      duration: const Duration(seconds: 4),
    );
  }

  /// Show success for update operations
  static void showUpdateSuccess(
    BuildContext context, {
    String? itemName,
  }) {
    final message = itemName != null
        ? '$itemName updated'
        : 'Updated successfully';
    showSuccess(context, message);
  }

  // ======= Loading & Progress =======

  /// Show loading indicator with message
  static void showLoading(
    BuildContext context,
    String message, {
    bool dismissible = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: dismissible,
      builder: (context) => PopScope(
        canPop: dismissible,
        child: Dialog(
          backgroundColor: HiPopColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    HiPopColors.primaryDeepSage,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    color: HiPopColors.darkTextPrimary,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Dismiss loading dialog
  static void dismissLoading(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  // ======= Confirmation Dialogs =======

  /// Show confirmation dialog with HiPop styling
  static Future<bool> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: HiPopColors.darkTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: HiPopColors.darkTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              cancelText,
              style: TextStyle(
                color: HiPopColors.darkTextTertiary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive
                  ? HiPopColors.errorPlum
                  : HiPopColors.primaryDeepSage,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              confirmText,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // ======= Private Helper Methods =======

  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required Color textColor,
    IconData? icon,
    Color? iconColor,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onDismissed,
    String? actionLabel,
    VoidCallback? onAction,
    HapticFeedback? hapticFeedback,
  }) {
    // Clear any existing snackbars
    ScaffoldMessenger.of(context).clearSnackBars();

    // Trigger haptic feedback if specified
    if (hapticFeedback != null) {
      hapticFeedback;
    }

    // Build snackbar content
    final content = Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            color: iconColor ?? textColor,
            size: 24,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );

    // Show snackbar
    final snackBar = SnackBar(
      content: content,
      backgroundColor: backgroundColor,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.all(16),
      elevation: 4,
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              onPressed: onAction,
              textColor: textColor.withOpacity( 0.9),
            )
          : null,
      onVisible: onDismissed,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Map authentication error codes to user-friendly messages
  static String _getAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'Authentication failed. Please try again';
    }
  }

  /// Log errors for analytics and debugging
  static void _logError(String message, {bool isRecoverable = true}) {
    // TODO: Implement actual logging to Firebase Crashlytics or similar
    debugPrint('[ERROR] ${isRecoverable ? 'Recoverable' : 'Fatal'}: $message');
  }

  /// Open app settings for permission management
  static void _openAppSettings(BuildContext context) {
    // TODO: Implement actual app settings navigation
    showInfo(context, 'Opening app settings...');
  }

  // ======= Batch Operations =======

  /// Show multiple errors at once (e.g., form validation)
  static void showMultipleErrors(
    BuildContext context,
    List<String> errors, {
    Duration duration = const Duration(seconds: 6),
  }) {
    if (errors.isEmpty) return;

    if (errors.length == 1) {
      showError(context, errors.first, duration: duration);
    } else {
      final message = '${errors.length} issues found:\n• ${errors.join('\n• ')}';
      showError(context, message, duration: duration);
    }
  }

  /// Show progress with percentage
  static void showProgress(
    BuildContext context,
    String operation,
    double progress, {
    VoidCallback? onCancel,
  }) {
    final percentage = (progress * 100).toStringAsFixed(0);
    _showSnackBar(
      context,
      message: '$operation: $percentage%',
      backgroundColor: HiPopColors.primaryDeepSage,
      textColor: Colors.white,
      icon: Icons.downloading_rounded,
      duration: const Duration(days: 1), // Long duration, manually dismiss
      actionLabel: 'Cancel',
      onAction: onCancel,
    );
  }
}