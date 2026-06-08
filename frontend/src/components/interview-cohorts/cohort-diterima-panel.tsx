/**
 * DITERIMA tab for interview cohort detail: sub-tahapan tabs, server pagination,
 * bulk advance, medical/SML bulk form — aligned with admin job detail ApplicationsTab.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from "react"
import { useNavigate } from "react-router-dom"
import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { format } from "date-fns"
import { id as idLocale } from "date-fns/locale"
import {
  IconArrowsRightLeft,
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
import { TransitionApplicationDialog } from "@/components/applications/transition-application-dialog"
import { CohortSelectField } from "@/components/interview-cohorts/cohort-select-field"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Checkbox } from "@/components/ui/checkbox"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import {
  bulkAdvanceDiterimaStep,
  bulkTransitionApplications,
  getApplications,
} from "@/api/applications"
import { bulkAdminProcessApplicants } from "@/api/applicants"
import { moveApplicationsToCohort } from "@/api/interview-cohorts"
import { createBroadcast, sendBroadcast } from "@/api/notifications"
import { useDebounce } from "@/hooks/use-debounce"
import { invalidateCohortDashboardCaches } from "@/lib/invalidate-cohort-caches"
import { toast } from "@/lib/toast"
import { cn } from "@/lib/utils"
import {
  DITERIMA_LAST_STEP,
  DOCUMENT_COLLECTION_STEP_LABELS,
  DOCUMENT_COLLECTION_STEP_ORDER,
  APPLICATION_STATUS_LABELS,
  type DocumentCollectionStepCode,
  type JobApplication,
} from "@/types/job-applications"

const PAGE_SIZE = 20

/** Stable fallback so `filteredApps` does not allocate a new `[]` every render while loading. */
const EMPTY_DITERIMA_APPLICATIONS: JobApplication[] = []

const COHORT_DITERIMA_TABLE_SHELL =
  "overflow-hidden rounded-xl border border-border/60 bg-card text-card-foreground shadow-sm"
const CD_HEADER_ROW = "border-border/60 bg-muted/35 hover:bg-muted/35"
const CD_BODY_ROW =
  "border-border/40 transition-colors hover:bg-muted/40 data-[state=selected]:bg-primary/[0.06]"

function formatDateTimeDisplay(value: string | null | undefined) {
  if (!value) return "-"
  return format(new Date(value), "dd MMM yyyy HH:mm", { locale: idLocale })
}

function cohortKonfirmasiDiterima(app: JobApplication): {
  sudah: boolean
  waktuIso: string | null
  applicable: boolean
} {
  const sudah =
    Boolean(app.pengumpulan_dokumen_confirmed_at) ||
    app.attendance_by_stage?.DITERIMA === true ||
    app.pengumpulan_dokumen_complete === true
  const waktuIso =
    app.pengumpulan_dokumen_confirmed_at ??
    app.attendance_marked_at_by_stage?.DITERIMA ??
    null
  return { sudah, waktuIso, applicable: true }
}

export interface CohortDiterimaPanelProps {
  cohortId: number
  jobId: number
  batchBase: string
  pelamarBase: string
  cohortBase: string
}

