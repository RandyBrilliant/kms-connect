"""Throttle for the public region dropdowns."""

from rest_framework.throttling import SimpleRateThrottle


class GeoRateThrottle(SimpleRateThrottle):
    """
    Per-IP cap on unauthenticated geo lists.

    The real protection is requiring a parent id so villages cannot dump 80k
    rows. This stops a client from hammering the filtered endpoints.
    """

    scope = "geo"

    def get_cache_key(self, request, view):
        return self.cache_format % {
            "scope": self.scope,
            "ident": self.get_ident(request),
        }
