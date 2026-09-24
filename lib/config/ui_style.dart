import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Shared style tokens: rounded radii + soft neumorphic shadows.
class UiStyle {
  static BorderRadius get rSm => BorderRadius.circular(10);
  static BorderRadius get rMd => BorderRadius.circular(12);
  static BorderRadius get rLg => BorderRadius.circular(16);
  static BorderRadius get rXl => BorderRadius.circular(20);

  /// Gentle neumorphic card shadows: dark depth bottom-right, faint lift
  /// top-left. Works on both themes.
  static List<BoxShadow> neuCard({double blur = 14, double dist = 5}) {
    if (AppColors.lightMode) {
      return [
        BoxShadow(color: const Color(0xFFB9C3D6).withValues(alpha: 0.55), blurRadius: blur, offset: Offset(dist, dist)),
        BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: blur, offset: Offset(-dist, -dist)),
      ];
    }
    return [
      BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: blur, offset: Offset(dist, dist)),
      BoxShadow(color: Colors.white.withValues(alpha: 0.05), blurRadius: blur, offset: Offset(-dist, -dist)),
    ];
  }

  /// iOS-like page switch: fade + gentle scale-up.
  static Widget iosSwitchTransition(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(scale: Tween<double>(begin: 0.97, end: 1.0).animate(curved), child: child),
    );
  }
}
