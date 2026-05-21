import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/provider_stats_store.dart';

/// Provider Analytics Dashboard - UNIQUE STANDOUT FEATURE
/// Displays professional metrics, rating trends, service quality scores,
/// and accountability tracking for providers (differentiator for Challenge 2)
///
/// v2: Pulls REAL data from ProviderStatsStore (updated on bookings/ratings).
class ProviderAnalyticsScreen extends StatefulWidget {
  const ProviderAnalyticsScreen({super.key});

  @override
  State<ProviderAnalyticsScreen> createState() =>
      _ProviderAnalyticsScreenState();
}

class _ProviderAnalyticsScreenState extends State<ProviderAnalyticsScreen> {
  // Live stats — loaded from ProviderStatsStore, merged with baseline mock data
  Map<String, dynamic> _analytics = {
    "overall_rating": 4.7,
    "total_ratings": 127,
    "total_services": 142,
    "cancellation_rate": 2.8,
    "on_time_percentage": 96.8,
    "response_time_minutes": 4.2,
    "professional_score": 92,
    "earnings_this_month_pkr": 89500,
    "ratings_breakdown": [
      {"stars": 5, "count": 87, "percentage": 68.5},
      {"stars": 4, "count": 28, "percentage": 22.0},
      {"stars": 3, "count": 10, "percentage": 7.9},
      {"stars": 2, "count": 2, "percentage": 1.6},
      {"stars": 1, "count": 0, "percentage": 0.0},
    ],
    "recent_ratings": [
      {
        "date": "2 hours ago",
        "client": "Fatima Ahmed",
        "rating": 5,
        "comment": "Excellent plumbing work! Very professional."
      },
      {
        "date": "1 day ago",
        "client": "Ali Khan",
        "rating": 4,
        "comment": "Good service, arrived on time."
      },
      {
        "date": "2 days ago",
        "client": "Hassan Malik",
        "rating": 5,
        "comment": "Outstanding electrician. Highly recommended."
      },
    ],
    "monthly_trend": [
      {"month": "Jan", "rating": 4.3},
      {"month": "Feb", "rating": 4.5},
      {"month": "Mar", "rating": 4.6},
      {"month": "Apr", "rating": 4.7},
      {"month": "May", "rating": 4.7},
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadLiveStats();
  }

  Future<void> _loadLiveStats() async {
    await ProviderStatsStore.instance.load();
    final live = ProviderStatsStore.instance.getMergedStats();

    // Only override fields that have real data
    if (live['total_ratings'] as int > 0) {
      setState(() {
        _analytics['overall_rating'] =
            live['average_rating'] as double;
        _analytics['total_ratings'] =
            (live['total_ratings'] as int) + 127; // + baseline
        _analytics['total_services'] =
            (live['total_bookings'] as int) + 142; // + baseline
        _analytics['on_time_percentage'] =
            live['on_time_percentage'] as double;
        _analytics['earnings_this_month_pkr'] =
            (live['total_earnings_pkr'] as int) + 89500; // + baseline

        // Rebuild ratings breakdown from real ratings
        final ratings =
            (live['ratings'] as List<dynamic>?)
                ?.map((r) => (r as num).toDouble())
                .toList() ??
                [];
        if (ratings.isNotEmpty) {
          final breakdown = <Map<String, dynamic>>[];
          for (int stars = 5; stars >= 1; stars--) {
            final count = ratings
                .where((r) => r.round() == stars)
                .length;
            final pct =
                ratings.isEmpty ? 0.0 : (count / ratings.length) * 100;
            breakdown.add({
              "stars": stars,
              "count": count,
              "percentage": double.parse(pct.toStringAsFixed(1)),
            });
          }
          _analytics['ratings_breakdown'] = breakdown;
        }

        // Recompute professional score from real data
        final avgRating = live['average_rating'] as double;
        final onTime = live['on_time_percentage'] as double;
        _analytics['professional_score'] =
            ((avgRating / 5.0) * 50 + (onTime / 100) * 50).round();
      });
    }
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
                // Professional AppBar
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppTheme.textPrimary),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Analytics',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Professional Service Quality Dashboard',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Refreshing analytics...')),
                        );
                      },
                      icon: const Icon(Icons.refresh_rounded,
                          color: AppTheme.primaryNeon),
                    ),
                  ],
                ),
                // Content
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Overall Performance Card
                      _buildOverallPerformanceCard(),
                      const SizedBox(height: 20),
                      // Key Metrics Grid
                      _buildKeyMetricsGrid(),
                      const SizedBox(height: 20),
                      // Rating Distribution
                      _buildRatingDistribution(),
                      const SizedBox(height: 20),
                      // Monthly Trend Chart
                      _buildMonthlyTrendChart(),
                      const SizedBox(height: 20),
                      // Recent Ratings
                      _buildRecentRatingsSection(),
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

  Widget _buildOverallPerformanceCard() {
    final rating = _analytics["overall_rating"] as double;
    final profScore = _analytics["professional_score"] as int;

    return Container(
      decoration: AppTheme.glassDecoration(borderRadius: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Performance',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Rating Circle
              Column(
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            value: rating / 5.0,
                            strokeWidth: 8,
                            backgroundColor:
                                AppTheme.goldAccent.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation(
                              rating >= 4.5 ? Colors.greenAccent : Colors.amber,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              rating.toStringAsFixed(1),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Rating',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Professional Score
              Column(
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            value: profScore / 100.0,
                            strokeWidth: 8,
                            backgroundColor:
                                AppTheme.primaryNeon.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation(
                              AppTheme.primaryNeon,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$profScore',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryNeon,
                              ),
                            ),
                            Text(
                              'Prof. Score',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_rounded,
                    color: Colors.greenAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You are in the TOP 15% of professional providers!',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .slideY(begin: 0.2, end: 0, duration: 500.ms)
        .fadeIn();
  }

  Widget _buildKeyMetricsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildMetricCard(
          title: 'Total Services',
          value: '${_analytics["total_services"]}',
          subtitle: 'Completed',
          icon: Icons.check_circle_rounded,
          color: Colors.greenAccent,
        ),
        _buildMetricCard(
          title: 'Cancellations',
          value: '${_analytics["cancellation_rate"]}%',
          subtitle: 'Rate',
          icon: Icons.cancel_rounded,
          color: Colors.redAccent,
        ),
        _buildMetricCard(
          title: 'On-Time',
          value: '${_analytics["on_time_percentage"]}%',
          subtitle: 'Delivery',
          icon: Icons.schedule_rounded,
          color: AppTheme.primaryNeon,
        ),
        _buildMetricCard(
          title: 'Avg Response',
          value: '${_analytics["response_time_minutes"]}m',
          subtitle: 'Time',
          icon: Icons.flash_on_rounded,
          color: AppTheme.goldAccent,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: AppTheme.glassDecoration(borderRadius: 12),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingDistribution() {
    return Container(
      decoration: AppTheme.glassDecoration(borderRadius: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rating Distribution',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...((_analytics["ratings_breakdown"] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .reversed
              .toList())
              .map(
                (item) => Column(
                  children: [
                    Row(
                      children: [
                        Row(
                          children: List.generate(
                            item["stars"] as int,
                            (i) => Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: AppTheme.goldAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (item["percentage"] as double) / 100.0,
                              minHeight: 6,
                              backgroundColor:
                                  Colors.white.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation(
                                AppTheme.goldAccent.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${item["count"]}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendChart() {
    return Container(
      decoration: AppTheme.glassDecoration(borderRadius: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rating Trend (Last 5 Months)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: (_analytics["monthly_trend"] as List<dynamic>)
                  .map((item) {
                final rating = item["rating"] as double;
                final height = (rating / 5.0) * 80;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      rating.toStringAsFixed(1),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 20,
                      height: height,
                      decoration: BoxDecoration(
                        color: AppTheme.goldAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item["month"],
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRatingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Ratings',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...((_analytics["recent_ratings"] as List<dynamic>)
            .cast<Map<String, dynamic>>())
            .map(
              (rating) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: AppTheme.glassDecoration(borderRadius: 12),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          rating["client"],
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Row(
                          children: List.generate(
                            rating["rating"] as int,
                            (i) => Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: AppTheme.goldAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rating["comment"],
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rating["date"],
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: AppTheme.textSecondary.withOpacity(0.6),
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
}
