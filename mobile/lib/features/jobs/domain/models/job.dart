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
    required this.createdAt,
    required this.updatedAt,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] as int,
      title: json['title'] as String,
      slug: json['slug'] as String,
      company: json['company'] as int,
      companyName: json['company_name'] as String? ?? '',
      locationCountry: json['location_country'] as String?,
      locationCity: json['location_city'] as String?,
      description: json['description'] as String,
      requirements: json['requirements'] as String?,
      employmentType: json['employment_type'] as String,
      salaryMin: json['salary_min'] as int?,
      salaryMax: json['salary_max'] as int?,
      currency: json['currency'] as String,
      status: json['status'] as String,
      postedAt: json['posted_at'] != null
          ? DateTime.parse(json['posted_at'] as String)
          : null,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
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
