import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/paginated_state.dart';
import '../../../../core/utils/retry.dart';
import '../../domain/models/news.dart';
import '../repositories/news_repository.dart';

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return NewsRepository();
});

// ─────────────────────────────────────────────────────────────────────────────
// Paginated news notifier
// ─────────────────────────────────────────────────────────────────────────────

class PaginatedNewsNotifier extends StateNotifier<PaginatedState<News>> {
  PaginatedNewsNotifier(this._repository, this._search)
      : super(const PaginatedState<News>()) {
    loadFirstPage();
  }

  final NewsRepository _repository;
  final String? _search;

  /// Load (or reload) the first page.
  Future<void> loadFirstPage() async {
    state = const PaginatedState<News>(isLoading: true);
    try {
      final response = await retryWithBackoff(
        () => _repository.getNews(search: _search, page: 1),
      );
      state = PaginatedState<News>(
        items: response.results,
        currentPage: 1,
        totalCount: response.count,
        hasMore: response.hasNext,
      );
    } catch (e) {
      state = PaginatedState<News>(error: e.toString());
    }
  }

  /// Load the next page and append results.
  Future<void> loadNextPage() async {
    if (state.isLoadingMore || !state.hasMore) return;

    final nextPage = state.currentPage + 1;
    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await retryWithBackoff(
        () => _repository.getNews(search: _search, page: nextPage),
      );
      state = state.copyWith(
        items: [...state.items, ...response.results],
        currentPage: nextPage,
        totalCount: response.count,
        hasMore: response.hasNext,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: () => e.toString(),
      );
    }
  }
}

/// Paginated news provider — auto-disposes when search query changes.
final paginatedNewsProvider = StateNotifierProvider.autoDispose
    .family<PaginatedNewsNotifier, PaginatedState<News>, String?>(
  (ref, search) {
    final repository = ref.read(newsRepositoryProvider);
    return PaginatedNewsNotifier(repository, search);
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Non-paginated providers (detail)
// ─────────────────────────────────────────────────────────────────────────────

final newsDetailProvider = FutureProvider.autoDispose.family<News, int>((ref, newsId) async {
  final repository = ref.read(newsRepositoryProvider);
  return await retryWithBackoff(() => repository.getNewsDetail(newsId));
});
