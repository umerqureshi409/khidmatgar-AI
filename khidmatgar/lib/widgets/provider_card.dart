import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../screens/professional_provider_profile_screen.dart';

class ProviderCard extends StatelessWidget {
  final dynamic provider;
  final int rank;
  final VoidCallback onBook;

  const ProviderCard({
    super.key,
    required this.provider,
    required this.rank,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    // If the provider is just a map coming from the dynamic API response
    final Map<String, dynamic> p = provider as Map<String, dynamic>;
    final name = p['name'] ?? 'Unknown Provider';
    final rating = p['rating']?.toDouble() ?? 0.0;
    final reviews = p['review_count'] ?? 0;
    final distance = p['distance_km']?.toDouble() ?? 0.0;
    final verified = p['verification']?['level'] == 'KHIDMATGAR_VERIFIED';
    final price = p['pricing']?['estimated_total_pkr'] ?? p['pricing']?['hourly_rate_pkr'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rank == 1 ? AppTheme.goldAccent : AppTheme.textSecondary.withOpacity(0.2),
          width: rank == 1 ? 1.5 : 1.0,
        ),
        boxShadow: rank == 1 ? [
          BoxShadow(
            color: AppTheme.goldAccent.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: rank == 1 ? AppTheme.goldAccent.withOpacity(0.2) : AppTheme.textSecondary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('#$rank', 
                    style: GoogleFonts.outfit(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold,
                      color: rank == 1 ? AppTheme.goldAccent : AppTheme.textPrimary,
                    )
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfessionalProviderProfileScreen(
                          providerId: p['provider_id']?.toString() ?? 'PRV-${p['name']?.toString().hashCode.abs()}',
                          providerName: name,
                          initialData: {
                            'provider_name': name,
                            'provider_id': p['provider_id']?.toString() ?? '',
                            'company_name': p['company_name'] ?? p['name'] ?? name,
                            'experience_years': p['experience_years'] ?? p['verification']?['experience_years'] ?? 5,
                            'total_services': p['total_jobs_completed'] ?? p['review_count'] ?? 0,
                            'rating': p['rating']?.toDouble() ?? 0.0,
                            'response_time_avg': p['response_time_minutes'] ?? 8.0,
                            'on_time_delivery': 95.0,
                            'professional_score': ((p['rating']?.toDouble() ?? 4.0) / 5.0 * 100).round(),
                            'about': p['bio'] ?? 'Professional service provider committed to quality and timely service delivery.',
                            'certifications': p['certifications'] ?? [],
                            'services': (p['service_categories'] as List<dynamic>? ?? [])
                                .map((s) => {'name': s.toString(), 'experience_years': 3})
                                .toList(),
                            'languages': ['Urdu', 'English'],
                            'service_area': [p['location']?['area'] ?? 'Local Area'],
                            'accountability': {
                              'cancellations': 0,
                              'disputes_resolved': 0,
                              'complaints_received': 0,
                              'disputes_resolved_rate': 100,
                            },
                            'badges': [
                              if (p['verification']?['level'] == 'KHIDMATGAR_VERIFIED')
                                {'name': 'Verified Professional', 'icon': 'verified'},
                              if ((p['rating']?.toDouble() ?? 0.0) >= 4.5)
                                {'name': 'Top Rated', 'icon': 'star'},
                              {'name': 'Active Provider', 'icon': 'check'},
                            ],
                          },
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(Icons.open_in_new_rounded, size: 13, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
              if (verified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNeon.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, size: 12, color: AppTheme.primaryNeon),
                      const SizedBox(width: 4),
                      Text('Verified', style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.primaryNeon)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoChip(Icons.star, '$rating ($reviews)', AppTheme.goldAccent),
              _buildInfoChip(Icons.location_on, '${distance}km away', AppTheme.textSecondary),
              _buildInfoChip(Icons.payments, 'Rs $price', AppTheme.secondaryNeon),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              onPressed: onBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: rank == 1 ? AppTheme.primaryNeon : AppTheme.cardNavy,
                foregroundColor: rank == 1 ? AppTheme.backgroundDark : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: rank == 1 ? BorderSide.none : const BorderSide(color: AppTheme.primaryNeon),
                ),
              ),
              child: Text(
                'Book Now',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
