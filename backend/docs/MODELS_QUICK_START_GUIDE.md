# Models Optimization - Quick Start Implementation Guide

This guide shows you EXACTLY what to change in your models.py to get immediate performance improvements for handling thousands of applicants.

## Step 1: Add Custom Managers (30 minutes) - BIGGEST IMPACT

Create a new file: `backend/account/managers.py` (separate from existing managers.py if you have CustomUserManager there)

```python
"""
Custom managers and querysets for optimized database access.
"""
from django.db import models
from django.db.models import Q, Prefetch
from django.utils import timezone
from datetime import timedelta


class ApplicantProfileQuerySet(models.QuerySet):
    """Optimized queryset for ApplicantProfile with common query patterns."""
    
    def with_user(self):
        """Select user to avoid N+1 queries."""
        return self.select_related('user')
    
    def with_related(self):
        """Optimize all common foreign key lookups."""
        return self.select_related(
            'user',
            'referrer',
            'verified_by',
            'village__sub_district__district__province',
            'family_village__sub_district__district__province'
        )
    
    def with_documents(self):
        """Prefetch all documents with their types."""
        from .models import ApplicantDocument
        return self.prefetch_related(
            Prefetch(
                'documents',
                queryset=ApplicantDocument.objects.select_related(
                    'document_type', 'reviewed_by'
                ).order_by('document_type__sort_order')
            )
        )
    
    def with_work_experiences(self):
        """Prefetch work experiences."""
        return self.prefetch_related('work_experiences')
    
    def with_full_details(self):
        """Load everything for detail views (use sparingly)."""
        return self.with_related().with_documents().with_work_experiences()
    
    # Status filters
    def draft(self):
        """Applicants in draft status."""
        from .models import ApplicantVerificationStatus
        return self.filter(verification_status=ApplicantVerificationStatus.DRAFT)
    
    def submitted(self):
        """Applicants submitted and waiting for review."""
        from .models import ApplicantVerificationStatus
        return self.filter(verification_status=ApplicantVerificationStatus.SUBMITTED)
    
    def accepted(self):
        """Accepted/verified applicants."""
        from .models import ApplicantVerificationStatus
        return self.filter(verification_status=ApplicantVerificationStatus.ACCEPTED)
    
    def rejected(self):
        """Rejected applicants."""
        from .models import ApplicantVerificationStatus
        return self.filter(verification_status=ApplicantVerificationStatus.REJECTED)
    
    def pending_review(self):
        """Alias for submitted() - clearer for admin dashboards."""
        return self.submitted()
    
    # Regional filters
    def by_province(self, province):
        """Filter by province."""
        return self.filter(province=province)
    
    def by_district(self, district):
        """Filter by district."""
        return self.filter(district=district)
    
    def by_region(self, province=None, district=None):
        """Filter by province and/or district."""
        qs = self
        if province:
            qs = qs.filter(province=province)
        if district:
            qs = qs.filter(district=district)
        return qs
    
    # Time-based filters
    def recent(self, days=30):
        """Applicants created in last N days."""
        cutoff = timezone.now() - timedelta(days=days)
        return self.filter(created_at__gte=cutoff)
    
    def submitted_recently(self, days=7):
        """Applicants submitted in last N days."""
        cutoff = timezone.now() - timedelta(days=days)
        return self.filter(
            submitted_at__gte=cutoff,
            submitted_at__isnull=False
        )
    
    # Referrer filters
    def by_referrer(self, referrer):
        """Filter by specific referrer (Staff/Admin)."""
        return self.filter(referrer=referrer)
    
    def referred_by_staff(self):
        """Applicants referred by staff (not admin)."""
        from .models import UserRole
        return self.filter(referrer__role=UserRole.STAFF)


class ApplicantProfileManager(models.Manager):
    """Custom manager for ApplicantProfile with optimized queries."""
    
    def get_queryset(self):
        return ApplicantProfileQuerySet(self.model, using=self._db)
    
    # Forward queryset methods
    def with_user(self):
        return self.get_queryset().with_user()
    
    def with_related(self):
        return self.get_queryset().with_related()
    
    def with_documents(self):
        return self.get_queryset().with_documents()
    
    def with_work_experiences(self):
        return self.get_queryset().with_work_experiences()
    
    def with_full_details(self):
        return self.get_queryset().with_full_details()
    
    def draft(self):
        return self.get_queryset().draft()
    
    def submitted(self):
        return self.get_queryset().submitted()
    
    def accepted(self):
        return self.get_queryset().accepted()
    
    def rejected(self):
        return self.get_queryset().rejected()
    
    def pending_review(self):
        return self.get_queryset().pending_review()
    
    def by_province(self, province):
        return self.get_queryset().by_province(province)
    
    def by_district(self, district):
        return self.get_queryset().by_district(district)
    
    def by_region(self, province=None, district=None):
        return self.get_queryset().by_region(province, district)
    
    def recent(self, days=30):
        return self.get_queryset().recent(days)
    
    def submitted_recently(self, days=7):
        return self.get_queryset().submitted_recently(days)
    
    def by_referrer(self, referrer):
        return self.get_queryset().by_referrer(referrer)
    
    def referred_by_staff(self):
        return self.get_queryset().referred_by_staff()
    
    # Bulk operations
    def bulk_update_status(self, profile_ids, status, verified_by):
        """
        Bulk update verification status for multiple applicants.
        
        Usage:
            ApplicantProfile.objects.bulk_update_status(
                profile_ids=[1, 2, 3],
                status=ApplicantVerificationStatus.ACCEPTED,
                verified_by=admin_user
            )
        """
        return self.filter(id__in=profile_ids).update(
            verification_status=status,
            verified_by=verified_by,
            verified_at=timezone.now()
        )


class ApplicantDocumentQuerySet(models.QuerySet):
    """Optimized queryset for ApplicantDocument."""
    
    def with_related(self):
        """Select related document type and review info."""
        return self.select_related(
            'applicant_profile__user',
            'document_type',
            'reviewed_by'
        )
    
    def pending(self):
        """Documents pending review."""
        from .models import DocumentReviewStatus
        return self.filter(review_status=DocumentReviewStatus.PENDING)
    
    def approved(self):
        """Approved documents."""
        from .models import DocumentReviewStatus
        return self.filter(review_status=DocumentReviewStatus.APPROVED)
    
    def rejected(self):
        """Rejected documents."""
        from .models import DocumentReviewStatus
        return self.filter(review_status=DocumentReviewStatus.REJECTED)
    
    def by_type(self, document_type_code):
        """Filter by document type code."""
        return self.filter(document_type__code=document_type_code)
    
    def ktp_documents(self):
        """All KTP documents."""
        return self.by_type('ktp')


class ApplicantDocumentManager(models.Manager):
    """Custom manager for ApplicantDocument."""
    
    def get_queryset(self):
        return ApplicantDocumentQuerySet(self.model, using=self._db)
    
    def with_related(self):
        return self.get_queryset().with_related()
    
    def pending(self):
        return self.get_queryset().pending()
    
    def approved(self):
        return self.get_queryset().approved()
    
    def rejected(self):
        return self.get_queryset().rejected()
    
    def by_type(self, document_type_code):
        return self.get_queryset().by_type(document_type_code)
    
    def ktp_documents(self):
        return self.get_queryset().ktp_documents()
```

