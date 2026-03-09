import { usePageTitle } from "@/hooks/use-page-title"

export function PrivacyPolicyPage() {
  usePageTitle("Kebijakan Privasi")

  return (
    <div className="min-h-svh bg-background text-foreground">
      {/* Header */}
      <header className="border-b bg-background/95 backdrop-blur sticky top-0 z-10">
        <div className="mx-auto max-w-3xl px-6 py-4 flex items-center gap-3">
          <span className="font-bold text-lg tracking-tight">KMS Connect</span>
          <span className="text-muted-foreground">/</span>
          <span className="text-muted-foreground text-sm">Kebijakan Privasi</span>
        </div>
      </header>

      {/* Content */}
      <main className="mx-auto max-w-3xl px-6 py-12 space-y-10">
        <div className="space-y-2">
          <h1 className="text-3xl font-bold tracking-tight">Kebijakan Privasi</h1>
          <p className="text-muted-foreground text-sm">
            Terakhir diperbarui: 9 Maret 2026
          </p>
        </div>

        <p className="text-muted-foreground leading-relaxed">
          PT. Karyatama Mitra Sejati ("kami") mengoperasikan aplikasi mobile dan web <strong>KMS Connect</strong>.
          Halaman ini menjelaskan bagaimana kami mengumpulkan, menggunakan, dan melindungi informasi
          pribadi Anda saat menggunakan layanan kami.
        </p>

        <Section title="1. Informasi yang Kami Kumpulkan">
          <p>Kami mengumpulkan informasi berikut saat Anda mendaftar dan menggunakan KMS Connect:</p>
          <ul>
            <li><strong>Identitas:</strong> nama lengkap, tanggal lahir, jenis kelamin, dan nomor KTP.</li>
            <li><strong>Kontak:</strong> alamat email dan nomor telepon.</li>
            <li><strong>Domisili:</strong> kota/kabupaten dan provinsi tempat tinggal.</li>
            <li><strong>Dokumen:</strong> foto KTP dan dokumen pendukung lainnya yang Anda unggah.</li>
            <li><strong>Akun Google:</strong> jika Anda masuk menggunakan Google Sign-In, kami menerima nama, alamat email, dan foto profil dari akun Google Anda.</li>
            <li><strong>Data perangkat:</strong> token notifikasi push (FCM) untuk mengirimkan pemberitahuan.</li>
            <li><strong>Log penggunaan:</strong> waktu masuk, aktivitas lamaran, dan status verifikasi.</li>
          </ul>
        </Section>

        <Section title="2. Cara Kami Menggunakan Informasi Anda">
          <p>Informasi yang dikumpulkan digunakan untuk:</p>
          <ul>
            <li>Memproses pendaftaran dan memverifikasi identitas pelamar.</li>
            <li>Mencocokkan pelamar dengan lowongan kerja yang sesuai.</li>
            <li>Mengirimkan notifikasi terkait status lamaran Anda (email dan push notification).</li>
            <li>Komunikasi resmi antara admin dan pelamar mengenai proses rekrutmen.</li>
            <li>Menghasilkan laporan internal untuk keperluan operasional rekrutmen.</li>
            <li>Mematuhi kewajiban hukum yang berlaku di Indonesia.</li>
          </ul>
        </Section>

        <Section title="3. Layanan Pihak Ketiga">
          <p>Kami menggunakan layanan pihak ketiga berikut yang memiliki kebijakan privasi masing-masing:</p>
          <ul>
            <li>
              <strong>Google Sign-In & Firebase</strong> — untuk autentikasi dan notifikasi push.{" "}
              <a
                href="https://policies.google.com/privacy"
                target="_blank"
                rel="noopener noreferrer"
                className="text-primary underline underline-offset-4"
              >
                Kebijakan Privasi Google
              </a>
            </li>
            <li>
              <strong>Google Cloud Vision API</strong> — untuk pembacaan data KTP (OCR) secara otomatis.
              Gambar KTP dikirim ke server Google untuk diproses dan tidak disimpan oleh Google.
            </li>
            <li>
              <strong>Amazon S3 / DigitalOcean Spaces</strong> — untuk penyimpanan dokumen yang Anda unggah.
            </li>
            <li>
              <strong>Mailgun</strong> — untuk pengiriman email transaksional (verifikasi, notifikasi).
            </li>
          </ul>
        </Section>

        <Section title="4. Penyimpanan dan Keamanan Data">
          <ul>
            <li>Data disimpan di server yang berlokasi di Singapore dan dikelola oleh penyedia cloud terpercaya.</li>
            <li>Seluruh komunikasi antara aplikasi dan server menggunakan enkripsi HTTPS/TLS.</li>
            <li>Password disimpan dalam bentuk hash menggunakan algoritma yang aman — kami tidak menyimpan password dalam bentuk teks biasa.</li>
            <li>Akses ke data dibatasi hanya kepada karyawan yang membutuhkannya untuk keperluan operasional.</li>
          </ul>
        </Section>

        <Section title="5. Berbagi Data">
          <p>
            Kami <strong>tidak menjual</strong> data pribadi Anda kepada pihak ketiga.
            Data hanya dibagikan kepada:
          </p>
          <ul>
            <li>Perusahaan mitra yang terlibat langsung dalam proses rekrutmen Anda, sebatas informasi yang diperlukan.</li>
            <li>Penyedia layanan teknis (tercantum di atas) yang membantu operasional platform.</li>
            <li>Otoritas hukum apabila diwajibkan oleh peraturan perundang-undangan yang berlaku.</li>
          </ul>
        </Section>

        <Section title="6. Hak Anda">
          <p>Anda memiliki hak untuk:</p>
          <ul>
            <li><strong>Mengakses</strong> data pribadi yang kami simpan tentang Anda.</li>
            <li><strong>Memperbarui</strong> data yang tidak akurat melalui halaman profil di aplikasi.</li>
            <li><strong>Menghapus akun</strong> dan data Anda dengan menghubungi kami (lihat bagian 9).</li>
            <li><strong>Menarik persetujuan</strong> untuk notifikasi push kapan saja melalui pengaturan aplikasi.</li>
          </ul>
        </Section>

        <Section title="7. Retensi Data">
          <p>
            Data akun aktif disimpan selama akun masih aktif. Jika Anda meminta penghapusan akun,
            data akan dihapus dalam waktu 30 hari, kecuali ada kewajiban hukum untuk menyimpannya lebih lama.
          </p>
        </Section>

        <Section title="8. Anak di Bawah Umur">
          <p>
            Layanan KMS Connect ditujukan untuk pengguna berusia <strong>18 tahun ke atas</strong>.
            Kami tidak secara sengaja mengumpulkan data dari pengguna di bawah 18 tahun.
          </p>
        </Section>

        <Section title="9. Hubungi Kami">
          <p>Jika Anda memiliki pertanyaan mengenai kebijakan privasi ini atau ingin menggunakan hak Anda, hubungi kami di:</p>
          <ul>
            <li><strong>Email:</strong> <a href="mailto:privacy@kms-connect.com" className="text-primary underline underline-offset-4">privacy@kms-connect.com</a></li>
            <li><strong>Perusahaan:</strong> PT. Karyatama Mitra Sejati</li>
            <li><strong>Kota:</strong> Medan, Sumatera Utara, Indonesia</li>
          </ul>
        </Section>

        <Section title="10. Perubahan Kebijakan">
          <p>
            Kami dapat memperbarui kebijakan ini sewaktu-waktu. Perubahan signifikan akan
            diberitahukan melalui email atau notifikasi di dalam aplikasi. Tanggal "Terakhir diperbarui"
            di bagian atas halaman ini akan selalu mencerminkan versi terkini.
          </p>
        </Section>
      </main>

      {/* Footer */}
      <footer className="border-t mt-16">
        <div className="mx-auto max-w-3xl px-6 py-6 text-center text-xs text-muted-foreground">
          © {new Date().getFullYear()} PT. Karyatama Mitra Sejati · KMS Connect
        </div>
      </footer>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-3">
      <h2 className="text-xl font-semibold tracking-tight">{title}</h2>
      <div className="text-muted-foreground leading-relaxed space-y-2 [&_ul]:list-disc [&_ul]:pl-5 [&_ul]:space-y-1">
        {children}
      </div>
    </section>
  )
}
