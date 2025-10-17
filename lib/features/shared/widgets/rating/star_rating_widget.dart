import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

/// Reusable star rating widget used across all rating screens
class StarRatingWidget extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final String title;
  final bool isRequired;
  final double starSize;
  final String? subtitle;
  final bool showDescription;

  const StarRatingWidget({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    required this.title,
    this.isRequired = false,
    this.starSize = 36,
    this.subtitle,
    this.showDescription = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title${isRequired ? ' *' : ''}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 12, color: HiPopColors.darkTextSecondary),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            final starValue = index + 1;
            return GestureDetector(
              onTap: () {
                onRatingChanged(starValue);
                HapticFeedback.lightImpact();
              },
              child: Container(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  starValue <= rating ? Icons.star : Icons.star_border,
                  color: starValue <= rating 
                      ? Colors.amber 
                      : HiPopColors.darkBorder,
                  size: starSize,
                ),
              ),
            );
          }),
        ),
        if (showDescription) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              _getRatingDescription(rating),
              style: TextStyle(
                fontSize: 14,
                color: rating > 0 
                    ? HiPopColors.shopperAccent 
                    : HiPopColors.darkTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _getRatingDescription(int rating) {
    switch (rating) {
      case 1:
        return 'Poor - Would not return';
      case 2:
        return 'Fair - Below expectations';
      case 3:
        return 'Good - Met expectations';
      case 4:
        return 'Very Good - Exceeded expectations';
      case 5:
        return 'Excellent - Outstanding experience';
      default:
        return 'Please select a rating';
    }
  }
}

/// Compact star rating widget for category ratings
class CompactStarRating extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final String label;
  final String? description;
  final double starSize;

  const CompactStarRating({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    required this.label,
    this.description,
    this.starSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: HiPopColors.darkBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          if (description != null) ...[
            Text(
              description!,
              style: TextStyle(fontSize: 12, color: HiPopColors.darkTextSecondary),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return GestureDetector(
                onTap: () {
                  onRatingChanged(starValue);
                  HapticFeedback.lightImpact();
                },
                child: Icon(
                  starValue <= rating ? Icons.star : Icons.star_border,
                  color: starValue <= rating 
                      ? Colors.amber 
                      : HiPopColors.darkBorder,
                  size: starSize,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Read-only star display widget
class StarDisplay extends StatelessWidget {
  final double rating;
  final double size;
  final bool showNumber;

  const StarDisplay({
    super.key,
    required this.rating,
    this.size = 16,
    this.showNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          final starValue = index + 1;
          if (starValue <= rating.floor()) {
            return Icon(Icons.star, color: Colors.amber, size: size);
          } else if (starValue - 0.5 <= rating) {
            return Icon(Icons.star_half, color: Colors.amber, size: size);
          } else {
            return Icon(Icons.star_border, color: HiPopColors.darkBorder, size: size);
          }
        }),
        if (showNumber) ...[
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size * 0.875,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}