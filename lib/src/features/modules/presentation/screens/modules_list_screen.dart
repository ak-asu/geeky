import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/geeky_empty_state.dart';
import '../../../../core/widgets/geeky_shimmer.dart';
import '../../../../routing/route_names.dart';
import '../../domain/module_entity.dart';
import '../../providers.dart';
import '../widgets/module_card.dart';

class ModulesListScreen extends ConsumerWidget {
  const ModulesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(allModulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Modules',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: context.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed(RouteNames.createModule),
        child: const Icon(Icons.add_rounded),
      ),
      body: modulesAsync.when(
        loading: _buildShimmerGrid,
        error: (error, _) => GeekyEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load modules',
          subtitle: error.toString(),
        ),
        data: (modules) {
          if (modules.isEmpty) {
            return GeekyEmptyState(
              icon: Icons.view_module_rounded,
              title: 'No Modules Yet',
              subtitle: 'Modules group related shorts into learning paths.',
              actionLabel: 'Create Module',
              onAction: () => context.pushNamed(RouteNames.createModule),
            );
          }
          return _buildGrid(context, modules);
        },
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<ModuleEntity> modules) {
    return GridView.builder(
      padding: AppSpacing.paddingAll16,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.s12,
        crossAxisSpacing: AppSpacing.s12,
        childAspectRatio: 0.85,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final module = modules[index];
        return ModuleCard(
          module: module,
          onTap: () =>
              context.pushNamed(RouteNames.moduleDetail, extra: module),
        );
      },
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: AppSpacing.paddingAll16,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.s12,
        crossAxisSpacing: AppSpacing.s12,
        childAspectRatio: 0.85,
      ),
      itemCount: 4,
      itemBuilder: (_, _) => GeekyShimmer.gridCard(),
    );
  }
}
