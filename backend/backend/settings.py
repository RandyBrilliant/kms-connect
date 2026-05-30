import os
from datetime import timedelta
from pathlib import Path
from celery.schedules import crontab

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

# Load .env from project root (optional: pip install django-environ)
def _env(key, default=None):
    return os.environ.get(key, default)

try:
    import environ
    env = environ.Env()
    env.read_env(BASE_DIR / ".env")
    def _env(key, default=None):
        return env(key, default=default)
except ImportError:
    pass


# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/6.0/howto/deployment/checklist/

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = _env(
    "SECRET_KEY",
    "django-insecure-+=w8)4##cbke$i$i8hrmu15i=iwm#_7gnmuthd(k9-hfgunlk4",
)

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = _env("DEBUG", "True").lower() in ("true", "1", "yes")

ALLOWED_HOSTS = _env("ALLOWED_HOSTS", "").split(",") if _env("ALLOWED_HOSTS") else []

# Production SSL / secure cookies (set in .env after SSL setup)
SECURE_SSL_REDIRECT = _env("SECURE_SSL_REDIRECT", "0") == "1"
SESSION_COOKIE_SECURE = _env("SESSION_COOKIE_SECURE", "0") == "1"
CSRF_COOKIE_SECURE = _env("CSRF_COOKIE_SECURE", "0") == "1"
CSRF_TRUSTED_ORIGINS = _env("CSRF_TRUSTED_ORIGINS", "").split(",") if _env("CSRF_TRUSTED_ORIGINS") else []

# Trust X-Forwarded-Proto header from Nginx (required when behind a reverse proxy)
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")


# Application definition

INSTALLED_APPS = [
    'daphne',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django_countries',
    'rest_framework',
    'rest_framework_simplejwt',
    'corsheaders',
    'anymail',
    'channels',
    'regions.apps.RegionsConfig',
    'account.apps.AccountConfig',
    'main.apps.MainConfig',
    'chat.apps.ChatConfig',
]

AUTH_USER_MODEL = 'account.CustomUser'

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'backend.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'backend.wsgi.application'
ASGI_APPLICATION = 'backend.asgi.application'


# Database
# https://docs.djangoproject.com/en/6.0/ref/settings/#databases
# PostgreSQL: set DATABASE_URL di .env (postgres://USER:PASSWORD@HOST:PORT/NAME)
# Kosong / tidak set = SQLite
try:
    DATABASES = {
        "default": env.db(
            "DATABASE_URL",
            default="sqlite:///" + str(BASE_DIR / "db.sqlite3"),
        )
    }
except NameError:
    DATABASE_URL = os.environ.get("DATABASE_URL")
    if DATABASE_URL and (
        DATABASE_URL.startswith("postgres://")
        or DATABASE_URL.startswith("postgresql://")
    ):
        raise ValueError(
            "DATABASE_URL dipakai tetapi django-environ tidak terpasang. "
            "Pasang: pip install django-environ"
        )
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }


# Password validation
# https://docs.djangoproject.com/en/6.0/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]


# Internationalization
# https://docs.djangoproject.com/en/6.0/topics/i18n/

LANGUAGE_CODE = 'id-id'

TIME_ZONE = 'Asia/Jakarta'

USE_I18N = True

USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/6.0/howto/static-files/

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

# Media files (user uploads: profile photos, documents)
MEDIA_URL = "media/"
MEDIA_ROOT = BASE_DIR / "media"

