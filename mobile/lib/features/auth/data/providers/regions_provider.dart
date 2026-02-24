import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/models/region.dart';

// ── Province ──────────────────────────────────────────────────────────────────
/// All provinces – loaded once, cached for session.
final provincesProvider = FutureProvider<List<Region>>((ref) async {
  final response = await ApiClient().dio.get(ApiEndpoints.provinces);
  final data = response.data as List<dynamic>;
  return data.map((e) => Region.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Regency (Kabupaten/Kota) ──────────────────────────────────────────────────
/// All regencies – used for "Tempat Lahir" picker (no province filter).
final regenciesProvider = FutureProvider<List<Region>>((ref) async {
  final response = await ApiClient().dio.get(ApiEndpoints.regencies);
  final data = response.data as List<dynamic>;
  return data.map((e) => Region.fromJson(e as Map<String, dynamic>)).toList();
});

/// Regencies filtered by [provinceId] – cascading address dropdown.
final regenciesByProvinceProvider =
    FutureProvider.family<List<Region>, int>((ref, provinceId) async {
  final response = await ApiClient()
      .dio
      .get(ApiEndpoints.regenciesByProvince(provinceId));
  final data = response.data as List<dynamic>;
  return data.map((e) => Region.fromJson(e as Map<String, dynamic>)).toList();
});

// ── District (Kecamatan) ──────────────────────────────────────────────────────
/// Districts filtered by [regencyId].
final districtsByRegencyProvider =
    FutureProvider.family<List<Region>, int>((ref, regencyId) async {
  final response = await ApiClient()
      .dio
      .get(ApiEndpoints.districtsByRegency(regencyId));
  final data = response.data as List<dynamic>;
  return data.map((e) => Region.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Village (Kelurahan/Desa) ──────────────────────────────────────────────────
/// Villages filtered by [districtId].
final villagesByDistrictProvider =
    FutureProvider.family<List<Region>, int>((ref, districtId) async {
  final response = await ApiClient()
      .dio
      .get(ApiEndpoints.villagesByDistrict(districtId));
  final data = response.data as List<dynamic>;
  return data.map((e) => Region.fromJson(e as Map<String, dynamic>)).toList();
});
