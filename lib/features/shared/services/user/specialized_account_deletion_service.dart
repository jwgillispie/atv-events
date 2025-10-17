import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_event.dart';
import 'package:hipop/features/premium/services/stripe_service.dart';
import 'package:hipop/features/premium/services/subscription_service.dart';

import 'user_data_deletion_service.dart';


/// Specialized account deletion service for vendors and market organizers
/// 
/// This service provides role-specific account deletion flows while reusing
/// the core deletion logic from UserDataDeletionService.
class SpecializedAccountDeletionService {
  final UserDataDeletionService _deletionService;
  
  SpecializedAccountDeletionService({
    UserDataDeletionService? deletionService,
  }) : _deletionService = deletionService ?? UserDataDeletionService();

  /// Delete vendor account with vendor-specific warnings and confirmation
  static Future<void> deleteVendorAccount(BuildContext context) async {
    final service = SpecializedAccountDeletionService();
    await service._deleteAccountWithTypeSpecificFlow(
      context: context,
      userType: 'vendor',
      typeSpecificWarnings: [
        '• All your vendor posts and product listings',
        '• Your vendor applications and status',
        '• Market relationships and vendor booth assignments',
        '• Sales data and analytics',
        '• Customer reviews and ratings',
        '• Revenue tracking and financial data',
        '• Product management and inventory data',
        '• Any active premium subscriptions (will be cancelled)',
      ],
      confirmationTitle: 'Delete Vendor Account',
      confirmationMessage: 'This will permanently delete your vendor account and remove you from all markets.',
      progressTitle: 'Deleting Vendor Account',
    );
  }

  /// Delete market organizer account with organizer-specific warnings
  static Future<void> deleteOrganizerAccount(BuildContext context) async {
    final service = SpecializedAccountDeletionService();
    await service._deleteAccountWithTypeSpecificFlow(
      context: context,
      userType: 'market_organizer',
      typeSpecificWarnings: [
        '• All markets you organize and manage',
        '• Vendor applications and approvals',
        '• Market events and scheduling data',
        '• Vendor relationships and communications',
        '• Market analytics and performance data',
        '• Financial data and revenue tracking',
        '• Organizer dashboard and settings',
        '• Any active premium subscriptions (will be cancelled)',
      ],
      confirmationTitle: 'Delete Organizer Account',
      confirmationMessage: 'This will permanently delete your organizer account and all associated markets.',
      progressTitle: 'Deleting Organizer Account',
    );
  }

  /// Delete shopper account (wrapper for consistency)
  static Future<void> deleteShopperAccount(BuildContext context) async {
    final service = SpecializedAccountDeletionService();
    await service._deleteAccountWithTypeSpecificFlow(
      context: context,
      userType: 'shopper',
      typeSpecificWarnings: [
        '• Your favorites and bookmarks',
        '• Search history and preferences', 
        '• Market check-ins and visit history',
        '• Reviews and ratings you\'ve left',
        '• Personalized recommendations',
        '• Shopping preferences and settings',
        '• Any active premium subscriptions (will be cancelled)',
      ],
      confirmationTitle: 'Delete Shopper Account',
      confirmationMessage: 'This will permanently delete your shopper account and preferences.',
      progressTitle: 'Deleting Shopper Account',
    );
  }

  /// Core deletion flow with type-specific customization
  Future<void> _deleteAccountWithTypeSpecificFlow({
    required BuildContext context,
    required String userType,
    required List<String> typeSpecificWarnings,
    required String confirmationTitle,
    required String confirmationMessage,
    required String progressTitle,
  }) async {
    // Show confirmation dialog first
    final confirmed = await _showTypeSpecificConfirmationDialog(
      context: context,
      userType: userType,
      typeSpecificWarnings: typeSpecificWarnings,
      title: confirmationTitle,
      message: confirmationMessage,
    );
    
    if (!confirmed) return;

    // Show progress dialog and execute deletion
    if (context.mounted) {
      await _executeAccountDeletionWithProgress(
        context: context,
        userType: userType,
        progressTitle: progressTitle,
      );
    }
  }

