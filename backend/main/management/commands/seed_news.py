"""
Seed data berita (News).
Idempoten: update_or_create by slug, safe to run multiple times.

Usage:
    python manage.py seed_news
    python manage.py seed_news --clear   # Hapus semua berita seed sebelum membuat ulang
"""
from django.core.management.base import BaseCommand
from django.utils import timezone

from main.models import News, NewsStatus

# ---------------------------------------------------------------------------
# Data berita
# ---------------------------------------------------------------------------
NEWS_ITEMS = [
    # ── Pinned (unggulan + hero image placeholder) ──────────────────────
    {
        "title": "Program Penempatan TKI Taiwan 2026: Kuota 5.000 Pekerja Dibuka",
        "slug": "program-penempatan-tki-taiwan-2026",
        "summary": (
            "Pemerintah Indonesia bersama mitra perusahaan Taiwan membuka kuota "
            "5.000 pekerja migran untuk sektor manufaktur dan perawatan lansia "
            "tahun 2026. Pendaftaran dibuka mulai 1 Maret 2026."
        ),
        "content": (
            "JAKARTA — Badan Perlindungan Pekerja Migran Indonesia (BP2MI) resmi "
            "mengumumkan pembukaan program penempatan Tenaga Kerja Indonesia (TKI) "
            "ke Taiwan dengan kuota 5.000 pekerja untuk tahun 2026.\n\n"
            "Program ini mencakup dua sektor utama:\n\n"
            "1. **Sektor Manufaktur** — sebanyak 3.500 posisi tersedia di pabrik "
            "elektronik, tekstil, dan komponen otomotif di wilayah Taoyuan, "
            "Taichung, dan Kaohsiung.\n\n"
            "2. **Perawatan Lansia (Caregiver)** — 1.500 posisi untuk pendamping "
            "dan perawat lansia di rumah tangga maupun fasilitas kesehatan.\n\n"
            "Persyaratan Umum:\n"
            "- Usia minimal 21 tahun, maksimal 45 tahun\n"
            "- Pendidikan minimal SMA/SMK sederajat\n"
            "- Sehat jasmani dan rohani (dibuktikan dengan surat keterangan dokter)\n"
            "- Tidak memiliki catatan kriminal\n"
            "- Mampu berkomunikasi dalam bahasa Mandarin (nilai +)\n\n"
            "Proses seleksi akan dilakukan secara bertahap: seleksi berkas, "
            "tes kesehatan, pelatihan pra keberangkatan, dan wawancara dengan "
            "perusahaan pengguna.\n\n"
            "Untuk informasi lebih lanjut dan pendaftaran, hubungi KMS Connect "
            "atau datangi kantor BP2MI terdekat di kota Anda."
        ),
        "is_pinned": True,
        "status": NewsStatus.PUBLISHED,
        "days_ago": 2,
    },
    {
        "title": "Peringatan: Waspada Penipuan Berkedok Lowongan Kerja Luar Negeri",
        "slug": "peringatan-waspada-penipuan-lowongan-luar-negeri",
        "summary": (
            "BP2MI mengeluarkan peringatan resmi kepada calon TKI agar mewaspadai "
            "modus penipuan rekrutmen ilegal yang marak beredar di media sosial."
        ),
        "content": (
            "JAKARTA — Badan Perlindungan Pekerja Migran Indonesia (BP2MI) kembali "
            "mengeluarkan peringatan kepada seluruh calon pekerja migran mengenai "
            "maraknya penipuan berkedok lowongan kerja luar negeri.\n\n"
            "Modus operandi yang sering ditemukan:\n\n"
            "1. Menawarkan gaji sangat tinggi tanpa proses seleksi yang ketat\n"
            "2. Meminta biaya pendaftaran atau 'uang jaminan' di muka\n"
            "3. Menggunakan dokumen palsu atau visa wisata untuk berangkat kerja\n"
            "4. Menjanjikan keberangkatan dalam waktu singkat (1-2 minggu)\n\n"
            "Tips Aman:\n"
            "- Gunakan hanya perusahaan penempatan yang terdaftar di BP2MI\n"
            "- Jangan pernah membayar biaya di muka tanpa kontrak tertulis\n"
            "- Verifikasi lowongan melalui aplikasi resmi KMS Connect atau "
            "situs BP2MI\n"
            "- Laporkan penipuan ke hotline BP2MI: 1500-476\n\n"
            "Pemerintah mengimbau agar seluruh proses rekrutmen dilakukan secara "
            "resmi dan terdokumentasi. Penempatan ilegal berisiko membuat pekerja "
            "menjadi korban perdagangan orang (TPPO)."
        ),
        "is_pinned": True,
        "status": NewsStatus.PUBLISHED,
        "days_ago": 1,
    },
    # ── Regular news ────────────────────────────────────────────────────
    {
        "title": "Gaji TKI di Korea Selatan Naik 5% Sesuai UMR 2026",
        "slug": "gaji-tki-korea-selatan-naik-2026",
        "summary": (
            "Pemerintah Korea Selatan menetapkan Upah Minimum Regional (UMR) 2026 "
            "sebesar KRW 10.600/jam, naik 5,1% dari tahun sebelumnya."
        ),
        "content": (
            "SEOUL — Pemerintah Korea Selatan resmi menetapkan upah minimum tahun "
            "2026 sebesar KRW 10.600 per jam (sekitar Rp 127.000), naik 5,1% "
            "dibanding UMR 2025 sebesar KRW 10.090.\n\n"
            "Dampak bagi Pekerja Migran Indonesia:\n\n"
            "Dengan UMR baru, pekerja migran sektor manufaktur yang bekerja "
            "8 jam/hari, 5 hari/minggu dapat mengharapkan gaji pokok sekitar "
            "KRW 2.200.000/bulan (±Rp 26,4 juta).\n\n"
            "Dengan lembur rata-rata 20 jam/bulan, total penghasilan bisa "
            "mencapai KRW 2.600.000 (±Rp 31,2 juta).\n\n"
            "Program EPS (Employment Permit System) Tahun 2026:\n"
            "- Kuota Indonesia: 7.000 pekerja\n"
            "- Sektor: manufaktur, pertanian, peternakan, perikanan\n"
            "- Masa kerja: kontrak 3 tahun (dapat diperpanjang 1+1 tahun)\n\n"
            "Untuk mendaftar EPS 2026, calon pekerja wajib lulus ujian Bahasa "
            "Korea (TOPIK level 1 minimum) yang diselenggarakan oleh "
            "Human Resources Development Service of Korea (HRD Korea) bekerjasama "
            "dengan BP2MI."
        ),
        "is_pinned": False,
        "status": NewsStatus.PUBLISHED,
        "days_ago": 4,
    },
    {
        "title": "Panduan Dokumen Wajib Sebelum Berangkat ke Luar Negeri",
        "slug": "panduan-dokumen-wajib-sebelum-berangkat",
        "summary": (
            "Lengkapi dokumen Anda sebelum keberangkatan untuk menghindari "
            "keterlambatan atau penolakan di bandara. Berikut daftar dokumen wajib "
            "yang harus disiapkan setiap calon TKI."
        ),
        "content": (
            "Persiapan dokumen yang lengkap dan valid merupakan kunci kelancaran "
            "keberangkatan Anda sebagai pekerja migran. Berikut panduan lengkapnya:\n\n"
            "**Dokumen Identitas:**\n"
            "- KTP (Kartu Tanda Penduduk) — fotokopi + asli\n"
            "- Kartu Keluarga — fotokopi + asli\n"
            "- Paspor — valid minimal 1 tahun dari tanggal keberangkatan\n"
            "- Foto 4x6 background merah (10 lembar)\n\n"
            "**Dokumen Medis:**\n"
            "- Surat Keterangan Sehat dari Rumah Sakit/Klinik terakreditasi\n"
            "- Hasil tes HIV/AIDS dan Hepatitis B\n"
            "- Kartu BPJS Kesehatan\n\n"
            "**Dokumen Pendidikan & Keahlian:**\n"
            "- Ijazah terakhir (legalisir Dinas Pendidikan)\n"
            "- Sertifikat keterampilan/vokasi (jika ada)\n"
            "- Sertifikat bahasa (jika dipersyaratkan)\n\n"
            "**Dokumen Keluarga:**\n"
            "- Surat izin suami/orang tua/keluarga (bermaterai Rp10.000)\n"
            "- Akta nikah / Surat keterangan status perkawinan\n\n"
            "**Dokumen Kontrak & Keberangkatan:**\n"
            "- Perjanjian Penempatan (dari PPTKIS/BP2MI)\n"
            "- Perjanjian Kerja (dari perusahaan pengguna)\n"
            "- KTKLN (Kartu Tenaga Kerja Luar Negeri)\n\n"
            "Pastikan semua dokumen sudah dilegalisir dan masih berlaku. "
            "Upload dokumen Anda melalui aplikasi KMS Connect jauh sebelum "
            "jadwal keberangkatan."
        ),
        "is_pinned": False,
        "status": NewsStatus.PUBLISHED,
        "days_ago": 7,
    },
    {
        "title": "Tips Mengelola Keuangan Selama Bekerja di Luar Negeri",
        "slug": "tips-mengelola-keuangan-selama-kerja-luar-negeri",
        "summary": (
            "Penghasilan besar di luar negeri tidak selalu berarti pulang kaya. "
            "Pelajari strategi mengelola remitansi dan investasi sederhana untuk "
            "masa depan yang lebih baik."
        ),
        "content": (
            "Salah satu tantangan terbesar bagi pekerja migran adalah mengelola "
            "penghasilan agar memberikan manfaat jangka panjang bagi keluarga "
            "di Indonesia.\n\n"
            "**Prinsip 50-30-20:**\n\n"
            "Sebagai panduan dasar, gunakan aturan 50-30-20:\n"
            "- 50% untuk biaya hidup dan kebutuhan di negara penempatan\n"
            "- 30% untuk kiriman ke keluarga di Indonesia (remitansi)\n"
            "- 20% untuk tabungan/investasi pribadi\n\n"
            "**Remitansi yang Efisien:**\n\n"
            "Gunakan layanan transfer resmi seperti Western Union, MoneyGram, "
            "atau aplikasi GoPay/OVO yang sudah terdaftar BI. Hindari jasa "
            "'kurir uang' tidak resmi yang rawan penipuan.\n\n"
            "**Investasi Sederhana:**\n\n"
            "- Reksa dana pasar uang: risiko rendah, likuiditas tinggi\n"
            "- Deposito berjangka di bank BUMN\n"
            "- Tabungan emas melalui Pegadaian\n"
            "- Saham blue chip melalui sekuritas terpercaya\n\n"
            "**Rencana Purna Penempatan:**\n\n"
            "Sebelum kontrak berakhir, siapkan rencana usaha atau investasi di "
            "Indonesia. Program KUR (Kredit Usaha Rakyat) tersedia bagi pensiunan "
            "TKI dengan plafon hingga Rp 50 juta bunga rendah.\n\n"
            "Konsultasikan rencana keuangan Anda dengan petugas KMS Connect "
            "sebelum keberangkatan."
        ),
        "is_pinned": False,
        "status": NewsStatus.PUBLISHED,
        "days_ago": 10,
    },
    {
        "title": "Update: Persyaratan Visa Kerja Jepang untuk Pekerja Indonesia 2026",
        "slug": "persyaratan-visa-kerja-jepang-2026",
        "summary": (
            "Jepang memperbarui kebijakan visa Specified Skilled Worker (SSW) "
            "mulai April 2026. Pelajari perubahan aturan dan cara mempersiapkan diri."
        ),
        "content": (
            "TOKYO — Pemerintah Jepang merevisi regulasi program Specified Skilled "
            "Worker (SSW / Tokutei Ginou) yang mulai berlaku April 2026.\n\n"
            "**Perubahan Utama SSW 2026:**\n\n"
            "1. **Perpanjangan masa kerja SSW-1** — Dari 5 tahun menjadi 7 tahun, "
            "memberi waktu lebih bagi pekerja untuk memenuhi syarat SSW-2.\n\n"
            "2. **Penambahan sektor baru** — Sektor konstruksi, perawatan lansia, "
            "industri makanan-minuman, dan pertanian kini menerima lebih banyak "
            "kuota dari Indonesia.\n\n"
            "3. **Ujian bahasa Jepang** — Minimal JLPT N4 atau hasil tes JFT-Basic "
            "masih disyaratkan. Tersedia kelas persiapan di Balai Latihan Kerja "
            "(BLK) yang bermitra dengan KMS Connect.\n\n"
            "4. **Biaya penempatan** — Sesuai perjanjian bilateral Indonesia-Jepang, "
            "biaya penempatan ditanggung perusahaan pengguna. Calon pekerja TIDAK "
            "boleh dipungut biaya oleh agen.\n\n"
            "**Timeline Pendaftaran:**\n"
            "- Februari–Maret 2026: Seleksi berkas & tes kemampuan\n"
            "- April–Mei 2026: Tes kesehatan & wawancara perusahaan\n"
            "- Juni–Agustus 2026: Pelatihan pra-keberangkatan\n"
            "- September 2026: Keberangkatan batch pertama\n\n"
            "Daftar melalui KMS Connect dan ikuti seminar orientasi Jepang "
            "yang kami adakan setiap bulan."
        ),
        "is_pinned": False,
        "status": NewsStatus.PUBLISHED,
        "days_ago": 14,
    },
    {
        "title": "Peluncuran Fitur Pelacakan Status Dokumen di Aplikasi KMS Connect",
        "slug": "fitur-baru-pelacakan-status-dokumen",
        "summary": (
            "Aplikasi KMS Connect kini hadir dengan fitur tracking dokumen real-time "
            "sehingga Anda dapat memantau progress verifikasi berkas kapan saja."
        ),
        "content": (
            "KMS Connect dengan bangga mengumumkan peluncuran fitur **Pelacakan "
            "Status Dokumen** yang memungkinkan setiap calon pekerja migran "
            "memantau perkembangan berkas mereka secara langsung (real-time).\n\n"
            "**Cara Kerja Fitur Ini:**\n\n"
            "1. Login ke aplikasi KMS Connect\n"
            "2. Buka menu 'Dokumen Saya'\n"
            "3. Setiap dokumen menampilkan status: Diunggah → Sedang Diverifikasi "
            "→ Disetujui / Perlu Revisi\n"
            "4. Notifikasi push dikirim otomatis saat status berubah\n\n"
            "**Manfaat:**\n"
            "- Tidak perlu lagi menelepon kantor untuk menanyakan status\n"
            "- Revisi dokumen lebih cepat dengan feedback langsung dari petugas\n"
            "- Proses keberangkatan lebih transparan dan terarah\n\n"
            "Fitur ini tersedia di KMS Connect versi 2.1 ke atas. "
            "Perbarui aplikasi Anda melalui Google Play Store atau App Store.\n\n"
            "Kami terus berkomitmen untuk mempermudah perjalanan Anda menuju "
            "pekerjaan impian di luar negeri."
        ),
        "is_pinned": False,
        "status": NewsStatus.PUBLISHED,
        "days_ago": 20,
    },
    {
        "title": "Kisah Sukses: Dari TKI Taiwan Menjadi Pengusaha Sukses di Jawa Tengah",
        "slug": "kisah-sukses-tki-taiwan-jadi-pengusaha",
        "summary": (
            "Setelah 6 tahun bekerja di industri elektronik Taiwan, Budi Santoso "
            "kini memiliki usaha konveksi dengan 15 karyawan di Pekalongan."
        ),
        "content": (
            "PEKALONGAN — Kisah Budi Santoso (38) bisa menjadi inspirasi bagi "
            "para pekerja migran yang bermimpi membangun kehidupan lebih baik "
            "setelah pulang ke tanah air.\n\n"
            "Budi berangkat ke Taiwan pada 2016 melalui program penempatan resmi "
            "dengan gaji awal TWD 22.000/bulan. Selama 6 tahun, ia bekerja di "
            "pabrik komponen elektronik di Taoyuan sambil menyisihkan tabungan.\n\n"
            "**Strategi Budi:**\n\n"
            "\"Saya sisihkan 40% gaji setiap bulan, tidak tergiur beli barang "
            "mewah. Saya juga ikut kelas online bisnis konveksi selama malam hari "
            "di asrama,\" cerita Budi.\n\n"
            "Setelah mengumpulkan Rp 280 juta, Budi pulang ke Pekalongan dan "
            "membuka usaha konveksi kecil-kecilan. Kini usahanya sudah berkembang "
            "dengan 15 karyawan dan omzet Rp 80 juta/bulan.\n\n"
            "**Pesan untuk sesama TKI:**\n\n"
            "\"Kerja di luar negeri itu bukan tujuan akhir, tapi batu loncatan. "
            "Manfaatkan setiap rupiah dengan bijak, terus belajar, dan punya "
            "rencana jelas mau ngapain setelah pulang.\"\n\n"
            "KMS Connect bangga menjadi bagian dari perjalanan Budi dan ribuan "
            "pekerja migran Indonesia lainnya."
        ),
        "is_pinned": False,
        "status": NewsStatus.PUBLISHED,
        "days_ago": 30,
    },
]


