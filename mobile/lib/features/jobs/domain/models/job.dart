import '../../../../core/utils/api_datetime.dart';

class Job {
  final int id;
  final String title;
  final String slug;
  final int company;
  final String companyName;
  final String? locationCountry;
  final String? locationCity;
  final String description;
  final String? requirements;
  final String employmentType;
  final int? salaryMin;
  final int? salaryMax;
  final String currency;
  final String status;
  final DateTime? postedAt;
  final DateTime? deadline;
  final DateTime? startDate;
  final int? quota;
  final DateTime createdAt;
  final DateTime updatedAt;

  Job({
    required this.id,
    required this.title,
    required this.slug,
    required this.company,
    required this.companyName,
    this.locationCountry,
    this.locationCity,
    required this.description,
    this.requirements,
    required this.employmentType,
    this.salaryMin,
    this.salaryMax,
    required this.currency,
    required this.status,
    this.postedAt,
    this.deadline,
    this.startDate,
    this.quota,
    required this.createdAt,
    required this.updatedAt,
  });

  static int _safeInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? fallback;
    if (v is double) return v.toInt();
    return fallback;
  }

  static int? _safeIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    if (v is double) return v.toInt();
    return null;
  }

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: _safeInt(json['id']),
      title: (json['title'] ?? '') as String,
      slug: (json['slug'] ?? '') as String,
      company: _safeInt(json['company']),
      companyName: json['company_name']?.toString() ?? '',
      locationCountry: json['location_country']?.toString(),
      locationCity: json['location_city']?.toString(),
      description: (json['description'] ?? '') as String,
      requirements: json['requirements']?.toString(),
      employmentType: (json['employment_type'] ?? '') as String,
      salaryMin: _safeIntOrNull(json['salary_min']),
      salaryMax: _safeIntOrNull(json['salary_max']),
      currency: (json['currency'] ?? 'IDR') as String,
      status: (json['status'] ?? '') as String,
      postedAt: ApiDateTime.parse(json['posted_at']),
      deadline: ApiDateTime.parse(json['deadline']),
      startDate: ApiDateTime.parse(json['start_date']),
      quota: _safeIntOrNull(json['quota']),
      createdAt:
          ApiDateTime.parseRequired(json['created_at'], fieldName: 'created_at'),
      updatedAt:
          ApiDateTime.parseRequired(json['updated_at'], fieldName: 'updated_at'),
    );
  }

  String get employmentTypeDisplay {
    switch (employmentType) {
      case 'FULL_TIME':
        return 'Penuh Waktu';
      case 'PART_TIME':
        return 'Paruh Waktu';
      case 'CONTRACT':
        return 'Kontrak';
      case 'INTERNSHIP':
        return 'Magang';
      default:
        return employmentType;
    }
  }

  String get salaryDisplay {
    if (salaryMin == null) return '-';
    if (salaryMax != null) {
      return '$currency ${_formatNumber(salaryMin!)} - ${_formatNumber(salaryMax!)}';
    }
    return '$currency ${_formatNumber(salaryMin!)}';
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String get locationDisplay {
    final parts = <String>[];
    if (locationCity != null && locationCity!.isNotEmpty) {
      parts.add(locationCity!);
    }
    if (locationCountry != null && locationCountry!.isNotEmpty) {
      parts.add(locationCountry!);
    }
    return parts.isEmpty ? '-' : parts.join(', ');
  }
}
