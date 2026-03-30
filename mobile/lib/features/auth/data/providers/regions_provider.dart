import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/endpoints.dart';
import '../../../../core/models/region.dart';

/// Loads a region list; on failure invalidates the source once and retries.
///
/// Avoids a stuck UI when a [FutureProvider] stayed in [AsyncError] after one
/// bad request (Riverpod keeps that state until invalidated).
Future<List<Region>> readRegionListWithRetry(
  WidgetRef ref,
  Future<List<Region>> Function() read,
  void Function() invalidate,
) async {
  try {
    return await read();
  } catch (_) {
    invalidate();
    return await read();
  }
}

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

// ── Kecamatan lookup from village ─────────────────────────────────────────────
/// Fetches the parent kecamatan (District) for a given [villageId].
///
/// Used when restoring a saved profile where kecamatan is not stored directly —
/// the village detail endpoint returns `district` (ID) and `district_name`.
final kecamatanFromVillageProvider =
    FutureProvider.family<Region, int>((ref, villageId) async {
  final response =
      await ApiClient().dio.get(ApiEndpoints.villageDetail(villageId));
  final data = response.data as Map<String, dynamic>;
  return Region(
    id: data['district'] as int,
    code: '',
    name: data['district_name'] as String,
  );
});
