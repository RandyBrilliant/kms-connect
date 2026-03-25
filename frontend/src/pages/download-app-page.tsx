import {
  IconBrandAndroid,
  IconDownload,
  IconShieldCheck,
  IconBell,
  IconBriefcase,
  IconUserCheck,
  IconMessageCircle,
  IconClockHour4,
  IconStarFilled,
  IconChevronRight,
  IconDeviceMobile,
  IconCheck,
  IconBrandApple,
} from "@tabler/icons-react"
import { usePageTitle } from "@/hooks/use-page-title"
import logo from "@/img/logo.png"

// ─── Configuration ────────────────────────────────────────────────────────────
const APK_DOWNLOAD_URL: string | null = "https://drive.google.com/drive/folders/1_MYWuuqusSMrAAIT2qYNdRIZdiXbh2tS?usp=sharing"
const APPLE_STORE_URL: string | null = "https://apps.apple.com/id/app/kms-connect/id6760560231"
const APP_VERSION = "1.0.0"
const APK_SIZE = "28 MB"
const MIN_ANDROID = "Android 8.0 (Oreo)"

// ─── Sub-components ───────────────────────────────────────────────────────────

function FeatureCard({
  icon: Icon,
  title,
  description,
}: {
  icon: React.ElementType
  title: string
  description: string
}) {
  return (
    <div className="group flex flex-col gap-3 rounded-2xl border border-white/10 bg-white/5 p-5 backdrop-blur-sm transition-all duration-300 hover:bg-white/10 hover:border-white/20">
      <div className="flex size-11 items-center justify-center rounded-xl bg-linear-to-br from-emerald-400/30 to-teal-400/30 ring-1 ring-emerald-400/20">
        <Icon className="size-5 text-emerald-300" stroke={1.8} />
      </div>
      <div>
        <h3 className="font-semibold text-white text-sm">{title}</h3>
        <p className="mt-1 text-xs leading-relaxed text-white/60">{description}</p>
      </div>
    </div>
  )
}

function RequirementRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between py-3 border-b border-white/10 last:border-0">
      <span className="text-sm text-white/50">{label}</span>
      <span className="text-sm font-medium text-white">{value}</span>
    </div>
  )
}

function StepBadge({ number, text }: { number: number; text: string }) {
  return (
    <div className="flex items-center gap-3">
      <div className="flex size-8 shrink-0 items-center justify-center rounded-full bg-linear-to-br from-emerald-500 to-teal-500 text-xs font-bold text-white shadow-lg shadow-emerald-500/25">
        {number}
      </div>
      <span className="text-sm text-white/80">{text}</span>
    </div>
  )
}

// ─── Main Page ────────────────────────────────────────────────────────────────

