import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shows Terms & Conditions and Privacy Policy modal bottom sheet
/// Used across registration and login flows
void showTermsAndPrivacyModal(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Syarat & Ketentuan',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Harap baca dengan saksama sebelum melanjutkan.',
                        textAlign: TextAlign.center,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. Syarat & Ketentuan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• Data yang Anda isi harus sesuai dengan dokumen resmi (KTP, KK, ijazah, dan dokumen pendukung lainnya) dan dapat dipertanggungjawabkan.\n\n'
                          '• Anda memberikan izin kepada perusahaan untuk menggunakan data ini dalam proses rekrutmen, pengolahan dokumen penempatan, dan pelaporan kepada instansi terkait.\n\n'
                          '• Apabila di kemudian hari ditemukan ketidaksesuaian atau pemalsuan data, perusahaan berhak membatalkan proses penempatan dan/atau melakukan tindakan lain sesuai ketentuan yang berlaku.\n\n'
                          '• Ketentuan lebih rinci mengenai proses penempatan kerja akan dijelaskan oleh petugas perusahaan dan/atau tercantum dalam dokumen perjanjian terpisah.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '2. Kebijakan Privasi',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• Data pribadi Anda akan disimpan dan diproses sesuai dengan ketentuan perlindungan data pribadi yang berlaku.\n\n'
                          '• Data hanya akan digunakan untuk keperluan proses rekrutmen, penempatan kerja, pemenuhan kewajiban hukum, dan peningkatan layanan perusahaan.\n\n'
                          '• Perusahaan tidak akan menjual atau membagikan data pribadi Anda kepada pihak ketiga yang tidak berkepentingan, kecuali diwajibkan oleh peraturan perundang-undangan atau dengan persetujuan Anda.\n\n'
                          '• Anda berhak mengajukan permintaan koreksi, pembaruan, atau penghapusan data sesuai dengan prosedur internal perusahaan dan ketentuan hukum yang berlaku.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cs.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            'Dengan melanjutkan, Anda menyatakan telah membaca, memahami, dan menyetujui Syarat & Ketentuan serta Kebijakan Privasi ini.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
