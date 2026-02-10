# Account App & Backend – Analysis & Recommendations

Analysis of the `account` app and backend for the KMS-Connect TKI recruitment platform, with a focus on **improvements**, **optimization**, and **scalability for thousands of job seekers**.

**Implementation status:** The recommendations below have been implemented in code (rate limiting, cache, public document types, pagination, health check, env.example, optional storage). Run `python manage.py makemigrations` (with venv active) to generate the migration for the new `ApplicantProfile` index.

---

## 1. What’s Already in Good Shape

- **Email-based auth** with `CustomUser`, roles (Admin, Staff, Company, Applicant), and `db_index` on `email`, `role`, `email_verified`, `google_id`.
- **JWT + HTTP-only cookies** for web and Bearer for mobile; cookie settings configurable via `SIMPLE_JWT`.
- **Structured API responses** via `api_responses` (detail, code, errors) and custom exception handler.
- **Consistent permissions**: `IsBackofficeAdmin`, role-based viewsets, no hard delete (deactivate only).
- **ApplicantProfile** aligned with FORM BIODATA PMI; verification workflow (DRAFT → SUBMITTED → ACCEPTED/REJECTED).
- **Document types & specs**: `document_specs.py` with size/format validation; image optimization and OCR in Celery.
- **Indexes** on `CustomUser` (role, is_active), `ApplicantProfile` (user, full_name, referrer, verification_status, created_at), `ApplicantDocument`, `WorkExperience`, etc.
- **Celery** for OCR, image optimization, and email (verification, password reset) with retries.
- **PostgreSQL** support via `DATABASE_URL`; django-environ for env-based config.

---

## 2. Improvements (Code Quality & Correctness)

### 2.1 Pagination for List Endpoints

- **Current**: Global `PAGE_SIZE = 20` in DRF; no explicit cap on list size.
- **Recommendation**: Keep `PageNumberPagination`; add `max_page_size` (e.g. 100) and consider `CursorPagination` for very large applicant lists to avoid deep offset cost and keep response size predictable.

```python
# settings.py – optional
REST_FRAMEWORK = {
    ...
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 20,
}
# In viewset, if you add LimitOffsetPagination or CursorPagination later:
# pagination_class = ... max_page_size = 100
```

### 2.2 Applicant List Queryset – Avoid N+1 and Heavy Serialization

- **Current**: `ApplicantUserViewSet.get_queryset()` uses `select_related("applicant_profile")` only.
- **Recommendation**: For list action, avoid loading nested relations you don’t need (e.g. work_experiences, documents). If you add list-only serializers later, use `only()`/`defer()` for very wide models. For now, `select_related("applicant_profile")` is good; ensure list serialization doesn’t nest full documents/work_experiences by default.

### 2.3 DocumentTypeViewSet Permission vs Public Needs

- **Current**: `DocumentTypeViewSet` uses `IsBackofficeAdmin`; queryset is read-only.
- **Recommendation**: If the **mobile app** needs to show document types (e.g. for upload checklist), add a **separate read-only endpoint** for unauthenticated or applicant users (e.g. `GET /api/document-types/public/` or allow `GET` with `AllowAny` on a dedicated view). Keep admin viewset as-is for backoffice.

### 2.4 Serializer Querysets (referrer / verified_by)

- **Current**: `ApplicantProfileSerializer` uses  
  `queryset=CustomUser.objects.filter(role__in=[UserRole.STAFF, UserRole.ADMIN])` at import time.
- **Recommendation**: For large DBs, use a lazy queryset so it’s not evaluated at import. For example:

```python
referrer = serializers.PrimaryKeyRelatedField(
    queryset=CustomUser.objects.none(),  # placeholder
    required=False,
    allow_null=True,
)

def __init__(self, *args, **kwargs):
    super().__init__(*args, **kwargs)
    from .models import UserRole
    qs = CustomUser.objects.filter(role__in=[UserRole.STAFF, UserRole.ADMIN])
    self.fields["referrer"].queryset = qs
    self.fields["verified_by"].queryset = qs
```

(And same for `verified_by`.) This avoids importing `UserRole` at top level if you prefer, and keeps queryset evaluation at request time.

