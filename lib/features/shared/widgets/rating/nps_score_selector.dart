import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

/// Reusable Net Promoter Score selector widget
class NPSScoreSelector extends StatelessWidget {
  final int? selectedScore;
  final ValueChanged<int> onScoreSelected;
  final String title;
  final String subtitle;

  const NPSScoreSelector({
    super.key,
    required this.selectedScore,
    required this.onScoreSelected,
    this.title = 'Likelihood to Recommend (0-10)',
    this.subtitle = 'How likely are you to recommend to friends?',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: HiPopColors.darkTextSecondary),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(11, (index) {
            return GestureDetector(
              onTap: () {
                onScoreSelected(index);
                HapticFeedback.lightImpact();
              },
              child: _buildScoreButton(index),
            );
          }),
        ),
        const SizedBox(height: 8),
        _buildScoreLabel(),
      ],
    );
  }

  Widget _buildScoreButton(int score) {
    final isSelected = selectedScore == score;
    final color = _getScoreColor(score);
    
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isSelected ? color : HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? color : HiPopColors.darkBorder,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Center(
        child: Text(
          '$score',
          style: TextStyle(
            color: isSelected ? Colors.white : HiPopColors.darkTextPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score <= 6) {
      return Colors.red.shade600; // Detractors
    } else if (score <= 8) {
      return Colors.orange.shade600; // Passives
    } else {
      return Colors.green.shade600; // Promoters
    }
  }

  Widget _buildScoreLabel() {
    if (selectedScore == null) return const SizedBox.shrink();
    
    String label;
    Color color;
    IconData icon;
    
    if (selectedScore! <= 6) {
      label = 'Detractor';
      color = Colors.red.shade600;
      icon = Icons.sentiment_dissatisfied;
    } else if (selectedScore! <= 8) {
      label = 'Passive';
      color = Colors.orange.shade600;
      icon = Icons.sentiment_neutral;
    } else {
      label = 'Promoter';
      color = Colors.green.shade600;
      icon = Icons.sentiment_very_satisfied;
    }
    
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simplified NPS display for read-only views
class NPSDisplay extends StatelessWidget {
  final double score;
  final int totalResponses;
  final bool showBreakdown;

  const NPSDisplay({
    super.key,
    required this.score,
    required this.totalResponses,
    this.showBreakdown = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getNPSColor(score);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getNPSIcon(score),
                color: color,
                size: 32,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NPS Score',
                    style: TextStyle(
                      fontSize: 12,
                      color: HiPopColors.darkTextSecondary,
                    ),
                  ),
                  Text(
                    score.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Based on $totalResponses responses',
            style: TextStyle(
              fontSize: 12,
              color: HiPopColors.darkTextSecondary,
            ),
          ),
          if (showBreakdown) ...[
            const SizedBox(height: 12),
            _buildBreakdown(),
          ],
        ],
      ),
    );
  }

  Color _getNPSColor(double score) {
    if (score < 0) return Colors.red.shade600;
    if (score < 30) return Colors.orange.shade600;
    if (score < 70) return Colors.blue.shade600;
    return Colors.green.shade600;
  }

  IconData _getNPSIcon(double score) {
    if (score < 0) return Icons.sentiment_very_dissatisfied;
    if (score < 30) return Icons.sentiment_dissatisfied;
    if (score < 70) return Icons.sentiment_satisfied;
    return Icons.sentiment_very_satisfied;
  }

  Widget _buildBreakdown() {
    // This would typically calculate from actual data
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildMetric('Promoters', '45%', Colors.green.shade600),
        _buildMetric('Passives', '35%', Colors.orange.shade600),
        _buildMetric('Detractors', '20%', Colors.red.shade600),
      ],
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: HiPopColors.darkTextSecondary,
          ),
        ),
      ],
    );
  }
}