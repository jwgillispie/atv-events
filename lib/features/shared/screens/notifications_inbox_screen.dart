import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/core/widgets/hipop_app_bar.dart';
import '../widgets/common/loading_widget.dart';

/// Premium Notifications Inbox Screen for HiPop Markets
/// Displays notification history with sophisticated grouping, visual hierarchy,
/// and seamless navigation to relevant app sections
class NotificationsInboxScreen extends StatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  State<NotificationsInboxScreen> createState() => _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState extends State<NotificationsInboxScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Notification filters
  bool _showUnreadOnly = false;

  // Track expanded date groups
  final Set<String> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    // Mark notifications as seen when opening inbox
    _markNotificationsAsSeen();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Mark all notifications as "seen" (not necessarily read)
  Future<void> _markNotificationsAsSeen() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();
      final unseenNotifications = await _firestore
          .collection('notification_logs')
          .where('userId', isEqualTo: user.uid)
          .where('seen', isEqualTo: false)
          .limit(50)
          .get();

      for (final doc in unseenNotifications.docs) {
        batch.update(doc.reference, {
          'seen': true,
          'seenAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking notifications as seen: $e');
    }
  }

  /// Mark a specific notification as read
  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notification_logs').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Delete a notification
  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notification_logs').doc(notificationId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notification deleted'),
            backgroundColor: HiPopColors.darkSurface,
            action: SnackBarAction(
              label: 'Undo',
              textColor: HiPopColors.primaryDeepSage,
              onPressed: () {
                // Could implement undo functionality here
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  /// Clear all read notifications
  Future<void> _clearReadNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        title: const Text(
          'Clear Read Notifications',
          style: TextStyle(color: HiPopColors.darkTextPrimary),
        ),
        content: const Text(
          'This will permanently delete all read notifications. Continue?',
          style: TextStyle(color: HiPopColors.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.primaryDeepSage,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final batch = _firestore.batch();
      final readNotifications = await _firestore
          .collection('notification_logs')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: true)
          .get();

      for (final doc in readNotifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Read notifications cleared'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  /// Navigate to appropriate screen based on notification type
  void _handleNotificationTap(Map<String, dynamic> data, String notificationId) {
    // Mark as read
    _markAsRead(notificationId);

    // Navigate based on type
    switch (data['type']) {
      case 'vendor_popup':
        if (data['vendorId'] != null) {
          context.pushNamed('vendorDetail', pathParameters: {'vendorId': data['vendorId']});
        }
        break;

      case 'market_today':
      case 'market_reminder':
        if (data['marketId'] != null) {
          context.pushNamed('marketDetail', pathParameters: {'marketId': data['marketId']});
        }
        break;

      case 'popup_starting':
        if (data['postId'] != null && data['vendorId'] != null) {
          context.pushNamed('vendorPostDetail', pathParameters: {
            'vendorId': data['vendorId'],
            'postId': data['postId'],
          });
        }
        break;

      case 'tomorrow_preview':
        context.pushNamed('calendar');
        break;

      default:
        // Navigate to home for unknown types
        context.go('/');
    }
  }

  /// Get icon for notification type
  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'vendor_popup':
        return Icons.store;
      case 'market_today':
        return Icons.today;
      case 'market_reminder':
        return Icons.alarm;
      case 'popup_starting':
        return Icons.notifications_active;
      case 'tomorrow_preview':
        return Icons.event_available;
      default:
        return Icons.notifications;
    }
  }

  /// Get color accent for notification type
  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'vendor_popup':
        return HiPopColors.vendorAccent;
      case 'market_today':
        return HiPopColors.primaryDeepSage;
      case 'market_reminder':
        return HiPopColors.warningAmber;
      case 'popup_starting':
        return HiPopColors.accentDustyRose;
      case 'tomorrow_preview':
        return HiPopColors.infoBlueGray;
      default:
        return HiPopColors.secondarySoftSage;
    }
  }

  /// Format notification type for display
  String _formatNotificationType(String? type) {
    switch (type) {
      case 'vendor_popup':
        return 'Vendor Update';
      case 'market_today':
        return 'Market Today';
      case 'market_reminder':
        return 'Market Reminder';
      case 'popup_starting':
        return 'Popup Starting';
      case 'tomorrow_preview':
        return 'Tomorrow\'s Events';
      default:
        return 'Notification';
    }
  }

  /// Group notifications by date
  Map<String, List<QueryDocumentSnapshot>> _groupNotificationsByDate(
    List<QueryDocumentSnapshot> notifications,
  ) {
    final Map<String, List<QueryDocumentSnapshot>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final notification in notifications) {
      final timestamp = notification.data() as Map<String, dynamic>;
      final createdAt = timestamp['createdAt']?.toDate() ?? DateTime.now();
      final notificationDate = DateTime(createdAt.year, createdAt.month, createdAt.day);

      String groupKey;
      if (notificationDate == today) {
        groupKey = 'Today';
      } else if (notificationDate == yesterday) {
        groupKey = 'Yesterday';
      } else if (notificationDate.isAfter(today.subtract(const Duration(days: 7)))) {
        groupKey = DateFormat('EEEE').format(createdAt); // Day name for past week
      } else {
        groupKey = DateFormat('MMM d, yyyy').format(createdAt);
      }

      grouped.putIfAbsent(groupKey, () => []).add(notification);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: HiPopAppBar(
        title: 'Notifications',
        backgroundColor: HiPopColors.darkSurface,
        centerTitle: true,
        actions: [
          // Filter button
          IconButton(
            icon: Icon(
              _showUnreadOnly ? Icons.markunread : Icons.all_inbox,
              color: HiPopColors.darkTextPrimary,
            ),
            onPressed: () {
              setState(() {
                _showUnreadOnly = !_showUnreadOnly;
              });
              HapticFeedback.lightImpact();
            },
            tooltip: _showUnreadOnly ? 'Show all' : 'Show unread only',
          ),
          // Clear all button
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: HiPopColors.darkTextPrimary),
            color: HiPopColors.darkSurface,
            onSelected: (value) {
              if (value == 'clear_read') {
                _clearReadNotifications();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_read',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: HiPopColors.darkTextSecondary, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Clear read',
                      style: TextStyle(color: HiPopColors.darkTextPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: user == null
          ? _buildSignInPrompt()
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('notification_logs')
                  .where('userId', isEqualTo: user.uid)
                  .where('read', isEqualTo: _showUnreadOnly ? false : null)
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingWidget();
                }

                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                final notifications = snapshot.data?.docs ?? [];

                if (notifications.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildNotificationsList(notifications);
              },
            ),
    );
  }

  /// Build sign-in prompt for unauthenticated users
  Widget _buildSignInPrompt() {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: HiPopColors.darkSurface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: HiPopColors.primaryDeepSage.withOpacity( 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_off,
                  size: 64,
                  color: HiPopColors.darkTextTertiary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Sign In to View Notifications',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Create an account to receive updates about your favorite vendors and markets',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: HiPopColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.goNamed('login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HiPopColors.primaryDeepSage,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build empty state when no notifications
  Widget _buildEmptyState() {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      HiPopColors.darkSurface,
                      HiPopColors.darkSurfaceVariant,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: HiPopColors.primaryDeepSage.withOpacity( 0.1),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  _showUnreadOnly ? Icons.mark_email_read : Icons.inbox,
                  size: 72,
                  color: HiPopColors.primaryDeepSage.withOpacity( 0.7),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _showUnreadOnly ? 'All Caught Up!' : 'No Notifications Yet',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _showUnreadOnly
                    ? 'You\'ve read all your notifications'
                    : 'When vendors and markets update, you\'ll see them here',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: HiPopColors.darkTextSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              if (!_showUnreadOnly) ...[
                OutlinedButton.icon(
                  onPressed: () => context.pushNamed('notificationSettings'),
                  icon: const Icon(Icons.settings),
                  label: const Text('Notification Settings'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HiPopColors.primaryDeepSage,
                    side: const BorderSide(color: HiPopColors.primaryDeepSage),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: HiPopColors.errorPlum,
            ),
            const SizedBox(height: 24),
            const Text(
              'Unable to Load Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: HiPopColors.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.primaryDeepSage,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the main notifications list with date grouping
  Widget _buildNotificationsList(List<QueryDocumentSnapshot> notifications) {
    final groupedNotifications = _groupNotificationsByDate(notifications);
    final sortedKeys = groupedNotifications.keys.toList();

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: HiPopColors.primaryDeepSage,
      backgroundColor: HiPopColors.darkSurface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Add some top padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 8),
          ),

          // Build grouped notifications
          ...sortedKeys.map((dateGroup) {
            final notificationsInGroup = groupedNotifications[dateGroup]!;
            final isExpanded = !_expandedGroups.contains(dateGroup);

            return SliverToBoxAdapter(
              child: _buildDateGroup(
                dateGroup,
                notificationsInGroup,
                isExpanded,
              ),
            );
          }),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  /// Build a date group section
  Widget _buildDateGroup(
    String dateLabel,
    List<QueryDocumentSnapshot> notifications,
    bool isExpanded,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header
          InkWell(
            onTap: () {
              setState(() {
                if (_expandedGroups.contains(dateLabel)) {
                  _expandedGroups.remove(dateLabel);
                } else {
                  _expandedGroups.add(dateLabel);
                }
              });
              HapticFeedback.lightImpact();
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: HiPopColors.darkTextSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: HiPopColors.primaryDeepSage.withOpacity( 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${notifications.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: HiPopColors.primaryDeepSage,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: HiPopColors.darkTextTertiary,
                  ),
                ],
              ),
            ),
          ),

          // Notifications in this group
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: notifications.map((notification) {
                final data = notification.data() as Map<String, dynamic>;
                return _buildNotificationCard(
                  notification.id,
                  data,
                );
              }).toList(),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Build individual notification card
  Widget _buildNotificationCard(String notificationId, Map<String, dynamic> data) {
    final bool isRead = data['read'] ?? false;
    final String? type = data['type'];
    final String? title = data['title'] ?? _formatNotificationType(type);
    final String? body = data['body'] ?? data['message'] ?? '';
    final timestamp = data['createdAt']?.toDate() ?? DateTime.now();

    return Dismissible(
      key: Key(notificationId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: HiPopColors.errorPlum,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 24,
        ),
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        return true;
      },
      onDismissed: (direction) {
        _deleteNotification(notificationId);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _handleNotificationTap(data, notificationId);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isRead
                    ? HiPopColors.darkSurface
                    : HiPopColors.darkSurfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isRead
                      ? Colors.transparent
                      : HiPopColors.primaryDeepSage.withOpacity( 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon container with type-specific color
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getNotificationColor(type).withOpacity( 0.2),
                          _getNotificationColor(type).withOpacity( 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getNotificationIcon(type),
                      size: 22,
                      color: _getNotificationColor(type),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row with unread indicator
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title ?? 'Notification',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                                  color: HiPopColors.darkTextPrimary,
                                  height: 1.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isRead) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: HiPopColors.primaryDeepSage,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Body text
                        if (body != null && body.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            body,
                            style: TextStyle(
                              fontSize: 13,
                              color: isRead
                                  ? HiPopColors.darkTextTertiary
                                  : HiPopColors.darkTextSecondary,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        // Metadata row
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Type badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _getNotificationColor(type).withOpacity( 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatNotificationType(type),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getNotificationColor(type),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Time
                            Text(
                              _formatRelativeTime(timestamp),
                              style: const TextStyle(
                                fontSize: 12,
                                color: HiPopColors.darkTextTertiary,
                              ),
                            ),
                            const Spacer(),
                            // Chevron indicator
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: HiPopColors.darkTextTertiary.withOpacity( 0.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Format relative time for display
  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }
}