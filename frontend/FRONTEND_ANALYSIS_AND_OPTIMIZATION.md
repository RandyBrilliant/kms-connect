# Frontend Analysis & Optimization - KMS Connect

## Executive Summary

Your frontend is **well-architected** with modern best practices (React 19, TanStack Query/Table/Form, TypeScript, Zod). However, there are **15 areas for improvement** to sync with backend changes, optimize performance, and enhance admin UX.

---

## 1. Missing Backend Fields in Frontend Types

### 1.1 ApplicantProfile Missing Fields

**Backend fields not in frontend types:**

```typescript
// Missing from src/types/applicant.ts
export interface ApplicantProfile {
  // ... existing fields ...
  
  // MISSING: New fields from backend
  registration_date: string | null
  destination_country: string  // DestinationCountry choice
  district: string  // Kabupaten/Kota
  province: string  // Provinsi
  village: number | null  // ForeignKey to regions.Village
  family_district: string
  family_province: string
  family_village: number | null
  data_declaration_confirmed: boolean
  zero_cost_understood: boolean
  religion: string  // Religion choice
  education_level: string  // EducationLevel choice
  education_major: string
  height_cm: number | null
  weight_kg: number | null
  wears_glasses: boolean | null
  writing_hand: string  // WritingHand choice
  marital_status: string  // MaritalStatus choice
  has_passport: string  // HasPassport choice
  passport_number: string
  passport_expiry_date: string | null
  family_card_number: string
  diploma_number: string
  bpjs_number: string
  shoe_size: string
  shirt_size: string
  
  // Computed/helper fields from backend
  age?: number  // Read-only computed property
  days_since_submission?: number  // Read-only
  is_passport_expired?: boolean  // Read-only
  document_approval_rate?: number  // Read-only
  has_complete_documents?: boolean  // Read-only
}
```

### 1.2 WorkExperience Missing Fields

```typescript
// Missing from src/types/applicant.ts
export interface WorkExperience {
  // ... existing fields ...
  
  // MISSING:
  location: string  // City/location
  country: string  // WorkCountry choice
  industry_type: string  // Industrytype choice
  department: string  // Department/division
}
```

### 1.3 Missing Choice Type Definitions

```typescript
// Add to src/types/applicant.ts
export type DestinationCountry = "MALAYSIA"

export type Religion =
  | "ISLAM"
  | "KRISTEN"
  | "KATHOLIK"
  | "HINDU"
  | "BUDHA"
  | "LAINNYA"

export type EducationLevel =
  | "SMP"
  | "SMA"
  | "SMK"
  | "MA"
  | "D3"
  | "S1"

export type WritingHand = "KANAN" | "KIRI"

export type MaritalStatus =
  | "BELUM MENIKAH"
  | "MENIKAH"
  | "CERAI HIDUP"
  | "CERAI MATI"

export type HasPassport = "BELUM" | "SUDAH"

export type WorkCountry =
  | "INDONESIA"
  | "MALAYSIA"
  | "NEGARA LAIN"

export type IndustryType =
  | "SEMICONDUCTOR"
  | "ELEKTRONIK"
  | "PABRIK LAIN"
  | "JASA"
  | "LAIN LAIN"
  | "BELUM PERNAH BEKERJA"
```

---

## 2. Performance Optimizations

### 2.1 Missing Query Optimizations

**Problem:** Frontend doesn't utilize backend's optimized query endpoints.

**Backend provides:**
- `/api/applicants/?with_related=true` - Loads related data
- `/api/applicants/?verification_status=SUBMITTED&province=JAWA%20BARAT` - Composite filtering

**Recommendation:** Add optimized query parameters

```typescript
// src/types/applicant.ts
export interface ApplicantsListParams {
  page?: number
  page_size?: number
  search?: string
  is_active?: boolean
  email_verified?: boolean
  verification_status?: ApplicantVerificationStatus
  ordering?: string
  
  // ADD: New filter params
  province?: string
  district?: string
  referrer?: number
  submitted_after?: string  // ISO date
  submitted_before?: string
  with_related?: boolean  // Use backend optimized queries
}
```

