import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_event.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/blocs/favorites/favorites_bloc.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/core/constants/ui_constants.dart';
import 'package:hipop/features/auth/services/onboarding_service.dart';
import 'package:hipop/features/shared/models/user_feedback.dart';
import 'package:hipop/features/shared/services/user/specialized_account_deletion_service.dart';
import 'package:hipop/features/shared/services/user/user_feedback_service.dart';
import 'package:hipop/features/premium/services/subscription_service.dart';
import 'package:hipop/features/premium/models/user_subscription.dart';
import 'package:hipop/features/tickets/screens/my_tickets_screen.dart';
import 'package:hipop/features/shopper/screens/scanner/shopper_qr_scanner_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Shopper Profile Screen
/// Contains user info, settings, and account management
class ShopperProfileScreen extends StatefulWidget {
  const ShopperProfileScreen({super.key});

  @override
  State<ShopperProfileScreen> createState() => _ShopperProfileScreenState();
}

class _ShopperProfileScreenState extends State<ShopperProfileScreen>
    with AutomaticKeepAliveClientMixin {
  UserSubscription? _subscription;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load subscription info
      final subscription = await SubscriptionService.getUserSubscription(user.uid);

      setState(() {
        _subscription = subscription;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Stream to get unread notifications count
  Stream<int> _getUnreadNotificationsCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('notification_logs')
        .where('userId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Scaffold(
          backgroundColor: HiPopColors.darkBackground,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Profile',
              style: TextStyle(
                color: HiPopColors.darkTextPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            centerTitle: true,
            actions: [
              // Favorites button with badge
              BlocBuilder<FavoritesBloc, FavoritesState>(
                builder: (context, favoritesState) {
                  final totalFavorites = favoritesState.totalFavorites;
                  return Stack(
                    children: [
                      IconButton(
                        onPressed: () => context.pushNamed('favorites'),
                        icon: const Icon(Icons.favorite_outline, color: HiPopColors.darkTextPrimary),
                        tooltip: 'My Favorites',
                      ),
                      if (totalFavorites > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: HiPopColors.shopperAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$totalFavorites',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              // Calendar button
              IconButton(
                onPressed: () => context.pushNamed('shopperCalendar'),
                icon: const Icon(Icons.calendar_today_outlined, color: HiPopColors.darkTextPrimary),
                tooltip: 'Market Calendar',
              ),
            ],
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: HiPopColors.shopperAccent,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUserData,
                  color: HiPopColors.shopperAccent,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(UIConstants.defaultPadding),
                    child: Column(
                      children: [
                        // User header section
                        _buildUserHeader(state),
                        const SizedBox(height: UIConstants.largeSpacing),

                        // Quick Action Cards - prominent and easy to tap
                        _buildQuickActionCards(),
                        const SizedBox(height: UIConstants.largeSpacing),

                        // Menu sections
                        _buildMenuSection(
                          'Shopping',
                          [
                            _MenuItem(
                              icon: Icons.confirmation_number_outlined,
                              title: 'My Tickets',
                              subtitle: 'View your event tickets',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const MyTicketsScreen(),
                                ),
                              ),
                            ),
                            _MenuItem(
                              icon: Icons.hourglass_empty,
                              title: 'My Waitlists',
                              subtitle: 'Products you\'re waiting for',
                              onTap: () => context.push('/shopper/waitlists'),
                            ),
                            _MenuItem(
                              icon: Icons.favorite_outline,
                              title: 'Favorites',
                              subtitle: 'Your saved items',
                              onTap: () => context.pushNamed('favorites'),
                              trailing: _buildFavoritesCount(),
                            ),
                            _MenuItem(
                              icon: Icons.star_outline,
                              title: 'My Reviews',
                              subtitle: 'Reviews you\'ve written',
                              onTap: () => context.push('/shopper/review-history'),
                            ),
                          ],
                        ),
                        const SizedBox(height: UIConstants.defaultPadding),

                        // Account section removed - Edit Profile, Addresses, Payment Methods, Notifications not implemented

                        _buildMenuSection(
                          'Settings',
                          [
                            _MenuItem(
                              icon: Icons.lock_outline,
                              title: 'Change Password',
                              subtitle: 'Update your password',
                              onTap: _changePassword,
                            ),
                            if (_subscription != null && _subscription!.isActive)
                              _MenuItem(
                                icon: Icons.workspace_premium,
                                title: 'Premium Subscription',
                                subtitle: 'Manage subscription',
                                onTap: () => context.pushNamed('subscriptionManagement'),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: HiPopColors.premiumGold,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'ACTIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: UIConstants.defaultPadding),

                        _buildMenuSection(
                          'Support',
                          [
                            _MenuItem(
                              icon: Icons.feedback_outlined,
                              title: 'Send Feedback',
                              subtitle: 'Help us improve',
                              onTap: _showFeedbackDialog,
                            ),
                            _MenuItem(
                              icon: Icons.help_outline,
                              title: 'Help & Support',
                              subtitle: 'Get assistance',
                              onTap: () => context.push('/support'),
                            ),
                            _MenuItem(
                              icon: Icons.article_outlined,
                              title: 'Terms & Privacy',
                              subtitle: 'Legal documents',
                              onTap: () => context.pushNamed('legal'),
                            ),
                            if (kDebugMode)
                              _MenuItem(
                                icon: Icons.refresh,
                                title: 'Reset Tutorial',
                                subtitle: 'Show onboarding again',
                                onTap: _resetOnboarding,
                              ),
                          ],
                        ),
                        const SizedBox(height: UIConstants.largeSpacing),

                        // Sign out button
                        _buildSignOutButton(),
                        const SizedBox(height: UIConstants.defaultPadding),

                        // Delete account button
                        _buildDeleteAccountButton(),
                        const SizedBox(height: UIConstants.largeSpacing),

                        // App version
                        Text(
                          'Version 1.3.0',
                          style: TextStyle(
                            color: HiPopColors.darkTextTertiary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: UIConstants.extraLargeSpacing),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildUserHeader(Authenticated state) {
    final user = state.user;

    return Container(
      padding: const EdgeInsets.all(UIConstants.defaultPadding),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity( 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 40,
            backgroundColor: HiPopColors.shopperAccent,
            backgroundImage: user.photoURL != null
                ? CachedNetworkImageProvider(user.photoURL!)
                : null,
            child: user.photoURL == null
                ? Text(
                    (user.displayName?.isNotEmpty ?? false)
                        ? user.displayName![0].toUpperCase()
                        : user.email![0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: UIConstants.defaultPadding),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName ?? 'Shopper',
                  style: const TextStyle(
                    color: HiPopColors.darkTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? '',
                  style: const TextStyle(
                    color: HiPopColors.darkTextSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Edit button removed - not implemented
        ],
      ),
    );
  }

  Widget _buildQuickActionCards() {
    return Row(
      children: [
        // Notifications Card
        Expanded(
          child: StreamBuilder<int>(
            stream: _getUnreadNotificationsCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;

              return InkWell(
                onTap: () => context.pushNamed('notificationsInbox'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 120,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        HiPopColors.darkSurface,
                        HiPopColors.darkSurfaceVariant,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: unreadCount > 0
                          ? HiPopColors.warningAmber.withOpacity(0.3)
                          : HiPopColors.darkBorder,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: unreadCount > 0
                            ? HiPopColors.warningAmber.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: unreadCount > 0
                                  ? HiPopColors.warningAmber.withOpacity(0.2)
                                  : HiPopColors.shopperAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              unreadCount > 0
                                  ? Icons.notifications_active
                                  : Icons.notifications_outlined,
                              color: unreadCount > 0
                                  ? HiPopColors.warningAmber
                                  : HiPopColors.shopperAccent,
                              size: 24,
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: HiPopColors.warningAmber,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications',
                            style: const TextStyle(
                              color: HiPopColors.darkTextPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            unreadCount > 0
                                ? '$unreadCount unread'
                                : 'All caught up!',
                            style: TextStyle(
                              color: unreadCount > 0
                                  ? HiPopColors.warningAmber
                                  : HiPopColors.darkTextSecondary,
                              fontSize: 12,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        // QR Scanner Card
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ShopperQRScannerScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 120,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    HiPopColors.darkSurface,
                    HiPopColors.darkSurfaceVariant,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: HiPopColors.darkBorder,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: HiPopColors.primaryDeepSage.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner,
                          color: HiPopColors.primaryDeepSage,
                          size: 24,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: HiPopColors.darkTextTertiary,
                        size: 16,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'QR Scanner',
                        style: TextStyle(
                          color: HiPopColors.darkTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scan to review',
                        style: TextStyle(
                          color: HiPopColors.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildMenuSection(String title, List<_MenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: HiPopColors.darkTextSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: HiPopColors.darkSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: items.map((item) {
              final isLast = items.last == item;
              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      item.icon,
                      color: HiPopColors.darkTextSecondary,
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(
                        color: HiPopColors.darkTextPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: item.subtitle != null
                        ? Text(
                            item.subtitle!,
                            style: const TextStyle(
                              color: HiPopColors.darkTextTertiary,
                              fontSize: 12,
                            ),
                          )
                        : null,
                    trailing: item.trailing ?? const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: HiPopColors.darkTextTertiary,
                    ),
                    onTap: item.onTap,
                  ),
                  if (!isLast)
                    const Divider(
                      height: 1,
                      indent: 56,
                      color: HiPopColors.darkBorder,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFavoritesCount() {
    return BlocBuilder<FavoritesBloc, FavoritesState>(
      builder: (context, state) {
        if (state.totalFavorites > 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: HiPopColors.shopperAccent.withOpacity( 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${state.totalFavorites}',
              style: const TextStyle(
                color: HiPopColors.shopperAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
        return const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: HiPopColors.darkTextTertiary,
        );
      },
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          context.read<AuthBloc>().add(LogoutEvent());
        },
        icon: const Icon(Icons.logout),
        label: const Text('Sign Out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: HiPopColors.darkTextSecondary,
          side: const BorderSide(color: HiPopColors.darkBorder),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
    return TextButton(
      onPressed: () {
        SpecializedAccountDeletionService.deleteShopperAccount(context);
      },
      child: const Text(
        'Delete Account',
        style: TextStyle(
          color: HiPopColors.errorPlum,
          fontSize: 14,
        ),
      ),
    );
  }


  void _changePassword() {
    context.pushNamed('shopperChangePassword');
  }

  Future<void> _resetOnboarding() async {
    try {
      await OnboardingService.resetShopperOnboarding();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tutorial reset! It will show again next time you restart the app.'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting tutorial: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  void _showFeedbackDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    FeedbackCategory selectedCategory = FeedbackCategory.general;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        title: const Text(
          'Send Feedback',
          style: TextStyle(color: HiPopColors.darkTextPrimary),
        ),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help us improve HiPop! Your feedback goes directly to our team.',
                  style: TextStyle(color: HiPopColors.darkTextSecondary),
                ),
                const SizedBox(height: 16),

                // Category selection
                const Text(
                  'Category:',
                  style: TextStyle(color: HiPopColors.darkTextPrimary),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<FeedbackCategory>(
                  value: selectedCategory,
                  dropdownColor: HiPopColors.darkSurfaceVariant,
                  style: const TextStyle(color: HiPopColors.darkTextPrimary),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: HiPopColors.darkBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  style: const TextStyle(color: HiPopColors.darkTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: HiPopColors.darkTextSecondary),
                    hintText: 'Brief summary of your feedback',
                    hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: HiPopColors.darkBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: HiPopColors.darkBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: HiPopColors.shopperAccent),
                    ),
                  ),
                  maxLength: 200,
                ),
                const SizedBox(height: 16),

                // Description
                TextField(
                  controller: descriptionController,
                  style: const TextStyle(color: HiPopColors.darkTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: HiPopColors.darkTextSecondary),
                    hintText: 'Please provide details about your feedback',
                    hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: HiPopColors.darkBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: HiPopColors.darkBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: HiPopColors.shopperAccent),
                    ),
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: HiPopColors.darkTextSecondary),
            ),
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
              backgroundColor: HiPopColors.shopperAccent,
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

  Future<void> _submitFeedback(
    FeedbackCategory category,
    String title,
    String description,
  ) async {
    try {
      final authBloc = context.read<AuthBloc>();
      final authState = authBloc.state;
      if (authState is! Authenticated) return;

      await UserFeedbackService.submitFeedback(
        userId: authState.user.uid,
        userType: authState.userType,
        userEmail: authState.user.email ?? '',
        userName: authState.user.displayName,
        category: category,
        title: title,
        description: description,
        metadata: {
          'screen': 'shopper_profile',
          'timestamp': DateTime.now().toIso8601String(),
          'appSection': 'profile',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback! We\'ll review it soon.'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending feedback: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });
}