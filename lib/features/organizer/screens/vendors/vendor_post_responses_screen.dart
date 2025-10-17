import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:atv_events/features/organizer/models/organizer_vendor_post.dart';
import 'package:atv_events/features/organizer/models/vendor_post_response.dart';
import 'package:atv_events/features/organizer/services/vendor_management/vendor_post_service.dart';
import 'package:atv_events/features/shared/widgets/common/error_widget.dart';
import 'package:atv_events/features/shared/widgets/common/loading_widget.dart';

class VendorPostResponsesScreen extends StatefulWidget {
  final String postId;
  
  const VendorPostResponsesScreen({
    super.key,
    required this.postId,
  });

  @override
  State<VendorPostResponsesScreen> createState() => _VendorPostResponsesScreenState();
}

class _VendorPostResponsesScreenState extends State<VendorPostResponsesScreen> {
  List<VendorPostResponse> _responses = [];
  OrganizerVendorPost? _post;
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all';

  final List<String> _filterOptions = ['all', 'newResponse', 'reviewed', 'contacted', 'accepted', 'rejected'];

  @override
  void initState() {
    super.initState();
    _loadPostAndResponses();
  }

  Future<void> _loadPostAndResponses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Please log in to access responses';
          _isLoading = false;
        });
        return;
      }

      // Load the post
      final post = await OrganizerVendorPostService.getVendorPost(widget.postId);
      if (post == null) {
        setState(() {
          _error = 'Post not found';
          _isLoading = false;
        });
        return;
      }

      // Verify user owns this post
      if (post.organizerId != user.uid) {
        setState(() {
          _error = 'Access denied';
          _isLoading = false;
        });
        return;
      }

      // Load responses
      final responses = await OrganizerVendorPostService.getPostResponses(
        widget.postId,
        status: _selectedFilter == 'all' ? null : ResponseStatus.values.firstWhere(
          (status) => status.name == _selectedFilter,
          orElse: () => ResponseStatus.newResponse,
        ),
        limit: 100,
      );

      setState(() {
        _post = post;
        _responses = responses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshResponses() async {
    await _loadPostAndResponses();
  }

  Future<void> _updateResponseStatus(VendorPostResponse response, ResponseStatus newStatus) async {
    try {
      await OrganizerVendorPostService.updateResponseStatus(
        response.id, 
        newStatus,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Response marked as ${_formatStatus(newStatus)}'),
          backgroundColor: Colors.green,
        ),
      );
      
      _refreshResponses();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating response: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addNotes(VendorPostResponse response) async {
    final controller = TextEditingController(text: response.organizerNotes ?? '');
    
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notes for ${response.vendorProfile.displayName}'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Your notes',
            hintText: 'Add notes about this vendor response...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (notes != null) {
      try {
        await OrganizerVendorPostService.updateResponseStatus(
          response.id,
          response.status,
          organizerNotes: notes.isEmpty ? null : notes,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notes updated'),
            backgroundColor: Colors.green,
          ),
        );
        
        _refreshResponses();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating notes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Responses'),
            if (_post != null)
              Text(
                _post!.title.length > 30 
                    ? '${_post!.title.substring(0, 30)}...'
                    : _post!.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading responses...')
          : _error != null
              ? ErrorDisplayWidget(
                  title: 'Load Error',
                  message: _error!,
                  onRetry: _refreshResponses,
                )
              : Column(
                  children: [
                    _buildPostSummary(),
                    _buildFilterSection(),
                    Expanded(
                      child: _responses.isEmpty
                          ? _buildEmptyState()
                          : _buildResponsesList(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPostSummary() {
    if (_post == null) return const SizedBox();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity( 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.campaign,
              color: Colors.deepPurple[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _post!.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildMetricChip(
                      Icons.visibility,
                      '${_post!.analytics.views} views',
                      Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _buildMetricChip(
                      Icons.reply,
                      '${_responses.length} responses',
                      Colors.green,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter Responses',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((filter) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(_formatFilterName(filter)),
                  selected: _selectedFilter == filter,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedFilter = filter);
                      _loadPostAndResponses();
                    }
                  },
                  selectedColor: Colors.deepPurple.withOpacity( 0.2),
                  checkmarkColor: Colors.deepPurple[700],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsesList() {
    return RefreshIndicator(
      onRefresh: _refreshResponses,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _responses.length,
        itemBuilder: (context, index) {
          final response = _responses[index];
          return _buildResponseCard(response);
        },
      ),
    );
  }

  Widget _buildResponseCard(VendorPostResponse response) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with vendor info and status
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple.withOpacity( 0.1),
                  child: Text(
                    response.vendorProfile.displayName.isNotEmpty
                        ? response.vendorProfile.displayName[0].toUpperCase()
                        : 'V',
                    style: TextStyle(
                      color: Colors.deepPurple[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        response.vendorProfile.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        response.vendorProfile.experience,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(response.status),
              ],
            ),

            const SizedBox(height: 16),

            // Categories if available
            if (response.vendorProfile.categories.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: response.vendorProfile.categories.take(4).map((category) => Chip(
                  label: Text(
                    _formatCategoryName(category),
                    style: const TextStyle(fontSize: 11),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: Colors.blue.withOpacity( 0.1),
                  side: BorderSide(color: Colors.blue.withOpacity( 0.3)),
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                response.message,
                style: const TextStyle(fontSize: 14),
              ),
            ),

            // Notes if any
            if (response.organizerNotes != null && response.organizerNotes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity( 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity( 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.note, size: 16, color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Your Notes:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      response.organizerNotes!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addNotes(response),
                    icon: const Icon(Icons.note_add),
                    label: const Text('Notes'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PopupMenuButton<ResponseStatus>(
                    onSelected: (status) => _updateResponseStatus(response, status),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.deepPurple),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.more_vert, color: Colors.deepPurple, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Actions',
                            style: TextStyle(color: Colors.deepPurple),
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => [
                      if (response.status != ResponseStatus.reviewed)
                        PopupMenuItem(
                          value: ResponseStatus.reviewed,
                          child: Row(
                            children: [
                              Icon(Icons.visibility, size: 18, color: Colors.blue[600]),
                              const SizedBox(width: 8),
                              const Text('Mark as Reviewed'),
                            ],
                          ),
                        ),
                      if (response.status != ResponseStatus.contacted)
                        PopupMenuItem(
                          value: ResponseStatus.contacted,
                          child: Row(
                            children: [
                              Icon(Icons.phone, size: 18, color: Colors.orange[600]),
                              const SizedBox(width: 8),
                              const Text('Mark as Contacted'),
                            ],
                          ),
                        ),
                      if (response.status != ResponseStatus.accepted)
                        PopupMenuItem(
                          value: ResponseStatus.accepted,
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 18, color: Colors.green[600]),
                              const SizedBox(width: 8),
                              const Text('Accept Vendor'),
                            ],
                          ),
                        ),
                      if (response.status != ResponseStatus.rejected)
                        PopupMenuItem(
                          value: ResponseStatus.rejected,
                          child: Row(
                            children: [
                              Icon(Icons.cancel, size: 18, color: Colors.red[600]),
                              const SizedBox(width: 8),
                              const Text('Reject Vendor'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Timestamp
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Received ${_formatTimestamp(response.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ResponseStatus status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case ResponseStatus.newResponse:
        color = Colors.blue;
        icon = Icons.new_releases;
        label = 'New';
        break;
      case ResponseStatus.reviewed:
        color = Colors.orange;
        icon = Icons.visibility;
        label = 'Reviewed';
        break;
      case ResponseStatus.contacted:
        color = Colors.purple;
        icon = Icons.phone;
        label = 'Contacted';
        break;
      case ResponseStatus.accepted:
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Accepted';
        break;
      case ResponseStatus.rejected:
        color = Colors.red;
        icon = Icons.cancel;
        label = 'Rejected';
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
          Icon(icon, size: 12, color: color),
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
    );
  }

  Widget _buildMetricChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity( 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity( 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
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
            Icon(
              Icons.inbox,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Responses Yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'all'
                  ? 'Vendors haven\'t responded to this post yet. Give it some time!'
                  : 'No responses match the selected filter.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_selectedFilter != 'all')
              ElevatedButton(
                onPressed: () {
                  setState(() => _selectedFilter = 'all');
                  _loadPostAndResponses();
                },
                child: const Text('View All Responses'),
              ),
          ],
        ),
      ),
    );
  }

  String _formatFilterName(String filter) {
    switch (filter) {
      case 'all':
        return 'All';
      case 'newResponse':
        return 'New';
      case 'reviewed':
        return 'Reviewed';
      case 'contacted':
        return 'Contacted';
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      default:
        return filter;
    }
  }

  String _formatStatus(ResponseStatus status) {
    switch (status) {
      case ResponseStatus.newResponse:
        return 'New';
      case ResponseStatus.reviewed:
        return 'Reviewed';
      case ResponseStatus.contacted:
        return 'Contacted';
      case ResponseStatus.accepted:
        return 'Accepted';
      case ResponseStatus.rejected:
        return 'Rejected';
    }
  }

  String _formatCategoryName(String category) {
    return category.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}