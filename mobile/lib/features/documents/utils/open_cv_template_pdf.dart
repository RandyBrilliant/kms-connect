import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/widgets/custom_toast.dart';

/// Bundled PDF for document type code `cv` (see backend `seed_document_types`).
const kCvTemplateAssetPath = 'assets/documents/cv_template.pdf';

/// Opens the official CV / daftar riwayat hidup template in the system PDF viewer.
Future<void> openCvTemplatePdf(BuildContext context) async {
  try {
    final data = await rootBundle.load(kCvTemplateAssetPath);
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/template_daftar_riwayat_hidup.pdf');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (!context.mounted) return;
    if (result.type != ResultType.done) {
      CustomToast.show(
        context,
        message: result.message.isNotEmpty
            ? result.message
            : 'Tidak dapat membuka PDF',
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
