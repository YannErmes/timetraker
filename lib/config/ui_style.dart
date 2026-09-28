import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';
import '../services/supabase_service.dart';

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

/// The Custom-theme background as the rest of the app needs it.
class CustomBgValue {
  final Uint8List? bytes;
  final double brightness;
  /// True when this came out of the cloud rather than this device's cache.
  final bool fromCloud;
  /// When the photo was saved, compared against the cloud copy's timestamp.
  final DateTime? savedAt;
  const CustomBgValue({this.bytes, required this.brightness, this.fromCloud = false, this.savedAt});
}

/// Device-level custom background image (shared by all users on the device).
///
/// The photo itself is also kept in the cloud (one `user_settings` row per
/// user) so it follows a customer to another device. This device's copy is a
/// cache: it is what makes the theme instant on launch and what still works
/// offline.
class CustomBg {
  static const imageKey = 'custom_bg_image_b64';
  static const brightnessKey = 'custom_bg_brightness';
  static const defaultBrightness = 0.55;

  /// When this device last saved the photo, and which user it belongs to. The
  /// user id is stored too: signing in as somebody else on a shared computer
  /// must not show the previous person's picture.
  static const savedAtKey = 'custom_bg_saved_at';
  static const ownerKey = 'custom_bg_owner_id';

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

  // --- Cloud copy: the photo follows the customer across devices ------------

  /// Resolves the background for the signed-in user, newest copy wins.
  ///
  /// Cloud wins when it holds a photo that is newer than this device's, or
  /// when this device has no photo at all (first sign-in on a new computer).
  /// The local photo is uploaded when the cloud has none — that is how the
  /// picture of a customer who only ever used this device gets into the cloud
  /// in the first place.
  static Future<CustomBgValue> resolveForUser(SupabaseService svc) async {
    final userId = svc.userId;
    final local = await _readLocal(userId);
    final cloud = await svc.fetchUserSettings();

    // Nobody signed in, or the cloud is unreachable: the device copy is all
    // we have and it is still better than an empty theme.
    if (userId == null || !svc.isConfigured) return local;

    final localAt = local.savedAt;
    final cloudAt = cloud?.updatedAt;
    final cloudIsNewer = cloud != null &&
        cloud.hasPhoto &&
        (localAt == null || local.bytes == null || (cloudAt != null && cloudAt.isAfter(localAt)));

    if (cloudIsNewer) {
      final remote = cloud;
      final encoded = remote!.backgroundB64;
      final bytes = _decode(encoded!);
      if (bytes != null) {
        // Cache it: next launch is instant and works offline.
        _cache = bytes;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(imageKey, encoded);
          await prefs.setString(savedAtKey, cloudAt!.toIso8601String());
          await prefs.setString(ownerKey, userId);
          final b = remote.brightness;
          if (b != null) await prefs.setDouble(brightnessKey, b.clamp(0.15, 1.0));
        } catch (_) {}
        return CustomBgValue(
          bytes: bytes,
          brightness: remote.brightness?.clamp(0.15, 1.0) ?? local.brightness,
          fromCloud: true,
        );
      }
    }

    // This device holds a photo the cloud has never seen (or an older one).
    if (local.bytes != null && (cloud == null || !cloud.hasPhoto || (cloudAt == null || local.savedAt!.isAfter(cloudAt)))) {
      await svc.saveUserBackground(base64Encode(local.bytes!));
    } else if (local.bytes == null && cloud != null && !cloud.hasPhoto && cloud.brightness != null) {
      // Nothing to upload, but keep the dimming in step across devices.
      await svc.saveUserBrightness(cloud.brightness!);
    }
    return local;
  }

  /// Saves the photo on this device and in the cloud. Returns false only when
  /// the *device* refused the write; a failed upload is retried on next launch
  /// by [resolveForUser] and must not scare the customer.
  static Future<bool> saveForUser(SupabaseService svc, Uint8List bytes) async {
    final ok = await save(bytes);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(savedAtKey, DateTime.now().toUtc().toIso8601String());
      await prefs.setString(ownerKey, svc.userId ?? '');
    } catch (_) {}
    if (svc.userId != null && svc.isConfigured) {
      await svc.saveUserBackground(base64Encode(bytes));
    }
    return ok;
  }

  static Future<void> saveBrightnessForUser(SupabaseService svc, double v) async {
    await saveBrightness(v);
    if (svc.userId != null && svc.isConfigured) await svc.saveUserBrightness(v);
  }

  /// Removes the photo here and in the cloud, so it does not come back on the
  /// next sign-in from another device.
  static Future<void> clearForUser(SupabaseService svc) async {
    await clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(savedAtKey);
      await prefs.remove(ownerKey);
    } catch (_) {}
    if (svc.userId != null && svc.isConfigured) await svc.clearUserSettings();
  }

  /// The device copy, ignoring the cloud. A photo saved for a different user
  /// is ignored on a shared computer, so signing in does not show the
  /// previous person's picture.
  static Future<CustomBgValue> _readLocal(String? userId) async {
    double brightness = defaultBrightness;
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getDouble(brightnessKey);
      if (v != null) brightness = v.clamp(0.15, 1.0);
      final owner = prefs.getString(ownerKey);
      final s = prefs.getString(imageKey);
      if (s == null || s.isEmpty) return CustomBgValue(brightness: brightness);
      // An ownerless photo predates per-user backgrounds: keep showing it.
      if (owner != null && owner.isNotEmpty && userId != null && owner != userId) {
        return CustomBgValue(brightness: brightness);
      }
      final bytes = _decode(s);
      _cache = bytes;
      return CustomBgValue(
        bytes: bytes,
        brightness: brightness,
        fromCloud: false,
        savedAt: DateTime.tryParse(prefs.getString(savedAtKey) ?? '')?.toUtc(),
      );
    } catch (e) {
      debugPrint('custom bg load failed: $e');
      return CustomBgValue(bytes: _cache, brightness: brightness);
    }
  }

  static Uint8List? _decode(String b64) {
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }
}
