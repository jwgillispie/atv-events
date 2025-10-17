import 'package:flutter/material.dart';

/// Utility class for common UI operations
class UIUtils {
  /// Shows a success snackbar with green background
  static void showSuccessSnackBar(BuildContext context, String message, {Duration? duration}) {
    _showSnackBar(
      context,
      message,
      backgroundColor: Colors.green,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Shows an error snackbar with red background
  static void showErrorSnackBar(BuildContext context, String message, {Duration? duration}) {
    _showSnackBar(
      context,
      message,
      backgroundColor: Colors.red,
      duration: duration ?? const Duration(seconds: 6),
    );
  }

  /// Shows a warning snackbar with orange background
  static void showWarningSnackBar(BuildContext context, String message, {Duration? duration}) {
    _showSnackBar(
      context,
      message,
      backgroundColor: Colors.orange,
      duration: duration ?? const Duration(seconds: 5),
    );
  }

  /// Shows an info snackbar with blue background
  static void showInfoSnackBar(BuildContext context, String message, {Duration? duration}) {
    _showSnackBar(
      context,
      message,
      backgroundColor: Colors.blue,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// Shows a floating snackbar (commonly used pattern in the app)
  static void showFloatingSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration? duration,
    IconData? icon,
  }) {
    _showSnackBar(
      context,
      message,
      backgroundColor: backgroundColor ?? Colors.grey[800],
      duration: duration ?? const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      icon: icon,
    );
  }

  /// Shows a snackbar with action button
  static void showActionSnackBar(
    BuildContext context,
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
    Color? backgroundColor,
    Duration? duration,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.grey[800],
        duration: duration ?? const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: actionLabel,
          onPressed: onAction,
          textColor: Colors.white,
        ),
      ),
    );
  }

  /// Private method to reduce code duplication
  static void _showSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration? duration,
    SnackBarBehavior? behavior,
    ShapeBorder? shape,
    IconData? icon,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration ?? const Duration(seconds: 3),
        behavior: behavior,
        shape: shape,
      ),
    );
  }

  /// Shows a loading indicator dialog
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message),
            ],
          ],
        ),
      ),
    );
  }

  /// Dismisses any showing dialog
  static void dismissDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// Shows a confirmation dialog
  static Future<bool?> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}