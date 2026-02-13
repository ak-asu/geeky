import 'package:flutter/material.dart';

abstract final class AppColors {
  // Primary — Teal/Cyan
  static const Color primary = Color(0xFF00BFA5);
  static const Color primaryLight = Color(0xFF5DF2D6);
  static const Color primaryDark = Color(0xFF008E76);
  static const Color primaryContainer = Color(0xFFB2DFDB);
  static const Color onPrimaryContainer = Color(0xFF00251E);

  // Secondary
  static const Color secondary = Color(0xFF26C6DA);
  static const Color secondaryContainer = Color(0xFFB2EBF2);

  // Tertiary
  static const Color tertiary = Color(0xFF80CBC4);
  static const Color tertiaryContainer = Color(0xFFE0F2F1);

  // Semantic
  static const Color error = Color(0xFFEF5350);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);

  // Light theme surfaces
  static const Color lightSurface = Color(0xFFFAFAFA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFE0E0E0);

  // Dark theme surfaces
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkDivider = Color(0xFF2C2C2C);

  // Node status colors (Knowledge Graph)
  static const Color nodeMastered = Color(0xFF4CAF50);
  static const Color nodeInProgress = Color(0xFF00BFA5);
  static const Color nodeUnread = Color(0xFF9E9E9E);
  static const Color nodeLocked = Color(0xFF424242);
}
