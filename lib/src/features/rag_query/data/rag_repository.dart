import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../services/local/database.dart';
import '../../../services/local/daos/shorts_dao.dart';
import '../../shorts/data/short_dto.dart';
import '../domain/rag_response.dart';

/// RAG repository — delegates to backend RAG orchestrator when online,
/// falls back to local keyword matching when offline.
class RagRepository {
  RagRepository(this._db, this._api);

  final AppDatabase _db;
  final ApiService _api;

  ShortsDao get _shortsDao => _db.shortsDao;

  Future<RagResponse> query(String question) async {
    // Try backend RAG first
    try {
      final response = await _api.post(
        '${ApiConstants.rag}/query',
        {'query': question},
        (json) => RagResponse.fromJson(json as Map<String, dynamic>),
      );
      return response;
    } catch (_) {
      // Fallback to local keyword search (offline)
    }

    return _localQuery(question);
  }

  // --- Local fallback ---

  Future<RagResponse> _localQuery(String question) async {
    final rows = await _shortsDao.getAllShorts();
    final shorts = rows.map(ShortDto.fromRow).toList();

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

    final answerParts = <String>[
      'Based on your knowledge base, here\'s what I found:\n',
    ];

    final citations = <Citation>[];
    for (var i = 0; i < topResults.length; i++) {
      final r = topResults[i];
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
