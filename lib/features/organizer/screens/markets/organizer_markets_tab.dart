import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/market/models/market.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
import 'package:intl/intl.dart';

/// Markets Tab - Market and event creation/management
/// Primary hub for organizers to manage their markets and events
class OrganizerMarketsTab extends StatefulWidget {
  const OrganizerMarketsTab({super.key});

  @override
  State<OrganizerMarketsTab> createState() => _OrganizerMarketsTabState();
}

class _OrganizerMarketsTabState extends State<OrganizerMarketsTab>
    with AutomaticKeepAliveClientMixin {
  final String? _organizerId = FirebaseAuth.instance.currentUser?.uid;
  bool _showPastMarkets = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text(
          'My Markets',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: HiPopColors.darkSurface,
        foregroundColor: HiPopColors.darkTextPrimary,
        elevation: 0,
        actions: [
          // Toggle between upcoming and past markets
          TextButton.icon(
            icon: Icon(
              _showPastMarkets ? Icons.upcoming : Icons.history,
              size: 18,
              color: HiPopColors.organizerAccent,
            ),
            label: Text(
              _showPastMarkets ? 'Upcoming' : 'Past',
              style: TextStyle(
                color: HiPopColors.organizerAccent,
                fontSize: 14,
              ),
            ),
            onPressed: () {
              setState(() {
                _showPastMarkets = !_showPastMarkets;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('markets')
            .where('organizerId', isEqualTo: _organizerId)
            .orderBy('eventDate', descending: _showPastMarkets)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget(message: 'Loading markets...');
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final markets = snapshot.data!.docs;
          final now = DateTime.now();
          final filteredMarkets = markets.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final marketDate = (data['eventDate'] as Timestamp).toDate();
            return _showPastMarkets ? marketDate.isBefore(now) : marketDate.isAfter(now);
          }).toList();

          if (filteredMarkets.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredMarkets.length,
            itemBuilder: (context, index) {
              final marketDoc = filteredMarkets[index];
              final market = Market.fromFirestore(marketDoc);
              return _buildMarketCard(market);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/organizer/create-market'),
        backgroundColor: HiPopColors.organizerAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Market',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showPastMarkets ? Icons.history : Icons.calendar_today,
            size: 80,
            color: HiPopColors.darkTextTertiary.withOpacity( 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _showPastMarkets
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
            _showPastMarkets
                ? 'Your past markets will appear here'
                : 'Create your first market to get started',
            style: TextStyle(
              fontSize: 14,
              color: HiPopColors.darkTextTertiary,
            ),
          ),
          if (!_showPastMarkets) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/organizer/create-market'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.organizerAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Create Market'),
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
              ? HiPopColors.organizerAccent.withOpacity( 0.3)
              : HiPopColors.darkBorder,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/organizer/edit-market/${market.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Market name and status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      market.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.darkTextPrimary,
                      ),
                    ),
                  ),
                  if (isUpcoming)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: HiPopColors.organizerAccent.withOpacity( 0.1),
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
              // Location
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: HiPopColors.darkTextTertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      market.address,
                      style: TextStyle(
                        fontSize: 14,
                        color: HiPopColors.darkTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stats row
              Row(
                children: [
                  _buildStatChip(
                    icon: Icons.store,
                    label: '$vendorCount vendors',
                    color: HiPopColors.vendorAccent,
                  ),
                  const SizedBox(width: 12),
                  // TODO: Add events when available
                ],
              ),
              // Action buttons
              if (isUpcoming) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/organizer/edit-market/${market.id}'),
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
                        onPressed: () => context.push('/organizer/vendor-management?marketId=${market.id}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HiPopColors.vendorAccent,
                          side: BorderSide(color: HiPopColors.vendorAccent),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.groups, size: 16),
                        label: const Text('Vendors'),
                      ),
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

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity( 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}