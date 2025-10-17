import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/shared/models/waitlist_models.dart';
import 'package:atv_events/features/shared/services/waitlist_service.dart';
import 'package:atv_events/features/shopper/widgets/waitlist_position_card.dart';

/// Screen showing all shopper's waitlist entries
/// Displays current position, status, and allows management
class MyWaitlistsScreen extends StatefulWidget {
  const MyWaitlistsScreen({super.key});

  @override
  State<MyWaitlistsScreen> createState() => _MyWaitlistsScreenState();
}

class _MyWaitlistsScreenState extends State<MyWaitlistsScreen> {
  final WaitlistService _waitlistService = WaitlistService();

  Stream<List<WaitlistEntry>> _getMyWaitlists() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _waitlistService.getUserWaitlistEntries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        backgroundColor: HiPopColors.darkSurface,
        title: const Text(
          'My Waitlists',
          style: TextStyle(
            color: HiPopColors.darkTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: HiPopColors.darkTextPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<List<WaitlistEntry>>(
        stream: _getMyWaitlists(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: HiPopColors.primaryDeepSage,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: HiPopColors.errorPlum,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load waitlists',
                    style: TextStyle(
                      color: HiPopColors.darkTextPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      color: HiPopColors.darkTextSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        // Trigger rebuild to retry
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(
                      foregroundColor: HiPopColors.primaryDeepSage,
                    ),
                  ),
                ],
              ),
            );
          }

          final waitlists = snapshot.data ?? [];

          if (waitlists.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                // Trigger rebuild to refresh
                setState(() {});
                await Future.delayed(const Duration(seconds: 1));
              },
              backgroundColor: HiPopColors.darkSurface,
              color: HiPopColors.primaryDeepSage,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: HiPopColors.warningAmber.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.access_time,
                              size: 64,
                              color: HiPopColors.warningAmber,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'No Waitlists Yet',
                            style: TextStyle(
                              color: HiPopColors.darkTextPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 48),
                            child: Text(
                              'Join a waitlist to be notified when sold-out products become available',
                              style: TextStyle(
                                color: HiPopColors.darkTextSecondary,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Group waitlists by status
          final notifiedWaitlists = waitlists
              .where((w) => w.status == WaitlistStatus.notified)
              .toList();
          final waitingWaitlists = waitlists
              .where((w) => w.status == WaitlistStatus.waiting)
              .toList();
          final completedWaitlists = waitlists
              .where((w) =>
                  w.status == WaitlistStatus.claimed ||
                  w.status == WaitlistStatus.expired ||
                  w.status == WaitlistStatus.cancelled)
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              // Trigger rebuild to refresh
              setState(() {});
              await Future.delayed(const Duration(seconds: 1));
            },
            backgroundColor: HiPopColors.darkSurface,
            color: HiPopColors.primaryDeepSage,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Available to claim section
                if (notifiedWaitlists.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Available to Claim',
                    icon: Icons.notifications_active,
                    color: HiPopColors.successGreen,
                  ),
                  const SizedBox(height: 12),
                  ...notifiedWaitlists.map((entry) => WaitlistPositionCard(
                        entry: entry,
                        onLeaveWaitlist: () {
                          setState(() {});
                        },
                        onClaim: () {
                          // Handle claim action
                        },
                      )),
                  const SizedBox(height: 24),
                ],

                // Waiting section
                if (waitingWaitlists.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Waiting',
                    icon: Icons.access_time,
                    color: HiPopColors.warningAmber,
                    count: waitingWaitlists.length,
                  ),
                  const SizedBox(height: 12),
                  ...waitingWaitlists.map((entry) => WaitlistPositionCard(
                        entry: entry,
                        onLeaveWaitlist: () {
                          setState(() {});
                        },
                      )),
                  const SizedBox(height: 24),
                ],

                // Completed section
                if (completedWaitlists.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Completed',
                    icon: Icons.history,
                    color: HiPopColors.darkTextTertiary,
                  ),
                  const SizedBox(height: 12),
                  ...completedWaitlists.map((entry) => WaitlistPositionCard(
                        entry: entry,
                      )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    String title, {
    required IconData icon,
    required Color color,
    int? count,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: HiPopColors.darkTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}