## Step 2: Update models.py to use new managers

In your `account/models.py`, add these imports at the top:

```python
from .managers import (
    CustomUserManager,  # Your existing manager
    ApplicantProfileManager,
    ApplicantDocumentManager,
)
```

Then in the ApplicantProfile model, add the custom manager:

```python
class ApplicantProfile(models.Model):
    # ... all your existing fields ...
    
    # Replace default manager with custom one
    objects = ApplicantProfileManager()
    
    # ... rest of the model ...
```

And in ApplicantDocument model:

```python
class ApplicantDocument(models.Model):
    # ... all your existing fields ...
    
    objects = ApplicantDocumentManager()
    
    # ... rest of the model ...
```

## Step 3: Add improved indexes (5 minutes)

In `account/models.py`, update the Meta class of ApplicantProfile:

```python
class ApplicantProfile(models.Model):
    # ... fields ...
    
    class Meta:
        verbose_name = _("profil pelamar")
        verbose_name_plural = _("daftar profil pelamar")
        indexes = [
            models.Index(fields=["user"]),
            models.Index(fields=["full_name"]),
            models.Index(fields=["referrer"]),
            models.Index(fields=["verification_status"]),
            models.Index(fields=["created_at"]),
            models.Index(fields=["verification_status", "submitted_at"]),
            # NEW indexes below
            models.Index(fields=["verification_status", "created_at"]),
            models.Index(fields=["referrer", "verification_status"]),
            models.Index(fields=["province", "verification_status"]),
            models.Index(fields=["district", "verification_status"]),
        ]
```

