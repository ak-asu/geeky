import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/geeky_empty_state.dart';
import '../../../../core/widgets/geeky_error_widget.dart';
import '../../../../core/widgets/geeky_shimmer.dart';
import '../../../../routing/route_names.dart';
import '../../../shorts/domain/short_entity.dart';
import '../../../shorts/presentation/screens/shorts_feed_screen.dart';
import '../../providers.dart';
import '../widgets/search_result_tile.dart';
import '../widgets/search_filter_bar.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSubmit(String query) {
    if (query.trim().isEmpty) return;
    ref.read(recentSearchesProvider.notifier).add(query.trim());
  }

  void _onClear() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).clear();
    _focusNode.requestFocus();
  }

  void _onRecentTap(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    ref.read(searchQueryProvider.notifier).update(query);
    ref.read(recentSearchesProvider.notifier).add(query);
  }

  void _onResultTap(ShortEntity short) {
    context.pushNamed(
      RouteNames.shortsFeed,
      extra: ShortsFeedParams(filterShortIds: [short.id], title: short.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final recentSearches = ref.watch(recentSearchesProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s8,
                AppSpacing.s8,
                AppSpacing.s16,
                AppSpacing.s4,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      onChanged: (v) =>
                          ref.read(searchQueryProvider.notifier).update(v),
                      onSubmitted: _onSubmit,
                      decoration: InputDecoration(
                        hintText: 'Search shorts, topics...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: AppSpacing.paddingV8H16,
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                onPressed: _onClear,
                              )
                            : null,
                      ),
                      style: context.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Filters
            if (query.isNotEmpty) const SearchFilterBar(),

            // Body: recent searches or results
            Expanded(
              child: query.isEmpty
                  ? _RecentSearchesBody(
                      searches: recentSearches,
                      onTap: _onRecentTap,
                      onRemove: (q) =>
                          ref.read(recentSearchesProvider.notifier).remove(q),
                      onClearAll: () =>
                          ref.read(recentSearchesProvider.notifier).clear(),
                    )
                  : _SearchResultsBody(onResultTap: _onResultTap),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSearchesBody extends StatelessWidget {
  const _RecentSearchesBody({
    required this.searches,
    required this.onTap,
    required this.onRemove,
    required this.onClearAll,
  });

  final List<String> searches;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) {
      return const GeekyEmptyState(
        icon: Icons.search_rounded,
        title: 'Search your knowledge',
        subtitle: 'Find shorts by keyword, topic, or title.',
      );
    }

    return ListView(
      padding: AppSpacing.paddingV8H16,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent',
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(onPressed: onClearAll, child: const Text('Clear all')),
          ],
        ),
        ...searches.map(
          (query) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.history_rounded,
              size: 20,
              color: context.colorScheme.onSurfaceVariant,
            ),
            title: Text(query, style: context.textTheme.bodyMedium),
            trailing: IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 16,
                color: context.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
              onPressed: () => onRemove(query),
            ),
            onTap: () => onTap(query),
          ),
        ),
      ],
    );
  }
}

class _SearchResultsBody extends ConsumerWidget {
  const _SearchResultsBody({required this.onResultTap});

  final ValueChanged<ShortEntity> onResultTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchResultsProvider);

    return resultsAsync.when(
      loading: () => ListView.builder(
        itemCount: 6,
        itemBuilder: (_, _) => GeekyShimmer.listItem(),
      ),
      error: (error, _) => GeekyErrorWidget(message: error.toString()),
      data: (results) {
        if (results.isEmpty) {
          return const GeekyEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No results found',
            subtitle: 'Try a different keyword or adjust your filters.',
          );
        }

        return ListView.builder(
          padding: AppSpacing.paddingV8H16,
          itemCount: results.length,
          itemBuilder: (context, index) {
            return SearchResultTile(
              short: results[index],
              onTap: () => onResultTap(results[index]),
            );
          },
        );
      },
    );
  }
}
