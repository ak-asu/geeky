import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/fsrs_scheduler.dart';
import '../../providers.dart';

class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({super.key, required this.results});

  final List<QuizResult> results;

  @override
  Widget build(BuildContext context) {
    final correct = results
        .where((r) => r.grade == FSRSGrade.good || r.grade == FSRSGrade.easy)
        .length;
    final hard = results.where((r) => r.grade == FSRSGrade.hard).length;
    final again = results.where((r) => r.grade == FSRSGrade.again).length;
    final total = results.length;
    final score = total > 0 ? (correct / total * 100).round() : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: ListView(
        padding: AppSpacing.paddingAll24,
        children: [
          // Score circle
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _scoreColor(score).withValues(alpha: 0.1),
                border: Border.all(color: _scoreColor(score), width: 3),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score%',
                      style: context.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _scoreColor(score),
                      ),
                    ),
                    Text(
                      'Score',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AppSpacing.gapV32,

          // Breakdown
          Text(
            'Breakdown',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.gapV12,
          _buildBreakdownRow(context, 'Easy', correct, AppColors.success),
          AppSpacing.gapV8,
          _buildBreakdownRow(context, 'Hard', hard, AppColors.warning),
          AppSpacing.gapV8,
          _buildBreakdownRow(context, 'Again', again, AppColors.error),
          AppSpacing.gapV32,

          // Actions
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
    BuildContext context,
    String label,
    int count,
    Color color,
  ) {
    final fraction = results.isNotEmpty ? count / results.length : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        AppSpacing.gapH12,
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        AppSpacing.gapH12,
        SizedBox(
          width: 24,
          child: Text(
            '$count',
            textAlign: TextAlign.end,
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }
}
