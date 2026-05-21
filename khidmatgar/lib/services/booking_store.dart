import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent local booking store — survives app restarts.
/// All bookings confirmed in chat are written here immediately.
class BookingStore {
  static final BookingStore instance = BookingStore._();
  BookingStore._();

  static const _key = 'kg_bookings_v2';

  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> get bookings => List.unmodifiable(_bookings);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _bookings = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
  }

  Future<void> addBooking(Map<String, dynamic> booking) async {
    // Avoid duplicates by booking_id
    final id = booking['booking_id']?.toString() ?? '';
    if (id.isNotEmpty && _bookings.any((b) => b['booking_id'] == id)) return;
    _bookings.insert(0, Map<String, dynamic>.from(booking));
    await _persist();
  }

  Future<void> updateStatus(String bookingId, String status) async {
    final idx = _bookings.indexWhere((b) => b['booking_id'] == bookingId);
    if (idx != -1) {
      _bookings[idx] = {..._bookings[idx], 'status': status};
      await _persist();
    }
  }

  Future<void> markRated(String bookingId, double rating) async {
    final idx = _bookings.indexWhere((b) => b['booking_id'] == bookingId);
    if (idx != -1) {
      _bookings[idx] = {..._bookings[idx], 'user_rating': rating, 'is_rated': true};
      await _persist();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_bookings));
    } catch (_) {}
  }

  /// Clear all (for logout)
  Future<void> clear() async {
    _bookings = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}