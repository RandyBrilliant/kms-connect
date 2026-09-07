import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Production API host that must present a Let's Encrypt certificate.
const kPinnedApiHost = 'data.kms-connect.com';

/// SHA-256 SPKI (base64) of the current leaf for data.kms-connect.com.
///
/// Recompute before a planned cert/key rotation:
/// ```
/// openssl s_client -connect data.kms-connect.com:443 -servername data.kms-connect.com \
///   < /dev/null 2>/dev/null | openssl x509 -pubkey -noout |
///   openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
/// ```
/// Add the new hash here, ship an app update, then let the old pin expire.
const kLeafSpkiPins = <String>{
  'ImqXEMXsiRR9Iqjr4L6AC+5ri1ua9jmJ8jnXF1vrXMQ=', // leaf, expires 2026-11-08
};

/// Let's Encrypt ECDSA/RSA intermediates we currently accept as a rotation
/// safety net. User-installed MITM CAs will not match. When LE publishes a
/// new intermediate, add its CN here before production starts using it.
const kLetsEncryptIntermediateCns = <String>{
  'YE1',
  'YE2',
  'YE3',
  'E5',
  'E6',
  'E7',
  'E8',
  'R10',
  'R11',
  'R12',
  'R13',
  'R14',
};

bool shouldPinCertificates({
  required String host,
  required String apiBaseUrl,
  required bool debugMode,
}) {
  if (debugMode) return false;
  final uri = Uri.tryParse(apiBaseUrl);
  if (uri == null || uri.scheme != 'https') return false;
  if (host != kPinnedApiHost) return false;
  return uri.host == kPinnedApiHost;
}

/// Extra check on top of the system trust store. Debug builds skip pinning
/// so Charles / local backends still work.
bool acceptPinnedCertificate({
  required X509Certificate? certificate,
  required String host,
  required String apiBaseUrl,
  required bool debugMode,
}) {
  if (!shouldPinCertificates(
    host: host,
    apiBaseUrl: apiBaseUrl,
    debugMode: debugMode,
  )) {
    return true;
  }
  if (certificate == null) return false;
  try {
    final spki = spkiSha256Base64(certificate.der);
    if (kLeafSpkiPins.contains(spki)) return true;
  } catch (_) {
    return false;
  }
  return isKnownLetsEncryptIssuer(certificate.issuer);
}

bool isKnownLetsEncryptIssuer(String issuer) {
  final normalized = issuer.toLowerCase();
  if (!normalized.contains("let's encrypt") &&
      !normalized.contains('lets encrypt')) {
    return false;
  }
  final cn = _issuerCommonName(issuer);
  if (cn == null) return false;
  return kLetsEncryptIntermediateCns.contains(cn);
}

String? _issuerCommonName(String issuer) {
  final match = RegExp(r'CN\s*=\s*([^,/]+)').firstMatch(issuer);
  if (match == null) return null;
  return match.group(1)?.trim();
}

String spkiSha256Base64(List<int> certificateDer) {
  final spki = extractSpki(Uint8List.fromList(certificateDer));
  return base64Encode(sha256.convert(spki).bytes);
}

/// SubjectPublicKeyInfo SEQUENCE from an X.509 certificate DER.
Uint8List extractSpki(Uint8List certDer) {
  if (certDer.isEmpty || certDer[0] != 0x30) {
    throw const FormatException('certificate is not a DER SEQUENCE');
  }
  var i = 1;
  i = _readLength(certDer, i).offset;
  if (i >= certDer.length || certDer[i] != 0x30) {
    throw const FormatException('missing TBS certificate');
  }
  i += 1;
  i = _readLength(certDer, i).offset;
  if (i < certDer.length && certDer[i] == 0xA0) {
    i = _skipTlv(certDer, i);
  }
  i = _skipTlv(certDer, i); // serial
  i = _skipTlv(certDer, i); // signature algorithm
  i = _skipTlv(certDer, i); // issuer
  i = _skipTlv(certDer, i); // validity
  i = _skipTlv(certDer, i); // subject
  if (i >= certDer.length || certDer[i] != 0x30) {
    throw const FormatException('missing SubjectPublicKeyInfo');
  }
  final start = i;
  i += 1;
  final spkiLen = _readLength(certDer, i);
  return Uint8List.sublistView(certDer, start, spkiLen.offset + spkiLen.length);
}

class _DerLen {
  const _DerLen(this.length, this.offset);
  final int length;
  final int offset;
}

_DerLen _readLength(Uint8List buf, int offset) {
  if (offset >= buf.length) {
    throw const FormatException('truncated DER length');
  }
  final first = buf[offset];
  offset += 1;
  if (first < 0x80) return _DerLen(first, offset);
  final n = first & 0x7F;
  if (n == 0 || n > 4 || offset + n > buf.length) {
    throw const FormatException('invalid DER length');
  }
  var length = 0;
  for (var j = 0; j < n; j++) {
    length = (length << 8) | buf[offset];
    offset += 1;
  }
  return _DerLen(length, offset);
}

int _skipTlv(Uint8List buf, int offset) {
  if (offset >= buf.length) {
    throw const FormatException('truncated DER TLV');
  }
  offset += 1;
  final len = _readLength(buf, offset);
  return len.offset + len.length;
}

/// Used by [ApiClient] so tests can pin against [Env.apiBaseUrl].
bool Function(X509Certificate? cert, String host, int port)
createCertificateValidator({
  required String apiBaseUrl,
  required bool debugMode,
}) {
  return (cert, host, port) => acceptPinnedCertificate(
    certificate: cert,
    host: host,
    apiBaseUrl: apiBaseUrl,
    debugMode: debugMode,
  );
}
