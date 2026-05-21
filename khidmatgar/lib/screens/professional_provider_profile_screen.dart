import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// Professional Provider Profile Screen - UNIQUE STANDOUT FEATURE
/// Displays provider credentials, experience, certifications, and accountability metrics
class ProfessionalProviderProfileScreen extends StatefulWidget {
  final String providerId;
  final String providerName;
  final Map<String, dynamic>? initialData;

  const ProfessionalProviderProfileScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    this.initialData,
  });

  @override
  State<ProfessionalProviderProfileScreen> createState() =>
      _ProfessionalProviderProfileScreenState();
}

class _ProfessionalProviderProfileScreenState
    extends State<ProfessionalProviderProfileScreen> {
  // Mock professional profile data
  late Map<String, dynamic> _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialData ??
        {
          "provider_name": widget.providerName,
          "provider_id": widget.providerId,
          "company_name": "Elite Services Pakistan",
          "experience_years": 12,
          "total_services": 485,
          "rating": 4.8,
          "response_time_avg": 3.5,
          "on_time_delivery": 98.5,
          "professional_score": 95,
          "about":
              "Professional service provider with 12+ years of industry experience. Specialized in plumbing, electrical, and general maintenance services. Committed to quality and customer satisfaction.",
          "certifications": [
            {
              "name": "Master Plumber License",
              "issuer": "Pakistan Technical Board",
              "year": 2018,
              "verified": true
            },
            {
              "name": "Electrical Safety Certification",
              "issuer": "WAPDA",
              "year": 2020,
              "verified": true
            },
            {
              "name": "Customer Service Excellence",
              "issuer": "Khidmatgar Training Program",
              "year": 2024,
              "verified": true
            },
          ],
          "services": [
            {"name": "Plumbing Repair", "experience_years": 12},
            {"name": "Electrical Work", "experience_years": 8},
            {"name": "General Maintenance", "experience_years": 12},
            {"name": "Installation Services", "experience_years": 10},
          ],
          "languages": ["Urdu", "Roman Urdu", "English"],
          "service_area": ["Islamabad", "Rawalpindi", "Chakbeli"],
          "accountability": {
            "cancellations": 14,
            "disputes_resolved": 4,
            "complaints_received": 2,
            "disputes_resolved_rate": 100
          },
          "badges": [
            {"name": "Verified Professional", "icon": "verified"},
            {"name": "Top Rated", "icon": "star"},
            {"name": "Reliable Performer", "icon": "check"},
          ],
        };
  }

  @override
  Widget build(BuildContext context) {
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
            child: CustomScrollView(
              slivers: [
                // App bar with back button
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppTheme.textPrimary),
                  ),
                  title: Text(
                    'Professional Profile',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                // Content
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Header with name and rating
                      _buildProfileHeader(),
                      const SizedBox(height: 20),
                      // Quick stats
                      _buildQuickStatsRow(),
                      const SizedBox(height: 20),
                      // About section
                      _buildAboutSection(),
                      const SizedBox(height: 20),
                      // Services
                      _buildServicesSection(),
                      const SizedBox(height: 20),
                      // Certifications
                      _buildCertificationsSection(),
                      const SizedBox(height: 20),
                      // Accountability
                      _buildAccountabilitySection(),
                      const SizedBox(height: 20),
                      // Badges
                      _buildBadgesSection(),
                      const SizedBox(height: 20),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      decoration: AppTheme.glassDecoration(borderRadius: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.goldAccent, AppTheme.primaryNeon],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                _profile["provider_name"][0].toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _profile["provider_name"],
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            _profile["company_name"],
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_rounded, color: AppTheme.goldAccent, size: 20),
              const SizedBox(width: 4),
              Text(
                "${_profile['rating']} Rating",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 4),
              Text(
                "Verified",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.greenAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .slideY(begin: 0.2, end: 0, duration: 500.ms)
        .fadeIn();
  }

  Widget _buildQuickStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: "Experience",
            value: "${_profile['experience_years']} yrs",
            icon: Icons.work_rounded,
            color: AppTheme.primaryNeon,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: "Services",
            value: "${_profile['total_services']}",
            icon: Icons.assignment_turned_in_rounded,
            color: AppTheme.goldAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: "On-Time",
            value: "${_profile['on_time_delivery']}%",
            icon: Icons.schedule_rounded,
            color: Colors.greenAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: AppTheme.glassDecoration(borderRadius: 12),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 9,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: AppTheme.glassDecoration(borderRadius: 12),
          padding: const EdgeInsets.all(12),
          child: Text(
            _profile['about'],
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Services',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...(_profile['services'] as List<dynamic>).cast<Map<String, dynamic>>()
            .map(
              (service) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: AppTheme.glassDecoration(borderRadius: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      service['name'],
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      "${service['experience_years']} yrs exp",
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  Widget _buildCertificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Certifications & Credentials',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...(_profile['certifications'] as List<dynamic>).cast<Map<String, dynamic>>()
            .map(
              (cert) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.3),
                    width: 1.5,
                  ),
                  color: Colors.greenAccent.withOpacity(0.05),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_user_rounded,
                            color: Colors.greenAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cert['name'],
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cert['issuer'],
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Issued: ${cert['year']}',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: AppTheme.textSecondary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  Widget _buildAccountabilitySection() {
    final acc = _profile['accountability'] as Map<String, dynamic>;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accountability & Transparency',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: AppTheme.glassDecoration(borderRadius: 12),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _buildAccountabilityRow(
                label: 'Total Services',
                value: '${_profile['total_services']}',
                icon: Icons.check_circle_rounded,
              ),
              const Divider(height: 16, color: Colors.white12),
              _buildAccountabilityRow(
                label: 'Cancellations',
                value: '${acc['cancellations']}',
                icon: Icons.cancel_rounded,
                color: Colors.redAccent,
              ),
              const Divider(height: 16, color: Colors.white12),
              _buildAccountabilityRow(
                label: 'Disputes Resolved',
                value: '${acc['disputes_resolved']} (${acc['disputes_resolved_rate']}%)',
                icon: Icons.handshake_rounded,
                color: Colors.greenAccent,
              ),
              const Divider(height: 16, color: Colors.white12),
              _buildAccountabilityRow(
                label: 'Complaints',
                value: '${acc['complaints_received']}',
                icon: Icons.warning_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountabilityRow({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color ?? AppTheme.goldAccent, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Professional Badges',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: (_profile['badges'] as List<dynamic>).cast<Map<String, dynamic>>()
              .map(
                (badge) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppTheme.primaryNeon.withOpacity(0.15),
                    border: Border.all(
                      color: AppTheme.primaryNeon.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        badge['icon'] == 'verified'
                            ? Icons.verified_rounded
                            : badge['icon'] == 'star'
                                ? Icons.star_rounded
                                : Icons.check_rounded,
                        color: AppTheme.primaryNeon,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        badge['name'],
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryNeon,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
