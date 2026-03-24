import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/geeky_error_widget.dart';
import '../../../../core/widgets/geeky_shimmer.dart';
import '../../../../routing/route_names.dart';
import '../../../analytics/data/analytics_repository.dart';
import '../../../analytics/providers.dart';
import '../../../auth/providers.dart';
import '../../../subscription/providers.dart';
import '../../providers.dart';
import '../widgets/expertise_radar_chart.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);
    final expertiseAsync = ref.watch(profileExpertiseProvider);
    final statsAsync = ref.watch(profileStatsProvider);
    final streakAsync = ref.watch(learningStreakProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 22),
            onPressed: () => context.pushNamed(RouteNames.editProfile),
          ),
          const SizedBox(width: AppSpacing.s4),
        ],
      ),
      body: ListView(
        padding: AppSpacing.paddingAll16,
        children: [
          // ── Avatar + name + email + plan badge ────────────────────────
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: user?.avatarUrl != null
                      ? ClipOval(
                          child: Image.network(
                            user!.avatarUrl!,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _AvatarFallback(name: user.name),
                          ),
                        )
                      : _AvatarFallback(name: user?.name ?? '?'),
                ),
                AppSpacing.gapV12,
                Text(
                  user?.name ?? 'Guest',
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AppSpacing.gapV4,
                Text(
                  user?.email ?? '',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.gapV12,
                // Subscription plan badge — tappable shortcut to subscription screen
                GestureDetector(
                  onTap: () => context.pushNamed(RouteNames.subscription),
                  child: Chip(
                    avatar: Icon(
                      isPremium
                          ? Icons.workspace_premium_rounded
                          : Icons.lock_open_rounded,
                      size: 14,
                      color: isPremium
                          ? AppColors.primary
                          : context.colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      isPremium ? 'Premium' : 'Free Plan',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: isPremium
                            ? AppColors.primary
                            : context.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: isPremium
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : context.colorScheme.surfaceContainerHighest,
                    side: BorderSide(
                      color: isPremium
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : context.colorScheme.outlineVariant,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          AppSpacing.gapV24,

          // ── Quick stats row ───────────────────────────────────────────
          streakAsync.when(
            data: (streak) => _QuickStatsRow(
              streakDays: streak.currentStreak,
              statsAsync: statsAsync,
            ),
            loading: () => GeekyShimmer(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
              ),
            ),
            error: (e, _) =>
                GeekyErrorWidget(message: e.toString(), compact: true),
          ),

          AppSpacing.gapV24,

          // ── Interests ─────────────────────────────────────────────────
          if (user != null) ...[
            Row(
              children: [
                Text(
                  'Interests',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.push(
                    '/${RouteNames.interestSelection}',
                    extra: true,
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: context.textTheme.labelMedium,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            AppSpacing.gapV8,
            if (user.interests.isEmpty)
              Text(
                'No interests added yet. Tap Edit to personalise your feed.',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: user.interests.map((interest) {
                  return Chip(
                    label: Text(
                      interest,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s4,
                    ),
                  );
                }).toList(),
              ),
            AppSpacing.gapV24,
          ],

          // ── Learning Goals ────────────────────────────────────────────
          if (user != null && user.goals.isNotEmpty) ...[
            Text(
              'Learning Goals',
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.gapV8,
            ...user.goals.map(
              (goal) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      size: 18,
                      color: AppColors.primary.withValues(alpha: 0.6),
                    ),
                    AppSpacing.gapH8,
                    Expanded(
                      child: Text(goal, style: context.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
            AppSpacing.gapV24,
          ],

          // ── Expertise radar chart ─────────────────────────────────────
          expertiseAsync.when(
            data: (topics) => ExpertiseRadarChart(topics: topics),
            loading: () => GeekyShimmer(
              child: Container(
                height: 240,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
              ),
            ),
            error: (e, _) =>
                GeekyErrorWidget(message: e.toString(), compact: true),
          ),

          AppSpacing.gapV32,

          // ── Sign Out ──────────────────────────────────────────────────
          // Placed at the bottom following the Apple ID / account page pattern.
          const Divider(),
          AppSpacing.gapV8,
          _SignOutTile(onTap: () => _showSignOutDialog(context, ref)),
          AppSpacing.gapV16,
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will be returned to the login screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
              // RouterNotifier detects the auth state change and redirects
              // to /login automatically — no manual navigation needed.
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Text(
      name.initials,
      style: context.textTheme.headlineMedium?.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SignOutTile extends StatelessWidget {
  const _SignOutTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
        child: Row(
          children: [
            Icon(
              Icons.logout_rounded,
              size: 22,
              color: context.colorScheme.onSurfaceVariant,
            ),
            AppSpacing.gapH12,
            Text(
              'Sign Out',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.streakDays, required this.statsAsync});

  final int streakDays;
  final AsyncValue<AnalyticsStats> statsAsync;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            icon: Icons.local_fire_department_rounded,
            value: '$streakDays',
            label: 'Streak',
            color: AppColors.warning,
          ),
        ),
        AppSpacing.gapH12,
        Expanded(
          child: statsAsync.when(
            data: (stats) => _MiniStat(
              icon: Icons.auto_stories_rounded,
              value: '${stats.totalShortsCompleted}',
              label: 'Read',
              color: AppColors.primary,
            ),
            loading: () => const _MiniStat(
              icon: Icons.auto_stories_rounded,
              value: '—',
              label: 'Read',
              color: AppColors.primary,
            ),
            error: (_, _) => const _MiniStat(
              icon: Icons.auto_stories_rounded,
              value: '—',
              label: 'Read',
              color: AppColors.primary,
            ),
          ),
        ),
        AppSpacing.gapH12,
        Expanded(
          child: statsAsync.when(
            data: (stats) => _MiniStat(
              icon: Icons.timer_rounded,
              value: '${stats.totalTimeMinutes}m',
              label: 'Time',
              color: AppColors.secondary,
            ),
            loading: () => const _MiniStat(
              icon: Icons.timer_rounded,
              value: '—',
              label: 'Time',
              color: AppColors.secondary,
            ),
            error: (_, _) => const _MiniStat(
              icon: Icons.timer_rounded,
              value: '—',
              label: 'Time',
              color: AppColors.secondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.s12,
        horizontal: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          AppSpacing.gapV4,
          Text(
            value,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
