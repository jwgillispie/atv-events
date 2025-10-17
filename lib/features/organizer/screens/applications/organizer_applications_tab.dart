import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../shared/blocs/application/application_bloc.dart';
import '../../../shared/blocs/application/application_event.dart';
import '../../../shared/blocs/application/application_state.dart';
import '../../../shared/models/vendor_application.dart';
import '../../../shared/widgets/applications/application_status_card.dart';
import '../../../shared/widgets/applications/application_quick_actions.dart';

/// Organizer tab for reviewing and managing vendor applications
/// Shows filterable list with quick approve/deny actions
class OrganizerApplicationsTab extends StatefulWidget {
  final String marketId;
  final String marketName;

  const OrganizerApplicationsTab({
    super.key,
    required this.marketId,
    required this.marketName,
  });

  @override
  State<OrganizerApplicationsTab> createState() => _OrganizerApplicationsTabState();
}

class _OrganizerApplicationsTabState extends State<OrganizerApplicationsTab> {
  ApplicationStatus? _filterStatus;
  String? _actioningApplicationId;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  void _loadApplications() {
    context.read<ApplicationBloc>().add(
          LoadMarketApplicationsEvent(
            marketId: widget.marketId,
            filterStatus: _filterStatus,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ApplicationBloc, ApplicationState>(
      listener: (context, state) {
        if (state is ApplicationApproved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Application approved! Vendor notified.')),
          );
          setState(() => _actioningApplicationId = null);
        } else if (state is ApplicationDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Application denied.')),
          );
          setState(() => _actioningApplicationId = null);
        } else if (state is ApplicationActionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${state.error}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _actioningApplicationId = null);
        }
      },
      child: BlocBuilder<ApplicationBloc, ApplicationState>(
        builder: (context, state) {
          if (state is ApplicationLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is MarketApplicationsLoaded) {
            return _buildApplicationsList(state);
          }

          return _buildEmptyState();
        },
      ),
    );
  }

  Widget _buildApplicationsList(MarketApplicationsLoaded state) {
    return RefreshIndicator(
      onRefresh: () async => _loadApplications(),
      child: Column(
        children: [
          // Header with stats and filter chips
          _buildHeader(state),

          // Applications list
          Expanded(
            child: state.applications.isEmpty
                ? _buildEmptyFilterState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.applications.length,
                    itemBuilder: (context, index) {
                      final application = state.applications[index];
                      final isActioning = _actioningApplicationId == application.id;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ApplicationStatusCard(
                          application: application,
                          showVendorInfo: true,
                          onTap: () => _showApplicationDetails(application),
                          onApprovePressed: application.isPending && !isActioning
                              ? () => _handleApprove(application)
                              : null,
                          onDenyPressed: application.isPending && !isActioning
                              ? () => _handleDeny(application)
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(MarketApplicationsLoaded state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  state.pendingCount.toString(),
                  Colors.orange,
                  Icons.schedule,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Approved',
                  state.approvedCount.toString(),
                  Colors.blue,
                  Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Confirmed',
                  state.confirmedCount.toString(),
                  Colors.green,
                  Icons.verified,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Spots remaining
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: state.isFull ? Colors.red.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: state.isFull
                    ? Colors.red.withValues(alpha: 0.3)
                    : Colors.blue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  state.isFull ? Icons.warning : Icons.info_outline,
                  size: 20,
                  color: state.isFull ? Colors.red[700] : Colors.blue[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.isFull
                        ? 'Market Full - No spots available'
                        : '${state.spotsRemaining} of ${state.spotsTotal} spots remaining (${state.fillPercentage.toStringAsFixed(0)}% filled)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: state.isFull ? Colors.red[700] : Colors.blue[700],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', null, state.applications.length),
                _buildFilterChip('Pending', ApplicationStatus.pending, state.pendingCount),
                _buildFilterChip('Approved', ApplicationStatus.approved, state.approvedCount),
                _buildFilterChip('Confirmed', ApplicationStatus.confirmed, state.confirmedCount),
                _buildFilterChip('Denied', ApplicationStatus.denied, state.deniedCount),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, ApplicationStatus? status, int count) {
    final isSelected = _filterStatus == status;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label ($count)'),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _filterStatus = selected ? status : null);
          _loadApplications();
        },
        backgroundColor: Colors.white,
        selectedColor: Colors.blue.withValues(alpha: 0.2),
        checkmarkColor: Colors.blue,
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
            Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Applications Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Vendor applications will appear here',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFilterState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Applications Match Filter',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() => _filterStatus = null);
                _loadApplications();
              },
              child: const Text('Clear Filter'),
            ),
          ],
        ),
      ),
    );
  }

  void _showApplicationDetails(VendorApplication application) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<ApplicationBloc>(),
        child: ApplicationReviewDialog(
          application: application,
          onApprove: () => _handleApprove(application),
          onDeny: (note) => _handleDenyWithNote(application, note),
        ),
      ),
    );
  }

  void _handleApprove(VendorApplication application) {
    setState(() => _actioningApplicationId = application.id);
    context.read<ApplicationBloc>().add(
          ApproveApplicationEvent(applicationId: application.id),
        );
  }

  void _handleDeny(VendorApplication application) {
    // Show deny dialog with note option
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deny Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Deny ${application.vendorName}\'s application?'),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Let the vendor know why...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              noteController.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final note = noteController.text.trim();
              noteController.dispose();
              Navigator.pop(context);
              _handleDenyWithNote(application, note.isEmpty ? null : note);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Deny'),
          ),
        ],
      ),
    );
  }

  void _handleDenyWithNote(VendorApplication application, String? note) {
    setState(() => _actioningApplicationId = application.id);
    context.read<ApplicationBloc>().add(
          DenyApplicationEvent(
            applicationId: application.id,
            denialNote: note,
          ),
        );
  }
}