### 2.2 Implement Bulk Operations

**Backend provides:** `bulk_update_status()` method

**Frontend missing:** Bulk approve/reject UI

**Impact:** Admin currently must approve applicants one-by-one

**Recommendation:** Add bulk selection and actions

```typescript
// src/api/applicants.ts
export async function bulkApproveApplicants(
  profileIds: number[],
  verifiedById: number,
  notes?: string
): Promise<{ updated: number }> {
  const { data } = await api.post("/api/applicants/bulk_approve/", {
    profile_ids: profileIds,
    verified_by: verifiedById,
    notes,
  })
  return data
}

export async function bulkRejectApplicants(
  profileIds: number[],
  verifiedById: number,
  notes: string
): Promise<{ updated: number }> {
  const { data } = await api.post("/api/applicants/bulk_reject/", {
    profile_ids: profileIds,
    verified_by: verifiedById,
    notes,
  })
  return data
}
```

### 2.3 Implement Caching for Static Data

**Backend provides:** `DocumentType.get_all_cached()`, `DocumentType.get_required_cached()`

**Frontend:** Currently fetches document types on every page load

**Recommendation:** Use longer cache time for static data

```typescript
// src/hooks/use-applicants-query.ts
export function useDocumentTypesQuery() {
  return useQuery({
    queryKey: documentTypesKeys.all,
    queryFn: () => getDocumentTypes(),
    staleTime: 1000 * 60 * 60, // 1 hour - these rarely change
    gcTime: 1000 * 60 * 60 * 24, // 24 hours
  })
}
```

### 2.4 Add Optimistic Updates

**Current:** UI waits for server response before updating

**Better:** Optimistic updates for faster perceived performance

```typescript
// Example for toggling activation
export function useActivateApplicantMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => activateApplicant(id),
    // Optimistic update
    onMutate: async (id) => {
      await queryClient.cancelQueries({ queryKey: applicantsKeys.detail(id) })
      const previous = queryClient.getQueryData(applicantsKeys.detail(id))
      
      queryClient.setQueryData(applicantsKeys.detail(id), (old: ApplicantUser) => ({
        ...old,
        is_active: true,
      }))
      
      return { previous }
    },
    onError: (err, id, context) => {
      queryClient.setQueryData(applicantsKeys.detail(id), context?.previous)
    },
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: applicantsKeys.lists() })
    },
  })
}
```

---

## 3. Code Quality Improvements

### 3.1 Extract Reusable Constants

**Problem:** Magic strings scattered across files

**Better:** Centralized constants

```typescript
// src/constants/applicant.ts (NEW FILE)
export const VERIFICATION_STATUS_LABELS: Record<ApplicantVerificationStatus, string> = {
  DRAFT: "Draf",
  SUBMITTED: "Dikirim",
  ACCEPTED: "Diterima",
  REJECTED: "Ditolak",
} as const

export const VERIFICATION_STATUS_COLORS: Record<ApplicantVerificationStatus, string> = {
  DRAFT: "outline",
  SUBMITTED: "secondary",
  ACCEPTED: "default",
  REJECTED: "destructive",
} as const

export const GENDER_LABELS: Record<Gender, string> = {
  M: "Laki-laki",
  F: "Perempuan",
  O: "Lainnya",
} as const

export const RELIGION_LABELS: Record<Religion, string> = {
  ISLAM: "Islam",
  KRISTEN: "Kristen",
  KATHOLIK: "Katholik",
  HINDU: "Hindu",
  BUDHA: "Budha",
  LAINNYA: "Lainnya",
} as const

// ... etc for all choices
```

### 3.2 Create Utility Functions

