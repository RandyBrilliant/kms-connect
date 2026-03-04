class WorkExperience {
  final int id;
  final String companyName;
  final String position;
  /// Free-text city/location (backend: `location` field).
  final String? location;
  /// ISO 3166-1 alpha-2 country code (backend: `country` CountryField). Read-only from server.
  final String? country;
  /// Industry type (backend: `industry_type` field, e.g. SEMICONDUCTOR, ELEKTRONIK).
  final String? industryType;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool stillEmployed;
  final String? description;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkExperience({
    required this.id,
    required this.companyName,
    required this.position,
    this.location,
    this.country,
    this.industryType,
    this.startDate,
    this.endDate,
    this.stillEmployed = false,
    this.description,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkExperience.fromJson(Map<String, dynamic> json) {
    return WorkExperience(
      id: json['id'] as int,
      companyName: json['company_name'] as String,
      position: json['position'] as String,
      location: json['location'] as String?,
      country: json['country'] as String?,
      industryType: json['industry_type'] as String?,
      startDate: json['start_date'] != null 
          ? DateTime.parse(json['start_date'] as String) 
          : null,
      endDate: json['end_date'] != null 
          ? DateTime.parse(json['end_date'] as String) 
          : null,
      stillEmployed: json['still_employed'] as bool? ?? false,
      description: json['description'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_name': companyName,
      'position': position,
      if (location != null) 'location': location,
      if (industryType != null && industryType!.isNotEmpty)
        'industry_type': industryType,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'still_employed': stillEmployed,
      'description': description,
      'sort_order': sortOrder,
    };
  }
}
