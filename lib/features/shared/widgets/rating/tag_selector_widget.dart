import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/hipop_colors.dart';

/// Reusable tag selector widget for rating screens
class TagSelectorWidget extends StatelessWidget {
  final List<String> availableTags;
  final List<String> selectedTags;
  final ValueChanged<List<String>> onTagsChanged;
  final String title;
  final String? subtitle;
  final int? maxSelections;
  final bool isOptional;

  const TagSelectorWidget({
    super.key,
    required this.availableTags,
    required this.selectedTags,
    required this.onTagsChanged,
    required this.title,
    this.subtitle,
    this.maxSelections,
    this.isOptional = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (isOptional) ...[
              const SizedBox(width: 8),
              Text(
                '(Optional)',
                style: TextStyle(
                  fontSize: 12,
                  color: HiPopColors.darkTextSecondary,
                ),
              ),
            ],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 12, color: HiPopColors.darkTextSecondary),
          ),
        ],
        if (maxSelections != null) ...[
          const SizedBox(height: 4),
          Text(
            '${selectedTags.length}/$maxSelections selected',
            style: TextStyle(
              fontSize: 11,
              color: selectedTags.length == maxSelections
                  ? HiPopColors.vendorAccent
                  : HiPopColors.darkTextSecondary,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableTags.map((tag) => _buildTagChip(tag)).toList(),
        ),
      ],
    );
  }

  Widget _buildTagChip(String tag) {
    final isSelected = selectedTags.contains(tag);
    final canSelect = maxSelections == null || 
                      selectedTags.length < maxSelections! || 
                      isSelected;

    return GestureDetector(
      onTap: canSelect ? () {
        HapticFeedback.lightImpact();
        final newTags = List<String>.from(selectedTags);
        if (isSelected) {
          newTags.remove(tag);
        } else {
          newTags.add(tag);
        }
        onTagsChanged(newTags);
      } : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? HiPopColors.shopperAccent 
              : canSelect 
                  ? HiPopColors.darkSurface 
                  : HiPopColors.darkSurface.withOpacity( 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? HiPopColors.shopperAccent 
                : canSelect
                    ? HiPopColors.darkBorder
                    : HiPopColors.darkBorder.withOpacity( 0.5),
          ),
        ),
        child: Text(
          _formatTagDisplay(tag),
          style: TextStyle(
            color: isSelected 
                ? Colors.white 
                : canSelect
                    ? HiPopColors.darkTextPrimary
                    : HiPopColors.darkTextSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatTagDisplay(String tag) {
    // Convert kebab-case to title case
    return tag
        .split('-')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

/// Predefined tag sets for different contexts
class RatingTags {
  RatingTags._();

  static const List<String> vendorTags = [
    'friendly-service',
    'knowledgeable',
    'great-prices',
    'unique-products',
    'fresh-quality',
    'quick-service',
    'accepts-cards',
    'gives-samples',
    'patient-with-questions',
    'sustainable-practices',
    'local-sourced',
    'creative-offerings',
  ];

  static const List<String> marketTags = [
    'well-organized',
    'good-variety',
    'family-friendly',
    'pet-friendly',
    'accessible',
    'clean-facilities',
    'good-signage',
    'ample-parking',
    'music-entertainment',
    'food-options',
    'covered-areas',
    'restrooms-available',
    'safe-environment',
    'easy-to-navigate',
    'crowded',
    'good-value',
  ];

  static const List<String> eventTags = [
    'special-event',
    'holiday-themed',
    'live-music',
    'food-trucks',
    'kids-activities',
    'cooking-demos',
    'workshops',
    'seasonal-products',
    'community-focused',
    'cultural-celebration',
  ];

  static const List<String> negativeTags = [
    'too-crowded',
    'poor-organization',
    'limited-selection',
    'overpriced',
    'unfriendly-staff',
    'hard-to-find',
    'no-parking',
    'cash-only',
    'long-wait-times',
  ];
}

/// Compact tag display for read-only views
class TagDisplay extends StatelessWidget {
  final List<String> tags;
  final Color? tagColor;
  final double fontSize;

  const TagDisplay({
    super.key,
    required this.tags,
    this.tagColor,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags.map((tag) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (tagColor ?? HiPopColors.shopperAccent).withOpacity( 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (tagColor ?? HiPopColors.shopperAccent).withOpacity( 0.3),
          ),
        ),
        child: Text(
          tag.replaceAll('-', ' '),
          style: TextStyle(
            fontSize: fontSize,
            color: tagColor ?? HiPopColors.shopperAccent,
            fontWeight: FontWeight.w500,
          ),
        ),
      )).toList(),
    );
  }
}