### 2.5 Email Sending – Synchronous in Admin Views

- **Current**: `SendVerificationEmailView` and `SendPasswordResetEmailView` call `send_verification_email()` / `send_password_reset_email()`, which queue Celery tasks. So email is already async.
- **Note**: Password reset link uses `FRONTEND_URL` from settings (in `email_utils`); task uses `make_password_reset_link(user)`. Ensure `FRONTEND_URL` is set correctly in production so links point to the right frontend.

### 2.6 api_exception_handler – “code” Type

- **Current**: For non-400 responses, you set  
  `data["code"] = { status.HTTP_404_NOT_FOUND: ApiCode.NOT_FOUND, ... }.get(response.status_code, ApiCode.VALIDATION_ERROR)`.  
  That yields a **string**, which is correct.
- **Recommendation**: No change needed; just ensure frontend always treats `code` as a string.

---

## 3. Scalability for Thousands of Job Seekers

### 3.1 Database

- **PostgreSQL**: Use it in production (you already support it via `DATABASE_URL`). Tune:
  - `shared_buffers`, `work_mem`, `effective_cache_size` for your instance size.
  - Connection pooling (e.g. PgBouncer) so each app worker doesn’t open too many connections.
- **Indexes**: You already have indexes on:
  - `CustomUser`: email, role, is_active, email_verified, google_id; composite (role, is_active).
  - `ApplicantProfile`: user, full_name, nik, referrer, verification_status, created_at.
  - Use these for filters: `role=APPLICANT`, `applicant_profile__verification_status`, `applicant_profile__created_at`, etc.
- **New indexes** (add if you query often):
  - `ApplicantProfile(verification_status, submitted_at)` if you often list “pending verification” and sort by submitted_at.
  - `ApplicantProfile(referrer_id, created_at)` if you often filter by referrer and time.

### 3.2 List APIs and Pagination

- **Applicant list**: Already paginated (DRF `PAGE_SIZE=20`). For 10k+ applicants:
  - Prefer **cursor-based pagination** for “infinite scroll” or very deep pages (e.g. by `(id, created_at)`).
  - Ensure filters (e.g. `verification_status`, `is_active`) use indexes; avoid full table scans.
- **Search**: `SearchFilter` on `email`, `applicant_profile__full_name`, `applicant_profile__nik`, `applicant_profile__contact_phone` can be heavy on large tables. Consider:
  - PostgreSQL `pg_trgm` + GIN index for fuzzy search on name/NIK if you use `__icontains`/`__search`.
  - Or a dedicated search backend (e.g. Elasticsearch) later if you need complex search.

### 3.3 Rate Limiting and Abuse Prevention

- **Current**: No rate limiting on auth or public endpoints.
- **Recommendation**:
  - **Login** (`CookieTokenObtainPairView`): Throttle per IP (e.g. 5–10/minute) to reduce brute force and credential stuffing.
  - **Password reset / verify email**: Throttle per IP and optionally per email (e.g. 3/hour per email) to prevent abuse and email bombing.
  - **Public endpoints** (e.g. verify-email, confirm-reset-password): Throttle per IP.
  - Use DRF throttling classes (e.g. `AnonRateThrottle`, `UserRateThrottle`) or django-ratelimit/django-axes. Example:

```python
# settings.py
REST_FRAMEWORK = {
    ...
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {
        "anon": "30/min",   # e.g. login, register
        "user": "120/min",
    },
}
# Then on auth views, use throttle_scope or custom throttle class for stricter limits.
```

### 3.4 File and Media Storage

- **Current**: Local `MEDIA_ROOT` (and optional Django storage).
- **Recommendation**: For thousands of applicants and 12 document types per applicant, use **DigitalOcean Spaces** in production (local `MEDIA_ROOT` when `DO_SPACES_*` is unset):
  - Offload files from app servers; better durability and scalability.
  - Use `django-storages[s3]` + boto3 for DigitalOcean Spaces; keep `upload_to` paths as-is (e.g. `account/documents/<id>/<code>/...`).
  - Optionally use CDN for read-heavy media URLs.

### 3.5 Celery and Background Jobs

