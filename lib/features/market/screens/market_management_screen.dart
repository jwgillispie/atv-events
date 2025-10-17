import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import 'package:atv_events/features/shared/services/user/user_profile_service.dart';
import 'package:atv_events/features/shared/widgets/common/loading_widget.dart';
import '../../market/models/market.dart';
import '../../market/services/market_service.dart';
import '../../premium/services/subscription_service.dart';
import '../../shared/services/analytics/real_time_analytics_service.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/organizer/services/vendor_management/vendor_post_service.dart';

class MarketManagementScreen extends StatefulWidget {
  final bool isEmbedded;

  const MarketManagementScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<MarketManagementScreen> createState() => MarketManagementScreenState();
}

class MarketManagementScreenState extends State<MarketManagementScreen>
    with AutomaticKeepAliveClientMixin {
  final String? _organizerId = FirebaseAuth.instance.currentUser?.uid;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Market> _markets = [];
  List<Market> _filteredMarkets = [];
  bool _isLoading = true;
  bool _showPastMarkets = false;
  bool _canCreateMarkets = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadMarkets();
  }

  // Public method to refresh markets from parent widget
  Future<void> refreshMarkets() async {
    await _loadMarkets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMarkets({bool showRefreshFeedback = false}) async {
    // Only show loading indicator on initial load, not on refresh
    if (_markets.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      // Load markets directly from Firebase for this organizer
      final marketsSnapshot = await FirebaseFirestore.instance
          .collection('markets')
          .where('organizerId', isEqualTo: _organizerId)
          .orderBy('eventDate', descending: false)
          .get();

      final markets = marketsSnapshot.docs
          .map((doc) => Market.fromFirestore(doc))
          .toList();

      // Check if user can create markets
      if (mounted) {
        final authState = context.read<AuthBloc>().state;
        if (authState is Authenticated && authState.userProfile != null) {
          final canCreate = await SubscriptionService.canCreateMarket(
            authState.userProfile!.userId,
          );

          if (mounted) {
            setState(() {
              _markets = markets;
              _filterMarkets();
              _canCreateMarkets = canCreate;
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _markets = markets;
            _filterMarkets();
            _isLoading = false;
          });
        }
      }

      // Show success feedback only for manual refresh via pull-to-refresh
      if (showRefreshFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Markets refreshed'),
            backgroundColor: HiPopColors.organizerAccent,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading markets: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterMarkets() {
    final now = DateTime.now();
    var filtered = _markets.where((market) {
      final isUpcoming = market.eventDate.isAfter(now);
      return _showPastMarkets ? !isUpcoming : isUpcoming;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((market) =>
        market.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        market.city.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        market.address.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    setState(() {
      _filteredMarkets = filtered;
    });
  }

  Future<void> _showCreateMarketDialog() async {
    // Check if user can create markets before showing dialog
    if (!_canCreateMarkets) {
      _showMarketLimitReachedDialog();
      return;
    }

    // Navigate to the create market screen
    final result = await context.push<bool>('/organizer/create-market');

    // Always reload markets when returning from the create screen
    // This ensures the list is up-to-date whether market was created or not
    await _loadMarkets();

    // Show success message if market was created
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Market created successfully!'),
          backgroundColor: HiPopColors.successGreen,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _navigateToMarketDetail(Market market) async {
    // Navigate to edit market screen
    await context.push('/organizer/edit-market/${market.id}');
    // Reload markets when returning to ensure any changes are reflected
    await _loadMarkets();
  }

  Future<void> _navigateToMarketVendors(Market market) async {
    // Navigate to vendor management screen for this specific market
    await context.push('/organizer/vendor-management?marketId=${market.id}');
  }


  Future<void> _editMarket(Market market) async {
    // Navigate to the full-screen edit market screen
    final result = await context.push<bool>('/organizer/edit-market/${market.id}');

    // Always refresh when returning from edit screen
    await _loadMarkets();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Market updated successfully!'),
          backgroundColor: HiPopColors.successGreen,
        ),
      );
    }
  }

  Future<void> _toggleMarketStatus(Market market) async {
    try {
      final updatedMarket = market.copyWith(isActive: !market.isActive);
      await MarketService.updateMarket(updatedMarket.id, updatedMarket.toFirestore());
      await _loadMarkets();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${market.name} ${market.isActive ? 'deactivated' : 'activated'}',
            ),
            backgroundColor: market.isActive ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating market status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteMarket(Market market) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        title: Text('Delete Market', style: TextStyle(color: HiPopColors.darkTextPrimary)),
        content: Text(
          'Are you sure you want to delete "${market.name}"?\n\n'
          'This will also remove all associated vendors. '
          'This action cannot be undone.',
          style: TextStyle(color: HiPopColors.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: HiPopColors.darkTextTertiary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete associated recruitment post if exists
        try {
          final posts = await OrganizerVendorPostService.getOrganizerPosts(
            market.organizerId ?? '',
            marketId: market.id,
          );
          for (final post in posts) {
            await OrganizerVendorPostService.deleteVendorPost(post.id);
            debugPrint('✅ Deleted recruitment post ${post.id} for market ${market.id}');
          }
        } catch (e) {
          debugPrint('⚠️ Failed to delete recruitment posts: $e');
          // Continue with market deletion even if recruitment post deletion fails
        }

        await MarketService.deleteMarket(market.id);

        // Remove from user profile
        if (mounted) {
          final authState = context.read<AuthBloc>().state;
          if (authState is Authenticated && authState.userProfile != null) {
            final userProfileService = UserProfileService();
            final updatedProfile = authState.userProfile!.removeManagedMarket(market.id);
            await userProfileService.updateUserProfile(updatedProfile);
          }
        }

        await _loadMarkets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${market.name} deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting market: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showMarketLimitReachedDialog() {
    // Track analytics for limit dialog shown
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated && authState.userProfile != null) {
      RealTimeAnalyticsService.trackEvent(
        'market_limit_dialog_shown',
        {
          'user_type': 'market_organizer',
          'current_market_count': _markets.length,
          'limit': 2,
          'is_premium': false,
          'source': 'market_management_screen',
        },
        userId: authState.userProfile!.userId,
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 8),
            Text('Market Limit Reached', style: TextStyle(color: HiPopColors.darkTextPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have reached your free tier limit of 2 markets.',
              style: TextStyle(fontSize: 16, color: HiPopColors.darkTextPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Usage: ${_markets.length} of 2 markets',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Upgrade to Market Organizer Pro for unlimited markets!',
                    style: TextStyle(color: Colors.orange[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pro Benefits:',
              style: TextStyle(fontWeight: FontWeight.bold, color: HiPopColors.darkTextPrimary),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• Unlimited markets', style: TextStyle(color: HiPopColors.darkTextSecondary)),
                Text('• Advanced analytics', style: TextStyle(color: HiPopColors.darkTextSecondary)),
                Text('• Vendor recruitment tools', style: TextStyle(color: HiPopColors.darkTextSecondary)),
                Text('• Priority support', style: TextStyle(color: HiPopColors.darkTextSecondary)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: HiPopColors.darkTextTertiary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToUpgrade();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.organizerAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  void _navigateToUpgrade() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated && authState.userProfile != null) {
      // Track analytics for upgrade button click
      RealTimeAnalyticsService.trackEvent(
        'upgrade_button_clicked',
        {
          'user_type': 'market_organizer',
          'source': 'market_management_screen',
          'current_market_count': _markets.length,
          'limit': 2,
          'is_premium': false,
        },
        userId: authState.userProfile!.userId,
      );

      // Navigate to premium upgrade flow for market organizers
      context.go('/premium/upgrade?tier=market_organizer&userId=${authState.userProfile!.userId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // When embedded, return just the body content
    if (widget.isEmbedded) {
      return _buildBodyContent();
    }

    // When standalone, return full Scaffold with AppBar
    return Scaffold(
          appBar: AppBar(
            title: const Text('Market Management'),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    HiPopColors.secondarySoftSage,
                    HiPopColors.accentMauve,
                  ],
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
            foregroundColor: HiPopColors.darkTextPrimary,
            actions: [
              TextButton.icon(
                icon: Icon(
                  _showPastMarkets ? Icons.upcoming : Icons.history,
                  size: 18,
                  color: HiPopColors.organizerAccent,
                ),
                label: Text(
                  _showPastMarkets ? 'Upcoming' : 'Past',
                  style: const TextStyle(
                    color: HiPopColors.organizerAccent,
                    fontSize: 14,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _showPastMarkets = !_showPastMarkets;
                    _filterMarkets();
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadMarkets,
                tooltip: 'Refresh markets',
              ),
            ],
          ),
          body: _buildBodyContent(),
          floatingActionButton: _buildFloatingActionButton(),
        );
  }

  Widget _buildBodyContent() {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      body: _isLoading
          ? const LoadingWidget(message: 'Loading markets...')
          : RefreshIndicator(
              onRefresh: () => _loadMarkets(showRefreshFeedback: true),
              color: HiPopColors.organizerAccent,
              backgroundColor: HiPopColors.darkSurface,
              displacement: 40,
              child: _filteredMarkets.isEmpty
                  ? CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: _buildSearchBar(),
                        ),
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          _buildSearchBar(),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredMarkets.length,
                            itemBuilder: (context, index) {
                              final market = _filteredMarkets[index];
                              return _buildMarketCard(market);
                            },
                          ),
                        ],
                      ),
                    ),
            ),
      floatingActionButton: widget.isEmbedded ? _buildFloatingActionButton() : null,
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _canCreateMarkets ? _showCreateMarketDialog : _showMarketLimitReachedDialog,
      backgroundColor: _canCreateMarkets ? HiPopColors.organizerAccent : Colors.grey,
      icon: Icon(_canCreateMarkets ? Icons.add : Icons.lock, color: Colors.white),
      label: Text(
        _canCreateMarkets ? 'New Market' : 'Limit Reached',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }


  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkBackground,
        border: Border(bottom: BorderSide(color: HiPopColors.darkBorder)),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: HiPopColors.darkTextPrimary),
        decoration: InputDecoration(
          hintText: 'Search markets...',
          hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
          prefixIcon: Icon(Icons.search, color: HiPopColors.darkTextTertiary),
          filled: true,
          fillColor: HiPopColors.darkBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: HiPopColors.darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: HiPopColors.darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: HiPopColors.accentMauve),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
          _filterMarkets();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    // Check if we have no markets at all
    final hasNoMarkets = _markets.isEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasNoMarkets
                ? Icons.store
                : (_showPastMarkets ? Icons.history : Icons.calendar_today),
            size: 80,
            color: HiPopColors.darkTextTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            hasNoMarkets
                ? 'No markets yet'
                : _showPastMarkets
                    ? 'No past markets'
                    : 'No upcoming markets',
            style: TextStyle(
              fontSize: 18,
              color: HiPopColors.darkTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasNoMarkets
                ? 'Create your first market to get started'
                : _showPastMarkets
                    ? 'Your past markets will appear here'
                    : _searchQuery.isNotEmpty
                        ? 'Try adjusting your search'
                        : 'All your markets are in the past',
            style: TextStyle(
              fontSize: 14,
              color: HiPopColors.darkTextTertiary,
            ),
          ),
          if ((hasNoMarkets || (!_showPastMarkets && _searchQuery.isEmpty)) && !_isLoading) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _canCreateMarkets ? _showCreateMarketDialog : _showMarketLimitReachedDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canCreateMarkets ? HiPopColors.organizerAccent : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: Icon(_canCreateMarkets ? Icons.add : Icons.lock),
              label: Text(_canCreateMarkets ? 'Create Market' : 'Limit Reached'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarketCard(Market market) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final vendorCount = market.associatedVendorIds.length;
    final isUpcoming = market.eventDate.isAfter(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: HiPopColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUpcoming
              ? HiPopColors.organizerAccent.withValues(alpha: 0.3)
              : HiPopColors.darkBorder,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToMarketDetail(market),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            market.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: HiPopColors.darkTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${market.address}, ${market.city}, ${market.state}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          if (market.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              market.description!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: market.isActive
                            ? HiPopColors.successGreen.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: market.isActive
                              ? HiPopColors.successGreen.withValues(alpha: 0.3)
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            market.isActive ? Icons.check_circle : Icons.pause_circle,
                            size: 14,
                            color: market.isActive ? HiPopColors.successGreen : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            market.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: market.isActive ? HiPopColors.successGreen : Colors.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isUpcoming) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: HiPopColors.organizerAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'UPCOMING',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: HiPopColors.organizerAccent,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // Date and time
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: HiPopColors.darkTextTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateFormat.format(market.eventDate),
                      style: TextStyle(
                        fontSize: 14,
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: HiPopColors.darkTextTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${market.startTime} - ${market.endTime}',
                      style: TextStyle(
                        fontSize: 14,
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Vendor count
                Row(
                  children: [
                    Icon(
                      Icons.store,
                      size: 16,
                      color: HiPopColors.vendorAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$vendorCount vendors',
                      style: TextStyle(
                        fontSize: 14,
                        color: HiPopColors.vendorAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Event Schedule:',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    market.eventDisplayInfo,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.teal[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              // Action buttons only for upcoming markets
              if (isUpcoming) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editMarket(market),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HiPopColors.organizerAccent,
                      side: BorderSide(color: HiPopColors.organizerAccent),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToMarketVendors(market),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HiPopColors.vendorAccent,
                      side: BorderSide(color: HiPopColors.vendorAccent),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.groups, size: 16),
                    label: const Text('Vendors'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _toggleMarketStatus(market),
                  icon: Icon(
                    market.isActive ? Icons.pause_circle : Icons.play_circle,
                    color: market.isActive ? Colors.orange : HiPopColors.successGreen,
                  ),
                  tooltip: market.isActive ? 'Deactivate' : 'Activate',
                ),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: HiPopColors.darkTextTertiary),
                  color: HiPopColors.darkSurface,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: const Icon(Icons.delete, color: Colors.red),
                        title: const Text('Delete', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteMarket(market);
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    ),
    ),
    );
  }

}