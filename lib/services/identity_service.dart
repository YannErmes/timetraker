import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_config.dart';

const _kNameKey = 'tracker_name';
const _kIdKey = 'tracker_user_id';
const _uuid = Uuid();

class Identity {
  final String id; // uuid, stable per name
  final String name;
  const Identity({required this.id, required this.name});
}

class IdentityService {
  Identity? _identity;
  Identity? get identity => _identity;
  String? get userId => _identity?.id;
  String? get name => _identity?.name;
  bool get isLoggedIn => _identity != null;

  final _controller = StreamController<Identity?>.broadcast();
  Stream<Identity?> get stream => _controller.stream;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final storedName = prefs.getString(_kNameKey);
    final storedId = prefs.getString(_kIdKey);
    if (storedName != null && storedId != null && storedName.trim().isNotEmpty) {
      _identity = Identity(id: storedId, name: storedName);
      _controller.add(_identity);
      // try to ensure remote record exists (best-effort, no block)
      if (isSupabaseConfigured) {
        unawaited(_ensureRemote(storedName, storedId));
      }
    }
  }

  Future<Identity> signInWithName(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) throw ArgumentError('Name is required');
    // Basic validation: 2-32 chars
    if (name.length < 2) throw ArgumentError('Name must be at least 2 characters');
    if (name.length > 32) throw ArgumentError('Name must be 32 characters or less');

    String id;
    String canonicalName = name; // keep exact typing as the key

    if (isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        // Try to reclaim by exact name
        final existing = await client.from('app_users').select().eq('name', canonicalName).maybeSingle();
        if (existing != null) {
          id = existing['id'] as String;
        } else {
          // create new
          id = _uuid.v4();
          await client.from('app_users').insert({'id': id, 'name': canonicalName});
        }
      } catch (e) {
        // if table missing or offline, fallback to local deterministic id
        debugPrint('identity supabase error: $e');
        // try local reclaim via stored prefs id if same name, else generate
        final prefs = await SharedPreferences.getInstance();
        final storedName = prefs.getString(_kNameKey);
        final storedId = prefs.getString(_kIdKey);
        if (storedName == canonicalName && storedId != null) {
          id = storedId;
        } else {
          id = _uuid.v4();
          // queue for later sync? store and let next online ensureRemote will create
          // we still need to ensure remote eventually, will be retried on next init
        }
        // still persist locally even if remote failed
      }
    } else {
      // Demo / no supabase: try to reclaim locally if same name previously stored, else new id
      final prefs = await SharedPreferences.getInstance();
      final storedName = prefs.getString(_kNameKey);
      final storedId = prefs.getString(_kIdKey);
      if (storedName == canonicalName && storedId != null) {
        id = storedId;
      } else {
        id = _uuid.v4();
      }
    }

    final ident = Identity(id: id, name: canonicalName);
    _identity = ident;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNameKey, canonicalName);
    await prefs.setString(_kIdKey, id);
    _controller.add(ident);

    if (isSupabaseConfigured) {
      unawaited(_ensureRemote(canonicalName, id));
    }
    return ident;
  }

  Future<void> signOut() async {
    // clear local identity; data remains on server under that name/id for reclaim
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kNameKey);
    await prefs.remove(_kIdKey);
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