- **Current**: OCR and image optimization on document upload; email tasks with retries.
- **Recommendation**:
  - **Broker**: Use Redis (or RabbitMQ) in production; you already have `CELERY_BROKER_URL`.
  - **Concurrency**: Scale Celery workers separately from Django (e.g. 2–4 workers per app instance); OCR and image tasks are CPU-bound, so tune worker concurrency.
  - **Rate limit** calls to Google Cloud Vision (e.g. Celery rate limit on `process_document_ocr` or use a dedicated queue with limited concurrency) to avoid hitting Vision API quotas when many applicants upload at once.
  - **Monitoring**: Track queue length and task failures (e.g. Flower, or your APM). Set alerts for backlog and repeated failures.

### 3.6 Caching (Optional but Useful)

- **DocumentType list**: Small, rarely changing. Cache in memory or Redis (e.g. 5–15 minutes) for public/list endpoints to reduce DB hits.
- **User/session**: Avoid caching full user object in Redis for every request; JWT + DB is fine. Optional: cache “document types” or other small reference data by key.
- **Applicant list**: Generally don’t cache full list responses; pagination + DB indexes are enough.

### 3.7 Security and Production Readiness

- **DEBUG**: Ensure `DEBUG=False` and `ALLOWED_HOSTS` is set in production.
- **SECRET_KEY**: From env only in production; rotate if ever exposed.
- **CORS**: Keep `CORS_ALLOWED_ORIGINS` explicit (no `*` with credentials).
- **Cookies**: `AUTH_COOKIE_SECURE=True` in production (you already set it with `not DEBUG`).
- **CSRF**: Auth views are CSRF-exempt because auth is JWT; ensure other state-changing endpoints that use session/CSRF are protected if you add them.

### 3.8 Monitoring and Observability

- **Health check**: You have `health/`; ensure it checks DB (and optionally Redis/Celery broker) so load balancers don’t send traffic to unhealthy instances.
- **Logging**: Structured logs (e.g. request id, user id, endpoint) help debug issues at scale. Avoid logging PII (NIK, full name) in plain text.
- **Metrics**: Consider request latency, error rate, and Celery queue length; integrate with your existing monitoring (e.g. Prometheus, Cloud Monitoring).

---

## 4. Summary of Recommendations (Prioritized)

| Priority | Area                | Action |
|----------|---------------------|--------|
| High     | Rate limiting       | Add throttling on login, password reset, verify-email (per IP and optionally per email). |
| High     | Production DB       | Use PostgreSQL + connection pooling; verify indexes for applicant list filters and search. |
| High     | Media at scale      | Use **DigitalOcean Spaces** for media in production (set `DO_SPACES_*` in .env). Local dev: leave unset → media in `MEDIA_ROOT`. |
| Medium   | Document types      | Add a public or applicant-readable endpoint for document types if mobile needs it. |
| Medium   | Pagination          | Consider cursor-based pagination for applicant list if you have very large lists and deep pages. |
| Medium   | Celery              | Rate-limit or queue OCR tasks so Vision API isn’t overwhelmed; monitor queue and failures. |
| Medium   | Search              | If search is slow, add pg_trgm or a dedicated search backend. |
| Low      | Serializer queryset | Lazy queryset for referrer/verified_by in ApplicantProfileSerializer. |
| Low      | Caching             | Cache document type list (and similar reference data) if you add a public endpoint. |

---

## 5. Quick Wins You Can Do Immediately

1. **Throttling**: Enable DRF `AnonRateThrottle`/`UserRateThrottle` and set rates; optionally stricter throttle class for auth views.
2. **Environment**: Document in `env.example` (or README): `FRONTEND_URL`, `ALLOWED_HOSTS`, `DATABASE_URL`, `CELERY_BROKER_URL`, and production-only vars.
3. **Indexes**: Add one composite index on `ApplicantProfile(verification_status, submitted_at)` if you list “pending verification” often.
4. **DocumentType**: Add one read-only, cached endpoint for document types for mobile (if required by product).

Your current design (roles, profiles, verification workflow, JWT+cookie, Celery, indexes) is solid for scaling to thousands of applicants. The main gaps are **rate limiting**, **media storage**, and **operational tuning** (DB, Celery, monitoring) as you grow.
