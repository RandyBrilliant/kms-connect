import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const kAppStorePackageId = 'id.kmsconnect.app';

const kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=$kAppStorePackageId';

/// Result of checking App Store / Play Store for a newer published build.
class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.updateRequired,
    required this.storeUrl,
    this.androidImmediateAvailable = false,
  });

  const AppUpdateCheckResult.none()
      : updateRequired = false,
        storeUrl = '',
        androidImmediateAvailable = false;

  final bool updateRequired;
  final String storeUrl;
  final bool androidImmediateAvailable;
}

/// Forces users onto the latest store build (Play Store + App Store).
///
/// Android uses Play Core (versionCode). iOS compares the live App Store
/// marketing version from the iTunes lookup API.
///
/// Debug builds skip the check so local development is not blocked.
class AppUpdateService {
  AppUpdateService({Dio? dio}) : _dio = dio ?? Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );

  final Dio _dio;

  Future<AppUpdateCheckResult> evaluate() async {
    if (kIsWeb) return const AppUpdateCheckResult.none();
    if (kDebugMode) return const AppUpdateCheckResult.none();

    try {
      if (Platform.isAndroid) return await _evaluateAndroid();
      if (Platform.isIOS) return await _evaluateIos();
    } catch (e) {
      if (kDebugMode) debugPrint('Force-update check failed: $e');
    }
    return const AppUpdateCheckResult.none();
  }

  Future<void> openStore(String storeUrl) async {
    final uri = Uri.parse(storeUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Play's full-screen immediate update. If the user cancels, the blocking
  /// in-app screen remains so they cannot keep using the old build.
  Future<void> startAndroidImmediateUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      if (kDebugMode) debugPrint('Immediate in-app update skipped: $e');
    }
  }

  Future<AppUpdateCheckResult> _evaluateAndroid() async {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability != UpdateAvailability.updateAvailable) {
      return const AppUpdateCheckResult.none();
    }
    return AppUpdateCheckResult(
      updateRequired: true,
      storeUrl: kPlayStoreUrl,
      androidImmediateAvailable: info.immediateUpdateAllowed,
    );
  }

  Future<AppUpdateCheckResult> _evaluateIos() async {
    final package = await PackageInfo.fromPlatform();
    final storeVersion = await _lookupAppStoreVersion(package.packageName);
    if (storeVersion == null) return const AppUpdateCheckResult.none();
    if (compareStoreVersions(storeVersion.version, package.version) <= 0) {
      return const AppUpdateCheckResult.none();
    }
    return AppUpdateCheckResult(
      updateRequired: true,
      storeUrl: storeVersion.trackViewUrl,
    );
  }

  Future<({String version, String trackViewUrl})?> _lookupAppStoreVersion(
    String bundleId,
  ) async {
    final id = bundleId.isEmpty ? kAppStorePackageId : bundleId;
    final urls = [
      'https://itunes.apple.com/id/lookup?bundleId=$id&t=${DateTime.now().millisecondsSinceEpoch}',
      'https://itunes.apple.com/lookup?bundleId=$id&t=${DateTime.now().millisecondsSinceEpoch}',
    ];
    for (final url in urls) {
      final response = await _dio.get<Map<String, dynamic>>(url);
      final results = response.data?['results'];
      if (results is! List || results.isEmpty) continue;
      final first = results.first;
      if (first is! Map) continue;
      final version = first['version']?.toString() ?? '';
      if (version.isEmpty) continue;
      final trackViewUrl = first['trackViewUrl']?.toString() ?? '';
      final trackId = first['trackId'];
      final storeUrl = trackViewUrl.isNotEmpty
          ? trackViewUrl
          : (trackId != null
              ? 'https://apps.apple.com/id/app/id$trackId'
              : 'https://apps.apple.com/id/search?term=KMS%20Connect');
      return (version: version, trackViewUrl: storeUrl);
    }
    return null;
  }
}

/// Numeric semver compare: `1.0.22` is newer than `1.0.9`.
@visibleForTesting
int compareStoreVersions(String store, String installed) {
  List<int> parts(String value) => value
      .split(RegExp(r'[^0-9]+'))
      .where((p) => p.isNotEmpty)
      .map(int.parse)
      .toList();

  final a = parts(store);
  final b = parts(installed);
  final len = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < len; i++) {
    final ai = i < a.length ? a[i] : 0;
    final bi = i < b.length ? b[i] : 0;
    if (ai != bi) return ai.compareTo(bi);
  }
  return 0;
}
