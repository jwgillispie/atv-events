import 'package:flutter/material.dart';
import 'package:hipop/features/organizer/screens/profile/organizer_profile_screen.dart';
import 'package:hipop/core/theme/hipop_colors.dart';

/// Profile Tab - Wrapper for existing organizer profile screen
/// Maintains consistency with vendor and shopper profile tabs
class OrganizerProfileTab extends StatefulWidget {
  const OrganizerProfileTab({super.key});

  @override
  State<OrganizerProfileTab> createState() => _OrganizerProfileTabState();
}

class _OrganizerProfileTabState extends State<OrganizerProfileTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Use the existing OrganizerProfileScreen
    return const OrganizerProfileScreen();
  }
}