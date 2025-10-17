import 'package:flutter/material.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import '../../vendor/models/vendor_categories.dart';

/// Advanced category targeting widget for vendor recruitment
/// Allows market organizers to select specific categories to target vendors
class CategoryTargetingSection extends StatefulWidget {
  final List<String> selectedCategories;
  final Function(List<String>) onCategoriesChanged;
  final bool isExpanded;

  const CategoryTargetingSection({
    super.key,
    required this.selectedCategories,
    required this.onCategoriesChanged,
    this.isExpanded = false,
  });

  @override
  State<CategoryTargetingSection> createState() => _CategoryTargetingSectionState();
}

class _CategoryTargetingSectionState extends State<CategoryTargetingSection>
    with TickerProviderStateMixin {

  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late AnimationController _categoryRevealController;
  late Animation<double> _categoryRevealAnimation;

  final TextEditingController _searchController = TextEditingController();

  List<String> _selectedCategories = [];
  Map<String, bool> _expandedGroups = {};
  String _searchQuery = '';
  bool _showAllCategories = false;

  @override
  void initState() {
    super.initState();

    _selectedCategories = List.from(widget.selectedCategories);

    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );

    _categoryRevealController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _categoryRevealAnimation = CurvedAnimation(
      parent: _categoryRevealController,
      curve: Curves.easeOut,
    );

    if (widget.isExpanded) {
      _expandController.value = 1.0;
      _categoryRevealController.value = 1.0;
    }

    // Initialize all groups as collapsed
    for (final group in VendorCategories.getGroupNames()) {
      _expandedGroups[group] = false;
    }
  }

  @override
  void didUpdateWidget(CategoryTargetingSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _expandController.forward();
        Future.delayed(const Duration(milliseconds: 150), () {
          _categoryRevealController.forward();
        });
      } else {
        _categoryRevealController.reverse();
        _expandController.reverse();
      }
    }

    if (widget.selectedCategories != oldWidget.selectedCategories) {
      setState(() {
        _selectedCategories = List.from(widget.selectedCategories);
      });
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    _categoryRevealController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
    widget.onCategoriesChanged(_selectedCategories);
  }

  void _toggleGroup(String group) {
    final categories = VendorCategories.getCategoriesForGroup(group);
    final allSelected = categories.every((cat) => _selectedCategories.contains(cat));

    setState(() {
      if (allSelected) {
        _selectedCategories.removeWhere((cat) => categories.contains(cat));
      } else {
        for (final category in categories) {
          if (!_selectedCategories.contains(category)) {
            _selectedCategories.add(category);
          }
        }
      }
    });
    widget.onCategoriesChanged(_selectedCategories);
  }

  bool _isGroupSelected(String group) {
    final categories = VendorCategories.getCategoriesForGroup(group);
    return categories.isNotEmpty &&
           categories.every((cat) => _selectedCategories.contains(cat));
  }

  bool _isGroupPartiallySelected(String group) {
    final categories = VendorCategories.getCategoriesForGroup(group);
    final selectedCount = categories.where((cat) => _selectedCategories.contains(cat)).length;
    return selectedCount > 0 && selectedCount < categories.length;
  }

  int _getGroupSelectedCount(String group) {
    final categories = VendorCategories.getCategoriesForGroup(group);
    return categories.where((cat) => _selectedCategories.contains(cat)).length;
  }

  List<String> _getFilteredCategories() {
    if (_searchQuery.isEmpty) return [];
    return VendorCategories.searchCategories(_searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _expandAnimation,
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HiPopColors.darkSurfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedCategories.isNotEmpty
                    ? HiPopColors.accentMauve.withValues(alpha: 0.5)
                    : HiPopColors.darkBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.category,
                        color: HiPopColors.accentMauve,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Target Specific Vendors',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedCategories.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: HiPopColors.successGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_selectedCategories.length} selected',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: HiPopColors.successGreen,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedCategories.isEmpty
                      ? 'Select vendor categories to target specific types of vendors'
                      : 'Your recruitment post will only be shown to vendors in these categories',
                    style: TextStyle(
                      fontSize: 13,
                      color: _selectedCategories.isEmpty
                        ? HiPopColors.darkTextSecondary
                        : HiPopColors.successGreen,
                    ),
                  ),

                  // Search Bar
                  FadeTransition(
                    opacity: _categoryRevealAnimation,
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        style: TextStyle(
                          color: HiPopColors.darkTextPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search categories...',
                          hintStyle: TextStyle(
                            color: HiPopColors.darkTextTertiary,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: HiPopColors.darkTextTertiary,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: HiPopColors.darkSurface,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: HiPopColors.darkBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: HiPopColors.accentMauve,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Category Selection Area
            FadeTransition(
              opacity: _categoryRevealAnimation,
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                child: _searchQuery.isNotEmpty
                  ? _buildSearchResults()
                  : _buildCategoryGroups(),
              ),
            ),

            // Selected Categories Summary
            if (_selectedCategories.isNotEmpty)
              FadeTransition(
                opacity: _categoryRevealAnimation,
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HiPopColors.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: HiPopColors.successGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: HiPopColors.successGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Targeting Active',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: HiPopColors.successGreen,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategories.clear();
                              });
                              widget.onCategoriesChanged(_selectedCategories);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: HiPopColors.errorPlum,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Clear All',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _selectedCategories.take(5).map((category) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: HiPopColors.darkSurface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: HiPopColors.successGreen.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 11,
                                color: HiPopColors.darkTextPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_selectedCategories.length > 5) ...[
                        const SizedBox(height: 4),
                        Text(
                          '+${_selectedCategories.length - 5} more categories',
                          style: TextStyle(
                            fontSize: 11,
                            color: HiPopColors.darkTextSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final results = _getFilteredCategories();

    if (results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HiPopColors.darkSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: HiPopColors.darkBorder),
        ),
        child: Center(
          child: Text(
            'No categories found for "$_searchQuery"',
            style: TextStyle(
              color: HiPopColors.darkTextTertiary,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HiPopColors.darkBorder),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.all(8),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final category = results[index];
          final group = VendorCategories.getGroupForCategory(category);
          final isSelected = _selectedCategories.contains(category);

          return InkWell(
            onTap: () => _toggleCategory(category),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: isSelected ? HiPopColors.successGreen : HiPopColors.darkTextTertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: TextStyle(
                            color: HiPopColors.darkTextPrimary,
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (group != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            group,
                            style: TextStyle(
                              color: HiPopColors.darkTextTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryGroups() {
    final popularGroups = [
      'Fresh & Produce',
      'Prepared Foods',
      'Baked Goods & Sweets',
      'Arts & Crafts',
      'Beauty & Wellness',
    ];

    final groupsToShow = _showAllCategories
      ? VendorCategories.getGroupNames()
      : popularGroups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Popular Categories Header
        if (!_showAllCategories) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  'Popular Categories',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HiPopColors.darkTextSecondary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showAllCategories = true;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: HiPopColors.accentMauve,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Show All',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: HiPopColors.accentMauve,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Category Groups
        ...groupsToShow.map((group) => _buildCategoryGroup(group)),

        // Show Less Button
        if (_showAllCategories) ...[
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _showAllCategories = false;
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: HiPopColors.darkTextSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.keyboard_arrow_up,
                    size: 18,
                    color: HiPopColors.darkTextSecondary,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Show Less',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryGroup(String group) {
    final isExpanded = _expandedGroups[group] ?? false;
    final isSelected = _isGroupSelected(group);
    final isPartiallySelected = _isGroupPartiallySelected(group);
    final selectedCount = _getGroupSelectedCount(group);
    final totalCount = VendorCategories.getCategoriesForGroup(group).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected || isPartiallySelected
            ? HiPopColors.accentMauve.withValues(alpha: 0.5)
            : HiPopColors.darkBorder,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedGroups[group] = !isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Checkbox
                  InkWell(
                    onTap: () => _toggleGroup(group),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isSelected
                          ? Icons.check_box
                          : isPartiallySelected
                            ? Icons.indeterminate_check_box
                            : Icons.check_box_outline_blank,
                        color: isSelected || isPartiallySelected
                          ? HiPopColors.successGreen
                          : HiPopColors.darkTextTertiary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: HiPopColors.darkTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedCount > 0
                            ? '$selectedCount of $totalCount selected'
                            : '$totalCount categories',
                          style: TextStyle(
                            fontSize: 11,
                            color: selectedCount > 0
                              ? HiPopColors.successGreen
                              : HiPopColors.darkTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: HiPopColors.darkTextSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Categories
          if (isExpanded) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: VendorCategories.getCategoriesForGroup(group).map((category) {
                  final isSelected = _selectedCategories.contains(category);

                  return InkWell(
                    onTap: () => _toggleCategory(category),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                          ? HiPopColors.successGreen.withValues(alpha: 0.2)
                          : HiPopColors.darkSurfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                            ? HiPopColors.successGreen.withValues(alpha: 0.5)
                            : HiPopColors.darkBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: HiPopColors.successGreen,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                ? HiPopColors.successGreen
                                : HiPopColors.darkTextPrimary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}