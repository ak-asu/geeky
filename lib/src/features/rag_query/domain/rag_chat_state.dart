import 'package:freezed_annotation/freezed_annotation.dart';

import 'chat_message.dart';
import 'rag_response.dart';

part 'rag_chat_state.freezed.dart';

@freezed
abstract class RagChatState with _$RagChatState {
  const factory RagChatState({
    @Default([]) List<ChatMessage> messages,
    @Default(false) bool isLoading,
    RagResponse? lastResponse,
  }) = _RagChatState;
}
