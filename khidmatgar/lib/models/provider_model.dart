class ProviderModel {
  final String id;
  final String name;
  final String? businessName;
  final String phone;
  final double rating;
  final int reviewCount;
  final double distanceKm;
  final int etaMinutes;
  final int visitFeePkr;
  final int hourlyRatePkr;
  final int? estimatedTotalPkr;
  final bool isKhidmatgarVerified;
  final List<String> tags;

  ProviderModel({
    required this.id,
    required this.name,
    this.businessName,
    required this.phone,
    required this.rating,
    required this.reviewCount,
    required this.distanceKm,
    required this.etaMinutes,
    required this.visitFeePkr,
    required this.hourlyRatePkr,
    this.estimatedTotalPkr,
    required this.isKhidmatgarVerified,
    required this.tags,
  });

  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    final verification = json['verification'] ?? {};
    final pricing = json['pricing'] ?? {};
    
    return ProviderModel(
      id: json['provider_id'] ?? '',
      name: json['name'] ?? '',
      businessName: json['business_name'],
      phone: json['phone'] ?? '',
      rating: (json['rating'] ?? 0).toDouble(),
      reviewCount: json['review_count'] ?? 0,
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
      etaMinutes: json['eta_minutes'] ?? 0,
      visitFeePkr: pricing['visit_fee_pkr'] ?? 0,
      hourlyRatePkr: pricing['hourly_rate_pkr'] ?? 0,
      estimatedTotalPkr: pricing['estimated_total_pkr'],
      isKhidmatgarVerified: verification['level'] == 'KHIDMATGAR_VERIFIED',
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}
