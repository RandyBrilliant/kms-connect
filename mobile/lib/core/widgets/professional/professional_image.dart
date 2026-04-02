import 'package:flutter/material.dart';
import '../../../config/colors.dart';

/// Professional image widget with overlay and fallback
/// Handles loading states and errors gracefully
class ProfessionalImage extends StatelessWidget {
  const ProfessionalImage({
    super.key,
    required this.imageUrl,
    this.height = 200,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.only(
      topLeft: Radius.circular(24),
      topRight: Radius.circular(24),
    ),
    this.withOverlay = true,
  });

  final String imageUrl;
  final double height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final bool withOverlay;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image or placeholder
            _buildImage(),
            
            // Gradient overlay for better text readability
            if (withOverlay)
              Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.imageOverlay,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    // For now, use asset image if exists, otherwise show professional placeholder
    return Image.asset(
      imageUrl,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Professional placeholder with gradient
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2B6E36),
                Color(0xFF4E9F3D),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.business_center_rounded,
                  size: 64,
                  color: Colors.white.withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'KMS Connect',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Platform Rekrutmen PMI',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Network image version for loading from Unsplash
class ProfessionalNetworkImage extends StatelessWidget {
  const ProfessionalNetworkImage({
    super.key,
    required this.imageUrl,
    this.height = 200,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.only(
      topLeft: Radius.circular(24),
      topRight: Radius.circular(24),
    ),
    this.withOverlay = true,
  });

  final String imageUrl;
  final double height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final bool withOverlay;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Network image with loading and error states
            Image.network(
              imageUrl,
              fit: fit,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: AppColors.backgroundOffWhite,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: AppColors.primaryDarkGreen,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2B6E36),
                        Color(0xFF4E9F3D),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.business_center_rounded,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                );
              },
            ),
            
            // Gradient overlay
            if (withOverlay)
              Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.imageOverlay,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
