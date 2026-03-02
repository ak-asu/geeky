import 'package:intl/intl.dart';

extension DateTimeExtensions on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  bool get isThisWeek {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return isAfter(weekStart.subtract(const Duration(days: 1)));
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  /// Locale-aware date formatted as "Today", "Yesterday", or "March 15, 2024".
  String get formatDate {
    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    return DateFormat.yMMMMd().format(this);
  }

  /// Locale-aware short date formatted as "Mar 15".
  String get formatShort {
    return DateFormat.MMMd().format(this);
  }
}
