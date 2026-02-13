import 'package:flutter/material.dart';
import 'exceptions.dart';
import 'failures.dart';

abstract final class ErrorHandler {
  static void showError(BuildContext context, Object error) {
    final message = _extractMessage(error);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Dismiss',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
  }

  static void showErrorWithRetry(
    BuildContext context,
    Object error,
    VoidCallback onRetry,
  ) {
    final message = _extractMessage(error);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: 'Retry', onPressed: onRetry),
        ),
      );
  }

  static String _extractMessage(Object error) {
    if (error is Failure) return error.message;
    if (error is AppException) return error.message;
    return 'Something went wrong. Please try again.';
  }
}
