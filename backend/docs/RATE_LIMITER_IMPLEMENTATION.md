# Mailgun Rate Limiter Implementation - Complete

## ✅ Changes Made

### 1. New Files Created

#### `backend/account/services/rate_limiter.py`
- **Token Bucket Rate Limiter** using Redis
- Limits operations across all Celery workers
- Configurable rate (default: 60/minute)
- Fallback mode if Redis unavailable
- Custom `RateLimitExceeded` exception for retry handling

**Key features:**
- Atomic operations using Redis INCR
- Blocking and non-blocking modes
- Status monitoring (`get_status()`)
- Decorator pattern for easy application

#### `backend/account/services/email_service.py`
- **Centralized email sending function**
- Automatically applies rate limiting
- Single and bulk email support
- Integrates with existing Django email backend

**Functions:**
- `send_email()` - Rate-limited single/multi-recipient send
- `send_email_bulk()` - For admin digests (multiple recipients)
- `get_rate_limit_status()` - Monitoring helper

### 2. Configuration Added

#### `backend/backend/settings.py` (after line 360)
```python
# Email rate limiting (to prevent Mailgun API rate limit errors)
# Mailgun Foundation plan: ~100-300/minute, we use 60/minute as safe default
EMAIL_RATE_LIMIT = int(_env("EMAIL_RATE_LIMIT", "60"))  # Max emails per window
EMAIL_RATE_LIMIT_WINDOW = int(_env("EMAIL_RATE_LIMIT_WINDOW", "60"))  # Window in seconds
```

**Environment variables (optional):**
- `EMAIL_RATE_LIMIT=60` - Adjust based on your Mailgun plan
- `EMAIL_RATE_LIMIT_WINDOW=60` - Time window in seconds

### 3. Tasks Updated

#### `backend/account/tasks.py`
All email-sending tasks now use the rate-limited email service:

1. **`send_email_async`** (line 123)
   - Changed to use `send_email()` from email_service
   - Catches `RateLimitExceeded` and retries with delay
   - Increased max_retries from 3 to 5

2. **`send_verification_email_task`** (line 145)
   - Uses rate-limited `send_email()`
   - Auto-retries on rate limit with backoff
   - Max retries: 5

3. **`send_password_reset_email_task`** (line 189)
   - Rate-limited email sending
   - Auto-retry with countdown
   - Max retries: 5

4. **`send_notification_email_task`** (line 228)
   - Rate-limited with retry logic
   - Only marks as sent after successful send
   - Max retries: 5

5. **`send_event_email_task`** (line 335)
   - Event-driven emails now rate-limited
   - Retry on rate limit exceeded
   - Max retries: 5

6. **`send_admin_daily_digest`** (line 420)
   - Uses `send_email_bulk()` for multiple recipients
   - Rate-limited (counts as 1 API call)
   - Auto-retry on rate limit
   - Max retries: 5

---

## 🔧 How It Works

### Rate Limiting Flow

```
1. Task calls send_email()
   ↓
2. email_service checks rate limiter
   ↓
3a. Token available → Send email ✓
   ↓
3b. Token unavailable → Raise RateLimitExceeded
   ↓
4. Celery catches exception
   ↓
5. Retry task after countdown (retry_after + 1 second)
   ↓
6. Repeat until success or max_retries
```

### Redis Storage

```
Key: rate_limit:mailgun
Value: Current request count

Key: rate_limit:mailgun:reset
Value: Unix timestamp when window resets
```

---

## 📊 Configuration Options

### Default Settings
- **Rate limit:** 60 emails/minute
- **Window:** 60 seconds
- **Max retries:** 5 attempts per task
- **Retry strategy:** Exponential backoff + countdown

### Adjust for Different Plans

**Mailgun Foundation (default):**
```env
EMAIL_RATE_LIMIT=60
EMAIL_RATE_LIMIT_WINDOW=60
```

**Mailgun Growth:**
```env
EMAIL_RATE_LIMIT=100
EMAIL_RATE_LIMIT_WINDOW=60
```

**For testing/development:**
```env
EMAIL_RATE_LIMIT=10
EMAIL_RATE_LIMIT_WINDOW=60
```

---

## 🧪 Testing

### 1. Unit Test (Backend)
```bash
cd backend
python test_rate_limiter.py
```

