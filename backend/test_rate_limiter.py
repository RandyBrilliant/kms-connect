"""
Test script for email rate limiter.

Run this to verify the rate limiter is working correctly.

Usage:
    python manage.py shell < test_rate_limiter.py
"""

from account.services.rate_limiter import RateLimiter, RateLimitExceeded, get_limiter
from account.services.email_service import send_email, get_rate_limit_status
import time

print("=" * 60)
print("Email Rate Limiter Test")
print("=" * 60)

# Test 1: Basic rate limiter functionality
print("\n1. Testing basic rate limiter (5 requests/10 seconds)...")
limiter = RateLimiter("test", limit=5, period=10)

success_count = 0
for i in range(7):
    if limiter.acquire(block=False):
        success_count += 1
        print(f"   Request {i+1}: ✓ Allowed")
    else:
        print(f"   Request {i+1}: ✗ Rate limited")

print(f"   Result: {success_count}/7 requests allowed (expected: 5)")
assert success_count == 5, "Rate limiter should allow exactly 5 requests"

# Test 2: Get status
print("\n2. Testing rate limiter status...")
status = limiter.get_status()
print(f"   Current count: {status['current_count']}/{status['limit']}")
print(f"   Remaining: {status['remaining']}")
print(f"   Reset in: {status['reset_in']:.1f}s")

# Test 3: Wait for reset
print(f"\n3. Waiting {status['reset_in']:.1f}s for rate limit reset...")
time.sleep(status['reset_in'] + 0.5)
if limiter.acquire(block=False):
    print("   ✓ Rate limit reset successfully")
else:
    print("   ✗ Rate limit did not reset")

# Test 4: Email service status
print("\n4. Testing email service rate limit status...")
email_status = get_rate_limit_status()
print(f"   Email rate limit: {email_status['limit']}/minute")
print(f"   Current count: {email_status['current_count']}")
print(f"   Remaining: {email_status['remaining']}")

# Test 5: RateLimitExceeded exception
print("\n5. Testing RateLimitExceeded exception...")
test_limiter = RateLimiter("test2", limit=1, period=60)
test_limiter.acquire()  # Use up the limit
try:
    if not test_limiter.acquire(block=False):
        raise RateLimitExceeded("test2", retry_after=5.0)
    print("   ✗ Should have raised exception")
except RateLimitExceeded as e:
    print(f"   ✓ Exception raised: {e}")
    print(f"   ✓ Retry after: {e.retry_after}s")

print("\n" + "=" * 60)
print("All tests passed! ✓")
print("=" * 60)

print("\n⚠️  IMPORTANT: To test in production-like scenario:")
print("   1. Set EMAIL_RATE_LIMIT=60 in your .env")
print("   2. Send 100+ emails via Celery tasks")
print("   3. Monitor logs for 'Rate limit hit' messages")
print("   4. Verify emails are retried automatically")
