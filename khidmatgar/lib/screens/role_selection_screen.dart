import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'provider_dashboard.dart';
import 'provider_registration_screen.dart';

/// Updated RoleSelectionScreen
/// - If user picks PROVIDER and has NOT registered before → go to ProviderRegistrationScreen
/// - If user picks PROVIDER and IS registered → go straight to ProviderDashboard
/// - If user picks CUSTOMER → go to HomeScreen (chat), which requests GPS on load

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo / Title
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNeon.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.handshake_rounded,
                  color: AppTheme.primaryNeon,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'KhidmatGar',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                'Pakistan\'s AI Service Platform',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppTheme.primaryNeon,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'How would you like to use the app?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              _buildRoleCard(
                context,
                ref,
                title: 'I need a Service',
                subtitle: 'Customer',
                description:
                    'Find and book electricians, plumbers, AC technicians, and more near you.',
                icon: Icons.home_repair_service_rounded,
                accentColor: AppTheme.primaryNeon,
                onTap: () {
                  ref.read(authProvider.notifier).setRole('CUSTOMER');
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                },
              ),

              const SizedBox(height: 20),

              _buildRoleCard(
                context,
                ref,
                title: 'I offer Services',
                subtitle: 'Service Provider',
                description:
                    'Register your skills, receive job requests, and earn in your area.',
                icon: Icons.engineering_rounded,
                accentColor: Colors.orange,
                onTap: () async {
                  ref.read(authProvider.notifier).setRole('PROVIDER');
                  final prefs = await SharedPreferences.getInstance();
                  final registered =
                      prefs.getBool('provider_registered') ?? false;
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => registered
                          ? const ProviderDashboard()
                          : const ProviderRegistrationScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardNavy,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.06),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle.toUpperCase(),
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: accentColor, size: 16),
          ],
        ),
      ),
    );
  }
}
