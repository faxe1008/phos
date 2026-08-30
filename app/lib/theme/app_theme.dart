import 'package:flutter/material.dart';

/// Phos dark theme: near-black charcoal base with a warm amber accent,
/// tonal cards with hairline borders, generous radii.
abstract final class AppTheme {
  static const Color seed = Color(0xFFE8A33D);
  static const Color bg = Color(0xFF0B0B0F);
  static const Color surface = Color(0xFF14141B);
  static const Color surfaceHigh = Color(0xFF1C1C26);
  static const Color hairline = Color(0x14FFFFFF);
  static const Color textPrimary = Color(0xFFF2F2F5);
  static const Color textSecondary = Color(0x99F2F2F5);
  static const Color textTertiary = Color(0x66F2F2F5);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: surface,
      onSurface: textPrimary,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: textSecondary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: hairline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        side: const BorderSide(color: hairline),
        labelStyle: const TextStyle(fontSize: 11, color: textSecondary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHigh,
        contentTextStyle: TextStyle(color: textPrimary, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(color: hairline, thickness: 1),
      listTileTheme: const ListTileThemeData(iconColor: textSecondary),
    );
  }
}