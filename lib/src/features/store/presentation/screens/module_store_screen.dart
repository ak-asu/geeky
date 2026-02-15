import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/geeky_empty_state.dart';
import '../../../../core/widgets/geeky_error_widget.dart';
import '../../../../core/widgets/geeky_shimmer.dart';
import '../../../../routing/route_names.dart';
import '../../../subscription/providers.dart';
import '../../domain/store_module_entity.dart';
import '../../providers.dart';
import '../widgets/store_module_card.dart';

class ModuleStoreScreen extends ConsumerWidget {
  const ModuleStoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(allStoreModulesProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Module Store')),
      body: modulesAsync.when(
        loading: () => GridView.builder(
          padding: AppSpacing.paddingAll16,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.s12,
            crossAxisSpacing: AppSpacing.s12,
            childAspectRatio: 0.75,
          ),
          itemCount: 4,
          itemBuilder: (_, _) => GeekyShimmer.gridCard(),
        ),
        error: (error, _) => GeekyErrorWidget(
          message: 'Could not load store',
          onRetry: () => ref.invalidate(allStoreModulesProvider),
        ),
        data: (modules) {
          if (modules.isEmpty) {
            return const GeekyEmptyState(
              icon: Icons.store_rounded,
              title: 'Store Empty',
              subtitle: 'No modules available in the store yet.',
            );
          }
          return _StoreGrid(modules: modules, isPremium: isPremium);
        },
      ),
    );
  }
}

class _StoreGrid extends ConsumerWidget {
  const _StoreGrid({required this.modules, required this.isPremium});

  final List<StoreModuleEntity> modules;
  final bool isPremium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadedCount = modules.where((m) => m.isDownloaded).length;

    return Column(
      children: [
        if (!isPremium)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s8,
              AppSpacing.s16,
              0,
            ),
            child: Text(
              '$downloadedCount / ${FreeTierLimits.maxStoreModules} downloads used',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: AppSpacing.paddingAll16,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.s12,
              crossAxisSpacing: AppSpacing.s12,
              childAspectRatio: 0.75,
            ),
            itemCount: modules.length,
            itemBuilder: (context, index) {
              final module = modules[index];
              return StoreModuleCard(
                    module: module,
                    onTap: () => context.pushNamed(
                      RouteNames.storeModuleDetail,
                      extra: module,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: (80 * index).ms)
                  .scale(
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1, 1),
                    duration: 300.ms,
                    delay: (80 * index).ms,
                  );
            },
          ),
        ),
      ],
    );
  }
}
