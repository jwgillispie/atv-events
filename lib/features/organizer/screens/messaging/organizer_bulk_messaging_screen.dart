import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import 'package:atv_events/core/widgets/hipop_app_bar.dart';
import 'package:atv_events/features/organizer/models/bulk_message.dart';
import 'package:atv_events/features/organizer/models/message_template.dart';
import 'package:atv_events/features/organizer/services/communication/bulk_messaging_service.dart';
import 'package:atv_events/features/premium/models/user_subscription.dart';
import 'package:atv_events/features/premium/services/subscription_service.dart';
import 'package:atv_events/features/shared/widgets/common/loading_widget.dart';


class OrganizerBulkMessagingScreen extends StatefulWidget {
  const OrganizerBulkMessagingScreen({super.key});

  @override
  State<OrganizerBulkMessagingScreen> createState() => _OrganizerBulkMessagingScreenState();
}

class _OrganizerBulkMessagingScreenState extends State<OrganizerBulkMessagingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _messageController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bulkMessagingService = BulkMessagingService();
  
  bool _isLoading = false;
  UserSubscription? _subscription;
  List<Map<String, dynamic>> _availableVendors = [];
  final List<String> _selectedVendors = [];
  List<MessageTemplate> _savedTemplates = [];
  MessageTemplate? _selectedTemplate;
  String _selectionMode = 'all'; // all, category, market, custom
  String? _selectedMarket;
  String? _selectedCategory;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeScreen();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    setState(() => _isLoading = true);
    
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      final organizerId = authState.user.uid;
      
      // Bulk messaging is now free for all organizers
      final subscription = await SubscriptionService.getUserSubscription(organizerId);
      
      // Load data for premium users
      await Future.wait([
        _loadAvailableVendors(organizerId),
        _loadSavedTemplates(organizerId),
      ]);
      
      if (mounted) {
        setState(() {
          _subscription = subscription;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAvailableVendors(String organizerId) async {
    try {
      final vendors = await _bulkMessagingService.getOrganizerVendors(organizerId);
      if (mounted) {
        setState(() {
          _availableVendors = vendors;
        });
      }
    } catch (e) {
      // Clear vendors list on error to prevent showing stale data
      if (mounted) {
        setState(() {
          _availableVendors = [];
        });
      }
    }
  }

  Future<void> _loadSavedTemplates(String organizerId) async {
    try {
      final templates = await _bulkMessagingService.getMessageTemplates(organizerId);
      if (mounted) {
        setState(() {
          _savedTemplates = templates;
        });
      }
    } catch (e) {
      // Clear templates list on error to prevent showing stale data
      if (mounted) {
        setState(() {
          _savedTemplates = [];
        });
      }
    }
  }

  // Premium upgrade prompt removed - bulk messaging is now free
  void _showUpgradePrompt_removed() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.diamond, color: Colors.amber.shade600),
            const SizedBox(width: 8),
            const Text('Premium Feature'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bulk Vendor Communications is a Market Organizer Pro feature that includes:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 16),
            Text('• Professional message templates'),
            Text('• Bulk messaging to hundreds of vendors'),
            Text('• Advanced vendor targeting & segmentation'),
            Text('• Delivery tracking and analytics'),
            Text('• Scheduled messaging capabilities'),
            Text('• Response rate monitoring'),
            SizedBox(height: 16),
            Text(
              'Upgrade to Market Organizer Pro for \$69/month to access these powerful communication tools.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop();
            },
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/premium/upgrade?tier=market_organizer');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading communication suite...'),
      );
    }

    if (_subscription == null) {
      return const Scaffold(
        body: Center(
          child: Text('Access denied. Premium subscription required.'),
        ),
      );
    }

    return Scaffold(
      appBar: HiPopAppBar(
        title: 'Vendor Communication Suite',
        userRole: 'vendor',
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Compose', icon: Icon(Icons.edit)),
            Tab(text: 'Templates', icon: Icon(Icons.article)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildComposeTab(),
          _buildTemplatesTab(),
          _buildAnalyticsTab(),
        ],
      ),
    );
  }

  Widget _buildComposeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.diamond, size: 16, color: Colors.amber.shade700),
                const SizedBox(width: 4),
                Text(
                  'Market Organizer Pro',
                  style: TextStyle(
                    color: Colors.amber.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Vendor Selection Section
          _buildVendorSelectionSection(),
          const SizedBox(height: 24),
          
          // Template Selection
          _buildTemplateSelection(),
          const SizedBox(height: 24),
          
          // Message Composition
          _buildMessageComposition(),
          const SizedBox(height: 32),
          
          // Send Button
          _buildSendButton(),
        ],
      ),
    );
  }

  Widget _buildVendorSelectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Recipients',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Selection Mode
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All Vendors'),
                  selected: _selectionMode == 'all',
                  onSelected: (selected) {
                    setState(() {
                      _selectionMode = 'all';
                      _updateSelectedVendors();
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('By Market'),
                  selected: _selectionMode == 'market',
                  onSelected: (selected) {
                    setState(() {
                      _selectionMode = 'market';
                      _updateSelectedVendors();
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('By Category'),
                  selected: _selectionMode == 'category',
                  onSelected: (selected) {
                    setState(() {
                      _selectionMode = 'category';
                      _updateSelectedVendors();
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Custom'),
                  selected: _selectionMode == 'custom',
                  onSelected: (selected) {
                    setState(() {
                      _selectionMode = 'custom';
                      _updateSelectedVendors();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Additional Filters
            if (_selectionMode == 'market') _buildMarketFilter(),
            if (_selectionMode == 'category') _buildCategoryFilter(),
            if (_selectionMode == 'custom') _buildCustomSelection(),
            
            const SizedBox(height: 12),
            
            // Recipients Count
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepPurple.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.people, color: Colors.deepPurple.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '${_getSelectedVendorCount()} vendors selected',
                    style: TextStyle(
                      color: Colors.deepPurple.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _showVendorPreview,
                    child: const Text('Preview'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketFilter() {
    // Get unique markets from vendors
    final markets = _availableVendors
        .where((v) => v['marketName'] != null)
        .map((v) => v['marketName'] as String)
        .toSet()
        .toList();
    
    return DropdownButton<String>(
      hint: const Text('Select Market'),
      value: _selectedMarket,
      isExpanded: true,
      onChanged: (value) {
        setState(() {
          _selectedMarket = value;
          _updateSelectedVendors();
        });
      },
      items: markets.map((market) => DropdownMenuItem(
        value: market,
        child: Text(market),
      )).toList(),
    );
  }

  Widget _buildCategoryFilter() {
    // Get unique categories from vendors
    final categories = _availableVendors
        .where((v) => v['category'] != null)
        .map((v) => v['category'] as String)
        .toSet()
        .toList();
    
    return DropdownButton<String>(
      hint: const Text('Select Category'),
      value: _selectedCategory,
      isExpanded: true,
      onChanged: (value) {
        setState(() {
          _selectedCategory = value;
          _updateSelectedVendors();
        });
      },
      items: categories.map((category) => DropdownMenuItem(
        value: category,
        child: Text(category),
      )).toList(),
    );
  }

  Widget _buildCustomSelection() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        itemCount: _availableVendors.length,
        itemBuilder: (context, index) {
          final vendor = _availableVendors[index];
          final vendorId = vendor['id'] as String;
          final isSelected = _selectedVendors.contains(vendorId);
          
          return CheckboxListTile(
            title: Text(vendor['businessName'] ?? vendor['displayName'] ?? 'Unknown'),
            subtitle: Text(vendor['marketName'] ?? 'No market'),
            value: isSelected,
            onChanged: (selected) {
              setState(() {
                if (selected == true) {
                  _selectedVendors.add(vendorId);
                } else {
                  _selectedVendors.remove(vendorId);
                }
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildTemplateSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Message Template',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _createNewTemplate,
                  icon: const Icon(Icons.add),
                  label: const Text('New Template'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_savedTemplates.isNotEmpty)
              DropdownButton<MessageTemplate>(
                hint: const Text('Choose a template or write custom message'),
                value: _selectedTemplate,
                isExpanded: true,
                onChanged: (template) {
                  setState(() {
                    _selectedTemplate = template;
                    if (template != null) {
                      _subjectController.text = template.subject;
                      _messageController.text = template.content;
                    }
                  });
                },
                items: _savedTemplates.map((template) => DropdownMenuItem(
                  value: template,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(template.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text(template.subject, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                )).toList(),
              ),
            
            if (_savedTemplates.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No saved templates. Create your first template to get started.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposition() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compose Message',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Subject Line
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject Line',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.subject),
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            
            // Message Content
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message Content',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.message),
                ),
              ),
              maxLines: 8,
              maxLength: 2000,
            ),
            const SizedBox(height: 16),
            
            // Variable Insertion Helper
            Wrap(
              spacing: 8,
              children: [
                _buildVariableChip('Vendor Name', '{vendor_name}'),
                _buildVariableChip('Market Name', '{market_name}'),
                _buildVariableChip('Today\'s Date', '{current_date}'),
                _buildVariableChip('Your Name', '{organizer_name}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariableChip(String label, String variable) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        final currentText = _messageController.text;
        final cursorPos = _messageController.selection.baseOffset;
        final newText = currentText.substring(0, cursorPos) +
            variable +
            currentText.substring(cursorPos);
        _messageController.text = newText;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: cursorPos + variable.length),
        );
      },
    );
  }

  Widget _buildSendButton() {
    final recipientCount = _getSelectedVendorCount();
    final hasContent = _subjectController.text.isNotEmpty && 
                      _messageController.text.isNotEmpty;
    final canSend = recipientCount > 0 && hasContent;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canSend ? _sendBulkMessage : null,
        icon: const Icon(Icons.send),
        label: Text('Send to $recipientCount Vendors'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Message Templates',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _createNewTemplate,
                icon: const Icon(Icons.add),
                label: const Text('Create Template'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_savedTemplates.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.article,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Templates Created Yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create professional message templates for common communications.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _savedTemplates.length,
                itemBuilder: (context, index) {
                  final template = _savedTemplates[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(template.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(template.subject),
                          const SizedBox(height: 4),
                          Text(
                            template.content.length > 100 
                                ? '${template.content.substring(0, 100)}...'
                                : template.content,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'use',
                            child: const Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Use Template'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'edit',
                            child: const Row(
                              children: [
                                Icon(Icons.edit_note),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red.shade700),
                                const SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red.shade700)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) => _handleTemplateAction(template, value.toString()),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Communication Analytics',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Analytics Coming Soon',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Track delivery rates, open rates, and vendor engagement.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateSelectedVendors() {
    setState(() {
      _selectedVendors.clear();
      
      switch (_selectionMode) {
        case 'all':
          _selectedVendors.addAll(_availableVendors.map((v) => v['id'] as String));
          break;
        case 'market':
          if (_selectedMarket != null) {
            _selectedVendors.addAll(
              _availableVendors
                  .where((v) => v['marketName'] == _selectedMarket)
                  .map((v) => v['id'] as String)
            );
          }
          break;
        case 'category':
          if (_selectedCategory != null) {
            _selectedVendors.addAll(
              _availableVendors
                  .where((v) => v['category'] == _selectedCategory)
                  .map((v) => v['id'] as String)
            );
          }
          break;
        case 'custom':
          // Custom selection is handled in the UI
          break;
      }
    });
  }

  int _getSelectedVendorCount() {
    return _selectedVendors.length;
  }

  void _showVendorPreview() {
    final selectedVendorDetails = _availableVendors
        .where((v) => _selectedVendors.contains(v['id']))
        .toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Selected Vendors (${selectedVendorDetails.length})'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: selectedVendorDetails.length,
            itemBuilder: (context, index) {
              final vendor = selectedVendorDetails[index];
              return ListTile(
                title: Text(vendor['businessName'] ?? vendor['displayName'] ?? 'Unknown'),
                subtitle: Text(vendor['marketName'] ?? 'No market'),
                leading: CircleAvatar(
                  child: Text((vendor['displayName'] ?? 'U')[0]),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _createNewTemplate() {
    showDialog(
      context: context,
      builder: (context) => _TemplateCreationDialog(
        onSave: (template) async {
          final authState = context.read<AuthBloc>().state;
          await _bulkMessagingService.saveMessageTemplate(template);
          if (mounted && authState is Authenticated) {
            await _loadSavedTemplates(authState.user.uid);
          }
        },
      ),
    );
  }

  void _handleTemplateAction(MessageTemplate template, String action) {
    switch (action) {
      case 'use':
        _tabController.animateTo(0);
        setState(() {
          _selectedTemplate = template;
          _subjectController.text = template.subject;
          _messageController.text = template.content;
        });
        break;
      case 'edit':
        _showEditTemplateDialog(template);
        break;
      case 'delete':
        _confirmDeleteTemplate(template);
        break;
    }
  }

  void _showEditTemplateDialog(MessageTemplate template) {
    showDialog(
      context: context,
      builder: (context) => _TemplateCreationDialog(
        template: template,
        onSave: (updatedTemplate) async {
          final authState = context.read<AuthBloc>().state;
          await _bulkMessagingService.saveMessageTemplate(updatedTemplate);
          if (mounted && authState is Authenticated) {
            await _loadSavedTemplates(authState.user.uid);
          }
        },
      ),
    );
  }

  void _confirmDeleteTemplate(MessageTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (mounted) {
                final authState = context.read<AuthBloc>().state;
                Navigator.of(context).pop();
                await _bulkMessagingService.deleteMessageTemplate(template.id);
                if (mounted && authState is Authenticated) {
                  await _loadSavedTemplates(authState.user.uid);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _sendBulkMessage() async {
    if (_selectedVendors.isEmpty || _messageController.text.isEmpty) {
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Bulk Message'),
        content: Text(
          'Send "${_subjectController.text}" to ${_selectedVendors.length} vendors?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Message'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      if (!mounted) return;
      final authState = context.read<AuthBloc>().state as Authenticated;
      final organizerId = authState.user.uid;

      final bulkMessage = BulkMessage(
        id: '',
        organizerId: organizerId,
        subject: _subjectController.text,
        content: _messageController.text,
        recipientIds: _selectedVendors,
        selectionCriteria: {
          'mode': _selectionMode,
          'market': _selectedMarket,
          'category': _selectedCategory,
        },
        status: MessageStatus.pending,
        createdAt: DateTime.now(),
        scheduledFor: DateTime.now(),
      );

      await _bulkMessagingService.sendBulkMessage(bulkMessage);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message sent to ${_selectedVendors.length} vendors'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reset form
        _messageController.clear();
        _subjectController.clear();
        _selectedTemplate = null;
        _selectedVendors.clear();
        _selectionMode = 'all';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _TemplateCreationDialog extends StatefulWidget {
  final MessageTemplate? template;
  final Function(MessageTemplate) onSave;

  const _TemplateCreationDialog({
    this.template,
    required this.onSave,
  });

  @override
  State<_TemplateCreationDialog> createState() => _TemplateCreationDialogState();
}

class _TemplateCreationDialogState extends State<_TemplateCreationDialog> {
  late TextEditingController _nameController;
  late TextEditingController _subjectController;
  late TextEditingController _contentController;
  String _selectedCategory = 'general';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template?.name ?? '');
    _subjectController = TextEditingController(text: widget.template?.subject ?? '');
    _contentController = TextEditingController(text: widget.template?.content ?? '');
    _selectedCategory = widget.template?.category ?? 'general';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.template == null ? 'Create Template' : 'Edit Template'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Template Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'general', child: Text('General')),
                DropdownMenuItem(value: 'event', child: Text('Event Announcement')),
                DropdownMenuItem(value: 'policy', child: Text('Policy Update')),
                DropdownMenuItem(value: 'invitation', child: Text('Market Invitation')),
                DropdownMenuItem(value: 'reminder', child: Text('Reminder')),
              ],
              onChanged: (value) => setState(() => _selectedCategory = value!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject Line',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Message Content',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveTemplate,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveTemplate() {
    if (_nameController.text.isEmpty ||
        _subjectController.text.isEmpty ||
        _contentController.text.isEmpty) {
      return;
    }

    final template = MessageTemplate(
      id: widget.template?.id ?? '',
      organizerId: widget.template?.organizerId ?? '',
      name: _nameController.text,
      subject: _subjectController.text,
      content: _contentController.text,
      category: _selectedCategory,
      createdAt: widget.template?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      usageCount: widget.template?.usageCount ?? 0,
    );

    widget.onSave(template);
    Navigator.of(context).pop();
  }
}