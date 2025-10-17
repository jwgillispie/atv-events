import 'package:flutter/material.dart';
import 'package:atv_events/features/organizer/screens/vendors/organizer_vendor_discovery_unified.dart';

/// Vendors Tab - Unified vendor discovery and recruitment hub
/// World-class marketplace experience combining recruitment posts and vendor directory
class OrganizerVendorsTab extends StatefulWidget {
  const OrganizerVendorsTab({super.key});

  @override
  State<OrganizerVendorsTab> createState() => _OrganizerVendorsTabState();
}

class _OrganizerVendorsTabState extends State<OrganizerVendorsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Use the new unified vendor discovery screen
    return const OrganizerVendorDiscoveryUnified();
  }
}