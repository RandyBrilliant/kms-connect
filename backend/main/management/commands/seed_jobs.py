"""
Seed lowongan kerja (LowonganKerja).
Idempoten: update_or_create by slug, safe to run multiple times.
Depends on seed_companies (requires at least one CompanyProfile).

Usage:
    python manage.py seed_jobs
    python manage.py seed_jobs --clear   # Hapus semua lowongan seed sebelum membuat ulang

    # Run companies first if not yet seeded:
    python manage.py seed_companies && python manage.py seed_jobs
"""
from django.core.management.base import BaseCommand
from django.utils import timezone

from account.models import CompanyProfile
from main.models import EmploymentType, JobStatus, LowonganKerja

# ---------------------------------------------------------------------------
# Data lowongan kerja
# company_email references emails defined in seed_companies.COMPANIES
# ---------------------------------------------------------------------------
JOB_LISTINGS = [
    # ── PT Manpower Sejahtera ─────────────────────────────────────────────
    {
        "slug": "operator-pabrik-elektronik-taiwan-2026",
        "company_email": "pt.manpower.sejahtera@example.com",
        "title": "Operator Pabrik Elektronik — Taiwan",
        "location_country": "Taiwan",
        "location_city": "Taoyuan",
        "employment_type": EmploymentType.CONTRACT,
        "salary_min": 22000,
        "salary_max": 28000,
        "currency": "TWD",
        "description": (
            "Kami membuka kesempatan bagi calon pekerja migran Indonesia untuk "
            "posisi Operator Lini Produksi di pabrik komponen elektronik di Taoyuan, "
            "Taiwan. Tugas utama meliputi perakitan komponen, pemeriksaan kualitas "
            "(QC), dan pengoperasian mesin produksi semi-otomatis.\n\n"
            "Jam kerja normal 8 jam/hari (5 hari/minggu) dengan overtime tersedia. "
            "Akomodasi asrama disediakan oleh perusahaan dengan biaya Rp 500.000/bulan "
            "dipotong dari gaji. Makan siang di kafetaria pabrik bersubsidi."
        ),
        "requirements": (
            "- Pria/Wanita, usia 21–40 tahun\n"
            "- Pendidikan minimal SMA/SMK sederajat\n"
            "- Sehat jasmani dan rohani, tidak buta warna\n"
            "- Bersedia bekerja shift dan lembur\n"
            "- Tidak memiliki tato permanen yang terlihat\n"
            "- Menyiapkan dokumen lengkap (KTP, KK, Paspor, Ijazah, Surat Sehat)\n"
            "- Diutamakan berpengalaman di bidang manufaktur/teknik"
        ),
        "status": JobStatus.OPEN,
        "posted_days_ago": 3,
        "deadline_days_ahead": 45,
    },
    {
        "slug": "caregiver-lansia-taiwan-2026",
        "company_email": "pt.manpower.sejahtera@example.com",
        "title": "Caregiver Perawatan Lansia — Taiwan",
        "location_country": "Taiwan",
        "location_city": "Taipei",
        "employment_type": EmploymentType.CONTRACT,
        "salary_min": 20280,
        "salary_max": 24000,
        "currency": "TWD",
        "description": (
            "Posisi Caregiver (pengasuh lansia) untuk mendampingi dan merawat "
            "orang tua/lanjut usia di rumah tangga Taiwan. Pekerjaan meliputi "
            "pendampingan harian, membantu mandi, makan, mobilitas, serta "
            "memberikan teman ngobrol bagi lansia.\n\n"
            "Kontrak awal 2 tahun dengan kemungkinan perpanjangan. Tinggal bersama "
            "keluarga majikan. Satu hari libur per minggu."
        ),
        "requirements": (
            "- Wanita, usia 21–45 tahun\n"
            "- Pendidikan minimal SMP/SMA sederajat\n"
            "- Berpengalaman merawat lansia/anak kecil (diutamakan)\n"
            "- Sabar, teliti, dan memiliki empati tinggi\n"
            "- Sehat fisik dan mental\n"
            "- Mampu berkomunikasi dasar dalam bahasa Mandarin (nilai +)\n"
            "- Tidak merokok\n"
            "- Sertifikat keperawatan/kebidanan menjadi nilai tambah"
        ),
        "status": JobStatus.OPEN,
        "posted_days_ago": 5,
        "deadline_days_ahead": 30,
    },
    # ── Global Wira Recruitment (Malaysia) ───────────────────────────────
    {
        "slug": "buruh-perladangan-kelapa-sawit-sabah-2026",
        "company_email": "global.wira.recruitment@example.com",
        "title": "Buruh Perladangan Kelapa Sawit — Sabah, Malaysia",
        "location_country": "Malaysia",
        "location_city": "Sabah",
        "employment_type": EmploymentType.CONTRACT,
        "salary_min": 1500,
        "salary_max": 2200,
        "currency": "MYR",
        "description": (
            "Tenaga perladangan untuk perkebunan kelapa sawit di Sabah, Malaysia. "
            "Tugas meliputi pemanenan tandan buah segar (TBS), pemupukan, dan "
            "perawatan tanaman. Termasuk perumahan di camp perkebunan dan "
            "transportasi antar lokasi."
        ),
        "requirements": (
            "- Pria, usia 20–45 tahun\n"
            "- Pendidikan minimal SMP sederajat\n"
            "- Fisik kuat, bersedia bekerja di lapangan terbuka\n"
            "- Tidak ada riwayat sakit berat (jantung, asma berat)\n"
            "- Bersedia tinggal di camp perkebunan\n"
            "- Pengalaman bertani/perkebunan menjadi nilai tambah"
        ),
        "status": JobStatus.OPEN,
        "posted_days_ago": 7,
        "deadline_days_ahead": 60,
    },
    {
        "slug": "pekerja-konstruksi-kuala-lumpur-2026",
        "company_email": "global.wira.recruitment@example.com",
        "title": "Pekerja Konstruksi Bangunan — Kuala Lumpur",
        "location_country": "Malaysia",
        "location_city": "Kuala Lumpur",
        "employment_type": EmploymentType.CONTRACT,
        "salary_min": 1800,
        "salary_max": 2500,
        "currency": "MYR",
        "description": (
            "Pekerja konstruksi (tukang besi, tukang batu, atau helper) untuk "
            "proyek gedung bertingkat di Kuala Lumpur. Jadwal proyek 18 bulan "
            "dengan kemungkinan perpanjangan. Akomodasi dan transportasi disediakan."
        ),
        "requirements": (
            "- Pria, usia 20–45 tahun\n"
            "- Berpengalaman di bidang konstruksi (tukang besi/batu/cat/plester)\n"
            "- Tidak takut ketinggian\n"
            "- Sehat jasmani, tidak ada penyakit fisik berat\n"
            "- Dapat berbahasa Melayu atau Inggris dasar\n"
            "- Memiliki CIDB Card (nilai tambah)"
        ),
        "status": JobStatus.OPEN,
        "posted_days_ago": 10,
        "deadline_days_ahead": 40,
    },
    # ── Asia Pacific Staffing (Taiwan) ────────────────────────────────────
    {
        "slug": "operator-mesin-cnc-taichung-taiwan",
        "company_email": "asia.pacific.staffing@example.com",
        "title": "Operator Mesin CNC — Taichung, Taiwan",
        "location_country": "Taiwan",
        "location_city": "Taichung",
        "employment_type": EmploymentType.FULL_TIME,
        "salary_min": 25000,
        "salary_max": 35000,
        "currency": "TWD",
        "description": (
            "Operator mesin CNC (Computer Numerical Control) untuk pabrik "
            "komponen otomotif presisi di Taichung Industrial Park. "
            "Tanggungjawab meliputi setup mesin, operasi produksi, quality "
            "inspection, dan pemeliharaan mesin level 1.\n\n"
            "Jam kerja: 2 shift (07.00–19.00 / 19.00–07.00). Overtime 20+ jam/bulan "
            "tersedia. Gaji lembur 1,33x rate normal."
        ),
        "requirements": (
            "- Pria/Wanita, usia 20–38 tahun\n"
            "- Pendidikan minimal SMK (Teknik Mesin/Teknik Pemesinan/Teknik Produksi)\n"
            "- Berpengalaman mengoperasikan mesin CNC Turning/Milling minimal 1 tahun\n"
            "- Mampu membaca gambar teknik (engineering drawing)\n"
            "- Familiar dengan sistem CAD/CAM menjadi nilai tambah\n"
            "- Sehat, tidak buta warna, tidak berkacamata tebal (>6 dioptri)\n"
            "- Bersedia bekerja shift malam"
        ),
        "status": JobStatus.OPEN,
        "posted_days_ago": 2,
        "deadline_days_ahead": 50,
    },
    # ── Hong Kong Domestic Workers Agency ─────────────────────────────────
    {
        "slug": "asisten-rumah-tangga-hong-kong-2026",
        "company_email": "hongkong.helpers.agency@example.com",
        "title": "Asisten Rumah Tangga (ART) — Hong Kong",
        "location_country": "Hong Kong",
        "location_city": "Hong Kong",
        "employment_type": EmploymentType.CONTRACT,
        "salary_min": 4870,
        "salary_max": 5500,
        "currency": "HKD",
        "description": (
            "Asisten Rumah Tangga (ART/Domestic Helper) untuk keluarga di "
            "Hong Kong. Tugas meliputi memasak, membersihkan rumah, merawat "
            "anak dan/atau lansia, serta pekerjaan rumah tangga umum.\n\n"
            "Kebijakan pemerintah Hong Kong: gaji minimum ART HKD 4.870/bulan, "
            "akomodasi layak, satu hari libur per minggu, tiket PP ke Indonesia "
            "setelah kontrak 2 tahun selesai."
        ),
        "requirements": (
            "- Wanita, usia 21–45 tahun\n"
            "- Pendidikan minimal SMP sederajat (SMA lebih diutamakan)\n"
            "- Dapat berbahasa Inggris dasar (komunikasi sehari-hari)\n"
            "- Berpengalaman memasak, membersihkan rumah, merawat anak/lansia\n"
            "- Sehat jasmani dan rohani\n"
            "- Berpenampilan rapi dan bersedia tinggal di rumah majikan\n"
            "- Tidak memiliki catatan kriminal"
        ),
        "status": JobStatus.OPEN,
        "posted_days_ago": 6,
        "deadline_days_ahead": 35,
    },
    # ── Al-Jawad Middle East ───────────────────────────────────────────────
    {
        "slug": "cleaning-service-hospital-riyadh-2026",
        "company_email": "middle.east.placement@example.com",
        "title": "Cleaning Service — RS King Abdulaziz, Riyadh",
        "location_country": "Saudi Arabia",
        "location_city": "Riyadh",
        "employment_type": EmploymentType.CONTRACT,
        "salary_min": 1200,
        "salary_max": 1500,
        "currency": "SAR",
        "description": (
            "Petugas kebersihan (cleaning service) untuk Rumah Sakit King "
            "Abdulaziz di Riyadh, Arab Saudi. Pekerjaan meliputi pembersihan "
            "ruang rawat, koridor, dan area umum sesuai standar kebersihan "
            "fasilitas medis.\n\n"
            "Gaji dibayar bulanan + akomodasi asrama + makan 3x sehari. "
            "Tiket PP Indonesia–Arab Saudi ditanggung perusahaan."
        ),
        "requirements": (
            "- Pria/Wanita, usia 21–45 tahun\n"
            "- Pendidikan minimal SMP sederajat\n"
            "- Sehat jasmani dan rohani\n"
            "- Tidak keberatan bekerja di lingkungan rumah sakit\n"
            "- Bersedia bekerja shift dan menaati peraturan fasilitas medis\n"
            "- Bebas HIV/AIDS, Hepatitis B, dan TBC aktif (dibuktikan tes medis)\n"
            "- Muslim diutamakan (sesuai aturan instansi)"
        ),
        "status": JobStatus.OPEN,
        "posted_days_ago": 8,
        "deadline_days_ahead": 55,
    },
    # ── Korindo Labor Corp (Korea) ────────────────────────────────────────
    {
        "slug": "pekerja-pabrik-baja-incheon-korea-2026",
        "company_email": "korindo.labor.corp@example.com",
        "title": "Pekerja Pabrik Baja — Incheon, Korea Selatan",
        "location_country": "South Korea",
        "location_city": "Incheon",
        "employment_type": EmploymentType.CONTRACT,
        "salary_min": 2200000,
        "salary_max": 2800000,
        "currency": "KRW",
        "description": (
            "Pekerja produksi di pabrik baja (steel mill) di Incheon Industrial "
            "Complex, Korea Selatan. Posisi tersedia: operator tungku, material "
            "handler, dan quality inspector.\n\n"
            "Program EPS (Employment Permit System) — kontrak awal 3 tahun, "
            "dapat diperpanjang 1+1 tahun. Akomodasi asrama disediakan di kawasan "
            "pabrik dengan biaya KRW 200.000/bulan."
        ),
        "requirements": (
            "- Pria, usia 21–39 tahun\n"
            "- Pendidikan minimal SMA/SMK (Teknik diutamakan)\n"
            "- Lulus tes bahasa Korea (EPS-TOPIK) — jadwal tesdiatur BP2MI\n"
            "- Sehat fisik, tidak memiliki penyakit kronis\n"
            "- Bersedia bekerja di lingkungan panas dan bising\n"
            "- Tidak ada penyakit kulit menular\n"
            "- Menyertakan SKCK (Surat Keterangan Catatan Kepolisian)"
        ),
        "status": JobStatus.OPEN,
        "posted_days_ago": 4,
        "deadline_days_ahead": 60,
    },
    {
        "slug": "magang-teknisi-otomotif-seoul-korea-2026",
        "company_email": "korindo.labor.corp@example.com",
        "title": "Magang Teknisi Bengkel Otomotif — Seoul",
        "location_country": "South Korea",
        "location_city": "Seoul",
        "employment_type": EmploymentType.INTERNSHIP,
        "salary_min": 1800000,
        "salary_max": 2100000,
        "currency": "KRW",
        "description": (
            "Program magang teknis (Technical Internship) di bengkel otomotif "
            "jaringan Hyundai/Kia bersertifikat. Peserta akan mempelajari "
            "diagnostik kendaraan, tune-up, hingga perbaikan komponen mayor "
            "di bawah bimbingan mekanik senior bersertifikat Korea.\n\n"
            "Durasi magang 12 bulan. Sertifikat kompetensi dikeluarkan oleh "
            "Korea Chamber of Commerce and Industry (KCCI) yang diakui secara "
            "internasional."
        ),
        "requirements": (
            "- Pria, usia 19–28 tahun\n"
            "- Lulus SMK Teknik Otomotif atau D3 Teknik Mesin\n"
            "- IPK/nilai rata-rata minimal 7.5 (dari skala 10)\n"
            "- Menguasai perawatan dasar kendaraan bermotor\n"
            "- Komunikatif dan mau belajar hal baru\n"
            "- Nilai bahasa Korea (EPS-TOPIK atau TOPIK I) menjadi nilai +"
        ),
        "status": JobStatus.OPEN,
        "posted_days_ago": 1,
        "deadline_days_ahead": 28,
    },
]


