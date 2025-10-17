import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/push_notification_service.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import '../../../core/widgets/hipop_app_bar.dart';
import '../../../core/utils/timezone_utils.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final PushNotificationService _notificationService = PushNotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  bool _vendorPopups = true;
  bool _marketReminders = true;
  bool _popupReminders = true;  // NEW: Monday/Thursday popup reminders
  bool _organizerReminders = true;  // NEW: Market organizer reminders
  bool _eveningPreview = true;
  bool _twoHourReminders = true;
  String _morningTime = '08:00';
  String _quietHoursStart = '22:00';
  String _quietHoursEnd = '07:00';
  String? _timezoneOffsetMessage;
  String? _dstMessage;

  @override
  void initState() {
    super.initState();
    _initializeTimezone();
    _loadPreferences();
  }
  
  Future<void> _initializeTimezone() async {
    try {
      await TimezoneUtils.initialize();
      setState(() {
        _timezoneOffsetMessage = TimezoneUtils.getTimezoneOffsetDescription();
        _dstMessage = TimezoneUtils.getDSTTransitionMessage();
      });
    } catch (e) {
      // Handle initialization error
      print('Error initializing timezone: $e');
    }
  }

  Future<void> _loadPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('user_profiles').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final prefs = data['notificationPreferences'] as Map<String, dynamic>?;
        
        if (prefs != null) {
          setState(() {
            _notificationsEnabled = prefs['enabled'] ?? true;
            _vendorPopups = prefs['vendorPopups'] ?? true;
            _marketReminders = prefs['marketReminders'] ?? true;
            _popupReminders = prefs['popupReminders'] ?? true;
            _organizerReminders = prefs['organizerReminders'] ?? true;
            _eveningPreview = prefs['eveningPreview'] ?? true;
            _twoHourReminders = prefs['twoHourReminders'] ?? true;
            _morningTime = prefs['morningTime'] ?? '08:00';
            _quietHoursStart = prefs['quietHoursStart'] ?? '22:00';
            _quietHoursEnd = prefs['quietHoursEnd'] ?? '07:00';
          });
        }
      }
      
      // Check if notifications are enabled at system level
      final systemEnabled = await _notificationService.areNotificationsEnabled();
      if (!systemEnabled && mounted) {
        setState(() {
          _notificationsEnabled = false;
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePreferences() async {
    final preferences = {
      'enabled': _notificationsEnabled,
      'vendorPopups': _vendorPopups,
      'marketReminders': _marketReminders,
      'popupReminders': _popupReminders,
      'organizerReminders': _organizerReminders,
      'eveningPreview': _eveningPreview,
      'twoHourReminders': _twoHourReminders,
      'morningTime': _morningTime,
      'quietHoursStart': _quietHoursStart,
      'quietHoursEnd': _quietHoursEnd,
      'timezone': 'America/New_York',  // All times in Eastern
    };

    await _notificationService.updatePreferences(preferences);
  }

  Future<void> _handleEnableNotifications(bool value) async {
    if (value) {
      // Request system permission
      final granted = await _notificationService.requestEnableNotifications();
      if (granted) {
        setState(() {
          _notificationsEnabled = true;
        });
        await _savePreferences();
      } else {
        // Show dialog to guide user to settings
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Enable Notifications'),
              content: const Text(
                'Please enable notifications in your device settings to receive updates about your favorite vendors and markets.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } else {
      setState(() {
        _notificationsEnabled = false;
      });
      await _savePreferences();
    }
  }

  Widget _buildTimePicker({
    required String title,
    required String time,
    required Function(String) onTimeChanged,
    String? helperText,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Format time with Eastern Time indicator
    final formattedTime = TimezoneUtils.formatNotificationTime(time);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(
          title,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedTime,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? HiPopColors.secondarySoftSage : HiPopColors.primaryDeepSage,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (helperText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  helperText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? HiPopColors.darkTextTertiary : HiPopColors.lightTextTertiary,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.access_time,
          color: isDark ? HiPopColors.darkTextSecondary : HiPopColors.lightTextSecondary,
        ),
        onTap: () async {
        final parts = time.split(':');
        final initialTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
        
        final picked = await showTimePicker(
          context: context,
          initialTime: initialTime,
        );
        
        if (picked != null) {
          final formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
          onTimeChanged(formattedTime);
          await _savePreferences();
        }
      },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        appBar: const HiPopAppBar(
          title: 'Notification Settings',
          useGradient: false,
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? HiPopColors.secondarySoftSage : HiPopColors.primaryDeepSage,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const HiPopAppBar(
        title: 'Notification Settings',
        useGradient: false,
      ),
      body: ListView(
        children: [
          // Master switch
          Card(
            margin: const EdgeInsets.all(16),
            child: SwitchListTile(
              title: Text(
                'Push Notifications',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Get notified about your favorite vendors and markets',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? HiPopColors.darkTextSecondary : HiPopColors.lightTextSecondary,
                ),
              ),
              value: _notificationsEnabled,
              onChanged: _handleEnableNotifications,
              activeColor: isDark ? HiPopColors.secondarySoftSage : HiPopColors.primaryDeepSage,
            ),
          ),
          
          // Notification types
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'NOTIFICATION TYPES',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: isDark ? HiPopColors.darkTextTertiary : HiPopColors.lightTextTertiary,
              ),
            ),
          ),
          
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              title: Text(
                'Vendor Popups',
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Text(
                'When your favorite vendors have popups',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? HiPopColors.darkTextSecondary : HiPopColors.lightTextSecondary,
                ),
              ),
              value: _vendorPopups && _notificationsEnabled,
              onChanged: !_notificationsEnabled ? null : (value) async {
                setState(() {
                  _vendorPopups = value;
                });
                await _savePreferences();
              },
              activeColor: isDark ? HiPopColors.secondarySoftSage : HiPopColors.primaryDeepSage,
              inactiveThumbColor: isDark ? HiPopColors.darkTextTertiary : HiPopColors.lightTextTertiary,
              inactiveTrackColor: isDark ? HiPopColors.darkBorder : HiPopColors.lightBorder,
            ),
          ),
          
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              title: Text(
                'Market Reminders',
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Text(
                'Reminders about upcoming markets',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? HiPopColors.darkTextSecondary : HiPopColors.lightTextSecondary,
                ),
              ),
              value: _marketReminders && _notificationsEnabled,
              onChanged: !_notificationsEnabled ? null : (value) async {
                setState(() {
                  _marketReminders = value;
                });
                await _savePreferences();
              },
              activeColor: isDark ? HiPopColors.secondarySoftSage : HiPopColors.primaryDeepSage,
              inactiveThumbColor: isDark ? HiPopColors.darkTextTertiary : HiPopColors.lightTextTertiary,
              inactiveTrackColor: isDark ? HiPopColors.darkBorder : HiPopColors.lightBorder,
            ),
          ),
          
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              title: Text(
                'Popup Creation Reminders',
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Text(
                'Monday & Thursday reminders to post upcoming popups',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? HiPopColors.darkTextSecondary : HiPopColors.lightTextSecondary,
                ),
              ),
              value: _popupReminders && _notificationsEnabled,
              onChanged: !_notificationsEnabled ? null : (value) async {
                setState(() {
                  _popupReminders = value;
                });
                await _savePreferences();
              },
              activeColor: isDark ? HiPopColors.secondarySoftSage : HiPopColors.primaryDeepSage,
              inactiveThumbColor: isDark ? HiPopColors.darkTextTertiary : HiPopColors.lightTextTertiary,
              inactiveTrackColor: isDark ? HiPopColors.darkBorder : HiPopColors.lightBorder,
            ),
          ),

          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              title: Text(
                'Market Organizer Reminders',
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Text(
                'Reminders to post market updates and announcements',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? HiPopColors.darkTextSecondary : HiPopColors.lightTextSecondary,
                ),
              ),
              value: _organizerReminders && _notificationsEnabled,
              onChanged: !_notificationsEnabled ? null : (value) async {
                setState(() {
                  _organizerReminders = value;
                });
                await _savePreferences();
              },
              activeColor: isDark ? HiPopColors.secondarySoftSage : HiPopColors.primaryDeepSage,
              inactiveThumbColor: isDark ? HiPopColors.darkTextTertiary : HiPopColors.lightTextTertiary,
              inactiveTrackColor: isDark ? HiPopColors.darkBorder : HiPopColors.lightBorder,
            ),
          ),

          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              title: Text(
                'Evening Preview',
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Text(
                'Tomorrow\'s events summary at 6 PM Eastern',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? HiPopColors.darkTextSecondary : HiPopColors.lightTextSecondary,
                ),
              ),
              value: _eveningPreview && _notificationsEnabled,
              onChanged: !_notificationsEnabled ? null : (value) async {
                setState(() {
                  _eveningPreview = value;
                });
                await _savePreferences();
              },
              activeColor: isDark ? HiPopColors.secondarySoftSage : HiPopColors.primaryDeepSage,
              inactiveThumbColor: isDark ? HiPopColors.darkTextTertiary : HiPopColors.lightTextTertiary,
              inactiveTrackColor: isDark ? HiPopColors.darkBorder : HiPopColors.lightBorder,
            ),
          ),
          
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              title: Text(
                '2-Hour Reminders',
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Text(
                'Reminder 2 hours before events',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? HiPopColors.darkTextSecondary : HiPopColors.lightTextSecondary,
                ),
              ),
              value: _twoHourReminders && _notificationsEnabled,
              onChanged: !_notificationsEnabled ? null : (value) async {
                setState(() {
                  _twoHourReminders = value;
                });
                await _savePreferences();
              },
              activeColor: isDark ? HiPopColors.secondarySoftSage : HiPopColors.primaryDeepSage,
              inactiveThumbColor: isDark ? HiPopColors.darkTextTertiary : HiPopColors.lightTextTertiary,
              inactiveTrackColor: isDark ? HiPopColors.darkBorder : HiPopColors.lightBorder,
            ),
          ),
          
          // Timing settings
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOTIFICATION TIMING',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: isDark ? HiPopColors.darkTextTertiary : HiPopColors.lightTextTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All times are in Eastern Time (${TimezoneUtils.getCurrentTimezoneAbbreviation()})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? HiPopColors.darkTextTertiary : HiPopColors.lightTextTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          
          _buildTimePicker(
            title: 'Morning Notifications',
            time: _morningTime,
            helperText: 'Daily summary of today\'s events',
            onTimeChanged: (time) {
              setState(() {
                _morningTime = time;
              });
            },
          ),
          
          // Quiet hours
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'QUIET HOURS',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: isDark ? HiPopColors.darkTextTertiary : HiPopColors.lightTextTertiary,
              ),
            ),
          ),
          
          _buildTimePicker(
            title: 'Quiet Hours Start',
            time: _quietHoursStart,
            helperText: 'No notifications after this time',
            onTimeChanged: (time) {
              setState(() {
                _quietHoursStart = time;
              });
            },
          ),
          
          _buildTimePicker(
            title: 'Quiet Hours End',
            time: _quietHoursEnd,
            helperText: 'Notifications resume at this time',
            onTimeChanged: (time) {
              setState(() {
                _quietHoursEnd = time;
              });
            },
          ),
          
          const SizedBox(height: 20),
          
          // Timezone info card
          if (_timezoneOffsetMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark 
                      ? HiPopColors.secondarySoftSage.withOpacity( 0.1)
                      : HiPopColors.surfacePalePink.withOpacity( 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? HiPopColors.darkBorder : HiPopColors.lightBorder,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 18,
                        color: isDark ? HiPopColors.secondarySoftSage : HiPopColors.primaryDeepSage,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _timezoneOffsetMessage!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? HiPopColors.darkTextSecondary : HiPopColors.lightTextSecondary,
                              ),
                            ),
                            if (_dstMessage != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _dstMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? HiPopColors.accentMauve : HiPopColors.primaryDeepSage,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Info card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          HiPopColors.secondarySoftSage.withOpacity( 0.15),
                          HiPopColors.accentMauve.withOpacity( 0.1),
                        ]
                      : [
                          HiPopColors.surfacePalePink,
                          HiPopColors.surfaceSoftPink,
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? HiPopColors.darkBorder : HiPopColors.lightBorder,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: isDark ? HiPopColors.premiumGold : HiPopColors.primaryDeepSage,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'How it works',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? HiPopColors.darkTextPrimary : HiPopColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Heart vendors and markets to automatically get notifications\n'
                      '• Morning notifications arrive at your selected time in Eastern Time\n'
                      '• Monday & Thursday reminders help you stay active\n'
                      '• No notifications during quiet hours (based on Eastern Time)\n'
                      '• Perfect for markets in Atlanta and the East Coast\n'
                      '• You can change these settings anytime',
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.5,
                        color: isDark ? HiPopColors.darkTextSecondary : HiPopColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}