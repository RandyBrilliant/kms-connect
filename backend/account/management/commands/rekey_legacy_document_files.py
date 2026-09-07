"""
Re-key legacy ApplicantDocument files so their object keys are not guessable.

Legacy uploads (before applicant_document_upload_to added a random prefix) are
stored as:
    account/documents/<profile_id>/<code>/<name-slug>-<last4nik>-<code>.<ext>
Every part of that is derivable from an applicant's name, so the object URL can
be guessed. This command rewrites each such object to an opaque key:
    account/documents/<profile_id>/<code>/<32-hex>.<ext>

The readable portion is dropped rather than kept, because nothing consumes it:
the ZIP export and every download response build their filenames from the
database (applicant name + document_type.code), never from the object key. This
also keeps the name and partial NIK out of CDN logs, browser history, and
Referer headers, and it keeps the key inside FileField's max_length.

The object ACL is preserved as-is by default (--acl public-read), so document
previews keep working. This command removes *guessability* only; making objects
private requires the signed-URL work and must not be done here.

Usage:
  python manage.py rekey_legacy_document_files --dry-run
  python manage.py rekey_legacy_document_files --limit 20
  python manage.py rekey_legacy_document_files
  python manage.py rekey_legacy_document_files --delete-orphans --dry-run
"""

import os
import re
import uuid

from botocore.exceptions import ClientError
from django.core.files.storage import default_storage
from django.core.management.base import BaseCommand, CommandError

from account.models import ApplicantDocument

DOCUMENTS_PREFIX = "account/documents/"

# Keys produced by the current applicant_document_upload_to().
RANDOM_PREFIX_RE = re.compile(r"^[0-9a-f]{16}-")
# Keys produced by this command. Recognised so re-runs are idempotent.
OPAQUE_NAME_RE = re.compile(r"^[0-9a-f]{32}(\.[A-Za-z0-9]+)?$")


def needs_rekey(name: str) -> bool:
    """True when the key's filename is derivable from applicant data."""
    if not name or not name.startswith(DOCUMENTS_PREFIX):
        return False
    filename = name.rsplit("/", 1)[-1]
    if RANDOM_PREFIX_RE.match(filename) or OPAQUE_NAME_RE.match(filename):
        return False
    return True


def rekeyed_name(name: str, max_length: int) -> str | None:
    """Opaque replacement key, or None if it cannot fit in max_length."""
    head, _, filename = name.rpartition("/")
    _, ext = os.path.splitext(filename)
    ext = ext.lower()
    candidate = f"{head}/{uuid.uuid4().hex}{ext}"
    if len(candidate) > max_length:
        # Retry without the extension before giving up; content type is copied
        # from the source object, so the extension is cosmetic.
        candidate = f"{head}/{uuid.uuid4().hex}"
        if len(candidate) > max_length:
            return None
    return candidate