```typescript
// src/lib/formatters.ts (NEW FILE)
import { format, formatDistanceToNow } from "date-fns"
import { id } from "date-fns/locale"

export function formatDate(date: string | Date | null): string {
  if (!date) return "-"
  return format(new Date(date), "dd MMM yyyy", { locale: id })
}

export function formatDateTime(date: string | Date | null): string {
  if (!date) return "-"
  return format(new Date(date), "dd MMM yyyy HH:mm", { locale: id })
}

export function formatRelativeTime(date: string | Date | null): string {
  if (!date) return "-"
  return formatDistanceToNow(new Date(date), { addSuffix: true, locale: id })
}

export function formatNIK(nik: string): string {
  if (!nik || nik.length !== 16) return nik
  // Format: 3302 0123 4567 8901
  return nik.replace(/(\d{4})(\d{4})(\d{4})(\d{4})/, "$1 $2 $3 $4")
}

export function formatPhone(phone: string): string {
  if (!phone) return "-"
  // Convert 08xxx to +62 8xxx format
  if (phone.startsWith("0")) {
    return `+62 ${phone.substring(1)}`
  }
  return phone
}
```

### 3.3 Add Validation Schemas

**Missing:** Zod schemas for new fields

```typescript
// src/schemas/applicant.ts
import { z } from "zod"

export const applicantProfileUpdateSchema = z.object({
  full_name: z.string().min(1, "Nama wajib diisi"),
  nik: z.string().regex(/^\d{16}$/, "NIK harus 16 digit"),
  birth_date: z.string().nullable(),
  birth_place: z.string().optional(),
  address: z.string().optional(),
  contact_phone: z.string().regex(/^(\+?62|0)\d{9,12}$/, "Format nomor tidak valid").optional(),
  gender: z.enum(["M", "F", "O"]).optional(),
  religion: z.enum(["ISLAM", "KRISTEN", "KATHOLIK", "HINDU", "BUDHA", "LAINNYA"]).optional(),
  education_level: z.enum(["SMP", "SMA", "SMK", "MA", "D3", "S1"]).optional(),
  height_cm: z.number().min(140).max(220).nullable().optional(),
  weight_kg: z.number().min(35).max(200).nullable().optional(),
  marital_status: z.enum(["BELUM MENIKAH", "MENIKAH", "CERAI HIDUP", "CERAI MATI"]).optional(),
  has_passport: z.enum(["BELUM", "SUDAH"]).optional(),
  passport_number: z.string().regex(/^[A-Z]{2}\d{7}$/, "Format paspor tidak valid (contoh: AB1234567)").optional(),
  passport_expiry_date: z.string().nullable().optional(),
  family_card_number: z.string().regex(/^\d{16}$/, "Nomor KK harus 16 digit").optional(),
  bpjs_number: z.string().regex(/^\d{13}$/, "Nomor BPJS harus 13 digit").optional(),
  // ... add all other new fields
})
```

### 3.4 Add Error Boundary

**Missing:** Global error handling for components

```typescript
// src/components/error-boundary.tsx (NEW FILE)
import { Component, ErrorInfo, ReactNode } from "react"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"

interface Props {
  children: ReactNode
}

interface State {
  hasError: boolean
  error?: Error
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props)
    this.state = { hasError: false }
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error("Error caught by boundary:", error, errorInfo)
  }

  render() {
    if (this.state.hasError) {
      return (
        <Card className="m-8 p-6">
          <h2 className="text-xl font-bold text-destructive">
            Terjadi Kesalahan
          </h2>
          <p className="text-muted-foreground mt-2">
            {this.state.error?.message || "Kesalahan tidak diketahui"}
          </p>
          <Button
            onClick={() => this.setState({ hasError: false })}
            className="mt-4 cursor-pointer"
          >
            Coba Lagi
          </Button>
        </Card>
      )
    }

    return this.props.children
  }
}
```

---

## 4. Admin UX Enhancements

### 4.1 Add Verification Status Actions

**Missing:** Quick approve/reject actions in list view

