import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';
import '../services/antigravity_service.dart';
import '../services/booking_store.dart';
import '../services/notification_service.dart';
import '../services/provider_notification_store.dart';
import '../services/provider_stats_store.dart';
import '../widgets/agent_trace_panel.dart';
import '../widgets/provider_card.dart';
import '../widgets/typing_indicator.dart';
import '../models/agent_trace_model.dart';
import '../providers/auth_provider.dart';
import 'booking_history_screen.dart';
import 'profile_screen.dart';
import 'map_view_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ChatMessage model
// ─────────────────────────────────────────────────────────────────────────────

class ChatMessage {
  final String text;
  final bool isUser;
  final String? agentName;
  final DateTime timestamp;
  final List<dynamic>? providers;
  final dynamic bookingData;
  final String? messageType;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.agentName,
    required this.timestamp,
    this.providers,
    this.bookingData,
    this.messageType,
    this.isError = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// ChatScreen
// ─────────────────────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isProcessing = false;
  bool _showTrace = false;
  AgentTrace? _currentTrace;
  int? _lastLatencyMs;
  bool _serverConnected = false;
  late AnimationController _pulseController;
  String _locationStatus = 'locating';
  Position? _currentPosition;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  Timer? _pollTimer;

  // Tracks pending mock bids (provider_id → mock provider data) so we can
  // de-duplicate and properly confirm them.
  final Map<String, Map<String, dynamic>> _pendingMockBids = {};

