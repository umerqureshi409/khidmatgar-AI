import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../services/antigravity_service.dart';
import '../services/booking_store.dart';
import '../services/notification_service.dart';
import '../services/provider_notification_store.dart';
import '../services/provider_stats_store.dart';
import '../theme/app_theme.dart';

class BookingHistoryScreen extends StatefulWidget {
  final bool isNested;
  const BookingHistoryScreen({super.key, this.isNested = false});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {

  List<Map<String, dynamic>> get _bookings => BookingStore.instance.bookings;

  void _refresh() => setState(() {});

  // ── Cancel ─────────────────────────────────────────────────────────────────
  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final bookingId = booking['booking_id']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Booking?',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        content: Text(
          'Are you sure? The provider will be notified immediately.',
          style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep It', style: GoogleFonts.outfit(color: AppTheme.primaryNeon)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    ) ?? false;
    if (!confirmed) return;

    try {
      // Best-effort backend cancel (ignore error for mock)
      try { await AntigravityService.instance.cancelBooking(bookingId); } catch (_) {}

      await BookingStore.instance.updateStatus(bookingId, 'CANCELLED');

      if (mounted) {
        await NotificationService().showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Booking Cancelled',
          body: 'Your booking #$bookingId has been cancelled.',
        );
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('✓ Booking cancelled'), backgroundColor: Colors.green.shade600),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade600),
        );
      }
    }
  }

  // ── Complete ───────────────────────────────────────────────────────────────
  Future<void> _completeBooking(Map<String, dynamic> booking) async {
    final bookingId = booking['booking_id']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Mark as Completed?',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        content: Text(
          'Confirm that the service has been delivered satisfactorily.',
          style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Not Yet', style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black87),
            child: const Text('Yes, Complete'),
          ),
        ],
      ),
    ) ?? false;
    if (!confirmed) return;

    try {
      try { await AntigravityService.instance.completeBooking(bookingId); } catch (_) {}
      await BookingStore.instance.updateStatus(bookingId, 'COMPLETED');

      // ── UPDATE PROVIDER STATS ──
      final providerId = booking['provider_id']?.toString() ?? '';
      final amount = (booking['pricing']?['estimated_total_pkr'] as num?)?.toInt() ?? 0;
      if (providerId.isNotEmpty) {
        await ProviderStatsStore.instance.recordJobCompleted(
          providerId: providerId,
          amount: amount,
        );
        // Notify provider of completed job
        await ProviderNotificationStore.instance.addNotification({
          'type': 'JOB_COMPLETED',
          'message': 'Job completed: ${(booking['service_type'] ?? 'Service').toString().replaceAll('_', ' ')} '
              '— PKR $amount earned. Booking $bookingId',
          'booking_id': bookingId,
          'provider_id': providerId,
          'amount': amount,
          'timestamp': DateTime.now().toIso8601String(),
          'read': false,
        });
      }

      if (mounted) {
        await NotificationService().showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Service Completed! ✅',
          body: 'Great! ${booking['provider_name'] ?? 'Your provider'} has completed the job.',
        );
        _refresh();

        // YAKEEN follow-up: prompt rating
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Service marked complete. Please rate ${booking['provider_name'] ?? 'the provider'}!'),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Rate Now',
                textColor: AppTheme.goldAccent,
                onPressed: () => _showRatingDialog(booking),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade600),
        );
      }
    }
  }

  // ── Rate ───────────────────────────────────────────────────────────────────
  Future<void> _showRatingDialog(Map<String, dynamic> booking) async {
    double rating = 5.0;
    final reviewController = TextEditingController();
    bool submitted = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.cardNavy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Rate Your Experience',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'How was ${booking['provider_name'] ?? 'the service'}?',
                  style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                RatingBar.builder(
                  initialRating: rating,
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                  itemBuilder: (_, __) =>
                      const Icon(Icons.star_rounded, color: AppTheme.goldAccent),
                  onRatingUpdate: (v) => setS(() => rating = v),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: reviewController,
                  style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Brief review (optional)',
                    hintStyle: GoogleFonts.outfit(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.goldAccent.withOpacity(0.3)),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Skip', style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                submitted = true;
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNeon),
              child: const Text('Submit Rating'),
            ),
          ],
        ),
      ),
    );

    if (!submitted || !context.mounted) return;

    try {
      final providerId = booking['provider_id']?.toString() ?? '';
      final bookingId = booking['booking_id']?.toString() ?? '';

      if (providerId.isNotEmpty) {
        // Submit to backend — backend should notify provider
        try {
          await AntigravityService.instance.rateProvider(
            providerId,
            rating,
            review: reviewController.text.isNotEmpty ? reviewController.text : null,
            bookingId: bookingId,
          );
        } catch (_) {}
      }

      // Persist rating locally
      await BookingStore.instance.markRated(bookingId, rating);

      // ── UPDATE PROVIDER STATS (local store) ──
      await ProviderStatsStore.instance.recordRating(
        providerId: providerId,
        rating: rating,
      );

      // ── PUSH NOTIFICATION TO PROVIDER (local store) ──
      await ProviderNotificationStore.instance.addNotification({
        'type': 'RATING_RECEIVED',
        'message': 'You received a ${rating.toStringAsFixed(1)}★ rating'
            '${reviewController.text.isNotEmpty ? ': "${reviewController.text}"' : '.'}'
            ' — Booking $bookingId',
        'booking_id': bookingId,
        'provider_id': providerId,
        'rating': rating,
        'review': reviewController.text,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      });

      if (mounted) {
        // Notify USER that rating was submitted
        await NotificationService().showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Rating Submitted ⭐',
          body: 'You gave ${booking['provider_name'] ?? 'the provider'} ${rating.toStringAsFixed(1)} stars!',
        );

        // Notify PROVIDER (simulated via notification if same device / real push via backend)
        await Future.delayed(const Duration(milliseconds: 800));
        await NotificationService().showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1,
          title: '📣 Provider Notified',
          body:
              '${booking['provider_name'] ?? 'Provider'} has been notified of your ${rating.toStringAsFixed(1)}★ rating.',
        );

        _refresh();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Rating submitted — ${booking['provider_name']} notified!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting rating: $e'),
              backgroundColor: Colors.red.shade600),
        );
      }
    }

    reviewController.dispose();
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [AppTheme.goldAccent.withOpacity(0.04), AppTheme.backgroundDark],
                radius: 1.2,
                center: const Alignment(0, -1),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            _buildAppBar(context),
            Expanded(
              child: _bookings.isEmpty
                  ? _buildEmptyState()
                  : _buildHistoryList(_bookings),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: AppTheme.glassDecoration(borderRadius: 0),
      child: Row(children: [
        if (!widget.isNested)
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          ),
        if (!widget.isNested) const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Booking History',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          Text('All your KhidmatGar bookings',
              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary)),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.goldAccent.withOpacity(0.1),
            border: Border.all(color: AppTheme.goldAccent.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('${_bookings.length} bookings',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: AppTheme.goldAccent, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 12),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.history_rounded, size: 64, color: AppTheme.textSecondary.withOpacity(0.4)),
        const SizedBox(height: 20),
        Text('No bookings yet',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Text('Confirmed bookings will appear here.',
            style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary)),
      ]),
    );
  }

  Widget _buildHistoryList(List<Map<String, dynamic>> list) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, i) => _buildHistoryCard(list[i], i),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> booking, int index) {
    final status = (booking['status'] ?? 'CONFIRMED').toString().toUpperCase();
    final isCancelled = status == 'CANCELLED';
    final isCompleted = status == 'COMPLETED';
    final isActive = !isCancelled && !isCompleted;
    final isRated = booking['is_rated'] == true;
    final userRating = (booking['user_rating'] as num?)?.toDouble();

    Color statusColor = AppTheme.primaryNeon;
    if (isCancelled) statusColor = Colors.redAccent;
    if (isCompleted) statusColor = Colors.greenAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldAccent.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AppTheme.goldAccent.withOpacity(0.05), blurRadius: 20, spreadRadius: 2)
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted
                    ? Icons.check_circle_rounded
                    : isCancelled
                        ? Icons.cancel_rounded
                        : Icons.schedule_rounded,
                color: statusColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(booking['provider_name'] ?? 'Booking',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Text(
                  '${(booking['service_type'] ?? 'Service').toString().replaceAll('_', ' ')} • ${booking['slot'] ?? ''}',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(status,
                  style: GoogleFonts.outfit(
                      fontSize: 10, color: statusColor,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ]),

          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.05), height: 1),
          const SizedBox(height: 12),

          // Detail chips
          Wrap(
            spacing: 12, runSpacing: 8,
            children: [
              _chip(Icons.tag_rounded, booking['booking_id'] ?? 'N/A', AppTheme.textSecondary),
              _chip(Icons.payments_rounded,
                  'PKR ${booking['pricing']?['estimated_total_pkr'] ?? '—'}', AppTheme.goldAccent),
              _chip(Icons.timer_rounded, '${booking['eta_minutes'] ?? '?'} min', AppTheme.primaryNeon),
            ],
          ),

          // User rating display (if already rated)
          if (isRated && userRating != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.star_rounded, size: 14, color: AppTheme.goldAccent),
              const SizedBox(width: 4),
              Text('You rated: ${userRating.toStringAsFixed(1)} ★',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.goldAccent)),
            ]),
          ],

          // Action buttons
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            // Complete button — only for active bookings
            if (isActive)
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _completeBooking(booking),
              ),

            // Cancel button — only for active bookings
            if (isActive)
              ElevatedButton.icon(
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Cancel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _cancelBooking(booking),
              ),

            // Rate button — only after completion and not yet rated
            if (isCompleted && !isRated)
              ElevatedButton.icon(
                icon: const Icon(Icons.star_outline_rounded, size: 16),
                label: const Text('Rate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.goldAccent,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showRatingDialog(booking),
              ),
          ]),
        ]),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 60))
        .slideY(begin: 0.1, end: 0, duration: 300.ms)
        .fadeIn();
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label,
          style: GoogleFonts.outfit(
              fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
    ]);
  }
}