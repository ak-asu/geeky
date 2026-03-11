import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../services/local/database.dart';
import '../../../services/local/daos/quiz_dao.dart';
import '../domain/quiz_card_entity.dart';
import '../domain/question_entity.dart';
import 'quiz_card_dto.dart';
import 'fsrs_scheduler.dart';

class QuizRepository {
  QuizRepository(this._db, this._api);

  final AppDatabase _db;
  final ApiService _api;

  QuizDao get _quizDao => _db.quizDao;

  // --- Quiz Cards (FSRS state) ---

  Future<List<QuizCardEntity>> getAllCards(String userId) async {
    final rows = await _quizDao.getAllCards(userId);
    return rows.map(QuizCardDto.fromRow).toList();
  }

  Future<List<QuizCardEntity>> getDueCards(String userId) async {
    try {
      // Try backend FSRS-scheduled due cards
      final result = await _api.get(
        '${ApiConstants.quiz}/review/due',
        (json) => json,
      );
      // Backend returns { cards, totalDue, ... } — extract cards
      if (result is Map<String, dynamic> && result['cards'] is List) {
        final cards = (result['cards'] as List)
            .map((c) => QuizCardEntity.fromJson(c as Map<String, dynamic>))
            .toList();
        // Cache locally
        for (final card in cards) {
          await _quizDao.upsertCard(QuizCardDto.toCompanion(card, userId));
        }
        return cards;
      }
    } catch (_) {
      // Fallback to local FSRS
    }
    final rows = await _quizDao.getDueCards(userId);
    return rows.map(QuizCardDto.fromRow).toList();
  }

  Future<QuizCardEntity?> getCardForArticle(
    String userId,
    String articleId,
  ) async {
    final row = await _quizDao.getCardForArticle(userId, articleId);
    return row != null ? QuizCardDto.fromRow(row) : null;
  }

  Future<void> saveCard(String userId, QuizCardEntity card) async {
    await _quizDao.upsertCard(QuizCardDto.toCompanion(card, userId));
  }

  /// Apply a grade to a card using simplified FSRS scheduling.
  Future<QuizCardEntity> gradeCard(
    String userId,
    QuizCardEntity card,
    FSRSGrade grade,
  ) async {
    final updated = FSRSScheduler.schedule(card, grade);
    await saveCard(userId, updated);

    // Submit review to backend
    try {
      await _api.post('${ApiConstants.quiz}/review/${card.articleId}', {
        'rating': grade.index,
      }, (json) => json);
    } catch (_) {
      // Local grade applied; backend sync deferred
    }

    return updated;
  }

  // --- Generate questions from shorts ---

  /// Generates questions from a short via the backend AI pipeline.
  /// Returns an empty list if the backend is unavailable.
  Future<List<QuestionEntity>> generateQuestionsForShort(String shortId) async {
    try {
      final result = await _api.post('${ApiConstants.quiz}/generate', {
        'short_ids': [shortId],
        'count': 3,
      }, (json) => json);
      if (result is Map<String, dynamic> && result['questions'] is List) {
        return (result['questions'] as List)
            .map((q) => QuestionEntity.fromJson(q as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Backend unavailable — no questions generated offline
    }
    return [];
  }
}
