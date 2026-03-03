import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/database_provider.dart';
import '../../../features/auth/providers.dart';
import '../../../services/local/database.dart';
import '../domain/interaction_enums.dart';

part 'interaction_notifier.g.dart';

/// Writes interaction events to the PendingInteractions table for later sync.
@riverpod
class InteractionNotifier extends _$InteractionNotifier {
  @override
  void build() {
    // No state — this is a side-effect-only notifier.
  }

  /// Record that the user viewed an article/note with engagement metrics.
  Future<void> recordView({
    required String articleId,
    required double timeSpent,
    required double scrollDepth,
  }) async {
    await _insert(
      articleId: articleId,
      type: InteractionType.view,
      timeSpent: timeSpent,
      scrollDepth: scrollDepth,
    );
  }

  /// Record a "done" / mark-as-read interaction.
  Future<void> recordDone({required String articleId}) async {
    await _insert(articleId: articleId, type: InteractionType.done);
  }

  /// Record a skip (swipe past without reading).
  Future<void> recordSkip({
    required String articleId,
    String? navigationDirection,
    String? fromArticleId,
  }) async {
    await _insert(
      articleId: articleId,
      type: InteractionType.skip,
      navigationDirection: navigationDirection,
      fromArticleId: fromArticleId,
    );
  }

  /// Record a bookmark toggle.
  Future<void> recordBookmark({required String articleId}) async {
    await _insert(articleId: articleId, type: InteractionType.bookmark);
  }

  /// Record explicit feedback.
  /// [feedbackType] is optional — omit for a generic tap signal.
  /// Use [FeedbackType.too_easy], [FeedbackType.too_hard], or
  /// [FeedbackType.not_relevant] for specific feedback.
  Future<void> recordFeedback({
    required String articleId,
    FeedbackType? feedbackType,
  }) async {
    await _insert(
      articleId: articleId,
      type: InteractionType.feedback,
      feedbackType: feedbackType,
    );
  }

  Future<void> _insert({
    required String articleId,
    required InteractionType type,
    double timeSpent = 0,
    double scrollDepth = 0,
    FeedbackType? feedbackType,
    String? navigationDirection,
    String? fromArticleId,
  }) async {
    final db = ref.read(appDatabaseProvider);
    await db.syncDao.insertInteraction(
      PendingInteractionsCompanion.insert(
        userId: Value(ref.read(currentUserProvider)?.id ?? ''),
        articleId: articleId,
        type: type.name,
        timestamp: DateTime.now(),
        timeSpent: Value(timeSpent),
        scrollDepth: Value(scrollDepth),
        feedbackType: Value(feedbackType?.name),
        navigationDirection: Value(navigationDirection),
        fromArticleId: Value(fromArticleId),
      ),
    );
  }
}
