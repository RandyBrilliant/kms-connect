import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';

/// A staff user that can be chosen as a referrer during registration.
class StaffReferrer {
  final int id;
  final String fullName;
  final String referralCode;

  const StaffReferrer({
    required this.id,
    required this.fullName,
    required this.referralCode,
  });

  factory StaffReferrer.fromJson(Map<String, dynamic> json) => StaffReferrer(
        id: json['id'] as int,
        fullName: (json['full_name'] as String?) ?? '',
        referralCode: (json['referral_code'] as String?) ?? '',
      );

  @override
  String toString() => fullName;
}

/// Loads active staff referrers from the public backend endpoint.
/// Cached by Riverpod for the lifetime of the provider — a single network
/// fetch per app session even if the picker is opened multiple times.
final staffReferrersProvider = FutureProvider<List<StaffReferrer>>((ref) async {
  final response =
      await ApiClient().dio.get(ApiEndpoints.publicStaffReferrers);
  final data = response.data as List<dynamic>;
  return data
      .map((e) => StaffReferrer.fromJson(e as Map<String, dynamic>))
      .toList();
});
