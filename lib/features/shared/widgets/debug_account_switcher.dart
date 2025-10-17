import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_event.dart';
import 'package:hipop/blocs/auth/auth_state.dart';


class DebugAccountSwitcher extends StatelessWidget {
  const DebugAccountSwitcher({super.key});

  // Your test emails for quick switching
  static const Map<String, String> debugEmails = {
    'shopper': 'jozo@gmail.com',
    'vendor': 'vendorjozo@gmail.com',
    'market_organizer': 'marketjozo@gmail.com',
  };

  bool _isDebugAccount(String? email) {
    if (email == null) return false;
    return debugEmails.values.contains(email);
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        // Only show if logged in with one of your debug accounts
        if (state is! Authenticated || !_isDebugAccount(state.user.email)) {
          return const SizedBox.shrink();
        }

        final currentEmail = state.user.email;
        final currentUserType = state.userProfile?.userType ?? 'unknown';

        return Container(
          margin: const EdgeInsets.all(16),
          child: Card(
            color: Colors.purple.shade50,
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.swap_horiz, color: Colors.purple.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Debug Account Switcher',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Current: $currentUserType',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: debugEmails.entries.map((entry) {
                      final userType = entry.key;
                      final email = entry.value;
                      final isCurrentAccount = email == currentEmail;
                      
                      return _buildSwitchButton(
                        context,
                        userType,
                        email,
                        isCurrentAccount,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSwitchButton(
    BuildContext context,
    String userType,
    String email,
    bool isCurrent,
  ) {
    final colorMap = {
      'shopper': Colors.blue,
      'vendor': Colors.purple,
      'market_organizer': Colors.orange,
    };

    final iconMap = {
      'shopper': Icons.shopping_bag,
      'vendor': Icons.store,
      'market_organizer': Icons.admin_panel_settings,
    };

    final labelMap = {
      'shopper': 'Shopper',
      'vendor': 'Vendor',
      'market_organizer': 'Organizer',
    };

    final color = colorMap[userType] ?? Colors.grey;
    final icon = iconMap[userType] ?? Icons.person;
    final label = labelMap[userType] ?? userType;

    return ElevatedButton.icon(
      onPressed: isCurrent ? null : () => _switchAccount(context, userType, email),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isCurrent ? Colors.grey : color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
        elevation: isCurrent ? 0 : 2,
      ),
    );
  }

  Future<void> _switchAccount(BuildContext context, String userType, String email) async {
    // Show password dialog
    final password = await _showPasswordDialog(context, userType, email);
    if (password == null || password.isEmpty) return;

    try {
      // Show loading dialog
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(
                child: Text('Switching to $userType...'),
              ),
            ],
          ),
        ),
      );

      // Login to the selected account
      if (context.mounted) {
        context.read<AuthBloc>().add(LoginEvent(
          email: email,
          password: password,
        ));
      }

      // Close loading dialog after a delay
      await Future.delayed(const Duration(seconds: 1));
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Switched to $userType\n$email'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Account switch failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<String?> _showPasswordDialog(BuildContext context, String userType, String email) async {
    final TextEditingController passwordController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Switch to $userType'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: $email'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                onSubmitted: (_) => Navigator.of(context).pop(passwordController.text),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(passwordController.text),
              child: const Text('Switch'),
            ),
          ],
        );
      },
    );
  }
}