### 2. Integration Test (Send 100+ emails)
```python
from account.tasks import send_email_async

# Queue 150 emails
for i in range(150):
    send_email_async.delay(
        to_email=f"test{i}@example.com",
        subject="Test",
        body="Testing rate limiter"
    )
```

**Expected behavior:**
- First 60 emails send immediately
- Remaining emails retry automatically
- Check logs for "Rate limit hit" messages
- All emails eventually sent successfully

### 3. Monitor Rate Limit Status
```python
from account.services.email_service import get_rate_limit_status

status = get_rate_limit_status()
print(status)
# {'limit': 60, 'current_count': 45, 'remaining': 15, 'reset_in': 23.5}
```

---

## 📝 Logs to Monitor

### Successful emails:
```
DEBUG: Email sent to ['user@example.com']: Welcome Email
DEBUG: Rate limiter 'mailgun': Token acquired, count=45/60
```

### Rate limited (will retry):
```
WARNING: Email rate limit hit: 60/60 emails sent. Retry after 15.3s. Recipients: ['user@example.com']
INFO: Task account.tasks.send_email_async[abc-123] retry: RateLimitExceeded('mailgun')
```

### After retry success:
```
DEBUG: Rate limiter 'mailgun': New window started, count=1/60
DEBUG: Email sent to ['user@example.com']: Welcome Email
```

---

## 🚨 Troubleshooting

### Issue: Emails stuck/not sending

**Check Redis connection:**
```python
from django.core.cache import cache
cache.set('test', 'hello')
print(cache.get('test'))  # Should print 'hello'
```

**Check Celery workers:**
```bash
celery -A backend inspect active
```

### Issue: Rate limit not working

**Verify settings loaded:**
```python
from django.conf import settings
print(settings.EMAIL_RATE_LIMIT)  # Should print 60
```

**Check rate limiter status:**
```python
from account.services.email_service import get_rate_limit_status
print(get_rate_limit_status())
```

### Issue: Too many retries

**Increase max_retries in tasks.py:**
```python
@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, max_retries=10)
```

---

## 🔄 Rollback Plan

If issues occur:

1. **Quick fix:** Increase rate limit temporarily
   ```env
   EMAIL_RATE_LIMIT=200  # Double the limit
   ```

2. **Disable rate limiting:** Set very high limit
   ```env
   EMAIL_RATE_LIMIT=10000  # Effectively unlimited
   ```

3. **Full rollback:** Revert to old code
   - The rate limiter has fallback mode (allows all requests on error)
   - Won't break email sending, just loses rate limiting

---

## 📈 Production Checklist

- [x] Rate limiter implemented with Redis
- [x] All email tasks updated to use rate limiter
- [x] Configuration added to settings.py
- [x] Retry logic with exponential backoff
- [x] Monitoring and logging in place
- [ ] **Test with 100+ emails in staging**
- [ ] **Monitor logs for rate limit events**
- [ ] **Verify Celery workers handling retries**
- [ ] **Set EMAIL_RATE_LIMIT in production .env**
- [ ] **Restart Celery workers after deployment**

---

## 🎯 Expected Results

### Before (Issue):
- Send 100 emails → Mailgun rate limit error
- Some emails fail
- Manual retry needed

### After (Fixed):
- Send 100 emails → Automatic throttling
- First 60 send immediately
- Next 40 retry automatically after 1 minute
- All emails delivered successfully
- Zero Mailgun rate limit errors

---

## 💡 Future Improvements

1. **Add Mailgun Batch API** (Option B)
   - When you reach 1,000+ emails/day
   - Requires code restructure
   - Can send 1,000 recipients per API call

2. **Add monitoring dashboard**
   - Track email sending rates
   - Alert on high retry counts
   - Visualize rate limit usage

3. **Per-event rate limits**
   - Different limits for different email types
   - Priority queue for critical emails
   - Separate limits for transactional vs marketing

---

## 📞 Support

If you encounter issues:
1. Check logs in Celery worker output
2. Verify Redis is running and accessible
3. Test rate limiter with test script
4. Check Mailgun dashboard for API errors

**Rate limiter is production-safe:**
- Has fallback mode on errors
- Won't block emails if Redis fails
- Logs all rate limit events for debugging