export function CohortDiterimaPanel({
  cohortId,
  jobId,
  batchBase,
  pelamarBase,
  cohortBase,
}: CohortDiterimaPanelProps) {
  const queryClient = useQueryClient()
  const navigate = useNavigate()

  const [page, setPage] = useState(1)
  const [stageSearch, setStageSearch] = useState("")
  const debouncedStageSearch = useDebounce(stageSearch, 400)
  /** Medical sub-tahapan only — server filter on ApplicantProfile.hasil_medical */
  const [medicalHasilFilter, setMedicalHasilFilter] = useState<"ALL" | "FIT" | "UNFIT">("ALL")
  const [selectedDiterimaStep, setSelectedDiterimaStep] = useState<"ALL" | DocumentCollectionStepCode>(
    "ALL"
  )
  const [selectedAdvanceAppIds, setSelectedAdvanceAppIds] = useState<Set<number>>(new Set())
  const [selectedAppIds, setSelectedAppIds] = useState<Set<number>>(new Set())
  const [bulkTglMedical, setBulkTglMedical] = useState<Date | undefined>(undefined)
  const [bulkHasilMedical, setBulkHasilMedical] = useState("")
  const [bulkTglBayarSml, setBulkTglBayarSml] = useState<Date | undefined>(undefined)
  const [bulkTglFwcmPsikotes, setBulkTglFwcmPsikotes] = useState<Date | undefined>(undefined)
  const [bulkTglBayarPsikotes, setBulkTglBayarPsikotes] = useState<Date | undefined>(undefined)
  const [isAdvancing, setIsAdvancing] = useState(false)

  const [announcementTitle, setAnnouncementTitle] = useState("")
  const [announcementBody, setAnnouncementBody] = useState("")
  const [confirmAnnouncementOpen, setConfirmAnnouncementOpen] = useState(false)

  const [moveDialogOpen, setMoveDialogOpen] = useState(false)
  const [moveTargetCohortId, setMoveTargetCohortId] = useState<number | null>(null)
  const [moveNote, setMoveNote] = useState("")
  const [moving, setMoving] = useState(false)

  const [previewUserId, setPreviewUserId] = useState<number | null>(null)
  const [previewUserLabel, setPreviewUserLabel] = useState("")
  const [processUserId, setProcessUserId] = useState<number | null>(null)
  const [processUserLabel, setProcessUserLabel] = useState("")

  const [confirmBulkOpen, setConfirmBulkOpen] = useState(false)
  const [note, setNote] = useState("")
  const [isSubmittingBulk, setIsSubmittingBulk] = useState(false)

  /** Pelamar identity for selections across paginated / filtered pages (bulk medical etc.). */
  const selectionMetaRef = useRef(
    new Map<number, { applicantUser: number; name: string }>()
  )

  const onDiterimaSubStep = selectedDiterimaStep !== "ALL"
  const isLastDiterimaStep = selectedDiterimaStep === DITERIMA_LAST_STEP
  const isMedicalStep = selectedDiterimaStep === "MEDICAL"
  const isPsikologiTestStep = selectedDiterimaStep === "PSIKOLOGI_TEST"
  const isFwcmsOrPsikologiStep =
    selectedDiterimaStep === "FWCMS" || selectedDiterimaStep === "PSIKOLOGI_TEST"
  const isBuatIdPekerjaStep = selectedDiterimaStep === "BUAT_ID_PEKERJA"
  const isBuatPasporStep = selectedDiterimaStep === "BUAT_PASPOR"

  const medicalHasilApi =
    isMedicalStep && medicalHasilFilter !== "ALL" ? medicalHasilFilter : undefined

  const diterimaStepOptions = useMemo(
    () =>
      DOCUMENT_COLLECTION_STEP_ORDER.map(
        (code) => [code, DOCUMENT_COLLECTION_STEP_LABELS[code]] as [DocumentCollectionStepCode, string]
      ),
    []
  )

  const nextDiterimaStepLabel = useMemo(() => {
    if (!onDiterimaSubStep || isLastDiterimaStep) return null
    const idx = DOCUMENT_COLLECTION_STEP_ORDER.indexOf(
      selectedDiterimaStep as DocumentCollectionStepCode
    )
    if (idx < 0 || idx >= DOCUMENT_COLLECTION_STEP_ORDER.length - 1) return null
    return DOCUMENT_COLLECTION_STEP_LABELS[DOCUMENT_COLLECTION_STEP_ORDER[idx + 1]]
  }, [onDiterimaSubStep, isLastDiterimaStep, selectedDiterimaStep])

  const { data, isLoading, isFetching } = useQuery({
    queryKey: [
      "cohort-diterima-apps",
      cohortId,
      selectedDiterimaStep,
      page,
      debouncedStageSearch,
      medicalHasilApi ?? null,
    ],
    queryFn: () =>
      getApplications({
        interview_cohort: cohortId,
        status: "DITERIMA",
        diterima_step: selectedDiterimaStep !== "ALL" ? selectedDiterimaStep : undefined,
        page,
        page_size: PAGE_SIZE,
        search: debouncedStageSearch.trim() || undefined,
        ordering: "applicant_name",
        hasil_medical: medicalHasilApi,
      }),
    placeholderData: keepPreviousData,
  })

  const filteredApps = data?.results ?? EMPTY_DITERIMA_APPLICATIONS

  const totalCount = data?.count ?? 0
  const pageCount = Math.max(1, Math.ceil(totalCount / PAGE_SIZE))
  const safePage = Math.min(page, pageCount)

  useEffect(() => {
    setPage(1)
  }, [selectedDiterimaStep, debouncedStageSearch, medicalHasilFilter])

  useEffect(() => {
    setPage((p) => Math.min(p, pageCount))
  }, [pageCount])

  useEffect(() => {
    for (const a of filteredApps) {
      if (typeof a.applicant_user === "number") {
        selectionMetaRef.current.set(a.id, {
          applicantUser: a.applicant_user,
          name: a.applicant_name,
        })
      }
    }
  }, [filteredApps])

  const resolveApplicantUsersFromAppIds = useCallback((ids: Set<number>) => {
    const out: number[] = []
    const seen = new Set<number>()
    for (const appId of ids) {
      const meta = selectionMetaRef.current.get(appId)
      if (meta != null && !seen.has(meta.applicantUser)) {
        seen.add(meta.applicantUser)
        out.push(meta.applicantUser)
      }
    }
    return out
  }, [])

  const selectedAdvanceApplicantUserIds = useMemo(
    () => resolveApplicantUsersFromAppIds(selectedAdvanceAppIds),
    [resolveApplicantUsersFromAppIds, selectedAdvanceAppIds]
  )

  const pageApplicationIds = useMemo(() => new Set(filteredApps.map((a) => a.id)), [filteredApps])

  const hiddenAdvanceSelectionCount = useMemo(() => {
    let n = 0
    for (const id of selectedAdvanceAppIds) {
      if (!pageApplicationIds.has(id)) n++
    }
    return n
  }, [selectedAdvanceAppIds, pageApplicationIds])

  const hiddenAppSelectionCount = useMemo(() => {
    let n = 0
    for (const id of selectedAppIds) {
      if (!pageApplicationIds.has(id)) n++
    }
    return n
  }, [selectedAppIds, pageApplicationIds])

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
        selectableAdvanceIds.forEach((id) => {
          next.add(id)
          const row = filteredApps.find((a) => a.id === id)
          if (row && typeof row.applicant_user === "number") {
            selectionMetaRef.current.set(id, {
              applicantUser: row.applicant_user,
              name: row.applicant_name,
            })
          }
        })
      }
      return next
    })
  }

  const toggleSelectAdvance = (appId: number, row?: JobApplication) => {
    setSelectedAdvanceAppIds((prev) => {
      const next = new Set(prev)
      if (next.has(appId)) {
        next.delete(appId)
      } else {
        next.add(appId)
        if (row && typeof row.applicant_user === "number") {
          selectionMetaRef.current.set(appId, {
            applicantUser: row.applicant_user,
            name: row.applicant_name,
          })
        }
      }
      return next
    })
  }

  const selectableApplicantUsers = filteredApps
    .map((a) => a.applicant_user)
    .filter((v): v is number => typeof v === "number")
  const allSelectableChecked =
    selectableApplicantUsers.length > 0 &&
    selectableApplicantUsers.every((id) => {
      const app = filteredApps.find((a) => a.applicant_user === id)
      return app ? selectedAppIds.has(app.id) : false
    })

  const toggleSelectAllApplicants = () => {
    setSelectedAppIds((prev) => {
      const next = new Set(prev)
      if (allSelectableChecked) {
        filteredApps.forEach((a) => next.delete(a.id))
      } else {
        filteredApps.forEach((a) => {
          next.add(a.id)
          if (typeof a.applicant_user === "number") {
            selectionMetaRef.current.set(a.id, {
              applicantUser: a.applicant_user,
              name: a.applicant_name,
            })
          }
        })
      }
      return next
    })
  }

  const toggleSelectApplicantRow = (applicationId: number, row?: JobApplication) => {
    setSelectedAppIds((prev) => {
      const next = new Set(prev)
      if (next.has(applicationId)) {
        next.delete(applicationId)
      } else {
        next.add(applicationId)
        if (row && typeof row.applicant_user === "number") {
          selectionMetaRef.current.set(applicationId, {
            applicantUser: row.applicant_user,
            name: row.applicant_name,
          })
        }
      }
      return next
    })
  }

  const selectedRecipientIds = useMemo(() => {
    const ids = new Set<number>()
    for (const appId of selectedAppIds) {
      const meta = selectionMetaRef.current.get(appId)
      if (meta != null) ids.add(meta.applicantUser)
    }
    return Array.from(ids)
  }, [selectedAppIds])

  const selectedRecipientNames = useMemo(() => {
    const names: string[] = []
    for (const appId of selectedAppIds) {
      const meta = selectionMetaRef.current.get(appId)
      if (meta?.name) names.push(meta.name)
    }
    return names
  }, [selectedAppIds])

  const enableAcceptedAnnouncement = !onDiterimaSubStep
  const canSendAnnouncement =
    selectedRecipientIds.length > 0 &&
    announcementTitle.trim().length > 0 &&
    announcementBody.trim().length > 0

  const invalidate = useCallback(() => {
    invalidateCohortDashboardCaches(queryClient, { cohortId, jobId })
  }, [queryClient, cohortId, jobId])

  const handleAdvanceDiterimaStep = async () => {
    const ids = Array.from(selectedAdvanceAppIds)
    if (!ids.length) return
    setIsAdvancing(true)
    try {
      if (isLastDiterimaStep) {
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
      invalidate()
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
      invalidate()
      setSelectedAdvanceAppIds(new Set())
    } catch (err: unknown) {
      const detail = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail
      toast.error("Gagal memindahkan pelamar ke Ditolak", detail ?? "Coba lagi nanti.")
    } finally {
      setIsAdvancing(false)
    }
  }

  const onBulkAdminProcessError = useCallback((err: unknown) => {
    const detail = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail
    toast.error("Gagal memperbarui data", detail ?? "Coba lagi nanti.")
  }, [])

  const bulkMedicalMutation = useMutation({
    mutationFn: bulkAdminProcessApplicants,
    onSuccess: async (result) => {
      invalidate()
      toast.success(
        "Data proses diperbarui",
        `${result.updated_count} profil pelamar diperbarui.`
      )
      setBulkTglMedical(undefined)
      setBulkHasilMedical("")
      setBulkTglBayarSml(undefined)
      setSelectedAdvanceAppIds(new Set())
    },
    onError: onBulkAdminProcessError,
  })

  const bulkFwcmsMutation = useMutation({
    mutationFn: bulkAdminProcessApplicants,
    onSuccess: async (result) => {
      invalidate()
      toast.success(
        "Data proses diperbarui",
        `${result.updated_count} profil pelamar diperbarui.`
      )
      setBulkTglFwcmPsikotes(undefined)
      setBulkTglBayarPsikotes(undefined)
      setSelectedAdvanceAppIds(new Set())
    },
    onError: onBulkAdminProcessError,
  })

  const handleBulkMedicalApply = () => {
    const applicantIds = resolveApplicantUsersFromAppIds(selectedAdvanceAppIds)
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
    const applicantIds = resolveApplicantUsersFromAppIds(selectedAdvanceAppIds)
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
      setConfirmAnnouncementOpen(false)
      setAnnouncementTitle("")
      setAnnouncementBody("")
      setSelectedAppIds(new Set())
    },
    onError: (err: unknown) => {
      const detail = (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail
      toast.error("Gagal mengirim pengumuman", detail ?? "Coba lagi nanti.")
    },
  })

  const runMoveToCohort = async () => {
    const ids = Array.from(selectedAppIds)
    if (!ids.length || moveTargetCohortId == null) return
    setMoving(true)
    try {
      await moveApplicationsToCohort(cohortId, {
        target_cohort: moveTargetCohortId,
        application_ids: ids,
        note: moveNote.trim() || undefined,
      })
      toast.success(`${ids.length} pelamar dipindah ke sesi lain.`)
      invalidateCohortDashboardCaches(queryClient, {
        cohortId,
        jobId,
        extraCohortIds: [moveTargetCohortId],
      })
      setSelectedAppIds(new Set())
      setMoveNote("")
      setMoveTargetCohortId(null)
      setMoveDialogOpen(false)
    } catch (e: unknown) {
      const ax = e as { response?: { data?: { detail?: string } } }
      toast.error("Gagal memindahkan", ax.response?.data?.detail ?? "Coba lagi.")
    } finally {
      setMoving(false)
    }
  }

  const runBulkToBerangkat = async () => {
    const ids = Array.from(selectedAppIds)
    if (ids.length === 0) {
      toast.error("Pilih minimal satu pelamar di tabel (centang baris).")
      return
    }
    setIsSubmittingBulk(true)
    try {
      const res = await bulkTransitionApplications({
        application_ids: ids,
        status: "BERANGKAT",
        note: note.trim() || undefined,
      })
      invalidate()
      setConfirmBulkOpen(false)
      setNote("")
      setSelectedAppIds(new Set())
      if (res.updated_count > 0) {
        toast.success(
          `${res.updated_count} pelamar dipindahkan ke "${APPLICATION_STATUS_LABELS.BERANGKAT}".`
        )
      }
      if (res.failed_count > 0) {
        toast.error(
          `${res.failed_count} gagal dipindahkan.`,
          res.failed[0]?.reason ?? ""
        )
      }
    } catch (e: unknown) {
      const ax = e as { response?: { data?: { detail?: string } } }
      toast.error("Gagal memindahkan pelamar", ax.response?.data?.detail ?? "Coba lagi nanti.")
    } finally {
      setIsSubmittingBulk(false)
    }
  }

  const showCheckboxCol =
    (enableAcceptedAnnouncement && !onDiterimaSubStep) || onDiterimaSubStep

  const actionsCell = (app: JobApplication) => (
    <div className="flex items-center justify-end gap-0.5">
      <TransitionApplicationDialog
        application={app}
        onSuccess={() => {
          invalidate()
        }}
      />
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
  )

  return (
    <div className="flex flex-col gap-4">
      {enableAcceptedAnnouncement && (
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-base">Pengumuman Tahap Diterima</CardTitle>
            <CardDescription>
              Gunakan centang pada tabel untuk memilih penerima, lalu kirim pengumuman hanya ke
              pelamar yang dipilih (tab Semua Tahapan).
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="grid gap-3 md:grid-cols-2">
              <div className="space-y-1.5 md:col-span-2">
                <Label htmlFor="cohort-diterima-announcement-title">Judul</Label>
                <Input
                  id="cohort-diterima-announcement-title"
                  value={announcementTitle}
                  onChange={(e) => setAnnouncementTitle(e.target.value)}
                  placeholder="Contoh: Pengumpulan dokumen tahap diterima"
                  maxLength={200}
                />
              </div>
              <div className="space-y-1.5 md:col-span-2">
                <Label htmlFor="cohort-diterima-announcement-body">Isi pengumuman</Label>
                <Textarea
                  id="cohort-diterima-announcement-body"
                  value={announcementBody}
                  onChange={(e) => setAnnouncementBody(e.target.value)}
                  rows={4}
                  maxLength={3000}
                  placeholder="Tulis isi pengumuman untuk pelamar terpilih..."
                />
              </div>
            </div>
            <div className="flex flex-wrap items-center justify-between gap-2">
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
                {sendAnnouncementMutation.isPending ? "Mengirim..." : "Kirim Pengumuman"}
              </Button>
            </div>
            {selectedRecipientNames.length > 0 && (
              <div className="rounded-md border bg-muted/30 p-3">
                <p className="mb-1 text-xs font-medium text-foreground">Preview penerima:</p>
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

      <div className="flex flex-wrap items-center gap-2 rounded-lg border bg-muted/30 p-3">
        <Button
          size="sm"
          variant="outline"
          className="cursor-pointer"
          disabled={selectedAppIds.size === 0 || moving}
          onClick={() => setMoveDialogOpen(true)}
        >
          <IconArrowsRightLeft className="mr-2 size-4" />
          Pindah ke Sesi Lain ({selectedAppIds.size} dipilih)
        </Button>
        <span className="text-muted-foreground text-xs">
          Pilih baris di tabel, lalu pindahkan ke sesi interview lain untuk lowongan ini (status
          tidak berubah).
        </span>
      </div>

      <Dialog
        open={moveDialogOpen}
        onOpenChange={(open) => {
          setMoveDialogOpen(open)
          if (!open) {
            setMoveTargetCohortId(null)
            setMoveNote("")
          }
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Pindah ke Sesi Lain</DialogTitle>
            <DialogDescription>
              Pilih sesi tujuan. Pelamar tetap pada tahapan lamaran yang sama; hanya kelompok sesi
              interview yang berubah.
            </DialogDescription>
          </DialogHeader>
          <div className="flex flex-col gap-4">
            <CohortSelectField
              jobId={jobId}
              value={moveTargetCohortId}
              onChange={setMoveTargetCohortId}
              excludeCohortId={cohortId}
              required
              hideCreateLink
              helperText="Hanya sesi aktif yang dapat dipilih sebagai tujuan."
            />
            <div className="flex flex-col gap-1.5">
              <Label className="text-xs">
                Catatan <span className="text-muted-foreground">(opsional)</span>
              </Label>
              <Textarea value={moveNote} onChange={(e) => setMoveNote(e.target.value)} rows={2} />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" className="cursor-pointer" disabled={moving} onClick={() => setMoveDialogOpen(false)}>
              Batal
            </Button>
            <Button
              className="cursor-pointer"
              disabled={moving || moveTargetCohortId == null || selectedAppIds.size === 0}
              onClick={() => void runMoveToCohort()}
            >
              {moving ? "Memproses..." : "Pindahkan"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <div className="space-y-2 rounded-lg border bg-muted/20 p-2">
        <p className="px-1 text-xs text-muted-foreground">
          Untuk memindahkan pelamar ke sub-tahapan berikutnya, pilih salah satu tab sub-tahapan
          (bukan <span className="font-medium">Semua Tahapan</span>), lalu centang pelamar di tabel
          dan klik tombol <span className="font-medium">Pindahkan</span>.
        </p>
        <Tabs
          value={selectedDiterimaStep}
          onValueChange={(v) => {
            const next = v as "ALL" | DocumentCollectionStepCode
            setSelectedDiterimaStep(next)
            setSelectedAdvanceAppIds(new Set())
            if (next !== "MEDICAL") {
              setMedicalHasilFilter("ALL")
            }
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

      {onDiterimaSubStep && (
        <div className="flex flex-wrap items-center gap-3 rounded-lg border bg-muted/30 p-3">
          <span className="text-sm text-muted-foreground">
            {selectedAdvanceAppIds.size > 0
              ? `${selectedAdvanceAppIds.size} pelamar terpilih${
                  hiddenAdvanceSelectionCount > 0
                    ? ` (${hiddenAdvanceSelectionCount} di luar halaman ini)`
                    : ""
                }`
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

      {isMedicalStep && (
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

      {isFwcmsOrPsikologiStep && (
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

      {!onDiterimaSubStep && totalCount > 0 && (
        <Card>
          <CardContent className="flex flex-col gap-3 py-4 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p className="text-sm font-medium">
                {totalCount} pelamar di tahap Diterima (sesi ini)
                {selectedAppIds.size > 0 ? (
                  <span className="text-muted-foreground font-normal">
                    {" "}
                    · {selectedAppIds.size} terpilih
                    {hiddenAppSelectionCount > 0
                      ? ` (${hiddenAppSelectionCount} di luar halaman ini)`
                      : null}
                  </span>
                ) : null}
              </p>
              <p className="text-muted-foreground text-xs">
                Centang pelamar di tabel, lalu pindahkan ke Berangkat (semua sub-tahapan harus
                selesai sesuai aturan bisnis per lamaran).
              </p>
            </div>
            <Button
              className="cursor-pointer"
              disabled={selectedAppIds.size === 0}
              onClick={() => setConfirmBulkOpen(true)}
            >
              Pindahkan ke Berangkat
            </Button>
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
            className="h-9 pl-9 text-sm"
            aria-label="Filter pelamar di tahap ini"
          />
        </div>
        {isMedicalStep ? (
          <div className="flex w-full flex-col gap-1 sm:w-auto sm:min-w-[200px]">
            <Label htmlFor="cohort-medical-hasil-filter" className="text-xs text-muted-foreground">
              Hasil medical
            </Label>
            <Select
              value={medicalHasilFilter}
              onValueChange={(v) => setMedicalHasilFilter(v as "ALL" | "FIT" | "UNFIT")}
            >
              <SelectTrigger id="cohort-medical-hasil-filter" className="h-9 w-full sm:w-[200px]">
                <SelectValue placeholder="Semua" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="ALL">Semua</SelectItem>
                <SelectItem value="FIT">FIT</SelectItem>
                <SelectItem value="UNFIT">UNFIT</SelectItem>
              </SelectContent>
            </Select>
          </div>
        ) : null}
        {isMedicalStep ? (
          <BulkReferralPdfButton
            kind="medical"
            selectedApplicantUserIds={selectedAdvanceApplicantUserIds}
          />
        ) : null}
        {isPsikologiTestStep ? (
          <BulkReferralPdfButton
            kind="psychology"
            selectedApplicantUserIds={selectedAdvanceApplicantUserIds}
          />
        ) : null}
      </div>

      <p className="text-sm text-muted-foreground">
        {totalCount} pelamar
        {totalCount > 0 ? (
          <span className="text-muted-foreground/80">
            {" "}
            (menampilkan {(safePage - 1) * PAGE_SIZE + 1}–
            {Math.min(safePage * PAGE_SIZE, totalCount)})
          </span>
        ) : null}
      </p>

      <div className={cn(COHORT_DITERIMA_TABLE_SHELL, isFetching && "opacity-90")}>
        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          </div>
        ) : isMedicalStep ? (
          <Table>
            <TableHeader>
              <TableRow className={CD_HEADER_ROW}>
                <TableHead className="w-[42px]">
                  <Checkbox
                    checked={allAdvanceChecked}
                    onCheckedChange={toggleSelectAllAdvance}
                    aria-label="Pilih semua pelamar di tabel"
                  />
                </TableHead>
                <TableHead className="min-w-[12rem]">Pelamar</TableHead>
                <TableHead className="whitespace-nowrap">NIK</TableHead>
                <TableHead className="min-w-[14rem]">Pra-seleksi &amp; sesi</TableHead>
                <TableHead className="whitespace-nowrap">Tgl. medical</TableHead>
                <TableHead>Hasil medical</TableHead>
                <TableHead className="whitespace-nowrap">Tgl. bayar SML</TableHead>
                <TableHead className="min-w-[11rem]">Konfirmasi Pelamar</TableHead>
                <TableHead className="sticky right-0 z-10 w-[180px] bg-background text-right">
                  Aksi
                </TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredApps.length ? (
                filteredApps.map((app) => (
                  <TableRow key={app.id} className={CD_BODY_ROW}>
                    <TableCell className="align-top">
                      <Checkbox
                        checked={selectedAdvanceAppIds.has(app.id)}
                        onCheckedChange={() => toggleSelectAdvance(app.id, app)}
                        aria-label={`Pilih ${app.applicant_name}`}
                      />
                    </TableCell>
                    <TableCell className="align-top">
                      <div className="flex flex-col">
                        <span className="font-medium">{app.applicant_name}</span>
                        <span className="text-muted-foreground text-xs">{app.applicant_email}</span>
                      </div>
                    </TableCell>
                    <TableCell className="text-muted-foreground align-top text-xs">
                      {app.applicant_nik || "—"}
                    </TableCell>
                    <TableCell className="align-top min-w-0">
                      <PelamarTahapanSesiCell app={app} batchBase={batchBase} cohortBase={cohortBase} />
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
                      <DocumentCollectionProgressCell app={app} highlightStep="MEDICAL" />
                    </TableCell>
                    <TableCell className="sticky right-0 bg-background text-right align-top">
                      {actionsCell(app)}
                    </TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow>
                  <TableCell colSpan={9} className="h-20 text-center text-muted-foreground">
                    Tidak ada pelamar pada filter ini.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        ) : isFwcmsOrPsikologiStep ? (
          <Table>
            <TableHeader>
              <TableRow className={CD_HEADER_ROW}>
                <TableHead className="w-[42px]">
                  <Checkbox
                    checked={allAdvanceChecked}
                    onCheckedChange={toggleSelectAllAdvance}
                    aria-label="Pilih semua pelamar di tabel"
                  />
                </TableHead>
                <TableHead className="min-w-[12rem]">Pelamar</TableHead>
                <TableHead className="whitespace-nowrap">NIK</TableHead>
                <TableHead className="min-w-[14rem]">Pra-seleksi &amp; sesi</TableHead>
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
                  <TableRow key={app.id} className={CD_BODY_ROW}>
                    <TableCell className="align-top">
                      <Checkbox
                        checked={selectedAdvanceAppIds.has(app.id)}
                        onCheckedChange={() => toggleSelectAdvance(app.id, app)}
                        aria-label={`Pilih ${app.applicant_name}`}
                      />
                    </TableCell>
                    <TableCell className="align-top">
                      <div className="flex flex-col">
                        <span className="font-medium">{app.applicant_name}</span>
                        <span className="text-muted-foreground text-xs">{app.applicant_email}</span>
                      </div>
                    </TableCell>
                    <TableCell className="text-muted-foreground align-top text-xs">
                      {app.applicant_nik || "—"}
                    </TableCell>
                    <TableCell className="align-top min-w-0">
                      <PelamarTahapanSesiCell app={app} batchBase={batchBase} cohortBase={cohortBase} />
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
                        highlightStep={selectedDiterimaStep}
                      />
                    </TableCell>
                    <TableCell className="sticky right-0 bg-background text-right align-top">
                      {actionsCell(app)}
                    </TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow>
                  <TableCell colSpan={8} className="h-20 text-center text-muted-foreground">
                    Tidak ada pelamar pada filter ini.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        ) : isBuatIdPekerjaStep ? (
          <Table>
            <TableHeader>
              <TableRow className={CD_HEADER_ROW}>
                <TableHead className="w-[42px]">
                  <Checkbox
                    checked={allAdvanceChecked}
                    onCheckedChange={toggleSelectAllAdvance}
                    aria-label="Pilih semua"
                  />
                </TableHead>
                <TableHead className="min-w-[12rem]">Pelamar</TableHead>
                <TableHead>NIK</TableHead>
                <TableHead className="min-w-[14rem]">Pra-seleksi &amp; sesi</TableHead>
                <TableHead className="whitespace-nowrap min-w-[10rem]">No. ID pekerja (SISKO)</TableHead>
                <TableHead className="min-w-[11rem]">Konfirmasi Pelamar</TableHead>
                <TableHead className="sticky right-0 z-10 w-[180px] bg-background text-right">
                  Aksi
                </TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredApps.length ? (
                filteredApps.map((app) => (
                  <TableRow key={app.id} className={CD_BODY_ROW}>
                    <TableCell className="align-top">
                      <Checkbox
                        checked={selectedAdvanceAppIds.has(app.id)}
                        onCheckedChange={() => toggleSelectAdvance(app.id, app)}
                      />
                    </TableCell>
                    <TableCell className="align-top">
                      <span className="font-medium">{app.applicant_name}</span>
                      <span className="text-muted-foreground block text-xs">{app.applicant_email}</span>
                    </TableCell>
                    <TableCell className="text-xs text-muted-foreground">{app.applicant_nik || "—"}</TableCell>
                    <TableCell className="align-top min-w-0">
                      <PelamarTahapanSesiCell app={app} batchBase={batchBase} cohortBase={cohortBase} />
                    </TableCell>
                    <TableCell className="align-top font-mono text-sm">
                      {(app.no_id_sisko || "").trim() || "—"}
                    </TableCell>
                    <TableCell className="align-top text-sm">
                      <DocumentCollectionProgressCell app={app} highlightStep="BUAT_ID_PEKERJA" />
                    </TableCell>
                    <TableCell className="sticky right-0 bg-background text-right align-top">
                      {actionsCell(app)}
                    </TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow>
                  <TableCell colSpan={7} className="h-20 text-center text-muted-foreground">
                    Tidak ada pelamar pada filter ini.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        ) : isBuatPasporStep ? (
          <Table>
            <TableHeader>
              <TableRow className={CD_HEADER_ROW}>
                <TableHead className="w-[42px]">
                  <Checkbox
                    checked={allAdvanceChecked}
                    onCheckedChange={toggleSelectAllAdvance}
                    aria-label="Pilih semua"
                  />
                </TableHead>
                <TableHead>Pelamar</TableHead>
                <TableHead>NIK</TableHead>
                <TableHead className="min-w-[14rem]">Pra-seleksi &amp; sesi</TableHead>
                <TableHead className="min-w-[8rem] whitespace-nowrap">Berkas paspor</TableHead>
                <TableHead className="min-w-[12rem]">Detail paspor (profil)</TableHead>
                <TableHead className="min-w-[11rem]">Konfirmasi Pelamar</TableHead>
                <TableHead className="sticky right-0 z-10 w-[180px] bg-background text-right">
                  Aksi
                </TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredApps.length ? (
                filteredApps.map((app) => (
                  <TableRow key={app.id} className={CD_BODY_ROW}>
                    <TableCell className="align-top">
                      <Checkbox
                        checked={selectedAdvanceAppIds.has(app.id)}
                        onCheckedChange={() => toggleSelectAdvance(app.id, app)}
                      />
                    </TableCell>
                    <TableCell className="align-top">
                      <span className="font-medium">{app.applicant_name}</span>
                      <span className="text-muted-foreground block text-xs">{app.applicant_email}</span>
                    </TableCell>
                    <TableCell className="text-xs text-muted-foreground">{app.applicant_nik || "—"}</TableCell>
                    <TableCell className="align-top min-w-0">
                      <PelamarTahapanSesiCell app={app} batchBase={batchBase} cohortBase={cohortBase} />
                    </TableCell>
                    <TableCell className="align-top">
                      <PassportBerkasLink url={app.passport_file_url} />
                    </TableCell>
                    <TableCell className="align-top">
                      <PassportDetailBlock app={app} />
                    </TableCell>
                    <TableCell className="align-top text-sm">
                      <DocumentCollectionProgressCell app={app} highlightStep="BUAT_PASPOR" />
                    </TableCell>
                    <TableCell className="sticky right-0 bg-background text-right align-top">
                      {actionsCell(app)}
                    </TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow>
                  <TableCell colSpan={8} className="h-20 text-center text-muted-foreground">
                    Tidak ada pelamar pada filter ini.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        ) : (
          <Table>
            <TableHeader>
              <TableRow className={CD_HEADER_ROW}>
                {showCheckboxCol && (
                  <TableHead className="w-10">
                    <Checkbox
                      checked={onDiterimaSubStep ? allAdvanceChecked : allSelectableChecked}
                      onCheckedChange={
                        onDiterimaSubStep ? toggleSelectAllAdvance : toggleSelectAllApplicants
                      }
                      aria-label="Pilih semua di halaman ini"
                    />
                  </TableHead>
                )}
                <TableHead>Pelamar</TableHead>
                <TableHead>NIK</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="whitespace-nowrap min-w-[10rem]">Tahapan pra-seleksi</TableHead>
                <TableHead className="whitespace-nowrap">Konfirmasi dokumen</TableHead>
                <TableHead className="whitespace-nowrap">Tanggal konfirmasi</TableHead>
                <TableHead className="min-w-[11rem]">Pengumpulan Dokumen</TableHead>
                <TableHead className="sticky right-0 z-10 bg-background text-right">Aksi</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredApps.length ? (
                filteredApps.map((app) => {
                  const konfirmasi = cohortKonfirmasiDiterima(app)
                  return (
                    <TableRow key={app.id} className={CD_BODY_ROW}>
                      {showCheckboxCol && (
                        <TableCell>
                          <Checkbox
                            checked={
                              onDiterimaSubStep
                                ? selectedAdvanceAppIds.has(app.id)
                                : selectedAppIds.has(app.id)
                            }
                            onCheckedChange={() =>
                              onDiterimaSubStep
                                ? toggleSelectAdvance(app.id, app)
                                : toggleSelectApplicantRow(app.id, app)
                            }
                            aria-label={`Pilih ${app.applicant_name}`}
                          />
                        </TableCell>
                      )}
                      <TableCell>
                        <div className="flex flex-col">
                          <span className="font-medium">{app.applicant_name}</span>
                          <span className="text-muted-foreground text-xs">{app.applicant_email}</span>
                        </div>
                      </TableCell>
                      <TableCell className="text-muted-foreground text-xs">
                        {app.applicant_nik || "-"}
                      </TableCell>
                      <TableCell>
                        <ApplicationStatusBadge status={app.status} />
                      </TableCell>
                      <TableCell
                        className="text-sm"
                        onClick={(e) => e.stopPropagation()}
                      >
                        {app.batch != null ? (
                          <button
                            type="button"
                            className="inline-flex cursor-pointer items-center gap-1 text-left text-sm text-primary underline-offset-2 hover:underline"
                            onClick={() => navigate(`${batchBase}/${app.batch}`)}
                          >
                            {app.batch_name?.trim() ||
                              app.batch_tahap_label?.trim() ||
                              `Batch #${app.batch}`}
                            <IconExternalLink className="size-3 shrink-0" />
                          </button>
                        ) : (
                          <span className="text-muted-foreground">—</span>
                        )}
                      </TableCell>
                      <TableCell className="text-sm">
                        {!konfirmasi.applicable ? (
                          <span className="text-muted-foreground">—</span>
                        ) : konfirmasi.sudah ? (
                          <Badge
                            variant="outline"
                            className="border-green-600/40 bg-green-50 font-normal text-green-800"
                          >
                            Sudah
                          </Badge>
                        ) : (
                          <Badge variant="secondary" className="font-normal">
                            Belum
                          </Badge>
                        )}
                      </TableCell>
                      <TableCell className="text-muted-foreground whitespace-nowrap text-sm">
                        {!konfirmasi.applicable || !konfirmasi.waktuIso
                          ? "—"
                          : formatDateTimeDisplay(konfirmasi.waktuIso)}
                      </TableCell>
                      <TableCell className="align-top text-sm">
                        <DocumentCollectionProgressCell app={app} />
                      </TableCell>
                      <TableCell className="sticky right-0 bg-background text-right">
                        {actionsCell(app)}
                      </TableCell>
                    </TableRow>
                  )
                })
              ) : (
                <TableRow>
                  <TableCell
                    colSpan={showCheckboxCol ? 9 : 8}
                    className="h-20 text-center text-muted-foreground"
                  >
                    Tidak ada pelamar pada filter ini.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        )}
      </div>

      {pageCount > 1 && (
        <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-muted-foreground">
          <div>
            Halaman{" "}
            <span className="font-medium text-foreground">
              {safePage} / {pageCount}
            </span>
          </div>
          <div className="flex items-center gap-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="h-7 cursor-pointer px-2"
              disabled={safePage <= 1 || isLoading || isFetching}
              onClick={() => setPage((p) => Math.max(1, p - 1))}
            >
              Sebelumnya
            </Button>
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="h-7 cursor-pointer px-2"
              disabled={safePage >= pageCount || isLoading || isFetching}
              onClick={() => setPage((p) => Math.min(pageCount, p + 1))}
            >
              Berikutnya
            </Button>
          </div>
        </div>
      )}

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
          previewUserId != null ? `${pelamarBase}/${previewUserId}` : pelamarBase
        }
        open={previewUserId != null}
        onOpenChange={(next) => {
          if (!next) {
            setPreviewUserId(null)
            setPreviewUserLabel("")
          }
        }}
      />

      <Dialog open={confirmAnnouncementOpen} onOpenChange={setConfirmAnnouncementOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Kirim pengumuman?</DialogTitle>
            <DialogDescription>
              Pengumuman akan dikirim ke {selectedRecipientIds.length} pelamar terpilih.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setConfirmAnnouncementOpen(false)}>
              Batal
            </Button>
            <Button
              onClick={() => sendAnnouncementMutation.mutate()}
              disabled={sendAnnouncementMutation.isPending}
            >
              {sendAnnouncementMutation.isPending ? "Mengirim..." : "Kirim"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={confirmBulkOpen} onOpenChange={setConfirmBulkOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Pindahkan ke Berangkat</DialogTitle>
            <DialogDescription>
              Anda akan memindahkan {selectedAppIds.size} pelamar terpilih dari Diterima ke Berangkat.
              Aturan FSM dan kelengkapan dokumen tetap diberlakukan per lamaran.
            </DialogDescription>
          </DialogHeader>
          <div className="flex flex-col gap-1.5">
            <Label>
              Catatan <span className="text-muted-foreground text-xs">(opsional)</span>
            </Label>
            <Textarea value={note} onChange={(e) => setNote(e.target.value)} rows={3} />
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setConfirmBulkOpen(false)} disabled={isSubmittingBulk}>
              Batal
            </Button>
            <Button onClick={() => void runBulkToBerangkat()} disabled={isSubmittingBulk}>
              {isSubmittingBulk ? "Memproses..." : "Konfirmasi"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
