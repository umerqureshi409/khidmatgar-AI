import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/antigravity_service.dart';

/// MapViewScreen — v2 (production-ready)
///
/// Fixes from v1:
/// 1. Uses REAL client GPS (via Geolocator) instead of lat-0.01 offset hack
/// 2. Polls backend for live provider location every 4 seconds
/// 3. Draws real polyline route between client and provider (direct for now;
///    swap _buildDirectRoute for Directions API call when key is available)
/// 4. Computes Haversine distance + ETA dynamically as both move
/// 5. Shows distance and ETA on the bottom info card in real-time
/// 6. Graceful fallback if GPS unavailable

class MapViewScreen extends StatefulWidget {
  final Map<String, dynamic> booking;

  const MapViewScreen({super.key, required this.booking});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  final Completer<GoogleMapController> _mapCtrl = Completer();

  // Positions
  LatLng? _clientPos;       // real GPS
  LatLng? _providerPos;     // from backend live location OR booking coords
  bool _clientLocated = false;
  bool _providerLocated = false;

  // Map state
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  double _distanceKm = 0;
  int _etaMinutes = 0;

  // Streams & timers
  StreamSubscription<Position>? _clientPosSub;
  Timer? _providerPollTimer;

  // Booking data
  String get _providerName =>
      widget.booking['provider_name']?.toString() ?? 'Provider';
  String get _providerId =>
      widget.booking['provider_id']?.toString() ?? '';
  String get _bookingId =>
      widget.booking['booking_id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _initClientLocation();
    _initProviderLocation();
  }

  @override
  void dispose() {
    _clientPosSub?.cancel();
    _providerPollTimer?.cancel();
    super.dispose();
  }

  // ── Client Location ───────────────────────────────────────────────────────

