import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/widgets/custom_toast.dart';

/// Asset paths — keep in sync with `pubspec.yaml` `assets/documents/` and
/// `seed_document_types` codes (`cv`, `bukti-penyerahan-dokumen`, `ijin-keluarga`, …).
const kCvTemplateAssetPath = 'assets/documents/cv_template.pdf';
const kIjinKeluargaTemplateAssetPath = 'assets/documents/ijin_keluarga_template.pdf';
const kSuratStatusPerkawinanTemplateAssetPath =
    'assets/documents/surat_keterangan_status_perkawinan_template.doc';
const kBuktiPenyerahanDokumenAssetPath =
    'assets/documents/bukti_penyerahan_dokumen.pdf';

Future<void> _openBundledAsset(
  BuildContext context, {
  required String assetPath,
  required String tempBaseName,
  required String mimeType,
}) async {
  try {
    final data = await rootBundle.load(assetPath);
    final tmp = await getTemporaryDirectory();
    final ext = _extensionForMime(mimeType);
    final file = File('${tmp.path}/$tempBaseName$ext');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    final result = await OpenFilex.open(file.path, type: mimeType);
    if (!context.mounted) return;
    if (result.type != ResultType.done) {
      CustomToast.show(
        context,
        message: result.message.isNotEmpty
            ? result.message
            : 'Tidak dapat membuka berkas',
        type: ToastType.warning,
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    CustomToast.show(
      context,
      message: 'Gagal membuka template. Pastikan berkas ada di aplikasi.',
      type: ToastType.error,
    );
  }
}

String _extensionForMime(String mimeType) {
  switch (mimeType) {
    case 'application/pdf':
      return '.pdf';
    case 'application/msword':
      return '.doc';
    default:
      return '';
  }
}

/// Official CV / daftar riwayat hidup template (PDF).
Future<void> openCvTemplatePdf(BuildContext context) {
  return _openBundledAsset(
    context,
    assetPath: kCvTemplateAssetPath,
    // v2 + timestamp: old viewers cached `template_daftar_riwayat_hidup.pdf`.
    tempBaseName:
        'template_daftar_riwayat_hidup_v2_${DateTime.now().millisecondsSinceEpoch}',
    mimeType: 'application/pdf',
  );
}

/// Surat izin keluarga (form biru) — PDF template.
Future<void> openIjinKeluargaTemplatePdf(BuildContext context) {
  return _openBundledAsset(
    context,
    assetPath: kIjinKeluargaTemplateAssetPath,
    tempBaseName: 'template_ijin_keluarga',
    mimeType: 'application/pdf',
  );
}

/// Surat keterangan status perkawinan — Word template (isi lalu unggah sebagai PDF).
Future<void> openSuratStatusPerkawinanTemplateDoc(BuildContext context) {
  return _openBundledAsset(
    context,
    assetPath: kSuratStatusPerkawinanTemplateAssetPath,
    tempBaseName: 'template_status_perkawinan',
    mimeType: 'application/msword',
  );
}

/// Bukti penyerahan dokumen — formulir PDF (unduh, isi, unggah).
Future<void> openBuktiPenyerahanDokumenPdf(BuildContext context) {
  return _openBundledAsset(
    context,
    assetPath: kBuktiPenyerahanDokumenAssetPath,
    tempBaseName: 'bukti_penyerahan_dokumen',
    mimeType: 'application/pdf',
  );
}
