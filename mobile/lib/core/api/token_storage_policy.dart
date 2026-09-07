/// Thrown when Keychain / encrypted storage cannot be used and the insecure
/// SharedPreferences fallback is not allowed (profile and release builds).
class SecureStorageUnavailableException implements Exception {
  const SecureStorageUnavailableException([
    this.message =
        'Penyimpanan aman tidak tersedia. Tidak dapat menyimpan sesi.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Whether JWT tokens may be stored in plaintext SharedPreferences.
///
/// Allowed only in debug builds: the iOS Simulator often has no Keychain when
/// code signing is disabled. Profile and release must use secure storage.
bool allowInsecureTokenFallback({required bool debugMode}) => debugMode;
