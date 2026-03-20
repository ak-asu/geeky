/// Time-of-day difficulty scheduling for adaptive content ranking.
///
/// Maps the current hour to a target difficulty window so the feeds can
/// surface cognitively-appropriate content at each phase of the day.
///
/// Phase schedule:
///   Night     22:00–05:59  →  Easy     [0.00, 0.35]  (winding down / pre-sleep)
///   Morning   06:00–11:59  →  Medium   [0.35, 0.65]  (cognitive warm-up)
///   Afternoon 12:00–17:59  →  Hard     [0.65, 1.00]  (peak performance)
///   Evening   18:00–21:59  →  Med-easy [0.25, 0.55]  (relaxing after work)
enum DayPhase { night, morning, afternoon, evening }

/// Static helpers for time-of-day difficulty scheduling.
abstract final class TimeOfDayContext {
  /// Returns the [DayPhase] for the given [hour] (0–23). Defaults to now.
  static DayPhase currentPhase([int? hour]) {
    final h = hour ?? DateTime.now().hour;
    if (h >= 22 || h < 6) return DayPhase.night;
    if (h < 12) return DayPhase.morning;
    if (h < 18) return DayPhase.afternoon;
    return DayPhase.evening;
  }

  /// Returns the `(min, max)` difficulty window for [phase].
  ///
  /// Difficulty is normalised to [0.0, 1.0]:
  ///   0.0 = trivially easy, 1.0 = extremely challenging.
  static (double, double) difficultyWindow(DayPhase phase) =>
      switch (phase) {
        DayPhase.night     => (0.00, 0.35),
        DayPhase.morning   => (0.35, 0.65),
        DayPhase.afternoon => (0.65, 1.00),
        DayPhase.evening   => (0.25, 0.55),
      };

  /// Continuous difficulty-window score.
  ///
  /// Returns +2.0 when [value] is inside [window], then decays linearly to
  /// 0.0 over a ±0.2 difficulty-unit margin beyond the window edge.
  /// This avoids hard cliff edges where a content item just outside the
  /// ideal window is scored identically to the worst possible match.
  static double windowScore(double value, (double, double) window) {
    final (min, max) = window;
    final mid = (min + max) / 2;
    final halfWidth = (max - min) / 2;
    final distance = (value - mid).abs();
    if (distance <= halfWidth) return 2.0;
    final overshot = distance - halfWidth;
    return (2.0 - (overshot / 0.20) * 2.0).clamp(0.0, 2.0);
  }

  /// Word-count proxy for notes difficulty (notes have no explicit field).
  ///
  /// Linear scale: difficulty ≈ wordCount / 2000, clamped to [0.0, 1.0].
  /// Equivalent target word-count ranges per phase:
  ///   Night     ≤ 700 words
  ///   Morning   700–1 300 words
  ///   Afternoon 1 300+ words
  ///   Evening   500–1 100 words
  static double notesDifficultyProxy(int wordCount) =>
      (wordCount / 2000.0).clamp(0.0, 1.0);
}
