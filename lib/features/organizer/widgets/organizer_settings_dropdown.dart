import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_event.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../auth/screens/change_password_screen.dart';
import '../../auth/services/onboarding_service.dart';
import '../../shared/services/user/specialized_account_deletion_service.dart';
import '../../shared/models/user_feedback.dart';
import '../../shared/services/user/user_feedback_service.dart';
import '../../premium/screens/subscription_management_screen.dart';
import '../../shared/providers/theme_provider.dart';
import '../../shared/services/theme_preferences_service.dart';

/// Market organizer-specific settings dropdown with specialized account deletion flow
class OrganizerSettingsDropdown extends StatefulWidget {
  const OrganizerSettingsDropdown({super.key});

  @override
  State<OrganizerSettingsDropdown> createState() => _OrganizerSettingsDropdownState();
}

class _OrganizerSettingsDropdownState extends State<OrganizerSettingsDropdown> {
  Future<void> _resetOnboarding() async {
    try {
      await OnboardingService.resetOrganizerOnboarding();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tutorial reset! It will show again next time you restart the app.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting tutorial: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ChangePasswordScreen(),
      ),
    );
  }

  void _showFeedbackDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    FeedbackCategory selectedCategory = FeedbackCategory.general;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Organizer Feedback'),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help us improve the market organizer experience! Your feedback goes directly to our team.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                
                // Category selection
                const Text('Category:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<FeedbackCategory>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: FeedbackCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(_getCategoryDisplayName(category)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Title
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Brief summary of your organizer feedback',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 200,
                ),
                const SizedBox(height: 16),

                // Description
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Please provide details about your organizer experience',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  maxLength: 2000,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();
              
              if (title.isEmpty || description.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all fields')),
                );
                return;
              }

              Navigator.pop(context);
              _submitFeedback(selectedCategory, title, description);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Feedback'),
          ),
        ],
      ),
    );
  }

  String _getCategoryDisplayName(FeedbackCategory category) {
    switch (category) {
      case FeedbackCategory.bug:
        return 'Bug Report';
      case FeedbackCategory.feature:
        return 'Feature Request';
      case FeedbackCategory.improvement:
        return 'Improvement Suggestion';
      case FeedbackCategory.general:
        return 'General Feedback';
      case FeedbackCategory.tutorial:
        return 'Tutorial Feedback';
      case FeedbackCategory.support:
        return 'Support Request';
    }
  }

  Future<void> _submitFeedback(FeedbackCategory category, String title, String description) async {
    try {
      final authBloc = context.read<AuthBloc>();
      final authState = authBloc.state;
      if (authState is! Authenticated) return;

      await UserFeedbackService.submitFeedback(
        userId: authState.user.uid,
        userType: 'market_organizer',
        userEmail: authState.user.email ?? '',
        userName: authState.user.displayName,
        category: category,
        title: title,
        description: description,
        metadata: {
          'screen': 'organizer_settings_dropdown',
          'timestamp': DateTime.now().toIso8601String(),
          'appSection': 'organizer_settings',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your organizer feedback! We\'ll review it soon.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showThemeDialog() {
    final themeProvider = ThemeProvider.maybeOf(context);
    if (themeProvider == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) {
            return RadioListTile<ThemeMode>(
              value: mode,
              groupValue: themeProvider.themeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  themeProvider.updateThemeMode(value);
                  Navigator.pop(context);
                }
              },
              title: Row(
                children: [
                  Icon(
                    ThemePreferencesService.getThemeModeIcon(mode),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(ThemePreferencesService.getThemeModeLabel(mode)),
                ],
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings),
      tooltip: 'Organizer Settings',
      onSelected: (String value) {
        switch (value) {
          case 'subscription':
            _navigateToSubscriptionManagement();
            break;
          case 'theme':
            _showThemeDialog();
            break;
          case 'change-password':
            _showChangePasswordDialog();
            break;
          case 'feedback':
            _showFeedbackDialog();
            break;
          case 'reset-onboarding':
            _resetOnboarding();
            break;
          case 'logout':
            context.read<AuthBloc>().add(LogoutEvent());
            break;
          case 'delete':
            SpecializedAccountDeletionService.deleteOrganizerAccount(context);
            break;
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<String>(
          value: 'subscription',
          child: Row(
            children: [
              Icon(Icons.credit_card, color: Colors.purple),
              SizedBox(width: 12),
              Text('Manage Subscription'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'theme',
          child: Row(
            children: [
              Icon(Icons.brightness_6, color: Colors.orange),
              SizedBox(width: 12),
              Text('Theme'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'change-password',
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.grey),
              SizedBox(width: 12),
              Text('Change Password'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'feedback',
          child: Row(
            children: [
              Icon(Icons.feedback, color: Colors.blue),
              SizedBox(width: 12),
              Text('Send Organizer Feedback'),
            ],
          ),
        ),
        if (kDebugMode) ...[
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'reset-onboarding',
            child: Row(
              children: [
                Icon(Icons.refresh, color: Colors.grey),
                SizedBox(width: 12),
                Text('Reset Tutorial'),
              ],
            ),
          ),
        ],
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.grey),
              SizedBox(width: 12),
              Text('Sign Out'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.red),
              SizedBox(width: 12),
              Text(
                'Delete Organizer Account',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  void _navigateToSubscriptionManagement() {
    final authBloc = context.read<AuthBloc>();
    final authState = authBloc.state;
    
    if (authState is Authenticated) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SubscriptionManagementScreen(
            userId: authState.user.uid,
          ),
        ),
      );
    }
  }
}