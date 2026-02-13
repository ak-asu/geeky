import 'package:flutter/material.dart';

abstract final class AppSpacing {
  // 8pt grid with 4pt half-step
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s48 = 48.0;
  static const double s64 = 64.0;

  // Border radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 999.0;

  // Common EdgeInsets
  static const EdgeInsets paddingAll8 = EdgeInsets.all(s8);
  static const EdgeInsets paddingAll16 = EdgeInsets.all(s16);
  static const EdgeInsets paddingAll24 = EdgeInsets.all(s24);
  static const EdgeInsets paddingH16 = EdgeInsets.symmetric(horizontal: s16);
  static const EdgeInsets paddingH24 = EdgeInsets.symmetric(horizontal: s24);
  static const EdgeInsets paddingV8 = EdgeInsets.symmetric(vertical: s8);
  static const EdgeInsets paddingV16 = EdgeInsets.symmetric(vertical: s16);
  static const EdgeInsets paddingV8H16 = EdgeInsets.symmetric(
    vertical: s8,
    horizontal: s16,
  );
  static const EdgeInsets paddingV16H24 = EdgeInsets.symmetric(
    vertical: s16,
    horizontal: s24,
  );

  // Common SizedBox gaps
  static const SizedBox gapH4 = SizedBox(width: s4);
  static const SizedBox gapH8 = SizedBox(width: s8);
  static const SizedBox gapH12 = SizedBox(width: s12);
  static const SizedBox gapH16 = SizedBox(width: s16);
  static const SizedBox gapH24 = SizedBox(width: s24);
  static const SizedBox gapV4 = SizedBox(height: s4);
  static const SizedBox gapV8 = SizedBox(height: s8);
  static const SizedBox gapV12 = SizedBox(height: s12);
  static const SizedBox gapV16 = SizedBox(height: s16);
  static const SizedBox gapV24 = SizedBox(height: s24);
  static const SizedBox gapV32 = SizedBox(height: s32);
  static const SizedBox gapV48 = SizedBox(height: s48);
}
