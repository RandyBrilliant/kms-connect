# Context Pack For New Chat

Project: `kms-connect`  
Goal: migrate interview workflow from `LamaranBatch` to `InterviewCohort` and align admin frontend UX.

---

## 1) Product/Domain Overview

### Old model (before changes)
- `LamaranBatch` handled:
  - pra-seleksi scheduling
  - interview scheduling
  - bulk transitions

### New model (target)
- `LamaranBatch` is **pra-seleksi only**.
- Interview and subsequent stages are managed by **`InterviewCohort`** (per job).
- `JobApplication` has nullable FK `interview_cohort`.
- Transition to `INTERVIEW` requires selecting `interview_cohort`.

---

## 2) Backend State (Implemented)

### Data model + migrations
- Added `InterviewCohort` model.
- Added `JobApplication.interview_cohort` (nullable, `PROTECT`).
- Removed interview schedule fields from `LamaranBatch`.
- Added migrations including backfill from old batch interview data.

### API changes
- New endpoints under `/api/interview-cohorts/`:
  - list/create
  - detail/patch
  - `transition`
  - `assign`
  - `assign-from-batch`
- Batch `bulk-transition` rules:
  - from `PRA_SELEKSI`: only `INTERVIEW` (requires `interview_cohort`) or `DITOLAK`.
  - later-stage bulk transitions happen via cohort `transition`.
- Single application transition:
  - `PATCH /api/applications/{id}/transition/` requires `interview_cohort` when target is `INTERVIEW`.

---

## 3) Frontend State (Implemented)

### Types/API
- Added `frontend/src/types/interview-cohort.ts`.
- Updated `frontend/src/types/lamaran-batch.ts`:
  - batch stage effectively pra-seleksi only.
  - `BulkTransitionInput` includes `interview_cohort`.
- Updated `frontend/src/types/job-applications.ts`:
  - `interview_cohort` fields and transition input.
- Added `frontend/src/api/interview-cohorts.ts`:
  - includes unwrap helpers for both `{data: ...}` and plain paginated responses.
- Updated `frontend/src/api/applications.ts`:
  - supports `interview_cohort` filter.

### New pages
- `frontend/src/pages/admin-interview-cohort-form-page.tsx`
- `frontend/src/pages/admin-interview-cohort-detail-page.tsx`

### Routing
- Added routes in `frontend/src/App.tsx` for both `/` (master admin) and `/admin-portal`:
  - `lowongan-kerja/:jobId/gelombang/baru`
  - `gelombang/:id`

### UI updates done
- `admin-batch-list-page.tsx`: removed interview column.
- `admin-batch-detail-page.tsx`:
  - removed interview schedule card from batch.
  - stats use derived interview confirmations from applications.
  - status-tab transition to `INTERVIEW` requires choosing cohort.
  - invalidates `interview-cohorts` queries.
  - removed dead bulkTransition placeholder.
- `transition-application-dialog.tsx`:
  - when `PRA_SELEKSI -> INTERVIEW`, user must pick cohort.
- `use-applications-query.ts`:
  - transition mutation invalidates interview-cohort query keys.

---

## 4) Latest UX Direction Requested (Most Recent Change)

User requested:
- remove dedicated **Batch** tab on Job Detail.
- merge batch workflow into **Pra-Seleksi** tab for easier admin flow.

Implemented in `frontend/src/pages/admin-job-detail-page.tsx`:
- removed `Batch` tab trigger/content.
- `PRA_SELEKSI` tab now includes:
  1) batch + interview cohort overview block
  2) pra-seleksi applications list
- default tab is now `PRA_SELEKSI`.
- tab-return invalidation moved from `"batch"` to `"PRA_SELEKSI"`.

---

## 5) Current Behavior Summary

### Job Detail page
- Tabs: `Info`, `Edit` (if allowed), `Pra-Seleksi`, `Interview`, `Diterima`, `Berangkat`, `Selesai`, `Ditolak`.
- `Pra-Seleksi` tab now acts as operational center:
  - create/open batch
  - create/open interview cohort
  - see all pra-seleksi applicants

### Batch Detail page
- Still has richer operational tools:
  - pra-seleksi schedule
  - per-status tab actions
  - announcements
  - export excel
  - transitions (including to interview with cohort selection)

---

## 6) What Still Needs To Be Done (Per User Intent)

User explicitly wants next phase:
1. **Inside batch, only transition to interview session**
   - simplify batch status actions so batch is only pra-seleksi scope.
   - likely hide/disable non-pra-seleksi transition flows in batch context.

2. **Export Excel only for pra-seleksi applicants in that batch**
   - in `admin-batch-detail-page.tsx`, currently export supports multiple status filters.
   - change export UX and call to only export pra-seleksi dataset for the batch.

3. **Send pengumuman should follow pra-seleksi/batch-focused flow**
   - simplify announcement recipient options to pra-seleksi-in-batch scope (as requested).
   - align backend payload (may need backend constraint if currently supports broad status selection).

4. **Potential backend hardening (if strict behavior required)**
   - enforce constraints server-side (not only UI):
     - batch transitions restricted as desired.
     - export endpoint forced to pra-seleksi-only for batch mode.
     - announcement recipient rules narrowed if required.

---

## 7) Known Technical Notes / Risks

- API responses are mixed between wrapped and unwrapped formats across endpoints; interview cohort list now safely handles both.
- React Query stale cache caused stale UI before; invalidation points were added.
- Existing lint errors in `App.tsx` around `any` are pre-existing and unrelated to this feature.
- Large dirty working tree exists in repo (many untracked files, including env/node_modules artifacts).

---

## 8) Suggested Next Implementation Plan (For New Chat)

1. **Batch detail UX simplification**
   - remove non-pra-seleksi status tabs or actions.
   - keep only:
     - pra-seleksi list
     - transition selected -> interview cohort
     - reject if still required by product.
2. **Export simplification**
   - single export action: pra-seleksi only.
   - update `exportBatchExcel` call accordingly.
3. **Announcement simplification**
   - remove multi-status picker in batch detail.
   - recipient config fixed to pra-seleksi in current batch.
4. **Server validation (optional but recommended)**
   - enforce constraints in backend to prevent bypass from old clients.
5. **QA pass**
   - create batch, assign applicants, schedule pra-seleksi, export, send announcement, transition to interview with cohort.
   - verify counts and list refresh in job detail pra-seleksi tab.

---

## 9) Files Most Relevant For Next Chat

### Frontend
- `frontend/src/pages/admin-job-detail-page.tsx`
- `frontend/src/pages/admin-batch-detail-page.tsx`
- `frontend/src/pages/admin-batch-list-page.tsx`
- `frontend/src/pages/admin-interview-cohort-form-page.tsx`
- `frontend/src/pages/admin-interview-cohort-detail-page.tsx`
- `frontend/src/components/applications/transition-application-dialog.tsx`
- `frontend/src/hooks/use-applications-query.ts`
- `frontend/src/api/interview-cohorts.ts`
- `frontend/src/api/batches.ts`
- `frontend/src/types/lamaran-batch.ts`
- `frontend/src/types/job-applications.ts`
- `frontend/src/types/interview-cohort.ts`
- `frontend/src/App.tsx`

### Backend
- `backend/main/models.py`
- `backend/main/serializers.py`
- `backend/main/views.py`
- `backend/main/urls.py`
- `backend/main/services.py`
- migrations under `backend/main/migrations/` for interview cohort changes

---

If you want, I can also generate a shorter copy-paste “next chat prompt” version in a second `.md` file.
