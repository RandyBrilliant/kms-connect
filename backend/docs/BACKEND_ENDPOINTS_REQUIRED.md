# Backend Endpoints Required for Frontend Features

This document lists the backend API endpoints that need to be implemented to support the new frontend verification workflow and bulk actions.

## Overview

The frontend now includes:
- **Bulk selection** of applicants in the table
- **Verification modal** for approving/rejecting applicants with notes
- **Bulk approve/reject** actions for processing multiple applicants at once

These features require new backend endpoints to function properly.

---

## 1. Single Applicant Approve

### Endpoint
```
POST /api/applicant-profiles/{id}/approve/
```

### Purpose
Approve a single applicant's profile for verification.

### Request Body
```json
{
  "notes": "Applicant meets all requirements"
}
```

### Expected Response
```json
{
  "success": true,
  "message": "Applicant approved successfully"
}
```

### Implementation Notes
- Use the `approve(verified_by, notes)` method from `ApplicantProfile` model (already implemented)
- Update `verification_status` to `ACCEPTED`
- Set `verified_by` to current admin user
- Set `verification_notes` to provided notes
- Update `verified_at` timestamp
- Requires admin/staff permissions

### Example Implementation
```python
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework import status

@action(detail=True, methods=['post'], url_path='approve')
def approve(self, request, pk=None):
    """Approve applicant profile"""
    profile = self.get_object()
    notes = request.data.get('notes', '')
    
    # Use the helper method from the model
    profile.approve(verified_by=request.user, notes=notes)
    
    return Response({
        'success': True,
        'message': 'Applicant approved successfully'
    }, status=status.HTTP_200_OK)
```

---

## 2. Single Applicant Reject

### Endpoint
```
POST /api/applicant-profiles/{id}/reject/
```

### Purpose
Reject a single applicant's profile for verification.

### Request Body
```json
{
  "notes": "Missing required documents"
}
```

**Note:** Notes are required for rejection (frontend validates this).

### Expected Response
```json
{
  "success": true,
  "message": "Applicant rejected successfully"
}
```

### Implementation Notes
- Use the `reject(verified_by, notes)` method from `ApplicantProfile` model (already implemented)
- Update `verification_status` to `REJECTED`
- Set `verified_by` to current admin user
- Set `verification_notes` to provided notes (required)
- Update `verified_at` timestamp
- Requires admin/staff permissions

### Example Implementation
```python
@action(detail=True, methods=['post'], url_path='reject')
def reject(self, request, pk=None):
    """Reject applicant profile"""
    profile = self.get_object()
    notes = request.data.get('notes', '')
    
    if not notes:
        return Response({
            'success': False,
            'message': 'Notes are required for rejection'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    # Use the helper method from the model
    profile.reject(verified_by=request.user, notes=notes)
    
    return Response({
        'success': True,
        'message': 'Applicant rejected successfully'
    }, status=status.HTTP_200_OK)
```

---

## 3. Bulk Approve Applicants

### Endpoint
```
POST /api/applicant-profiles/bulk-approve/
```

### Purpose
Approve multiple applicants in a single request.

### Request Body
```json
{
  "profile_ids": [1, 2, 3, 4, 5],
  "notes": "Batch approval for qualified applicants"
}
```

### Expected Response
```json
{
  "success": true,
  "message": "5 applicants approved successfully",
  "updated": 5
}
```

### Implementation Notes
- Use the `bulk_update_status()` method from `ApplicantProfileManager` (already implemented)
- Filters profiles by `verification_status=SUBMITTED` before updating
- Atomic operation (all or nothing)
- Requires admin/staff permissions
- Should log the bulk action for audit trail

### Example Implementation
```python
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework import status
from django.db import transaction

@action(detail=False, methods=['post'], url_path='bulk-approve')
def bulk_approve(self, request):
    """Bulk approve applicants"""
    profile_ids = request.data.get('profile_ids', [])
    notes = request.data.get('notes', '')
    
    if not profile_ids:
        return Response({
            'success': False,
            'message': 'profile_ids is required'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    # Use the optimized bulk update from the manager
    from account.models import ApplicantProfile
    updated = ApplicantProfile.objects.bulk_update_status(
        profile_ids=profile_ids,
        status='ACCEPTED',
        verified_by=request.user,
        notes=notes
    )
    
    return Response({
        'success': True,
        'message': f'{updated} applicants approved successfully',
        'updated': updated
    }, status=status.HTTP_200_OK)
```

---

## 4. Bulk Reject Applicants

### Endpoint
```
POST /api/applicant-profiles/bulk-reject/
```

### Purpose
Reject multiple applicants in a single request.

### Request Body
```json
{
  "profile_ids": [6, 7, 8],
  "notes": "Incomplete documentation"
}
```

**Note:** Notes are required for rejection (frontend validates this).

### Expected Response
```json
{
  "success": true,
  "message": "3 applicants rejected successfully",
  "updated": 3
}
```

