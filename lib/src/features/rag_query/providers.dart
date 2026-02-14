import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/database_provider.dart';
import 'data/rag_repository.dart';
import 'domain/chat_message.dart';
import 'domain/rag_response.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
RagRepository ragRepository(Ref ref) {
  return RagRepository(ref.read(appDatabaseProvider));
}

/// Manages the RAG chat session: message history and querying.
@Riverpod(keepAlive: true)
class RagChat extends _$RagChat {
  @override
  RagChatState build() => const RagChatState();

  Future<void> ask(String question) async {
    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      role: MessageRole.user,
      content: question,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      lastResponse: null,
    );

    try {
      final repo = ref.read(ragRepositoryProvider);
      final response = await repo.query(question);

      final assistantMsg = ChatMessage(
        id: const Uuid().v4(),
        role: MessageRole.assistant,
        content: response.answer,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isLoading: false,
        lastResponse: response,
      );
    } catch (e) {
      final errorMsg = ChatMessage(
        id: const Uuid().v4(),
        role: MessageRole.assistant,
        content: 'Something went wrong. Please try again.',
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isLoading: false,
      );
    }
  }

  void clearSession() {
    state = const RagChatState();
  }
}

/// Holds the full chat state: messages + loading + last response.
class RagChatState {
  const RagChatState({
    this.messages = const [],
    this.isLoading = false,
    this.lastResponse,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final RagResponse? lastResponse;

  RagChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    Object? lastResponse = _sentinel,
  }) {
    return RagChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      lastResponse: lastResponse == _sentinel
          ? this.lastResponse
          : lastResponse as RagResponse?,
    );
  }

  static const _sentinel = Object();
}