# Media storage: local when DEBUG (development), Spaces when not DEBUG and DO_SPACES_* set (production).
_do_spaces_bucket = _env("DO_SPACES_BUCKET_NAME", "").strip()
if _do_spaces_bucket and not DEBUG:
    _do_spaces_region = _env("DO_SPACES_REGION", "sgp1").strip()
    AWS_STORAGE_BUCKET_NAME = _do_spaces_bucket
    AWS_ACCESS_KEY_ID = _env("DO_SPACES_ACCESS_KEY_ID", "")
    AWS_SECRET_ACCESS_KEY = _env("DO_SPACES_SECRET_ACCESS_KEY", "")
    AWS_S3_REGION_NAME = _do_spaces_region
    AWS_S3_ENDPOINT_URL = f"https://{_do_spaces_region}.digitaloceanspaces.com"
    AWS_S3_CUSTOM_DOMAIN = _env("DO_SPACES_CDN_DOMAIN", "")
    # public-read needed for CDN to serve files; use private if you serve via signed URLs only
    AWS_DEFAULT_ACL = _env("DO_SPACES_ACL", "public-read").strip() or "public-read"
    AWS_S3_OBJECT_PARAMETERS = {"CacheControl": "max-age=86400"}
    
    # Django 4.2+ uses STORAGES setting
    try:
        import storages.backends.s3boto3  # noqa: F401
        STORAGES = {
            "default": {
                "BACKEND": "storages.backends.s3boto3.S3Boto3Storage",
            },
            "staticfiles": {
                "BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage",
            },
        }
        # Update MEDIA_URL to use CDN if available
        if AWS_S3_CUSTOM_DOMAIN:
            MEDIA_URL = f"https://{AWS_S3_CUSTOM_DOMAIN}/media/"
    except ImportError:
        pass

# -----------------------------------------------------------------------------
# Env-based (isi di .env; lihat env.example)
# -----------------------------------------------------------------------------
# CORS: asal frontend/mobile yang boleh akses API
# Untuk HTTP-only cookie (web): wajib credentials=True dan daftar origin eksplisit (bukan *).
CORS_ALLOWED_ORIGINS = (
    _env("CORS_ALLOWED_ORIGINS", "").split(",")
    if _env("CORS_ALLOWED_ORIGINS")
    else []
)
CORS_ALLOW_CREDENTIALS = True

# Frontend & email links (untuk tautan verifikasi & reset password)
FRONTEND_URL = _env("FRONTEND_URL", "http://localhost:3000")
# URL logo untuk email (absolut; kosong = tidak tampil). Contoh: https://api.domain.com/static/image/logo.jpg
LOGO_URL = _env("LOGO_URL", "")
# Masa berlaku token verifikasi email (hari)
EMAIL_VERIFICATION_MAX_AGE_DAYS = 7

# -----------------------------------------------------------------------------
# Cache (for document types list, rate limiting; Redis when broker is Redis)
# -----------------------------------------------------------------------------
_cache_backend = "django.core.cache.backends.locmem.LocMemCache"
_cache_location = None
if _env("CELERY_BROKER_URL", "").strip().startswith("redis"):
    _redis_base = _env("CELERY_BROKER_URL", "redis://localhost:6379/0").strip()
    # Use DB 2 for cache to avoid clash with Celery (DB 0)
    _cache_location = _redis_base.rsplit("/", 1)[0] + "/2" if "/" in _redis_base else _redis_base + "/2"
    try:
        from django.core.cache.backends.redis import RedisCache
        _cache_backend = "django.core.cache.backends.redis.RedisCache"
    except ImportError:
        _cache_location = None
if _cache_location:
    try:
        CACHES = {
            "default": {
                "BACKEND": "django.core.cache.backends.redis.RedisCache",
                "LOCATION": _cache_location,
                "KEY_PREFIX": "kms",
                "TIMEOUT": 300,
            }
        }
    except Exception:
        CACHES = {"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache", "OPTIONS": {}, "KEY_PREFIX": "kms", "TIMEOUT": 300}}
else:
    CACHES = {
        "default": {
            "BACKEND": _cache_backend,
            "OPTIONS": {},
            "KEY_PREFIX": "kms",
            "TIMEOUT": 300,
        }
    }

# Document types public list cache TTL (seconds)
DOCUMENT_TYPES_CACHE_TIMEOUT = int(_env("DOCUMENT_TYPES_CACHE_TIMEOUT", "900"))  # 15 min default

