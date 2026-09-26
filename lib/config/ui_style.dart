import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Device-level custom background image (shared by all users on the device).
class CustomBg {
  static const imageKey = 'custom_bg_image_b64';
  static const brightnessKey = 'custom_bg_brightness';
  static const defaultBrightness = 0.55;

  /// Let the user pick an image (PC file dialog / mobile gallery),
  /// downscaled so it stays small enough for local storage.
  static Future<Uint8List?> pick() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return null;
      final raw = await picked.readAsBytes();
      return downscale(raw);
    } catch (_) {
      return null;
    }
  }

  /// Downscale to a max width and re-encode as JPEG so it stays small
  /// enough for local storage on any device.
  static Future<Uint8List?> downscale(Uint8List bytes, {int maxWidth = 1600}) async {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final resized = decoded.width > maxWidth ? img.copyResize(decoded, width: maxWidth) : decoded;
      final out = img.encodeJpg(resized, quality: 75);
      if (out.isEmpty) return null;
      return Uint8List.fromList(out);
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> load() async {
    try {
      final s = (await SharedPreferences.getInstance()).getString(imageKey);
      if (s == null || s.isEmpty) return null;
      return base64Decode(s);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(Uint8List bytes) async {
    try {
      (await SharedPreferences.getInstance()).setString(imageKey, base64Encode(bytes));
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      (await SharedPreferences.getInstance()).remove(imageKey);
    } catch (_) {}
  }

  static Future<double> loadBrightness() async {
    try {
      final v = (await SharedPreferences.getInstance()).getDouble(brightnessKey);
      if (v == null) return defaultBrightness;
      return v.clamp(0.15, 1.0);
    } catch (_) {
      return defaultBrightness;
    }
  }

  static Future<void> saveBrightness(double v) async {
    try {
      (await SharedPreferences.getInstance()).setDouble(brightnessKey, v.clamp(0.15, 1.0));
    } catch (_) {}
  }
}
