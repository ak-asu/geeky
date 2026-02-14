import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class MarkdownRenderer extends StatelessWidget {
  const MarkdownRenderer({
    super.key,
    required this.data,
    this.shrinkWrap = false,
    this.physics,
  });

  final String data;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return MarkdownWidget(
      data: data,
      shrinkWrap: shrinkWrap,
      physics: physics,
      markdownGenerator: MarkdownGenerator(
        linesMargin: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      ),
      config: MarkdownConfig(
        configs: [
          PConfig(
            textStyle: context.textTheme.bodyLarge!.copyWith(
              height: 1.7,
              color: context.colorScheme.onSurface,
            ),
          ),
          H1Config(
            style: context.textTheme.headlineSmall!.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colorScheme.onSurface,
            ),
          ),
          H2Config(
            style: context.textTheme.titleLarge!.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurface,
            ),
          ),
          H3Config(
            style: context.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurface,
            ),
          ),
          PreConfig(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            padding: AppSpacing.paddingAll16,
          ),
          CodeConfig(
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: AppColors.primary,
              backgroundColor: isDark
                  ? AppColors.darkCard
                  : const Color(0xFFF5F5F5),
            ),
          ),
          BlockquoteConfig(
            sideColor: AppColors.primary,
            textColor: context.colorScheme.onSurfaceVariant,
          ),
          const LinkConfig(
            style: TextStyle(
              color: AppColors.primary,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
