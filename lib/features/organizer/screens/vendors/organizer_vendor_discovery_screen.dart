import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/core/widgets/hipop_app_bar.dart';
import 'package:atv_events/features/organizer/services/analytics/discovery_analytics_service.dart';
import 'package:atv_events/features/organizer/services/vendor_management/vendor_discovery_service.dart';
import 'package:atv_events/features/organizer/services/vendor_management/vendor_invitation_service.dart';
import 'package:atv_events/features/premium/services/subscription_service.dart';
import 'package:atv_events/features/shared/models/user_profile.dart';
import 'package:atv_events/features/shared/widgets/common/error_widget.dart';
import 'package:atv_events/features/shared/widgets/common/hipop_text_field.dart';
import 'package:atv_events/features/shared/widgets/common/loading_widget.dart';
import 'package:atv_events/features/vendor/services/engagement/vendor_contact_service.dart';


class OrganizerVendorDiscoveryScreen extends StatefulWidget {
  const OrganizerVendorDiscoveryScreen({super.key});

  @override
  State<OrganizerVendorDiscoveryScreen> createState() => _OrganizerVendorDiscoveryScreenState();
}

class _OrganizerVendorDiscoveryScreenState extends State<OrganizerVendorDiscoveryScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final VendorContactService _contactService = VendorContactService();
  
  bool _isLoading = true;
  bool _hasPremiumAccess = true; // Vendor discovery is now free for all organizers
  bool _isInviting = false;
  String? _error;
  
  List<VendorDiscoveryResult> _discoveryResults = [];
  List<String> _selectedCategories = [];
  List<String> _selectedExperienceLevels = [];
  String _selectedLocation = '';
  double _minRating = 0.0;
  bool _onlyAvailable = false;
  final Set<String> _selectedVendors = {};

  final List<String> _availableCategories = [
    'produce', 'baked_goods', 'prepared_foods', 'crafts', 'beverages',
    'health_beauty', 'flowers', 'meat_seafood', 'dairy', 'other'
  ];

  final List<String> _experienceLevels = [
    'Beginner', 'Intermediate', 'Experienced', 'Expert'
  ];

  @override
  void initState() {
    super.initState();
    _checkPremiumAccessAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkPremiumAccessAndLoad() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Please log in to access Vendor Discovery';
          _isLoading = false;
        });
        return;
      }

      // Vendor discovery is now free for all organizers
      setState(() => _hasPremiumAccess = true);
      
      // Load initial vendor discovery results
      await _discoverVendors();
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _discoverVendors() async {
    // Vendor discovery is now free - no premium check needed
    
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final results = await VendorDiscoveryService.discoverVendorsForOrganizer(
        user.uid,
        categories: _selectedCategories.isEmpty ? null : _selectedCategories,
        location: _selectedLocation.isEmpty ? null : _selectedLocation,
        experienceLevels: _selectedExperienceLevels.isEmpty ? null : _selectedExperienceLevels,
        minRating: _minRating > 0 ? _minRating : null,
        searchQuery: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        onlyVerified: true,
        onlyAvailable: _onlyAvailable,
        limit: 25,
      );

      setState(() {
        _discoveryResults = results;
        _selectedVendors.clear();
        _isLoading = false;
      });

      // Track analytics
      await VendorDiscoveryAnalyticsService.trackVendorDiscoveryUsage(
        user.uid,
        {
          'categories': _selectedCategories,
          'location': _selectedLocation,
          'experienceLevels': _selectedExperienceLevels,
          'minRating': _minRating,
          'searchQuery': _searchController.text.trim(),
          'onlyAvailable': _onlyAvailable,
        },
        results.length,
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendInvitation(VendorDiscoveryResult vendor, String marketId) async {
    try {
      setState(() => _isInviting = true);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await VendorInvitationService.sendInvitationToVendor(
        user.uid,
        vendor.vendor.userId,
        marketId,
        customMessage: 'We discovered your profile and think you\'d be a great fit for our market!',
      );

      // Track analytics
      await VendorDiscoveryAnalyticsService.trackVendorInvitation(
        user.uid,
        vendor.vendor.userId,
        marketId,
        'single',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation sent to ${vendor.vendor.displayTitle}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send invitation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  Future<void> _sendBulkInvitations() async {
    if (_selectedVendors.isEmpty) return;

    try {
      setState(() => _isInviting = true);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // For simplicity, we'll invite to the first market the organizer has
      // In a real app, you'd let them select the market
      final organizerMarkets = await VendorDiscoveryService.getOrganizerMarkets(user.uid);
      if (organizerMarkets.isEmpty) {
        throw Exception('No markets found for organizer');
      }

      final firstMarketId = organizerMarkets.first.id;
      
      await VendorInvitationService.sendBulkInvitations(
        user.uid,
        _selectedVendors.toList(),
        firstMarketId,
        customMessage: 'We discovered your profiles and think you\'d be great fits for our market!',
      );

      // Track analytics for bulk invitations
      for (final vendorId in _selectedVendors) {
        await VendorDiscoveryAnalyticsService.trackVendorInvitation(
          user.uid,
          vendorId,
          firstMarketId,
          'bulk',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent ${_selectedVendors.length} invitations successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _selectedVendors.clear());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send bulk invitations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: HiPopAppBar(
        title: 'Vendor Discovery',
        userRole: 'vendor',
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          if (_hasPremiumAccess && _selectedVendors.isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text('${_selectedVendors.length}'),
                child: const Icon(Icons.send),
              ),
              tooltip: 'Send bulk invitations',
              onPressed: _isInviting ? null : _sendBulkInvitations,
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Discovering qualified vendors...')
          : _error != null
              ? ErrorDisplayWidget(
                  title: 'Discovery Error',
                  message: _error!,
                  onRetry: _discoverVendors,
                )
              : Column(
                  children: [
                    _buildFiltersSection(),
                    Expanded(
                      child: _discoveryResults.isEmpty
                          ? _buildEmptyState()
                          : _buildVendorsList(),
                    ),
                  ],
                ),
    );
  }

  // Premium upgrade prompt removed - vendor discovery is now free for all organizers

  Widget _buildFiltersSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          HiPopTextField(
            controller: _searchController,
            labelText: 'Search vendors by name or business',
            hintText: 'e.g., "Organic Bakery" or "Sarah\'s Crafts"',
            prefixIcon: const Icon(Icons.search),
            onChanged: (_) => _discoverVendors(),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _discoverVendors();
                    },
                  )
                : null,
          ),
          const SizedBox(height: 16),
          
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Category filter
                _buildFilterChip(
                  _selectedCategories.isEmpty 
                      ? 'All Categories' 
                      : '${_selectedCategories.length} Categories',
                  Icons.category,
                  onTap: () => _showCategoryDialog(),
                ),
                const SizedBox(width: 8),
                
                // Experience filter
                _buildFilterChip(
                  _selectedExperienceLevels.isEmpty 
                      ? 'All Experience Levels' 
                      : '${_selectedExperienceLevels.length} Levels',
                  Icons.trending_up,
                  onTap: () => _showExperienceDialog(),
                ),
                const SizedBox(width: 8),
                
                // Location filter
                _buildFilterChip(
                  _selectedLocation.isEmpty ? 'Any Location' : _selectedLocation,
                  Icons.location_on,
                  onTap: () => _showLocationDialog(),
                ),
                const SizedBox(width: 8),
                
                // Rating filter
                _buildFilterChip(
                  _minRating > 0 ? '${_minRating.toStringAsFixed(1)}+ Stars' : 'Any Rating',
                  Icons.star,
                  onTap: () => _showRatingDialog(),
                ),
                const SizedBox(width: 8),
                
                // Available only filter
                _buildFilterChip(
                  _onlyAvailable ? 'Available Only' : 'All Vendors',
                  Icons.check_circle,
                  isSelected: _onlyAvailable,
                  onTap: () {
                    setState(() {
                      _onlyAvailable = !_onlyAvailable;
                    });
                    _discoverVendors();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    IconData icon, {
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
      selected: isSelected,
      onSelected: onTap != null ? (_) => onTap() : null,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: Colors.deepPurple.withOpacity( 0.2),
      checkmarkColor: Colors.deepPurple[700],
    );
  }

  Widget _buildVendorsList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _discoveryResults.length,
      itemBuilder: (context, index) {
        final result = _discoveryResults[index];
        return _buildVendorCard(result);
      },
    );
  }

  Widget _buildVendorCard(VendorDiscoveryResult result) {
    final isSelected = _selectedVendors.contains(result.vendor.userId);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedVendors.remove(result.vendor.userId);
            } else {
              _selectedVendors.add(result.vendor.userId);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with vendor name, rating, and selection
              Row(
                children: [
                  // Avatar/Initial
                  CircleAvatar(
                    backgroundColor: Colors.deepPurple.shade100,
                    child: Text(
                      result.vendor.displayTitle[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.vendor.displayTitle,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getExperienceLevelColor(result.experienceLevel).withOpacity( 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _getExperienceLevelColor(result.experienceLevel)),
                              ),
                              child: Text(
                                result.experienceLevel,
                                style: TextStyle(
                                  color: _getExperienceLevelColor(result.experienceLevel),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (result.averageRating > 0) ...[
                              Icon(Icons.star, size: 16, color: Colors.amber[700]),
                              const SizedBox(width: 4),
                              Text(
                                '${result.averageRating.toStringAsFixed(1)} (${result.totalMarkets})',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Selection checkbox
                  Checkbox(
                    value: isSelected,
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedVendors.add(result.vendor.userId);
                        } else {
                          _selectedVendors.remove(result.vendor.userId);
                        }
                      });
                    },
                    activeColor: Colors.deepPurple,
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Categories
              if (result.categories?.isNotEmpty ?? false) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: result.categories!.take(4).map((category) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity( 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Text(
                      _formatCategoryName(category),
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 12),
              ],
              
              // Bio/description if available
              if (result.vendor.bio != null && result.vendor.bio!.isNotEmpty) ...[
                Text(
                  result.vendor.bio!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],
              
              // Insights
              if (result.insights.isNotEmpty) ...[
                ...result.insights.take(3).map((insight) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb, size: 14, color: Colors.amber[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          insight,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 12),
              ],
              
              // Contact Information
              _buildContactInfoSection(result.vendor),
              
              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isInviting ? null : () => _showMarketSelectionDialog(result),
                  icon: _isInviting 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isInviting ? 'Sending...' : 'Send Invitation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactInfoSection(UserProfile vendor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          _buildContactActions(vendor),
        ],
      ),
    );
  }

  Widget _buildContactActions(UserProfile vendor) {
    final hasPhone = vendor.phoneNumber?.isNotEmpty == true;
    final hasInstagram = vendor.instagramHandle?.isNotEmpty == true;
    final hasWebsite = vendor.website?.isNotEmpty == true;
    
    if (!hasPhone && !hasInstagram && !hasWebsite) {
      return Text(
        'No contact information available',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Email action (always available)
        _buildContactActionChip(
          icon: Icons.email,
          label: 'Email',
          color: Colors.blue,
          onTap: () => _contactService.launchEmail(
            vendor.email,
            subject: 'Partnership Opportunity - Farmers Market',
            body: 'Hi ${vendor.displayTitle},\n\nI would like to discuss a potential partnership opportunity for our farmers market...',
          ),
        ),
        
        // Phone action
        if (hasPhone)
          _buildContactActionChip(
            icon: Icons.phone,
            label: VendorContactService.formatPhoneNumber(vendor.phoneNumber),
            color: Colors.green,
            onTap: () => _contactService.launchPhoneCall(vendor.phoneNumber),
          ),
        
        // Instagram action
        if (hasInstagram)
          _buildContactActionChip(
            icon: Icons.camera_alt,
            label: VendorContactService.formatInstagramHandle(vendor.instagramHandle),
            color: Colors.purple,
            onTap: () => _contactService.launchInstagram(vendor.instagramHandle),
          ),
        
        // Website action
        if (hasWebsite)
          _buildContactActionChip(
            icon: Icons.web,
            label: VendorContactService.formatWebsiteForDisplay(vendor.website),
            color: Colors.teal,
            onTap: () => _contactService.launchWebsite(vendor.website),
          ),
      ],
    );
  }

  Widget _buildContactActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity( 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity( 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getExperienceLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'expert':
        return Colors.purple;
      case 'experienced':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'beginner':
      default:
        return Colors.blue;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Vendors Found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search filters or expanding your criteria to find more qualified vendors.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                _selectedCategories.clear();
                _selectedExperienceLevels.clear();
                _selectedLocation = '';
                _minRating = 0.0;
                _onlyAvailable = false;
                _discoverVendors();
              },
              child: const Text('Clear All Filters'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMarketSelectionDialog(VendorDiscoveryResult vendor) async {
    // For simplicity, we'll get the organizer's first market
    // In a real app, you'd show a dialog to select which market to invite to
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final organizerMarkets = await VendorDiscoveryService.getOrganizerMarkets(user.uid);
      if (organizerMarkets.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No markets found. Please create a market first.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final selectedMarket = organizerMarkets.first;
      await _sendInvitation(vendor, selectedMarket.id);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCategoryDialog() {
    final tempSelected = List<String>.from(_selectedCategories);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter by Categories'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _availableCategories.map((category) => CheckboxListTile(
                  title: Text(_formatCategoryName(category)),
                  value: tempSelected.contains(category),
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        tempSelected.add(category);
                      } else {
                        tempSelected.remove(category);
                      }
                    });
                  },
                )).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setDialogState(() => tempSelected.clear());
              },
              child: const Text('Clear All'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _selectedCategories = tempSelected);
                Navigator.pop(context);
                _discoverVendors();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExperienceDialog() {
    final tempSelected = List<String>.from(_selectedExperienceLevels);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter by Experience Level'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _experienceLevels.map((level) => CheckboxListTile(
              title: Text(level),
              value: tempSelected.contains(level),
              onChanged: (checked) {
                setDialogState(() {
                  if (checked == true) {
                    tempSelected.add(level);
                  } else {
                    tempSelected.remove(level);
                  }
                });
              },
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setDialogState(() => tempSelected.clear());
              },
              child: const Text('Clear All'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _selectedExperienceLevels = tempSelected);
                Navigator.pop(context);
                _discoverVendors();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationDialog() {
    final controller = TextEditingController(text: _selectedLocation);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Location'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Location',
            hintText: 'e.g., Atlanta, GA or 30309',
            prefixIcon: Icon(Icons.location_on),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _selectedLocation = '');
              Navigator.pop(context);
              _discoverVendors();
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _selectedLocation = controller.text.trim());
              Navigator.pop(context);
              _discoverVendors();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog() {
    double tempRating = _minRating;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Minimum Rating'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${tempRating.toStringAsFixed(1)} stars and above'),
              const SizedBox(height: 16),
              Slider(
                value: tempRating,
                min: 0.0,
                max: 5.0,
                divisions: 10,
                onChanged: (value) {
                  setDialogState(() => tempRating = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() => _minRating = 0.0);
                Navigator.pop(context);
                _discoverVendors();
              },
              child: const Text('Clear'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _minRating = tempRating);
                Navigator.pop(context);
                _discoverVendors();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCategoryName(String category) {
    return category.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }
}