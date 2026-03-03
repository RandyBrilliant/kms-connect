import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/colors.dart';

/// A standardized, optimized network image widget that wraps
/// [CachedNetworkImage] with consistent defaults:
///
///  - Memory-efficient: uses [memCacheWidth]/[memCacheHeight] to keep decoded
///    bitmaps small — critical when displaying many images in lists.
///  - Consistent skeleton placeholder and error fallback.
///  - Proper fade-in duration for smooth UX.
///
/// ```dart
/// OptimizedNetworkImage(
///   imageUrl: news.heroImage ?? '',
///   width: 100,
///   height: 100,
/// )
/// ```
class OptimizedNetworkImage extends StatelessWidget {
  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 12.0,
    this.memCacheWidth = 400,
    this.memCacheHeight,
    this.placeholderIcon = Icons.image_outlined,
    this.errorIcon = Icons.broken_image_outlined,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;

  /// Max width/height for the decoded bitmap in memory.
  /// Defaults to 400px wide which is sufficient for list thumbnails.
  /// For hero/full-screen images, increase this or set to null.
  final int? memCacheWidth;
  final int? memCacheHeight;

  final IconData placeholderIcon;
  final IconData errorIcon;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _fallback(context, placeholderIcon);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        fadeInDuration: const Duration(milliseconds: 250),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (_, __) => _placeholder(context),
        errorWidget: (_, __, ___) => _fallback(context, errorIcon),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryDarkGreen.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context, IconData icon) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.primaryDarkGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        icon,
        color: AppColors.primaryDarkGreen.withValues(alpha: 0.3),
        size: 28,
      ),
    );
  }
}
