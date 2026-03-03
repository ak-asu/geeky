/// Mirrors backend InteractionType enum (backend/app/models/common.py).
///
/// Values are lowercase strings matching the backend wire format so that
/// [InteractionType.name] can be used directly as the JSON value.
enum InteractionType {
  view,
  done,
  skip,
  bookmark,
  feedback;

  static InteractionType fromString(String value) => InteractionType.values
      .firstWhere((e) => e.name == value, orElse: () => InteractionType.view);
}

/// Mirrors backend FeedbackType enum (backend/app/models/common.py).
///
/// Values are snake_case strings matching the backend wire format so that
/// [FeedbackType.name] can be used directly as the JSON value.
enum FeedbackType {
  // ignore: constant_identifier_names
  too_easy,
  // ignore: constant_identifier_names
  too_hard,
  // ignore: constant_identifier_names
  not_relevant;

  static FeedbackType? fromString(String? value) {
    if (value == null) return null;
    return FeedbackType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FeedbackType.not_relevant,
    );
  }
}