class Command(BaseCommand):
    help = "Seed berita (News) — idempoten via update_or_create by slug."

    def add_arguments(self, parser):
        parser.add_argument(
            "--clear",
            action="store_true",
            help="Hapus semua berita yang dibuat oleh seed ini sebelum membuat ulang.",
        )

    def handle(self, *args, **options):
        if options["clear"]:
            slugs = [item["slug"] for item in NEWS_ITEMS]
            deleted, _ = News.objects.filter(slug__in=slugs).delete()
            self.stdout.write(f"  Deleted {deleted} existing seed news articles.\n")

        self.stdout.write("Seeding berita…\n")
        now = timezone.now()

        for item in NEWS_ITEMS:
            slug = item["slug"]
            published_at = now - timezone.timedelta(days=item.pop("days_ago", 0))

            obj, created = News.objects.update_or_create(
                slug=slug,
                defaults={
                    "title": item["title"],
                    "summary": item.get("summary", ""),
                    "content": item["content"],
                    "hero_image": None,  # No local images in seed; use placeholder
                    "status": item.get("status", NewsStatus.PUBLISHED),
                    "is_pinned": item.get("is_pinned", False),
                    "published_at": published_at,
                    "created_by": None,
                },
            )
            action = "Created" if created else "Updated"
            pin = " 📌" if obj.is_pinned else ""
            self.stdout.write(f"  {action}: [{obj.status}]{pin} {obj.title[:60]}")

        count = len(NEWS_ITEMS)
        self.stdout.write(self.style.SUCCESS(f"\nDone. {count} news articles seeded."))
