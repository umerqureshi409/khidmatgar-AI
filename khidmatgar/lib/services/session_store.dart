import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists user session so the app does not lose context on close/minimize.
class SessionStore {
  static final SessionStore instance = SessionStore._();
  SessionStore._();

  static const _userKey = 'kg_user_v1';
  static const _sessionKey = 'kg_session_id_v1';

  // ── User ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_userKey);
      if (raw == null) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user));
    } catch (_) {}
  }

  Future<void> clearUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
    } catch (_) {}
  }

  // ── Session ID ────────────────────────────────────────────────────────────
  Future<String?> loadSessionId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_sessionKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSessionId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, id);
    } catch (_) {}
  }
}