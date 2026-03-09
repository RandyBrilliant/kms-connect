import { usePageTitle } from "@/hooks/use-page-title"

export function AccountDeletionPage() {
  usePageTitle("Penghapusan Akun — KMS Connect")

  return (
    <div className="min-h-svh bg-background text-foreground">
      {/* Header */}
      <header className="border-b bg-background/95 backdrop-blur sticky top-0 z-10">
        <div className="mx-auto max-w-3xl px-6 py-4 flex items-center gap-3">
          <span className="font-bold text-lg tracking-tight">KMS Connect</span>
          <span className="text-muted-foreground">/</span>
          <span className="text-muted-foreground text-sm">Penghapusan Akun</span>
        </div>
      </header>

      {/* Content */}
      <main className="mx-auto max-w-3xl px-6 py-12 space-y-10">
        <div className="space-y-2">
          <h1 className="text-3xl font-bold tracking-tight">Permintaan Penghapusan Akun</h1>
          <p className="text-muted-foreground text-sm">
            PT. Karyatama Mitra Sejati · Aplikasi KMS Connect
          </p>
        </div>

        <p className="text-muted-foreground leading-relaxed">
          Anda berhak meminta penghapusan akun dan data pribadi Anda dari platform{" "}
          <strong>KMS Connect</strong> yang dioperasikan oleh{" "}
          <strong>PT. Karyatama Mitra Sejati</strong>. Halaman ini menjelaskan cara
          mengajukan permintaan tersebut beserta rincian data yang akan dihapus atau
          dipertahankan.
        </p>

        {/* ------------------------------------------------------------------ */}
        <Section title="Cara Mengajukan Permintaan Penghapusan Akun">
          <p>Anda dapat mengajukan permintaan penghapusan akun melalui salah satu cara berikut:</p>

          <div className="space-y-4 mt-2">
            <OptionCard
              number="1"
              title="Melalui Aplikasi KMS Connect (Direkomendasikan)"
              steps={[
                "Masuk ke aplikasi KMS Connect.",
                "Buka menu Profil (ikon pengguna di sudut kanan atas).",
                'Gulir ke bawah dan ketuk "Hapus Akun".',
                "Isi alasan penghapusan (opsional), lalu konfirmasi permintaan.",
                "Tim admin akan meninjau permintaan dalam 7 hari kerja dan menginformasikan hasilnya melalui email.",
              ]}
            />

            <OptionCard
              number="2"
              title="Melalui Email"
              steps={[
                <>
                  Kirim email ke{" "}
                  <a
                    href="mailto:privacy@kms-connect.com"
                    className="text-primary underline underline-offset-4"
                  >
                    privacy@kms-connect.com
                  </a>{" "}
                  dengan subjek: <strong>Permintaan Penghapusan Akun</strong>.
                </>,
                "Cantumkan nama lengkap dan alamat email yang terdaftar pada akun Anda.",
                "Tim kami akan memverifikasi identitas Anda dan memproses permintaan dalam 7 hari kerja.",
              ]}
            />
          </div>
        </Section>

        {/* ------------------------------------------------------------------ */}
        <Section title="Data yang Akan Dihapus">
          <p>
            Setelah permintaan dikonfirmasi, data berikut akan dihapus secara permanen dalam{" "}
            <strong>30 hari</strong>:
          </p>
          <ul>
            <li>Informasi akun: nama, alamat email, nomor telepon, dan kata sandi (hash).</li>
            <li>Data profil: tanggal lahir, jenis kelamin, nomor KTP, dan foto profil.</li>
            <li>Domisili: kota/kabupaten dan provinsi tempat tinggal.</li>
            <li>Dokumen yang diunggah: foto KTP dan berkas pendukung lainnya.</li>
            <li>Riwayat pekerjaan yang Anda masukkan.</li>
            <li>Token notifikasi push (FCM) yang terkait dengan perangkat Anda.</li>
            <li>Data Google Sign-In yang tertaut (nama, email, foto profil dari Google).</li>
            <li>Preferensi notifikasi dan riwayat notifikasi.</li>
          </ul>
        </Section>

        {/* ------------------------------------------------------------------ */}
        <Section title="Data yang Mungkin Dipertahankan">
          <p>
            Beberapa data dapat dipertahankan lebih lama apabila diwajibkan oleh hukum atau
            diperlukan untuk kepentingan operasional yang sah:
          </p>
          <ul>
            <li>
              <strong>Catatan lamaran pekerjaan</strong> — riwayat lamaran dapat disimpan
              hingga <strong>1 tahun</strong> untuk keperluan audit rekrutmen internal
              perusahaan mitra.
            </li>
            <li>
              <strong>Log transaksi dan aktivitas</strong> — disimpan hingga{" "}
              <strong>90 hari</strong> untuk kebutuhan keamanan dan investigasi fraud.
            </li>
            <li>
              <strong>Kewajiban hukum</strong> — data yang harus disimpan berdasarkan
              peraturan perundang-undangan yang berlaku di Indonesia akan dipertahankan
              sesuai batas waktu yang ditentukan peraturan tersebut.
            </li>
          </ul>
          <p className="mt-2">
            Data yang dipertahankan tidak akan digunakan untuk tujuan pemasaran atau
            dibagikan kepada pihak ketiga.
          </p>
        </Section>

        {/* ------------------------------------------------------------------ */}
        <Section title="Masa Tunggu dan Pembatalan">
          <ul>
            <li>
              Permintaan penghapusan akan diproses dalam waktu <strong>30 hari</strong>{" "}
              sejak dikonfirmasi.
            </li>
            <li>
              Selama masa tunggu tersebut, Anda masih dapat membatalkan permintaan
              penghapusan dengan masuk kembali ke akun atau menghubungi kami melalui email.
            </li>
            <li>
              Setelah 30 hari, penghapusan bersifat <strong>permanen dan tidak dapat
              dibatalkan</strong>.
            </li>
          </ul>
        </Section>

        {/* ------------------------------------------------------------------ */}
        <Section title="Hubungi Kami">
          <p>
            Jika Anda memiliki pertanyaan atau butuh bantuan terkait permintaan penghapusan
            akun, hubungi kami di:
          </p>
          <ul>
            <li>
              <strong>Email:</strong>{" "}
              <a
                href="mailto:privacy@kms-connect.com"
                className="text-primary underline underline-offset-4"
              >
                privacy@kms-connect.com
              </a>
            </li>
            <li>
              <strong>Perusahaan:</strong> PT. Karyatama Mitra Sejati
            </li>
            <li>
              <strong>Kota:</strong> Medan, Sumatera Utara, Indonesia
            </li>
          </ul>
        </Section>
      </main>

      {/* Footer */}
      <footer className="border-t mt-16">
        <div className="mx-auto max-w-3xl px-6 py-6 text-center text-xs text-muted-foreground">
          © {new Date().getFullYear()} PT. Karyatama Mitra Sejati · KMS Connect ·{" "}
          <a href="/privacy" className="underline underline-offset-4">
            Kebijakan Privasi
          </a>
        </div>
      </footer>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Helpers
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

function OptionCard({
  number,
  title,
  steps,
}: {
  number: string
  title: string
  steps: React.ReactNode[]
}) {
  return (
    <div className="rounded-lg border bg-card p-5 space-y-3">
      <div className="flex items-center gap-3">
        <span className="inline-flex size-7 items-center justify-center rounded-full bg-primary text-primary-foreground text-sm font-bold">
          {number}
        </span>
        <h3 className="font-semibold text-foreground">{title}</h3>
      </div>
      <ol className="list-decimal pl-5 space-y-1 text-sm text-muted-foreground">
        {steps.map((step, i) => (
          <li key={i}>{step}</li>
        ))}
      </ol>
    </div>
  )
}