Update ApplicantDocument Meta class:

```python
class ApplicantDocument(models.Model):
    # ... fields ...
    
    class Meta:
        verbose_name = _("dokumen pelamar")
        verbose_name_plural = _("daftar dokumen pelamar")
        constraints = [
            models.UniqueConstraint(
                fields=["applicant_profile", "document_type"],
                name="account_applicantdocument_unique_profile_doctype",
            ),
        ]
        indexes = [
            models.Index(fields=["applicant_profile", "document_type"]),
            models.Index(fields=["uploaded_at"]),
            models.Index(fields=["review_status"]),
            models.Index(fields=["applicant_profile", "review_status"]),
            # NEW indexes below
            models.Index(fields=["review_status", "uploaded_at"]),
            models.Index(fields=["document_type", "review_status"]),
        ]
```

After adding indexes, run migrations:

```bash
python manage.py makemigrations
python manage.py migrate
```

## Step 4: Add __repr__ methods (5 minutes)

Add these methods to each model:

```python
class CustomUser(AbstractUser):
    # ... existing code ...
    
    def __repr__(self) -> str:
        return f"<CustomUser: {self.email} ({self.role})>"


class ApplicantProfile(models.Model):
    # ... existing code ...
    
    def __repr__(self) -> str:
        return f"<ApplicantProfile: {self.full_name} (NIK: {self.nik}, Status: {self.verification_status})>"


class WorkExperience(models.Model):
    # ... existing code ...
    
    def __repr__(self) -> str:
        return f"<WorkExperience: {self.company_name} - {self.position} ({self.applicant_profile.full_name})>"


class ApplicantDocument(models.Model):
    # ... existing code ...
    
    def __repr__(self) -> str:
        doc_type = self.document_type.code if self.document_type_id else 'unknown'
        return f"<ApplicantDocument: {doc_type} for {self.applicant_profile.nik}>"


class StaffProfile(models.Model):
    # ... existing code ...
    
    def __repr__(self) -> str:
        return f"<StaffProfile: {self.full_name} ({self.user.email})>"


class CompanyProfile(models.Model):
    # ... existing code ...
    
    def __repr__(self) -> str:
        return f"<CompanyProfile: {self.company_name} ({self.user.email})>"
```

## Step 5: Add helper methods to ApplicantProfile (10 minutes)

