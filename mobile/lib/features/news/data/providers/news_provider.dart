import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/news.dart';
import '../repositories/news_repository.dart';

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return NewsRepository();
});

final newsProvider = FutureProvider.family<List<News>, String?>((ref, search) async {
  final repository = ref.read(newsRepositoryProvider);
  return await repository.getNews(search: search);
});

final newsDetailProvider = FutureProvider.family<News, int>((ref, newsId) async {
  final repository = ref.read(newsRepositoryProvider);
  return await repository.getNewsDetail(newsId);
});
