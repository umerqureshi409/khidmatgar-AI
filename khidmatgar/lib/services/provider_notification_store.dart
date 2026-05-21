import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local persistent store for provider notifications.
///
/// Written to whenever:
///   • A booking is confirmed (NEW_BOOKING)
///   • A job is marked completed (JOB_COMPLETED)
///   • A rating is received (RATING_RECEIVED)
///
/// Read by ProviderNotificationsScreen as the primary source
/// (backend notifications merged in as secondary).
class ProviderNotificationStore {
  static final ProviderNotificationStore instance =
      ProviderNotificationStore._();
  ProviderNotificationStore._();

  static const _key = 'kg_provider_notifications_v1';

  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount =>
      _notifications.where((n) => n['read'] == false).length;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _notifications = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}
  }

  Future<void> addNotification(Map<String, dynamic> notif) async {
    // Avoid duplicates by booking_id + type
    final bookingId = notif['booking_id']?.toString() ?? '';
    final type = notif['type']?.toString() ?? '';
    if (bookingId.isNotEmpty &&
        _notifications.any((n) =>
            n['booking_id'] == bookingId && n['type'] == type)) {
      return; // already stored
    }

    final entry = {
      'id': 'pn_${DateTime.now().millisecondsSinceEpoch}',
      ...notif,
      'read': false,
      'timestamp': notif['timestamp'] ?? DateTime.now().toIso8601String(),
    };

    _notifications.insert(0, entry);

    // Keep last 100 notifications
    if (_notifications.length > 100) {
      _notifications = _notifications.take(100).toList();
    }

    await _persist();
  }

  Future<void> markRead(String notifId) async {
    final idx = _notifications.indexWhere((n) => n['id'] == notifId);
    if (idx != -1) {
      _notifications[idx] = {..._notifications[idx], 'read': true};
      await _persist();
    }
  }

  Future<void> markAllRead() async {
    _notifications = _notifications
        .map((n) => {...n, 'read': true})
        .toList();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_notifications));
    } catch (_) {}
  }

  Future<void> clear() async {
    _notifications = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
