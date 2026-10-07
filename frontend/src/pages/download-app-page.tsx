import type { ReactNode } from "react"
import { Link } from "react-router-dom"

import { usePageTitle } from "@/hooks/use-page-title"
import homeShot from "@/img/download/home.png"
import logo from "@/img/logo.png"
import loginShot from "@/img/download/login.png"

const APP_VERSION = "1.0.25"

const PLAY_STORE_URL =
  "https://play.google.com/store/apps/details?id=id.kmsconnect.app&hl=id"
const APP_STORE_URL = "https://apps.apple.com/id/app/kms-connect/id6760560231"

const STEPS = [
  {
    index: "01",
    title: "Lowongan",
    detail: "Posisi, syarat, lokasi, dan batas pendaftaran, sebelum Anda melamar.",
  },
  {
    index: "02",
    title: "Status",
    detail: "Pra-seleksi, interview, diterima, sampai penempatan. Diperbarui saat ada kabar.",
  },
  {
    index: "03",
    title: "Dokumen",
    detail: "KTP dan ijazah PDF diunggah sekali, lalu dipakai untuk lamaran berikutnya.",
  },
  {
    index: "04",
    title: "Kabar",
    detail: "Notifikasi status, pengumuman, dan chat langsung dengan tim rekrutmen.",
  },
] as const

export function DownloadAppPage() {
  usePageTitle("Download Aplikasi")

  return (
    <div className="min-h-svh bg-[#f7f6f3] text-[#1a1a1a]">
      <header className="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
        <div className="flex items-center gap-2.5">
          <img src={logo} alt="" className="size-8 object-contain" />
          <span className="text-sm font-semibold tracking-tight">KMS Connect</span>
        </div>
        <Link
          to="/privacy"
          className="text-sm text-[#5c5c5c] underline-offset-4 hover:text-[#1a1a1a] hover:underline"
        >
          Kebijakan Privasi
        </Link>
      </header>

      <main>
        <section className="mx-auto grid max-w-6xl items-end gap-14 px-6 pb-8 pt-8 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.05fr)] lg:pt-16">
          <div className="max-w-xl pb-4">
            <p className="text-sm font-medium text-[#2B6E36]">
              Platform rekrutmen PMI
            </p>
            <h1 className="mt-4 text-[2.75rem] font-semibold leading-[0.95] tracking-[-0.045em] sm:text-6xl lg:text-[4.25rem]">
              Lamaran kerja,
              <br />
              dari ponsel.
            </h1>
            <p className="mt-6 max-w-md text-[17px] leading-relaxed text-[#4a4a4a]">
              Aplikasi resmi PT. Karyatama Mitra Sejati. Cari lowongan,
              kirim lamaran, dan ikuti proses seleksi tanpa menunggu kabar
              lewat telepon.
            </p>

            <div className="mt-8 flex flex-wrap gap-3">
              <StoreBadge
                href={PLAY_STORE_URL}
                kicker="Dapatkan di"
                name="Google Play"
                icon={<PlayMark />}
              />
              <StoreBadge
                href={APP_STORE_URL}
                kicker="Unduh di"
                name="App Store"
                icon={<AppleMark />}
              />
            </div>

            <p className="mt-6 text-sm text-[#6b6b6b]">
              Versi {APP_VERSION}
              <span className="px-2 text-[#c4c4c4]">/</span>
              Gratis
              <span className="px-2 text-[#c4c4c4]">/</span>
              Android 7.0+
              <span className="px-2 text-[#c4c4c4]">/</span>
              iOS 16+
            </p>
          </div>

          <div className="relative mx-auto w-full max-w-xl">
            <div
              aria-hidden
              className="absolute inset-x-6 top-10 bottom-0 rounded-[2rem] bg-[#2B6E36]"
            />
            <div className="relative flex items-end justify-center gap-3 px-4 pt-16 sm:gap-5 sm:px-8">
              <img
                src={loginShot}
                alt="Layar masuk KMS Connect"
                className="mb-10 hidden w-[42%] rounded-[1.4rem] shadow-[0_20px_50px_-24px_rgba(0,0,0,0.55)] ring-1 ring-black/10 sm:block"
              />
              <img
                src={homeShot}
                alt="Beranda KMS Connect, dengan status lamaran dan pengumuman"
                className="w-[78%] rounded-[1.6rem] shadow-[0_28px_60px_-20px_rgba(0,0,0,0.45)] ring-1 ring-black/15 sm:w-[48%]"
              />
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-6xl px-6 pb-16 pt-20 sm:pb-20 sm:pt-24">
          <ul>
            {STEPS.map((step) => (
              <li
                key={step.index}
                className="grid grid-cols-[2.5rem_1fr] gap-x-4 border-t border-black/10 py-7 sm:grid-cols-[4rem_14rem_1fr] sm:items-baseline sm:gap-x-8 sm:py-8"
              >
                <span className="pt-1 text-sm tabular-nums text-[#2B6E36]">
                  {step.index}
                </span>
                <h2 className="text-2xl font-medium tracking-tight sm:text-[1.75rem]">
                  {step.title}
                </h2>
                <p className="col-start-2 mt-2 text-[15px] leading-relaxed text-[#4a4a4a] sm:col-start-3 sm:mt-0">
                  {step.detail}
                </p>
              </li>
            ))}
          </ul>
          <div className="border-t border-black/10" />
        </section>

        <section className="mx-auto flex max-w-6xl flex-col gap-8 px-6 pb-20 sm:flex-row sm:items-end sm:justify-between">
          <div className="max-w-xl">
            <p className="text-sm text-[#6b6b6b]">Versi {APP_VERSION}</p>
            <p className="mt-3 text-[15px] leading-relaxed text-[#4a4a4a]">
              Ijazah diunggah sebagai PDF, maksimal 2 MB. Pas Foto tidak lagi
              muncul dua kali. Unggah dokumen lebih stabil. Rilis yang sama di
              Google Play dan App Store.
            </p>
          </div>
          <div className="flex flex-wrap gap-3">
            <StoreBadge
              href={PLAY_STORE_URL}
              kicker="Dapatkan di"
              name="Google Play"
              icon={<PlayMark />}
            />
            <StoreBadge
              href={APP_STORE_URL}
              kicker="Unduh di"
              name="App Store"
              icon={<AppleMark />}
            />
          </div>
        </section>
      </main>

      <footer className="border-t border-black/10">
        <div className="mx-auto flex max-w-6xl flex-col gap-2 px-6 py-6 text-sm text-[#6b6b6b] sm:flex-row sm:items-center sm:justify-between">
          <p>© {new Date().getFullYear()} PT. Karyatama Mitra Sejati</p>
          <p>KMS Connect {APP_VERSION}</p>
        </div>
      </footer>
    </div>
  )
}

