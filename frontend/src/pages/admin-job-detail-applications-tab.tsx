/**
 * Downstream status tabs (Cadangan / Diterima / Berangkat / Selesai / Ditolak).
 * Lazily imported from the job detail page so the 1.5k-line table UI is its own chunk.
 */

import { useEffect, useMemo, useState } from "react"
import { useNavigate } from "react-router-dom"
import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import {
  IconClipboardList,
  IconExternalLink,
  IconEye,
  IconFileSpreadsheet,
  IconSearch,
} from "@tabler/icons-react"

import { ApplicantAdminProcessDialog } from "@/components/applicants/applicant-admin-process-dialog"
import { ApplicantDetailPreviewDialog } from "@/components/batches/applicant-detail-preview-dialog"
import { ApplicationStatusBadge } from "@/components/applications/application-status-badge"
import { BulkFwcmsPsikotesCard } from "@/components/applications/bulk-fwcms-psikotes-card"
import { BulkMedicalSmlCard } from "@/components/applications/bulk-medical-sml-card"
import { BulkReferralPdfButton } from "@/components/applications/bulk-referral-pdf-button"
import {
  formatDiterimaDate,
  MedicalHasilPill,
  PassportBerkasLink,
  PassportDetailBlock,
  PelamarTahapanSesiCell,
} from "@/components/applications/diterima-shared-cells"
import { DocumentCollectionProgressCell } from "@/components/applications/document-collection-progress-cell"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Checkbox } from "@/components/ui/checkbox"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { useDebounce } from "@/hooks/use-debounce"
import { toast } from "@/lib/toast"
import { getBatches } from "@/api/batches"
import { getInterviewCohorts } from "@/api/interview-cohorts"
import {
  bulkAdvanceDiterimaStep,
  bulkTransitionApplications,
  exportApplicationsExcel,
  getApplications,
} from "@/api/applications"
import { createBroadcast, sendBroadcast } from "@/api/notifications"
import { bulkAdminProcessApplicants } from "@/api/applicants"
import {
  DITERIMA_LAST_STEP,
  DOCUMENT_COLLECTION_STEP_LABELS,
  DOCUMENT_COLLECTION_STEP_ORDER,
  type ApplicationStatus,
  type DocumentCollectionStepCode,
} from "@/types/job-applications"
import {
  APPLICATIONS_TAB_PAGE_SIZE,
  EMPTY_APPLICATION_RESULTS,
  JOB_DETAIL_TABLE_SHELL,
  JD_BODY_ROW,
  JD_HEADER_ROW,
  JobDetailPagination,
  formatDate,
} from "./admin-job-detail-shared"

