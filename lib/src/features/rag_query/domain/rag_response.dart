import 'package:freezed_annotation/freezed_annotation.dart';

part 'rag_response.freezed.dart';
part 'rag_response.g.dart';

@freezed
abstract class Citation with _$Citation {
  const factory Citation({
    required String shortId,
    required String title,
    String? snippet,
  }) = _Citation;

  factory Citation.fromJson(Map<String, dynamic> json) =>
      _$CitationFromJson(json);
}

@freezed
abstract class RagResponse with _$RagResponse {
  const factory RagResponse({
    required String answer,
    @Default([]) List<Citation> citations,
    @Default([]) List<String> followUpQuestions,
  }) = _RagResponse;

  factory RagResponse.fromJson(Map<String, dynamic> json) =>
      _$RagResponseFromJson(json);
}
