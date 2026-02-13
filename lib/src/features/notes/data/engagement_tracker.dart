import '../../../core/constants/app_constants.dart';

/// Tracks user engagement metrics for a single card/article view.
///
/// Manages a [Stopwatch] for time spent, scroll depth tracking,
/// and determines if the viewing session qualifies as a "read".
class EngagementTracker {
  final Stopwatch _stopwatch = Stopwatch();
  double _maxScrollDepth = 0;
  bool _isActive = false;

  /// Whether the tracker is currently running.
  bool get isActive => _isActive;

  /// Total time spent viewing in seconds.
  double get timeSpentSeconds => _stopwatch.elapsed.inMilliseconds / 1000;

  /// Maximum scroll depth reached (0.0 to 1.0).
  double get maxScrollDepth => _maxScrollDepth;

  /// Whether the user spent enough time to count as a read.
  bool get qualifiesAsRead => _stopwatch.elapsed >= AppConstants.minReadTime;

  /// Start tracking engagement.
  void start() {
    _stopwatch.start();
    _isActive = true;
  }

  /// Pause tracking (e.g. app backgrounded).
  void pause() {
    _stopwatch.stop();
    _isActive = false;
  }

  /// Resume tracking after pause.
  void resume() {
    _stopwatch.start();
    _isActive = true;
  }

  /// Update scroll depth (0.0 to 1.0).
  void updateScrollDepth(double depth) {
    if (depth > _maxScrollDepth) {
      _maxScrollDepth = depth.clamp(0.0, 1.0);
    }
  }

  /// Stop tracking and return final metrics.
  EngagementMetrics stop() {
    _stopwatch.stop();
    _isActive = false;
    return EngagementMetrics(
      timeSpentSeconds: timeSpentSeconds,
      maxScrollDepth: _maxScrollDepth,
      qualifiesAsRead: qualifiesAsRead,
    );
  }

  /// Reset all tracked values.
  void reset() {
    _stopwatch.reset();
    _maxScrollDepth = 0;
    _isActive = false;
  }
}

/// Immutable snapshot of engagement metrics.
class EngagementMetrics {
  const EngagementMetrics({
    required this.timeSpentSeconds,
    required this.maxScrollDepth,
    required this.qualifiesAsRead,
  });

  final double timeSpentSeconds;
  final double maxScrollDepth;
  final bool qualifiesAsRead;
}
