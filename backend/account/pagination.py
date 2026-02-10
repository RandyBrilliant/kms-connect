"""
Pagination classes for account API.
Page size cap to avoid heavy list responses at scale.
"""
from rest_framework.pagination import PageNumberPagination, CursorPagination


class StandardResultsSetPagination(PageNumberPagination):
    """
    PageNumberPagination with max_page_size cap.
    Use for admin/staff/company/applicant lists.
    """
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100


class ApplicantCursorPagination(CursorPagination):
    """
    Cursor-based pagination for applicant list (optional).
    Efficient for very large lists; use when listing 10k+ applicants.
    Ordering by -id (CustomUser) for stable cursor.
    """
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100
    ordering = "-id"
