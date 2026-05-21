import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/agent_trace_model.dart';
import 'session_store.dart';

class AntigravityService {
  static final AntigravityService instance = AntigravityService._internal();
  AntigravityService._internal() {
    _restoreSession();
  }

  static const List<String> _baseUrls = [
    'https://khidmatgar-backend-fgeyfwf2a3hqcneh.southeastasia-01.azurewebsites.net',
    'http://192.168.100.4:8000',
    'http://192.168.1.100:8000',
    'http://10.0.2.2:8000',
    'http://localhost:8000',
  ];

  String? _activeBaseUrl;
  String? _customIp;

  final List<AgentResponse> _history = [];
  List<AgentResponse> get history => List.unmodifiable(_history);

  String _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
  String get sessionId => _sessionId;

  Future<void> _restoreSession() async {
    final saved = await SessionStore.instance.loadSessionId();
    if (saved != null) _sessionId = saved;
  }

  void setCustomIp(String ip) {
    _customIp = 'http://$ip:8000';
    _activeBaseUrl = _customIp;
  }

  Future<String> _getActiveBaseUrl() async {
    if (_activeBaseUrl != null) return _activeBaseUrl!;
    if (_customIp != null) return _customIp!;
    for (final url in _baseUrls) {
      try {
        final response = await http
            .get(Uri.parse('$url/health'))
            .timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) {
          _activeBaseUrl = url;
          return url;
        }
      } catch (_) { continue; }
    }
    _activeBaseUrl = _baseUrls[0];
    return _activeBaseUrl!;
  }

  Future<String> getBaseUrl() async => await _getActiveBaseUrl();

  Future<AgentResponse> processRequest(String userMessage, {double? lat, double? lng}) async {
    String baseUrl;
    try {
      baseUrl = await _getActiveBaseUrl();
    } catch (_) {
      baseUrl = _baseUrls[0];
    }

    final url = '$baseUrl/v1/workflows/khidmatgar-master/run';

    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final Map<String, dynamic> inputs = {
          'user_message': userMessage,
          'session_id': _sessionId,
          'timestamp': DateTime.now().toIso8601String(),
          'platform': 'flutter_mobile',
        };
        if (lat != null && lng != null) {
          inputs['client_lat'] = lat;
          inputs['client_lng'] = lng;
        }

        final response = await http
            .post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'X-Session-ID': _sessionId,
              },
              body: jsonEncode({
                'inputs': inputs,
                'session_id': _sessionId,
                'stream': false,
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final result = AgentResponse.fromJson(data);
          _history.insert(0, result);
          return result;
        } else {
          throw Exception('Server error ${response.statusCode}: ${response.body}');
        }
      } on SocketException {
        if (attempt == 2) {
          _activeBaseUrl = null;
          throw Exception('IP_FALLBACK');
        }
        await Future.delayed(const Duration(milliseconds: 800));
      } on http.ClientException catch (e) {
        if (attempt == 2) throw Exception('Network error: ${e.message}');
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }
    throw Exception('Request failed after 2 attempts');
  }

  Future<bool> checkServerHealth() async {
    try {
      final baseUrl = await _getActiveBaseUrl();
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void resetSession() {
    _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    _activeBaseUrl = null;
    SessionStore.instance.saveSessionId(_sessionId);
  }

  /// NOTE: Bookings are now managed by BookingStore (persistent).
  /// This method kept for legacy provider-dashboard compatibility.
  Future<List<dynamic>> fetchBookings() async {
    try {
      final baseUrl = await _getActiveBaseUrl();
      final response = await http
          .get(Uri.parse('$baseUrl/bookings'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['bookings'] ?? [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> registerProvider(Map<String, dynamic> profile) async {
    try {
      final baseUrl = await _getActiveBaseUrl();
      await http
          .post(
            Uri.parse('$baseUrl/provider/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(profile),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      print('Failed to register provider: $e');
    }
  }

  Future<bool> cancelBooking(String bookingId) async {
    try {
      final baseUrl = await _getActiveBaseUrl();
      final response = await http
          .post(Uri.parse('$baseUrl/bookings/$bookingId/cancel'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
      throw Exception('Failed to cancel booking: ${response.statusCode}');
    } catch (e) {
      print('Error cancelling booking: $e');
      rethrow;
    }
  }

  Future<bool> completeBooking(String bookingId) async {
    try {
      final baseUrl = await _getActiveBaseUrl();
      final response = await http
          .post(Uri.parse('$baseUrl/bookings/$bookingId/complete'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
      // If backend doesn't support it yet, treat as success locally
      return true;
    } catch (_) {
      return true; // Optimistic for offline scenario
    }
  }

  /// Rate a provider — also notifies them via backend
  Future<bool> rateProvider(String providerId, double rating, {
    String? review,
    String? bookingId,
  }) async {
    try {
      final baseUrl = await _getActiveBaseUrl();
      final response = await http
          .post(
            Uri.parse('$baseUrl/rate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'provider_id': providerId,
              'booking_id': bookingId,
              'rating': rating,
              'review': review,
              'notify_provider': true,  // explicit flag for backend
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
      throw Exception('Failed to rate: ${response.statusCode}');
    } catch (e) {
      print('Error rating provider: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getBookingStatus(String bookingId) async {
    try {
      final baseUrl = await _getActiveBaseUrl();
      final response = await http
          .get(Uri.parse('$baseUrl/bookings/$bookingId/status'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> fetchProviderNotifications(
      String providerId) async {
    try {
      final baseUrl = await _getActiveBaseUrl();
      final response = await http
          .get(Uri.parse('$baseUrl/provider/notifications/$providerId'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['notifications'] as List<dynamic>? ?? [];
        return raw.map((n) => Map<String, dynamic>.from(n as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ─── Provider Ranking — distance-weighted scoring ─────────────────────────
  /// Scores a provider considering both quality AND proximity.
  /// A nearby mock provider should rank above a far real provider.
  static double scoreProvider(Map<String, dynamic> p, {double? clientLat, double? clientLng}) {
    final rating = (p['rating'] ?? 3.0).toDouble();           // 0–5
    final distKm = (p['distance_km'] ?? 50.0).toDouble();     // km
    final isMock = p['is_mock'] == true;
    final isVerified = p['verification']?['level'] == 'KHIDMATGAR_VERIFIED';

    // Normalise distance: 0 km → 1.0, 20 km → 0.0 (linear decay, capped)
    final distanceFactor = (1.0 - (distKm / 20.0)).clamp(0.0, 1.0);

    // Composite score: 40% rating + 50% proximity + 10% verified bonus
    double score = (rating / 5.0) * 0.40 +
        distanceFactor * 0.50 +
        (isVerified ? 1.0 : 0.0) * 0.10;

    return score;
  }

  /// Sort a list of providers by composite score (highest first).
  static List<Map<String, dynamic>> rankProviders(
    List<dynamic> providers, {
    double? clientLat,
    double? clientLng,
  }) {
    final list = providers
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
    list.sort((a, b) =>
        scoreProvider(b, clientLat: clientLat, clientLng: clientLng)
            .compareTo(scoreProvider(a, clientLat: clientLat, clientLng: clientLng)));
    return list;
  }
}

// ─── Response Models ──────────────────────────────────────────────────────────

class AgentResponse {
  final String userMessage;
  final String currentAgent;
  final AgentTrace trace;
  final List<dynamic>? providers;
  final dynamic bookingData;
  final String messageType;
  final String? sessionId;
  final int? latencyMs;
  final Map<String, dynamic>? antigravityTrace;

  AgentResponse({
    required this.userMessage,
    required this.currentAgent,
    required this.trace,
    this.providers,
    this.bookingData,
    required this.messageType,
    this.sessionId,
    this.latencyMs,
    this.antigravityTrace,
  });

  factory AgentResponse.fromJson(Map<String, dynamic> json) {
    return AgentResponse(
      userMessage: json['user_message'] ?? '',
      currentAgent: json['current_agent'] ?? 'KhidmatGar',
      trace: AgentTrace.fromJson(json['agent_trace'] ?? {}),
      providers: json['providers'],
      bookingData: json['booking_data'],
      messageType: json['message_type'] ?? 'TEXT',
      sessionId: json['session_id'],
      latencyMs: json['latency_ms'],
      antigravityTrace: json['antigravity_trace'],
    );
  }

  bool get hasBooking => bookingData != null;
  bool get hasProviders => providers != null && providers!.isNotEmpty;
}