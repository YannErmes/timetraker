import 'package:flutter/material.dart';

/// App-wide palette. Values switch between dark and light sets based on
/// [lightMode] — read them in `build()` (never in `const` expressions).
class AppColors {
  /// Flipped by the app root whenever the theme preference changes.
  static bool lightMode = false;

  // Accent works on both themes.
  static const Color _accent = Color(0xFF4F6BFF);
  static Color get accent => _accent;

  static Color get bg => lightMode ? const Color(0xFFF1F4F9) : const Color(0xFF0B0F19);
  static Color get surface => lightMode ? const Color(0xFFFFFFFF) : const Color(0xFF141A29);
  static Color get surfaceAlt => lightMode ? const Color(0xFFF4F6FB) : const Color(0xFF161D2E); // alternating row
  static Color get header => lightMode ? const Color(0xFFE6EAF2) : const Color(0xFF1B2333);
  static Color get border => lightMode ? const Color(0xFFD4DBE7) : const Color(0xFF2A3346);
  static Color get textPrimary => lightMode ? const Color(0xFF141A29) : const Color(0xFFEDEFF3);
  static Color get textSecondary => lightMode ? const Color(0xFF5C6679) : const Color(0xFF8891A5);
  static Color get inputFill => lightMode ? const Color(0xFFEAEEF5) : const Color(0xFF1E2536);
  static Color get inputBorder => lightMode ? const Color(0xFFC6CFDF) : const Color(0xFF333D52);
  static Color get noneFill => lightMode ? const Color(0xFFEAEEF5) : const Color(0xFF1E2536);
  static Color get noneBorder => lightMode ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  static Color get doneFill => lightMode ? const Color(0xFFDDF5E6) : const Color(0xFF14321F);
  static Color get doneText => lightMode ? const Color(0xFF15803D) : const Color(0xFFBBF7D0);
  static Color get doneBorder => lightMode ? const Color(0xFF22C55E) : const Color(0xFF22C55E);
  static Color get cancelFill => lightMode ? const Color(0xFFFDE3E8) : const Color(0xFF3A1520);
  static Color get cancelText => lightMode ? const Color(0xFFBE123C) : const Color(0xFFFECDD3);
  static Color get cancelBorder => lightMode ? const Color(0xFFF43F5E) : const Color(0xFFF43F5E);
  static Color get inProgressFill => lightMode ? const Color(0xFFFEF3D7) : const Color(0xFF2A2416);
  static Color get inProgressText => lightMode ? const Color(0xFFB45309) : const Color(0xFFFDE68A);
  static Color get inProgressBorder => lightMode ? const Color(0xFFF59E0B) : const Color(0xFFF59E0B);
}
