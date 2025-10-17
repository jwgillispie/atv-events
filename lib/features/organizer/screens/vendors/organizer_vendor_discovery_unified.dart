import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/organizer/models/organizer_vendor_post.dart';
import 'package:hipop/features/organizer/services/vendor_management/vendor_directory_service.dart';
import 'package:hipop/features/organizer/services/vendor_management/vendor_post_service.dart';
import 'package:hipop/features/shared/widgets/common/error_widget.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
import 'package:hipop/features/shared/widgets/common/hipop_text_field.dart';
import 'package:hipop/features/vendor/services/engagement/vendor_contact_service.dart';
import 'package:hipop/features/shopper/screens/shopper_main_screen.dart';
import 'package:hipop/features/shared/blocs/application/application_bloc.dart';
import 'package:hipop/features/shared/blocs/application/application_event.dart';
import 'package:hipop/features/shared/blocs/application/application_state.dart';
import 'package:hipop/features/shared/models/vendor_application.dart';
import 'package:hipop/features/shared/widgets/applications/application_status_card.dart';

// View Mode Management
enum ViewMode { recruitment, directory, applications }

/// Unified Vendor Discovery & Recruitment Hub
/// World-class marketplace experience for market organizers
/// Combines vendor directory browsing with recruitment post management
class OrganizerVendorDiscoveryUnified extends StatefulWidget {
  const OrganizerVendorDiscoveryUnified({super.key});

  @override
  State<OrganizerVendorDiscoveryUnified> createState() =>
      _OrganizerVendorDiscoveryUnifiedState();
}

