import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local persistent store for provider performance stats.
///
/// Updated whenever:
///   • A booking is confirmed → recordNewBooking()
///   • A job is completed    → recordJobCompleted()
///   • A rating is received  → recordRating()
///
/// Read by ProviderAnalyticsScreen to show live stats.
class ProviderStatsStore {
  static final ProviderStatsStore instance = ProviderStatsStore._();
  ProviderStatsStore._();

  static const _key = 'kg_provider_stats_v1';

  /// Stats keyed by providerId. Falls back to a shared 'default' bucket.
  Map<String, Map<String, dynamic>> _allStats = {};

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _allStats = decoded.map((k, v) =>
            MapEntry(k, Map<String, dynamic>.from(v as Map)));
      }
    } catch (_) {}
  }

  Map<String, dynamic> _getOrCreate(String providerId) {
    return _allStats.putIfAbsent(providerId, () => _emptyStats());
  }

  Map<String, dynamic> _emptyStats() => {
        'total_bookings': 0,
        'completed_jobs': 0,
        'total_earnings_pkr': 0,
        'ratings': <double>[],
        'average_rating': 0.0,
        'total_ratings': 0,
        'cancellation_rate': 0.0,
        'on_time_percentage': 100.0,
        'last_updated': DateTime.now().toIso8601String(),
      };

  /// Called when a new booking is confirmed.
  Future<void> recordNewBooking({
    required String providerId,
    required int amount,
  }) async {
    final stats = _getOrCreate(providerId);
    stats['total_bookings'] = (stats['total_bookings'] as int? ?? 0) + 1;
    stats['last_updated'] = DateTime.now().toIso8601String();
    await _persist();
  }

  /// Called when a job is marked COMPLETED.
  Future<void> recordJobCompleted({
    required String providerId,
    required int amount,
  }) async {
    final stats = _getOrCreate(providerId);
    stats['completed_jobs'] = (stats['completed_jobs'] as int? ?? 0) + 1;
    stats['total_earnings_pkr'] =
        (stats['total_earnings_pkr'] as int? ?? 0) + amount;

    // Recompute on-time percentage (simple: completed / total * 100)
    final total = stats['total_bookings'] as int? ?? 1;
    final completed = stats['completed_jobs'] as int;
    stats['on_time_percentage'] =
        ((completed / total) * 100).clamp(0.0, 100.0);

    stats['last_updated'] = DateTime.now().toIso8601String();
    await _persist();
  }

  /// Called when a user submits a rating.
  Future<void> recordRating({
    required String providerId,
    required double rating,
  }) async {
    final stats = _getOrCreate(providerId);

    // Maintain rolling list of ratings (last 500)
    final ratings = List<double>.from(
        (stats['ratings'] as List<dynamic>?)?.map((r) => (r as num).toDouble()) ?? []);
    ratings.add(rating);
    if (ratings.length > 500) ratings.removeAt(0);

    stats['ratings'] = ratings;
    stats['total_ratings'] = ratings.length;

    // Recalculate average
    final avg = ratings.reduce((a, b) => a + b) / ratings.length;
    stats['average_rating'] = double.parse(avg.toStringAsFixed(2));

    stats['last_updated'] = DateTime.now().toIso8601String();
    await _persist();
  }

  /// Get stats for a provider. Returns empty stats if none recorded yet.
  Map<String, dynamic> getStats(String providerId) {
    return Map<String, dynamic>.from(
        _allStats[providerId] ?? _emptyStats());
  }

  /// Get stats for the current session's active provider (any provider).
  /// Used by ProviderAnalyticsScreen when provider_id is not known yet.
  Map<String, dynamic> getMergedStats() {
    if (_allStats.isEmpty) return _emptyStats();
    // Merge all provider stats (useful for single-device demo)
    int totalBookings = 0;
    int completedJobs = 0;
    int totalEarnings = 0;
    final allRatings = <double>[];
    for (final s in _allStats.values) {
      totalBookings += (s['total_bookings'] as int? ?? 0);
      completedJobs += (s['completed_jobs'] as int? ?? 0);
      totalEarnings += (s['total_earnings_pkr'] as int? ?? 0);
      allRatings.addAll(
          (s['ratings'] as List<dynamic>?)?.map((r) => (r as num).toDouble()) ??
              []);
    }
    final avgRating = allRatings.isEmpty
        ? 0.0
        : allRatings.reduce((a, b) => a + b) / allRatings.length;
    final onTime = totalBookings == 0
        ? 100.0
        : ((completedJobs / totalBookings) * 100).clamp(0.0, 100.0);

    return {
      'total_bookings': totalBookings,
      'completed_jobs': completedJobs,
      'total_earnings_pkr': totalEarnings,
      'ratings': allRatings,
      'average_rating': double.parse(avgRating.toStringAsFixed(2)),
      'total_ratings': allRatings.length,
      'on_time_percentage': double.parse(onTime.toStringAsFixed(1)),
      'cancellation_rate': 0.0,
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_allStats));
    } catch (_) {}
  }

  Future<void> clear() async {
    _allStats = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