class Command(BaseCommand):
    help = "Seed lowongan kerja (LowonganKerja) — requires seed_companies first."

    def add_arguments(self, parser):
        parser.add_argument(
            "--clear",
            action="store_true",
            help="Hapus semua lowongan seed sebelum membuat ulang.",
        )

    def handle(self, *args, **options):
        if options["clear"]:
            slugs = [item["slug"] for item in JOB_LISTINGS]
            deleted, _ = LowonganKerja.objects.filter(slug__in=slugs).delete()
            self.stdout.write(f"  Deleted {deleted} existing seed job listings.\n")

        # Build email→CompanyProfile lookup
        company_emails = {item["company_email"] for item in JOB_LISTINGS}
        company_map: dict[str, CompanyProfile] = {}
        missing: list[str] = []

        for email in company_emails:
            try:
                company_map[email] = CompanyProfile.objects.get(user__email=email)
            except CompanyProfile.DoesNotExist:
                missing.append(email)

        if missing:
            self.stderr.write(
                self.style.ERROR(
                    f"Missing CompanyProfile for: {', '.join(missing)}\n"
                    "Run `python manage.py seed_companies` first."
                )
            )
            return

        self.stdout.write("Seeding lowongan kerja…\n")
        now = timezone.now()

        for item in JOB_LISTINGS:
            slug = item["slug"]
            posted_at = now - timezone.timedelta(days=item.pop("posted_days_ago", 0))
            deadline = now + timezone.timedelta(days=item.pop("deadline_days_ahead", 30))
            company = company_map[item.pop("company_email")]

            obj, created = LowonganKerja.objects.update_or_create(
                slug=slug,
                defaults={
                    "title": item["title"],
                    "company": company,
                    "location_country": item.get("location_country", ""),
                    "location_city": item.get("location_city", ""),
                    "description": item.get("description", ""),
                    "requirements": item.get("requirements", ""),
                    "employment_type": item.get("employment_type", EmploymentType.FULL_TIME),
                    "salary_min": item.get("salary_min"),
                    "salary_max": item.get("salary_max"),
                    "currency": item.get("currency", "IDR"),
                    "status": item.get("status", JobStatus.OPEN),
                    "posted_at": posted_at,
                    "deadline": deadline,
                    "created_by": None,
                },
            )
            action = "Created" if created else "Updated"
            self.stdout.write(
                f"  {action}: [{obj.get_status_display()}] "
                f"{obj.title} ({company.company_name[:30]}…)"
            )

        count = len(JOB_LISTINGS)
        self.stdout.write(self.style.SUCCESS(f"\nDone. {count} job listings seeded."))
