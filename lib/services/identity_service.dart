import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_config.dart';

const _kNameKey = 'tracker_name'; // kept for backward compat, now stores email
const _kEmailKey = 'tracker_email';
const _kIdKey = 'tracker_user_id';
const _kVipKey = 'tracker_vip_key';
const _uuid = Uuid();

class Identity {
  final String id; // uuid, stable per email
  final String name; // email (kept as name for compat)
  final String? vipKey;
  final bool isVip;
  const Identity({required this.id, required this.name, this.vipKey, this.isVip = false});
  String get email => name;
}

bool isValidVipKey(String key) {
  final s = key.toLowerCase().trim();
  if (s.isEmpty) return false;
  final yIdx = s.indexOf('y');
  if (yIdx == -1) return false;
  // no 'a' before the y used for the sequence
  if (s.substring(0, yIdx).contains('a')) return false;
  final aIdx = s.indexOf('a', yIdx + 1);
  if (aIdx == -1) return false;
  final n1 = s.indexOf('n', aIdx + 1);
  if (n1 == -1) return false;
  final n2 = s.indexOf('n', n1 + 1);
  if (n2 == -1) return false;
  return true;
}

class IdentityService {
  Identity? _identity;
  Identity? get identity => _identity;
  String? get userId => _identity?.id;
  String? get name => _identity?.name; // email stored as name for compat
  String? get email => _identity?.name;
  bool get isLoggedIn => _identity != null;
  bool get isVipUnlocked => _identity?.isVip ?? false;
  String? get vipKey => _identity?.vipKey;

  final _controller = StreamController<Identity?>.broadcast();
  Stream<Identity?> get stream => _controller.stream;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // support both old _kNameKey and new _kEmailKey (email is now the identity)
    final storedEmail = prefs.getString(_kEmailKey) ?? prefs.getString(_kNameKey);
    final storedId = prefs.getString(_kIdKey);
    final storedVip = prefs.getString(_kVipKey);
    final isVip = storedVip != null && isValidVipKey(storedVip);
    if (storedEmail != null && storedId != null && storedEmail.trim().isNotEmpty) {
      _identity = Identity(id: storedId, name: storedEmail, vipKey: storedVip, isVip: isVip);
      _controller.add(_identity);
      if (isSupabaseConfigured) {
        unawaited(_ensureRemote(storedEmail, storedId));
      }
    }
  }

  // email + optional vip
  Future<Identity> signInWithEmail(String rawEmail, {String? vipKey}) async {
    final email = rawEmail.trim();
    if (email.isEmpty) throw ArgumentError('Email is required');
    if (!email.contains('@') || !email.contains('.')) throw ArgumentError('Enter a valid email address');
    if (vipKey != null && vipKey.trim().isNotEmpty && !isValidVipKey(vipKey.trim())) {
      throw ArgumentError('Invalid VIP key');
    }
    return signInWithName(email, vipKey: vipKey);
  }

  Future<Identity> signInWithName(String rawName, {String? vipKey}) async {
    final name = rawName.trim();
    if (name.isEmpty) throw ArgumentError('Email is required');
    // allow email format, but keep old 2-64 validation for backward compat
    if (name.length < 3) throw ArgumentError('Enter a valid email');
    if (name.length > 64) throw ArgumentError('Email must be 64 characters or less');

    String id;
    String canonicalName = name; // keep exact typing as the key (email case-sensitive per spec)
    final normalizedVip = vipKey?.trim();
    final vipValid = normalizedVip != null && normalizedVip.isNotEmpty && isValidVipKey(normalizedVip);

    if (isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        final existing = await client.from('app_users').select().eq('name', canonicalName).maybeSingle();
        if (existing != null) {
          id = existing['id'] as String;
        } else {
          id = _uuid.v4();
          await client.from('app_users').insert({'id': id, 'name': canonicalName});
        }
      } catch (e) {
        debugPrint('identity supabase error: $e');
        final prefs = await SharedPreferences.getInstance();
        final storedName = prefs.getString(_kEmailKey) ?? prefs.getString(_kNameKey);
        final storedId = prefs.getString(_kIdKey);
        if (storedName == canonicalName && storedId != null) {
          id = storedId;
        } else {
          id = _uuid.v4();
        }
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final storedName = prefs.getString(_kEmailKey) ?? prefs.getString(_kNameKey);
      final storedId = prefs.getString(_kIdKey);
      if (storedName == canonicalName && storedId != null) {
        id = storedId;
      } else {
        id = _uuid.v4();
      }
    }

    final ident = Identity(id: id, name: canonicalName, vipKey: normalizedVip, isVip: vipValid);
    _identity = ident;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEmailKey, canonicalName);
    await prefs.setString(_kNameKey, canonicalName); // keep for compat
    await prefs.setString(_kIdKey, id);
    if (normalizedVip != null) {
      await prefs.setString(_kVipKey, normalizedVip);
    } else {
      // keep existing vip if not provided? For new login without vip, keep null to allow later addition
      // don't remove existing vip unless explicitly cleared
      if (vipKey != null) await prefs.remove(_kVipKey);
    }
    // also store vip valid flag implicitly via isValid check
    _controller.add(ident);

    if (isSupabaseConfigured) {
      unawaited(_ensureRemote(canonicalName, id));
    }
    return ident;
  }

  Future<void> setVipKey(String rawKey) async {
    final key = rawKey.trim();
    if (key.isNotEmpty && !isValidVipKey(key)) {
      throw ArgumentError('Invalid VIP key');
    }
    final prefs = await SharedPreferences.getInstance();
    if (key.isEmpty) {
      await prefs.remove(_kVipKey);
    } else {
      await prefs.setString(_kVipKey, key);
    }
    if (_identity != null) {
      _identity = Identity(id: _identity!.id, name: _identity!.name, vipKey: key.isEmpty ? null : key, isVip: isValidVipKey(key));
      _controller.add(_identity);
    }
  }

  Future<String?> getStoredVipKey() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kVipKey);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kNameKey);
    await prefs.remove(_kEmailKey);
    await prefs.remove(_kIdKey);
    // keep VIP key? The VIP is per-install, not per-user, so keep it. If you want to clear it on sign out, uncomment:
    // await prefs.remove(_kVipKey);
    _identity = null;
    _controller.add(null);
  }

  Future<void> _ensureRemote(String name, String id) async {
    try {
      final client = Supabase.instance.client;
      final existing = await client.from('app_users').select().eq('id', id).maybeSingle();
      if (existing == null) {
        // if id not found but name exists with different id, we already handled reclaim; otherwise insert
        final byName = await client.from('app_users').select().eq('name', name).maybeSingle();
        if (byName == null) {
          await client.from('app_users').insert({'id': id, 'name': name});
        }
      }
    } catch (e) {
      debugPrint('ensureRemote failed: $e');
    }
  }

  void dispose() {
    _controller.close();
  }
}