export function ApplicationsTab({
  jobId,
  status,
  batchBase,
  cohortBase,
  pelamarBase,
  enabled = true,
}: {
  jobId: number
  status: ApplicationStatus
  batchBase: string
  cohortBase: string
  pelamarBase: string
  enabled?: boolean
}) {
  const navigate = useNavigate()
  const [page, setPage] = useState(1)
  const [stageSearch, setStageSearch] = useState("")
  const [previewUserId, setPreviewUserId] = useState<number | null>(null)
  const [previewUserLabel, setPreviewUserLabel] = useState("")
  const [processUserId, setProcessUserId] = useState<number | null>(null)
  const [processUserLabel, setProcessUserLabel] = useState("")
  const [selectedApplicantUsers, setSelectedApplicantUsers] = useState<Set<number>>(
    new Set()
  )
  const [announcementTitle, setAnnouncementTitle] = useState("")
  const [announcementBody, setAnnouncementBody] = useState("")
  const [confirmAnnouncementOpen, setConfirmAnnouncementOpen] = useState(false)
  const [isExporting, setIsExporting] = useState(false)
  const [selectedDiterimaStep, setSelectedDiterimaStep] = useState<"ALL" | DocumentCollectionStepCode>(
    "ALL"
  )
  const [batchFilterId, setBatchFilterId] = useState<number | null>(null)
  const [cohortFilterId, setCohortFilterId] = useState<number | null>(null)
  // Selection state for the admin "advance to next sub-step" action.
  // Only active when viewing a specific (non-ALL) DITERIMA sub-step tab.
  const [selectedAdvanceAppIds, setSelectedAdvanceAppIds] = useState<Set<number>>(new Set())
  const [isAdvancing, setIsAdvancing] = useState(false)
  const [bulkTglMedical, setBulkTglMedical] = useState<Date | undefined>(undefined)
  const [bulkHasilMedical, setBulkHasilMedical] = useState("")
  const [bulkTglBayarSml, setBulkTglBayarSml] = useState<Date | undefined>(undefined)
  const [bulkTglFwcmPsikotes, setBulkTglFwcmPsikotes] = useState<Date | undefined>(undefined)
  const [bulkTglBayarPsikotes, setBulkTglBayarPsikotes] = useState<Date | undefined>(undefined)
  const queryClient = useQueryClient()

  const debouncedStageSearch = useDebounce(stageSearch, 400)

  const showDiterimaBatchCohortFilters = status === "DITERIMA"

  const { data: batchFilterData } = useQuery({
    queryKey: ["batches", { job: jobId, select: "diterima-filter" }],
    queryFn: () =>
      getBatches({
        job: jobId,
        page_size: 200,
        ordering: "tahap_order,created_at",
      }),
    enabled: enabled && showDiterimaBatchCohortFilters,
  })

  const { data: cohortFilterData } = useQuery({
    queryKey: ["interview-cohorts", { job: jobId, select: "diterima-filter" }],
    queryFn: () =>
      getInterviewCohorts({
        job: jobId,
        page_size: 200,
        ordering: "-interview_date,-created_at",
      }),
    enabled: enabled && showDiterimaBatchCohortFilters,
  })

  const batchFilterOptions = batchFilterData?.results ?? []
  const cohortFilterOptions = cohortFilterData?.results ?? []

  useEffect(() => {
    setPage(1)
  }, [debouncedStageSearch, batchFilterId, cohortFilterId, selectedDiterimaStep])

  const { data, isLoading, isFetching } = useQuery({
    queryKey: [
      "applications",
      {
        job: jobId,
        status,
        page,
        search: debouncedStageSearch,
        diterima_step: selectedDiterimaStep,
        batch: batchFilterId,
        interview_cohort: cohortFilterId,
      },
    ],
    queryFn: () =>
      getApplications({
        job: jobId,
        status,
        diterima_step:
          status === "DITERIMA" && selectedDiterimaStep !== "ALL"
            ? selectedDiterimaStep
            : undefined,
        batch: batchFilterId ?? undefined,
        interview_cohort: cohortFilterId ?? undefined,
        page,
        page_size: APPLICATIONS_TAB_PAGE_SIZE,
        search: debouncedStageSearch.trim() || undefined,
        ordering: "applicant_name",
      }),
    enabled,
    placeholderData: keepPreviousData,
  })

  const totalCount = data?.count ?? 0
  const pageCount = Math.max(1, Math.ceil(totalCount / APPLICATIONS_TAB_PAGE_SIZE))
  const currentPage = Math.min(page, pageCount)

  useEffect(() => {
    setPage((p) => Math.min(p, pageCount))
  }, [pageCount])

  const filteredApps = data?.results ?? EMPTY_APPLICATION_RESULTS
  const showCohortCol = status !== "DITOLAK"
  const showDocCol = status === "DITERIMA" && selectedDiterimaStep !== "ALL"
  const isMedicalDiterimaStep =
    status === "DITERIMA" && selectedDiterimaStep === "MEDICAL"
  const isPsikologiTestDiterimaStep =
    status === "DITERIMA" && selectedDiterimaStep === "PSIKOLOGI_TEST"
  const isFwcmsOrPsikologiDiterimaStep =
    status === "DITERIMA" &&
    (selectedDiterimaStep === "FWCMS" || selectedDiterimaStep === "PSIKOLOGI_TEST")
  const isBuatIdPekerjaDiterimaStep =
    status === "DITERIMA" && selectedDiterimaStep === "BUAT_ID_PEKERJA"
  const isBuatPasporDiterimaStep =
    status === "DITERIMA" && selectedDiterimaStep === "BUAT_PASPOR"
  const showDocColEffective =
    showDocCol &&
    !isMedicalDiterimaStep &&
    !isFwcmsOrPsikologiDiterimaStep &&
    !isBuatIdPekerjaDiterimaStep &&
    !isBuatPasporDiterimaStep
  const showCohortColEffective =
    showCohortCol &&
    !isMedicalDiterimaStep &&
    !isFwcmsOrPsikologiDiterimaStep &&
    !isBuatIdPekerjaDiterimaStep &&
    !isBuatPasporDiterimaStep
  const showDiterimaStepFilter = status === "DITERIMA"
  const diterimaStepOptions = useMemo(
    () =>
      DOCUMENT_COLLECTION_STEP_ORDER.map(
        (code) => [code, DOCUMENT_COLLECTION_STEP_LABELS[code]] as [DocumentCollectionStepCode, string]
      ),
    []
  )

  // Whether we're on a specific (non-ALL) DITERIMA sub-step tab.
  const onDiterimaSubStep =
    status === "DITERIMA" && selectedDiterimaStep !== "ALL"
  const isLastDiterimaStep = selectedDiterimaStep === DITERIMA_LAST_STEP
  const nextDiterimaStepLabel = useMemo(() => {
    if (!onDiterimaSubStep || isLastDiterimaStep) return null
    const idx = DOCUMENT_COLLECTION_STEP_ORDER.indexOf(
      selectedDiterimaStep as DocumentCollectionStepCode
    )
    if (idx < 0 || idx >= DOCUMENT_COLLECTION_STEP_ORDER.length - 1) return null
    return DOCUMENT_COLLECTION_STEP_LABELS[DOCUMENT_COLLECTION_STEP_ORDER[idx + 1]]
  }, [onDiterimaSubStep, isLastDiterimaStep, selectedDiterimaStep])

  const enableAcceptedAnnouncement = status === "DITERIMA" && !onDiterimaSubStep
  const selectableApplicantUsers = filteredApps
    .map((a) => a.applicant_user)
    .filter((v): v is number => typeof v === "number")
  const allSelectableChecked =
    selectableApplicantUsers.length > 0 &&
    selectableApplicantUsers.every((id) => selectedApplicantUsers.has(id))

  // Advance-action selection helpers (sub-step tabs only).
  const selectableAdvanceIds = filteredApps.map((a) => a.id)
  const allAdvanceChecked =
    selectableAdvanceIds.length > 0 &&
    selectableAdvanceIds.every((id) => selectedAdvanceAppIds.has(id))
  const toggleSelectAllAdvance = () => {
    setSelectedAdvanceAppIds((prev) => {
      const next = new Set(prev)
      if (allAdvanceChecked) {
        selectableAdvanceIds.forEach((id) => next.delete(id))
      } else {
        selectableAdvanceIds.forEach((id) => next.add(id))
      }
      return next
    })
  }
  const toggleSelectAdvance = (appId: number) => {
    setSelectedAdvanceAppIds((prev) => {
      const next = new Set(prev)
      if (next.has(appId)) next.delete(appId)
      else next.add(appId)
      return next
    })
  }
  const selectedAdvanceApplicantUserIds = useMemo(() => {
    const ids: number[] = []
    const seen = new Set<number>()
    for (const app of filteredApps) {
      if (
        selectedAdvanceAppIds.has(app.id) &&
        typeof app.applicant_user === "number" &&
        !seen.has(app.applicant_user)
      ) {
        seen.add(app.applicant_user)
        ids.push(app.applicant_user)
      }
    }
    return ids
  }, [filteredApps, selectedAdvanceAppIds])
  const selectedRecipientIds = Array.from(selectedApplicantUsers)
  const selectedRecipientNames = filteredApps
    .filter(
      (app) =>
        typeof app.applicant_user === "number" &&
        selectedApplicantUsers.has(app.applicant_user)
    )
    .map((app) => app.applicant_name)
  const canSendAnnouncement =
    selectedRecipientIds.length > 0 &&
    announcementTitle.trim().length > 0 &&
    announcementBody.trim().length > 0
  const showCheckboxCol = onDiterimaSubStep || enableAcceptedAnnouncement
  const emptyColSpan = isMedicalDiterimaStep
    ? (showCheckboxCol ? 1 : 0) + 6
    : isFwcmsOrPsikologiDiterimaStep
      ? (showCheckboxCol ? 1 : 0) + 5
    : isBuatIdPekerjaDiterimaStep
      ? (showCheckboxCol ? 1 : 0) + 4
      : isBuatPasporDiterimaStep
        ? (showCheckboxCol ? 1 : 0) + 5
        : 5 +
          (showCohortColEffective ? 1 : 0) +
          (showDocColEffective ? 1 : 0) +
          (showCheckboxCol ? 1 : 0)

  const handleExportExcel = async () => {
    setIsExporting(true)
    try {
      await exportApplicationsExcel(
        {
          job: jobId,
          status,
          diterima_step:
            status === "DITERIMA" && selectedDiterimaStep !== "ALL"
              ? selectedDiterimaStep
              : undefined,
          batch: batchFilterId ?? undefined,
          interview_cohort: cohortFilterId ?? undefined,
          search: debouncedStageSearch.trim() || undefined,
          ordering: "applicant_name",
        },
        `pelamar_${status.toLowerCase()}${
          status === "DITERIMA" && selectedDiterimaStep !== "ALL"
            ? `_${selectedDiterimaStep.toLowerCase()}`
            : ""
        }.xlsx`
      )
      toast.success("File Excel berhasil diunduh.")
    } catch {
      toast.error("Gagal mengunduh data Excel.")
    } finally {
      setIsExporting(false)
    }
  }

  const handleAdvanceDiterimaStep = async () => {
    const ids = Array.from(selectedAdvanceAppIds)
    if (!ids.length) return
    setIsAdvancing(true)
    try {
      if (isLastDiterimaStep) {
        // Transition to master BERANGKAT status using the existing bulk endpoint.
        await bulkTransitionApplications({ application_ids: ids, status: "BERANGKAT", note: "" })
        toast.success(`${ids.length} pelamar dipindahkan ke tahap Berangkat.`)
      } else {
        const result = await bulkAdvanceDiterimaStep(ids)
        const count = result.advanced.length
        const skipped = result.skipped.length
        if (count > 0) {
          toast.success(
            `${count} pelamar dipindahkan ke ${nextDiterimaStepLabel ?? "sub-tahapan berikutnya"}.` +
              (skipped > 0 ? ` ${skipped} dilewati.` : "")
          )
        } else {
          toast.error("Tidak ada pelamar yang berhasil dipindahkan.")
        }
      }
      await queryClient.invalidateQueries({
        queryKey: ["applications", { job: jobId, status }],
        exact: false,
      })
      setSelectedAdvanceAppIds(new Set())
    } catch (err: unknown) {
      const detail = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail
      toast.error("Gagal memindahkan pelamar", detail ?? "Coba lagi nanti.")
    } finally {
      setIsAdvancing(false)
    }
  }

  const handleRejectFromDiterimaSubStep = async () => {
    const ids = Array.from(selectedAdvanceAppIds)
    if (!ids.length) return
    setIsAdvancing(true)
    try {
      await bulkTransitionApplications({ application_ids: ids, status: "DITOLAK", note: "" })
      toast.success(`${ids.length} pelamar dipindahkan ke tahap Ditolak.`)
      await queryClient.invalidateQueries({
        queryKey: ["applications", { job: jobId, status }],
        exact: false,
      })
      setSelectedAdvanceAppIds(new Set())
    } catch (err: unknown) {
      const detail = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail
      toast.error("Gagal memindahkan pelamar ke Ditolak", detail ?? "Coba lagi nanti.")
    } finally {
      setIsAdvancing(false)
    }
  }

  const onBulkAdminProcessError = (err: unknown) => {
    const detail = (err as { response?: { data?: { detail?: string } } })?.response
      ?.data?.detail
    toast.error("Gagal memperbarui data", detail ?? "Coba lagi nanti.")
  }

  const bulkMedicalMutation = useMutation({
    mutationFn: bulkAdminProcessApplicants,
    onSuccess: async (result) => {
      await queryClient.invalidateQueries({
        queryKey: ["applications", { job: jobId, status }],
        exact: false,
      })
      toast.success(
        "Data proses diperbarui",
        `${result.updated_count} profil pelamar diperbarui.`
      )
      setBulkTglMedical(undefined)
      setBulkHasilMedical("")
      setBulkTglBayarSml(undefined)
    },
    onError: onBulkAdminProcessError,
  })

  const bulkFwcmsMutation = useMutation({
    mutationFn: bulkAdminProcessApplicants,
    onSuccess: async (result) => {
      await queryClient.invalidateQueries({
        queryKey: ["applications", { job: jobId, status }],
        exact: false,
      })
      toast.success(
        "Data proses diperbarui",
        `${result.updated_count} profil pelamar diperbarui.`
      )
      setBulkTglFwcmPsikotes(undefined)
      setBulkTglBayarPsikotes(undefined)
    },
    onError: onBulkAdminProcessError,
  })

  const handleBulkMedicalApply = () => {
    const applicantIds = filteredApps
      .filter((a) => selectedAdvanceAppIds.has(a.id) && a.applicant_user)
      .map((a) => a.applicant_user as number)
    if (!applicantIds.length) {
      toast.error("Pilih pelamar", "Centang minimal satu pelamar di tabel.")
      return
    }
    const payload: Parameters<typeof bulkAdminProcessApplicants>[0] = {
      applicant_user_ids: applicantIds,
    }
    if (bulkTglMedical) {
      payload.tgl_medical = format(bulkTglMedical, "yyyy-MM-dd")
    }
    if (bulkHasilMedical) {
      payload.hasil_medical = bulkHasilMedical
    }
    if (bulkTglBayarSml) {
      payload.tgl_bayar_sml = format(bulkTglBayarSml, "yyyy-MM-dd")
    }
    if (Object.keys(payload).length <= 1) {
      toast.error(
        "Isi data",
        "Pilih minimal satu dari tanggal medical, hasil medical, atau tanggal bayar SML."
      )
      return
    }
    bulkMedicalMutation.mutate(payload)
  }

  const handleBulkFwcmsApply = () => {
    const applicantIds = filteredApps
      .filter((a) => selectedAdvanceAppIds.has(a.id) && a.applicant_user)
      .map((a) => a.applicant_user as number)
    if (!applicantIds.length) {
      toast.error("Pilih pelamar", "Centang minimal satu pelamar di tabel.")
      return
    }
    const payload: Parameters<typeof bulkAdminProcessApplicants>[0] = {
      applicant_user_ids: applicantIds,
    }
    if (bulkTglFwcmPsikotes) {
      payload.tgl_fwcm_psikotes = format(bulkTglFwcmPsikotes, "yyyy-MM-dd")
    }
    if (bulkTglBayarPsikotes) {
      payload.tgl_bayar_psikotes = format(bulkTglBayarPsikotes, "yyyy-MM-dd")
    }
    if (Object.keys(payload).length <= 1) {
      toast.error(
        "Isi data",
        "Pilih minimal satu dari tanggal FWCMS & psikotes atau tanggal bayar psikotes."
      )
      return
    }
    bulkFwcmsMutation.mutate(payload)
  }

  const canApplyBulkMedical =
    selectedAdvanceAppIds.size > 0 &&
    !!(bulkTglMedical || bulkHasilMedical || bulkTglBayarSml)

  const canApplyBulkFwcms =
    selectedAdvanceAppIds.size > 0 && !!(bulkTglFwcmPsikotes || bulkTglBayarPsikotes)

  const sendAnnouncementMutation = useMutation({
    mutationFn: async () => {
      const created = await createBroadcast({
        title: announcementTitle.trim(),
        message: announcementBody.trim(),
        notification_type: "BROADCAST",
        priority: "NORMAL",
        recipient_config: {
          selection_type: "users",
          user_ids: selectedRecipientIds,
        },
        send_email: false,
        send_in_app: true,
        send_push: true,
      })
      return sendBroadcast(created.id)
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["broadcasts"] })
      toast.success(
        "Pengumuman dikirim",
        `Pengumuman dikirim ke ${selectedRecipientIds.length} pelamar terpilih.`
      )
      setAnnouncementTitle("")
      setAnnouncementBody("")
      setSelectedApplicantUsers(new Set())
    },
    onError: (err: unknown) => {
      const detail = (err as { response?: { data?: { detail?: string } } })?.response
        ?.data?.detail
      toast.error("Gagal mengirim pengumuman", detail ?? "Coba lagi nanti.")
    },
  })

  const toggleSelectAllApplicants = () => {
    setSelectedApplicantUsers((prev) => {
      const next = new Set(prev)
      if (allSelectableChecked) {
        selectableApplicantUsers.forEach((id) => next.delete(id))
      } else {
        selectableApplicantUsers.forEach((id) => next.add(id))
      }
      return next
    })
  }

  const toggleSelectApplicant = (applicantUserId: number) => {
    setSelectedApplicantUsers((prev) => {
      const next = new Set(prev)
      if (next.has(applicantUserId)) {
        next.delete(applicantUserId)
      } else {
        next.add(applicantUserId)
      }
      return next
    })
  }

  return (
    <>
      <div className="flex flex-col gap-4">
        <div className="flex items-center justify-between gap-2 flex-wrap">
          <p className="text-sm text-muted-foreground">
            {totalCount} pelamar
            {totalCount > 0 ? (
              <span className="text-muted-foreground/80">
                {" "}
                (menampilkan{" "}
                {(currentPage - 1) * APPLICATIONS_TAB_PAGE_SIZE + 1}–
                {Math.min(currentPage * APPLICATIONS_TAB_PAGE_SIZE, totalCount)})
              </span>
            ) : null}
          </p>
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="cursor-pointer"
            disabled={isExporting || totalCount === 0}
            onClick={() => void handleExportExcel()}
          >
            <IconFileSpreadsheet className="mr-2 size-4" />
            {isExporting ? "Mengunduh..." : "Export Excel"}
          </Button>
        </div>

        {showDiterimaStepFilter && (
          <div className="rounded-lg border bg-muted/20 p-2 space-y-2">
            <p className="px-1 text-xs text-muted-foreground">
              Untuk memindahkan pelamar ke sub-tahapan berikutnya, pilih salah satu tab sub-tahapan
              (bukan <span className="font-medium">Semua Tahapan</span>), lalu centang pelamar di
              tabel dan klik tombol <span className="font-medium">Pindahkan</span>.
            </p>
            <Tabs
              value={selectedDiterimaStep}
              onValueChange={(v) => {
                setSelectedDiterimaStep(v as "ALL" | DocumentCollectionStepCode)
                setPage(1)
                setSelectedAdvanceAppIds(new Set())
              }}
            >
              <TabsList className="h-auto w-full justify-start overflow-x-auto flex-nowrap">
                <TabsTrigger value="ALL">Semua Tahapan</TabsTrigger>
                {diterimaStepOptions.map(([code, label]) => (
                  <TabsTrigger key={code} value={code}>
                    {label}
                  </TabsTrigger>
                ))}
              </TabsList>
            </Tabs>
          </div>
        )}

        {/* Action bar: advance applicants through DITERIMA sub-steps (shown only on sub-step tabs) */}
        {onDiterimaSubStep && (
          <div className="flex flex-wrap items-center gap-3 rounded-lg border bg-muted/30 p-3">
            <span className="text-sm text-muted-foreground">
              {selectedAdvanceAppIds.size > 0
                ? `${selectedAdvanceAppIds.size} pelamar terpilih`
                : "Pilih pelamar untuk dipindahkan"}
            </span>
            <div className="ml-auto flex flex-wrap gap-2">
              <Button
                type="button"
                size="sm"
                variant="destructive"
                disabled={selectedAdvanceAppIds.size === 0 || isAdvancing}
                onClick={() => void handleRejectFromDiterimaSubStep()}
                className="cursor-pointer"
              >
                {isAdvancing ? "Memproses..." : "Pindahkan ke Ditolak"}
              </Button>
              {isLastDiterimaStep ? (
                <Button
                  type="button"
                  size="sm"
                  disabled={selectedAdvanceAppIds.size === 0 || isAdvancing}
                  onClick={() => void handleAdvanceDiterimaStep()}
                  className="cursor-pointer"
                >
                  {isAdvancing ? "Memindahkan..." : "Pindahkan ke Berangkat"}
                </Button>
              ) : (
                <Button
                  type="button"
                  size="sm"
                  variant="secondary"
                  disabled={selectedAdvanceAppIds.size === 0 || isAdvancing}
                  onClick={() => void handleAdvanceDiterimaStep()}
                  className="cursor-pointer"
                >
                  {isAdvancing
                    ? "Memindahkan..."
                    : `Pindahkan ke ${nextDiterimaStepLabel ?? "Berikutnya"}`}
                </Button>
              )}
            </div>
          </div>
        )}

        {isMedicalDiterimaStep && (
          <BulkMedicalSmlCard
            bulkTglMedical={bulkTglMedical}
            onBulkTglMedicalChange={setBulkTglMedical}
            bulkHasilMedical={bulkHasilMedical}
            onBulkHasilMedicalChange={setBulkHasilMedical}
            bulkTglBayarSml={bulkTglBayarSml}
            onBulkTglBayarSmlChange={setBulkTglBayarSml}
            selectedCount={selectedAdvanceAppIds.size}
            canApply={canApplyBulkMedical}
            isPending={bulkMedicalMutation.isPending}
            onApply={() => void handleBulkMedicalApply()}
          />
        )}

        {isFwcmsOrPsikologiDiterimaStep && (
          <BulkFwcmsPsikotesCard
            bulkTglFwcmPsikotes={bulkTglFwcmPsikotes}
            onBulkTglFwcmPsikotesChange={setBulkTglFwcmPsikotes}
            bulkTglBayarPsikotes={bulkTglBayarPsikotes}
            onBulkTglBayarPsikotesChange={setBulkTglBayarPsikotes}
            selectedCount={selectedAdvanceAppIds.size}
            canApply={canApplyBulkFwcms}
            isPending={bulkFwcmsMutation.isPending}
            onApply={() => void handleBulkFwcmsApply()}
          />
        )}

        {enableAcceptedAnnouncement && (
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-base">Pengumuman Tahap Diterima</CardTitle>
              <p className="text-sm text-muted-foreground">
                Pilih pelamar pada tabel, lalu kirim pengumuman hanya ke pelamar terpilih.
              </p>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="grid gap-3 md:grid-cols-2">
                <div className="space-y-1.5 md:col-span-2">
                  <Label htmlFor="accepted-announcement-title">Judul</Label>
                  <Input
                    id="accepted-announcement-title"
                    value={announcementTitle}
                    onChange={(e) => setAnnouncementTitle(e.target.value)}
                    placeholder="Contoh: Info pemberkasan tahap diterima"
                    maxLength={200}
                  />
                </div>
                <div className="space-y-1.5 md:col-span-2">
                  <Label htmlFor="accepted-announcement-body">Isi pengumuman</Label>
                  <Textarea
                    id="accepted-announcement-body"
                    value={announcementBody}
                    onChange={(e) => setAnnouncementBody(e.target.value)}
                    placeholder="Tulis isi pengumuman untuk pelamar yang dipilih..."
                    rows={4}
                    maxLength={3000}
                  />
                </div>
              </div>
              <div className="flex items-center justify-between gap-2 flex-wrap">
                <span className="text-xs text-muted-foreground">
                  {selectedRecipientIds.length} pelamar terpilih
                </span>
                <Button
                  type="button"
                  size="sm"
                  className="cursor-pointer"
                  disabled={!canSendAnnouncement || sendAnnouncementMutation.isPending}
                  onClick={() => setConfirmAnnouncementOpen(true)}
                >
                  {sendAnnouncementMutation.isPending
                    ? "Mengirim..."
                    : "Kirim Pengumuman"}
                </Button>
              </div>
              {selectedRecipientNames.length > 0 && (
                <div className="rounded-md border bg-muted/30 p-3">
                  <p className="mb-1 text-xs font-medium text-foreground">
                    Preview penerima:
                  </p>
                  <p className="text-xs text-muted-foreground">
                    {selectedRecipientNames.slice(0, 8).join(", ")}
                    {selectedRecipientNames.length > 8
                      ? `, dan ${selectedRecipientNames.length - 8} pelamar lainnya`
                      : ""}
                  </p>
                </div>
              )}
            </CardContent>
          </Card>
        )}

        <div className="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-end">
          <div className="relative max-w-md min-w-[min(100%,16rem)] flex-1">
            <IconSearch className="text-muted-foreground absolute left-3 top-1/2 size-4 -translate-y-1/2" />
            <Input
              placeholder="Cari nama, email, NIK, atau rujukan..."
              value={stageSearch}
              onChange={(e) => setStageSearch(e.target.value)}
              className="pl-9 h-9 text-sm"
              aria-label="Filter pelamar di tahap ini"
            />
          </div>
          {showDiterimaBatchCohortFilters ? (
            <>
              <div className="flex w-full flex-col gap-1 sm:w-auto sm:min-w-[200px]">
                <Label htmlFor="diterima-batch-filter" className="text-xs text-muted-foreground">
                  Tahapan / batch
                </Label>
                <Select
                  value={batchFilterId != null ? String(batchFilterId) : "ALL"}
                  onValueChange={(v) => {
                    setBatchFilterId(v === "ALL" ? null : Number(v))
                    setSelectedAdvanceAppIds(new Set())
                    setSelectedApplicantUsers(new Set())
                  }}
                >
                  <SelectTrigger id="diterima-batch-filter" className="h-9 w-full sm:w-[220px]">
                    <SelectValue placeholder="Semua tahapan" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="ALL">Semua tahapan</SelectItem>
                    {batchFilterOptions.map((b) => (
                      <SelectItem key={b.id} value={String(b.id)}>
                        Tahap {b.tahap_order}: {b.name}
                        {b.tahap_label ? ` · ${b.tahap_label}` : ""}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="flex w-full flex-col gap-1 sm:w-auto sm:min-w-[220px]">
                <Label htmlFor="diterima-cohort-filter" className="text-xs text-muted-foreground">
                  Sesi interview
                </Label>
                <Select
                  value={cohortFilterId != null ? String(cohortFilterId) : "ALL"}
                  onValueChange={(v) => {
                    setCohortFilterId(v === "ALL" ? null : Number(v))
                    setSelectedAdvanceAppIds(new Set())
                    setSelectedApplicantUsers(new Set())
                  }}
                >
                  <SelectTrigger id="diterima-cohort-filter" className="h-9 w-full sm:w-[240px]">
                    <SelectValue placeholder="Semua sesi" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="ALL">Semua sesi</SelectItem>
                    {cohortFilterOptions.map((c) => (
                      <SelectItem key={c.id} value={String(c.id)}>
                        {c.name}
                        {c.interview_date
                          ? ` · ${format(new Date(c.interview_date), "dd MMM yyyy HH:mm", {
                              locale: idLocale,
                            })}`
                          : " · Belum dijadwalkan"}
                        {!c.is_active ? " · Non-aktif" : ""}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </>
          ) : null}
          {isMedicalDiterimaStep ? (
            <BulkReferralPdfButton
              kind="medical"
              selectedApplicantUserIds={selectedAdvanceApplicantUserIds}
            />
          ) : null}
          {isPsikologiTestDiterimaStep ? (
            <BulkReferralPdfButton
              kind="psychology"
              selectedApplicantUserIds={selectedAdvanceApplicantUserIds}
            />
          ) : null}
        </div>

        <div className={JOB_DETAIL_TABLE_SHELL}>
          {isLoading && !data ? (
            <div className="flex min-h-[14rem] items-center justify-center">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
            </div>
          ) : isMedicalDiterimaStep ? (
            <Table className="border-collapse">
              <TableHeader>
                <TableRow className={JD_HEADER_ROW}>
                  <TableHead className="w-[42px]">
                    <Checkbox
                      checked={allAdvanceChecked}
                      onCheckedChange={toggleSelectAllAdvance}
                      aria-label="Pilih semua pelamar di tabel"
                    />
                  </TableHead>
                  <TableHead className="min-w-[14rem]">
                    Pelamar, tahapan &amp; sesi
                  </TableHead>
                  <TableHead className="whitespace-nowrap">Tgl. medical</TableHead>
                  <TableHead>Hasil medical</TableHead>
                  <TableHead className="whitespace-nowrap">Tgl. bayar SML</TableHead>
                  <TableHead className="min-w-[11rem]">Konfirmasi Pelamar</TableHead>
                  <TableHead className="text-right w-[180px] sticky right-0 bg-background z-10">
                    Aksi
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredApps.length ? (
                  filteredApps.map((app) => (
                    <TableRow key={app.id} className={JD_BODY_ROW}>
                      <TableCell className="align-top">
                        <Checkbox
                          checked={selectedAdvanceAppIds.has(app.id)}
                          onCheckedChange={() => toggleSelectAdvance(app.id)}
                          aria-label={`Pilih ${app.applicant_name}`}
                        />
                      </TableCell>
                      <TableCell className="align-top min-w-0">
                        <PelamarTahapanSesiCell
                          app={app}
                          batchBase={batchBase}
                          cohortBase={cohortBase}
                        />
                      </TableCell>
                      <TableCell className="align-top text-sm whitespace-nowrap">
                        {formatDiterimaDate(app.tgl_medical ?? null)}
                      </TableCell>
                      <TableCell className="align-top">
                        <MedicalHasilPill value={app.hasil_medical} />
                      </TableCell>
                      <TableCell className="align-top text-sm whitespace-nowrap">
                        {formatDiterimaDate(app.tgl_bayar_sml ?? null)}
                      </TableCell>
                      <TableCell className="align-top text-sm">
                        <DocumentCollectionProgressCell
                          app={app}
                          highlightStep="MEDICAL"
                        />
                      </TableCell>
                      <TableCell className="text-right sticky right-0 bg-background align-top">
                        <div className="flex items-center justify-end gap-0.5">
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                            title="Lihat detail pelamar"
                            disabled={!app.applicant_user}
                            onClick={() => {
                              if (!app.applicant_user) return
                              setPreviewUserId(app.applicant_user)
                              setPreviewUserLabel(app.applicant_name)
                            }}
                          >
                            <IconEye className="size-4" />
                            <span className="sr-only">Lihat detail pelamar</span>
                          </Button>
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                            title="Kelola dokumen pelamar"
                            disabled={!app.applicant_user}
                            onClick={() => {
                              if (!app.applicant_user) return
                              navigate(`${pelamarBase}/${app.applicant_user}`)
                            }}
                          >
                            <IconFileSpreadsheet className="size-4" />
                            <span className="sr-only">Kelola dokumen pelamar</span>
                          </Button>
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                            title="Edit data proses"
                            disabled={!app.applicant_user}
                            onClick={() => {
                              if (!app.applicant_user) return
                              setProcessUserId(app.applicant_user)
                              setProcessUserLabel(app.applicant_name)
                            }}
                          >
                            <IconClipboardList className="size-4" />
                            <span className="sr-only">Edit data proses</span>
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))
                ) : (
                  <TableRow>
                    <TableCell
                      colSpan={emptyColSpan}
                      className="h-20 text-center text-muted-foreground"
                    >
                      Tidak ada pelamar dengan status ini.
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          ) : isFwcmsOrPsikologiDiterimaStep ? (
            <Table className="border-collapse">
              <TableHeader>
                <TableRow className={JD_HEADER_ROW}>
                  <TableHead className="w-[42px]">
                    <Checkbox
                      checked={allAdvanceChecked}
                      onCheckedChange={toggleSelectAllAdvance}
                      aria-label="Pilih semua pelamar di tabel"
                    />
                  </TableHead>
                  <TableHead className="min-w-[14rem]">
                    Pelamar, tahapan &amp; sesi
                  </TableHead>
                  <TableHead className="whitespace-nowrap">Tgl. FWCMS &amp; Psikotes</TableHead>
                  <TableHead className="whitespace-nowrap">Tgl. bayar psikotes</TableHead>
                  <TableHead className="min-w-[11rem]">Konfirmasi Pelamar</TableHead>
                  <TableHead className="sticky right-0 z-10 w-[180px] bg-background text-right">
                    Aksi
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredApps.length ? (
                  filteredApps.map((app) => (
                    <TableRow key={app.id} className={JD_BODY_ROW}>
                      <TableCell className="align-top">
                        <Checkbox
                          checked={selectedAdvanceAppIds.has(app.id)}
                          onCheckedChange={() => toggleSelectAdvance(app.id)}
                          aria-label={`Pilih ${app.applicant_name}`}
                        />
                      </TableCell>
                      <TableCell className="align-top min-w-0">
                        <PelamarTahapanSesiCell
                          app={app}
                          batchBase={batchBase}
                          cohortBase={cohortBase}
                        />
                      </TableCell>
                      <TableCell className="align-top text-sm whitespace-nowrap">
                        {formatDiterimaDate(app.tgl_fwcm_psikotes ?? null)}
                      </TableCell>
                      <TableCell className="align-top text-sm whitespace-nowrap">
                        {formatDiterimaDate(app.tgl_bayar_psikotes ?? null)}
                      </TableCell>
                      <TableCell className="align-top text-sm">
                        <DocumentCollectionProgressCell
                          app={app}
                          highlightStep={selectedDiterimaStep as DocumentCollectionStepCode}
                        />
                      </TableCell>
                      <TableCell className="sticky right-0 bg-background text-right align-top">
                        <div className="flex items-center justify-end gap-0.5">
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                            title="Lihat detail pelamar"
                            disabled={!app.applicant_user}
                            onClick={() => {
                              if (!app.applicant_user) return
                              setPreviewUserId(app.applicant_user)
                              setPreviewUserLabel(app.applicant_name)
                            }}
                          >
                            <IconEye className="size-4" />
                            <span className="sr-only">Lihat detail pelamar</span>
                          </Button>
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                            title="Kelola dokumen pelamar"
                            disabled={!app.applicant_user}
                            onClick={() => {
                              if (!app.applicant_user) return
                              navigate(`${pelamarBase}/${app.applicant_user}`)
                            }}
                          >
                            <IconFileSpreadsheet className="size-4" />
                            <span className="sr-only">Kelola dokumen pelamar</span>
                          </Button>
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                            title="Edit data proses"
                            disabled={!app.applicant_user}
                            onClick={() => {
                              if (!app.applicant_user) return
                              setProcessUserId(app.applicant_user)
                              setProcessUserLabel(app.applicant_name)
                            }}
                          >
                            <IconClipboardList className="size-4" />
                            <span className="sr-only">Edit data proses</span>
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))
                ) : (
                  <TableRow>
                    <TableCell
                      colSpan={emptyColSpan}
                      className="h-20 text-center text-muted-foreground"
                    >
                      Tidak ada pelamar dengan status ini.
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          ) : isBuatIdPekerjaDiterimaStep ? (
            <Table className="border-collapse">
              <TableHeader>
                <TableRow className={JD_HEADER_ROW}>
                  <TableHead className="w-[42px]">
                    <Checkbox
                      checked={allAdvanceChecked}
                      onCheckedChange={toggleSelectAllAdvance}
                      aria-label="Pilih semua pelamar di tabel"
                    />
                  </TableHead>
                  <TableHead className="min-w-[14rem]">
                    Pelamar, tahapan &amp; sesi
                  </TableHead>
                  <TableHead className="whitespace-nowrap min-w-[10rem]">
                    No. ID pekerja (SISKO)
                  </TableHead>
                  <TableHead className="min-w-[11rem]">Konfirmasi Pelamar</TableHead>
                  <TableHead className="text-right w-[180px] sticky right-0 bg-background z-10">
                    Aksi
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredApps.length ? (
                  filteredApps.map((app) => (
                    <TableRow key={app.id} className={JD_BODY_ROW}>
                      <TableCell className="align-top">
                        <Checkbox
                          checked={selectedAdvanceAppIds.has(app.id)}
                          onCheckedChange={() => toggleSelectAdvance(app.id)}
                          aria-label={`Pilih ${app.applicant_name}`}
                        />
                      </TableCell>
                      <TableCell className="align-top min-w-0">
                        <PelamarTahapanSesiCell
                          app={app}
                          batchBase={batchBase}
                          cohortBase={cohortBase}
                        />
                      </TableCell>
                      <TableCell className="align-top font-mono text-sm">
                        {(app.no_id_sisko || "").trim() || "—"}
                      </TableCell>
                      <TableCell className="align-top text-sm">
                        <DocumentCollectionProgressCell
                          app={app}
                          highlightStep="BUAT_ID_PEKERJA"
                        />
                      </TableCell>
                      <TableCell className="text-right sticky right-0 bg-background align-top">
                        <div className="flex items-center justify-end gap-0.5">
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                            title="Lihat detail pelamar"
                            disabled={!app.applicant_user}
                            onClick={() => {
                              if (!app.applicant_user) return
                              setPreviewUserId(app.applicant_user)
                              setPreviewUserLabel(app.applicant_name)
                            }}
                          >
                            <IconEye className="size-4" />
                            <span className="sr-only">Lihat detail pelamar</span>
                          </Button>
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                            title="Kelola dokumen pelamar"
                            disabled={!app.applicant_user}
                            onClick={() => {
                              if (!app.applicant_user) return
                              navigate(`${pelamarBase}/${app.applicant_user}`)
                            }}
                          >
                            <IconFileSpreadsheet className="size-4" />
                            <span className="sr-only">Kelola dokumen pelamar</span>
                          </Button>
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                            title="Edit data proses"
                            disabled={!app.applicant_user}
                            onClick={() => {
                              if (!app.applicant_user) return
                              setProcessUserId(app.applicant_user)
                              setProcessUserLabel(app.applicant_name)
                            }}
                          >
                            <IconClipboardList className="size-4" />
                            <span className="sr-only">Edit data proses</span>
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))
                ) : (
                  <TableRow>
                    <TableCell
                      colSpan={emptyColSpan}
                      className="h-20 text-center text-muted-foreground"
                    >
                      Tidak ada pelamar dengan status ini.
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          ) : isBuatPasporDiterimaStep ? (
            <Table className="border-collapse">
              <TableHeader>
                <TableRow className={JD_HEADER_ROW}>
                  <TableHead className="w-[42px]">
                    <Checkbox
                      checked={allAdvanceChecked}
                      onCheckedChange={toggleSelectAllAdvance}
                      aria-label="Pilih semua pelamar di tabel"
                    />
                  </TableHead>
                  <TableHead className="min-w-[14rem]">
                    Pelamar, tahapan &amp; sesi
                  </TableHead>
                  <TableHead className="min-w-[8rem] whitespace-nowrap">
                    Berkas paspor
                  </TableHead>
                  <TableHead className="min-w-[12rem]">Detail paspor (profil)</TableHead>
                  <TableHead className="min-w-[11rem]">Konfirmasi Pelamar</TableHead>
                  <TableHead className="text-right w-[180px] sticky right-0 bg-background z-10">
                    Aksi
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredApps.length ? (
                  filteredApps.map((app) => (
                    <TableRow key={app.id} className={JD_BODY_ROW}>
                      <TableCell className="align-top">
                        <Checkbox
                          checked={selectedAdvanceAppIds.has(app.id)}
                          onCheckedChange={() => toggleSelectAdvance(app.id)}
                          aria-label={`Pilih ${app.applicant_name}`}
                        />
                      </TableCell>
                      <TableCell className="align-top min-w-0">
                        <PelamarTahapanSesiCell
                          app={app}
                          batchBase={batchBase}
                          cohortBase={cohortBase}
                        />
                      </TableCell>
                      <TableCell className="align-top">
                        <PassportBerkasLink url={app.passport_file_url} />
                      </TableCell>
                      <TableCell className="align-top">
                        <PassportDetailBlock app={app} />
                      </TableCell>
                      <TableCell className="align-top text-sm">
                        <DocumentCollectionProgressCell
                          app={app}
                          highlightStep="BUAT_PASPOR"
                        />
                      </TableCell>
                      <TableCell className="text-right sticky right-0 bg-background align-top">
                        <div className="flex items-center justify-end gap-0.5">
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                            title="Lihat detail pelamar"
                            disabled={!app.applicant_user}
                            onClick={() => {
                              if (!app.applicant_user) return
                              setPreviewUserId(app.applicant_user)
                              setPreviewUserLabel(app.applicant_name)
                            }}
                          >
                            <IconEye className="size-4" />
                            <span className="sr-only">Lihat detail pelamar</span>
                          </Button>
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                            title="Kelola dokumen pelamar"
                            disabled={!app.applicant_user}
                            onClick={() => {
                              if (!app.applicant_user) return
                              navigate(`${pelamarBase}/${app.applicant_user}`)
                            }}
                          >
                            <IconFileSpreadsheet className="size-4" />
                            <span className="sr-only">Kelola dokumen pelamar</span>
                          </Button>
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                            title="Edit data proses"
                            disabled={!app.applicant_user}
                            onClick={() => {
                              if (!app.applicant_user) return
                              setProcessUserId(app.applicant_user)
                              setProcessUserLabel(app.applicant_name)
                            }}
                          >
                            <IconClipboardList className="size-4" />
                            <span className="sr-only">Edit data proses</span>
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))
                ) : (
                  <TableRow>
                    <TableCell
                      colSpan={emptyColSpan}
                      className="h-20 text-center text-muted-foreground"
                    >
                      Tidak ada pelamar dengan status ini.
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          ) : (
            <Table className="border-collapse">
              <TableHeader>
                <TableRow className={JD_HEADER_ROW}>
                  {onDiterimaSubStep ? (
                    <TableHead className="w-[42px]">
                      <Checkbox
                        checked={allAdvanceChecked}
                        onCheckedChange={toggleSelectAllAdvance}
                        aria-label="Pilih semua pelamar di tabel"
                      />
                    </TableHead>
                  ) : enableAcceptedAnnouncement ? (
                    <TableHead className="w-[42px]">
                      <Checkbox
                        checked={allSelectableChecked}
                        onCheckedChange={toggleSelectAllApplicants}
                        aria-label="Pilih semua pelamar di tabel"
                      />
                    </TableHead>
                  ) : null}
                  <TableHead>Pelamar</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Tahapan / Batch</TableHead>
                  {showCohortColEffective && <TableHead>Sesi Interview</TableHead>}
                  {showDocColEffective && (
                    <TableHead className="min-w-[11rem]">
                      Konfirmasi Pelamar
                    </TableHead>
                  )}
                  <TableHead>Tanggal Lamar</TableHead>
                  <TableHead className="text-right w-[180px] sticky right-0 bg-background z-10">
                    Aksi
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredApps.length ? (
                  filteredApps.map((app) => (
                    <TableRow key={app.id} className={JD_BODY_ROW}>
                      {onDiterimaSubStep ? (
                        <TableCell>
                          <Checkbox
                            checked={selectedAdvanceAppIds.has(app.id)}
                            onCheckedChange={() => toggleSelectAdvance(app.id)}
                            aria-label={`Pilih ${app.applicant_name}`}
                          />
                        </TableCell>
                      ) : enableAcceptedAnnouncement ? (
                        <TableCell>
                          {app.applicant_user ? (
                            <Checkbox
                              checked={selectedApplicantUsers.has(app.applicant_user)}
                              onCheckedChange={() =>
                                toggleSelectApplicant(app.applicant_user as number)
                              }
                              aria-label={`Pilih ${app.applicant_name}`}
                            />
                          ) : null}
                        </TableCell>
                      ) : null}
                      <TableCell>
                        <div className="flex flex-col">
                          <span className="font-medium">{app.applicant_name}</span>
                          <span className="text-xs text-muted-foreground">
                            {app.applicant_email}
                          </span>
                        </div>
                      </TableCell>
                      <TableCell>
                        <ApplicationStatusBadge status={app.status} />
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground">
                        {app.batch ? (
                          <button
                            type="button"
                            className="inline-flex items-center gap-1 text-primary underline-offset-2 hover:underline cursor-pointer"
                            onClick={() => navigate(`${batchBase}/${app.batch}`)}
                          >
                            {app.batch_tahap_label ?? app.batch_name ?? `Batch #${app.batch}`}
                            <IconExternalLink className="size-3" />
                          </button>
                        ) : (
                          "—"
                        )}
                      </TableCell>
                      {showCohortColEffective && (
                        <TableCell className="text-sm text-muted-foreground">
                          {app.interview_cohort != null ? (
                            <button
                              type="button"
                              className="inline-flex items-center gap-1 text-primary underline-offset-2 hover:underline cursor-pointer"
                              onClick={() =>
                                navigate(`${cohortBase}/${app.interview_cohort}`)
                              }
                            >
                              {app.interview_cohort_name ??
                                `Sesi #${app.interview_cohort}`}
                              <IconExternalLink className="size-3" />
                            </button>
                          ) : (
                            "—"
                          )}
                        </TableCell>
                      )}
                      {showDocColEffective && (
                        <TableCell className="text-sm align-top">
                          <DocumentCollectionProgressCell
                            app={app}
                            highlightStep={
                              onDiterimaSubStep
                                ? (selectedDiterimaStep as DocumentCollectionStepCode)
                                : undefined
                            }
                          />
                        </TableCell>
                      )}
                      <TableCell className="text-sm text-muted-foreground">
                        {formatDate(app.applied_at)}
                      </TableCell>
                      <TableCell className="text-right sticky right-0 bg-background">
                        <div className="flex items-center justify-end gap-0.5">
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                            title="Lihat detail pelamar"
                            disabled={!app.applicant_user}
                            onClick={() => {
                              if (!app.applicant_user) return
                              setPreviewUserId(app.applicant_user)
                              setPreviewUserLabel(app.applicant_name)
                            }}
                          >
                            <IconEye className="size-4" />
                            <span className="sr-only">Lihat detail pelamar</span>
                          </Button>
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                            title="Kelola dokumen pelamar"
                            disabled={!app.applicant_user}
                            onClick={() => {
                              if (!app.applicant_user) return
                              navigate(`${pelamarBase}/${app.applicant_user}`)
                            }}
                          >
                            <IconFileSpreadsheet className="size-4" />
                            <span className="sr-only">Kelola dokumen pelamar</span>
                          </Button>
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="size-8 shrink-0 cursor-pointer text-muted-foreground"
                            title="Edit data proses"
                            disabled={!app.applicant_user}
                            onClick={() => {
                              if (!app.applicant_user) return
                              setProcessUserId(app.applicant_user)
                              setProcessUserLabel(app.applicant_name)
                            }}
                          >
                            <IconClipboardList className="size-4" />
                            <span className="sr-only">Edit data proses</span>
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))
                ) : (
                  <TableRow>
                    <TableCell
                      colSpan={emptyColSpan}
                      className="h-20 text-center text-muted-foreground"
                    >
                      Tidak ada pelamar dengan status ini.
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          )}
        </div>

        <JobDetailPagination
          pageSize={APPLICATIONS_TAB_PAGE_SIZE}
          currentPage={currentPage}
          pageCount={pageCount}
          totalCount={totalCount}
          isFetching={isFetching}
          itemLabel="pelamar"
          onPrev={() => setPage((p) => Math.max(1, p - 1))}
          onNext={() => setPage((p) => p + 1)}
        />
      </div>

      <ApplicantAdminProcessDialog
        applicantUserId={processUserId}
        open={processUserId != null}
        onOpenChange={(next) => {
          if (!next) {
            setProcessUserId(null)
            setProcessUserLabel("")
          }
        }}
        applicantLabel={processUserLabel}
      />
      <ApplicantDetailPreviewDialog
        applicantUserId={previewUserId}
        applicantLabel={previewUserLabel}
        applicantDetailPath={
          previewUserId != null
            ? `${pelamarBase}/${previewUserId}`
            : pelamarBase
        }
        open={previewUserId != null}
        onOpenChange={(next) => {
          if (!next) {
            setPreviewUserId(null)
            setPreviewUserLabel("")
          }
        }}
      />
      <AlertDialog
        open={confirmAnnouncementOpen}
        onOpenChange={setConfirmAnnouncementOpen}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Kirim pengumuman ke pelamar terpilih?</AlertDialogTitle>
            <AlertDialogDescription asChild>
              <div className="space-y-2 text-sm text-muted-foreground">
                <p>
                  Pengumuman akan dikirim ke{" "}
                  <span className="font-medium text-foreground">
                    {selectedRecipientIds.length}
                  </span>{" "}
                  pelamar di tahap Diterima.
                </p>
                {selectedRecipientNames.length > 0 && (
                  <p className="text-xs">
                    {selectedRecipientNames.slice(0, 10).join(", ")}
                    {selectedRecipientNames.length > 10
                      ? `, dan ${selectedRecipientNames.length - 10} lainnya`
                      : ""}
                  </p>
                )}
              </div>
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel
              type="button"
              className="cursor-pointer"
              disabled={sendAnnouncementMutation.isPending}
            >
              Batal
            </AlertDialogCancel>
            <AlertDialogAction
              type="button"
              className="cursor-pointer"
              disabled={!canSendAnnouncement || sendAnnouncementMutation.isPending}
              onClick={(e) => {
                e.preventDefault()
                sendAnnouncementMutation.mutate()
              }}
            >
              {sendAnnouncementMutation.isPending
                ? "Mengirim..."
                : "Ya, Kirim Pengumuman"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  )
}

export default ApplicationsTab
