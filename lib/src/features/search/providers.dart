import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/api_service.dart';
import '../../core/providers/database_provider.dart';
import '../auth/providers.dart';
import '../shorts/domain/short_entity.dart';
import '../shorts/providers.dart';
import 'data/search_repository.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
SearchRepository searchRepository(Ref ref) {
  return SearchRepository(
    ref.read(appDatabaseProvider),
    ref.read(apiServiceProvider),
  );
}

/// The current search query text. Updated with 300ms debounce.
@riverpod
class SearchQuery extends _$SearchQuery {
  Timer? _debounce;

  @override
  String build() {
    ref.onDispose(() => _debounce?.cancel());
    return '';
  }

  void update(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      state = query;
    });
  }

  void clear() {
    _debounce?.cancel();
    state = '';
  }
}

/// Active topic filter for search results.
@riverpod
class SearchTopicFilter extends _$SearchTopicFilter {
  @override
  String? build() => null;

  void set(String? topic) => state = topic;
}

/// Active difficulty filter for search results.
@riverpod
class SearchDifficultyFilter extends _$SearchDifficultyFilter {
  @override
  String? build() => null;

  void set(String? difficulty) => state = difficulty;
}

/// Active read/unread filter for search results. null = all, true = read, false = unread.
@riverpod
class SearchReadFilter extends _$SearchReadFilter {
  @override
  bool? build() => null;

  void set(bool? value) => state = value;
}

/// Search results based on current query and filters.
@riverpod
Future<List<ShortEntity>> searchResults(Ref ref) async {
  final query = ref.watch(searchQueryProvider);
  final topicFilter = ref.watch(searchTopicFilterProvider);
  final difficultyFilter = ref.watch(searchDifficultyFilterProvider);
  final readFilter = ref.watch(searchReadFilterProvider);
  final doneIds = ref.watch(shortsFeedProvider);
  final userId = ref.watch(currentUserProvider)?.id ?? '';

  if (query.isEmpty) return [];

  return ref
      .read(searchRepositoryProvider)
      .searchShorts(
        userId: userId,
        query: query,
        topicFilter: topicFilter,
        difficultyFilter: difficultyFilter,
        readFilter: readFilter,
        doneIds: doneIds,
      );
}

/// Topic suggestions for autocomplete.
@riverpod
Future<List<String>> searchSuggestions(Ref ref) async {
  final query = ref.watch(searchQueryProvider);
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  if (query.isEmpty) return [];
  return ref.read(searchRepositoryProvider).suggestTopics(userId, query);
}

/// All available topics for filter chips.
@riverpod
Future<List<String>> availableTopics(Ref ref) async {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  return ref.read(searchRepositoryProvider).getAllTopics(userId);
}

/// Recent search queries (in-memory for now).
@Riverpod(keepAlive: true)
class RecentSearches extends _$RecentSearches {
  static const _maxRecent = 10;

  @override
  List<String> build() => [];

  void add(String query) {
    if (query.trim().isEmpty) return;
    final updated = [query, ...state.where((q) => q != query)];
    state = updated.take(_maxRecent).toList();
  }

  void remove(String query) {
    state = state.where((q) => q != query).toList();
  }

  void clear() => state = [];
}
