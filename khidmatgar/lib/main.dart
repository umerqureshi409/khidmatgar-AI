import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/booking_store.dart';
import 'services/session_store.dart';
import 'services/antigravity_service.dart';
import 'services/provider_notification_store.dart';
import 'services/provider_stats_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore persistent session & bookings before rendering
  await BookingStore.instance.load();

  // Restore provider notification & stats stores
  await ProviderNotificationStore.instance.load();
  await ProviderStatsStore.instance.load();

  // Restore session ID so polling continues across restarts
  final savedSessionId = await SessionStore.instance.loadSessionId();
  if (savedSessionId == null) {
    // First run — persist current session ID
    await SessionStore.instance.saveSessionId(AntigravityService.instance.sessionId);
  }

  // Try Firebase (optional — fails gracefully if not configured)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  await NotificationService().init();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const ProviderScope(child: KhidmatGarApp()));
}

class KhidmatGarApp extends StatelessWidget {
  const KhidmatGarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KhidmatGar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
}
  }