  Future<void> _initClientLocation() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _fallbackClientLocation();
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _fallbackClientLocation();
        return;
      }

      // Initial fix
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10)),
      );
      _updateClientPos(LatLng(pos.latitude, pos.longitude));

      // Continuous stream
      _clientPosSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((p) => _updateClientPos(LatLng(p.latitude, p.longitude)));
    } catch (_) {
      _fallbackClientLocation();
    }
  }

  void _fallbackClientLocation() {
    // Use booking location if client GPS is unavailable
    final coords = widget.booking['location']?['client_coordinates'];
    if (coords != null) {
      _updateClientPos(LatLng(
        (coords['lat'] as num).toDouble(),
        (coords['lng'] as num).toDouble(),
      ));
    }
    // If booking also has no client coords, provider side sets center
  }

  void _updateClientPos(LatLng pos) {
    if (!mounted) return;
    setState(() {
      _clientPos = pos;
      _clientLocated = true;
    });
    _rebuildMap();
  }

  // ── Provider Location ─────────────────────────────────────────────────────

  void _initProviderLocation() {
    // Seed from booking coordinates
    final coords = widget.booking['location']?['provider_coordinates'];
    if (coords != null && coords['lat'] != null) {
      _updateProviderPos(LatLng(
        (coords['lat'] as num).toDouble(),
        (coords['lng'] as num).toDouble(),
      ));
    }

    // Poll live location from backend every 4 seconds
    _providerPollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _pollProviderLocation(),
    );
    _pollProviderLocation(); // Immediate first call
  }

  Future<void> _pollProviderLocation() async {
    if (_providerId.isEmpty) return;
    try {
      final baseUrl = await AntigravityService.instance.getBaseUrl();
      final res = await http
          .get(Uri.parse('$baseUrl/provider/location/$_providerId'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          _updateProviderPos(LatLng(lat, lng));
        }
      }
    } catch (_) {
      // Provider location endpoint may not exist yet — keep last known
    }
  }

  void _updateProviderPos(LatLng pos) {
    if (!mounted) return;
    setState(() {
      _providerPos = pos;
      _providerLocated = true;
    });
    _rebuildMap();
  }

  // ── Map Rebuild ───────────────────────────────────────────────────────────

  void _rebuildMap() {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    if (_clientPos != null) {
      markers.add(Marker(
        markerId: const MarkerId('client'),
        position: _clientPos!,
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }

    if (_providerPos != null) {
      markers.add(Marker(
        markerId: const MarkerId('provider'),
        position: _providerPos!,
        infoWindow: InfoWindow(title: _providerName),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
    }

    if (_clientPos != null && _providerPos != null) {
      // Direct-line route (replace with Directions API for roads)
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: [_providerPos!, _clientPos!],
        color: AppTheme.primaryNeon,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));

      // Compute distance & ETA
      _distanceKm = _haversine(
        _clientPos!.latitude,
        _clientPos!.longitude,
        _providerPos!.latitude,
        _providerPos!.longitude,
      );
      // 30 km/h city average
      _etaMinutes = ((_distanceKm / 30) * 60).round().clamp(2, 120);

      // Fit camera to both points
      _fitCamera([_clientPos!, _providerPos!]);
    } else {
      final single = _clientPos ?? _providerPos;
      if (single != null) {
        _mapCtrl.future.then((c) {
          c.animateCamera(CameraUpdate.newLatLngZoom(single, 15));
        });
      }
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });
  }

  void _fitCamera(List<LatLng> points) {
    _mapCtrl.future.then((c) {
      final sw = LatLng(
        points.map((p) => p.latitude).reduce(math.min),
        points.map((p) => p.longitude).reduce(math.min),
      );
      final ne = LatLng(
        points.map((p) => p.latitude).reduce(math.max),
        points.map((p) => p.longitude).reduce(math.max),
      );
      c.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: sw, northeast: ne),
        80,
      ));
    });
  }

  // ── Haversine ─────────────────────────────────────────────────────────────

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    return r * 2 * math.asin(math.sqrt(a.toDouble()));
  }

  double _rad(double deg) => deg * math.pi / 180;

  // ── Rating Dialog ─────────────────────────────────────────────────────────

  void _showRatingDialog() {
    double rating = 5.0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardNavy,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rate $_providerName',
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            RatingBar.builder(
              initialRating: 5,
              minRating: 1,
              direction: Axis.horizontal,
              itemCount: 5,
              itemSize: 36,
              itemBuilder: (_, __) =>
                  const Icon(Icons.star_rounded, color: Colors.amber),
              onRatingUpdate: (r) => rating = r,
            ),
            const SizedBox(height: 12),
            Text('Your feedback helps improve the platform.',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNeon),
            onPressed: () async {
              Navigator.pop(context);
              await _submitRating(rating);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Submit',
                style: TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRating(double rating) async {
    try {
      final baseUrl = await AntigravityService.instance.getBaseUrl();
      await http.post(
        Uri.parse('$baseUrl/rate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'provider_id': _providerId,
          'rating': rating,
          'booking_id': _bookingId,
        }),
      );
    } catch (_) {}
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bothLocated = _clientLocated && _providerLocated;
    final initialTarget = _providerPos ?? _clientPos ?? const LatLng(33.6844, 73.0479);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.cardNavy,
        title: Text('Tracking $_providerName',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: _showRatingDialog,
            icon: const Icon(Icons.star_rounded,
                color: Colors.amber, size: 18),
            label: const Text('Rate',
                style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Full-screen Map ───────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (c) => _mapCtrl.complete(c),
            myLocationEnabled: _clientLocated,
            myLocationButtonEnabled: _clientLocated,
            zoomControlsEnabled: true,
            mapType: MapType.normal,
          ),

          // ── Bottom Info Card ──────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardNavy,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  top: BorderSide(
                      color: AppTheme.primaryNeon.withOpacity(0.3),
                      width: 1),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNeon.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryNeon,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _providerLocated
                              ? 'Live tracking active'
                              : 'Locating provider...',
                          style: const TextStyle(
                              color: AppTheme.primaryNeon,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Provider name
                  Text(_providerName,
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),

                  // Booking ID
                  Text('Booking: $_bookingId',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),

                  const SizedBox(height: 14),

                  // Distance & ETA stats
                  if (bothLocated)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statTile(
                          Icons.straighten_rounded,
                          '${_distanceKm.toStringAsFixed(1)} km',
                          'Distance',
                        ),
                        Container(
                            width: 1, height: 40, color: Colors.white12),
                        _statTile(
                          Icons.timer_outlined,
                          '$_etaMinutes min',
                          'ETA',
                        ),
                        Container(
                            width: 1, height: 40, color: Colors.white12),
                        _statTile(
                          Icons.speed_rounded,
                          '~30 km/h',
                          'Avg speed',
                        ),
                      ],
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryNeon,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Calculating route...',
                              style: TextStyle(
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),

                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),

          // ── Location status chips ─────────────────────────────────────────
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _locChip(
                    _clientLocated ? Icons.gps_fixed : Icons.gps_off,
                    _clientLocated ? 'Your GPS' : 'GPS pending',
                    _clientLocated ? Colors.green : Colors.orange),
                const SizedBox(width: 8),
                _locChip(
                    _providerLocated
                        ? Icons.person_pin_circle_rounded
                        : Icons.person_search_rounded,
                    _providerLocated
                        ? 'Provider tracked'
                        : 'Provider locating...',
                    _providerLocated ? AppTheme.primaryNeon : Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryNeon, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _locChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
