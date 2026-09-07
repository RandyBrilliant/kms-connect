"""
The ACL backfill for existing document objects (B1 step 3).

Mocked rather than run against Spaces: the risk being guarded here is scope —
that the command privatises something outside account/documents/ — and that is
a property of which keys it calls put_object_acl on, not of the network.

workers=1 throughout so call counts are deterministic.
"""

from io import StringIO
from unittest.mock import MagicMock, patch

from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import TestCase

from account.management.commands.backfill_document_acls import (
    DOCUMENTS_PREFIX,
    is_public,
)

PUBLIC_ACL = {
    "Grants": [
        {"Grantee": {"Type": "CanonicalUser"}, "Permission": "FULL_CONTROL"},
        {
            "Grantee": {
                "Type": "Group",
                "URI": "http://acs.amazonaws.com/groups/global/AllUsers",
            },
            "Permission": "READ",
        },
    ]
}

PRIVATE_ACL = {
    "Grants": [
        {"Grantee": {"Type": "CanonicalUser"}, "Permission": "FULL_CONTROL"},
    ]
}


class IsPublicTests(TestCase):
    def test_detects_anonymous_read(self):
        self.assertTrue(is_public(PUBLIC_ACL))

    def test_owner_only_is_private(self):
        self.assertFalse(is_public(PRIVATE_ACL))

    def test_empty_acl_is_private(self):
        self.assertFalse(is_public({}))


class BackfillCommandTests(TestCase):
    def setUp(self):
        self.client = MagicMock()
        self.client.get_object_acl.return_value = PUBLIC_ACL

        storage = MagicMock()
        storage.bucket_name = "kms-data"
        self.storage_patch = patch(
            "account.management.commands.backfill_document_acls.default_storage",
            storage,
        )
        self.storage_patch.start()
        self.addCleanup(self.storage_patch.stop)

        # The command builds its own client for adaptive retries.
        self.client_patch = patch(
            "account.management.commands.backfill_document_acls.build_client",
            return_value=self.client,
        )
        self.client_patch.start()
        self.addCleanup(self.client_patch.stop)

    def _paginate(self, *pages):
        """Wire the paginator to yield the given lists of keys."""
        self.client.get_paginator.return_value.paginate.return_value = [
            {"Contents": [{"Key": key} for key in page]} for page in pages
        ]

    def _run(self, **kwargs):
        out = StringIO()
        call_command(
            "backfill_document_acls", workers=1, stdout=out, stderr=out, **kwargs
        )
        return out.getvalue()

    def _privatised_keys(self):
        return [
            call.kwargs["Key"]
            for call in self.client.put_object_acl.call_args_list
        ]

    # -- scope -------------------------------------------------------------

    def test_only_touches_the_documents_prefix(self):
        """The paginator is asked for one prefix and one prefix only."""
        self._paginate([f"{DOCUMENTS_PREFIX}1/ktp/a.jpg"])
        self._run()
        paginate = self.client.get_paginator.return_value.paginate
        self.assertEqual(paginate.call_args.kwargs["Prefix"], DOCUMENTS_PREFIX)
        self.assertEqual(paginate.call_args.kwargs["Bucket"], "kms-data")

    def test_refuses_keys_outside_the_prefix(self):
        """
        Guards against a mis-scoped listing. main/news/ holds public website
        images and the bucket is shared with an unrelated project.
        """
        self._paginate(
            [
                f"{DOCUMENTS_PREFIX}1/ktp/a.jpg",
                "main/news/hero.jpg",
                "kta/something.pdf",
            ]
        )
        output = self._run()

        self.assertEqual(self._privatised_keys(), [f"{DOCUMENTS_PREFIX}1/ktp/a.jpg"])
        self.assertIn("outside prefix, refused", output)

    def test_writes_private_acl(self):
        self._paginate([f"{DOCUMENTS_PREFIX}1/ktp/a.jpg"])
        self._run()
        self.assertEqual(self.client.put_object_acl.call_args.kwargs["ACL"], "private")

    # -- idempotence -------------------------------------------------------

    def test_skips_objects_that_are_already_private(self):
        self.client.get_object_acl.return_value = PRIVATE_ACL
        self._paginate([f"{DOCUMENTS_PREFIX}1/ktp/a.jpg"])
        output = self._run()

        self.client.put_object_acl.assert_not_called()
        self.assertIn("already_private=1", output)

    # -- dry run and limit -------------------------------------------------

    def test_dry_run_writes_nothing(self):
        self._paginate([f"{DOCUMENTS_PREFIX}1/ktp/a.jpg"])
        output = self._run(dry_run=True)

        self.client.put_object_acl.assert_not_called()
        self.assertIn("would_make_private=1", output)

    def test_limit_is_exact(self):
        """
        A canary's whole point is a small blast radius, so --limit 2 must flip
        two objects, not round up to the end of the page.
        """
        self._paginate(
            [f"{DOCUMENTS_PREFIX}{i}/ktp/a.jpg" for i in range(5)],
            [f"{DOCUMENTS_PREFIX}99/ktp/b.jpg"],
        )
        self._run(limit=2)

        self.assertEqual(len(self._privatised_keys()), 2)
        self.assertNotIn(f"{DOCUMENTS_PREFIX}99/ktp/b.jpg", self._privatised_keys())

    def test_already_private_objects_do_not_consume_the_limit(self):
        """--limit counts objects actually changed, so a canary flips N."""
        self.client.get_object_acl.side_effect = [
            PRIVATE_ACL,
            PRIVATE_ACL,
            PUBLIC_ACL,
            PUBLIC_ACL,
        ]
        self._paginate([f"{DOCUMENTS_PREFIX}{i}/ktp/a.jpg" for i in range(4)])
        self._run(limit=2)

        self.assertEqual(len(self._privatised_keys()), 2)

    # -- verification ------------------------------------------------------

    def test_verify_reports_an_object_that_stayed_public(self):
        """If Spaces accepts the write but the ACL does not change, say so."""
        self._paginate([f"{DOCUMENTS_PREFIX}1/ktp/a.jpg"])
        output = self._run(verify=True)

        self.assertIn("STILL PUBLIC", output)
        self.assertIn("still_public=1", output)

    def test_verify_passes_when_the_acl_changed(self):
        self.client.get_object_acl.side_effect = [PUBLIC_ACL, PRIVATE_ACL]
        self._paginate([f"{DOCUMENTS_PREFIX}1/ktp/a.jpg"])
        output = self._run(verify=True)

        self.assertIn("made_private=1", output)
        self.assertIn("still_public=0", output)

    # -- guards ------------------------------------------------------------

    def test_refuses_to_run_without_object_storage(self):
        storage = MagicMock()
        storage.bucket_name = None
        with patch(
            "account.management.commands.backfill_document_acls.default_storage",
            storage,
        ):
            with self.assertRaises(CommandError):
                self._run()
