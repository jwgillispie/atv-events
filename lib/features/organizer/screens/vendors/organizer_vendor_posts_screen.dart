import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/features/organizer/models/organizer_vendor_post.dart';
import '../../services/vendor_management/vendor_post_service.dart';
import '../../../shared/widgets/common/loading_widget.dart';
import '../../../shared/widgets/common/error_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import '../../../../core/widgets/hipop_app_bar.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

class OrganizerVendorPostsScreen extends StatefulWidget {
  const OrganizerVendorPostsScreen({super.key});

  @override
  State<OrganizerVendorPostsScreen> createState() =>
      _OrganizerVendorPostsScreenState();
}

class _OrganizerVendorPostsScreenState
    extends State<OrganizerVendorPostsScreen> {
  List<OrganizerVendorPost> _posts = [];
  bool _isLoading = true;
  bool _hasPremiumAccess = false;
  String? _error;
  String _selectedFilter = 'all';

  final List<String> _filterOptions = [
    'all',
    'active',
    'paused',
    'closed',
    'expired',
  ];

  @override
  void initState() {
    super.initState();
    _checkPremiumAccessAndLoad();
  }

  Future<void> _checkPremiumAccessAndLoad() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! Authenticated) {
        setState(() {
          _error = 'Please log in to access Vendor Posts';
          _isLoading = false;
        });
        return;
      }

      // Check premium access via user profile
      final userProfile = authState.userProfile;
      final hasAccess = userProfile?.isPremium ?? false;

      if (!hasAccess) {
        setState(() {
          _hasPremiumAccess = false;
          _isLoading = false;
        });
        return;
      }

      setState(() => _hasPremiumAccess = true);

      // Load posts (no remaining posts limit for premium users)
      await _loadPosts();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPosts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final posts = await OrganizerVendorPostService.getOrganizerPosts(
        user.uid,
        limit: 50,
        status:
            _selectedFilter == 'all'
                ? null
                : PostStatus.values.firstWhere(
                  (status) => status.name == _selectedFilter,
                  orElse: () => PostStatus.active,
                ),
      );

      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshPosts() async {
    await _loadPosts();
  }

  Future<void> _deletePost(OrganizerVendorPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Post'),
            content: Text(
              'Are you sure you want to delete "${post.title}"? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await OrganizerVendorPostService.deleteVendorPost(post.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshPosts();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePostStatus(OrganizerVendorPost post) async {
    try {
      final newStatus =
          post.status == PostStatus.active
              ? PostStatus.paused
              : PostStatus.active;

      await OrganizerVendorPostService.updatePostStatus(post.id, newStatus);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post ${newStatus.name}'),
          backgroundColor: Colors.green,
        ),
      );

      _refreshPosts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating post: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: HiPopAppBar(
        title: 'Vendor Posts',
        userRole: 'vendor',
        centerTitle: true,
        actions: [
          if (_hasPremiumAccess)
            IconButton(
              onPressed: () {
                context.go('/organizer/vendor-recruitment/create');
              },
              icon: const Icon(Icons.add),
              tooltip: 'Create New Post',
            ),
        ],
      ),
      body:
          !_hasPremiumAccess
              ? _buildUpgradePrompt()
              : _isLoading
              ? const LoadingWidget(message: 'Loading vendor posts...')
              : _error != null
              ? ErrorDisplayWidget(
                title: 'Load Error',
                message: _error!,
                onRetry: _refreshPosts,
              )
              : Column(
                children: [
                  _buildFilterSection(),
                  Expanded(
                    child:
                        _posts.isEmpty ? _buildEmptyState() : _buildPostsList(),
                  ),
                ],
              ),
      floatingActionButton:
          _hasPremiumAccess && !_isLoading
              ? FloatingActionButton(
                onPressed: () {
                  context.go('/organizer/vendor-recruitment/create');
                },
                backgroundColor: HiPopColors.organizerAccent,
                child: const Icon(Icons.add, color: Colors.white),
              )
              : null,
    );
  }

  Widget _buildUpgradePrompt() {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity( 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Icon(Icons.campaign, size: 64, color: Colors.amber[700]),
            ),
            const SizedBox(height: 24),
            Text(
              'Upgrade to Organizer Premium',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple[800],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Create "Looking for Vendors" posts that appear directly in vendor market discovery feeds.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'With Organizer Pro, you get:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...[
                      'Create unlimited vendor recruitment posts',
                      'Posts appear in vendor premium discovery feeds',
                      'Track views, responses, and conversion rates',
                      'Advanced response management and filtering',
                      'Smart matching to qualified vendors',
                      'Comprehensive analytics and insights',
                    ].map(
                      (feature) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green[600],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                feature,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    context.go(
                      '/premium/upgrade?tier=organizer&userId=${user.uid}',
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: HiPopColors.organizerAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.diamond),
                    const SizedBox(width: 8),
                    const Text(
                      'Upgrade to Organizer Premium - \$69/month',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Maybe Later',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: HiPopColors.darkSurface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter Posts',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  _filterOptions
                      .map(
                        (filter) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(_formatFilterName(filter)),
                            selected: _selectedFilter == filter,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedFilter = filter);
                                _loadPosts();
                              }
                            },
                            selectedColor: HiPopColors.organizerAccent
                                .withOpacity( 0.2),
                            checkmarkColor: HiPopColors.organizerAccent,
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFilterName(String filter) {
    switch (filter) {
      case 'all':
        return 'All Posts';
      case 'active':
        return 'Active';
      case 'paused':
        return 'Paused';
      case 'closed':
        return 'Closed';
      case 'expired':
        return 'Expired';
      default:
        return filter.toUpperCase();
    }
  }

  Widget _buildPostsList() {
    return RefreshIndicator(
      onRefresh: _refreshPosts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return _buildPostCard(post);
        },
      ),
    );
  }

  Widget _buildPostCard(OrganizerVendorPost post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post.description.length > 100
                            ? '${post.description.substring(0, 100)}...'
                            : post.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(post.status),
              ],
            ),

            const SizedBox(height: 16),

            // Categories
            if (post.categories.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    post.categories
                        .take(3)
                        .map(
                          (category) => Chip(
                            label: Text(
                              _formatCategoryName(category),
                              style: const TextStyle(fontSize: 12),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: Colors.deepPurple.withValues(
                              alpha: 0.1,
                            ),
                            side: BorderSide(
                              color: Colors.deepPurple.withOpacity( 0.3),
                            ),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Analytics row
            Row(
              children: [
                _buildMetricChip(
                  Icons.visibility,
                  '${post.analytics.views} views',
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildMetricChip(
                  Icons.reply,
                  '${post.analytics.responses} responses',
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildMetricChip(
                  Icons.schedule,
                  _formatDate(post.createdAt),
                  Colors.orange,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.go(
                        '/organizer/vendor-posts/${post.id}/responses',
                      );
                    },
                    icon: const Icon(Icons.inbox),
                    label: const Text('Responses'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.go('/organizer/vendor-posts/${post.id}/edit');
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'toggle':
                        _togglePostStatus(post);
                        break;
                      case 'delete':
                        _deletePost(post);
                        break;
                    }
                  },
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Icon(
                                post.status == PostStatus.active
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                post.status == PostStatus.active
                                    ? 'Pause Post'
                                    : 'Activate Post',
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete,
                                size: 18,
                                color: Colors.red[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Delete Post',
                                style: TextStyle(color: Colors.red[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.more_vert, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(PostStatus status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case PostStatus.active:
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Active';
        break;
      case PostStatus.paused:
        color = Colors.orange;
        icon = Icons.pause_circle;
        label = 'Paused';
        break;
      case PostStatus.closed:
        color = Colors.grey;
        icon = Icons.cancel;
        label = 'Closed';
        break;
      case PostStatus.expired:
        color = Colors.red;
        icon = Icons.schedule;
        label = 'Expired';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity( 0.1),
        borderRadius: BorderRadius.circular(12),
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
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity( 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity( 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
            Icon(Icons.campaign, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Vendor Posts Yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first "Looking for Vendors" post to attract qualified vendors to your market.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.go('/organizer/vendor-recruitment/create');
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Post'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.organizerAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCategoryName(String category) {
    return category
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }
}
