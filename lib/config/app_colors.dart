import 'package:flutter/material.dart';

/// App-wide palette. Values switch between dark/light sets based on
/// [lightMode], and turn translucent when [customMode] has a background
/// image ([customHasImage]) so the photo shows through frosted surfaces.
/// Read them in `build()` (never in `const` expressions).
class AppColors {
  /// Flipped by the app root whenever the theme preference changes.
  static bool lightMode = false;

  /// True when the Custom theme is active AND a background image is set.
  static bool customBg = false;

  // Accent works on both themes.
  static const Color _accent = Color(0xFF4F6BFF);
  static Color get accent => _accent;

  static Color _t(Color c, double alpha) => c.withValues(alpha: alpha);

  static Color get bg => customBg
      ? Colors.transparent
      : lightMode
          ? const Color(0xFFF1F4F9)
          : const Color(0xFF0B0F19);
  static Color get surface => customBg
      ? _t(const Color(0xFF141A29), 0.86)
      : lightMode
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF141A29);
  static Color get surfaceAlt => customBg
      ? _t(const Color(0xFF161D2E), 0.86)
      : lightMode
          ? const Color(0xFFF4F6FB)
          : const Color(0xFF161D2E); // alternating row
  static Color get header => customBg
      ? _t(const Color(0xFF1B2333), 0.9)
      : lightMode
          ? const Color(0xFFE6EAF2)
          : const Color(0xFF1B2333);
  static Color get border => lightMode && !customBg ? const Color(0xFFD4DBE7) : const Color(0xFF2A3346);
  static Color get textPrimary => lightMode && !customBg ? const Color(0xFF141A29) : const Color(0xFFEDEFF3);
  static Color get textSecondary => lightMode && !customBg ? const Color(0xFF5C6679) : const Color(0xFF8891A5);
  static Color get inputFill => customBg
      ? _t(const Color(0xFF1E2536), 0.72)
      : lightMode
          ? const Color(0xFFEAEEF5)
          : const Color(0xFF1E2536);
  static Color get inputBorder => lightMode && !customBg ? const Color(0xFFC6CFDF) : const Color(0xFF333D52);
  static Color get noneFill => customBg
      ? _t(const Color(0xFF1E2536), 0.72)
      : lightMode
          ? const Color(0xFFEAEEF5)
          : const Color(0xFF1E2536);
  static Color get noneBorder => lightMode && !customBg ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  static Color get doneFill => customBg
      ? _t(const Color(0xFF14321F), 0.88)
      : lightMode
          ? const Color(0xFFDDF5E6)
          : const Color(0xFF14321F);
  static Color get doneText => lightMode && !customBg ? const Color(0xFF15803D) : const Color(0xFFBBF7D0);
  static Color get doneBorder => const Color(0xFF22C55E);
  static Color get cancelFill => customBg
      ? _t(const Color(0xFF3A1520), 0.88)
      : lightMode
          ? const Color(0xFFFDE3E8)
          : const Color(0xFF3A1520);
  static Color get cancelText => lightMode && !customBg ? const Color(0xFFBE123C) : const Color(0xFFFECDD3);
  static Color get cancelBorder => const Color(0xFFF43F5E);
  static Color get inProgressFill => customBg
      ? _t(const Color(0xFF2A2416), 0.88)
      : lightMode
          ? const Color(0xFFFEF3D7)
          : const Color(0xFF2A2416);
  static Color get inProgressText => lightMode && !customBg ? const Color(0xFFB45309) : const Color(0xFFFDE68A);
  static Color get inProgressBorder => const Color(0xFFF59E0B);
  static Color get purpleFill => customBg
      ? _t(const Color(0xFF251536), 0.88)
      : lightMode
          ? const Color(0xFFEDE4FB)
          : const Color(0xFF251536);
  static Color get purpleText => lightMode && !customBg ? const Color(0xFF6D28D9) : const Color(0xFFC4B5FD);
  static Color get purpleBorder => lightMode && !customBg ? const Color(0xFF8B5CB6) : const Color(0xFF7C3AED);
}
