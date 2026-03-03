/// Generic paginated list state used by infinite-scroll providers.
///
/// Works with DRF's `PageNumberPagination` response format:
/// ```json
/// { "count": 42, "next": "…?page=3", "previous": "…?page=1", "results": [...] }
/// ```
class PaginatedState<T> {
  const PaginatedState({
    this.items = const [],
    this.currentPage = 0,
    this.totalCount = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  /// Accumulated items from all loaded pages.
  final List<T> items;

  /// Last page that was successfully fetched (1-based from backend).
  final int currentPage;

  /// Total count of items reported by the backend.
  final int totalCount;

  /// True when the first page is loading.
  final bool isLoading;

  /// True when subsequent pages are loading (append).
  final bool isLoadingMore;

  /// Whether more pages are available.
  final bool hasMore;

  /// Latest error message, if any.
  final String? error;

  PaginatedState<T> copyWith({
    List<T>? items,
    int? currentPage,
    int? totalCount,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? Function()? error,
  }) {
    return PaginatedState<T>(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error != null ? error() : this.error,
    );
  }
}

/// Parsed response from a DRF paginated endpoint.
class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.count,
    required this.results,
    required this.hasNext,
  });

  final int count;
  final List<T> results;
  final bool hasNext;
}
