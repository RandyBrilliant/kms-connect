"""
Redis-based Token Bucket Rate Limiter for Resend API calls.

This module provides a rate limiter that works across multiple Celery workers
by using Redis as a shared state store.

Usage:
    from .rate_limiter import rate_limit, RateLimitExceeded

    @rate_limit("resend", limit=4, period=1)
    def send_email(...):
        ...

Or manually:
    limiter = RateLimiter("resend", limit=4, period=1)
    if limiter.acquire():
        send_email(...)
    else:
        raise RateLimitExceeded("resend")
"""

import logging
import time
from functools import wraps
from typing import Callable, Any

from django.core.cache import cache

logger = logging.getLogger(__name__)


class RateLimitExceeded(Exception):
    """Raised when rate limit is exceeded and cannot acquire a token."""

    def __init__(self, key: str, retry_after: float = 1.0):
        self.key = key
        self.retry_after = retry_after
        super().__init__(f"Rate limit exceeded for '{key}'. Retry after {retry_after:.1f}s")


class RateLimiter:
    """
    Token Bucket Rate Limiter using Redis/Django cache.

    Limits the rate of operations across all workers to `limit` operations
    per `period` seconds.

    Args:
        key: Unique identifier for this rate limiter (e.g., "resend")
        limit: Maximum number of operations allowed per period
        period: Time window in seconds (default: 60)
    """

    def __init__(self, key: str, limit: int = 60, period: int = 60):
        self.key = key
        self.limit = limit
        self.period = period
        self._cache_key = f"rate_limit:{key}"
        self._cache_key_reset = f"rate_limit:{key}:reset"

    def _get_current_count(self) -> int:
        """Get current request count from cache."""
        try:
            count = cache.get(self._cache_key)
            return int(count) if count is not None else 0
        except Exception as e:
            logger.warning(f"Rate limiter cache read failed: {e}")
            return 0

    def _get_reset_time(self) -> float:
        """Get the time when the rate limit window resets."""
        try:
            reset_time = cache.get(self._cache_key_reset)
            return float(reset_time) if reset_time is not None else 0
        except Exception as e:
            logger.warning(f"Rate limiter cache read failed: {e}")
            return 0

    def acquire(self, block: bool = False, timeout: float = 30.0) -> bool:
        """
        Try to acquire a token from the bucket.

        Uses Django's cache API exclusively so key prefixes stay consistent.
        Django's RedisCache.incr() is atomic (Redis INCR under the hood).

        Args:
            block: If True, wait until a token is available
            timeout: Maximum time to wait if blocking (seconds)

        Returns:
            True if token acquired, False otherwise
        """
        start_time = time.time()
        ttl = self.period + 5

        while True:
            try:
                current_time = time.time()
                reset_time = self._get_reset_time()

                if reset_time == 0 or current_time >= reset_time:
                    new_reset_time = current_time + self.period
                    cache.set(self._cache_key, 1, timeout=ttl)
                    cache.set(self._cache_key_reset, new_reset_time, timeout=ttl)
                    logger.debug(
                        f"Rate limiter '{self.key}': New window, count=1/{self.limit}"
                    )
                    return True

                current_count = self._get_current_count()

                if current_count < self.limit:
                    try:
                        new_count = cache.incr(self._cache_key)
                    except ValueError:
                        cache.set(self._cache_key, 1, timeout=ttl)
                        new_count = 1

                    if new_count <= self.limit:
                        logger.debug(
                            f"Rate limiter '{self.key}': Token acquired, "
                            f"count={new_count}/{self.limit}"
                        )
                        return True

                if not block:
                    retry_after = reset_time - current_time
                    logger.info(
                        f"Rate limiter '{self.key}': Limit reached "
                        f"({current_count}/{self.limit}), retry after {retry_after:.1f}s"
                    )
                    return False

                elapsed = time.time() - start_time
                if elapsed >= timeout:
                    logger.warning(
                        f"Rate limiter '{self.key}': Timeout waiting for token"
                    )
                    return False

                wait_time = min(reset_time - current_time + 0.1, timeout - elapsed)
                if wait_time > 0:
                    logger.debug(
                        f"Rate limiter '{self.key}': Waiting {wait_time:.1f}s for token"
                    )
                    time.sleep(wait_time)

            except Exception as e:
                logger.error(f"Rate limiter error: {e}")
                return True

    def get_status(self) -> dict:
        """Get current rate limiter status."""
        current_time = time.time()
        reset_time = self._get_reset_time()
        current_count = self._get_current_count()

        return {
            "key": self.key,
            "limit": self.limit,
            "period": self.period,
            "current_count": current_count,
            "remaining": max(0, self.limit - current_count),
            "reset_in": max(0, reset_time - current_time) if reset_time else 0,
        }


# Singleton instances for common rate limiters
_limiters: dict[str, RateLimiter] = {}


def get_limiter(key: str, limit: int = 60, period: int = 60) -> RateLimiter:
    """Get or create a rate limiter instance."""
    cache_key = f"{key}:{limit}:{period}"
    if cache_key not in _limiters:
        _limiters[cache_key] = RateLimiter(key, limit, period)
    return _limiters[cache_key]


def rate_limit(
    key: str,
    limit: int = 60,
    period: int = 60,
    block: bool = False,
    timeout: float = 30.0,
) -> Callable:
    """
    Decorator to apply rate limiting to a function.

    Args:
        key: Unique identifier for this rate limiter
        limit: Maximum operations per period
        period: Time window in seconds
        block: If True, wait for token instead of raising exception
        timeout: Maximum wait time if blocking

    Raises:
        RateLimitExceeded: When rate limit is exceeded and not blocking

    Example:
        @rate_limit("resend", limit=4, period=1)
        def send_email(to, subject, body):
            ...
    """

    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs) -> Any:
            limiter = get_limiter(key, limit, period)

            if not limiter.acquire(block=block, timeout=timeout):
                status = limiter.get_status()
                raise RateLimitExceeded(key, retry_after=status["reset_in"])

            return func(*args, **kwargs)

        return wrapper

    return decorator


# Convenience function for manual rate limiting
def check_rate_limit(key: str, limit: int = 60, period: int = 60) -> bool:
    """
    Check and consume a rate limit token.

    Returns:
        True if allowed, False if rate limited
    """
    limiter = get_limiter(key, limit, period)
    return limiter.acquire(block=False)
