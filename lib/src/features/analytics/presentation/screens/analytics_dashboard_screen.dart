import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/geeky_error_widget.dart';
import '../../../../core/widgets/geeky_shimmer.dart';
import '../../providers.dart';
import '../widgets/streak_card.dart';
import '../widgets/stats_row.dart';
import '../widgets/engagement_chart.dart';
import '../widgets/topic_progress_list.dart';
import '../widgets/achievement_grid.dart';

class AnalyticsDashboardScreen extends ConsumerWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(learningStreakProvider);
          ref.invalidate(analyticsStatsProvider);
          ref.invalidate(topicProgressProvider);
          ref.invalidate(achievementsProvider);
          ref.invalidate(weeklyEngagementProvider);
        },
        child: ListView(
          padding: AppSpacing.paddingAll16,
          children: const [
            // Streak card
            _StreakSection(),
            AppSpacing.gapV16,

            // Stats row
            _StatsSection(),
            AppSpacing.gapV24,

            // Weekly engagement chart
            _EngagementSection(),
            AppSpacing.gapV24,

            // Topic progress
            _TopicProgressSection(),
            AppSpacing.gapV24,

            // Achievements
            _AchievementsSection(),
            AppSpacing.gapV32,
          ],
        ),
      ),
    );
  }
}

class _StreakSection extends ConsumerWidget {
  const _StreakSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(learningStreakProvider);

    return streakAsync.when(
      loading: () => GeekyShimmer(
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
        ),
      ),
      error: (e, _) => GeekyErrorWidget(message: e.toString(), compact: true),
      data: (streak) => StreakCard(streak: streak),
    );
  }
}

class _StatsSection extends ConsumerWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(analyticsStatsProvider);

    return statsAsync.when(
      loading: () => GeekyShimmer(
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
        ),
      ),
      error: (e, _) => GeekyErrorWidget(message: e.toString(), compact: true),
      data: (stats) => StatsRow(stats: stats),
    );
  }
}

class _EngagementSection extends ConsumerWidget {
  const _EngagementSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engagementAsync = ref.watch(weeklyEngagementProvider);

    return engagementAsync.when(
      loading: () => GeekyShimmer(
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
        ),
      ),
      error: (e, _) => GeekyErrorWidget(message: e.toString(), compact: true),
      data: (data) => EngagementChart(data: data),
    );
  }
}

class _TopicProgressSection extends ConsumerWidget {
  const _TopicProgressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(topicProgressProvider);

    return progressAsync.when(
      loading: () =>
          Column(children: List.generate(3, (_) => GeekyShimmer.listItem())),
      error: (e, _) => GeekyErrorWidget(message: e.toString(), compact: true),
      data: (topics) => TopicProgressList(topics: topics),
    );
  }
}

class _AchievementsSection extends ConsumerWidget {
  const _AchievementsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsAsync = ref.watch(achievementsProvider);

    return achievementsAsync.when(
      loading: () => GeekyShimmer(
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
        ),
      ),
      error: (e, _) => GeekyErrorWidget(message: e.toString(), compact: true),
      data: (achievements) => AchievementGrid(achievements: achievements),
    );
  }
}
