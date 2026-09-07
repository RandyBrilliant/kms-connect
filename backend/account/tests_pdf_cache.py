"""B10: repeat PDF renders should hit the cache."""

from django.core.cache import cache
from django.test import TestCase

from account.services.pdf_cache import cached_pdf_bytes


class _Profile:
    pk = 7
    updated_at = "2026-01-01"
    user = None

    class _Empty:
        def all(self):
            return []

    documents = _Empty()
    work_experiences = _Empty()


class CachedPdfBytesTests(TestCase):
    def setUp(self):
        cache.clear()

    def test_renderer_runs_once_for_the_same_fingerprint(self):
        calls = []

        def renderer(_profile):
            calls.append(1)
            return b"%PDF-cached"

        first = cached_pdf_bytes("cv", _Profile(), renderer)
        second = cached_pdf_bytes("cv", _Profile(), renderer)
        self.assertEqual(first, b"%PDF-cached")
        self.assertEqual(second, b"%PDF-cached")
        self.assertEqual(len(calls), 1)
