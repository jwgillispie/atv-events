import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

/// Option for time duration selection
class TimeDurationOption {
  final String label;
  final Duration duration;

  const TimeDurationOption(this.label, this.duration);
}

/// Reusable time duration selector widget
class TimeDurationSelector extends StatelessWidget {
  final Duration? selectedDuration;
  final ValueChanged<Duration> onDurationSelected;
  final List<TimeDurationOption> options;
  final String title;
  final String? subtitle;
  final bool isOptional;

  const TimeDurationSelector({
    super.key,
    required this.selectedDuration,
    required this.onDurationSelected,
    required this.options,
    required this.title,
    this.subtitle,
    this.isOptional = true,
  });

  /// Factory constructor for vendor visit durations
  factory TimeDurationSelector.vendor({
    Duration? selectedDuration,
    required ValueChanged<Duration> onDurationSelected,
  }) {
    return TimeDurationSelector(
      selectedDuration: selectedDuration,
      onDurationSelected: onDurationSelected,
      title: 'Time at Vendor',
      subtitle: 'Approximately how long did you spend at this vendor?',
      options: const [
        TimeDurationOption('< 2 min', Duration(minutes: 2)),
        TimeDurationOption('5 min', Duration(minutes: 5)),
        TimeDurationOption('10 min', Duration(minutes: 10)),
        TimeDurationOption('15 min', Duration(minutes: 15)),
        TimeDurationOption('20+ min', Duration(minutes: 20)),
      ],
    );
  }

  /// Factory constructor for market visit durations
  factory TimeDurationSelector.market({
    Duration? selectedDuration,
    required ValueChanged<Duration> onDurationSelected,
  }) {
    return TimeDurationSelector(
      selectedDuration: selectedDuration,
      onDurationSelected: onDurationSelected,
      title: 'Time at Market',
      subtitle: 'How long did you spend at the market?',
      options: const [
        TimeDurationOption('15 min', Duration(minutes: 15)),
        TimeDurationOption('30 min', Duration(minutes: 30)),
        TimeDurationOption('1 hour', Duration(hours: 1)),
        TimeDurationOption('1.5 hours', Duration(minutes: 90)),
        TimeDurationOption('2+ hours', Duration(hours: 2)),
      ],
    );
  }

  /// Factory constructor for event durations
  factory TimeDurationSelector.event({
    Duration? selectedDuration,
    required ValueChanged<Duration> onDurationSelected,
  }) {
    return TimeDurationSelector(
      selectedDuration: selectedDuration,
      onDurationSelected: onDurationSelected,
      title: 'Event Duration',
      subtitle: 'How long did you attend the event?',
      options: const [
        TimeDurationOption('30 min', Duration(minutes: 30)),
        TimeDurationOption('1 hour', Duration(hours: 1)),
        TimeDurationOption('2 hours', Duration(hours: 2)),
        TimeDurationOption('3 hours', Duration(hours: 3)),
        TimeDurationOption('4+ hours', Duration(hours: 4)),
      ],
    );
  }

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
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: options.map((option) => _buildTimeOption(option)).toList(),
        ),
      ],
    );
  }

  Widget _buildTimeOption(TimeDurationOption option) {
    final isSelected = selectedDuration == option.duration;
    
    return GestureDetector(
      onTap: () {
        onDurationSelected(option.duration);
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? HiPopColors.shopperAccent 
              : HiPopColors.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? HiPopColors.shopperAccent 
                : HiPopColors.darkBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time,
              size: 14,
              color: isSelected ? Colors.white : HiPopColors.darkTextPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              option.label,
              style: TextStyle(
                color: isSelected ? Colors.white : HiPopColors.darkTextPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Display widget for showing selected duration
class DurationDisplay extends StatelessWidget {
  final Duration duration;
  final String label;

  const DurationDisplay({
    super.key,
    required this.duration,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.access_time,
          size: 16,
          color: HiPopColors.darkTextSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ${_formatDuration(duration)}',
          style: TextStyle(
            fontSize: 12,
            color: HiPopColors.darkTextSecondary,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} minutes';
    } else if (duration.inHours == 1) {
      return '1 hour';
    } else if (duration.inMinutes % 60 == 0) {
      return '${duration.inHours} hours';
    } else {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '$hours hr $minutes min';
    }
  }
}