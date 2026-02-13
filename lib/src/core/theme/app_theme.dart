import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static const _schemeColor = FlexSchemeColor(
    primary: AppColors.primary,
    primaryContainer: AppColors.primaryContainer,
    secondary: AppColors.secondary,
    secondaryContainer: AppColors.secondaryContainer,
    tertiary: AppColors.tertiary,
    tertiaryContainer: AppColors.tertiaryContainer,
  );

  static const _subThemes = FlexSubThemesData(
    interactionEffects: true,
    blendOnColors: true,
    useM2StyleDividerInM3: false,

    // Card
    cardRadius: AppSpacing.radiusLg,
    cardElevation: 0,

    // Input
    inputDecoratorRadius: AppSpacing.radiusMd,
    inputDecoratorBorderType: FlexInputBorderType.outline,
    inputDecoratorUnfocusedHasBorder: true,
    inputDecoratorFocusedHasBorder: true,

    // Chips
    chipRadius: AppSpacing.radiusSm,

    // Buttons
    elevatedButtonRadius: AppSpacing.radiusMd,
    filledButtonRadius: AppSpacing.radiusMd,
    outlinedButtonRadius: AppSpacing.radiusMd,
    textButtonRadius: AppSpacing.radiusMd,

    // FAB
    fabRadius: AppSpacing.radiusLg,
    fabUseShape: true,

    // Bottom sheet
    bottomSheetRadius: AppSpacing.radiusXl,

    // Dialog
    dialogRadius: AppSpacing.radiusLg,

    // Navigation drawer
    drawerRadius: 0,
    drawerWidth: 300,

    // Snackbar
    snackBarRadius: AppSpacing.radiusMd,
  );

  static ThemeData light() {
    final base = FlexThemeData.light(
      colors: _schemeColor,
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 2,
      subThemesData: _subThemes,
      useMaterial3: true,
      textTheme: AppTypography.textTheme,
      primaryTextTheme: AppTypography.textTheme,
    );

    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
      primaryTextTheme: GoogleFonts.plusJakartaSansTextTheme(
        base.primaryTextTheme,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: AppColors.lightCard,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: base.dividerTheme.copyWith(color: AppColors.lightDivider),
    );
  }

  static ThemeData dark() {
    final base = FlexThemeData.dark(
      colors: _schemeColor,
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 8,
      subThemesData: _subThemes,
      useMaterial3: true,
      textTheme: AppTypography.textTheme,
      primaryTextTheme: AppTypography.textTheme,
    );

    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
      primaryTextTheme: GoogleFonts.plusJakartaSansTextTheme(
        base.primaryTextTheme,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: AppColors.darkCard,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: base.dividerTheme.copyWith(color: AppColors.darkDivider),
    );
  }
}
