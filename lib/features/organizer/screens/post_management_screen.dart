import 'package:flutter/material.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/market/screens/market_management_screen.dart';
import 'package:atv_events/features/organizer/screens/events/organizer_event_management_screen.dart';
import 'package:atv_events/features/organizer/widgets/organizer_calendar_modal.dart';

/// PostManagementScreen - Container for Markets and Events with Material Design 3 TabBar
///
/// This screen implements a sophisticated tab-based interface that unifies market and event
/// management under a single "Post" concept. It follows Google/Meta design standards with:
/// - Cohesive color theming using HiPopColors
/// - State preservation using IndexedStack
/// - Context-aware floating action button
/// - Smooth transitions and premium user experience
class PostManagementScreen extends StatefulWidget {
  const PostManagementScreen({super.key});

  @override
  State<PostManagementScreen> createState() => _PostManagementScreenState();
}

class _PostManagementScreenState extends State<PostManagementScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin, WidgetsBindingObserver {

  late TabController _tabController;
  final GlobalKey<MarketManagementScreenState> _marketKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh markets when app comes back to foreground
      _marketKey.currentState?.refreshMarkets();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  void _showCalendarModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: HiPopColors.darkBackground,
      builder: (context) => const OrganizerCalendarModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text(
          'HiPop Post',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: HiPopColors.darkSurface,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'View Calendar',
            onPressed: () => _showCalendarModal(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Markets'),
            Tab(text: 'Events'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe to maintain state
        children: [
          // Markets Tab - wrapped to hide internal scaffold elements
          MarketManagementScreen(key: _marketKey, isEmbedded: true),
          // Events Tab
          const OrganizerEventManagementScreen(),
        ],
      ),
    );
  }
}