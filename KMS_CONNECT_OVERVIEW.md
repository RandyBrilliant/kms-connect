# KMS Connect: Project Briefing for Content Research

This briefing comes from a full read of the codebase (`kms-connect` repo, about 200 commits, Feb–Oct 2026). Use it as background on the product, its audience, its features and its brand voice. Each fact is marked as either **in the code** (verified) or **demo/seed content** (possibly not real).

---

## 1. What it is, in one paragraph

**KMS Connect** is the official digital recruitment platform of **PT. Karyatama Mitra Sejati**, a migrant-worker placement agency based in **Medan, North Sumatra (Sumatera Utara), Indonesia**. It recruits Indonesian migrant workers, known as **PMI (Pekerja Migran Indonesia)**. Candidates are called **CPMI (Calon PMI)**, and the older term is TKI. Placements are mainly in **factory jobs in Malaysia**: semiconductor, electronics, other factories and services.

Candidates use a free mobile app (Android + iOS) to register with their national ID card, fill in their data, upload documents and follow every stage from pre-selection to departure. They get push updates and can chat with the recruitment team. The agency's admins, field recruiters and partner employers run the process from a web dashboard.

**Core value proposition (official copy):** *"Lamaran kerja, dari ponsel."* ("Job applications, from your phone.") The supporting line says applicants can follow the process *"tanpa menunggu kabar lewat telepon"* ("without waiting for news by phone call").

---

## 2. Brand facts

| Item | Value |
|---|---|
| Product name | KMS Connect (sometimes written "KMS-Connect") |
| Company | PT. Karyatama Mitra Sejati, Medan, Sumatera Utara |
| Website / domains | kms-connect.com (API: data.kms-connect.com) |
| Contact email | privacy@kms-connect.com (no phone, WhatsApp or street address in the code) |
| App ID | `id.kmsconnect.app` |
| Google Play | https://play.google.com/store/apps/details?id=id.kmsconnect.app&hl=id |
| App Store | https://apps.apple.com/id/app/kms-connect/id6760560231 |
| App version | 1.0.26 (download page still says 1.0.25) |
| Requirements | Free · Android 7.0+ · iOS 16+ |
| Language | Bahasa Indonesia only |
| Taglines | "Platform Rekrutmen PMI" · "Mulai perjalanan karir profesional Anda" (Start your professional career journey) · "Aman dan Terpercaya" (Safe and Trusted) · "Aplikasi resmi PT. Karyatama Mitra Sejati" |

### Visual identity
- **Primary colour:** forest/dark green **#2B6E36**. The design docs say it was chosen to mean "Trust, Growth, Stability".
- **Gradient:** #1E5128 → #2B6E36 → #4E9F3D. Light green is #D4E9D7.
- **Accents:** trust blue #0066CC and premium gold #D4AF37 (used sparingly). Backgrounds are off-white (#F5F5F5 in the app, warm #F7F6F3 on the web download page).
- **Font:** **Plus Jakarta Sans** (bold 700/800 headings) in the app. The web uses the system sans font.
- **Logo:** a circular silver-white badge with a green ring and a dark-green **upward arrow**, which stands for growth and moving up.
- **Style:** green gradient wave headers, white rounded cards, clean and professional. The app was deliberately redesigned from a "playful" look (clouds, stars, bouncy animation) to a **"professional, trust-building"** one.

### Tone of voice
- Mostly formal, polite Indonesian ("Anda"), with a few casual "kamu/-mu" touches ("lamaranmu").
- Reassuring, transparent and procedural: it explains each stage clearly.

---

## 3. Target audience

**Primary: job seekers (applicants / "pelamar")**
- Indonesians aged **18–45** (enforced at sign-up) who want to work abroad.
- Education at junior/senior/vocational high school level (SMP/SMA/SMK/MA).
- Some have prior overseas experience (Saudi Arabia, Hong Kong, Taiwan, Japan, South Korea, Malaysia, Kuwait, Bahrain); others have never worked ("Belum Pernah Bekerja").
- Target industries: Semiconductor, Electronics, Other factory, Services.
- Likely concerns: fraud by illegal brokers, hidden fees, not knowing what stage they're at, long paperwork.

**Secondary (web dashboard, not public-facing)**
- **Staff / field recruiters ("Pemberi Rujukan")**: bring in candidates using a personal referral code, see their own referrals' progress and have a referral leaderboard.
- **Partner companies (employers)**: post jobs and see the applicants for their jobs.
- **Admins**: verify candidates, run selection, manage documents, send broadcasts.

---

## 4. Key messaging angles (strongest to weakest)