### Implementation Notes
- Use the `bulk_update_status()` method from `ApplicantProfileManager` (already implemented)
- Filters profiles by `verification_status=SUBMITTED` before updating
- Atomic operation (all or nothing)
- Requires notes parameter (validate in view)
- Requires admin/staff permissions
- Should log the bulk action for audit trail

### Example Implementation
```python
@action(detail=False, methods=['post'], url_path='bulk-reject')
def bulk_reject(self, request):
    """Bulk reject applicants"""
    profile_ids = request.data.get('profile_ids', [])
    notes = request.data.get('notes', '')
    
    if not profile_ids:
        return Response({
            'success': False,
            'message': 'profile_ids is required'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    if not notes:
        return Response({
            'success': False,
            'message': 'Notes are required for rejection'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    # Use the optimized bulk update from the manager
    from account.models import ApplicantProfile
    updated = ApplicantProfile.objects.bulk_update_status(
        profile_ids=profile_ids,
        status='REJECTED',
        verified_by=request.user,
        notes=notes
    )
    
    return Response({
        'success': True,
        'message': f'{updated} applicants rejected successfully',
        'updated': updated
    }, status=status.HTTP_200_OK)
```

---

## 5. URL Configuration

Add these endpoints to your URL configuration:

### Option A: Add to ApplicantProfileViewSet

If you have a ViewSet for `ApplicantProfile`, add the actions there:

```python
# backend/account/views.py

class ApplicantProfileViewSet(viewsets.ModelViewSet):
    # ... existing code ...
    
    @action(detail=True, methods=['post'], url_path='approve')
    def approve(self, request, pk=None):
        # Implementation from above
        pass
    
    @action(detail=True, methods=['post'], url_path='reject')
    def reject(self, request, pk=None):
        # Implementation from above
        pass
    
    @action(detail=False, methods=['post'], url_path='bulk-approve')
    def bulk_approve(self, request):
        # Implementation from above
        pass
    
    @action(detail=False, methods=['post'], url_path='bulk-reject')
    def bulk_reject(self, request):
        # Implementation from above
        pass
```

### Option B: Create Standalone Views

If you prefer standalone views:

```python
# backend/account/urls.py

from django.urls import path
from .views import (
    ApproveApplicantView,
    RejectApplicantView,
    BulkApproveApplicantsView,
    BulkRejectApplicantsView,
)

urlpatterns = [
    # ... existing patterns ...
    path('applicant-profiles/<int:pk>/approve/', ApproveApplicantView.as_view()),
    path('applicant-profiles/<int:pk>/reject/', RejectApplicantView.as_view()),
    path('applicant-profiles/bulk-approve/', BulkApproveApplicantsView.as_view()),
    path('applicant-profiles/bulk-reject/', BulkRejectApplicantsView.as_view()),
]
```

---

## Testing the Endpoints

### Using curl

**Approve Single:**
```bash
curl -X POST http://localhost:8000/api/applicant-profiles/1/approve/ \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"notes": "Approved"}'
```

**Bulk Approve:**
```bash
curl -X POST http://localhost:8000/api/applicant-profiles/bulk-approve/ \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"profile_ids": [1,2,3], "notes": "Batch approval"}'
```

### Frontend Integration

Once the backend endpoints are implemented, the frontend will automatically work with them. The frontend code already includes:
- API functions in `frontend/src/api/applicants.ts`
- TanStack Query mutation hooks in `frontend/src/hooks/use-applicants-query.ts`
- UI components for bulk selection and verification modal

---

## Performance Considerations

1. **Bulk Operations**: Use `bulk_update_status()` method which:
   - Filters by verification_status=SUBMITTED first
   - Uses `select_for_update()` for row-level locking
   - Updates in a single query with `.update()`
   - ~100x faster than individual updates

2. **Permissions**: Cache permission checks when possible

3. **Audit Logging**: Consider async logging for bulk operations to avoid blocking the response

4. **Transaction Safety**: Wrap bulk operations in `transaction.atomic()`

---

## Related Backend Code

These backend components are already implemented and ready to use:

1. **Model Methods** (`backend/account/models.py`):
   - `ApplicantProfile.approve(verified_by, notes)`
   - `ApplicantProfile.reject(verified_by, notes)`

2. **Manager Methods** (`backend/account/custom_managers.py`):
   - `ApplicantProfileManager.bulk_update_status(profile_ids, status, verified_by, notes)`

3. **Permissions** (should already exist):
   - `IsBackofficeAdmin` or similar

---

## Summary

| Endpoint | Method | Purpose | Status |
|----------|--------|---------|---------|
| `/api/applicant-profiles/{id}/approve/` | POST | Approve single applicant | ❌ Need to implement |
| `/api/applicant-profiles/{id}/reject/` | POST | Reject single applicant | ❌ Need to implement |
| `/api/applicant-profiles/bulk-approve/` | POST | Approve multiple applicants | ❌ Need to implement |
| `/api/applicant-profiles/bulk-reject/` | POST | Reject multiple applicants | ❌ Need to implement |

**Frontend Status**: ✅ Fully implemented and ready
**Backend Status**: ❌ Endpoints need to be added

Once these endpoints are implemented, the verification workflow will be fully functional!