class _OrganizerVendorDiscoveryUnifiedState
    extends State<OrganizerVendorDiscoveryUnified>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {

  // Animation Controllers
  late AnimationController _modeTransitionController;
  late AnimationController _filterAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // View Mode Management
  ViewMode _currentMode = ViewMode.recruitment;

  // Data & State
  bool _isLoading = true;
  String? _error;

  // Recruitment Posts Data
  List<OrganizerVendorPost> _recruitmentPosts = [];
  String _postStatusFilter = 'active';

  // Vendor Directory Data
  List<Map<String, dynamic>> _vendors = [];
  final Set<String> _selectedVendorIds = {};
  bool _isBulkSelectionMode = false;

  // Applications Data
  List<VendorApplication> _applications = [];
  ApplicationStatus? _applicationFilterStatus;

  // Search & Filter Controllers
  final _searchController = TextEditingController();
  final _locationController = TextEditingController();
  final _scrollController = ScrollController();

  // Filter State
  List<String> _selectedCategories = [];
  String? _selectedExperienceLevel;
  double _minRating = 0.0;
  bool _onlyAvailable = false;
  bool _filtersExpanded = false;

  // Contact Service
  final VendorContactService _contactService = VendorContactService();

  // Category Options
  final List<String> _availableCategories = [
    'produce', 'baked_goods', 'prepared_foods', 'crafts', 'beverages',
    'health_beauty', 'flowers', 'meat_seafood', 'dairy', 'jewelry',
    'clothing', 'art', 'music', 'other'
  ];

  final List<String> _experienceLevels = [
    'Beginner', 'Intermediate', 'Experienced', 'Expert'
  ];

  // Analytics tracking
  DateTime? _lastInteractionTime;
  int _interactionCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    debugPrint('🟣 [VENDOR DISCOVERY] initState() called');
    _initializeAnimations();
    _checkPremiumAccessAndLoad();
    _setupScrollListener();
  }

  void _initializeAnimations() {
    _modeTransitionController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _modeTransitionController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _modeTransitionController,
      curve: Curves.easeOutCubic,
    ));

    _modeTransitionController.forward();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Implement infinite scroll if needed
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        // Load more items
      }
    });
  }

  @override
  void dispose() {
    _modeTransitionController.dispose();
    _filterAnimationController.dispose();
    _searchController.dispose();
    _locationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkPremiumAccessAndLoad() async {
    debugPrint('🟡 [VENDOR DISCOVERY] _checkPremiumAccessAndLoad() called');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authState = context.read<AuthBloc>().state;
      debugPrint('🟡 [VENDOR DISCOVERY] Auth state type: ${authState.runtimeType}');

      if (authState is! Authenticated) {
        debugPrint('🔴 [VENDOR DISCOVERY] Not authenticated');
        setState(() {
          _error = 'Please log in to access Vendor Discovery';
          _isLoading = false;
        });
        return;
      }

      // Load initial data based on mode - no premium check needed for organizers
      debugPrint('🟡 [VENDOR DISCOVERY] Current mode: $_currentMode');
      await _loadDataForCurrentMode();

      setState(() => _isLoading = false);
      debugPrint('🟢 [VENDOR DISCOVERY] Loading complete');
    } catch (e) {
      debugPrint('🔴 [VENDOR DISCOVERY] Error in _checkPremiumAccessAndLoad: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDataForCurrentMode() async {
    if (_currentMode == ViewMode.recruitment) {
      await _loadRecruitmentPosts();
    } else if (_currentMode == ViewMode.directory) {
      await _searchVendors();
    } else if (_currentMode == ViewMode.applications) {
      // Applications are loaded via BLoC stream, just trigger event
      _loadApplications();
    }
  }

  void _loadApplications() {
    // Note: This requires market context. For now, we'll load across all markets
    // In production, you'd filter by a specific market
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      // For now, showing applications across all organizer's markets
      // You can enhance this to filter by specific market
      debugPrint('🟡 [APPLICATIONS] Loading applications for organizer: ${user.uid}');
    }
  }

  Future<void> _loadRecruitmentPosts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final posts = await OrganizerVendorPostService.getOrganizerPosts(
        user.uid,
        limit: 50,
        status: _postStatusFilter == 'all'
            ? null
            : PostStatus.values.firstWhere(
                (status) => status.name == _postStatusFilter,
                orElse: () => PostStatus.active,
              ),
      );

      setState(() => _recruitmentPosts = posts);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _searchVendors() async {
    try {
      final results = await VendorDirectoryService.searchVendors(
        searchQuery: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        categories: _selectedCategories.isEmpty
            ? null
            : _selectedCategories,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        experienceLevel: _selectedExperienceLevel,
        onlyAvailable: _onlyAvailable,
        limit: 50,
      );

      setState(() => _vendors = results);

      // Track interaction
      _trackInteraction('vendor_search');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _switchMode(ViewMode newMode) {
    if (_currentMode == newMode) return;

    debugPrint('🟣 [VENDOR DISCOVERY] Switching mode from $_currentMode to $newMode');
    HapticFeedback.lightImpact();

    setState(() {
      _currentMode = newMode;
      _selectedVendorIds.clear();
      _isBulkSelectionMode = false;
    });

    // Animate transition
    _modeTransitionController.reset();
    _modeTransitionController.forward();

    // Load data for new mode
    _loadDataForCurrentMode();

    _trackInteraction('mode_switch_$newMode');
  }

  void _trackInteraction(String action) {
    _lastInteractionTime = DateTime.now();
    _interactionCount++;
    // Implement analytics tracking
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          if (_error != null)
            SliverToBoxAdapter(
              child: ErrorDisplayWidget(
                title: 'Error',
                message: _error!,
                onRetry: _loadDataForCurrentMode,
              ),
            )
          else if (_isLoading)
            const SliverFillRemaining(
              child: LoadingWidget(message: 'Loading vendor discovery...'),
            )
          else ...[
            _buildModeToggleSection(),
            _buildFilterSection(),
            _buildContentSection(),
          ],
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: HiPopColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      title: const Text(
        'Vendors',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        // Map Icon with Enhanced Visual
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: HiPopColors.shopperAccent.withOpacity( 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              Icons.map_rounded,
              color: HiPopColors.shopperAccent,
              size: 22,
            ),
            tooltip: 'Browse as Shopper',
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ShopperMainScreen(),
                ),
              );
            },
          ),
        ),

        // Filter Icon with Enhanced Visual
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _hasActiveFilters()
                      ? HiPopColors.organizerAccent.withOpacity( 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: AnimatedRotation(
                    turns: _filtersExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.tune_rounded,
                      color: _hasActiveFilters()
                          ? HiPopColors.organizerAccent
                          : HiPopColors.darkTextSecondary,
                      size: 22,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _filtersExpanded = !_filtersExpanded);
                    if (_filtersExpanded) {
                      _filterAnimationController.forward();
                    } else {
                      _filterAnimationController.reverse();
                    }
                  },
                ),
              ),
              if (_hasActiveFilters())
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: HiPopColors.organizerAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: HiPopColors.darkSurface,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggleSection() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: HiPopColors.darkSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subtitle based on current mode
            Text(
              _currentMode == ViewMode.recruitment
                  ? 'Find and recruit top vendors for your markets'
                  : _currentMode == ViewMode.directory
                      ? 'Browse our curated vendor directory'
                      : 'Review vendor applications from your recruitment posts',
              style: TextStyle(
                color: HiPopColors.darkTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 12),
            // Toggle Container
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: HiPopColors.darkBackground,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: HiPopColors.organizerAccent.withOpacity( 0.2),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  // Animated Background Indicator
                  AnimatedAlign(
                    alignment: _currentMode == ViewMode.recruitment
                        ? Alignment.centerLeft
                        : _currentMode == ViewMode.directory
                            ? Alignment.center
                            : Alignment.centerRight,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.29,
                      height: 40,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: HiPopColors.organizerAccent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                  // Toggle Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildSimpleToggleButton(
                          ViewMode.recruitment,
                          Icons.campaign_rounded,
                          'Posts',
                        ),
                      ),
                      Expanded(
                        child: _buildSimpleToggleButton(
                          ViewMode.directory,
                          Icons.store_rounded,
                          'Directory',
                        ),
                      ),
                      Expanded(
                        child: _buildSimpleToggleButton(
                          ViewMode.applications,
                          Icons.inbox_rounded,
                          'Applications',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleToggleButton(
    ViewMode mode,
    IconData icon,
    String label,
  ) {
    final isSelected = _currentMode == mode;

    return GestureDetector(
      onTap: () => _switchMode(mode),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40, // Match the inner container height
        alignment: Alignment.center, // Center the content
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Take minimum space needed
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : HiPopColors.darkTextTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : HiPopColors.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedToggleButton(
    ViewMode mode,
    IconData icon,
    String label,
    String sublabel,
  ) {
    final isSelected = _currentMode == mode;

    return GestureDetector(
      onTap: () => _switchMode(mode),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.1 : 0.95,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? Colors.white
                    : HiPopColors.darkTextTertiary,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : HiPopColors.darkTextSecondary,
                    letterSpacing: isSelected ? 0.2 : 0,
                  ),
                ),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: isSelected
                        ? Colors.white.withOpacity( 0.9)
                        : HiPopColors.darkTextTertiary,
                    height: 1,
                  ),
                  child: Text(sublabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFilterSection() {
    if (!_filtersExpanded) return const SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _filterAnimationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _filterAnimationController,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, -0.1),
                end: Offset.zero,
              ).animate(_filterAnimationController),
              child: Container(
                decoration: BoxDecoration(
                  color: HiPopColors.darkSurface,
                  border: Border(
                    bottom: BorderSide(
                      color: HiPopColors.darkBorder,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Search Bar
                    if (_currentMode == ViewMode.directory)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildSearchField(),
                            const SizedBox(height: 12),
                            _buildLocationField(),
                          ],
                        ),
                      ),

                    // Filter Chips
                    _buildFilterChips(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: HiPopColors.darkBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HiPopColors.darkBorder,
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: HiPopColors.darkTextPrimary),
        decoration: InputDecoration(
          hintText: 'Search vendors by name or products...',
          hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
          prefixIcon: Icon(
            Icons.search,
            color: HiPopColors.darkTextSecondary,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: HiPopColors.darkTextSecondary,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _searchVendors();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onChanged: (_) {
          if (_searchController.text.isEmpty ||
              _searchController.text.length > 2) {
            _searchVendors();
          }
        },
      ),
    );
  }

  Widget _buildLocationField() {
    return Container(
      decoration: BoxDecoration(
        color: HiPopColors.darkBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HiPopColors.darkBorder,
          width: 1,
        ),
      ),
      child: TextField(
        controller: _locationController,
        style: TextStyle(color: HiPopColors.darkTextPrimary),
        decoration: InputDecoration(
          hintText: 'Filter by location...',
          hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
          prefixIcon: Icon(
            Icons.location_on,
            color: HiPopColors.darkTextSecondary,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onChanged: (_) => _searchVendors(),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_currentMode == ViewMode.recruitment) ...[
            _buildFilterChip(
              label: 'Active',
              isSelected: _postStatusFilter == 'active',
              onTap: () {
                setState(() => _postStatusFilter = 'active');
                _loadRecruitmentPosts();
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Paused',
              isSelected: _postStatusFilter == 'paused',
              onTap: () {
                setState(() => _postStatusFilter = 'paused');
                _loadRecruitmentPosts();
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Closed',
              isSelected: _postStatusFilter == 'closed',
              onTap: () {
                setState(() => _postStatusFilter = 'closed');
                _loadRecruitmentPosts();
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'All Posts',
              isSelected: _postStatusFilter == 'all',
              onTap: () {
                setState(() => _postStatusFilter = 'all');
                _loadRecruitmentPosts();
              },
            ),
          ] else ...[
            _buildFilterChip(
              label: _selectedCategories.isEmpty
                  ? 'All Categories'
                  : '${_selectedCategories.length} Categories',
              icon: Icons.category,
              onTap: _showCategoryDialog,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: _selectedExperienceLevel ?? 'All Experience',
              icon: Icons.trending_up,
              onTap: _showExperienceDialog,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: _minRating > 0
                  ? '${_minRating.toStringAsFixed(1)}+ ⭐'
                  : 'Any Rating',
              icon: Icons.star,
              onTap: _showRatingDialog,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Available Only',
              isSelected: _onlyAvailable,
              onTap: () {
                setState(() => _onlyAvailable = !_onlyAvailable);
                _searchVendors();
              },
            ),
            if (_hasActiveFilters()) ...[
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Clear All',
                icon: Icons.clear,
                onTap: _clearAllFilters,
                isDestructive: true,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    bool isSelected = false,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? HiPopColors.organizerAccent.withOpacity( 0.2)
              : HiPopColors.darkBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? HiPopColors.organizerAccent
                : isDestructive
                    ? HiPopColors.errorPlum.withOpacity( 0.5)
                    : HiPopColors.darkBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? HiPopColors.organizerAccent
                    : isDestructive
                        ? HiPopColors.errorPlum
                        : HiPopColors.darkTextSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? HiPopColors.organizerAccent
                    : isDestructive
                        ? HiPopColors.errorPlum
                        : HiPopColors.darkTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: _currentMode == ViewMode.recruitment
          ? _buildRecruitmentPostsContent()
          : _currentMode == ViewMode.directory
              ? _buildVendorDirectoryContent()
              : _buildApplicationsContent(),
    );
  }

  Widget _buildRecruitmentPostsContent() {
    debugPrint('🔴 [RECRUITMENT] _buildRecruitmentPostsContent called');

    if (_recruitmentPosts.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(
          icon: Icons.post_add,
          title: 'No Recruitment Posts',
          subtitle: 'Create your first vendor recruitment post to start finding vendors for your markets.',
          actionLabel: 'Create Post',
          onAction: () => context.push('/organizer/vendor-recruitment/create'),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final post = _recruitmentPosts[index];
          return _buildRecruitmentPostCard(post);
        },
        childCount: _recruitmentPosts.length,
      ),
    );
  }

  Widget _buildRecruitmentPostCard(OrganizerVendorPost post) {
    final statusColor = _getStatusColor(post.status);
    final hasApplications = post.analytics.responses > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          color: statusColor.withOpacity( 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity( 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/organizer/vendors/posts/${post.id}'),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity( 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.store,
                        color: statusColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: HiPopColors.darkTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity( 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  post.status.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Market: ${post.marketId}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: HiPopColors.darkTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Action Menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: HiPopColors.darkTextSecondary,
                      ),
                      onSelected: (value) => _handlePostAction(value, post),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              const SizedBox(width: 12),
                              Text('Edit Post'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: post.status == PostStatus.active
                              ? 'pause'
                              : 'activate',
                          child: Row(
                            children: [
                              Icon(
                                post.status == PostStatus.active
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Text(post.status == PostStatus.active
                                  ? 'Pause Post'
                                  : 'Activate Post'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete,
                                size: 18,
                                color: HiPopColors.errorPlum,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Delete Post',
                                style: TextStyle(color: HiPopColors.errorPlum),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Event Date
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: HiPopColors.organizerAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Deadline: ${post.requirements.applicationDeadline != null ? _formatDate(post.requirements.applicationDeadline!) : "No deadline"}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Categories Needed
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: post.categories.take(5).map((category) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: HiPopColors.organizerAccent.withOpacity( 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: HiPopColors.organizerAccent.withOpacity( 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _formatCategory(category),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: HiPopColors.organizerAccent,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Stats Row
                Row(
                  children: [
                    _buildStatChip(
                      icon: Icons.people,
                      label: '${post.analytics.views} views',
                      color: HiPopColors.successGreen,
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      icon: Icons.inbox,
                      label: '${post.analytics.responses} applications',
                      color: hasApplications
                          ? HiPopColors.warningAmber
                          : HiPopColors.darkTextTertiary,
                    ),
                    const Spacer(),
                    // View Applications Button
                    if (hasApplications)
                      TextButton.icon(
                        onPressed: () => context.push(
                          '/organizer/vendors/posts/${post.id}/responses',
                        ),
                        icon: Icon(
                          Icons.visibility,
                          size: 16,
                          color: HiPopColors.organizerAccent,
                        ),
                        label: Text(
                          'View',
                          style: TextStyle(
                            color: HiPopColors.organizerAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: HiPopColors.organizerAccent.withOpacity( 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity( 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorDirectoryContent() {
    debugPrint('🔴 [VENDOR DIRECTORY] _buildVendorDirectoryContent called');

    if (_vendors.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(
          icon: Icons.search_off,
          title: 'No Vendors Found',
          subtitle: 'Try adjusting your search filters or expanding your criteria to find more vendors.',
          actionLabel: 'Clear Filters',
          onAction: _clearAllFilters,
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final vendor = _vendors[index];
          return _buildVendorCard(vendor);
        },
        childCount: _vendors.length,
      ),
    );
  }

  Widget _buildVendorCard(Map<String, dynamic> vendor) {
    final vendorId = vendor['id'] ?? '';
    final isSelected = _selectedVendorIds.contains(vendorId);
    final hasPhone = vendor['phoneNumber']?.isNotEmpty == true;
    final hasInstagram = vendor['instagramHandle']?.isNotEmpty == true;
    final hasWebsite = vendor['website']?.isNotEmpty == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          color: isSelected
              ? HiPopColors.organizerAccent.withOpacity( 0.5)
              : HiPopColors.darkBorder,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? HiPopColors.organizerAccent.withOpacity( 0.2)
                : Colors.black.withOpacity( 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isBulkSelectionMode
              ? () => _toggleVendorSelection(vendorId)
              : null,
          onLongPress: () {
            HapticFeedback.mediumImpact();
            setState(() {
              _isBulkSelectionMode = true;
              _selectedVendorIds.add(vendorId);
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            HiPopColors.vendorAccent,
                            HiPopColors.vendorAccentLight,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (vendor['businessName'] ?? 'V')[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vendor['businessName'] ?? 'Unknown Vendor',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: HiPopColors.darkTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (vendor['experienceLevel'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getExperienceColor(
                                      vendor['experienceLevel'],
                                    ).withOpacity( 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    vendor['experienceLevel'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _getExperienceColor(
                                        vendor['experienceLevel'],
                                      ),
                                    ),
                                  ),
                                ),
                              if (vendor['rating'] != null) ...[
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 14,
                                      color: HiPopColors.warningAmber,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${vendor['rating'].toStringAsFixed(1)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: HiPopColors.warningAmber,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (vendor['marketsParticipated'] != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '${vendor['marketsParticipated']} markets',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: HiPopColors.darkTextTertiary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_isBulkSelectionMode)
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleVendorSelection(vendorId),
                        activeColor: HiPopColors.organizerAccent,
                      ),
                  ],
                ),

                // Bio
                if (vendor['bio']?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    vendor['bio'],
                    style: TextStyle(
                      fontSize: 14,
                      color: HiPopColors.darkTextSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Categories
                if (vendor['categories']?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: (vendor['categories'] as List).take(5).map((cat) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: HiPopColors.vendorAccent.withOpacity( 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: HiPopColors.vendorAccent.withOpacity( 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _formatCategory(cat.toString()),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: HiPopColors.vendorAccent,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Featured Items
                if (vendor['featuredItems']?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: 14,
                        color: HiPopColors.premiumGold,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Featured: ${vendor['featuredItems']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: HiPopColors.darkTextTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Contact Actions
                Row(
                  children: [
                    // Contact Buttons
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildContactButton(
                            icon: Icons.email,
                            color: HiPopColors.infoBlueGray,
                            onTap: () => _launchContact(
                              vendor['email'],
                              'email',
                            ),
                          ),
                          if (hasPhone)
                            _buildContactButton(
                              icon: Icons.phone,
                              color: HiPopColors.successGreen,
                              onTap: () => _launchContact(
                                vendor['phoneNumber'],
                                'phone',
                              ),
                            ),
                          if (hasInstagram)
                            _buildContactButton(
                              icon: Icons.camera_alt,
                              color: HiPopColors.vendorAccent,
                              onTap: () => _launchContact(
                                vendor['instagramHandle'],
                                'instagram',
                              ),
                            ),
                          if (hasWebsite)
                            _buildContactButton(
                              icon: Icons.web,
                              color: Colors.teal,
                              onTap: () => _launchContact(
                                vendor['website'],
                                'website',
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Contact Button
                    if (!_isBulkSelectionMode)
                      ElevatedButton.icon(
                        onPressed: () => _showVendorContactOptions(vendor),
                        icon: Icon(Icons.contact_mail, size: 16),
                        label: Text('Contact'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HiPopColors.organizerAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationsContent() {
    debugPrint('🔴 [APPLICATIONS] _buildApplicationsContent called');

    // For now showing placeholder - will be enhanced with full application management
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: HiPopColors.darkSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inbox_rounded,
                  size: 64,
                  color: HiPopColors.organizerAccent.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Applications Coming Soon',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Vendor applications from your recruitment posts will appear here.\nFull application management features are being integrated.',
                style: TextStyle(
                  fontSize: 14,
                  color: HiPopColors.darkTextSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // Switch to recruitment posts to create applications
                  _switchMode(ViewMode.recruitment);
                },
                icon: Icon(Icons.campaign_rounded),
                label: Text('Create Recruitment Post'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HiPopColors.organizerAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity( 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HiPopColors.darkSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: HiPopColors.darkTextTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: HiPopColors.darkTextSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                onAction();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.organizerAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                actionLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HiPopColors.darkBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: HiPopColors.organizerAccent.withOpacity( 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: HiPopColors.organizerAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: HiPopColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_isBulkSelectionMode && _selectedVendorIds.isNotEmpty) {
      return FloatingActionButton.extended(
        onPressed: _sendBulkInvitations,
        backgroundColor: HiPopColors.organizerAccent,
        icon: Icon(Icons.send, color: Colors.white),
        label: Text(
          'Invite ${_selectedVendorIds.length} Vendors',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (_currentMode == ViewMode.recruitment) {
      return FloatingActionButton(
        onPressed: () => context.push('/organizer/vendor-recruitment/create'),
        backgroundColor: HiPopColors.organizerAccent,
        child: Icon(Icons.add, color: Colors.white),
      );
    }

    return null;
  }

  // Helper Methods
  bool _hasActiveFilters() {
    return _selectedCategories.isNotEmpty ||
        _selectedExperienceLevel != null ||
        _minRating > 0 ||
        _onlyAvailable ||
        _searchController.text.isNotEmpty ||
        _locationController.text.isNotEmpty;
  }

  void _clearAllFilters() {
    setState(() {
      _selectedCategories.clear();
      _selectedExperienceLevel = null;
      _minRating = 0.0;
      _onlyAvailable = false;
      _searchController.clear();
      _locationController.clear();
    });
    _searchVendors();
  }

  void _toggleVendorSelection(String vendorId) {
    setState(() {
      if (_selectedVendorIds.contains(vendorId)) {
        _selectedVendorIds.remove(vendorId);
        if (_selectedVendorIds.isEmpty) {
          _isBulkSelectionMode = false;
        }
      } else {
        _selectedVendorIds.add(vendorId);
      }
    });
    HapticFeedback.lightImpact();
  }

  Color _getStatusColor(PostStatus status) {
    switch (status) {
      case PostStatus.active:
        return HiPopColors.successGreen;
      case PostStatus.paused:
        return HiPopColors.warningAmber;
      case PostStatus.closed:
      case PostStatus.expired:
        return HiPopColors.darkTextTertiary;
      default:
        return HiPopColors.darkTextSecondary;
    }
  }

  Color _getExperienceColor(String level) {
    switch (level.toLowerCase()) {
      case 'expert':
        return HiPopColors.premiumGold;
      case 'experienced':
        return HiPopColors.successGreen;
      case 'intermediate':
        return HiPopColors.warningAmber;
      case 'beginner':
      default:
        return HiPopColors.shopperAccent;
    }
  }

  String _formatCategory(String category) {
    return category
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // Dialog Methods
  void _showCategoryDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: HiPopColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CategoryFilterSheet(
        selectedCategories: _selectedCategories,
        availableCategories: _availableCategories,
        onApply: (categories) {
          setState(() => _selectedCategories = categories);
          _searchVendors();
        },
      ),
    );
  }

  void _showExperienceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: HiPopColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ExperienceFilterSheet(
        selectedLevel: _selectedExperienceLevel,
        levels: _experienceLevels,
        onApply: (level) {
          setState(() => _selectedExperienceLevel = level);
          _searchVendors();
        },
      ),
    );
  }

  void _showRatingDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: HiPopColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _RatingFilterSheet(
        currentRating: _minRating,
        onApply: (rating) {
          setState(() => _minRating = rating);
          _searchVendors();
        },
      ),
    );
  }

  // Action Methods
  void _handlePostAction(String action, OrganizerVendorPost post) {
    switch (action) {
      case 'edit':
        context.push('/organizer/vendors/posts/${post.id}/edit');
        break;
      case 'pause':
      case 'activate':
        _togglePostStatus(post);
        break;
      case 'delete':
        _confirmDeletePost(post);
        break;
    }
  }

  Future<void> _togglePostStatus(OrganizerVendorPost post) async {
    try {
      final newStatus = post.status == PostStatus.active
          ? PostStatus.paused
          : PostStatus.active;

      await OrganizerVendorPostService.updatePostStatus(post.id, newStatus);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post ${newStatus.name}'),
          backgroundColor: HiPopColors.successGreen,
        ),
      );

      _loadRecruitmentPosts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating post: $e'),
          backgroundColor: HiPopColors.errorPlum,
        ),
      );
    }
  }

  void _confirmDeletePost(OrganizerVendorPost post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        title: Text(
          'Delete Post',
          style: TextStyle(color: HiPopColors.darkTextPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${post.title}"? This action cannot be undone.',
          style: TextStyle(color: HiPopColors.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deletePost(post);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.errorPlum,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(OrganizerVendorPost post) async {
    try {
      await OrganizerVendorPostService.deleteVendorPost(post.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post deleted successfully'),
          backgroundColor: HiPopColors.successGreen,
        ),
      );
      _loadRecruitmentPosts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting post: $e'),
          backgroundColor: HiPopColors.errorPlum,
        ),
      );
    }
  }

  void _launchContact(String? value, String type) async {
    if (value == null || value.isEmpty) return;

    Uri? uri;
    switch (type) {
      case 'email':
        uri = Uri.parse('mailto:$value?subject=Market Opportunity');
        break;
      case 'phone':
        uri = Uri.parse('tel:$value');
        break;
      case 'instagram':
        final handle = value.startsWith('@') ? value.substring(1) : value;
        uri = Uri.parse('https://instagram.com/$handle');
        break;
      case 'website':
        uri = Uri.parse(value.startsWith('http') ? value : 'https://$value');
        break;
    }

    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      _trackInteraction('vendor_contact_$type');
    }
  }

  void _showVendorContactOptions(Map<String, dynamic> vendor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: HiPopColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.contact_mail, color: HiPopColors.organizerAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact ${vendor['businessName']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      if (vendor['tagline'] != null)
                        Text(
                          vendor['tagline'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: HiPopColors.darkTextSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Contact Options
            if (vendor['email'] != null) ...[
              _buildContactOption(
                icon: Icons.email,
                label: 'Email',
                value: vendor['email'],
                onTap: () => _launchContact('mailto:${vendor['email']}', 'email'),
              ),
              const Divider(height: 24, color: HiPopColors.darkBorder),
            ],

            if (vendor['phoneNumber'] != null) ...[
              _buildContactOption(
                icon: Icons.phone,
                label: 'Phone',
                value: vendor['phoneNumber'],
                onTap: () => _launchContact('tel:${vendor['phoneNumber']}', 'phone'),
              ),
              const Divider(height: 24, color: HiPopColors.darkBorder),
            ],

            if (vendor['website'] != null) ...[
              _buildContactOption(
                icon: Icons.web,
                label: 'Website',
                value: vendor['website'],
                onTap: () => _launchContact(vendor['website'], 'website'),
              ),
              const Divider(height: 24, color: HiPopColors.darkBorder),
            ],

            if (vendor['instagram'] != null) ...[
              _buildContactOption(
                icon: Icons.camera_alt,
                label: 'Instagram',
                value: '@${vendor['instagram']}',
                onTap: () => _launchContact('https://instagram.com/${vendor['instagram']}', 'instagram'),
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HiPopColors.organizerAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: HiPopColors.organizerAccent, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: HiPopColors.darkTextSecondary,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: HiPopColors.darkTextSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _sendBulkInvitations() async {
    // Implementation for bulk invitations
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sent ${_selectedVendorIds.length} invitations'),
        backgroundColor: HiPopColors.successGreen,
      ),
    );
    setState(() {
      _selectedVendorIds.clear();
      _isBulkSelectionMode = false;
    });
  }
}

// Filter Sheet Widgets
class _CategoryFilterSheet extends StatefulWidget {
  final List<String> selectedCategories;
  final List<String> availableCategories;
  final Function(List<String>) onApply;

  const _CategoryFilterSheet({
    required this.selectedCategories,
    required this.availableCategories,
    required this.onApply,
  });

  @override
  State<_CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends State<_CategoryFilterSheet> {
  late List<String> _tempSelected;

  @override
  void initState() {
    super.initState();
    _tempSelected = List.from(widget.selectedCategories);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter by Categories',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: HiPopColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: widget.availableCategories.map((category) {
                final isSelected = _tempSelected.contains(category);
                return CheckboxListTile(
                  title: Text(
                    category.split('_').map((w) =>
                      w[0].toUpperCase() + w.substring(1)
                    ).join(' '),
                    style: TextStyle(color: HiPopColors.darkTextPrimary),
                  ),
                  value: isSelected,
                  activeColor: HiPopColors.organizerAccent,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _tempSelected.add(category);
                      } else {
                        _tempSelected.remove(category);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _tempSelected.clear());
                  },
                  child: Text('Clear All'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_tempSelected);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HiPopColors.organizerAccent,
                  ),
                  child: Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExperienceFilterSheet extends StatelessWidget {
  final String? selectedLevel;
  final List<String> levels;
  final Function(String?) onApply;

  const _ExperienceFilterSheet({
    required this.selectedLevel,
    required this.levels,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter by Experience',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: HiPopColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            title: Text(
              'All Levels',
              style: TextStyle(color: HiPopColors.darkTextPrimary),
            ),
            leading: Radio<String?>(
              value: null,
              groupValue: selectedLevel,
              activeColor: HiPopColors.organizerAccent,
              onChanged: (value) {
                onApply(value);
                Navigator.pop(context);
              },
            ),
          ),
          ...levels.map((level) => ListTile(
            title: Text(
              level,
              style: TextStyle(color: HiPopColors.darkTextPrimary),
            ),
            leading: Radio<String?>(
              value: level,
              groupValue: selectedLevel,
              activeColor: HiPopColors.organizerAccent,
              onChanged: (value) {
                onApply(value);
                Navigator.pop(context);
              },
            ),
          )),
        ],
      ),
    );
  }
}

class _RatingFilterSheet extends StatefulWidget {
  final double currentRating;
  final Function(double) onApply;

  const _RatingFilterSheet({
    required this.currentRating,
    required this.onApply,
  });

  @override
  State<_RatingFilterSheet> createState() => _RatingFilterSheetState();
}

class _RatingFilterSheetState extends State<_RatingFilterSheet> {
  late double _tempRating;

  @override
  void initState() {
    super.initState();
    _tempRating = widget.currentRating;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Minimum Rating',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: HiPopColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (int i = 1; i <= 5; i++)
                Icon(
                  i <= _tempRating ? Icons.star : Icons.star_border,
                  color: HiPopColors.warningAmber,
                  size: 32,
                ),
              const SizedBox(width: 16),
              Text(
                '${_tempRating.toStringAsFixed(1)}+',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Slider(
            value: _tempRating,
            min: 0,
            max: 5,
            divisions: 10,
            activeColor: HiPopColors.organizerAccent,
            onChanged: (value) {
              setState(() => _tempRating = value);
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.onApply(0);
                    Navigator.pop(context);
                  },
                  child: Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_tempRating);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HiPopColors.organizerAccent,
                  ),
                  child: Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}