export function DownloadAppPage() {
  usePageTitle("Download Aplikasi")

  const handleDownload = () => {
    if (APK_DOWNLOAD_URL) {
      window.open(APK_DOWNLOAD_URL, "_blank", "noopener,noreferrer")
    }
  }

  const handleAppleStoreDownload = () => {
    if (APPLE_STORE_URL) {
      window.open(APPLE_STORE_URL, "_blank", "noopener,noreferrer")
    }
  }

  return (
    <div className="min-h-svh bg-[#0a0f1c] text-white">
      {/* ── Background decoration ─────────────────────────────────────────── */}
      <div
        aria-hidden
        className="pointer-events-none fixed inset-0 overflow-hidden"
      >
        {/* Radial glow top-left */}
        <div className="absolute -top-32 -left-32 size-150 rounded-full bg-emerald-600/15 blur-[120px]" />
        {/* Radial glow bottom-right */}
        <div className="absolute -bottom-32 -right-32 size-125 rounded-full bg-teal-600/15 blur-[120px]" />
        {/* Subtle grid */}
        <div
          className="absolute inset-0 opacity-[0.04]"
          style={{
            backgroundImage:
              "linear-gradient(rgba(255,255,255,0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.1) 1px, transparent 1px)",
            backgroundSize: "50px 50px",
          }}
        />
      </div>

      {/* ── Header ────────────────────────────────────────────────────────── */}
      <header className="relative z-10 border-b border-white/5 bg-white/2 backdrop-blur-md">
        <div className="mx-auto flex max-w-5xl items-center gap-3 px-6 py-4">
          <img src={logo} alt="KMS Connect" className="size-8 rounded-lg object-contain" />
          <span className="font-bold tracking-tight text-white">KMS Connect</span>
          <span className="ml-auto rounded-full border border-emerald-500/30 bg-emerald-500/10 px-3 py-1 text-xs font-medium text-emerald-400">
            v{APP_VERSION}
          </span>
        </div>
      </header>

      {/* ── Hero Section ─────────────────────────────────────────────────── */}
      <section className="relative z-10 mx-auto max-w-5xl px-6 pb-16 pt-20">
        <div className="flex flex-col items-center gap-10 lg:flex-row lg:items-start lg:gap-16">
          {/* Left: text + CTA */}
          <div className="flex flex-1 flex-col items-center text-center lg:items-start lg:text-left">
            {/* Badge */}
            <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-emerald-500/30 bg-emerald-500/10 px-4 py-2 text-sm text-emerald-400">
              <IconBrandAndroid className="size-4" />
              <span>Tersedia untuk Android</span>
              <span className="text-white/30">•</span>
              <IconBrandApple className="size-4" />
              <span>iOS</span>
            </div>

            <h1 className="text-4xl font-extrabold leading-tight tracking-tight sm:text-5xl">
              Download{" "}
              <span className="bg-linear-to-r from-emerald-400 to-teal-400 bg-clip-text text-transparent">
                KMS Connect
              </span>
              <br />
              Sekarang
            </h1>

            <p className="mt-5 max-w-lg text-base leading-relaxed text-white/60">
              Pantau status lamaran kerja Anda kapan saja dan di mana saja.
              Dapatkan notifikasi real-time, komunikasi langsung dengan tim
              rekrutmen, dan akses penuh ke semua fitur KMS.
            </p>

            {/* Rating */}
            <div className="mt-5 flex items-center gap-2">
              <div className="flex items-center gap-0.5">
                {Array.from({ length: 5 }).map((_, i) => (
                  <IconStarFilled key={i} className="size-4 text-amber-400" />
                ))}
              </div>
              <span className="text-sm text-white/50">
                Tersedia segera di Google Play Store
              </span>
            </div>

            {/* Download CTA */}
            <div className="mt-8 flex flex-col items-center gap-3 sm:flex-row lg:items-start">
              {APK_DOWNLOAD_URL ? (
                <button
                  onClick={handleDownload}
                  className="group flex items-center gap-3 rounded-2xl bg-linear-to-r from-emerald-500 to-teal-500 px-7 py-4 text-sm font-semibold text-white shadow-lg shadow-emerald-500/30 transition-all duration-200 hover:shadow-emerald-500/50 hover:scale-[1.02] active:scale-[0.98]"
                >
                  <IconBrandAndroid className="size-5 transition-transform duration-200 group-hover:-translate-y-0.5" />
                  Download Android
                  <IconChevronRight className="size-4 opacity-60" />
                </button>
              ) : (
                <div className="flex flex-col items-center gap-2 sm:flex-row sm:items-start lg:items-start">
                  <button
                    disabled
                    className="flex cursor-not-allowed items-center gap-3 rounded-2xl bg-linear-to-r from-emerald-500/50 to-teal-500/50 px-7 py-4 text-sm font-semibold text-white/60 shadow-lg"
                  >
                    <IconDownload className="size-5" />
                    Download APK
                    <IconChevronRight className="size-4 opacity-60" />
                  </button>
                  <div className="flex items-center gap-2 rounded-xl border border-amber-500/20 bg-amber-500/10 px-4 py-3 text-xs text-amber-400">
                    <IconClockHour4 className="size-4 shrink-0" />
                    <span>
                      Segera tersedia — menunggu persetujuan
                      <br className="hidden sm:block" /> Google Play Store
                    </span>
                  </div>
                </div>
              )}
              {APPLE_STORE_URL && (
                <button
                  onClick={handleAppleStoreDownload}
                  className="group flex items-center gap-3 rounded-2xl bg-linear-to-r from-gray-700 to-gray-800 px-7 py-4 text-sm font-semibold text-white shadow-lg shadow-gray-700/30 transition-all duration-200 hover:shadow-gray-700/50 hover:scale-[1.02] active:scale-[0.98]"
                >
                  <IconBrandApple className="size-5 transition-transform duration-200 group-hover:-translate-y-0.5" />
                  Download iOS
                  <IconChevronRight className="size-4 opacity-60" />
                </button>
              )}
            </div>

            {/* Trust badges */}
            <div className="mt-6 flex flex-wrap items-center justify-center gap-4 lg:justify-start">
              {[
                { icon: IconShieldCheck, text: "Aman & Terverifikasi" },
                { icon: IconBrandAndroid, text: "Android 8.0+" },
                { icon: IconCheck, text: "Gratis Selamanya" },
              ].map(({ icon: Icon, text }) => (
                <div key={text} className="flex items-center gap-1.5 text-xs text-white/40">
                  <Icon className="size-3.5 text-emerald-500" />
                  {text}
                </div>
              ))}
            </div>
          </div>

          {/* Right: phone mockup */}
          <div className="relative shrink-0">
            <div className="relative flex size-65 items-center justify-center sm:size-75">
              {/* Glow ring */}
              <div className="absolute inset-0 rounded-full bg-linear-to-br from-emerald-500/20 to-teal-500/20 blur-3xl" />
              {/* Phone frame */}
              <div className="relative flex h-65 w-32.5 flex-col overflow-hidden rounded-[2.5rem] border border-white/20 bg-linear-to-b from-white/10 to-white/5 shadow-2xl ring-1 ring-white/10 sm:h-75 sm:w-37.5">
                {/* Notch */}
                <div className="mx-auto mt-3 h-3 w-16 rounded-full bg-black/60" />
                {/* Screen content placeholder */}
                <div className="flex flex-1 flex-col items-center justify-center gap-3 p-3">
                  <img src={logo} alt="" className="size-14 rounded-2xl object-contain shadow-lg" />
                  <div className="space-y-1.5 w-full">
                    {[100, 85, 70].map((w) => (
                      <div
                        key={w}
                        className="h-2 rounded-full bg-linear-to-r from-emerald-500/40 to-teal-500/20"
                        style={{ width: `${w}%` }}
                      />
                    ))}
                  </div>
                  <div className="mt-2 flex w-full items-center justify-center rounded-xl bg-linear-to-r from-emerald-500/30 to-teal-500/30 py-2.5">
                    <IconDeviceMobile className="size-4 text-emerald-400 mr-1" />
                    <span className="text-[10px] font-medium text-emerald-300">KMS Connect</span>
                  </div>
                </div>
              </div>
              {/* Floating notification bubble */}
              <div className="absolute -right-4 top-8 flex items-center gap-2 rounded-xl border border-white/10 bg-white/10 px-3 py-2 text-[11px] font-medium text-white shadow-xl backdrop-blur-md">
                <div className="size-2 rounded-full bg-emerald-400 animate-pulse" />
                Lamaran Disetujui!
              </div>
              {/* Floating message bubble */}
              <div className="absolute -left-4 bottom-12 flex items-center gap-2 rounded-xl border border-white/10 bg-white/10 px-3 py-2 text-[11px] font-medium text-white shadow-xl backdrop-blur-md">
                <IconMessageCircle className="size-3.5 text-teal-400" />
                Pesan Baru
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── Features ─────────────────────────────────────────────────────── */}
      <section className="relative z-10 mx-auto max-w-5xl px-6 pb-20">
        <div className="mb-8 text-center">
          <h2 className="text-2xl font-bold">Fitur Unggulan</h2>
          <p className="mt-2 text-sm text-white/50">
            Semua yang Anda butuhkan ada di satu aplikasi
          </p>
        </div>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <FeatureCard
            icon={IconBriefcase}
            title="Pantau Lamaran Kerja"
            description="Lihat status lamaran Anda secara real-time — dari pengajuan hingga penerimaan."
          />
          <FeatureCard
            icon={IconBell}
            title="Notifikasi Real-Time"
            description="Dapatkan pemberitahuan instan setiap ada update terkait lamaran atau rekrutmen Anda."
          />
          <FeatureCard
            icon={IconUserCheck}
            title="Profil & Biodata Lengkap"
            description="Kelola profil dan unggah dokumen penting langsung dari smartphone Anda."
          />
          <FeatureCard
            icon={IconMessageCircle}
            title="Chat Langsung"
            description="Berkomunikasi langsung dengan tim rekrutmen KMS tanpa perlu keluar dari aplikasi."
          />
          <FeatureCard
            icon={IconShieldCheck}
            title="Keamanan Data"
            description="Data Anda dilindungi dengan enkripsi end-to-end dan standar keamanan industri."
          />
          <FeatureCard
            icon={IconClockHour4}
            title="Akses 24/7"
            description="Cek status lamaran kapan saja dan di mana saja, tanpa batasan waktu."
          />
        </div>
      </section>

      {/* ── Installation Guide + Requirements ────────────────────────────── */}
      <section className="relative z-10 mx-auto max-w-5xl px-6 pb-20">
        <div className="grid gap-6 lg:grid-cols-2">
          {/* How to install */}
          <div className="rounded-2xl border border-white/10 bg-white/5 p-6 backdrop-blur-sm">
            <h2 className="mb-6 text-lg font-bold">Cara Install APK</h2>
            <div className="flex flex-col gap-4">
              <StepBadge
                number={1}
                text='Download file APK menggunakan tombol "Download APK" di atas.'
              />
              <StepBadge
                number={2}
                text='Buka Pengaturan → Keamanan → Aktifkan "Sumber Tidak Dikenal" (Unknown Sources).'
              />
              <StepBadge
                number={3}
                text="Buka file APK yang telah diunduh dari folder Downloads."
              />
              <StepBadge
                number={4}
                text='Ketuk "Install" dan tunggu proses instalasi selesai.'
              />
              <StepBadge
                number={5}
                text="Buka aplikasi KMS Connect dan login dengan akun Anda."
              />
            </div>
            <div className="mt-6 rounded-xl border border-amber-500/20 bg-amber-500/10 p-4 text-xs leading-relaxed text-amber-300/80">
              <strong className="text-amber-400">Mengapa izin "Sumber Tidak Dikenal"?</strong>
              <br />
              Karena aplikasi ini belum tersedia di Play Store, Anda perlu mengizinkan
              instalasi dari luar toko secara sementara. Aplikasi ini aman dan berasal
              langsung dari PT. Karyatama Mitra Sejati.
            </div>
          </div>

          {/* Requirements */}
          <div className="rounded-2xl border border-white/10 bg-white/5 p-6 backdrop-blur-sm">
            <h2 className="mb-6 text-lg font-bold">Persyaratan Sistem</h2>
            <div className="divide-white/5">
              <RequirementRow label="Sistem Operasi" value={MIN_ANDROID} />
              <RequirementRow label="Ukuran File" value={APK_SIZE} />
              <RequirementRow label="Versi Aplikasi" value={`v${APP_VERSION}`} />
              <RequirementRow label="Koneksi Internet" value="Diperlukan" />
              <RequirementRow label="Platform" value="Android & iOS" />
              <RequirementRow label="iOS (iPhone)" value="Tersedia di App Store" />
            </div>

            {/* Store Status */}
            <div className="mt-6 flex flex-col gap-3">
              <div className="flex items-center gap-4 rounded-xl border border-white/10 bg-white/5 p-4">
                <div className="flex size-12 shrink-0 items-center justify-center rounded-xl bg-white/10">
                  <IconBrandAndroid className="size-6 text-emerald-400" />
                </div>
                <div>
                  <p className="text-sm font-semibold text-white">Google Play Store</p>
                  <p className="mt-0.5 text-xs text-white/50">
                    Dalam proses review — segera tersedia
                  </p>
                </div>
                <div className="ml-auto rounded-full border border-amber-400/30 bg-amber-400/10 px-2.5 py-1 text-[11px] font-medium text-amber-400">
                  Pending
                </div>
              </div>
              {APPLE_STORE_URL && (
                <div className="flex items-center gap-4 rounded-xl border border-emerald-500/20 bg-emerald-500/10 p-4">
                  <div className="flex size-12 shrink-0 items-center justify-center rounded-xl bg-white/10">
                    <IconBrandApple className="size-6 text-emerald-400" />
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-white">Apple App Store</p>
                    <p className="mt-0.5 text-xs text-white/50">
                      Tersedia sekarang — download gratis
                    </p>
                  </div>
                  <div className="ml-auto rounded-full border border-emerald-400/30 bg-emerald-400/10 px-2.5 py-1 text-[11px] font-medium text-emerald-400">
                    Live
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </section>

      {/* ── Bottom CTA ───────────────────────────────────────────────────── */}
      <section className="relative z-10 mx-auto max-w-5xl px-6 pb-24">
        <div className="overflow-hidden rounded-3xl bg-linear-to-br from-emerald-600/30 to-teal-600/20 p-10 text-center ring-1 ring-white/10">
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 rounded-3xl bg-linear-to-br from-emerald-500/10 to-transparent"
          />
          <h2 className="text-2xl font-bold">
            Siap Memulai Karir Anda?
          </h2>
          <p className="mt-3 text-sm text-white/60">
            Download aplikasi KMS Connect dan pantau perjalanan rekrutmen Anda
            dari mana saja.
          </p>
          <div className="mt-8 flex flex-col gap-3 items-center sm:flex-row sm:justify-center">
            {APK_DOWNLOAD_URL ? (
              <button
                onClick={handleDownload}
                className="inline-flex items-center gap-3 rounded-2xl bg-linear-to-r from-emerald-500 to-teal-500 px-8 py-4 text-sm font-semibold text-white shadow-lg shadow-emerald-500/30 transition-all duration-200 hover:scale-[1.02] hover:shadow-emerald-500/50 active:scale-[0.98]"
              >
                <IconBrandAndroid className="size-5" />
                Download Android
              </button>
            ) : (
              <div className="inline-flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-5 py-3 text-sm text-white/50">
                <IconClockHour4 className="size-4" />
                Link download akan segera tersedia
              </div>
            )}
            {APPLE_STORE_URL && (
              <button
                onClick={handleAppleStoreDownload}
                className="inline-flex items-center gap-3 rounded-2xl bg-linear-to-r from-gray-700 to-gray-800 px-8 py-4 text-sm font-semibold text-white shadow-lg shadow-gray-700/30 transition-all duration-200 hover:scale-[1.02] hover:shadow-gray-700/50 active:scale-[0.98]"
              >
                <IconBrandApple className="size-5" />
                Download iOS
              </button>
            )}
          </div>
        </div>
      </section>

      {/* ── Footer ───────────────────────────────────────────────────────── */}
      <footer className="relative z-10 border-t border-white/5 py-8">
        <div className="mx-auto flex max-w-5xl flex-col items-center gap-2 px-6 text-center">
          <div className="flex items-center gap-2">
            <img src={logo} alt="KMS Connect" className="size-5 rounded object-contain opacity-60" />
            <span className="text-sm font-medium text-white/40">KMS Connect</span>
          </div>
          <p className="text-xs text-white/30">
            &copy; {new Date().getFullYear()} PT. Karyatama Mitra Sejati. Seluruh hak cipta dilindungi.
          </p>
          <p className="text-xs text-white/20">
            Versi {APP_VERSION} &middot; {MIN_ANDROID}+
          </p>
        </div>
      </footer>
    </div>
  )
}
