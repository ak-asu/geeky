import '../../../services/local/database.dart';
import '../../../services/local/daos/quiz_dao.dart';
import '../../../services/local/daos/shorts_dao.dart';
import '../domain/quiz_card_entity.dart';
import '../domain/question_entity.dart';
import '../../shorts/domain/short_entity.dart';
import '../../shorts/data/short_dto.dart';
import 'quiz_card_dto.dart';
import 'fsrs_scheduler.dart';

class QuizRepository {
  QuizRepository(this._db);

  final AppDatabase _db;

  QuizDao get _quizDao => _db.quizDao;
  ShortsDao get _shortsDao => _db.shortsDao;

  // --- Quiz Cards (FSRS state) ---

  Future<List<QuizCardEntity>> getAllCards() async {
    final rows = await _quizDao.getAllCards();
    return rows.map(QuizCardDto.fromRow).toList();
  }

  Future<List<QuizCardEntity>> getDueCards() async {
    final rows = await _quizDao.getDueCards();
    return rows.map(QuizCardDto.fromRow).toList();
  }

  Future<QuizCardEntity?> getCardForArticle(String articleId) async {
    final row = await _quizDao.getCardForArticle(articleId);
    return row != null ? QuizCardDto.fromRow(row) : null;
  }

  Future<void> saveCard(QuizCardEntity card) async {
    await _quizDao.upsertCard(QuizCardDto.toCompanion(card));
  }

  /// Apply a grade to a card using simplified FSRS scheduling.
  Future<QuizCardEntity> gradeCard(QuizCardEntity card, FSRSGrade grade) async {
    final updated = FSRSScheduler.schedule(card, grade);
    await saveCard(updated);
    return updated;
  }

  // --- Generate questions from shorts ---

  /// Generates mock questions from a short for the quiz.
  Future<List<QuestionEntity>> generateQuestionsForShort(String shortId) async {
    final row = await _shortsDao.getShortById(shortId);
    if (row == null) return [];

    final short = ShortDto.fromRow(row);
    return _mockQuestionsFromShort(short);
  }

  List<QuestionEntity> _mockQuestionsFromShort(ShortEntity short) {
    final now = DateTime.now();
    return [
      QuestionEntity(
        id: '${short.id}-q1',
        articleId: short.id,
        questionText: 'What is the main concept discussed in "${short.title}"?',
        type: QuestionType.freeResponse,
        correctAnswer: short.summary.isNotEmpty ? short.summary : short.title,
        explanation: short.summary,
        topic: short.topics.isNotEmpty ? short.topics.first : null,
        difficulty: short.difficulty,
        createdAt: now,
      ),
      if (short.prompts.isNotEmpty)
        QuestionEntity(
          id: '${short.id}-q2',
          articleId: short.id,
          questionText: short.prompts.first,
          type: QuestionType.freeResponse,
          correctAnswer: 'See the article "${short.title}" for details.',
          explanation: short.summary,
          topic: short.topics.isNotEmpty ? short.topics.first : null,
          difficulty: short.difficulty,
          createdAt: now,
        ),
    ];
  }
}
