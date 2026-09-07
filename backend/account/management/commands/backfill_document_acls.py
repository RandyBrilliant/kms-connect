"""
Make existing applicant document objects private (B1 step 3).

New uploads already land private — ApplicantDocument.file is bound to its own
storage with default_acl=private. Everything written before that still carries
the bucket's public-read default, so any object URL that leaked is still
readable by whoever holds it. This command closes that.

Scoped hard to account/documents/. The bucket also serves public website images
under main/news/ and is shared with an unrelated project, so a global ACL flip
would break things outside this app. The prefix is a module constant rather
than an option for exactly that reason.

Nothing in the product reads a document by object URL any more: the frontend
links, passport_file_url, and the Excel exports all go through the authenticated
file/ endpoint, which re-signs on every request. So this is safe to run.

Only the ACL is rewritten. Object data and metadata are left alone, which is
why this uses put_object_acl rather than a copy — a copy would rewrite 46k
objects to change a header that no longer matters once they are private.

Already-cached copies at the CDN edge can still be served until their
CacheControl (max-age=86400, set when they were uploaded) expires. Purge the
CDN for account/documents/* afterwards to close that window immediately.

Usage:
  python manage.py backfill_document_acls --dry-run
  python manage.py backfill_document_acls --limit 200      # canary
  python manage.py backfill_document_acls --verify --limit 200
  python manage.py backfill_document_acls                  # the rest
"""

from concurrent.futures import ThreadPoolExecutor

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError
from django.core.files.storage import default_storage
from django.core.management.base import BaseCommand, CommandError

# Never widen this. See the module docstring.
DOCUMENTS_PREFIX = "account/documents/"

PUBLIC_URI_FRAGMENT = "AllUsers"


def build_client(storage, workers: int):
    """
    An S3 client sized and configured for a long ACL rewrite.

    Two departures from the storage's own client. Adaptive retries, because
    Spaces throttles a sustained rewrite and botocore's default mode backs off
    without logging anything, which is indistinguishable from a hang. And a
    connection pool at least as large as the worker count, since the default
    of 10 would otherwise cap concurrency no matter how many threads run.
    """
    return boto3.client(
        "s3",
        endpoint_url=storage.endpoint_url,
        region_name=storage.region_name,
        aws_access_key_id=storage.access_key,
        aws_secret_access_key=storage.secret_key,
        config=Config(
            retries={"max_attempts": 10, "mode": "adaptive"},
            max_pool_connections=max(10, workers),
        ),
    )


def is_public(acl: dict) -> bool:
    """True when the ACL grants READ to anonymous callers."""
    for grant in acl.get("Grants", []):
        uri = grant.get("Grantee", {}).get("URI", "") or ""
        if PUBLIC_URI_FRAGMENT in uri:
            return True
    return False