1. **Zero-cost placement.** At registration every applicant confirms this statement: *"Saya telah membaca dan memahami bahwa proses penempatan kerja menggunakan skema **zero cost**, di mana seluruh biaya proses resmi ditanggung oleh perusahaan sesuai ketentuan yang berlaku."* (I understand the placement process uses a zero-cost scheme: all official process costs are paid by the company.) The system also tracks **transport-cost refunds** to applicants at each processing stage.
2. **Official and legal, not a calo (broker).** "Aplikasi resmi" (official app). The process follows Indonesian government steps: BP3MI pre-departure orientation (PAP), SISKO registration, Disnaker (labour office) and SIP/Job Order permits. Demo news content includes fraud warnings from BP2MI.
3. **Transparency.** Every stage is visible in the app, with push notifications and status history, so applicants don't have to wait for a phone call.
4. **Convenience.** Scan your KTP and the app auto-fills your ID number (OCR). Upload documents once and reuse them. Download your own filled-in CV and biodata PDFs.
5. **Direct communication.** In-app chat with the recruitment team once accepted, plus announcements for each batch.
6. **Data safety.** "Kami tidak menjual data pribadi Anda" (we do not sell your personal data). Data is encrypted in transit and hosted in Singapore, and accounts can be deleted.

---

## 5. The applicant journey

### A. Getting started (mobile app)
1. **Download** the free app (Play Store / App Store).
2. **Register in two steps.**
   - Step 1: email, phone number and password.
   - Step 2: **photograph your KTP** (national ID). OCR reads the NIK automatically, and you confirm name, birthplace and birth date.
   - You can also choose the staff recruiter who referred you, or sign in with Google/Apple.
3. **Accept two declarations:** your data is true, and you understand the zero-cost scheme.
4. **Complete your biodata**, section by section: personal data, KTP address, family, spouse, heir/next of kin, education & physical details (height, weight, glasses, writing hand), document numbers and passport.
5. **Verify your email** with a 6-digit code.
6. **Upload your initial documents:** KTP, ijazah (diploma, PDF), Kartu Keluarga (family card), BPJS health card, passport and pas foto (passport-style photo). CV and skills certificate are optional.
7. **Wait for admin verification:** Dikirim (submitted) → Diterima (accepted) / Ditolak (rejected). Each document is reviewed separately.

### B. Selection and placement pipeline
Applicants do **not** self-apply. Admins assign eligible candidates to a job's selection batch, and each candidate has one active application at a time.

| # | Stage (Indonesian) | Meaning |
|---|---|---|
| 1 | **Pra-Seleksi** | Pre-selection. Can have several numbered stages (e.g. "Pra-Seleksi 1: CV Screening", psych test, group discussion). Applicant confirms attendance in the app. |
| 2 | **Interview** | Interview session (cohort) with date and location. Applicant confirms attendance. |
| 3 | **Cadangan** | Reserve list, promoted if a main slot opens ("Anda masuk daftar cadangan — menunggu konfirmasi slot"). |
| 4 | **Diterima** | Accepted. Followed by 9 processing steps (below). Chat with admin unlocks here. |
| 5 | **Berangkat** | Departed for Malaysia. |
| 6 | **Selesai** | Placement completed. |
| – | Ditolak / Dipindah | Rejected, or transferred to another job vacancy. |

**The 9 post-acceptance steps:**
1. Masuk Berkas Asli: hand in original documents
2. Medical: medical check-up (the app provides a referral letter)
3. Buat ID Pekerja: create worker ID
4. Buat Paspor: passport
5. FWCMS: registration in Malaysia's Foreign Workers Centralised Management System
6. Psikologi Test: psychology test (the app provides a referral letter)
7. PAP BP3MI: official pre-departure orientation by the provincial migrant-worker protection agency
8. PDO Kilang: pre-departure orientation for the factory ("kilang" is Malay for factory)
9. Persiapan Keberangkatan: departure preparation

**After-interview documents:** Surat Izin Keluarga ("Form Biru", the family consent letter), consent-giver statement, parent/guardian KTP, health certificate, marital-status statement, marriage book (optional), placement agreement and proof of document handover. The app includes downloadable templates for some of these.

**Reminders sent automatically:** departure in 7 days and in 1 day, job deadline approaching, new job posted, every status change, document rejected, and batch announcements.

---

## 6. App features (mobile; bottom tabs: Beranda · Lowongan · Lamaranku · Berita · Profil)

- **Beranda (Home / "Dashboard Karir"):**
  - Greeting by time of day.
  - **Profile completeness %** card and current application status card.
  - Quick actions (Jobs, Profile, Applications, Chat) and the latest announcements.
- **Lowongan (Jobs):** search, filter by type (full-time, part-time, contract, internship), country/city, salary range, requirements and deadline.
- **Lamaranku (My Applications):** the full pipeline tracker above, with schedules, locations, attendance confirmation, announcements and chat.
- **Berita (News & Announcements):** "Informasi terkini untuk karier dan rekrutmen Anda", with featured and announcement tags.
- **Profil:**
  - Verification badge (Terverifikasi / Menunggu Verifikasi / Belum Lengkap).
  - Biodata and work experience.
  - Downloads: biodata PDF, CV PDF and referral letters.
  - Notification settings, change password, delete account.
