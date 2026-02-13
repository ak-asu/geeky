import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_spacing.dart';

class GeekyShimmer extends StatelessWidget {
  const GeekyShimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: child,
    );
  }

  /// Full-screen card shimmer (for feed)
  static Widget feedCard(BuildContext context) {
    return GeekyShimmer(
      child: Padding(
        padding: AppSpacing.paddingAll16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topic chip
            _shimmerBox(width: 80, height: 24, radius: AppSpacing.radiusFull),
            AppSpacing.gapV16,
            // Title
            _shimmerBox(width: double.infinity, height: 28),
            AppSpacing.gapV8,
            _shimmerBox(width: 200, height: 28),
            AppSpacing.gapV24,
            // Body lines
            _shimmerBox(width: double.infinity, height: 16),
            AppSpacing.gapV8,
            _shimmerBox(width: double.infinity, height: 16),
            AppSpacing.gapV8,
            _shimmerBox(width: 280, height: 16),
            AppSpacing.gapV8,
            _shimmerBox(width: double.infinity, height: 16),
            AppSpacing.gapV8,
            _shimmerBox(width: 220, height: 16),
          ],
        ),
      ),
    );
  }

  /// List item shimmer
  static Widget listItem() {
    return GeekyShimmer(
      child: Padding(
        padding: AppSpacing.paddingV8H16,
        child: Row(
          children: [
            _shimmerBox(width: 48, height: 48, radius: AppSpacing.radiusSm),
            AppSpacing.gapH12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(width: double.infinity, height: 16),
                  AppSpacing.gapV4,
                  _shimmerBox(width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Grid card shimmer
  static Widget gridCard() {
    return GeekyShimmer(
      child: Container(
        padding: AppSpacing.paddingAll16,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shimmerBox(width: 40, height: 40, radius: AppSpacing.radiusSm),
            AppSpacing.gapV12,
            _shimmerBox(width: double.infinity, height: 16),
            AppSpacing.gapV4,
            _shimmerBox(width: 80, height: 12),
            const Spacer(),
            _shimmerBox(width: double.infinity, height: 6, radius: 3),
          ],
        ),
      ),
    );
  }
}

Widget _shimmerBox({required double height, double? width, double radius = 4}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