**Recommendation:** Add action buttons in table

```typescript
// In applicant-table.tsx columns
{
  id: "verification_actions",
  header: "Verifikasi",
  cell: ({ row }) => {
    const applicant = row.original
    const status = applicant.applicant_profile?.verification_status
    
    if (status === "SUBMITTED") {
      return (
        <div className="flex gap-1">
          <Button
            variant="default"
            size="sm"
            className="h-7 cursor-pointer"
            onClick={() => handleQuickApprove(applicant)}
          >
            <IconCheck className="mr-1 size-3" />
            Terima
          </Button>
          <Button
            variant="destructive"
            size="sm"
            className="h-7 cursor-pointer"
            onClick={() => handleQuickReject(applicant)}
          >
            <IconX className="mr-1 size-3" />
            Tolak
          </Button>
        </div>
      )
    }
    
    return <Badge variant={getStatusVariant(status)}>{VERIFICATION_STATUS_LABELS[status]}</Badge>
  }
}
```

### 4.2 Add Filters Panel

**Current:** Basic filters in dropdown

**Better:** Advanced filters panel

```typescript
// src/components/applicants/applicant-filters.tsx (NEW COMPONENT)
export function ApplicantFilters({ 
  onFilterChange 
}: { 
  onFilterChange: (filters: ApplicantsListParams) => void 
}) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Filter Pelamar</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <Field>
            <FieldLabel>Provinsi</FieldLabel>
            <Select onValueChange={(v) => handleChange("province", v)}>
              <SelectTrigger>
                <SelectValue placeholder="Pilih provinsi" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="">Semua</SelectItem>
                {provinces.map((p) => (
                  <SelectItem key={p} value={p}>{p}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </Field>
          
          <Field>
            <FieldLabel>Kabupaten/Kota</FieldLabel>
            <Select onValueChange={(v) => handleChange("district", v)}>
              <SelectTrigger>
                <SelectValue placeholder="Pilih kabupaten" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="">Semua</SelectItem>
                {districts.map((d) => (
                  <SelectItem key={d} value={d}>{d}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </Field>
          
          <Field>
            <FieldLabel>Tanggal Submit (Dari)</FieldLabel>
            <DatePicker
              date={submitDateFrom}
              onSelect={(d) => handleChange("submitted_after", d?.toISOString())}
            />
          </Field  >
          
          <Field>
            <FieldLabel>Tanggal Submit (Sampai)</FieldLabel>
            <DatePicker
              date={submitDateTo}
              onSelect={(d) => handleChange("submitted_before", d?.toISOString())}
            />
          </Field>
        </div>
        
        <div className="flex gap-2">
          <Button variant="default" onClick={applyFilters}>
            Terapkan Filter
          </Button>
          <Button variant="outline" onClick={clearFilters}>
            Reset
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}
```

### 4.3 Add Bulk Selection

**Missing:** Select multiple applicants for bulk actions

```typescript
// In applicant-table.tsx
const [selectedRows, setSelectedRows] = useState<Set<number>>(new Set())

// Add checkbox column
{
  id: "select",
  header: ({ table }) => (
    <Checkbox
      checked={table.getIsAllRowsSelected()}
      onCheckedChange={(value) => {
        table.toggleAllRowsSelected(!!value)
        if (value) {
          setSelectedRows(new Set(table.getRowModel().rows.map(r => r.original.id)))
        } else {
          setSelectedRows(new Set())
        }
      }}
    />
  ),
  cell: ({ row }) => (
    <Checkbox
      checked={selectedRows.has(row.original.id)}
      onCheckedChange={(value) => {
        const newSelected = new Set(selectedRows)
        if (value) {
          newSelected.add(row.original.id)
        } else {
          newSelected.delete(row.original.id)
        }
        setSelectedRows(newSelected)
      }}
    />
  ),
}

// Add bulk action bar
{selectedRows.size > 0 && (
  <div className="fixed bottom-0 left-0 right-0 border-t bg-background p-4 shadow-lg">
    <div className="container mx-auto flex items-center justify-between">
      <p className="text-sm">{selectedRows.size} pelamar dipilih</p>
      <div className="flex gap-2">
        <Button
          variant="default"
          onClick={() => handleBulkApprove(Array.from(selectedRows))}
        >
          Terima Semua
        </Button>
        <Button
          variant="destructive"
          onClick={() => handleBulkReject(Array.from(selectedRows))}
        >
          Tolak Semua
        </Button>
        <Button
          variant="outline"
          onClick={() => setSelectedRows(new Set())}
        >
          Batal
        </Button>
      </div>
    </div>
  </div>
)}
```

