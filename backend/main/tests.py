"""B9 prefetch and B14 company queryset guards."""

from django.db.models import Prefetch
from django.test import RequestFactory, TestCase

from account.models import ApplicantDocument, CustomUser, UserRole
from main.views import CompanyJobListingsViewSet, JobApplicationViewSet


class JobApplicationPrefetchTests(TestCase):
    def test_admin_list_prefetches_status_history_and_documents(self):
        lookups = JobApplicationViewSet().get_queryset()._prefetch_related_lookups
        self.assertIn("status_history__changed_by", lookups)
        docs = [
            item
            for item in lookups
            if isinstance(item, Prefetch)
            and item.prefetch_through == "applicant__documents"
        ]
        self.assertEqual(len(docs), 1)
        self.assertEqual(docs[0].to_attr, "_prefetched_all_docs")


class CompanyQuerysetGuardTests(TestCase):
    def test_company_user_without_profile_gets_empty_jobs(self):
        user = CustomUser.objects.create_user(
            email="noprofile-co@example.com",
            password="testpass123",
            role=UserRole.COMPANY,
        )
        request = RequestFactory().get("/")
        request.user = user
        view = CompanyJobListingsViewSet()
        view.request = request
        view.format_kwarg = None
        self.assertEqual(list(view.get_queryset()), [])


class DocumentFileMaxLengthTests(TestCase):
    def test_file_field_allows_255_characters(self):
        self.assertEqual(ApplicantDocument._meta.get_field("file").max_length, 255)
