import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/antigravity_service.dart';
import '../services/provider_notification_store.dart';

/// Provider Notifications Screen — v2
///
/// Fixes from v1:
/// 1. PRIMARY source: ProviderNotificationStore (local, always populated)
/// 2. SECONDARY source: backend API (merged in if available)
/// 3. "Mark all read" action
/// 4. Correct provider_id lookup (from dashboard's stored profile OR auto-detected)
class ProviderNotificationsScreen extends StatefulWidget {
  const ProviderNotificationsScreen({super.key});

  @override
  State<ProviderNotificationsScreen> createState() =>
      _ProviderNotificationsScreenState();
}

class _ProviderNotificationsScreenState
    extends State<ProviderNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _hasUnread = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    // Ensure local store is loaded
    await ProviderNotificationStore.instance.load();

    // Merge: local first, then try backend
    final localNotifs = List<Map<String, dynamic>>.from(
        ProviderNotificationStore.instance.notifications);

    List<Map<String, dynamic>> backendNotifs = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileStr = prefs.getString('provider_profile');
      if (profileStr != null) {
        final profile = jsonDecode(profileStr) as Map<String, dynamic>;
        // provider_id may be stored directly or needs to be derived
        final providerId = profile['provider_id']?.toString() ??
            profile['_generated_provider_id']?.toString() ?? '';
        if (providerId.isNotEmpty) {
          final baseUrl = await AntigravityService.instance.getBaseUrl();
          final response = await http
              .get(Uri.parse('$baseUrl/provider/notifications/$providerId'))
              .timeout(const Duration(seconds: 5));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final raw = data['notifications'] as List<dynamic>? ?? [];
            backendNotifs = raw
                .map((n) => Map<String, dynamic>.from(n as Map))
                .toList();
          }
        }
      }
    } catch (_) {
      // Backend unavailable — that's fine, we have local store
    }

    // Convert backend notifs to standard format and merge (avoid duplicates)
    final localIds = localNotifs.map((n) => n['id']?.toString() ?? '').toSet();
    for (final bn in backendNotifs) {
      final id = 'backend_${bn['timestamp'] ?? DateTime.now().millisecondsSinceEpoch}';
      if (!localIds.contains(id)) {
        final text = bn['message']?.toString() ?? '';
        String type = 'SYSTEM_UPDATE';
        if (text.toLowerCase().contains('cancel')) type = 'BOOKING_CANCELLED';
        else if (text.toLowerCase().contains('rating')) type = 'RATING_RECEIVED';
        else if (text.toLowerCase().contains('booking') || text.toLowerCase().contains('new job')) type = 'NEW_BOOKING';

        localNotifs.add({
          'id': id,
          'type': type,
          'message': text,
          'timestamp': bn['timestamp'] ?? DateTime.now().toIso8601String(),
          'read': false,
          'source': 'backend',
        });
      }
    }

    // Sort newest first
    localNotifs.sort((a, b) {
      final ta = DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime(2000);
      final tb = DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime(2000);
      return tb.compareTo(ta);
    });

    if (mounted) {
      setState(() {
        _notifications = localNotifs;
        _hasUnread = localNotifs.any((n) => n['read'] == false);
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    await ProviderNotificationStore.instance.markAllRead();
    setState(() {
      _notifications = _notifications.map((n) => {...n, 'read': true}).toList();
      _hasUnread = false;
    });
  }

  Future<void> _markRead(Map<String, dynamic> notif) async {
    final id = notif['id']?.toString() ?? '';
    if (id.isNotEmpty && notif['source'] != 'backend') {
      await ProviderNotificationStore.instance.markRead(id);
    }
    setState(() {
      final idx = _notifications.indexWhere((n) => n['id'] == id);
      if (idx != -1) _notifications[idx] = {..._notifications[idx], 'read': true};
      _hasUnread = _notifications.any((n) => n['read'] == false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['read'] == false).length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppTheme.goldAccent.withOpacity(0.04),
                    AppTheme.backgroundDark,
                  ],
                  radius: 1.2,
                  center: const Alignment(0, -1),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: AppTheme.glassDecoration(borderRadius: 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: AppTheme.textPrimary),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifications',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Bookings, Ratings & Updates',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unreadCount new',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _markAllRead,
                          icon: const Icon(Icons.done_all_rounded,
                              color: AppTheme.primaryNeon, size: 20),
                          tooltip: 'Mark all read',
                        ),
                      ],
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded,
                            color: AppTheme.textSecondary, size: 20),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ),

                // Body
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryNeon))
                      : _notifications.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              color: AppTheme.primaryNeon,
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _notifications.length,
                                itemBuilder: (context, index) {
                                  final notif = _notifications[index];
                                  return _buildNotificationCard(notif, index);
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.4),
          ),
          const SizedBox(height: 20),
          Text(
            'All Caught Up!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Notifications appear here when\nbookings are confirmed or ratings received.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif, int index) {
    final type = notif['type']?.toString() ?? 'SYSTEM_UPDATE';
    final isUnread = notif['read'] == false;
    final message = notif['message']?.toString() ?? '';
    final timestampStr = notif['timestamp']?.toString() ?? '';
    final timestamp = DateTime.tryParse(timestampStr) ?? DateTime.now();

    IconData icon;
    Color color;
    String title;

    switch (type) {
      case 'NEW_BOOKING':
        icon = Icons.work_rounded;
        color = AppTheme.primaryNeon;
        title = 'New Booking';
        break;
      case 'BOOKING_CANCELLED':
        icon = Icons.cancel_rounded;
        color = Colors.redAccent;
        title = 'Booking Cancelled';
        break;
      case 'RATING_RECEIVED':
        icon = Icons.star_rounded;
        color = AppTheme.goldAccent;
        title = 'Rating Received';
        break;
      case 'JOB_COMPLETED':
        icon = Icons.task_alt_rounded;
        color = Colors.greenAccent;
        title = 'Job Completed';
        break;
      default:
        icon = Icons.info_rounded;
        color = AppTheme.primaryNeon;
        title = 'Update';
    }

    // Extract rating if present
    final rating = notif['rating'] != null
        ? (notif['rating'] as num).toDouble()
        : null;
    final amount = notif['amount'] as int?;

    return GestureDetector(
      onTap: () => _markRead(notif),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isUnread ? color.withOpacity(0.08) : AppTheme.cardNavy,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnread ? color.withOpacity(0.4) : Colors.white12,
            width: 1.5,
          ),
          boxShadow: [
            if (isUnread)
              BoxShadow(
                color: color.withOpacity(0.12),
                blurRadius: 12,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (isUnread) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          _formatTime(timestamp),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Rating stars if present
                  if (rating != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) {
                        return Icon(
                          i < rating.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: AppTheme.goldAccent,
                          size: 14,
                        );
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 10),
              Text(
                message,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              if (amount != null && amount > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.goldAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.goldAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.payments_rounded,
                          color: AppTheme.goldAccent, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        'PKR $amount',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppTheme.goldAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      )
          .animate(delay: Duration(milliseconds: index * 50))
          .slideY(begin: 0.1, end: 0, duration: 300.ms)
          .fadeIn(),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
