import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../config/colors.dart';
import '../../../../config/strings.dart';
import '../../data/providers/news_provider.dart';

class NewsDetailPage extends ConsumerWidget {
  final int newsId;

  const NewsDetailPage({super.key, required this.newsId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(newsDetailProvider(newsId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.news),
      ),
      body: newsAsync.when(
        data: (news) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (news.heroImage != null)
                CachedNetworkImage(
                  imageUrl: news.heroImage!,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 250,
                    color: AppColors.backgroundOffWhite,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 250,
                    color: AppColors.backgroundOffWhite,
                    child: const Icon(Icons.error),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (news.isPinned)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDarkGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PINNED',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (news.isPinned) const SizedBox(height: 12),
                    Text(
                      news.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Text(
                          news.publishedAt != null
                              ? DateFormat('dd MMMM yyyy', 'id_ID').format(news.publishedAt!)
                              : DateFormat('dd MMMM yyyy', 'id_ID').format(news.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (news.summary != null && news.summary!.isNotEmpty) ...[
                      Text(
                        news.summary!,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMedium,
                            ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      news.content,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(newsDetailProvider(newsId)),
                child: const Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
