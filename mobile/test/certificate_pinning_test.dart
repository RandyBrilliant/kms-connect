import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/certificate_pinning.dart';

const _leafPem = '''
-----BEGIN CERTIFICATE-----
MIIDljCCAxygAwIBAgISBWc0KxcYDg1jDyZfkkoUHoGkMAoGCCqGSM49BAMDMDMx
CzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MQwwCgYDVQQDEwNZ
RTIwHhcNMjYwODEwMDE0NzQzWhcNMjYxMTA4MDE0NzQyWjAfMR0wGwYDVQQDExRk
YXRhLmttcy1jb25uZWN0LmNvbTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABDNA
A4UddUWOqa9PuEljpXUV6WeYMnXTWdotj8O2tQGKcLvUiDRaO9Lt8a2Ac3f/ZLne
QlfMhrTSe0Lxw7NDKbGjggIiMIICHjAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAww
CgYIKwYBBQUHAwEwDAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQUiMtyYvNL8B7KOX/b
1BrWFqiWpeAwHwYDVR0jBBgwFoAUuVnyjs8i8IbTN0j/dhQYuoLYVYcwMwYIKwYB
BQUHAQEEJzAlMCMGCCsGAQUFBzAChhdodHRwOi8veWUyLmkubGVuY3Iub3JnLzAf
BgNVHREEGDAWghRkYXRhLmttcy1jb25uZWN0LmNvbTATBgNVHSAEDDAKMAgGBmeB
DAECATAuBgNVHR8EJzAlMCOgIaAfhh1odHRwOi8veWUyLmMubGVuY3Iub3JnLzM3
LmNybDCCAQwGCisGAQQB1nkCBAIEgf0EgfoA+AB3AK9niDtXsE7dj6bZfvYuqOuB
CsdxYPAkXlXWDC/nhYc6AAABn+mQRQQAAAQDAEgwRgIhAI8o8HgmJ2b5iAl4rCfL
bYbEjZXv6XUJbc3h7bnFJnb1AiEAz6lIOlZ81kWu4k6GEpJvIix0/aasv/hTfiXQ
bvjj1N8AfQAm42RuWGkhI7w0P0ckNZs3ks0kWojYFdOTM/2ZGKtHIwAAAZ/pkD87
AAgAAAUAMxxLVwQDAEYwRAIgO7rrFK4M7t1btU0A93MXUAloRVViIJcF1zNQ5WGn
oMACIBxboCXaSYvWXiz/uALHdEV6VEgJckWuoQpdvMiYUneuMAoGCCqGSM49BAMD
A2gAMGUCMBjEAY4ueid4nGwB3mAdgq83xX49C5UN+VpXiom1viZHQthWWKDaplDo
79FD7LdzhAIxAO8q3IzAYvwrLZn9nOOBJCmE5tqNyrbfSeflrX79zuy4EeAyo3tj
VKz5Puh9TryHFw==
-----END CERTIFICATE-----
''';

Uint8List _derFromPem(String pem) {
  final b64 = pem
      .replaceAll(RegExp(r'-----[^-]+-----'), '')
      .replaceAll(RegExp(r'\s'), '');
  return Uint8List.fromList(base64Decode(b64));
}

void main() {
  test('extracts the live leaf SPKI pin', () {
    expect(
      spkiSha256Base64(_derFromPem(_leafPem)),
      'ImqXEMXsiRR9Iqjr4L6AC+5ri1ua9jmJ8jnXF1vrXMQ=',
    );
    expect(
      kLeafSpkiPins.contains('ImqXEMXsiRR9Iqjr4L6AC+5ri1ua9jmJ8jnXF1vrXMQ='),
      isTrue,
    );
  });

  test('pins only the production HTTPS API host outside debug', () {
    expect(
      shouldPinCertificates(
        host: 'data.kms-connect.com',
        apiBaseUrl: 'https://data.kms-connect.com',
        debugMode: false,
      ),
      isTrue,
    );
    expect(
      shouldPinCertificates(
        host: 'data.kms-connect.com',
        apiBaseUrl: 'https://data.kms-connect.com',
        debugMode: true,
      ),
      isFalse,
    );
    expect(
      shouldPinCertificates(
        host: 'data.kms-connect.com',
        apiBaseUrl: 'http://192.168.0.10:8000',
        debugMode: false,
      ),
      isFalse,
    );
    expect(
      shouldPinCertificates(
        host: 'evil.example',
        apiBaseUrl: 'https://data.kms-connect.com',
        debugMode: false,
      ),
      isFalse,
    );
  });

  test('accepts known Let\'s Encrypt intermediates as a rotation safety net', () {
    expect(
      isKnownLetsEncryptIssuer("C=US, O=Let's Encrypt, CN=YE2"),
      isTrue,
    );
    expect(
      isKnownLetsEncryptIssuer('/C=US/O=Let\'s Encrypt/CN=E7'),
      isTrue,
    );
    expect(
      isKnownLetsEncryptIssuer('O=Corporate Proxy CA, CN=MITM'),
      isFalse,
    );
  });
}
