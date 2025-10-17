import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/vendor_management/vendor_directory_service.dart';
import '../../../shared/widgets/common/loading_widget.dart';
import '../../../shared/widgets/common/error_widget.dart';
import '../../../shared/widgets/common/hipop_text_field.dart';
import '../../../../core/widgets/hipop_app_bar.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

class VendorDirectoryScreen extends StatefulWidget {
  const VendorDirectoryScreen({super.key});

  @override
  State<VendorDirectoryScreen> createState() => _VendorDirectoryScreenState();
}

class _VendorDirectoryScreenState extends State<VendorDirectoryScreen> {
  final _searchController = TextEditingController();
  final _locationController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;
  
  List<Map<String, dynamic>> _vendors = [];
  List<String> _selectedCategories = [];
  String? _selectedExperience;
  bool _onlyAvailable = false;
  
  // Available categories (from vendor signup)
  final List<String> _availableCategories = [
    'produce', 'baked_goods', 'prepared_foods', 'crafts', 'beverages',
    'health_beauty', 'flowers', 'meat_seafood', 'dairy', 'jewelry',
    'clothing', 'art', 'music', 'other'
  ];
  
  final List<String> _experienceLevels = [
    'Beginner', 'Intermediate', 'Experienced', 'Expert'
  ];

  @override
  void initState() {
    super.initState();
    _loadVendorDirectory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadVendorDirectory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Please log in to access Vendor Directory';
          _isLoading = false;
        });
        return;
      }

      // Load initial vendors - no premium check needed for organizers
      await _searchVendors();

    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _searchVendors() async {
    setState(() => _isSearching = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final results = await VendorDirectoryService.searchVendors(
        searchQuery: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        categories: _selectedCategories.isEmpty ? null : _selectedCategories,
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        experienceLevel: _selectedExperience,
        onlyAvailable: _onlyAvailable,
        limit: 50,
      );

      setState(() {
        _vendors = results;
        _isSearching = false;
        _isLoading = false;
      });

      // Track search analytics
      if (_searchController.text.isNotEmpty || _selectedCategories.isNotEmpty) {
        // Analytics tracking could be added here
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSearching = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _sendInvitation(Map<String, dynamic> vendor) async {
    // For simplicity, we'll use a dialog to select market
    // In production, you'd want a more sophisticated market selection
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Invitation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Send invitation to ${vendor['businessName']}?'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Custom Message (Optional)',
                hintText: 'We think you would be a great fit...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Send invitation logic here
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Invitation sent to ${vendor['businessName']}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Send Invitation'),
          ),
        ],
      ),
    );
  }

  void _launchContact(String? value, String type) async {
    if (value == null || value.isEmpty) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
      // Track contact analytics
      // VendorDirectoryService.trackVendorContact(user.uid, vendorId, type);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: HiPopAppBar(
        title: 'Vendor Directory',
        userRole: 'vendor',
        centerTitle: true,
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading vendor directory...')
          : _error != null
              ? ErrorDisplayWidget(
                  title: 'Error Loading Directory',
                  message: _error!,
                  onRetry: _searchVendors,
                )
              : Column(
                  children: [
                    _buildSearchSection(),
                    _buildFilterChips(),
                    Expanded(
                      child: _isSearching
                          ? const LoadingWidget(message: 'Searching vendors...')
                          : _vendors.isEmpty
                              ? _buildEmptyState()
                              : _buildVendorsList(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      color: HiPopColors.darkSurface,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          HiPopTextField(
            controller: _searchController,
            labelText: 'Search vendors',
            hintText: 'Business name, products, or description',
            prefixIcon: const Icon(Icons.search),
            onChanged: (_) => _searchVendors(),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _searchVendors();
                    },
                  )
                : null,
          ),
          const SizedBox(height: 12),
          HiPopTextField(
            controller: _locationController,
            labelText: 'Location',
            hintText: 'City, state, or zip',
            prefixIcon: const Icon(Icons.location_on),
            onChanged: (_) => _searchVendors(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: HiPopColors.darkSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Category filter
            ActionChip(
              label: Text(_selectedCategories.isEmpty 
                  ? 'All Categories' 
                  : '${_selectedCategories.length} Categories'),
              avatar: const Icon(Icons.category, size: 18),
              onPressed: _showCategoryDialog,
            ),
            const SizedBox(width: 8),
            
            // Experience filter
            ActionChip(
              label: Text(_selectedExperience ?? 'All Experience'),
              avatar: const Icon(Icons.trending_up, size: 18),
              onPressed: _showExperienceDialog,
            ),
            const SizedBox(width: 8),
            
            // Available only
            FilterChip(
              label: const Text('Available Only'),
              selected: _onlyAvailable,
              onSelected: (selected) {
                setState(() => _onlyAvailable = selected);
                _searchVendors();
              },
            ),
            const SizedBox(width: 8),
            
            // Clear filters
            if (_selectedCategories.isNotEmpty || 
                _selectedExperience != null || 
                _onlyAvailable)
              ActionChip(
                label: const Text('Clear Filters'),
                avatar: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  setState(() {
                    _selectedCategories.clear();
                    _selectedExperience = null;
                    _onlyAvailable = false;
                  });
                  _searchVendors();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _vendors.length,
      itemBuilder: (context, index) {
        final vendor = _vendors[index];
        return _buildVendorCard(vendor);
      },
    );
  }

  Widget _buildVendorCard(Map<String, dynamic> vendor) {
    final hasPhone = vendor['phoneNumber']?.isNotEmpty == true;
    final hasInstagram = vendor['instagramHandle']?.isNotEmpty == true;
    final hasWebsite = vendor['website']?.isNotEmpty == true;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade100,
                  child: Text(
                    (vendor['businessName'] ?? 'V')[0].toUpperCase(),
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
                        vendor['businessName'] ?? 'Unknown Vendor',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (vendor['experienceLevel'] != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getExperienceColor(vendor['experienceLevel']).withOpacity( 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _getExperienceColor(vendor['experienceLevel'])),
                          ),
                          child: Text(
                            vendor['experienceLevel'],
                            style: TextStyle(
                              color: _getExperienceColor(vendor['experienceLevel']),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Stats
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (vendor['activePostsCount'] != null && vendor['activePostsCount'] > 0)
                      Text(
                        '${vendor['activePostsCount']} active posts',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (vendor['marketsParticipated'] != null && vendor['marketsParticipated'] > 0)
                      Text(
                        '${vendor['marketsParticipated']} markets',
                        style: TextStyle(
                          fontSize: 12,
                          color: HiPopColors.darkTextTertiary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            
            // Categories
            if (vendor['categories'] != null && (vendor['categories'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (vendor['categories'] as List).take(5).map((category) => 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: HiPopColors.vendorAccent.withOpacity( 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: HiPopColors.vendorAccent.withOpacity( 0.3)),
                    ),
                    child: Text(
                      _formatCategory(category.toString()),
                      style: TextStyle(
                        color: HiPopColors.vendorAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ).toList(),
              ),
            ],
            
            // Bio
            if (vendor['bio'] != null && vendor['bio'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                vendor['bio'],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: HiPopColors.darkTextSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            // Featured items
            if (vendor['featuredItems'] != null && vendor['featuredItems'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.star, size: 16, color: Colors.amber[700]),
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
            
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            
            // Contact actions
            Row(
              children: [
                // Email
                IconButton(
                  icon: const Icon(Icons.email),
                  color: HiPopColors.organizerAccent,
                  tooltip: 'Email',
                  onPressed: () => _launchContact(vendor['email'], 'email'),
                ),
                
                // Phone
                if (hasPhone)
                  IconButton(
                    icon: const Icon(Icons.phone),
                    color: HiPopColors.successGreen,
                    tooltip: 'Call',
                    onPressed: () => _launchContact(vendor['phoneNumber'], 'phone'),
                  ),
                
                // Instagram
                if (hasInstagram)
                  IconButton(
                    icon: const Icon(Icons.camera_alt),
                    color: HiPopColors.vendorAccent,
                    tooltip: 'Instagram',
                    onPressed: () => _launchContact(vendor['instagramHandle'], 'instagram'),
                  ),
                
                // Website
                if (hasWebsite)
                  IconButton(
                    icon: const Icon(Icons.web),
                    color: Colors.teal,
                    tooltip: 'Website',
                    onPressed: () => _launchContact(vendor['website'], 'website'),
                  ),
                
                const Spacer(),
                
                // Send invitation button
                ElevatedButton.icon(
                  onPressed: () => _sendInvitation(vendor),
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Invite'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HiPopColors.organizerAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: HiPopColors.darkTextTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No Vendors Found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: HiPopColors.darkTextTertiary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search filters',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: HiPopColors.darkTextTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                _locationController.clear();
                _selectedCategories.clear();
                _selectedExperience = null;
                _onlyAvailable = false;
                _searchVendors();
              },
              child: const Text('Clear All Filters'),
            ),
          ],
        ),
      ),
    );
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
                  title: Text(_formatCategory(category)),
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
                _searchVendors();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExperienceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Experience'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String?>(
              title: const Text('All Experience Levels'),
              value: null,
              groupValue: _selectedExperience,
              onChanged: (value) {
                setState(() => _selectedExperience = value);
                Navigator.pop(context);
                _searchVendors();
              },
            ),
            ..._experienceLevels.map((level) => RadioListTile<String>(
              title: Text(level),
              value: level,
              groupValue: _selectedExperience,
              onChanged: (value) {
                setState(() => _selectedExperience = value);
                Navigator.pop(context);
                _searchVendors();
              },
            )),
          ],
        ),
      ),
    );
  }

  Color _getExperienceColor(String level) {
    switch (level) {
      case 'Expert':
        return Colors.purple;
      case 'Experienced':
        return Colors.green;
      case 'Intermediate':
        return HiPopColors.warningAmber;
      case 'Beginner':
      default:
        return HiPopColors.shopperAccent;
    }
  }

  String _formatCategory(String category) {
    return category.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }
}