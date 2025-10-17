import 'package:flutter/material.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/core/constants/ui_constants.dart';
import 'package:hipop/features/shared/widgets/skeleton_loaders.dart';
import 'package:hipop/features/shopper/widgets/feed_card.dart';

/// Demo screen to showcase world-class loading experience
/// Demonstrates Instagram, LinkedIn, and Twitter-style loading patterns
class LoadingDemoScreen extends StatefulWidget {
  const LoadingDemoScreen({super.key});

  @override
  State<LoadingDemoScreen> createState() => _LoadingDemoScreenState();
}

class _LoadingDemoScreenState extends State<LoadingDemoScreen> {
  bool _isLoading = true;
  int _selectedDemo = 0;

  final List<String> _demoNames = [
    'Instagram-style Feed',
    'LinkedIn-style List',
    'Twitter-style Mixed',
    'Smooth Transition',
  ];

  void _toggleLoading() {
    setState(() {
      _isLoading = !_isLoading;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text('World-Class Loading Demo'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                HiPopColors.shopperAccent,
                HiPopColors.primaryDeepSage,
              ],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Demo selector
          Container(
            padding: const EdgeInsets.all(UIConstants.defaultPadding),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  _demoNames.length,
                  (index) => Padding(
                    padding: EdgeInsets.only(
                      right: index < _demoNames.length - 1 
                        ? UIConstants.smallSpacing 
                        : 0,
                    ),
                    child: ChoiceChip(
                      label: Text(_demoNames[index]),
                      selected: _selectedDemo == index,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedDemo = index;
                            _isLoading = true;
                          });
                        }
                      },
                      selectedColor: HiPopColors.shopperAccent,
                      labelStyle: TextStyle(
                        color: _selectedDemo == index
                            ? Colors.white
                            : HiPopColors.darkTextPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Loading toggle button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UIConstants.defaultPadding,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleLoading,
                    icon: Icon(
                      _isLoading ? Icons.visibility : Icons.hourglass_empty,
                    ),
                    label: Text(
                      _isLoading ? 'Show Content' : 'Show Loading',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HiPopColors.shopperAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: UIConstants.contentSpacing,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: UIConstants.defaultPadding),
          
          // Demo content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(UIConstants.defaultPadding),
              child: _buildDemoContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoContent() {
    switch (_selectedDemo) {
      case 0:
        return _buildInstagramDemo();
      case 1:
        return _buildLinkedInDemo();
      case 2:
        return _buildTwitterDemo();
      case 3:
        return _buildSmoothTransitionDemo();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInstagramDemo() {
    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Instagram-style Feed Loading',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: HiPopColors.darkTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: UIConstants.smallSpacing),
          Text(
            'Clean skeletons with smooth pulse animation, no jarring shimmer',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: HiPopColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: UIConstants.largeSpacing),
          const VendorCardSkeleton(enableAnimation: true),
          const FeedCardSkeleton(
            itemCount: 2,
            enableAnimation: true,
          ),
        ],
      );
    }

    return StaggeredListAnimation(
      itemDelay: const Duration(milliseconds: 50),
      fadeInDuration: const Duration(milliseconds: 400),
      children: [
        Text(
          'Content Loaded!',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: HiPopColors.darkTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: UIConstants.largeSpacing),
        FeedCard.vendorPost(
          id: 'demo1',
          vendorId: 'vendor1',
          vendorName: 'Fresh Farm Produce',
          dateTime: 'Today, 9:00 AM - 3:00 PM',
          location: '123 Market Street, Atlanta, GA',
          description: 'Fresh organic vegetables and fruits from local farms',
          onTap: () {},
          photoUrls: [],
          vendorItems: ['Tomatoes', 'Lettuce', 'Carrots', 'Apples'],
        ),
        FeedCard.market(
          id: 'demo2',
          name: 'Downtown Farmers Market',
          displayInfo: 'Every Saturday',
          address: '456 Main Street, Atlanta, GA',
          description: 'Weekly farmers market featuring local vendors',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildLinkedInDemo() {
    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LinkedIn-style List Loading',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: HiPopColors.darkTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: UIConstants.smallSpacing),
          Text(
            'Professional list skeletons with staggered wave animation',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: HiPopColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: UIConstants.largeSpacing),
          const ListItemSkeleton(
            itemCount: 5,
            enableAnimation: true,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Content Loaded!',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: HiPopColors.darkTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: UIConstants.largeSpacing),
        ...List.generate(5, (index) => _buildListItem(index)),
      ],
    );
  }

  Widget _buildTwitterDemo() {
    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Twitter-style Mixed Feed',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: HiPopColors.darkTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: UIConstants.smallSpacing),
          Text(
            'Combination of different skeleton types with coordinated animations',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: HiPopColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: UIConstants.largeSpacing),
          const FeedCardSkeleton(
            itemCount: 1,
            enableAnimation: true,
          ),
          const SizedBox(height: UIConstants.smallSpacing),
          const VendorCardSkeleton(enableAnimation: true),
          const SizedBox(height: UIConstants.smallSpacing),
          const FeedCardSkeleton(
            itemCount: 1,
            enableAnimation: true,
          ),
        ],
      );
    }

    return StaggeredListAnimation(
      itemDelay: const Duration(milliseconds: 40),
      fadeInDuration: const Duration(milliseconds: 350),
      children: [
        Text(
          'Mixed Content Loaded!',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: HiPopColors.darkTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: UIConstants.largeSpacing),
        FeedCard.event(
          id: 'event1',
          name: 'Summer Food Festival',
          dateTime: 'June 15, 10:00 AM',
          location: 'Central Park, Atlanta',
          description: 'Annual food festival with 50+ vendors',
          tags: ['Food', 'Festival', 'Family'],
          onTap: () {},
        ),
        FeedCard.vendorPost(
          id: 'vendor2',
          vendorId: 'v2',
          vendorName: 'Artisan Bakery',
          dateTime: 'Tomorrow, 8:00 AM',
          location: 'Corner of 5th and Main',
          description: 'Fresh baked goods and pastries',
          onTap: () {},
        ),
        FeedCard.market(
          id: 'market3',
          name: 'Weekend Pop-up Market',
          displayInfo: 'This Weekend',
          address: 'Downtown Plaza',
          description: 'Special weekend market event',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildSmoothTransitionDemo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Smooth Content Transition',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: HiPopColors.darkTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: UIConstants.smallSpacing),
        Text(
          'Seamless fade transition from skeleton to content',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: HiPopColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: UIConstants.largeSpacing),
        SmoothContentTransition(
          isLoading: _isLoading,
          fadeInDuration: const Duration(milliseconds: 400),
          loadingWidget: const Column(
            children: [
              FeedCardSkeleton(
                itemCount: 2,
                enableAnimation: true,
              ),
              SizedBox(height: UIConstants.smallSpacing),
              VendorCardSkeleton(enableAnimation: true),
            ],
          ),
          contentWidget: StaggeredListAnimation(
            children: [
              FeedCard.market(
                id: 'smooth1',
                name: 'Organic Market',
                displayInfo: 'Every Sunday',
                address: 'Green Street Park',
                description: 'All organic produce and products',
                onTap: () {},
              ),
              FeedCard.vendorPost(
                id: 'smooth2',
                vendorId: 'vs2',
                vendorName: 'Local Honey Co.',
                dateTime: 'This Saturday',
                location: 'Market Square',
                description: 'Raw honey and bee products',
                onTap: () {},
              ),
              FeedCard.event(
                id: 'smooth3',
                name: 'Harvest Festival',
                dateTime: 'October 20',
                location: 'City Farm',
                description: 'Celebrate the harvest season',
                tags: ['Harvest', 'Family', 'Local'],
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListItem(int index) {
    final items = [
      ('Atlanta Farmers Market', 'Open today • 8:00 AM - 2:00 PM'),
      ('Sweet Peach Produce', 'Vendor • Fresh fruits available'),
      ('Garden Fresh Veggies', 'Vendor • Organic vegetables'),
      ('Local Artisan Crafts', 'Market • This weekend'),
      ('Farm to Table Festival', 'Event • Next Saturday'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: UIConstants.contentSpacing,
        horizontal: UIConstants.defaultPadding,
      ),
      margin: const EdgeInsets.only(bottom: UIConstants.smallSpacing),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(UIConstants.smallBorderRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: HiPopColors.shopperAccent.withOpacity( 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                items[index].$1[0],
                style: TextStyle(
                  color: HiPopColors.shopperAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: UIConstants.contentSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  items[index].$1,
                  style: const TextStyle(
                    color: HiPopColors.darkTextPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  items[index].$2,
                  style: const TextStyle(
                    color: HiPopColors.darkTextSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}