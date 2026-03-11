import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/geeky_empty_state.dart';
import '../../../../core/widgets/geeky_shimmer.dart';
import '../../../shorts/domain/short_entity.dart';
import '../../../shorts/providers.dart';
import '../../data/fsrs_scheduler.dart';
import '../../domain/quiz_card_entity.dart';
import '../../providers.dart';
import '../widgets/flashcard_widget.dart';
import '../widgets/self_grade_buttons.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final dueCardsAsync = ref.watch(dueQuizCardsProvider);
    // Build a lookup map from short ID → ShortEntity for displaying real content.
    final shortsMap = <String, ShortEntity>{
      for (final s in ref.watch(allShortsProvider).value ?? <ShortEntity>[])
        s.id: s,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: dueCardsAsync.when(
        loading: () => GeekyShimmer.feedCard(context),
        error: (error, _) => GeekyEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load quiz',
          subtitle: error.toString(),
        ),
        data: (dueCards) {
          if (dueCards.isEmpty) {
            return const GeekyEmptyState(
              icon: Icons.school_rounded,
              title: 'All caught up!',
              subtitle:
                  'No cards are due for review right now. Check back later.',
            );
          }

          // Start session if not started
          final session = ref.watch(quizSessionProvider);
          if (session.cards.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(quizSessionProvider.notifier).startSession(dueCards);
            });
            return GeekyShimmer.feedCard(context);
          }

          if (session.isComplete) {
            return _buildComplete(context, session);
          }

          final currentCard = session.currentCard!;
          return _buildQuizBody(context, currentCard, session, shortsMap);
        },
      ),
    );
  }

  Widget _buildQuizBody(
    BuildContext context,
    QuizCardEntity card,
    QuizSessionState session,
    Map<String, ShortEntity> shortsMap,
  ) {
    final short = shortsMap[card.articleId];
    return Padding(
      padding: AppSpacing.paddingAll16,
      child: Column(
        children: [
          // Progress indicator
          _buildProgress(context, session),
          AppSpacing.gapV24,

          // Flashcard
          Expanded(
            child: FlashcardWidget(
              key: ValueKey(card.articleId),
              question: 'What do you remember about this topic?',
              topic: short?.title ?? 'Review',
              answer: short?.content ?? 'Open the short to review the content.',
              onFlipped: () {
                setState(() => _revealed = true);
              },
            ),
          ),
          AppSpacing.gapV16,

          // Grade buttons (only after reveal)
          SelfGradeButtons(
            enabled: _revealed,
            onGrade: (grade) {
              ref.read(quizSessionProvider.notifier).recordGrade(grade);
              setState(() => _revealed = false);
            },
          ),
          AppSpacing.gapV16,
        ],
      ),
    );
  }

  Widget _buildProgress(BuildContext context, QuizSessionState session) {
    final progress = session.totalCards > 0
        ? session.answeredCards / session.totalCards
        : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${session.answeredCards} / ${session.totalCards}',
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        AppSpacing.gapV8,
        Semantics(
          label: 'Quiz progress',
          value:
              '${session.answeredCards} of ${session.totalCards} cards, '
              '${(progress * 100).round()} percent complete',
          excludeSemantics: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComplete(BuildContext context, QuizSessionState session) {
    final correct = session.results
        .where((r) => r.grade == FSRSGrade.good || r.grade == FSRSGrade.easy)
        .length;
    final total = session.results.length;

    return Center(
      child: Padding(
        padding: AppSpacing.paddingAll24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              excludeSemantics: true,
              child: Icon(
                Icons.celebration_rounded,
                size: 64,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
            ),
            AppSpacing.gapV16,
            Text(
              'Session Complete!',
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            AppSpacing.gapV8,
            Text(
              '$correct / $total cards rated Good or Easy',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            AppSpacing.gapV32,
            FilledButton(
              onPressed: () {
                ref.invalidate(dueQuizCardsProvider);
                ref.invalidate(quizSessionProvider);
              },
              child: const Text('Start New Session'),
            ),
            AppSpacing.gapV12,
            OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