- **Documents:** a checklist in stages with statuses (Not uploaded / Waiting for review / Approved / Rejected / Locked) and a camera crop guide.
- **Notifications:** push plus an in-app inbox, in categories (Jobs, Applications, Documents, Profile, Announcements, System).
- **Chat:** real-time with the recruitment admin, one thread per application.
- **Other:** offline banner, force-update prompt, Indonesian province → village address pickers (83,000+ villages).

### Download page copy (verbatim, for reference)
- Eyebrow: **"Platform rekrutmen PMI"**
- Headline: **"Lamaran kerja, dari ponsel."**
- Subhead: *"Aplikasi resmi PT. Karyatama Mitra Sejati. Cari lowongan, kirim lamaran, dan ikuti proses seleksi tanpa menunggu kabar lewat telepon."*
- Four feature blurbs:
  - **01 Lowongan:** "Posisi, syarat, lokasi, dan batas pendaftaran, sebelum Anda melamar."
  - **02 Status:** "Pra-seleksi, interview, diterima, sampai penempatan. Diperbarui saat ada kabar."
  - **03 Dokumen:** "KTP dan ijazah PDF diunggah sekali, lalu dipakai untuk lamaran berikutnya."
  - **04 Kabar:** "Notifikasi status, pengumuman, dan chat langsung dengan tim rekrutmen."

---

## 7. Back-office features (web dashboard, internal)

- Dashboards: KPIs, 30-day applicant growth, daily registrations.
- Applicant verification, one at a time or in bulk, plus document review.
- Job postings, pre-selection batches, interview cohorts, bulk status moves.
- Generates the official forms automatically as PDFs:
  - Biodata CPMI
  - CV
  - Medical and psych-test referral letters
  - Transport-cost refund receipts ("Inbond")
- Excel export in the agency's own template format, plus reports by gender, status, education and top-referring staff.
- Broadcast push/email to selected user groups, and news publishing.
- Staff referral tracking and leaderboard.
- Audit log of every action. Account-deletion handling (deleted within 30 days, with a grace period).

---

## 8. Tech summary (only if needed for "how it's built" content)

- **Mobile:** Flutter (Android + iOS) with Riverpod, go_router, Firebase push, Google/Apple sign-in, camera + OCR flow and certificate pinning.
- **Web dashboard:** React 19 + TypeScript + Vite, Tailwind + shadcn/ui, hosted on Vercel.
- **Backend:** Django 6 + Django REST Framework, PostgreSQL, Redis, Celery (scheduled reminders), Django Channels (real-time chat WebSocket).
- **Services:**
  - Google Cloud Vision (KTP OCR)
  - Firebase Cloud Messaging (push)
  - Resend (email)
  - DigitalOcean Spaces in Singapore (file storage)
  - DigitalOcean droplet + Nginx + Docker
- Five user roles: Master Admin, Admin, Staff, Company, Applicant.

---

## 9. Glossary (Indonesian → English)

| Term | Meaning |
|---|---|
| PMI / CPMI / TKI | Indonesian migrant worker / prospective migrant worker / older term for migrant worker |
| Pelamar | Applicant |
| Lowongan Kerja | Job vacancy |
| Lamaran / Lamaranku | Application / My applications |
| Pra-Seleksi | Pre-selection |
| Diterima / Ditolak / Cadangan | Accepted / Rejected / Reserve list |
| Berangkat / Selesai | Departed / Completed |
| Berita / Pengumuman | News / Announcement |
| Pemberi Rujukan | Referrer (field recruiter) |
| KTP / NIK | National ID card / national ID number |
| KK (Kartu Keluarga) | Family card |
| Ijazah | School diploma |
| BPJS | National health/social insurance |
| Pas Foto | Passport-style photo |
| Ahli Waris | Heir / next of kin |
| Disnaker | Regional labour/manpower office |
| BP3MI / BP2MI | Provincial / national agency for migrant-worker protection (BP2MI is now part of the Ministry KP2MI) |
| PAP | Pre-departure orientation (official) |
| PDO Kilang | Pre-departure orientation for the factory |
| FWCMS | Malaysia's Foreign Workers Centralised Management System |
| Calling visa | Malaysian work-visa approval |
| SISKO | Indonesia's migrant-worker computerised system |
| SIP / JO | Recruitment permit / Job order |
| Surat Pengantar | Referral letter |
| Zero cost | Placement scheme in which the employer pays all official fees |

---

## 10. Caveats for the researcher

- **Malaysia is the only destination built into the code.** News items about Taiwan quotas, Korean wages and Japan jobs are **seed/demo content**, so don't present them as company offerings unless confirmed.
- Sample names ("MIRA SETIAWAN") and companies ("PT. MAJU JAYA", "PT Manpower Sejahtera Indonesia") are **test data**.
- The app's screenshots (March 2026) show an older login screen with "Lanjutkan dengan Google". Check the current store build before quoting UI copy.
- There are no public statistics in the code (placement numbers, years in operation, licence number). These need to come from the company.
- The code doesn't include the company's P3MI licence number, office address, phone or social media accounts. Ask the client for these if content needs them.