class Command(BaseCommand):
    help = (
        "Rewrite guessable legacy document keys to opaque ones, repoint the DB, "
        "and delete the old keys. Preserves the existing ACL by default."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Print actions without touching storage or the database.",
        )
        parser.add_argument(
            "--limit",
            type=int,
            default=0,
            help="Process at most N documents (0 = no limit). Use for a canary run.",
        )
        parser.add_argument(
            "--acl",
            default="public-read",
            help=(
                "ACL for the new object. Defaults to public-read to preserve "
                "current behaviour; do not set private until signed URLs ship."
            ),
        )
        parser.add_argument(
            "--keep-old",
            action="store_true",
            help="Do not delete the old object after a successful copy.",
        )
        parser.add_argument(
            "--delete-orphans",
            action="store_true",
            help=(
                "Also delete objects under account/documents/ that no document "
                "row references. Respects --dry-run."
            ),
        )

    def handle(self, *args, **options):
        dry_run: bool = options["dry_run"]
        limit: int = options["limit"]
        acl: str = options["acl"]
        keep_old: bool = options["keep_old"]
        delete_orphans: bool = options["delete_orphans"]

        bucket_name = getattr(default_storage, "bucket_name", None)
        if not bucket_name:
            raise CommandError(
                "Default storage is not S3/Spaces. Run this against production "
                "settings where DO_SPACES_BUCKET_NAME is configured."
            )
        client = default_storage.bucket.meta.client
        max_length = ApplicantDocument._meta.get_field("file").max_length

        self.stdout.write(
            f"bucket={bucket_name} acl={acl} max_length={max_length} dry_run={dry_run}"
        )

        rekeyed = 0
        already_ok = 0
        missing = 0
        failed = 0
        too_long = 0

        qs = (
            ApplicantDocument.objects.only("id", "file")
            .order_by("id")
            .iterator(chunk_size=200)
        )

        for doc in qs:
            name = doc.file.name or ""
            if not needs_rekey(name):
                already_ok += 1
                continue

            new_name = rekeyed_name(name, max_length)
            if new_name is None:
                self.stderr.write(f"  cannot fit in max_length, skipped: {name}")
                too_long += 1
                continue

            if dry_run:
                self.stdout.write(f"[dry-run] {doc.pk}: {name} -> {new_name}")
                rekeyed += 1
                if limit and rekeyed >= limit:
                    break
                continue

            try:
                client.copy_object(
                    Bucket=bucket_name,
                    CopySource={"Bucket": bucket_name, "Key": name},
                    Key=new_name,
                    ACL=acl,
                    MetadataDirective="COPY",
                )
                # Confirm the copy landed before removing the only other copy.
                client.head_object(Bucket=bucket_name, Key=new_name)
            except ClientError as exc:
                code = exc.response.get("Error", {}).get("Code", "")
                if code in ("NoSuchKey", "404", "NotFound"):
                    self.stderr.write(f"  missing in bucket, skipped: {name}")
                    missing += 1
                else:
                    self.stderr.write(f"  copy failed ({code}): {name}")
                    failed += 1
                continue

            try:
                # update() avoids re-running upload_to and post_save side effects.
                ApplicantDocument.objects.filter(pk=doc.pk).update(file=new_name)
            except Exception as exc:
                # Roll back the copy so we do not leave a stray public object.
                self.stderr.write(f"  db update failed for {doc.pk}: {exc}")
                try:
                    client.delete_object(Bucket=bucket_name, Key=new_name)
                except ClientError:
                    pass
                failed += 1
                continue

            if not keep_old:
                try:
                    client.delete_object(Bucket=bucket_name, Key=name)
                except ClientError as exc:
                    # DB already points at the new key, so the app is fine; the
                    # stale public object just needs a manual sweep.
                    self.stderr.write(f"  delete failed, still public: {name} ({exc})")

            rekeyed += 1
            if rekeyed % 250 == 0:
                self.stdout.write(f"  ...{rekeyed} re-keyed")
            if limit and rekeyed >= limit:
                break

        if delete_orphans:
            self.stdout.write("")
            self._sweep_orphans(client, bucket_name, dry_run)

        self.stdout.write(
            self.style.SUCCESS(
                f"Done. rekeyed={rekeyed} already_unguessable={already_ok} "
                f"missing={missing} failed={failed} too_long={too_long} "
                f"dry_run={dry_run}"
            )
        )
        if rekeyed and not dry_run:
            self.stdout.write(
                self.style.WARNING(
                    "Old URLs may still be served from the CDN edge for up to "
                    "24h (CacheControl max-age=86400) if they were fetched "
                    "recently. Purge the CDN for account/documents/* to be sure."
                )
            )

    def _sweep_orphans(self, client, bucket_name: str, dry_run: bool) -> None:
        """Delete objects under account/documents/ that no document row uses."""
        referenced = set(ApplicantDocument.objects.values_list("file", flat=True))
        paginator = client.get_paginator("list_objects_v2")
        orphans = 0
        for page in paginator.paginate(Bucket=bucket_name, Prefix=DOCUMENTS_PREFIX):
            for obj in page.get("Contents", []):
                key = obj["Key"]
                if key in referenced:
                    continue
                orphans += 1
                if dry_run:
                    self.stdout.write(f"[dry-run] delete orphan {key}")
                    continue
                try:
                    client.delete_object(Bucket=bucket_name, Key=key)
                except ClientError as exc:
                    self.stderr.write(f"  orphan delete failed: {key} ({exc})")
        self.stdout.write(f"unreferenced objects handled: {orphans}")
