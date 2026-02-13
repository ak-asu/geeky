import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const String fontFamily = 'PlusJakartaSans';

  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1.2,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.25,
      height: 1.25,
    ),
    displaySmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    headlineLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    headlineMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    headlineSmall: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.4,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.4,
    ),
  );
}
