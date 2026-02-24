import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/database_provider.dart';
import '../../../features/auth/providers.dart';
import '../../../services/local/database.dart';

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
      type: 'view',
      timeSpent: timeSpent,
      scrollDepth: scrollDepth,
    );
  }

  /// Record a "done" / mark-as-read interaction.
  Future<void> recordDone({required String articleId}) async {
    await _insert(articleId: articleId, type: 'done');
  }

  /// Record a skip (swipe past without reading).
  Future<void> recordSkip({
    required String articleId,
    String? navigationDirection,
    String? fromArticleId,
  }) async {
    await _insert(
      articleId: articleId,
      type: 'skip',
      navigationDirection: navigationDirection,
      fromArticleId: fromArticleId,
    );
  }

  /// Record a bookmark toggle.
  Future<void> recordBookmark({required String articleId}) async {
    await _insert(articleId: articleId, type: 'bookmark');
  }

  /// Record explicit feedback (e.g. "too easy", "not relevant").
  Future<void> recordFeedback({
    required String articleId,
    required String feedbackType,
  }) async {
    await _insert(
      articleId: articleId,
      type: 'feedback',
      feedbackType: feedbackType,
    );
  }

  Future<void> _insert({
    required String articleId,
    required String type,
    double timeSpent = 0,
    double scrollDepth = 0,
    String? feedbackType,
    String? navigationDirection,
    String? fromArticleId,
  }) async {
    final db = ref.read(appDatabaseProvider);
    await db.syncDao.insertInteraction(
      PendingInteractionsCompanion.insert(
        userId: Value(ref.read(currentUserProvider)?.id ?? ''),
        articleId: articleId,
        type: type,
        timestamp: DateTime.now(),
        timeSpent: Value(timeSpent),
        scrollDepth: Value(scrollDepth),
        feedbackType: Value(feedbackType),
        navigationDirection: Value(navigationDirection),
        fromArticleId: Value(fromArticleId),
      ),
    );
  }
}
