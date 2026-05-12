/**
 * Tahapan dengan biaya transport inbound (subset Diterima; tanpa Masuk Berkas Asli).
 * Sync with backend `account.inbound_transport_stages.INBOUND_TRANSPORT_STAGES`.
 */
export const INBOUND_TRANSPORT_STAGES = [
  ["MEDICAL", "Medical"],
  ["BUAT_ID_PEKERJA", "Buat ID Pekerja"],
  ["BUAT_PASPOR", "Buat Paspor"],
  ["FWCMS", "FWCMS"],
  ["PSIKOLOGI_TEST", "Psikologi Test"],
  ["PAP_BP3MI", "PAP BP3MI"],
  ["PDO_KILANG", "PDO Kilang"],
  ["PERSIAPAN_KEBERANGKATAN", "Persiapan Keberangkatan"],
] as const

export type InboundTransportStageCode =
  (typeof INBOUND_TRANSPORT_STAGES)[number][0]