class Command(BaseCommand):
    help = (
        "Set ACL=private on existing objects under account/documents/. "
        "Leaves every other prefix, and all object data, untouched."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Report what would change without writing any ACL.",
        )
        parser.add_argument(
            "--limit",
            type=int,
            default=0,
            help="Stop after N objects made private (0 = no limit). Use for a canary.",
        )
        parser.add_argument(
            "--workers",
            type=int,
            default=16,
            help="Parallel ACL requests. Lower this if Spaces starts throttling.",
        )
        parser.add_argument(
            "--verify",
            action="store_true",
            help=(
                "Re-read each ACL after writing it and fail loudly if it is "
                "still public. Slower; worth it on a canary run."
            ),
        )
        parser.add_argument(
            "--verbose",
            action="store_true",
            help="Print each key whose ACL is rewritten (or would be, on --dry-run).",
        )

    def handle(self, *args, **options):
        dry_run: bool = options["dry_run"]
        limit: int = options["limit"]
        workers: int = max(1, options["workers"])
        verify: bool = options["verify"]
        verbose: bool = options["verbose"]
        # docker exec buffers Python stdout; without this a long run looks hung.
        try:
            self.stdout.reconfigure(line_buffering=True)
            self.stderr.reconfigure(line_buffering=True)
        except (AttributeError, OSError):
            pass

        bucket_name = getattr(default_storage, "bucket_name", None)
        if not bucket_name:
            raise CommandError(
                "Default storage is not S3/Spaces. Run this against production "
                "settings where DO_SPACES_BUCKET_NAME is configured."
            )
        client = build_client(default_storage, workers)

        # --limit must be exact, and already-private objects must not eat it.
        # Parallelism would race past the budget, so a capped run is sequential.
        if limit:
            workers = 1

        self.stdout.write(
            f"bucket={bucket_name} prefix={DOCUMENTS_PREFIX} "
            f"workers={workers} dry_run={dry_run} verify={verify}"
        )

        self.scanned = 0
        self.already_private = 0
        self.made_private = 0
        self.failed = 0
        self.still_public = 0

        def process(key: str) -> None:
            # Belt and braces: the paginator is already scoped by Prefix, but a
            # mistake here would mean privatising someone else's project.
            if limit and self.made_private >= limit:
                return
            if not key.startswith(DOCUMENTS_PREFIX):
                self.stderr.write(f"  outside prefix, refused: {key}")
                self.failed += 1
                return
            try:
                acl = client.get_object_acl(Bucket=bucket_name, Key=key)
            except ClientError as exc:
                self.stderr.write(f"  read acl failed: {key} ({exc})")
                self.failed += 1
                return

            if not is_public(acl):
                self.already_private += 1
                return

            if limit and self.made_private >= limit:
                return

            if dry_run:
                if verbose:
                    self.stdout.write(f"  [dry-run] {key}")
                self.made_private += 1
                return

            try:
                client.put_object_acl(
                    Bucket=bucket_name, Key=key, ACL="private"
                )
            except ClientError as exc:
                self.stderr.write(f"  write acl failed: {key} ({exc})")
                self.failed += 1
                return

            if verify:
                try:
                    after = client.get_object_acl(Bucket=bucket_name, Key=key)
                except ClientError as exc:
                    self.stderr.write(f"  verify failed: {key} ({exc})")
                    self.failed += 1
                    return
                if is_public(after):
                    self.stderr.write(f"  STILL PUBLIC after write: {key}")
                    self.still_public += 1
                    return

            if verbose:
                self.stdout.write(f"  private {key}")
            self.made_private += 1

        paginator = client.get_paginator("list_objects_v2")
        # Small pages so --limit is honoured promptly and progress is visible.
        pages = paginator.paginate(
            Bucket=bucket_name,
            Prefix=DOCUMENTS_PREFIX,
            PaginationConfig={"PageSize": 200},
        )

        with ThreadPoolExecutor(max_workers=workers) as pool:
            for page in pages:
                keys = [obj["Key"] for obj in page.get("Contents", [])]
                if not keys:
                    continue
                if limit:
                    for key in keys:
                        if self.made_private >= limit:
                            break
                        process(key)
                        self.scanned += 1
                else:
                    self.scanned += len(keys)
                    list(pool.map(process, keys))
                self.stdout.write(
                    f"  scanned {self.scanned}, made private {self.made_private}, "
                    f"already private {self.already_private}, failed {self.failed}",
                    ending="\n",
                )
                self.stdout.flush()

                if limit and self.made_private >= limit:
                    self.stdout.write(f"  reached --limit {limit}, stopping")
                    break

        summary = (
            f"Done. scanned={self.scanned} "
            f"{'would_make_private' if dry_run else 'made_private'}="
            f"{self.made_private} already_private={self.already_private} "
            f"failed={self.failed} still_public={self.still_public} "
            f"dry_run={dry_run}"
        )
        if self.failed or self.still_public:
            self.stdout.write(self.style.ERROR(summary))
        else:
            self.stdout.write(self.style.SUCCESS(summary))

        if self.made_private and not dry_run:
            self.stdout.write(
                self.style.WARNING(
                    "Objects fetched through the CDN in the last 24h may still "
                    "be served from the edge until CacheControl max-age=86400 "
                    "expires. Purge the CDN for account/documents/* to close "
                    "that window now."
                )
            )
