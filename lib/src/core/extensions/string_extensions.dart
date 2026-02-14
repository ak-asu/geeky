/// Formats note type codes into display labels.
String formatNoteType(String type) {
  return switch (type) {
    'text' => 'Text Note',
    'url' => 'Web Link',
    'pdf' => 'PDF',
    'image' => 'Image',
    'audio' => 'Audio',
    'video' => 'Video',
    _ => type.capitalized,
  };
}

extension StringExtensions on String {
  String get capitalized {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String get titleCase {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalized).join(' ');
  }

  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - suffix.length)}$suffix';
  }

  String get initials {
    if (isEmpty) return '';
    final words = trim().split(RegExp(r'\s+'));
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}
