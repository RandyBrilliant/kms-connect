import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTheme {
  // M3 seed — drives the generated color roles (primary, secondary, tertiary,
  // surface-container tones, etc.) automatically.
  static const _seed = AppColors.primaryDarkGreen;

  // Cached once — avoids rebuilding ColorScheme, GoogleFonts, and all
  // button/input themes on every widget rebuild.
  static final ThemeData lightTheme = _buildLightTheme();

  static ThemeData _buildLightTheme() {
    final base = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );

    // Override specific roles to keep exact brand fidelity while still
    // benefiting from the full generated M3 palette for surface containers.
    final colorScheme = base.copyWith(
      primary: AppColors.primaryDarkGreen,
      onPrimary: Colors.white,
      secondary: const Color(0xFF52796F),
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.textDark,
      onSurfaceVariant: AppColors.textMedium,
      outline: AppColors.divider,
      outlineVariant: const Color(0xFFE8EDE8),
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    ).copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800, letterSpacing: -1.0),
      displayMedium: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      headlineSmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w400),
      bodyMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w400),
      bodySmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w400),
      labelLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      labelMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
      labelSmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),

      // ── Filled Button (M3 primary CTA) ────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // ── Elevated Button ───────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // ── Outlined Button ───────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Text Button ───────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ── Input Decoration (default — individual fields may override) ───────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textMedium,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        floatingLabelStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textMedium,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textMedium,
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ── Chip ──────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),

      // ── List Tile ─────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // ── Navigation Bar ────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.plusJakartaSans(
              fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),

      // ── Bottom Sheet ──────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // ── Dialog ────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}
