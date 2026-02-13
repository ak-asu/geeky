abstract final class Validators {
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final _urlRegex = RegExp(
    r'^https?://[^\s/$.?#].[^\s]*$',
    caseSensitive: false,
  );

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!_emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? url(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'URL is required';
    }
    if (!_urlRegex.hasMatch(value.trim())) {
      return 'Enter a valid URL';
    }
    return null;
  }

  static bool isValidEmail(String value) => _emailRegex.hasMatch(value.trim());
  static bool isValidUrl(String value) => _urlRegex.hasMatch(value.trim());
}
