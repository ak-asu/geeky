import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/learning_streak.dart';

class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.streak});

  final LearningStreak streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingAll16,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Streak fire icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Center(
                  child: Text('🔥', style: TextStyle(fontSize: 28)),
                ),
              ),
              AppSpacing.gapH16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${streak.currentStreak} day streak',
                      style: context.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AppSpacing.gapV4,
                    Text(
                      'Best: ${streak.longestStreak} days',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.gapV16,
          // Weekly activity mini-bar chart
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: streak.weeklyActivity.entries.map((entry) {
              final maxVal = streak.weeklyActivity.values.fold<int>(
                1,
                (a, b) => a > b ? a : b,
              );
              final ratio = entry.value / maxVal;
              return _DayBar(
                label: entry.key,
                ratio: ratio,
                value: entry.value,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.label,
    required this.ratio,
    required this.value,
  });

  final String label;
  final double ratio;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 24,
              height: 8 + (32 * ratio),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: ratio > 0 ? 0.6 : 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.s4),
              ),
            ),
          ),
        ),
        AppSpacing.gapV4,
        Text(
          label.substring(0, 1),
          style: context.textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