  /// Show type-specific confirmation dialog
  Future<bool> _showTypeSpecificConfirmationDialog({
    required BuildContext context,
    required String userType,
    required List<String> typeSpecificWarnings,
    required String title,
    required String message,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Get deletion preview
    UserDataDeletionPreview? preview;
    try {
      preview = await _deletionService.getDeletePreview(user.uid);
    } catch (e) {
    }

    if (!context.mounted) return false;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                
                Text(
                  'This action will permanently delete:',
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                
                // Type-specific warnings
                ...typeSpecificWarnings.map((warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(warning, style: TextStyle(color: Colors.grey[700])),
                )),
                
                const SizedBox(height: 12),
                
                // Common data
                Text('• Your user profile and account settings', style: TextStyle(color: Colors.grey[700])),
                Text('• All personal preferences and data', style: TextStyle(color: Colors.grey[700])),
                
                if (preview != null && preview.totalDocumentsToDelete > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Data Summary',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${preview.totalDocumentsToDelete} total records to delete'),
                        if (preview.estimatedTimeMinutes > 0)
                          Text('Estimated time: ${preview.estimatedTimeMinutes} minute${preview.estimatedTimeMinutes == 1 ? '' : 's'}'),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This action cannot be undone. All your data will be permanently lost.',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete ${_capitalizeUserType(userType)} Account'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// Execute account deletion with progress dialog
  Future<void> _executeAccountDeletionWithProgress({
    required BuildContext context,
    required String userType,
    required String progressTitle,
  }) async {
    String deletionProgress = '';

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(progressTitle)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please wait while we delete your account and data...'),
              if (deletionProgress.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  deletionProgress,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      // Re-authenticate the user before deletion (required by Firebase)
      final credentials = await _promptForPasswordConfirmation(context);
      if (credentials == null) {
        if (context.mounted) Navigator.of(context).pop(); // Close progress dialog
        return;
      }

      // Re-authenticate with Firebase
      await user.reauthenticateWithCredential(credentials);

      // Cancel any active premium subscriptions first
      try {
        final subscription = await SubscriptionService.getUserSubscription(user.uid);
        
        if (subscription != null && subscription.isPremium && subscription.isActive) {
          
          // Cancel subscription with immediate cancellation and account deletion reason
          final cancelled = await StripeService.cancelSubscriptionEnhanced(
            user.uid,
            cancellationType: 'immediate',
            feedback: 'Account deletion - User requested account closure',
          );
          
          if (cancelled) {
            deletionProgress = 'Cancelled premium subscription';
          } else {
            deletionProgress = 'Warning: Subscription cancellation failed';
          }
        } else {
        }
      } catch (e) {
        deletionProgress = 'Warning: Subscription cleanup failed';
        // Continue with deletion - subscription cancellation failure shouldn't block account deletion
      }

      // Delete user data from Firestore using the comprehensive service
      try {
        
        final result = await _deletionService.deleteAllUserData(
          user.uid,
          userType: userType,
          onProgress: (operation, completed, total) {
            deletionProgress = '$operation ($completed/$total)';
            // Note: We can't reliably update the dialog state here since it's async
          },
        );
        
        if (result.success) {
        } else {
        }
      } catch (e) {
        // Continue with account deletion even if data deletion fails
        // to prevent account lock-out, but log the error
      }

      // Delete the Firebase account
      await user.delete();

      // Sign out and navigate to auth screen
      await FirebaseAuth.instance.signOut();
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        context.read<AuthBloc>().add(LogoutEvent());
        context.go('/auth');
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_capitalizeUserType(userType)} account deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Prompt for password confirmation (reused from SettingsDropdown)
  Future<AuthCredential?> _promptForPasswordConfirmation(BuildContext context) async {
    AuthCredential? credential;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final passwordController = TextEditingController();
        bool obscurePassword = true;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirm Your Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'For security reasons, please enter your password to confirm account deletion.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                    onSubmitted: (value) => _processPasswordConfirmation(
                      passwordController.text,
                      dialogContext,
                      (cred) => credential = cred,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _processPasswordConfirmation(
                    passwordController.text,
                    dialogContext,
                    (cred) => credential = cred,
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    return credential;
  }

  /// Process password confirmation (reused from SettingsDropdown)
  void _processPasswordConfirmation(
    String password,
    BuildContext dialogContext,
    Function(AuthCredential) setCredential,
  ) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null && password.isNotEmpty) {
      setCredential(EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      ));
    }
    Navigator.pop(dialogContext);
  }

  /// Get user-friendly error messages (reused from SettingsDropdown)
  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'wrong-password':
          return 'The password you entered is incorrect.';
        case 'requires-recent-login':
          return 'For security reasons, please log out and log back in before deleting your account.';
        case 'user-not-found':
          return 'User account not found.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection and try again.';
        default:
          return 'Authentication error: ${error.message}';
      }
    }
    return error.toString();
  }

  /// Capitalize user type for display
  String _capitalizeUserType(String userType) {
    switch (userType) {
      case 'vendor':
        return 'Vendor';
      case 'market_organizer':
        return 'Market Organizer';
      case 'shopper':
        return 'Shopper';
      default:
        return userType;
    }
  }
}