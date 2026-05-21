import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 4)); // Give time for the animation
    if (!mounted) return;
    
    final user = ref.read(authProvider);
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => user != null ? const HomeScreen() : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          // Background Glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryNeon.withOpacity(0.15),
                    AppTheme.backgroundDark,
                  ],
                  radius: 1.0,
                  center: const Alignment(0, -0.2),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 1.seconds),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing Core
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryNeon.withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                          )
                        ],
                      ),
                    ).animate(onPlay: (controller) => controller.repeat())
                     .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 2.seconds, curve: Curves.easeInOut)
                     .then()
                     .scale(begin: const Offset(1.2, 1.2), end: const Offset(0.8, 0.8), duration: 2.seconds, curve: Curves.easeInOut),
                    
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.5), width: 2),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback if image not found or invalid
                            return const Icon(Icons.psychology, color: AppTheme.primaryNeon, size: 50);
                          },
                        ),
                      ),
                    ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),
                  ],
                ),
                const SizedBox(height: 40),
                
                // Text
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [Colors.white, AppTheme.primaryNeon],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    'KhidmatGar AI',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ).animate().slideY(begin: 0.3, end: 0, duration: 800.ms).fadeIn(),
                
                const SizedBox(height: 12),
                Text(
                  'OBSERVE • REASON • ACT',
                  style: GoogleFonts.outfit(
                    color: AppTheme.primaryNeon,
                    fontSize: 14,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w600,
                  ),
                ).animate().fadeIn(delay: 600.ms),
                
                const SizedBox(height: 16),
                Text(
                  'The True Agentic Service Platform',
                  style: GoogleFonts.outfit(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ).animate().fadeIn(delay: 1000.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
