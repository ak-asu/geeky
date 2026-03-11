class NoteCreationResponse {
  const NoteCreationResponse({required this.noteId, this.processingTaskId});

  factory NoteCreationResponse.fromJson(Map<String, dynamic> json) {
    return NoteCreationResponse(
      noteId: json['id'] as String,
      processingTaskId: json['processingTaskId'] as String?,
    );
  }

  final String noteId;
  final String? processingTaskId;
}