```python
class ApplicantProfile(models.Model):
    # ... existing fields and methods ...
    
    def submit_for_verification(self):
        """
        Submit profile for admin verification.
        Changes status from DRAFT to SUBMITTED.
        
        Raises:
            ValidationError: If not in DRAFT status or missing required data
        """
        from django.core.exceptions import ValidationError
        
        if self.verification_status != ApplicantVerificationStatus.DRAFT:
            raise ValidationError(_("Hanya profil dengan status Draf yang dapat dikirim."))
        
        # Check required fields
        required_fields = {
            'full_name': self.full_name,
            'nik': self.nik,
            'birth_date': self.birth_date,
            'address': self.address,
        }
        missing = [name for name, value in required_fields.items() if not value]
        if missing:
            raise ValidationError(
                _("Field wajib belum diisi: %(fields)s") % {
                    'fields': ', '.join(missing)
                }
            )
        
        self.verification_status = ApplicantVerificationStatus.SUBMITTED
        self.submitted_at = timezone.now()
        self.save(update_fields=['verification_status', 'submitted_at'])
    
    def approve(self, verified_by, notes=''):
        """
        Approve this applicant profile.
        
        Args:
            verified_by: CustomUser (admin/staff) who approved
            notes: Optional approval notes
        """
        self.verification_status = ApplicantVerificationStatus.ACCEPTED
        self.verified_by = verified_by
        self.verified_at = timezone.now()
        self.verification_notes = notes
        self.save(update_fields=[
            'verification_status', 'verified_by',
            'verified_at', 'verification_notes'
        ])
    
    def reject(self, verified_by, notes):
        """
        Reject this applicant profile.
        
        Args:
            verified_by: CustomUser (admin/staff) who rejected
            notes: Required rejection reason
            
        Raises:
            ValidationError: If notes is empty
        """
        from django.core.exceptions import ValidationError
        
        if not notes:
            raise ValidationError(_("Catatan penolakan harus diisi."))
        
        self.verification_status = ApplicantVerificationStatus.REJECTED
        self.verified_by = verified_by
        self.verified_at = timezone.now()
        self.verification_notes = notes
        self.save(update_fields=[
            'verification_status', 'verified_by',
            'verified_at', 'verification_notes'
        ])
    
    @property
    def age(self):
        """Calculate age from birth_date."""
        if not self.birth_date:
            return None
        from datetime import date
        today = date.today()
        return today.year - self.birth_date.year - (
            (today.month, today.day) < (self.birth_date.month, self.birth_date.day)
        )
    
    @property
    def days_since_submission(self):
        """Days since profile was submitted for review."""
        if not self.submitted_at:
            return None
        return (timezone.now() - self.submitted_at).days
```

## Step 6: Update your views to use optimized queries

### Before (SLOW - causes N+1 queries):

```python
# In views.py or serializers.py
def list_applicants(request):
    applicants = ApplicantProfile.objects.all()  # BAD
    # Each iteration causes additional queries
    for applicant in applicants:
        print(applicant.user.email)  # Query
        print(applicant.referrer.email)  # Query
```

### After (FAST - uses optimized queries):

```python
def list_applicants(request):
    # Use optimized manager methods
    applicants = ApplicantProfile.objects.with_user()
    # Or for more detail:
    # applicants = ApplicantProfile.objects.with_related()
    
    for applicant in applicants:
        print(applicant.user.email)  # No extra query
        print(applicant.referrer.email if applicant.referrer else "Admin")  # No extra query
```

### Examples for common views:

```python
# Applicant detail page
def applicant_detail(request, pk):
    applicant = ApplicantProfile.objects.with_full_details().get(pk=pk)
    # Has user, referrer, verified_by, documents, work_experiences all loaded
    return render(request, 'applicant_detail.html', {'applicant': applicant})


# Admin dashboard - pending reviews
def pending_applicants(request):
    pending = ApplicantProfile.objects.with_user().pending_review()
    return render(request, 'pending_list.html', {'applicants': pending})


# Applicants by region
def regional_applicants(request, province):
    applicants = ApplicantProfile.objects.with_user().by_province(province).accepted()
    return render(request, 'regional_list.html', {'applicants': applicants})


# Recent submissions
def recent_submissions(request):
    recent = ApplicantProfile.objects.with_user().submitted_recently(days=7)
    return render(request, 'recent_list.html', {'applicants': recent})
```