### 4.4 Add Statistics Dashboard

**Missing:** Quick overview of applicant statistics

```typescript
// src/components/applicants/applicant-stats.tsx (NEW)
export function ApplicantStats() {
  const { data: stats } = useQuery({
    queryKey: ["applicant-stats"],
    queryFn: async () => {
      const [total, pending, accepted, rejected] = await Promise.all([
        getApplicants({ page_size: 1 }),
        getApplicants({ verification_status: "SUBMITTED", page_size: 1 }),
        getApplicants({ verification_status: "ACCEPTED", page_size: 1 }),
        getApplicants({ verification_status: "REJECTED", page_size: 1 }),
      ])
      return {
        total: total.count,
        pending: pending.count,
        accepted: accepted.count,
        rejected: rejected.count,
      }
    },
  })

  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <StatsCard
        title="Total Pelamar"
        value={stats?.total ?? 0}
        icon={<IconUsers />}
      />
      <StatsCard
        title="Menunggu Review"
        value={stats?.pending ?? 0}
        icon={<IconClock />}
        variant="warning"
      />
      <StatsCard
        title="Diterima"
        value={stats?.accepted ?? 0}
        icon={<IconCheck />}
        variant="success"
      />
      <StatsCard
        title="Ditolak"
        value={stats?.rejected ?? 0}
        icon={<IconX />}
        variant="danger"
      />
    </div>
  )
}
```

### 4.5 Add Export Functionality

**Missing:** Export filtered applicants to Excel

```typescript
// src/api/applicants.ts
export async function exportApplicants(
  params: ApplicantsListParams
): Promise<Blob> {
  const { data } = await api.get("/api/applicants/export/", {
    params,
    responseType: "blob",
  })
  return data
}

// In table component
const handleExport = async () => {
  try {
    const blob = await exportApplicants(params)
    const url = URL.createObjectURL(blob)
    const a = document.createElement("a")
    a.href = url
    a.download = `pelamar-${format(new Date(), "yyyy-MM-dd")}.xlsx`
    a.click()
    URL.revokeObjectURL(url)
    toast.success("Export berhasil")
  } catch {
    toast.error("Export gagal")
  }
}
```

---

## 5. Missing Features from Backend

### 5.1 Approval/Rejection Workflow

**Backend provides:** `approve()`, `reject()`, `submit_for_verification()` methods

**Frontend missing:** Proper workflow UI

