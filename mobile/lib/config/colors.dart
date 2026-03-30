import 'package:flutter/material.dart';

/// Professional color palette for KMS Connect job listing platform
/// Primary: Dark Green #2B6E36 (Trust, Growth, Stability)
/// Secondary: Light Green #D4E9D7 (Fresh, Professional)
/// Background: Off-white #F5F5F5 (Clean, Modern)
class AppColors {
  // ── Primary Colors (Brand Identity) ──────────────────────────────────────
  static const Color primaryDarkGreen = Color(0xFF2B6E36);
  static const Color secondaryLightGreen = Color(0xFFD4E9D7);
  static const Color backgroundOffWhite = Color(0xFFF5F5F5);

  // ── Professional Gradient Colors ─────────────────────────────────────────
  /// Main gradient start (darker green)
  static const Color gradientStart = Color(0xFF1E5128);
  
  /// Main gradient middle
  static const Color gradientMiddle = Color(0xFF2B6E36);
  
  /// Main gradient end (lighter green)
  static const Color gradientEnd = Color(0xFF4E9F3D);
  
  /// Overlay gradient for depth (semi-transparent)
  static const Color gradientOverlay = Color(0x1A000000);

  // ── Neutral Colors (WCAG AA Compliant) ───────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textMedium = Color(0xFF666666);
  static const Color textLight = Color(0xFF999999);
  static const Color textHint = Color(0xFFAAAAAA);

  // ── Semantic Colors ──────────────────────────────────────────────────────
  static const Color error = Color(0xFFDC3545);
  static const Color success = Color(0xFF28A745);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF17A2B8);

  // ── UI Element Colors ────────────────────────────────────────────────────
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color disabled = Color(0xFFCCCCCC);
  static const Color shadow = Color(0x1A000000);
  static const Color shimmer = Color(0xFFE8E8E8);

  // ── Professional Accent Colors ──────────────────────────────────────────
  /// For trust badges and security indicators
  static const Color trustBlue = Color(0xFF0066CC);
  
  /// For premium/featured content
  static const Color premiumGold = Color(0xFFD4AF37);

  // ── Helper Methods ───────────────────────────────────────────────────────
  
  /// Professional linear gradient for backgrounds
  static const LinearGradient professionalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientMiddle, gradientEnd],
    stops: [0.0, 0.5, 1.0],
  );

  /// Subtle overlay for images
  static const LinearGradient imageOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0x80000000)],
    stops: [0.3, 1.0],
  );

  /// Card shadow for elevation
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: shadow,
          blurRadius: 20,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  /// Elevated card shadow
  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: shadow,
          blurRadius: 30,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
      ];

  /// Subtle inner shadow for input fields
  static List<BoxShadow> get innerShadow => [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 4,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ];
}