## Step 7: Add DocumentType caching (BONUS - 5 minutes)

In `account/models.py`, update DocumentType model:

```python
from django.core.cache import cache

class DocumentType(models.Model):
    # ... existing fields ...
    
    @classmethod
    def get_all_cached(cls, timeout=3600):
        """Get all document types from cache (1 hour default)."""
        cache_key = 'document_types_all'
        doc_types = cache.get(cache_key)
        if doc_types is None:
            doc_types = list(cls.objects.all())
            cache.set(cache_key, doc_types, timeout)
        return doc_types
    
    @classmethod
    def get_required_cached(cls, timeout=3600):
        """Get only required document types from cache."""
        cache_key = 'document_types_required'
        doc_types = cache.get(cache_key)
        if doc_types is None:
            doc_types = list(cls.objects.filter(is_required=True))
            cache.set(cache_key, doc_types, timeout)
        return doc_types
    
    def save(self, *args, **kwargs):
        """Invalidate cache when document types change."""
        super().save(*args, **kwargs)
        cache.delete('document_types_all')
        cache.delete('document_types_required')
    
    def delete(self, *args, **kwargs):
        """Invalidate cache when document types are deleted."""
        super().delete(*args, **kwargs)
        cache.delete('document_types_all')
        cache.delete('document_types_required')
```

Use in views:

```python
# Instead of:
doc_types = DocumentType.objects.all()

# Use:
doc_types = DocumentType.get_all_cached()
```

## Testing Your Changes

Run these in Django shell to verify:

```python
from django.db import connection, reset_queries
from account.models import ApplicantProfile

# Test 1: Query count before optimization
reset_queries()
applicants = list(ApplicantProfile.objects.all()[:10])
for a in applicants:
    _ = a.user.email
    _ = a.referrer
print(f"Queries: {len(connection.queries)}")  # Should be 20+

# Test 2: Query count after optimization
reset_queries()
applicants = list(ApplicantProfile.objects.with_related()[:10])
for a in applicants:
    _ = a.user.email
    _ = a.referrer
print(f"Queries: {len(connection.queries)}")  # Should be 2-3

# Test 3: Helper methods work
applicant = ApplicantProfile.objects.first()
print(applicant.age)
print(applicant.days_since_submission)

# Test 4: Filtering methods work
pending = ApplicantProfile.objects.pending_review()
print(f"Pending: {pending.count()}")

accepted = ApplicantProfile.objects.accepted()
print(f"Accepted: {accepted.count()}")
```

## Expected Results

After implementing these changes:

✅ **Query Reduction**: 100 applicants with relations: 200+ queries → 3-5 queries
✅ **Dashboard Speed**: Admin dashboard loads 5-10x faster
✅ **Developer Experience**: Cleaner, more readable view code
✅ **Scalability**: Handles 10,000+ applicants without slowdown

## Next Steps

After these quick wins, consider implementing:

1. **Database constraints** for data integrity (see main analysis doc)
2. **Full-text search** for name/NIK searching (PostgreSQL GIN indexes)
3. **Bulk operations** for admin batch actions
4. **Soft delete** for audit trail
5. **Field-level encryption** for sensitive PII

## Need Help?

If you encounter issues:

1. Check migrations ran successfully: `python manage.py showmigrations account`
2. Verify imports: Make sure managers.py is imported correctly
3. Test in Django shell before deploying
4. Check Django debug toolbar to see query counts

## Performance Monitoring

Add this to your views to monitor query performance:

```python
from django.db import connection

def your_view(request):
    # ... your code ...
    if settings.DEBUG:
        print(f"Queries executed: {len(connection.queries)}")
    # ...
```

Or install django-debug-toolbar:

```bash
pip install django-debug-toolbar
```

This will show you exactly how many queries each page generates.