```typescript
// src/components/applicants/verification-modal.tsx (NEW)
export function VerificationModal({
  applicant,
  action,
  onClose,
}: {
  applicant: ApplicantUser
  action: "approve" | "reject"
  onClose: () => void
}) {
  const [notes, setNotes] = useState("")
  const updateMutation = useUpdateApplicantMutation(applicant.id)

  const handleSubmit = async () => {
    try {
      await updateMutation.mutateAsync({
        applicant_profile: {
          verification_status: action === "approve" ? "ACCEPTED" : "REJECTED",
          verification_notes: notes,
          verified_at: new Date().toISOString(),
        },
      })
      toast.success(
        action === "approve" ? "Pelamar disetujui" : "Pelamar ditolak"
      )
      onClose()
    } catch {
      toast.error("Gagal menyimpan")
    }
  }

  return (
    <Dialog open onOpenChange={onClose}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {action === "approve" ? "Terima" : "Tolak"} Pelamar
          </DialogTitle>
          <DialogDescription>
            {applicant.applicant_profile?.full_name} - {applicant.email}
          </DialogDescription>
        </DialogHeader>
        
        <div className="space-y-4 py-4">
          <Field>
            <FieldLabel>
              Catatan {action === "reject" && <span className="text-destructive">*</span>}
            </FieldLabel>
            <Textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder={
                action === "approve"
                  ? "Catatan opsional untuk persetujuan"
                  : "Alasan penolakan (wajib diisi)"
              }
              rows={4}
            />
          </Field>
        </div>
        
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            Batal
          </Button>
          <Button
            variant={action === "approve" ? "default" : "destructive"}
            onClick={handleSubmit}
            disabled={action === "reject" && !notes.trim()}
          >
            {action === "approve" ? "Terima" : "Tolak"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
```

### 5.2 Document Review Status

**Backend has:** `review_status`, `reviewed_by`, `reviewed_at`, `review_notes`

**Frontend shows:** Basic upload/delete only

**Missing:** Admin review UI for documents

```typescript
// src/components/applicants/document-review-card.tsx (NEW)
export function DocumentReviewCard({
  document,
  applicantId,
}: {
  document: ApplicantDocument
  applicantId: number
}) {
  const [reviewStatus, setReviewStatus] = useState(document.review_status)
  const [notes, setNotes] = useState(document.review_notes || "")
  const updateMutation = useUpdateApplicantDocumentMutation(applicantId)

  const handleReview = async (status: DocumentReviewStatus) => {
    try {
      await updateMutation.mutateAsync({
        id: document.id,
        input: {
          review_status: status,
          review_notes: notes,
        },
      })
      setReviewStatus(status)
      toast.success(
        status === "APPROVED" ? "Dokumen disetujui" : "Dokumen ditolak"
      )
    } catch {
      toast.error("Gagal menyimpan review")
    }
  }

  return (
    <Card>
      <CardHeader>
        <div className="flex items-start justify-between">
          <div>
            <CardTitle className="text-base">{document.document_type}</CardTitle>
            <CardDescription>
              Upload: {formatDateTime(document.uploaded_at)}
            </CardDescription>
          </div>
          <Badge variant={getReviewStatusVariant(reviewStatus)}>
            {REVIEW_STATUS_LABELS[reviewStatus]}
          </Badge>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        <div>
          <a
            href={document.file}
            target="_blank"
            rel="noopener noreferrer"
            className="text-primary hover:underline"
          >
            Lihat Dokumen →
          </a>
        </div>
        
        {reviewStatus === "PENDING" && (
          <>
            <Field>
              <FieldLabel>Catatan Review</FieldLabel>
              <Textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Tambahkan catatan (opsional untuk approve, wajib untuk reject)"
                rows={3}
              />
            </Field>
            
            <div className="flex gap-2">
              <Button
                variant="default"
                size="sm"
                onClick={() => handleReview("APPROVED")}
              >
                <IconCheck className="mr-1 size-4" />
                Setujui
              </Button>
              <Button
                variant="destructive"
                size="sm"
                onClick={() => handleReview("REJECTED")}
                disabled={!notes.trim()}
              >
                <IconX className="mr-1 size-4" />
                Tolak
              </Button>
            </div>
          </>
        )}
        
        {reviewStatus !== "PENDING" && document.review_notes && (
          <div className="rounded-md bg-muted p-3 text-sm">
            <p className="font-medium">Catatan:</p>
            <p className="text-muted-foreground">{document.review_notes}</p>
          </div>
        )}
      </CardContent>
    </Card>
  )
}
```

---

## 6. TypeScript Improvements

### 6.1 Add Type Guards

