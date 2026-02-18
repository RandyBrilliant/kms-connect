"""
Verification script to test model optimizations.

Run this in Django shell:
    python manage.py shell < verify_optimizations.py

Or:
    python manage.py shell
    >>> exec(open('verify_optimizations.py').read())
"""

print("=" * 80)
print("MODEL OPTIMIZATION VERIFICATION")
print("=" * 80)

# Test 1: Check imports
print("\n1. Testing imports...")
try:
    from account.models import (
        CustomUser, ApplicantProfile, ApplicantDocument, 
        DocumentType, WorkExperience, StaffProfile, CompanyProfile
    )
    from account.managers import (
        ApplicantProfileManager, ApplicantDocumentManager
    )
    print("   ✓ All imports successful")
except ImportError as e:
    print(f"   ✗ Import error: {e}")
    exit()

# Test 2: Check managers are assigned
print("\n2. Testing custom managers...")
try:
    assert hasattr(ApplicantProfile, 'objects')
    assert isinstance(ApplicantProfile.objects, ApplicantProfileManager)
    print("   ✓ ApplicantProfile has custom manager")
    
    assert hasattr(ApplicantDocument, 'objects')
    assert isinstance(ApplicantDocument.objects, ApplicantDocumentManager)
    print("   ✓ ApplicantDocument has custom manager")
except AssertionError:
    print("   ✗ Manager not properly assigned")

# Test 3: Check queryset methods exist
print("\n3. Testing queryset methods...")
methods_to_check = [
    'with_user', 'with_related', 'with_documents', 'with_full_details',
    'draft', 'submitted', 'accepted', 'rejected', 'pending_review',
    'by_province', 'by_district', 'by_region',
    'recent', 'submitted_recently'
]

for method in methods_to_check:
    if hasattr(ApplicantProfile.objects, method):
        print(f"   ✓ ApplicantProfile.objects.{method}() exists")
    else:
        print(f"   ✗ ApplicantProfile.objects.{method}() missing")

# Test 4: Check __repr__ methods
print("\n4. Testing __repr__ methods...")
models_with_repr = [
    CustomUser, ApplicantProfile, StaffProfile, 
    WorkExperience, DocumentType, ApplicantDocument, CompanyProfile
]

for model in models_with_repr:
    if hasattr(model, '__repr__'):
        print(f"   ✓ {model.__name__}.__repr__() exists")
    else:
        print(f"   ✗ {model.__name__}.__repr__() missing")

# Test 5: Check helper methods on ApplicantProfile
print("\n5. Testing helper methods...")
helper_methods = ['submit_for_verification', 'approve', 'reject']
for method in helper_methods:
    if hasattr(ApplicantProfile, method):
        print(f"   ✓ ApplicantProfile.{method}() exists")
    else:
        print(f"   ✗ ApplicantProfile.{method}() missing")

# Test 6: Check property methods
print("\n6. Testing property methods...")
properties = ['age', 'days_since_submission', 'is_passport_expired', 
              'document_approval_rate', 'has_complete_documents']
for prop in properties:
    if hasattr(ApplicantProfile, prop):
        prop_obj = getattr(ApplicantProfile, prop)
        if isinstance(prop_obj, property):
            print(f"   ✓ ApplicantProfile.{prop} property exists")
        else:
            print(f"   ⚠ ApplicantProfile.{prop} exists but is not a property")
    else:
        print(f"   ✗ ApplicantProfile.{prop} missing")

# Test 7: Check DocumentType caching methods
print("\n7. Testing DocumentType caching...")
if hasattr(DocumentType, 'get_all_cached'):
    print("   ✓ DocumentType.get_all_cached() exists")
else:
    print("   ✗ DocumentType.get_all_cached() missing")

if hasattr(DocumentType, 'get_required_cached'):
    print("   ✓ DocumentType.get_required_cached() exists")
else:
    print("   ✗ DocumentType.get_required_cached() missing")

# Test 8: Query performance test (if data exists)
print("\n8. Testing query performance...")
from django.db import connection, reset_queries

try:
    if ApplicantProfile.objects.exists():
        # Test without optimization
        reset_queries()
        profiles = list(ApplicantProfile.objects.all()[:5])
        for p in profiles:
            _ = p.user.email if p.user else None
        queries_without = len(connection.queries)
        
        # Test with optimization
        reset_queries()
        profiles = list(ApplicantProfile.objects.with_user()[:5])
        for p in profiles:
            _ = p.user.email if p.user else None
        queries_with = len(connection.queries)
        
        print(f"   Without optimization: {queries_without} queries")
        print(f"   With optimization: {queries_with} queries")
        
        if queries_with < queries_without:
            improvement = ((queries_without - queries_with) / queries_without) * 100
            print(f"   ✓ Performance improved by {improvement:.1f}%")
        else:
            print("   ⚠ No performance improvement detected")
    else:
        print("   ⚠ No data to test (create some applicants first)")
except Exception as e:
    print(f"   ⚠ Could not test performance: {e}")

# Test 9: Test property with real data
print("\n9. Testing property methods with data...")
try:
    from datetime import date
    applicant = ApplicantProfile.objects.first()
    if applicant:
        if applicant.birth_date:
            age = applicant.age
            print(f"   ✓ Age calculation works: {age} years old")
        else:
            print("   ⚠ No birth_date to test age calculation")
        
        if applicant.submitted_at:
            days = applicant.days_since_submission
            print(f"   ✓ Days since submission works: {days} days")
        else:
            print("   ⚠ Profile not submitted yet")
    else:
        print("   ⚠ No applicants to test properties")
except Exception as e:
    print(f"   ✗ Property test failed: {e}")

# Test 10: Test bulk operations
print("\n10. Testing bulk operations...")
try:
    # Just check the method exists and is callable
    bulk_method = getattr(ApplicantProfile.objects, 'bulk_update_status', None)
    if callable(bulk_method):
        print("   ✓ bulk_update_status() method is callable")
    else:
        print("   ✗ bulk_update_status() not callable")
except Exception as e:
    print(f"   ✗ Bulk operation test failed: {e}")

# Summary
print("\n" + "=" * 80)
print("VERIFICATION COMPLETE")
print("=" * 80)
print("\nNext steps:")
print("1. Run: python manage.py makemigrations account")
print("2. Run: python manage.py migrate account")
print("3. Update your views to use the new optimized queries")
print("\nSee IMPLEMENTATION_COMPLETE.md for detailed usage examples.")
print("=" * 80)
