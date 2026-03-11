/// Mirrors the backend NoteType enum (backend/app/models/common.py).
///
/// Values are lowercase strings matching the backend wire format so that
/// [NoteType.name] can be used directly as the JSON value without a custom
/// serializer.
enum NoteType {
  text,
  image,
  audio,
  link,
  video,
  file;

  /// Parse from a wire-format string, defaulting to [NoteType.text].
  static NoteType fromString(String value) => NoteType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => NoteType.text,
  );
}
