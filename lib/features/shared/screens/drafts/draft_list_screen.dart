import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/hipop_colors.dart';
import '../../models/form_draft.dart';
import '../../services/drafts/form_draft_service.dart';

/// Screen to view and manage all saved drafts
/// Allows users to resume, delete, or start new forms
class DraftListScreen extends StatefulWidget {
  const DraftListScreen({super.key});

  @override
  State<DraftListScreen> createState() => _DraftListScreenState();
}

class _DraftListScreenState extends State<DraftListScreen>
    with SingleTickerProviderStateMixin {
  final FormDraftService _draftService = FormDraftService();
  late TabController _tabController;

  List<FormDraft> _allDrafts = [];
  List<FormDraft> _popupDrafts = [];
  List<FormDraft> _marketDrafts = [];
  List<FormDraft> _eventDrafts = [];
  bool _isLoading = true;
  DraftType? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0:
              _selectedFilter = null;
              break;
            case 1:
              _selectedFilter = DraftType.popup;
              break;
            case 2:
              _selectedFilter = DraftType.market;
              break;
            case 3:
              _selectedFilter = DraftType.event;
              break;
          }
        });
      }
    });
    _loadDrafts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDrafts() async {
    setState(() => _isLoading = true);

    try {
      final drafts = await _draftService.getUserDrafts();

      setState(() {
        _allDrafts = drafts;
        _popupDrafts = drafts.where((d) => d.type == DraftType.popup).toList();
        _marketDrafts = drafts.where((d) => d.type == DraftType.market).toList();
        _eventDrafts = drafts.where((d) => d.type == DraftType.event).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading drafts: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  Future<void> _deleteDraft(FormDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draft?'),
        content: Text(
          'This will permanently delete your ${draft.typeName} draft. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: HiPopColors.errorPlum,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _draftService.deleteDraft(draft.id);
        HapticFeedback.mediumImpact();
        await _loadDrafts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Draft deleted'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting draft: $e'),
              backgroundColor: HiPopColors.errorPlum,
            ),
          );
        }
      }
    }
  }

  void _resumeDraft(FormDraft draft) {
    HapticFeedback.lightImpact();

    // Navigate to appropriate form screen based on draft type
    switch (draft.type) {
      case DraftType.popup:
        context.push('/vendor/create-popup', extra: {'draftId': draft.id});
        break;
      case DraftType.market:
        context.push('/organizer/create-market', extra: {'draftId': draft.id});
        break;
      case DraftType.event:
        context.push('/organizer/create-event', extra: {'draftId': draft.id});
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? HiPopColors.darkBackground
          : HiPopColors.lightBackground,
      appBar: AppBar(
        title: const Text('Saved Drafts'),
        backgroundColor: isDarkMode
            ? HiPopColors.darkSurface
            : HiPopColors.lightSurface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: HiPopColors.primaryDeepSage,
          labelColor: HiPopColors.primaryDeepSage,
          unselectedLabelColor: isDarkMode
              ? HiPopColors.darkTextTertiary
              : HiPopColors.lightTextTertiary,
          tabs: [
            Tab(
              text: 'All',
              icon: _buildTabIcon(Icons.drafts, _allDrafts.length),
            ),
            Tab(
              text: 'Pop-ups',
              icon: _buildTabIcon(Icons.storefront, _popupDrafts.length),
            ),
            Tab(
              text: 'Markets',
              icon: _buildTabIcon(Icons.location_city, _marketDrafts.length),
            ),
            Tab(
              text: 'Events',
              icon: _buildTabIcon(Icons.event, _eventDrafts.length),
            ),
          ],
        ),
        actions: [
          if (_allDrafts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _showClearAllDialog,
              tooltip: 'Clear all drafts',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDraftList(_allDrafts),
                _buildDraftList(_popupDrafts),
                _buildDraftList(_marketDrafts),
                _buildDraftList(_eventDrafts),
              ],
            ),
    );
  }

  Widget _buildTabIcon(IconData icon, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 24),
        if (count > 0)
          Positioned(
            right: -8,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: HiPopColors.primaryDeepSage,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                count.toString(),
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
  }

  Widget _buildDraftList(List<FormDraft> drafts) {
    if (drafts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadDrafts,
      color: HiPopColors.primaryDeepSage,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: drafts.length,
        itemBuilder: (context, index) {
          final draft = drafts[index];
          return _DraftCard(
            draft: draft,
            onResume: () => _resumeDraft(draft),
            onDelete: () => _deleteDraft(draft),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.drafts_outlined,
              size: 80,
              color: isDarkMode
                  ? HiPopColors.darkTextTertiary
                  : HiPopColors.lightTextTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No drafts saved',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: isDarkMode
                        ? HiPopColors.darkTextSecondary
                        : HiPopColors.lightTextSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _getEmptyStateMessage(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDarkMode
                        ? HiPopColors.darkTextTertiary
                        : HiPopColors.lightTextTertiary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildCreateNewButton(),
          ],
        ),
      ),
    );
  }

  String _getEmptyStateMessage() {
    switch (_selectedFilter) {
      case DraftType.popup:
        return 'Your pop-up drafts will appear here';
      case DraftType.market:
        return 'Your market drafts will appear here';
      case DraftType.event:
        return 'Your event drafts will appear here';
      case null:
        return 'Drafts are automatically saved as you fill out forms';
    }
  }

  Widget _buildCreateNewButton() {
    if (_selectedFilter == null) return const SizedBox.shrink();

    String label;
    VoidCallback onPressed;

    switch (_selectedFilter) {
      case DraftType.popup:
        label = 'Create Pop-up';
        onPressed = () => context.push('/vendor/create-popup');
        break;
      case DraftType.market:
        label = 'Create Market';
        onPressed = () => context.push('/organizer/create-market');
        break;
      case DraftType.event:
        label = 'Create Event';
        onPressed = () => context.push('/organizer/create-event');
        break;
      default:
        return const SizedBox.shrink();
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(_selectedFilter!.icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: _selectedFilter!.color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Drafts?'),
        content: const Text(
          'This will permanently delete all your saved drafts. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _draftService.clearAllDrafts();
              HapticFeedback.heavyImpact();
              await _loadDrafts();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All drafts cleared'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: HiPopColors.errorPlum,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  final FormDraft draft;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  const _DraftCard({
    required this.draft,
    required this.onResume,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final title = draft.formData['name'] ??
        draft.formData['vendorName'] ??
        'Untitled ${draft.typeName}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isDarkMode ? HiPopColors.darkSurface : HiPopColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: draft.isRecent
              ? draft.type.color.withOpacity(0.3)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onResume,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: draft.type.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      draft.type.icon,
                      color: draft.type.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? HiPopColors.darkTextPrimary
                                : HiPopColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: isDarkMode
                                  ? HiPopColors.darkTextTertiary
                                  : HiPopColors.lightTextTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              draft.ageDescription,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDarkMode
                                    ? HiPopColors.darkTextTertiary
                                    : HiPopColors.lightTextTertiary,
                              ),
                            ),
                            if (draft.isRecent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: HiPopColors.successGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Recent',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: HiPopColors.successGreen,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: isDarkMode
                          ? HiPopColors.darkTextTertiary
                          : HiPopColors.lightTextTertiary,
                    ),
                    onPressed: onDelete,
                    tooltip: 'Delete draft',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: draft.completionPercentage / 100,
                  minHeight: 6,
                  backgroundColor: isDarkMode
                      ? HiPopColors.darkBorder
                      : HiPopColors.lightBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(draft.completionPercentage),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${draft.completionPercentage.toInt()}% complete',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDarkMode
                      ? HiPopColors.darkTextTertiary
                      : HiPopColors.lightTextTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 80) {
      return HiPopColors.successGreen;
    } else if (percentage >= 50) {
      return HiPopColors.warningAmber;
    } else {
      return HiPopColors.infoBlueGray;
    }
  }
}