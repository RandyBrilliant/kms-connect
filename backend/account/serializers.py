"""
Serializers for account API (admin-side CRUD: Admin, Staff, Company, Applicant).
Mendukung partial update (PATCH); pesan error/detail dari api_responses untuk frontend.
"""
from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError

from .models import (
    CustomUser,
    UserRole,
    StaffProfile,
    CompanyProfile,
    ApplicantProfile,
    WorkExperience,
    DocumentType,
    ApplicantDocument,
)
from .api_responses import (
    ApiMessage,
    validate_email_unique,
    validate_nik_format,
    validate_nik_unique,
)


# ---------------------------------------------------------------------------
# Admin (CustomUser saja, role=ADMIN)
# ---------------------------------------------------------------------------

class AdminUserSerializer(serializers.ModelSerializer):
    """CRUD untuk pengguna Admin. Hanya CustomUser, tanpa profil."""

    password = serializers.CharField(write_only=True, required=False, validators=[validate_password])

    class Meta:
        model = CustomUser
        fields = [
            "id",
            "email",
            "password",
            "is_active",
            "email_verified",
            "email_verified_at",
            "date_joined",
            "updated_at",
        ]
        read_only_fields = ["id", "email_verified_at", "date_joined", "updated_at"]
        extra_kwargs = {"password": {"write_only": True, "required": False}}

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if self.context.get("is_own_profile"):
            for f in ("is_active", "email_verified"):
                if f in self.fields:
                    self.fields[f].read_only = True

    def validate_email(self, value):
        return validate_email_unique(CustomUser, value, self.instance)

    def create(self, validated_data):
        password = validated_data.pop("password", None)
        if not password:
            raise serializers.ValidationError({
                "password": [ApiMessage.PASSWORD_REQUIRED_ON_CREATE],
            })
        user = CustomUser.objects.create_user(
            role=UserRole.ADMIN,
            **validated_data,
        )
        user.set_password(password)
        user.save(update_fields=["password"])
        return user

    def update(self, instance, validated_data):
        password = validated_data.pop("password", None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        if password is not None:
            instance.set_password(password)
        instance.save()
        return instance


# ---------------------------------------------------------------------------
# Staff (CustomUser + StaffProfile)
# ---------------------------------------------------------------------------

class StaffProfileSerializer(serializers.ModelSerializer):
    """Profil staf (nama, telepon, foto)."""

    class Meta:
        model = StaffProfile
        fields = ["id", "full_name", "contact_phone", "photo", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]


class StaffUserSerializer(serializers.ModelSerializer):
    """CRUD untuk pengguna Staff: user + profil staf (nested)."""

    password = serializers.CharField(write_only=True, required=False, validators=[validate_password])
    staff_profile = StaffProfileSerializer(required=False)

    class Meta:
        model = CustomUser
        fields = [
            "id",
            "email",
            "password",
            "is_active",
            "email_verified",
            "email_verified_at",
            "date_joined",
            "updated_at",
            "staff_profile",
        ]
        read_only_fields = ["id", "email_verified_at", "date_joined", "updated_at"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if self.context.get("is_own_profile"):
            for f in ("is_active", "email_verified"):
                if f in self.fields:
                    self.fields[f].read_only = True

    def validate_email(self, value):
        return validate_email_unique(CustomUser, value, self.instance)

    def create(self, validated_data):
        profile_data = validated_data.pop("staff_profile", None)
        if not profile_data or not profile_data.get("full_name"):
            raise serializers.ValidationError({
                "staff_profile": {"full_name": [ApiMessage.PROFILE_FULL_NAME_REQUIRED]},
            })
        password = validated_data.pop("password", None)
        if not password:
            raise serializers.ValidationError({
                "password": [ApiMessage.PASSWORD_REQUIRED_ON_CREATE],
            })
        user = CustomUser.objects.create_user(role=UserRole.STAFF, **validated_data)
        user.set_password(password)
        user.save(update_fields=["password"])
        StaffProfile.objects.create(user=user, **profile_data)
        return user

    def update(self, instance, validated_data):
        profile_data = validated_data.pop("staff_profile", None)
        password = validated_data.pop("password", None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        if password is not None:
            instance.set_password(password)
        instance.save()
        if profile_data is not None:
            profile = getattr(instance, "staff_profile", None)
            if profile:
                for attr, value in profile_data.items():
                    setattr(profile, attr, value)
                profile.save()
            else:
                StaffProfile.objects.create(user=instance, **profile_data)
        return instance


# ---------------------------------------------------------------------------
# Company (CustomUser + CompanyProfile)
# ---------------------------------------------------------------------------

class CompanyProfileSerializer(serializers.ModelSerializer):
    """Profil perusahaan (nama perusahaan, telepon, alamat)."""

    class Meta:
        model = CompanyProfile
        fields = ["id", "company_name", "contact_phone", "address", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]


class CompanyUserSerializer(serializers.ModelSerializer):
    """CRUD untuk pengguna Perusahaan: user + profil perusahaan (nested)."""

    password = serializers.CharField(write_only=True, required=False, validators=[validate_password])
    company_profile = CompanyProfileSerializer(required=False)

    class Meta:
        model = CustomUser
        fields = [
            "id",
            "email",
            "password",
            "is_active",
            "email_verified",
            "email_verified_at",
            "date_joined",
            "updated_at",
            "company_profile",
        ]
        read_only_fields = ["id", "email_verified_at", "date_joined", "updated_at"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if self.context.get("is_own_profile"):
            for f in ("is_active", "email_verified"):
                if f in self.fields:
                    self.fields[f].read_only = True

    def validate_email(self, value):
        return validate_email_unique(CustomUser, value, self.instance)

    def create(self, validated_data):
        profile_data = validated_data.pop("company_profile", None)
        if not profile_data or not profile_data.get("company_name"):
            raise serializers.ValidationError({
                "company_profile": {"company_name": [ApiMessage.PROFILE_COMPANY_NAME_REQUIRED]},
            })
        password = validated_data.pop("password", None)
        if not password:
            raise serializers.ValidationError({
                "password": [ApiMessage.PASSWORD_REQUIRED_ON_CREATE],
            })
        user = CustomUser.objects.create_user(role=UserRole.COMPANY, **validated_data)
        user.set_password(password)
        user.save(update_fields=["password"])
        CompanyProfile.objects.create(user=user, **profile_data)
        return user

    def update(self, instance, validated_data):
        profile_data = validated_data.pop("company_profile", None)
        password = validated_data.pop("password", None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        if password is not None:
            instance.set_password(password)
        instance.save()
        if profile_data is not None:
            profile = getattr(instance, "company_profile", None)
            if profile:
                for attr, value in profile_data.items():
                    setattr(profile, attr, value)
                profile.save()
            else:
                CompanyProfile.objects.create(user=instance, **profile_data)
        return instance


# ---------------------------------------------------------------------------
# Applicant (CustomUser + ApplicantProfile) – admin review & backdoor create
# ---------------------------------------------------------------------------

class ApplicantProfileSerializer(serializers.ModelSerializer):
    """Profil pelamar (biodata, keluarga, verifikasi). referrer/verified_by = ID user Admin/Staff."""

    referrer = serializers.PrimaryKeyRelatedField(
        queryset=CustomUser.objects.none(),
        required=False,
        allow_null=True,
    )
    verified_by = serializers.PrimaryKeyRelatedField(
        queryset=CustomUser.objects.none(),
        required=False,
        allow_null=True,
    )

    class Meta:
        model = ApplicantProfile
        fields = [
            "id",
            "referrer",
            "full_name",
            "birth_place",
            "birth_date",
            "address",
            "contact_phone",
            "sibling_count",
            "birth_order",
            "father_name",
            "father_age",
            "father_occupation",
            "mother_name",
            "mother_age",
            "mother_occupation",
            "spouse_name",
            "spouse_age",
            "spouse_occupation",
            "family_address",
            "family_contact_phone",
            "nik",
            "gender",
            "photo",
            "notes",
            "verification_status",
            "submitted_at",
            "verified_at",
            "verified_by",
            "verification_notes",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Lazy queryset for referrer/verified_by (Admin/Staff only) to avoid import-time evaluation
        backoffice_qs = CustomUser.objects.filter(role__in=[UserRole.STAFF, UserRole.ADMIN])
        self.fields["referrer"].queryset = backoffice_qs
        self.fields["verified_by"].queryset = backoffice_qs
        if self.context.get("is_own_profile"):
            for f in ("referrer", "verified_by", "verification_status", "submitted_at", "verified_at", "verification_notes"):
                if f in self.fields:
                    self.fields[f].read_only = True

    def validate_nik(self, value):
        """Format 16 digit; uniqueness dicek di parent ApplicantUserSerializer (supaya punya akses profile instance)."""
        return validate_nik_format(value) if value else value


class ApplicantUserSerializer(serializers.ModelSerializer):
    """CRUD untuk pelamar: user + profil pelamar (nested). Admin review & backdoor create."""

    password = serializers.CharField(write_only=True, required=False, validators=[validate_password])
    applicant_profile = ApplicantProfileSerializer(required=False)

    class Meta:
        model = CustomUser
        fields = [
            "id",
            "email",
            "password",
            "is_active",
            "email_verified",
            "email_verified_at",
            "date_joined",
            "updated_at",
            "applicant_profile",
        ]
        read_only_fields = ["id", "email_verified_at", "date_joined", "updated_at"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if self.context.get("is_own_profile"):
            for f in ("is_active", "email_verified"):
                if f in self.fields:
                    self.fields[f].read_only = True

    def validate_email(self, value):
        return validate_email_unique(CustomUser, value, self.instance)

    def validate(self, attrs):
        """NIK uniqueness butuh profile instance (untuk update); dicek di sini."""
        profile_data = attrs.get("applicant_profile")
        if profile_data and profile_data.get("nik"):
            profile_instance = getattr(self.instance, "applicant_profile", None) if self.instance else None
            validate_nik_unique(profile_data["nik"], profile_instance)
        return attrs

    def create(self, validated_data):
        profile_data = validated_data.pop("applicant_profile", None)
        if not profile_data or not profile_data.get("full_name"):
            raise serializers.ValidationError({
                "applicant_profile": {"full_name": [ApiMessage.APPLICANT_FULL_NAME_REQUIRED]},
            })
        if not profile_data.get("nik"):
            raise serializers.ValidationError({
                "applicant_profile": {"nik": [ApiMessage.APPLICANT_NIK_REQUIRED]},
            })
        validate_nik_format(profile_data["nik"])
        if ApplicantProfile.objects.filter(nik=profile_data["nik"].strip()).exists():
            raise serializers.ValidationError({
                "applicant_profile": {"nik": [ApiMessage.NIK_TAKEN]},
            })
        password = validated_data.pop("password", None)
        if not password:
            raise serializers.ValidationError({
                "password": [ApiMessage.PASSWORD_REQUIRED_ON_CREATE],
            })
        user = CustomUser.objects.create_user(role=UserRole.APPLICANT, **validated_data)
        user.set_password(password)
        user.save(update_fields=["password"])
        ApplicantProfile.objects.create(user=user, **profile_data)
        return user

    def update(self, instance, validated_data):
        profile_data = validated_data.pop("applicant_profile", None)
        password = validated_data.pop("password", None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        if password is not None:
            instance.set_password(password)
        instance.save()
        if profile_data is not None:
            profile = getattr(instance, "applicant_profile", None)
            if profile:
                for attr, value in profile_data.items():
                    setattr(profile, attr, value)
                try:
                    profile.full_clean()
                except DjangoValidationError as e:
                    raise serializers.ValidationError(
                        e.message_dict if hasattr(e, "message_dict") else {"applicant_profile": e.messages}
                    )
                profile.save()
            else:
                ApplicantProfile.objects.create(user=instance, **profile_data)
        return instance


# ---------------------------------------------------------------------------
# WorkExperience (nested under applicant)
# ---------------------------------------------------------------------------

class WorkExperienceSerializer(serializers.ModelSerializer):
    """Pengalaman kerja per pelamar."""

    class Meta:
        model = WorkExperience
        fields = [
            "id",
            "company_name",
            "position",
            "start_date",
            "end_date",
            "still_employed",
            "description",
            "sort_order",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]


# ---------------------------------------------------------------------------
# ApplicantDocument (nested under applicant, file upload)
# ---------------------------------------------------------------------------

class ApplicantDocumentSerializer(serializers.ModelSerializer):
    """Dokumen pelamar (satu per tipe: KTP, ijasah, dll.). File + OCR fields read-only."""

    document_type = serializers.PrimaryKeyRelatedField(queryset=DocumentType.objects.all())

    class Meta:
        model = ApplicantDocument
        fields = [
            "id",
            "document_type",
            "file",
            "uploaded_at",
            "ocr_text",
            "ocr_data",
            "ocr_processed_at",
        ]
        read_only_fields = ["id", "uploaded_at", "ocr_text", "ocr_data", "ocr_processed_at"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Allow file and document_type to be optional on update (PATCH)
        if self.instance:
            self.fields["file"].required = False
            self.fields["document_type"].required = False


# ---------------------------------------------------------------------------
# DocumentType (read-only untuk dropdown / daftar tipe)
# ---------------------------------------------------------------------------

class DocumentTypeSerializer(serializers.ModelSerializer):
    """Tipe dokumen (read-only). Untuk dropdown di admin/frontend."""

    class Meta:
        model = DocumentType
        fields = ["id", "code", "name", "is_required", "sort_order", "description", "created_at"]
        read_only_fields = ["id", "code", "name", "is_required", "sort_order", "description", "created_at"]