# -----------------------------------------------------------------------------
# Django Channels (WebSocket real-time chat)
# -----------------------------------------------------------------------------
# Use Redis DB 1 for the Channel layer (DB 0 = Celery, DB 2 = cache)
_channels_redis_url = _env("CELERY_BROKER_URL", "redis://localhost:6379/0").strip()
_channels_redis_host = _channels_redis_url.rsplit("/", 1)[0] + "/1" if "/" in _channels_redis_url else _channels_redis_url + "/1"

CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {
            "hosts": [_channels_redis_host],
            "capacity": 1500,
            "expiry": 10,
        },
    },
}

# -----------------------------------------------------------------------------
# Django REST Framework & SimpleJWT (untuk serializers/views API)
# -----------------------------------------------------------------------------
REST_FRAMEWORK = {
    # JWT only for the API. SessionAuthentication is omitted so browser POSTs
    # from the SPA are not forced through DRF's CSRF checks (which break
    # hard reloads when a Django session exists, e.g. /admin/ in the same browser).
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "account.jwt_cookie_auth.JWTCookieAuthentication",
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
    "DEFAULT_FILTER_BACKENDS": [
        "django_filters.rest_framework.DjangoFilterBackend",
    ],
    "DEFAULT_PAGINATION_CLASS": "account.pagination.StandardResultsSetPagination",
    "PAGE_SIZE": 20,
    "EXCEPTION_HANDLER": "account.api_responses.api_exception_handler",
    # Throttling: anon/user defaults; auth endpoints use stricter throttle (see account.throttles)
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {
        "anon": _env("DRF_THROTTLE_ANON", "30/min"),
        "user": _env("DRF_THROTTLE_USER", "120/min"),
        "auth": _env("DRF_THROTTLE_AUTH", "10/min"),
        "auth_public": _env("DRF_THROTTLE_AUTH_PUBLIC", "5/min"),
    },
}

SIMPLE_JWT = {
    "AUTH_HEADER_TYPES": ("Bearer",),
    "UPDATE_LAST_LOGIN": True,
    # Token lifetimes — short-lived access, long-lived refresh for mobile UX.
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=int(_env("JWT_ACCESS_MINUTES", "15"))),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=int(_env("JWT_REFRESH_DAYS", "90"))),
    # Rotate refresh tokens so each refresh call issues a fresh refresh token.
    # Mobile clients MUST persist the new refresh token returned in the response body.
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": False,  # Set True only after adding token_blacklist app + migration
    # Cookie names for web (HTTP-only). Mobile uses response body tokens.
    "AUTH_COOKIE_ACCESS_KEY": _env("JWT_ACCESS_COOKIE_NAME", "kms_access"),
    "AUTH_COOKIE_REFRESH_KEY": _env("JWT_REFRESH_COOKIE_NAME", "kms_refresh"),
    "AUTH_COOKIE_SECURE": not DEBUG,
    "AUTH_COOKIE_HTTP_ONLY": True,
    "AUTH_COOKIE_SAMESITE": "Lax",
    "AUTH_COOKIE_PATH": "/",
}

# Mobile clients receive longer-lived refresh tokens so sessions persist
# indefinitely (like Instagram, WhatsApp, etc.). With ROTATE_REFRESH_TOKENS
# enabled, each refresh resets the clock — the user only gets logged out if
# they don't open the app for this many days. Default: 365 days (1 year).
JWT_MOBILE_REFRESH_DAYS = int(_env("JWT_MOBILE_REFRESH_DAYS", "365"))

# Google Login: Client ID untuk verifikasi ID token (google-auth)
GOOGLE_CLIENT_ID = _env("GOOGLE_CLIENT_ID", "")

# Apple Sign-In: Bundle ID (iOS) used as audience when verifying Apple identity tokens.
APPLE_CLIENT_ID = _env("APPLE_CLIENT_ID", "")

