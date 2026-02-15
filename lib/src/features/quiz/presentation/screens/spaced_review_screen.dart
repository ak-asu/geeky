import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/geeky_empty_state.dart';
import '../../../../core/widgets/geeky_shimmer.dart';
import '../../../../routing/route_names.dart';
import '../../domain/quiz_card_entity.dart';
import '../../providers.dart';

class SpacedReviewScreen extends ConsumerWidget {
  const SpacedReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allCardsAsync = ref.watch(allQuizCardsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Spaced Review')),
      body: allCardsAsync.when(
        loading: () => ListView.builder(
          itemCount: 5,
          itemBuilder: (_, _) => Padding(
            padding: AppSpacing.paddingV8H16,
            child: GeekyShimmer.listItem(),
          ),
        ),
        error: (error, _) => GeekyEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load cards',
          subtitle: error.toString(),
        ),
        data: (cards) {
          if (cards.isEmpty) {
            return const GeekyEmptyState(
              icon: Icons.school_rounded,
              title: 'No Review Cards',
              subtitle:
                  'Read some shorts first — quiz cards will be generated automatically.',
            );
          }

          // Sort: due first, then by due date
          final sorted = List<QuizCardEntity>.from(cards)
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

          final now = DateTime.now();
          final dueCards = sorted
              .where((c) => c.dueDate.isBefore(now))
              .toList();
          final upcomingCards = sorted
              .where((c) => !c.dueDate.isBefore(now))
              .toList();

          return ListView(
            padding: AppSpacing.paddingAll16,
            children: [
              // Due section
              if (dueCards.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  'Due Now',
                  '${dueCards.length} cards',
                  AppColors.primary,
                ),
                AppSpacing.gapV8,
                ...dueCards.map((card) => _CardTile(card: card, isDue: true)),
                AppSpacing.gapV16,
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => context.pushNamed(RouteNames.quiz),
                    child: Text('Review ${dueCards.length} cards'),
                  ),
                ),
                AppSpacing.gapV24,
              ],

              // Upcoming section
              if (upcomingCards.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  'Upcoming',
                  '${upcomingCards.length} cards',
                  context.colorScheme.onSurfaceVariant,
                ),
                AppSpacing.gapV8,
                ...upcomingCards.map(
                  (card) => _CardTile(card: card, isDue: false),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle,
    Color color,
  ) {
    return Row(
      children: [
        Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const Spacer(),
        Text(
          subtitle,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.isDue});

  final QuizCardEntity card;
  final bool isDue;

  @override
  Widget build(BuildContext context) {
    final stateLabel = switch (card.state) {
      CardState.newCard => 'New',
      CardState.learning => 'Learning',
      CardState.review => 'Review',
      CardState.relearning => 'Relearning',
    };

    final dueLabel = isDue
        ? 'Due now'
        : _formatDueIn(card.dueDate.difference(DateTime.now()));

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isDue
              ? AppColors.primary.withValues(alpha: 0.3)
              : context.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // State indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isDue ? AppColors.primary : AppColors.nodeUnread,
              shape: BoxShape.circle,
            ),
          ),
          AppSpacing.gapH12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.articleId,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                AppSpacing.gapV4,
                Row(
                  children: [
                    Text(
                      stateLabel,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s8,
                      ),
                      child: Text(
                        '\u00B7',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      'Reps: ${card.reps}',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            dueLabel,
            style: context.textTheme.labelSmall?.copyWith(
              color: isDue
                  ? AppColors.primary
                  : context.colorScheme.onSurfaceVariant,
              fontWeight: isDue ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDueIn(Duration duration) {
    if (duration.inMinutes < 60) return 'in ${duration.inMinutes}m';
    if (duration.inHours < 24) return 'in ${duration.inHours}h';
    return 'in ${duration.inDays}d';
  }
}
