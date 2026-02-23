import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/models/region.dart';

/// Fetches all Indonesian provinces once and caches for the app session.
final provincesProvider = FutureProvider<List<Region>>((ref) async {
  final response = await ApiClient().dio.get(ApiEndpoints.provinces);
  final data = response.data as List<dynamic>;
  return data
      .map((e) => Region.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Fetches all Indonesian regencies/cities once and caches for the app session.
/// These match what appears in the "Tempat Lahir" field on a KTP.
final regenciesProvider = FutureProvider<List<Region>>((ref) async {
  final response = await ApiClient().dio.get(ApiEndpoints.regencies);
  final data = response.data as List<dynamic>;
  return data
      .map((e) => Region.fromJson(e as Map<String, dynamic>))
      .toList();
});
