import 'package:flutter/material.dart';

/// Simple terms + privacy modal used by registration declarations.
Future<void> showTermsAndPrivacyModal(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;

  Widget bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '• $text',
        textAlign: TextAlign.left,
        style: tt.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
          height: 1.45,
        ),
      ),
    );
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Syarat & Ketentuan',
                  textAlign: TextAlign.left,
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Harap baca dengan saksama sebelum melanjutkan.',
                  textAlign: TextAlign.left,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. Syarat & Ketentuan',
                          textAlign: TextAlign.left,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        bullet(
                          'Data yang Anda isi harus sesuai dengan dokumen resmi (KTP, KK, ijazah, dan dokumen pendukung lainnya) dan dapat dipertanggungjawabkan.',
                        ),
                        bullet(
                          'Anda memberikan izin kepada perusahaan untuk menggunakan data ini dalam proses rekrutmen, pengolahan dokumen penempatan, dan pelaporan kepada instansi terkait.',
                        ),
                        bullet(
                          'Apabila di kemudian hari ditemukan ketidaksesuaian atau pemalsuan data, perusahaan berhak membatalkan proses penempatan dan/atau melakukan tindakan lain sesuai ketentuan yang berlaku.',
                        ),
                        bullet(
                          'Ketentuan lebih rinci mengenai proses penempatan kerja akan dijelaskan oleh petugas perusahaan dan/atau tercantum dalam dokumen perjanjian terpisah.',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '2. Kebijakan Privasi',
                          textAlign: TextAlign.left,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        bullet(
                          'Data pribadi Anda akan disimpan dan diproses sesuai dengan ketentuan perlindungan data pribadi yang berlaku.',
                        ),
                        bullet(
                          'Data hanya akan digunakan untuk keperluan proses rekrutmen, penempatan kerja, pemenuhan kewajiban hukum, dan peningkatan layanan perusahaan.',
                        ),
                        bullet(
                          'Perusahaan tidak akan menjual atau membagikan data pribadi Anda kepada pihak ketiga yang tidak berkepentingan, kecuali diwajibkan oleh peraturan perundang-undangan atau dengan persetujuan Anda.',
                        ),
                        bullet(
                          'Anda berhak mengajukan permintaan koreksi, pembaruan, atau penghapusan data sesuai dengan prosedur internal perusahaan dan ketentuan hukum yang berlaku.',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Dengan melanjutkan, Anda menyatakan telah membaca, memahami, dan menyetujui Syarat & Ketentuan serta Kebijakan Privasi ini.',
                          textAlign: TextAlign.left,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
