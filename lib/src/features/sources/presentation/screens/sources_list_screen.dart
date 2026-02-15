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
import '../../domain/content_source_entity.dart';
import '../../providers.dart';
import '../widgets/source_card.dart';

class SourcesListScreen extends ConsumerWidget {
  const SourcesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(allSourcesProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sources',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: context.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final sources = sourcesAsync.value ?? [];
          if (!isPremium && sources.length >= FreeTierLimits.maxSources) {
            context.showSnackBar(
              'Free tier limited to ${FreeTierLimits.maxSources} sources. Upgrade for unlimited.',
            );
            return;
          }
          context.pushNamed(RouteNames.addSource);
        },
        child: const Icon(Icons.add_rounded),
      ),
      body: sourcesAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.only(top: AppSpacing.s8),
          itemCount: 3,
          itemBuilder: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s4,
            ),
            child: GeekyShimmer.listItem(),
          ),
        ),
        error: (error, _) => GeekyErrorWidget(
          message: 'Could not load sources',
          onRetry: () => ref.invalidate(allSourcesProvider),
        ),
        data: (sources) {
          if (sources.isEmpty) {
            return GeekyEmptyState(
              icon: Icons.source_rounded,
              title: 'No Sources Yet',
              subtitle: 'Add content sources to feed your learning pipeline.',
              actionLabel: 'Add Source',
              onAction: () => context.pushNamed(RouteNames.addSource),
            );
          }
          return _SourcesList(sources: sources, isPremium: isPremium);
        },
      ),
    );
  }
}

class _SourcesList extends StatelessWidget {
  const _SourcesList({required this.sources, required this.isPremium});

  final List<ContentSourceEntity> sources;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
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
              '${sources.length} / ${FreeTierLimits.maxSources} sources used',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
            itemCount: sources.length,
            itemBuilder: (context, index) {
              final source = sources[index];
              return SourceCard(
                    source: source,
                    onTap: () => context.pushNamed(
                      RouteNames.sourceDetail,
                      extra: source,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: (50 * index).ms)
                  .slideY(
                    begin: 0.1,
                    end: 0,
                    duration: 300.ms,
                    delay: (50 * index).ms,
                  );
            },
          ),
        ),
      ],
    );
  }
}