# -----------------------------------------------------------------------------
# Google Cloud Vision (OCR dokumen: KTP, dll.)
# -----------------------------------------------------------------------------
# Path ke service account JSON. Bila set, dipakai untuk Vision API (ADC).
# Di GCP (Cloud Run, GKE): bisa kosong, pakai default service account.
GOOGLE_APPLICATION_CREDENTIALS = _env("GOOGLE_APPLICATION_CREDENTIALS", "")
if GOOGLE_APPLICATION_CREDENTIALS:
    # Convert relative path to absolute if needed
    if not os.path.isabs(GOOGLE_APPLICATION_CREDENTIALS):
        GOOGLE_APPLICATION_CREDENTIALS = os.path.join(BASE_DIR, GOOGLE_APPLICATION_CREDENTIALS)
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = GOOGLE_APPLICATION_CREDENTIALS

# -----------------------------------------------------------------------------
# Email (Resend API via django-anymail – bukan SMTP)
# -----------------------------------------------------------------------------
RESEND_API_KEY = _env("RESEND_API_KEY", "")
DEFAULT_FROM_EMAIL = _env("DEFAULT_FROM_EMAIL", "noreply@localhost")

if RESEND_API_KEY:
    EMAIL_BACKEND = "anymail.backends.resend.EmailBackend"
    ANYMAIL = {"RESEND_API_KEY": RESEND_API_KEY}
else:
    EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# Email rate limiting (Resend default: 5 API requests/second per team)
# Default 4 req/sec leaves headroom; increase via support if Resend raises your limit
EMAIL_RATE_LIMIT = int(_env("EMAIL_RATE_LIMIT", "4"))  # Max emails per window
EMAIL_RATE_LIMIT_WINDOW = int(_env("EMAIL_RATE_LIMIT_WINDOW", "1"))  # Window in seconds

# -----------------------------------------------------------------------------
# Celery (background tasks: email, OCR, export, push)
# -----------------------------------------------------------------------------
CELERY_BROKER_URL = _env("CELERY_BROKER_URL", "redis://localhost:6379/0")
CELERY_RESULT_BACKEND = _env("CELERY_RESULT_BACKEND", CELERY_BROKER_URL)
CELERY_ACCEPT_CONTENT = ["json"]
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_TIMEZONE = TIME_ZONE
CELERY_TASK_TRACK_STARTED = True
CELERY_TASK_TIME_LIMIT = 30 * 60  # 30 minutes max per task
CELERY_BEAT_SCHEDULE = {
    # ---- Existing ----
    # Close job listings that have passed their deadline (midnight daily).
    "close-expired-jobs-every-midnight": {
        "task": "main.tasks.close_expired_jobs",
        "schedule": crontab(minute=0, hour=0),
    },

    # ---- Notification schedules ----
    # Admin daily digest: pending profiles + new applicants (07:30 WIB).
    "admin-daily-digest": {
        "task": "account.tasks.send_admin_daily_digest",
        "schedule": crontab(minute=30, hour=7),
    },
    # Job deadline reminders: notify applicants when deadline is 3 days away (09:00 WIB).
    "job-deadline-reminders-daily": {
        "task": "account.tasks.send_job_deadline_reminders",
        "schedule": crontab(minute=0, hour=9),
    },
    # Batch departure reminders: 7-day and 1-day alerts (08:00 WIB).
    "batch-departure-reminders-daily": {
        "task": "account.tasks.send_batch_departure_reminders",
        "schedule": crontab(minute=0, hour=8),
    },
}

# -----------------------------------------------------------------------------
# Firebase Cloud Messaging (push notifications)
# -----------------------------------------------------------------------------
FIREBASE_CREDENTIALS_PATH = _env("FIREBASE_CREDENTIALS_PATH", "")
if not FIREBASE_CREDENTIALS_PATH:
    # Default to firebase-service-account.json in BASE_DIR if env var not set
    default_path = os.path.join(BASE_DIR, "firebase-service-account.json")
    if os.path.exists(default_path):
        FIREBASE_CREDENTIALS_PATH = default_path
elif not os.path.isabs(FIREBASE_CREDENTIALS_PATH):
    # Convert relative path to absolute
    FIREBASE_CREDENTIALS_PATH = os.path.join(BASE_DIR, FIREBASE_CREDENTIALS_PATH)