function StoreBadge({
  href,
  kicker,
  name,
  icon,
}: {
  href: string
  kicker: string
  name: string
  icon: ReactNode
}) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className="inline-flex items-center gap-3 rounded-xl bg-[#111] px-4 py-2.5 text-white transition-colors hover:bg-[#2a2a2a]"
    >
      {icon}
      <span className="text-left leading-none">
        <span className="block text-[10px] tracking-wide text-white/70">
          {kicker}
        </span>
        <span className="mt-1 block text-[15px] font-medium">{name}</span>
      </span>
    </a>
  )
}

function PlayMark() {
  return (
    <svg viewBox="0 0 24 24" className="size-6" aria-hidden>
      <path fill="#34A853" d="M3.5 20.6 13.2 12 3.5 3.4z" />
      <path fill="#FBBC04" d="m13.2 12 2.7 2.5-9.2 5.3z" />
      <path fill="#4285F4" d="M20.2 10.6 15.9 8.1 13.2 12l2.7 2.5 4.3-2.5c.7-.4.7-1.4 0-1.4z" />
      <path fill="#EA4335" d="M3.5 3.4 13.2 12l2.7-3.9L6.7 2.8c-.8-.5-1.8 0-2.2.6z" />
    </svg>
  )
}

function AppleMark() {
  return (
    <svg viewBox="0 0 24 24" className="size-6" aria-hidden>
      <path
        fill="currentColor"
        d="M16.4 12.6c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.2-2.8.8-3.5.8s-1.8-.8-3-.8c-1.5 0-3 .9-3.8 2.3-1.6 2.8-.4 7 1.2 9.3.8 1.1 1.7 2.3 2.9 2.3 1.2 0 1.6-.7 3-.7s1.8.7 3 .7 2-.1 2.9-2.3c.7-1 1.2-2.1 1.5-3.2-3.9-1.5-3.8-5.8-3.8-6.1zM14.7 6.2c.6-.8 1.1-1.9.9-3-1 .1-2.1.6-2.8 1.4-.6.7-1.2 1.8-1 2.9 1.1.1 2.2-.5 2.9-1.3z"
      />
    </svg>
  )
}
