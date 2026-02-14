import '../../../services/local/database.dart';
import '../../../services/local/daos/shorts_dao.dart';
import '../../shorts/data/short_dto.dart';
import '../domain/rag_response.dart';

/// Mock RAG repository — simulates RAG answers by searching shorts locally
/// and composing a mock answer with citations. Will be replaced by backend
/// POST /rag/query calls when live.
class RagRepository {
  RagRepository(this._db);

  final AppDatabase _db;

  ShortsDao get _shortsDao => _db.shortsDao;

  Future<RagResponse> query(String question) async {
    final rows = await _shortsDao.getAllShorts();
    final shorts = rows.map(ShortDto.fromRow).toList();

    // Simple keyword matching to find relevant shorts
    final lowerQ = question.toLowerCase();
    final words = lowerQ
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toList();

    final scored =
        <({String id, String title, String content, double score})>[];
    for (final short in shorts) {
      double score = 0;
      final searchText =
          '${short.title} ${short.summary} ${short.topics.join(' ')}'
              .toLowerCase();

      for (final word in words) {
        if (searchText.contains(word)) score += 1.0;
        if (short.title.toLowerCase().contains(word)) score += 2.0;
      }

      if (score > 0) {
        scored.add((
          id: short.id,
          title: short.title,
          content: short.content,
          score: score,
        ));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final topResults = scored.take(3).toList();

    if (topResults.isEmpty) {
      return const RagResponse(
        answer:
            'I couldn\'t find relevant information in your knowledge base for this question. '
            'Try adding more notes on this topic, or rephrase your query.',
        citations: [],
        followUpQuestions: [
          'What topics are covered in my knowledge base?',
          'How do I add new notes?',
        ],
      );
    }

    // Compose a mock answer referencing the found shorts
    final answerParts = <String>[
      'Based on your knowledge base, here\'s what I found:\n',
    ];

    final citations = <Citation>[];
    for (var i = 0; i < topResults.length; i++) {
      final r = topResults[i];
      // Extract first 2 sentences as snippet
      final sentences = r.content
          .replaceAll(RegExp(r'[#*_`]'), '')
          .split(RegExp(r'[.!?]\s'))
          .where((s) => s.trim().isNotEmpty)
          .take(2)
          .join('. ');
      final snippet = sentences.length > 200
          ? '${sentences.substring(0, 200)}...'
          : '$sentences.';

      answerParts.add('**${r.title}**: $snippet [${i + 1}]\n');

      citations.add(Citation(shortId: r.id, title: r.title, snippet: snippet));
    }

    // Generate follow-up questions based on topics of found shorts
    final allTopics = <String>{};
    for (final r in topResults) {
      final short = shorts.firstWhere((s) => s.id == r.id);
      allTopics.addAll(short.topics);
    }

    final followUps = allTopics.take(3).map((t) {
      return 'Tell me more about $t';
    }).toList();

    if (followUps.isEmpty) {
      followUps.add('Can you explain this in simpler terms?');
    }

    return RagResponse(
      answer: answerParts.join('\n'),
      citations: citations,
      followUpQuestions: followUps,
    );
  }
}
