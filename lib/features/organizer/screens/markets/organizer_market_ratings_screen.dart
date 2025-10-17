import 'package:flutter/material.dart';
import 'package:hipop/core/widgets/hipop_app_bar.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/organizer/screens/markets/market_ratings_tab.dart';

/// Screen wrapper for organizer market ratings
class OrganizerMarketRatingsScreen extends StatelessWidget {
  const OrganizerMarketRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: const HiPopAppBar(
        title: 'Market Ratings',
        userRole: 'organizer',
        centerTitle: true,
      ),
      body: const MarketRatingsTab(),
    );
  }
}