  final List<Map<String, String>> _quickSuggestions = [
    {'text': 'AC wala chahiye G-11 mein', 'lang': '🇵🇰'},
    {'text': 'مجھے ابھی پلمبر چاہیے', 'lang': '🇵🇰'},
    {'text': 'Urgent! Pipe burst in DHA Karachi', 'lang': '🚨'},
    {'text': 'Electrician needed F-7 today', 'lang': '🇬🇧'},
    {'text': 'Carpenter chahiye kal subah', 'lang': '🇵🇰'},
    {'text': 'Pest control service Lahore', 'lang': '🇬🇧'},
  ];

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _addWelcomeMessage();
    _checkServerConnection();
    _speech.initialize();
    _startPolling();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Location ────────────────────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationStatus = 'denied');
        _addSystemMessage(
          '📍 Location services are OFF. Enable them for accurate provider matching, '
          'or type your area (e.g. "G-11 Islamabad").',
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        _addSystemMessage(
          '📍 KhidmatGar needs your location to find nearest providers. Please allow when prompted.',
        );
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _locationStatus = 'denied');
        _addSystemMessage(
          '⚠️ Location denied. Mention your area in messages, e.g. "Plumber DHA Karachi mein".',
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _locationStatus = 'granted';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locationStatus = 'denied');
    }
  }

  // ── Server / Polling ────────────────────────────────────────────────────────

  Future<void> _checkServerConnection() async {
    final connected = await AntigravityService.instance.checkServerHealth();
    if (mounted) setState(() => _serverConnected = connected);
    if (!connected) _showIpDialog();
  }

  void _showIpDialog() {
    final ipController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Backend Unreachable',
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ipController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter Server IP (e.g. 192.168.1.5)',
            hintStyle: const TextStyle(color: Colors.grey),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppTheme.primaryNeon),
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (ipController.text.isNotEmpty) {
                AntigravityService.instance
                    .setCustomIp(ipController.text.trim());
                Navigator.pop(context);
                _checkServerConnection();
              }
            },
            child: const Text('Save & Connect',
                style: TextStyle(
                    color: AppTheme.primaryNeon, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!_serverConnected) return;
      try {
        final sessionId = AntigravityService.instance.sessionId;
        final baseUrl = await AntigravityService.instance.getBaseUrl();
        final response = await http.get(
            Uri.parse('$baseUrl/client/sessions/$sessionId/updates'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final updates = data['updates'] as List<dynamic>;
          for (final update in updates) {
            final msg = update['message'] as String;
            if (msg.startsWith('SYSTEM_INCOMING_BID:')) {
              final parts = msg.split(':');
              final providerName = parts[1];
              final price = parts[2];
              final eta = parts[3];
              final jobId = parts[4];
              final key = 'offered to do this for PKR $price';
              if (!_messages.any((m) => m.text.contains(key))) {
                _addBidMessage(
                  providerName: providerName,
                  price: price,
                  eta: eta,
                  jobId: jobId,
                  isMock: false,
                );
              }
            } else if (msg == 'SYSTEM_PROVIDER_ARRIVED') {
              if (!_messages
                  .any((m) => m.text == 'Your provider has arrived!')) {
                _addSystemMessage('🚗 Your provider has arrived at the location!');
              }
            }
          }
        }
      } catch (_) {}
    });
  }

  // ── Mock auto-bid logic ─────────────────────────────────────────────────────

  /// Called when a response with mock providers comes back.
  /// Picks the best mock provider and fires an automatic bid after a short delay.
  // Tracks which provider IDs have already bid IN THIS booking request cycle.
  // Cleared every time new providers arrive so each new request gets fresh bids.
  void _triggerMockAutoBid(List<dynamic> providers) {
    final mocks = providers
        .map((p) => p as Map<String, dynamic>)
        .where((p) => p['is_mock'] == true)
        .toList();
    if (mocks.isEmpty) return;

    // Clear previous cycle's bids so each new request triggers fresh bids
    _pendingMockBids.clear();

    // Sort by score — nearest/best mock first
    mocks.sort((a, b) =>
        AntigravityService.scoreProvider(b, clientLat: _currentPosition?.latitude, clientLng: _currentPosition?.longitude)
            .compareTo(AntigravityService.scoreProvider(a, clientLat: _currentPosition?.latitude, clientLng: _currentPosition?.longitude)));

    // Fire bids from top 1–2 providers with staggered delays
    final toFire = mocks.take(2).toList();
    for (int i = 0; i < toFire.length; i++) {
      final provider = toFire[i];
      final pid = provider['provider_id']?.toString() ?? 'mock_${provider['name']?.hashCode}_$i';

      // Skip exact duplicates within this batch
      if (_pendingMockBids.containsKey(pid)) continue;
      _pendingMockBids[pid] = provider;

      final name = provider['name'] ?? 'Ahmed';

      // Use provider's actual quoted price from mock data; add slight variation for second bidder
      final basePrice = (provider['pricing']?['estimated_total_pkr'] ??
          provider['pricing']?['hourly_rate_pkr'] ??
          1500) as num;
      // Second provider bids slightly lower to show competition
      final price = i == 0 ? basePrice : (basePrice * 0.92).round();

      final eta = (provider['eta_minutes'] ?? (20 + i * 5));

      final delaySeconds = 2 + (i * 4); // 2s for first, 6s for second

      Future.delayed(Duration(seconds: delaySeconds), () {
        if (!mounted) return;
        // Only show second bid if first was already shown (no duplicate check needed since cleared)
        _addBidMessage(
          providerName: name.toString(),
          price: price.toString(),
          eta: eta.toString(),
          jobId: pid,
          isMock: true,
          mockProviderData: provider,
        );
      });
    }
  }

  void _addBidMessage({
    required String providerName,
    required String price,
    required String eta,
    required String jobId,
    required bool isMock,
    Map<String, dynamic>? mockProviderData,
  }) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        text: '$providerName ne PKR $price mein yeh kaam karne ki peshkash ki. ETA: $eta min. Confirm karein?',
        isUser: false,
        agentName: 'MUKHTAR',
        messageType: 'BID_RECEIVED',
        bookingData: {
          'job_id': jobId,
          'is_mock': isMock,
          'provider_name': providerName,
          'estimated_price': price,
          'eta': eta,
          'mock_provider_data': mockProviderData,
        },
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  // ── Confirm booking (mock) ──────────────────────────────────────────────────

  Future<void> _confirmMockBooking(Map<String, dynamic> bidData) async {
    if (!mounted) return;
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 800)); // simulate processing

    final mockData = bidData['mock_provider_data'] as Map<String, dynamic>? ?? {};
    final bookingId =
        'KG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final providerName = bidData['provider_name'] ?? mockData['name'] ?? 'Ahmed';

    // CRITICAL FIX: Use the EXACT price the provider bid (from bidData),
    // NOT the mock data's pricing. bidData['estimated_price'] is what was
    // passed to _addBidMessage → stored in message.bookingData → passed here.
    final rawPrice = bidData['estimated_price']?.toString() ?? '1500';
    final bidAmountPkr = int.tryParse(rawPrice) ??
        (mockData['pricing']?['estimated_total_pkr'] as num?)?.toInt() ??
        1500;

    final eta = bidData['eta'] ?? '25';
    final providerId = bidData['job_id'] ?? mockData['provider_id'] ?? 'mock_001';

    final booking = <String, dynamic>{
      'booking_id': bookingId,
      'provider_id': providerId,
      'provider_name': providerName,
      'provider_phone': mockData['phone'] ?? '0300-1234567',
      'provider_rating': mockData['rating'] ?? 4.5,
      'service_type': mockData['service_categories']?[0] ?? 'HOME_SERVICE',
      'slot': 'Today, As Soon As Possible',
      'eta_minutes': int.tryParse(eta.toString()) ?? 25,
      'is_mock': true,
      'status': 'CONFIRMED',
      'location': {
        'area': mockData['location']?['area'] ?? 'Local Area',
        'city': mockData['location']?['city'] ?? 'Islamabad',
        'lat': _currentPosition?.latitude,
        'lng': _currentPosition?.longitude,
      },
      'pricing': {
        // Use the actual bid amount — this is what shows on the receipt
        'estimated_total_pkr': bidAmountPkr,
        'bid_amount_pkr': bidAmountPkr,
        'payment_method': 'CASH_ON_DELIVERY',
      },
      'created_at': DateTime.now().toIso8601String(),
    };

    // Persist booking
    await BookingStore.instance.addBooking(booking);

    // ── PROVIDER NOTIFICATION: Write to local provider notification store ──
    // This lets ProviderNotificationsScreen show the booking even when backend is offline.
    await ProviderNotificationStore.instance.addNotification({
      'type': 'NEW_BOOKING',
      'message': 'New booking confirmed: ${(booking['service_type'] ?? 'Service').toString().replaceAll('_', ' ')} '
          'at ${(booking['location'] as Map?)?['area'] ?? 'your area'}. '
          'PKR $bidAmountPkr • Booking ID: $bookingId',
      'booking_id': bookingId,
      'provider_id': providerId,
      'provider_name': providerName,
      'amount': bidAmountPkr,
      'timestamp': DateTime.now().toIso8601String(),
      'read': false,
    });

    // Also update provider stats
    await ProviderStatsStore.instance.recordNewBooking(
      providerId: providerId,
      amount: bidAmountPkr,
    );

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _messages.add(ChatMessage(
        text: 'Booking confirmed!',
        isUser: false,
        agentName: 'MUKHTAR',
        messageType: 'BOOKING_CONFIRMED',
        bookingData: booking,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();

    // Push notification
    await NotificationService().showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Booking Confirmed! ✅',
      body: '$providerName will arrive in ~$eta mins. PKR $bidAmountPkr',
    );

    // YAKEEN follow-up after receipt
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: '📲 Main $providerName ko track kar raha hun. ~$eta minute mein pahunchenge. '
              'Jab kaam muka le toh booking ko "Complete" mark karna aur rating zaroor dena! ⭐',
          isUser: false,
          agentName: 'YAKEEN',
          messageType: 'FOLLOWUP',
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    });
  }

  // ── Send real backend message ────────────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isProcessing) return;
    HapticFeedback.lightImpact();

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isProcessing = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final result = await AntigravityService.instance.processRequest(
        text,
        lat: _currentPosition?.latitude,
        lng: _currentPosition?.longitude,
      );

      setState(() {
        _isProcessing = false;
        _currentTrace = result.trace;
        _lastLatencyMs = result.latencyMs;
        _serverConnected = true;

        // Rank providers with distance weighting before display
        List<dynamic>? rankedProviders;
        if (result.providers != null && result.providers!.isNotEmpty) {
          rankedProviders = AntigravityService.rankProviders(
            result.providers!,
            clientLat: _currentPosition?.latitude,
            clientLng: _currentPosition?.longitude,
          );
        }

        _messages.add(ChatMessage(
          text: result.userMessage,
          isUser: false,
          agentName: result.currentAgent,
          timestamp: DateTime.now(),
          providers: rankedProviders ?? result.providers,
          bookingData: result.bookingData,
          messageType: result.messageType,
        ));

        if (!_showTrace && result.hasProviders) _showTrace = true;
      });

      // Persist confirmed booking from backend
      if (result.hasBooking && result.messageType == 'BOOKING_CONFIRMED') {
        final bd = result.bookingData as Map<String, dynamic>;
        await BookingStore.instance.addBooking({
          ...bd,
          'status': 'CONFIRMED',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Trigger auto-bid for mock providers
      if (result.hasProviders) {
        _triggerMockAutoBid(result.providers!);
      }

      // YAKEEN follow-up on real booking confirmed
      if (result.trace.yakeenTrace != null &&
          result.trace.yakeenTrace!.isNotEmpty &&
          result.hasBooking) {
        await NotificationService().showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Booking Confirmed!',
          body:
              '${result.bookingData?['provider_name'] ?? 'Provider'} will arrive in ~${result.bookingData?['eta_minutes'] ?? 30} mins.',
        );
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              _messages.add(ChatMessage(
                text: _extractYakeenMessage(result),
                isUser: false,
                agentName: 'YAKEEN',
                timestamp: DateTime.now(),
                messageType: 'FOLLOWUP',
              ));
            });
            _scrollToBottom();
          }
        });
      }

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _serverConnected = false;
      });
      if (e.toString().contains('IP_FALLBACK')) {
        _showIpDialog();
      } else {
        setState(() {
          _messages.add(ChatMessage(
            text: '⚠️ HIFAZAT Active\n\nEk masla aa gaya: ${e.toString()}\n\nDobara try karein.',
            isUser: false,
            agentName: 'HIFAZAT',
            timestamp: DateTime.now(),
            isError: true,
          ));
        });
      }
    }
  }

  String _extractYakeenMessage(AgentResponse result) {
    final booking = result.bookingData;
    if (booking == null) return '';
    final provider = booking['provider_name'] ?? '';
    final eta = booking['eta_minutes'] ?? 30;
    return '📲 Main $provider ko track kar raha hun. ~$eta minute mein pahunchenge. '
        'Jab kaam muka le toh "Complete" mark karna na bhulen! ⭐';
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      text: 'Assalam-o-Alaikum! 👋\n\nMain KhidmatGar hun — Pakistan ka pehla Multi-Agent AI service platform.\n\n'
          '🤖 5 specialized agents:\n• ZARA — Aapki baat samjhe\n• KHOJI — Best provider dhundhe\n'
          '• MUKHTAR — Booking kare\n• YAKEEN — Follow-up kare\n• HIFAZAT — Maslon ka hal kare\n\n'
          'Urdu, Roman Urdu, ya English mein request karein!',
      isUser: false,
      agentName: 'KhidmatGar',
      timestamp: DateTime.now(),
    ));
  }

  void _addSystemMessage(String text) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
        agentName: 'SYSTEM',
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _listen() async {
    if (!_isListening) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) return;
      final available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) =>
              setState(() => _controller.text = val.recognizedWords),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [AppTheme.primaryNeon.withOpacity(0.06), AppTheme.backgroundDark],
                radius: 1.5,
                center: const Alignment(0, -1),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            _buildAppBar(),
            _buildAgentStatusBar(),
            Expanded(child: _buildChatList()),
            if (_currentTrace != null)
              AgentTracePanel(
                trace: _currentTrace!,
                isExpanded: _showTrace,
                onToggle: () => setState(() => _showTrace = !_showTrace),
                latencyMs: _lastLatencyMs,
              ),
            if (_messages.length == 1) _buildQuickSuggestions(),
            _buildInputBar(),
          ]),
        ),
      ]),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.glassDecoration(borderRadius: 0),
      child: Row(children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, __) => Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryNeon.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.primaryNeon
                    .withOpacity(0.4 + _pulseController.value * 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryNeon
                      .withOpacity(0.2 + _pulseController.value * 0.2),
                  blurRadius: 12,
                )
              ],
            ),
            child: const Icon(Icons.psychology, color: AppTheme.primaryNeon, size: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('KhidmatGar AI',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            Row(children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _serverConnected ? AppTheme.primaryNeon : Colors.orange,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _serverConnected ? 'Multi-Agent Core Active' : 'Connecting...',
                style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: _serverConnected ? AppTheme.primaryNeon : Colors.orange),
              ),
            ]),
          ]),
        ),
        IconButton(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const BookingHistoryScreen())),
          icon: const Icon(Icons.history_rounded, color: AppTheme.textSecondary),
          tooltip: 'Booking History',
        ),
        IconButton(
          onPressed: () => setState(() => _showTrace = !_showTrace),
          icon: Icon(Icons.hub_rounded,
              color: _showTrace ? AppTheme.goldAccent : AppTheme.textSecondary),
          tooltip: 'Live Agent Brain',
        ),
        GestureDetector(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          child: Consumer(builder: (_, ref, __) {
            final user = ref.watch(authProvider);
            return Container(
              margin: const EdgeInsets.only(left: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.cardNavy,
                backgroundImage:
                    user?.photoUrl != null ? NetworkImage(user!.photoUrl) : null,
                child: user?.photoUrl == null
                    ? const Icon(Icons.person, size: 16, color: Colors.white)
                    : null,
              ),
            );
          }),
        ),
      ]),
    );
  }

  Widget _buildAgentStatusBar() {
    final agents = [
      {'name': 'ZARA', 'icon': Icons.translate_rounded, 'role': 'Intent'},
      {'name': 'KHOJI', 'icon': Icons.radar_rounded, 'role': 'Discovery'},
      {'name': 'MUKHTAR', 'icon': Icons.task_alt_rounded, 'role': 'Booking'},
      {'name': 'YAKEEN', 'icon': Icons.schedule_rounded, 'role': 'Follow-up'},
    ];
    return Container(
      height: 52,
      margin: const EdgeInsets.only(top: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: agents.length,
        itemBuilder: (_, i) {
          final agent = agents[i];
          final isActive = _currentTrace?.activeAgent == agent['name'];
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(right: 10, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.primaryNeon.withOpacity(0.15)
                  : AppTheme.glassPanel,
              border: Border.all(
                color: isActive
                    ? AppTheme.primaryNeon
                    : Colors.white.withOpacity(0.08),
                width: isActive ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(agent['icon'] as IconData,
                  size: 13,
                  color: isActive ? AppTheme.primaryNeon : AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(agent['name'] as String,
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppTheme.primaryNeon : AppTheme.textSecondary)),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_isProcessing ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _messages.length) return const TypingIndicator();
        final msg = _messages[i];
        if (msg.messageType == 'BOOKING_CONFIRMED' && msg.bookingData != null) {
          return _buildBookingReceiptCard(msg);
        }
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 60),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00C853), AppTheme.primaryNeon],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(color: AppTheme.primaryNeon.withOpacity(0.3), blurRadius: 12, spreadRadius: -2)
            ],
          ),
          child: Text(message.text,
              style: GoogleFonts.outfit(
                  color: AppTheme.backgroundDark, fontSize: 15, fontWeight: FontWeight.w500)),
        ),
      ).animate().slideX(begin: 0.3, end: 0, duration: 350.ms, curve: Curves.easeOutCubic).fadeIn();
    }

    final agentColor = _agentColor(message.agentName ?? 'KhidmatGar');
    final isError = message.isError;
    final isBid = message.messageType == 'BID_RECEIVED';
    final isFollowup = message.messageType == 'FOLLOWUP';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (message.agentName != null)
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_agentIcon(message.agentName!), size: 12, color: agentColor),
            const SizedBox(width: 5),
            Text(message.agentName!,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, fontWeight: FontWeight.bold,
                    color: agentColor, letterSpacing: 1.5)),
            if (isFollowup) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: agentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('FOLLOW-UP',
                    style: GoogleFonts.outfit(
                        fontSize: 8, color: agentColor,
                        fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ],
          ]),
        ),
      Container(
        margin: const EdgeInsets.only(bottom: 16, right: 40),
        decoration: BoxDecoration(
          color: isError ? Colors.red.withOpacity(0.08) : AppTheme.glassPanel,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4), topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20),
          ),
          border: Border.all(
            color: isError ? Colors.red.withOpacity(0.3) : agentColor.withOpacity(0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message.text,
                style: GoogleFonts.outfit(
                    color: isError ? Colors.red.shade300 : AppTheme.textPrimary,
                    fontSize: 15, height: 1.55)),

            // BID confirm button
            if (isBid && message.bookingData != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final bidData = message.bookingData as Map<String, dynamic>;
                      if (bidData['is_mock'] == true) {
                        _confirmMockBooking(bidData);
                      } else {
                        _sendMessage('SYSTEM_BOOK_PROVIDER:${bidData['job_id']}');
                      }
                    },
                    icon: const Icon(Icons.check_circle_rounded, color: Colors.black87),
                    label: Text('Confirm Booking',
                        style: GoogleFonts.outfit(color: Colors.black87, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryNeon,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    // Dismiss bid
                    final bidData = message.bookingData as Map<String, dynamic>;
                    final pid = bidData['job_id']?.toString() ?? '';
                    _pendingMockBids.remove(pid);
                    _addSystemMessage('Bid dismissed. Aap dusra provider bhi select kar sakte hain.');
                  },
                  icon: const Icon(Icons.close, size: 16, color: Colors.white),
                  label: Text('Decline', style: GoogleFonts.outfit(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ]),
            ],

            // Provider cards
            if (message.providers != null && message.providers!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Divider(color: AppTheme.primaryNeon.withOpacity(0.15), height: 24),
              Text('Top Providers Found',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              ...message.providers!.asMap().entries.map(
                (e) => ProviderCard(
                  provider: e.value,
                  rank: e.key + 1,
                  onBook: () => _sendMessage(
                      'SYSTEM_BOOK_PROVIDER:${(e.value as Map)['provider_id']}'),
                ),
              ),
            ],
          ]),
        ),
      ),
    ])
        .animate()
        .slideX(begin: -0.2, end: 0, duration: 400.ms, curve: Curves.easeOutCubic)
        .fadeIn();
  }

  // ── Booking receipt card ─────────────────────────────────────────────────────

  Widget _buildBookingReceiptCard(ChatMessage message) {
    final booking = message.bookingData as Map<String, dynamic>? ?? {};
    final agentColor = _agentColor(message.agentName ?? 'MUKHTAR');
    final bookingId = booking['booking_id'] ?? '—';
    final providerName = booking['provider_name'] ?? '—';
    final providerPhone = booking['provider_phone'] ?? '—';
    final providerRating =
        (booking['provider_rating'] ?? 0.0).toStringAsFixed(1);
    final service = (booking['service_type'] ?? '—').toString().replaceAll('_', ' ');
    final slot = booking['slot'] ?? '—';
    final eta = booking['eta_minutes']?.toString() ?? '—';
    final area = (booking['location'] as Map?)?['area'] ?? '—';
    final city = (booking['location'] as Map?)?['city'] ?? '';
    final pricingMap = booking['pricing'] as Map? ?? {};
    final price = pricingMap['estimated_total_pkr']?.toString() ?? '—';
    final payment = (pricingMap['payment_method'] ?? 'CASH ON DELIVERY')
        .toString().replaceAll('_', ' ');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.task_alt_rounded, size: 12, color: agentColor),
          const SizedBox(width: 5),
          Text(message.agentName ?? 'MUKHTAR',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.bold,
                  color: agentColor, letterSpacing: 1.5)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
            ),
            child: Text('✓ BOOKING CONFIRMED',
                style: GoogleFonts.outfit(
                    fontSize: 8, color: Colors.greenAccent,
                    fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ]),
      ),
      Container(
        margin: const EdgeInsets.only(bottom: 16, right: 8),
        decoration: BoxDecoration(
          color: AppTheme.glassPanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.greenAccent.withOpacity(0.07), blurRadius: 16, spreadRadius: 2)
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.greenAccent.withOpacity(0.18),
                AppTheme.primaryNeon.withOpacity(0.10),
              ]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14), topRight: Radius.circular(14),
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.greenAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Service Booking Receipt',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  Text('KhidmatGar — Confirmed',
                      style: GoogleFonts.outfit(
                          fontSize: 11, color: Colors.greenAccent, fontWeight: FontWeight.w500)),
                ]),
              ),
            ]),
          ),
          // Booking ID banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: AppTheme.cardNavy,
            child: Center(
              child: Text('Booking ID: $bookingId',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: AppTheme.primaryNeon,
                      fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _receiptSection('Service Details', [
                _receiptRow(Icons.build_rounded, 'Service', service),
                _receiptRow(Icons.schedule_rounded, 'Slot', slot),
                _receiptRow(Icons.timer_rounded, 'ETA', '$eta minutes'),
                _receiptRow(Icons.location_on_rounded, 'Location',
                    '$area${city.isNotEmpty ? ', $city' : ''}'),
              ]),
              const SizedBox(height: 14),
              _receiptSection('Provider Details', [
                _receiptRow(Icons.person_rounded, 'Provider', providerName),
                _receiptRow(Icons.phone_rounded, 'Contact', providerPhone),
                _receiptRow(Icons.star_rounded, 'Rating', '★ $providerRating / 5.0'),
              ]),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.goldAccent.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.goldAccent.withOpacity(0.25)),
                ),
                child: Row(children: [
                  const Icon(Icons.payments_rounded, color: AppTheme.goldAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Estimated Cost',
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: AppTheme.textSecondary)),
                      Text('PKR $price',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 18, fontWeight: FontWeight.bold,
                              color: AppTheme.goldAccent)),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppTheme.cardNavy, borderRadius: BorderRadius.circular(6)),
                    child: Text(payment,
                        style: GoogleFonts.outfit(
                            fontSize: 10, color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ]),
          ),
          Divider(color: Colors.white.withOpacity(0.05), height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MapViewScreen(booking: booking)),
                  );
                  if (result != null && result is AgentResponse && mounted) {
                    setState(() {
                      _messages.add(ChatMessage(
                        text: result.userMessage,
                        isUser: false,
                        agentName: result.currentAgent,
                        timestamp: DateTime.now(),
                        messageType: 'FOLLOWUP',
                      ));
                    });
                    _scrollToBottom();
                  }
                },
                icon: const Icon(Icons.map_rounded, color: Colors.black87, size: 18),
                label: Text('Track Provider Live',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ]),
      ),
    ])
        .animate()
        .slideX(begin: -0.2, end: 0, duration: 400.ms, curve: Curves.easeOutCubic)
        .fadeIn();
  }

  Widget _receiptSection(String title, List<Widget> rows) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: GoogleFonts.outfit(
              fontSize: 11, color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600, letterSpacing: 1.1)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: AppTheme.cardNavy,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: rows),
      ),
    ]);
  }

  Widget _receiptRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(children: [
        Icon(icon, size: 15, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Text(label,
            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary)),
        const Spacer(),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.end,
              style: GoogleFonts.outfit(
                  fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  // ── Quick suggestions ────────────────────────────────────────────────────────

  Widget _buildQuickSuggestions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 8),
        child: Text('Quick Requests',
            style: GoogleFonts.outfit(
                fontSize: 11, color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600, letterSpacing: 1.2)),
      ),
      SizedBox(
        height: 42,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _quickSuggestions.length,
          itemBuilder: (_, i) {
            final s = _quickSuggestions[i];
            return GestureDetector(
              onTap: () => _sendMessage(s['text']!),
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primaryNeon.withOpacity(0.08),
                  border: Border.all(color: AppTheme.primaryNeon.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(s['lang']!, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(s['text']!,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppTheme.primaryNeon,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            ).animate(delay: Duration(milliseconds: i * 80))
                .slideX(begin: 0.3, end: 0, duration: 300.ms)
                .fadeIn();
          },
        ),
      ),
      const SizedBox(height: 8),
    ]);
  }

  // ── Input bar ────────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: AppTheme.glassDecoration(borderRadius: 0).copyWith(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardNavy,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isProcessing
                    ? AppTheme.primaryNeon.withOpacity(0.4)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: TextField(
              controller: _controller,
              style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 15),
              maxLines: null,
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: 'Service request karein...',
                hintStyle: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onSubmitted: _sendMessage,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _listen,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isListening ? Colors.redAccent.withOpacity(0.2) : AppTheme.cardNavy,
              shape: BoxShape.circle,
              border: Border.all(
                  color: _isListening ? Colors.redAccent : Colors.white.withOpacity(0.08)),
            ),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none_rounded,
              color: _isListening ? Colors.redAccent : AppTheme.textSecondary,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _isProcessing ? null : () => _sendMessage(_controller.text),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: _isProcessing
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF00C853), AppTheme.primaryNeon]),
              color: _isProcessing ? AppTheme.cardNavy : null,
              shape: BoxShape.circle,
              boxShadow: _isProcessing
                  ? []
                  : [BoxShadow(color: AppTheme.primaryNeon.withOpacity(0.4), blurRadius: 14)],
            ),
            child: _isProcessing
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryNeon),
                  )
                : const Icon(Icons.arrow_upward_rounded,
                    color: AppTheme.backgroundDark, size: 24),
          ),
        ),
      ]),
    );
  }

  // ── Agent helpers ────────────────────────────────────────────────────────────

  Color _agentColor(String name) {
    switch (name) {
      case 'ZARA': return AppTheme.secondaryNeon;
      case 'KHOJI': return AppTheme.primaryNeon;
      case 'MUKHTAR': return AppTheme.goldAccent;
      case 'YAKEEN': return const Color(0xFF9C27B0);
      case 'HIFAZAT': return Colors.redAccent;
      default: return AppTheme.textSecondary;
    }
  }

  IconData _agentIcon(String name) {
    switch (name) {
      case 'ZARA': return Icons.translate_rounded;
      case 'KHOJI': return Icons.radar_rounded;
      case 'MUKHTAR': return Icons.task_alt_rounded;
      case 'YAKEEN': return Icons.schedule_rounded;
      case 'HIFAZAT': return Icons.shield_rounded;
      default: return Icons.auto_awesome_rounded;
    }
  }
}