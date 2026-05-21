import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/antigravity_service.dart';
import 'provider_dashboard.dart';

/// ProviderRegistrationScreen
/// Captures provider profile on first launch:
///   - Full name
///   - Company / business name
///   - Services offered (multi-select)
///   - Phone number
///   - Years of experience
///   - Live GPS location (with permission prompt + manual fallback)
/// Persists to SharedPreferences so ProviderDashboard can read it.

class ProviderRegistrationScreen extends StatefulWidget {
  const ProviderRegistrationScreen({super.key});

  @override
  State<ProviderRegistrationScreen> createState() =>
      _ProviderRegistrationScreenState();
}

class _ProviderRegistrationScreenState
    extends State<ProviderRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController(text: '1');
  final _manualAreaCtrl = TextEditingController();

  bool _isLocating = false;
  bool _locationCaptured = false;
  double? _lat;
  double? _lng;
  String _locationLabel = '';
  bool _isSaving = false;

  // Available services — match backend service_type values
  static const _allServices = [
    {'key': 'AC_TECHNICIAN', 'label': 'AC Technician', 'icon': '❄️'},
    {'key': 'ELECTRICIAN', 'label': 'Electrician', 'icon': '⚡'},
    {'key': 'PLUMBER', 'label': 'Plumber', 'icon': '🔧'},
    {'key': 'CARPENTER', 'label': 'Carpenter', 'icon': '🪚'},
    {'key': 'PAINTER', 'label': 'Painter', 'icon': '🎨'},
    {'key': 'CLEANER', 'label': 'Cleaner / Maid', 'icon': '🧹'},
    {'key': 'PEST_CONTROL', 'label': 'Pest Control', 'icon': '🐛'},
    {'key': 'APPLIANCE_REPAIR', 'label': 'Appliance Repair', 'icon': '🔌'},
    {'key': 'MECHANIC', 'label': 'Mechanic', 'icon': '🚗'},
    {'key': 'GARDENER', 'label': 'Gardener', 'icon': '🌿'},
    {'key': 'TUTOR', 'label': 'Tutor', 'icon': '📚'},
    {'key': 'COOK', 'label': 'Cook / Chef', 'icon': '👨‍🍳'},
    {'key': 'BEAUTY_SERVICES', 'label': 'Beauty Services', 'icon': '💄'},
    {'key': 'DRIVER', 'label': 'Driver', 'icon': '🚙'},
    {'key': 'SECURITY_GUARD', 'label': 'Security Guard', 'icon': '🛡️'},
  ];

  final Set<String> _selectedServices = {};

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    _experienceCtrl.dispose();
    _manualAreaCtrl.dispose();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _captureLocation() async {
    setState(() => _isLocating = true);

    try {
      // Check service
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationError(
          'Location services are turned OFF on this device.',
          showSettings: true,
        );
        return;
      }

      // Check / request permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationError(
          'Location permission denied. Your live location is needed to show you nearby job requests.',
          showSettings: permission == LocationPermission.deniedForever,
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _locationCaptured = true;
        _locationLabel =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      });
    } catch (e) {
      _showLocationError('Could not get location: $e');
    } finally {
      setState(() => _isLocating = false);
    }
  }

  void _showLocationError(String msg, {bool showSettings = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardNavy,
        title: Text('Location Error',
            style: GoogleFonts.outfit(color: Colors.white)),
        content: Text(msg,
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          if (showSettings)
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.pop(context);
              },
              child: const Text('Open Settings',
                  style: TextStyle(color: AppTheme.primaryNeon)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK',
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  // ── Save & Continue ───────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one service you offer.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (!_locationCaptured && _manualAreaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please capture your live location OR enter your area manually.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final profile = {
      'provider_name': _nameCtrl.text.trim(),
      'company_name': _companyCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'experience_years': int.tryParse(_experienceCtrl.text) ?? 1,
      'services': _selectedServices.toList(),
      'lat': _lat,
      'lng': _lng,
      'manual_area': _manualAreaCtrl.text.trim(),
      'location_captured': _locationCaptured,
      'registered_at': DateTime.now().toIso8601String(),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_profile', jsonEncode(profile));
    await prefs.setBool('provider_registered', true);

    // POST to backend so KHOJI can see the new provider immediately
    await AntigravityService.instance.registerProvider(profile);

    if (!mounted) return;
    setState(() => _isSaving = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ProviderDashboard()),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.cardNavy,
        title: Text('Provider Registration',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _sectionHeader('Personal Information'),
            const SizedBox(height: 12),
            _field(
              controller: _nameCtrl,
              label: 'Full Name *',
              hint: 'e.g. Muhammad Ali',
              icon: Icons.person_rounded,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _companyCtrl,
              label: 'Company / Business Name',
              hint: 'e.g. Ali AC Services (or leave blank)',
              icon: Icons.business_rounded,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _phoneCtrl,
              label: 'Phone Number *',
              hint: '+92-3XX-XXXXXXX',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Phone number is required';
                }
                if (v.trim().length < 10) return 'Enter a valid phone number';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _field(
              controller: _experienceCtrl,
              label: 'Years of Experience *',
              hint: 'e.g. 5',
              icon: Icons.star_rounded,
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 0) return 'Enter valid years';
                return null;
              },
            ),

            const SizedBox(height: 24),
            _sectionHeader('Services You Offer *'),
            const SizedBox(height: 4),
            Text(
              'Select all that apply',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allServices.map((s) {
                final key = s['key']!;
                final selected = _selectedServices.contains(key);
                return FilterChip(
                  label: Text('${s['icon']} ${s['label']}'),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedServices.add(key);
                      } else {
                        _selectedServices.remove(key);
                      }
                    });
                  },
                  backgroundColor: AppTheme.cardNavy,
                  selectedColor: AppTheme.primaryNeon.withOpacity(0.2),
                  checkmarkColor: AppTheme.primaryNeon,
                  labelStyle: TextStyle(
                    color: selected ? AppTheme.primaryNeon : Colors.white70,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                    color: selected
                        ? AppTheme.primaryNeon
                        : Colors.white24,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
            _sectionHeader('Your Location'),
            const SizedBox(height: 4),
            Text(
              'Live location helps clients track you in real-time and enables accurate ETA calculation.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),

            // Live location button
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: _locationCaptured
                    ? Colors.green.withOpacity(0.1)
                    : AppTheme.primaryNeon.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _locationCaptured
                      ? Colors.green
                      : AppTheme.primaryNeon.withOpacity(0.4),
                ),
              ),
              child: ListTile(
                leading: Icon(
                  _locationCaptured
                      ? Icons.check_circle_rounded
                      : Icons.my_location_rounded,
                  color: _locationCaptured
                      ? Colors.green
                      : AppTheme.primaryNeon,
                ),
                title: Text(
                  _locationCaptured
                      ? 'Location Captured ✓'
                      : 'Capture My Live Location',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _locationCaptured
                      ? _locationLabel
                      : 'Tap to use GPS — required for live tracking',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                trailing: _isLocating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryNeon,
                        ),
                      )
                    : TextButton(
                        onPressed: _captureLocation,
                        child: Text(
                          _locationCaptured ? 'Re-capture' : 'Capture',
                          style: const TextStyle(
                              color: AppTheme.primaryNeon),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),
            Text(
              'OR enter area manually (if GPS is unavailable)',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            _field(
              controller: _manualAreaCtrl,
              label: 'Area / Sector / Neighborhood',
              hint: 'e.g. G-11 Islamabad, DHA Karachi, Gulberg Lahore',
              icon: Icons.location_on_rounded,
            ),

            const SizedBox(height: 36),

            SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNeon,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.black87)
                    : Text(
                        'Complete Registration & Start',
                        style: GoogleFonts.outfit(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        color: AppTheme.primaryNeon,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        prefixIcon: Icon(icon, color: AppTheme.primaryNeon, size: 20),
        filled: true,
        fillColor: AppTheme.cardNavy,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryNeon),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}
