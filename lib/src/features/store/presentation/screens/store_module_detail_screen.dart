import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/topic_chip.dart';
import '../../../subscription/providers.dart';
import '../../domain/store_module_entity.dart';
import '../../providers.dart';

class StoreModuleDetailScreen extends ConsumerWidget {
  const StoreModuleDetailScreen({super.key, required this.module});

  final StoreModuleEntity module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-watch the stream to get live download state
    final modulesAsync = ref.watch(allStoreModulesProvider);
    final liveModule =
        modulesAsync.value?.where((m) => m.id == module.id).firstOrNull ??
        module;
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: AppSpacing.paddingAll16,
        children: [
          // Title
          Text(
            liveModule.name,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          AppSpacing.gapV4,

          // Author
          Text(
            'by ${liveModule.author}',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.gapV16,

          // Stats row
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 18,
                color: AppColors.warning,
              ),
              AppSpacing.gapH4,
              Text(
                liveModule.rating.toStringAsFixed(1),
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              AppSpacing.gapH16,
              Icon(
                Icons.download_rounded,
                size: 18,
                color: context.colorScheme.onSurfaceVariant,
              ),
              AppSpacing.gapH4,
              Text(
                _formatDownloads(liveModule.downloads),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.gapH16,
              Icon(
                Icons.article_rounded,
                size: 18,
                color: context.colorScheme.onSurfaceVariant,
              ),
              AppSpacing.gapH4,
              Text(
                '${liveModule.shortCount} shorts',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          AppSpacing.gapV24,

          // Topics
          if (liveModule.topics.isNotEmpty) ...[
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: liveModule.topics
                  .map((t) => TopicChip(label: t))
                  .toList(),
            ),
            AppSpacing.gapV24,
          ],

          // Description
          Text(
            liveModule.description,
            style: context.textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
          AppSpacing.gapV32,

          // Download button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  _handleDownload(context, ref, liveModule, isPremium),
              icon: Icon(
                liveModule.isDownloaded
                    ? Icons.check_rounded
                    : Icons.download_rounded,
              ),
              label: Text(liveModule.isDownloaded ? 'Downloaded' : 'Download'),
              style: FilledButton.styleFrom(
                backgroundColor: liveModule.isDownloaded
                    ? AppColors.success
                    : AppColors.primary,
                padding: AppSpacing.paddingV16,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDownload(
    BuildContext context,
    WidgetRef ref,
    StoreModuleEntity current,
    bool isPremium,
  ) {
    final repo = ref.read(storeRepositoryProvider);

    // If already downloaded, allow un-download
    if (current.isDownloaded) {
      repo.toggleDownload(current.id);
      context.showSnackBar('Module removed');
      return;
    }

    // Check free tier limit
    if (!isPremium && repo.downloadedCount >= FreeTierLimits.maxStoreModules) {
      context.showSnackBar(
        'Free tier limited to ${FreeTierLimits.maxStoreModules} downloads. Upgrade for unlimited.',
      );
      return;
    }

    repo.toggleDownload(current.id);
    context.showSnackBar('Module downloaded');
  }

  String _formatDownloads(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
