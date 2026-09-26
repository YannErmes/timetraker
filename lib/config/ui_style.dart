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

  /// Browsers cap localStorage per origin (~5 MB) and a base64 JPEG easily
  /// doubles the payload, so we keep the encoded string well under 2.8 MB.
  static const maxBase64Chars = 2800000;

  /// Last known good bytes: keeps the theme working for this session even if
  /// the device refuses to persist the payload.
  static Uint8List? _cache;

  /// Let the user pick an image (PC file dialog / mobile gallery),
  /// downscaled so it stays small enough for local storage.
  static Future<Uint8List?> pick() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return null;
      final raw = await picked.readAsBytes();
      return compress(raw);
    } catch (e) {
      debugPrint('custom bg pick failed: $e');
      return null;
    }
  }

  /// Re-encode to JPEG, shrinking quality/size in steps until the base64
  /// payload is small enough for local storage on any platform.
  static Uint8List? compress(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      for (final step in const [(1600, 78), (1440, 70), (1200, 60), (1000, 50), (800, 42)]) {
        final resized = decoded.width > step.$1 ? img.copyResize(decoded, width: step.$1) : decoded;
        final out = img.encodeJpg(resized, quality: step.$2);
        if (out.isEmpty) continue;
        if (base64Encode(out).length <= maxBase64Chars) return Uint8List.fromList(out);
      }
      return null;
    } catch (e) {
      debugPrint('custom bg compress failed: $e');
      return null;
    }
  }

  static Future<Uint8List?> load() async {
    try {
      final s = (await SharedPreferences.getInstance()).getString(imageKey);
      if (s == null || s.isEmpty) return null;
      final bytes = base64Decode(s);
      _cache = bytes;
      return bytes;
    } catch (e) {
      debugPrint('custom bg load failed: $e');
      return _cache;
    }
  }

  /// Persist the image. Returns false when the device rejected the write
  /// (e.g. storage quota) so the caller can tell the user.
  static Future<bool> save(Uint8List bytes) async {
    _cache = bytes;
    final encoded = base64Encode(bytes);
    try {
      final prefs = await SharedPreferences.getInstance();
      final ok = await prefs.setString(imageKey, encoded);
      if (!ok) {
        debugPrint('custom bg save rejected (${encoded.length} chars)');
        return false;
      }
      // Read back: a silent no-op write is worse than an explicit failure.
      if ((prefs.getString(imageKey) ?? '').length != encoded.length) {
        debugPrint('custom bg save did not persist');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('custom bg save failed: $e');
      return false;
    }
  }

  static Future<void> clear() async {
    _cache = null;
    try {
      await (await SharedPreferences.getInstance()).remove(imageKey);
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
