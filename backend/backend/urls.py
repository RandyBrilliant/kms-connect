"""
URL configuration for backend project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/6.0/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import path, include
from rest_framework_simplejwt.views import TokenVerifyView

from . import views
from account.auth_cookie_views import (
    CookieTokenObtainPairView,
    CookieTokenRefreshView,
    CookieLogoutView,
    VerifyEmailView,
    RequestPasswordResetView,
    ConfirmResetPasswordView,
)

urlpatterns = [
    path("health/", views.health),
    path("admin/", admin.site.urls),
    path("api/auth/token/", CookieTokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("api/auth/token/refresh/", CookieTokenRefreshView.as_view(), name="token_refresh"),
    path("api/auth/token/verify/", TokenVerifyView.as_view(), name="token_verify"),
    path("api/auth/logout/", CookieLogoutView.as_view(), name="auth_logout"),
    path("api/auth/verify-email/", VerifyEmailView.as_view(), name="verify_email"),
    path("api/auth/request-password-reset/", RequestPasswordResetView.as_view(), name="request_password_reset"),
    path("api/auth/confirm-reset-password/", ConfirmResetPasswordView.as_view(), name="confirm_reset_password"),
    path("api/", include("account.urls")),
    path("api/", include("main.urls")),
]

if settings.DEBUG and settings.MEDIA_ROOT:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