```typescript
// src/lib/type-guards.ts (NEW)
import type { ApplicantUser } from "@/types/applicant"

export function isApplicantActive(applicant: ApplicantUser): boolean {
  return applicant.is_active && applicant.email_verified
}

export function canBeApproved(applicant: ApplicantUser): boolean {
  return (
    applicant.applicant_profile?.verification_status === "SUBMITTED" &&
    applicant.is_active
  )
}

export function hasRequiredDocuments(applicant: ApplicantUser): boolean {
  // Check if all required documents are uploaded and approved
  return applicant.applicant_profile?.has_complete_documents ?? false
}
```

### 6.2 Improve API Error Types

```typescript
// src/types/api.ts
export interface APIError {
  detail?: string
  errors?: Record<string, string[] | Record<string, string[]>>
  non_field_errors?: string[]
}

export interface APIValidationError {
  field: string
  messages: string[]
}

export function parseAPIError(error: unknown): APIValidationError[] {
  const e = error as { response?: { data?: APIError } }
  const data = e?.response?.data
  
  if (!data) return []
  
  const errors: APIValidationError[] = []
  
  if (data.errors) {
    for (const [field, messages] of Object.entries(data.errors)) {
      if (Array.isArray(messages)) {
        errors.push({ field, messages })
      } else if (typeof messages === "object") {
        for (const [subField, subMessages] of Object.entries(messages)) {
          errors.push({
            field: `${field}.${subField}`,
            messages: Array.isArray(subMessages) ? subMessages : [String(subMessages)],
          })
        }
      }
    }
  }
  
  if (data.non_field_errors) {
    errors.push({ field: "__all__", messages: data.non_field_errors })
  }
  
  return errors
}
```

---

## Implementation Priority

### Phase 1: Critical (Week 1)
1. ✅ Update types with missing backend fields
2. ✅ Add choice type definitions and labels
3. ✅ Create constants file for labels
4. ✅ Update biodata form with new fields
5. ✅ Add verification workflow modal

### Phase 2: High Impact (Week 2)
1. ✅ Implement bulk selection and actions
2. ✅ Add document review UI
3. ✅ Create advanced filters panel
4. ✅ Add statistics dashboard
5. ✅ Implement optimistic updates

### Phase 3: Nice-to-Have (Week 3)
1. ✅ Add export functionality
2. ✅ Create utility functions
3. ✅ Add error boundary
4. ✅ Implement type guards
5. ✅ Add loading skeletons

---

## Quick Wins (Implement First)

1. **Add missing type fields** (30 min)
2. **Create constants file** (20 min)
3. **Update table with verification actions** (1 hour)
4. **Add bulk approve/reject** (2 hours)
5. **Implement document review** (1 hour)

Total: ~5 hours for major UX improvements!

---

## Files to Create/Modify

### New Files:
- `src/types/choices.ts` - All choice types and labels
- `src/constants/applicant.ts` - Labels, colors, etc.
- `src/lib/formatters.ts` - Format functions
- `src/lib/type-guards.ts` - Type guard functions
- `src/components/applicants/applicant-filters.tsx`
- `src/components/applicants/applicant-stats.tsx`
- `src/components/applicants/verification-modal.tsx`
- `src/components/applicants/document-review-card.tsx`
- `src/components/error-boundary.tsx`
- `src/api/bulk-actions.ts` - Bulk operations

### Files to Modify:
- `src/types/applicant.ts` - Add missing fields
- `src/api/applicants.ts` - Add bulk endpoints
- `src/hooks/use-applicants-query.ts` - Add bulk mutations
- `src/components/applicants/applicant-table.tsx` - Add bulk selection
- `src/components/applicants/applicant-biodata-tab.tsx` - Add new fields
- `src/components/applicants/applicant-documents-tab.tsx` - Add review UI
- `src/schemas/applicant.ts` - Add validation for new fields

---

See `FRONTEND_IMPLEMENTATION_GUIDE.md` for step-by-step code!
