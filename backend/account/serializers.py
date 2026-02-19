"""
Serializers for account API (admin-side CRUD: Admin, Staff, Company, Applicant).
- full_name on CustomUser; profile serializers use source="user.full_name".
- Region fields (province, district, village) are FK to regions app.
- WorkExperience.country uses CountryField (ISO 3166-1 alpha-2).
- Supports partial update (PATCH); error messages via api_responses.
"""
from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.utils import timezone

from .models import (
    CustomUser,
    UserRole,
    StaffProfile,
    CompanyProfile,
    ApplicantProfile,
    WorkExperience,
    DocumentType,
    ApplicantDocument,
    ApplicantVerificationStatus,
    DocumentReviewStatus,
    Broadcast,
    Notification,
    NotificationType,
    NotificationPriority,
)
from .api_responses import (
    ApiMessage,
    validate_email_unique,
    validate_nik_format,
    validate_nik_unique,
)
def _regency_queryset():
    from regions.models import Regency
    return Regency.objects.all()


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
            "full_name",
            "role",
            "password",
            "is_active",
            "email_verified",
            "email_verified_at",
            "date_joined",
            "last_login",
            "updated_at",
        ]
        read_only_fields = ["id", "role", "email_verified_at", "date_joined", "last_login", "updated_at"]
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
        validated_data.setdefault("is_active", True)
        validated_data.setdefault("email_verified", False)
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
    """Profil staf (nama dari user, telepon, foto)."""

    full_name = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=255,
        write_only=True,  # Only used for writing during create/update, not stored on StaffProfile
        help_text="Nama lengkap (disimpan pada CustomUser, bukan StaffProfile)",
    )

    class Meta:
        model = StaffProfile
        fields = ["id", "full_name", "contact_phone", "photo", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]
    
    def to_representation(self, instance):
        """When reading, get full_name from user.full_name."""
        ret = super().to_representation(instance)
        if instance and hasattr(instance, "user"):
            ret["full_name"] = instance.user.full_name
        return ret


class StaffUserSerializer(serializers.ModelSerializer):
    """CRUD untuk pengguna Staff: user + profil staf (nested)."""

    password = serializers.CharField(write_only=True, required=False, validators=[validate_password])
    staff_profile = StaffProfileSerializer(required=False)

    class Meta:
        model = CustomUser
        fields = [
            "id",
            "email",
            "role",
            "password",
            "is_active",
            "email_verified",
            "email_verified_at",
            "date_joined",
            "last_login",
            "updated_at",
            "referral_code",
            "google_id",
            "staff_profile",
        ]
        read_only_fields = ["id", "role", "email_verified_at", "date_joined", "last_login", "updated_at", "referral_code", "google_id"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if self.context.get("is_own_profile"):
            for f in ("is_active", "email_verified"):
                if f in self.fields:
                    self.fields[f].read_only = True
        # Make staff_profile required when creating
        if self.instance is None:  # Creating new instance
            self.fields["staff_profile"].required = True
            # Make full_name required in nested serializer when creating
            if "staff_profile" in self.fields:
                nested_serializer = self.fields["staff_profile"]
                if hasattr(nested_serializer, "fields") and "full_name" in nested_serializer.fields:
                    nested_serializer.fields["full_name"].required = True
                    nested_serializer.fields["full_name"].allow_blank = False

    def validate_email(self, value):
        return validate_email_unique(CustomUser, value, self.instance)

    def create(self, validated_data):
        profile_data = validated_data.pop("staff_profile", None)
        if not profile_data:
            raise serializers.ValidationError({
                "staff_profile": {"full_name": [ApiMessage.PROFILE_FULL_NAME_REQUIRED]},
            })
        full_name = profile_data.pop("full_name", "").strip()
        if not full_name:
            raise serializers.ValidationError({
                "staff_profile": {"full_name": [ApiMessage.PROFILE_FULL_NAME_REQUIRED]},
            })
        password = validated_data.pop("password", None)
        if not password or not password.strip():
            raise serializers.ValidationError({
                "password": [ApiMessage.PASSWORD_REQUIRED_ON_CREATE],
            })
        validated_data["full_name"] = full_name
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
            full_name = profile_data.pop("full_name", None)
            if full_name is not None:
                instance.full_name = full_name
                instance.save(update_fields=["full_name"])
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
            "role",
            "password",
            "is_active",
            "email_verified",
            "email_verified_at",
            "date_joined",
            "updated_at",
            "company_profile",
        ]
        read_only_fields = ["id", "role", "email_verified_at", "date_joined", "updated_at"]

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

class ReferrerListSerializer(serializers.ModelSerializer):
    """Minimal serializer for referrer dropdown (Staff + Admin users)."""

    class Meta:
        model = CustomUser
        fields = ["id", "full_name", "email", "referral_code"]


class ApplicantProfileSerializer(serializers.ModelSerializer):
    """Profil pelamar (biodata, keluarga, verifikasi). referrer/verified_by = ID user Admin/Staff."""

    village_display = serializers.SerializerMethodField(read_only=True)
    family_village_display = serializers.SerializerMethodField(read_only=True)
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

    full_name = serializers.CharField(
        source="user.full_name",
        required=False,
        allow_blank=True,
        max_length=255,
    )
    birth_place = serializers.PrimaryKeyRelatedField(
        queryset=_regency_queryset(),
        required=False,
        allow_null=True,
    )

    class Meta:
        model = ApplicantProfile
        fields = [
            "id",
            "referrer",
            "registration_date",
            "destination_country",
            "full_name",
            "birth_place",
            "birth_date",
            "address",
            "district",
            "province",
            "village",
            "village_display",
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
            "family_district",
            "family_province",
            "family_village",
            "family_village_display",
            "family_contact_phone",
            "data_declaration_confirmed",
            "zero_cost_understood",
            "nik",
            "gender",
            "religion",
            "education_level",
            "education_major",
            "height_cm",
            "weight_kg",
            "wears_glasses",
            "writing_hand",
            "marital_status",
            "has_passport",
            "passport_number",
            "passport_issue_date",
            "passport_issue_place",
            "passport_expiry_date",
            "family_card_number",
            "diploma_number",
            "bpjs_number",
            "shoe_size",
            "shirt_size",
            "photo",
            "notes",
            "verification_status",
            "submitted_at",
            "verified_at",
            "verified_by",
            "verification_notes",
            "score",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "score", "created_at", "updated_at"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Lazy queryset for referrer/verified_by (Admin/Staff only)
        backoffice_qs = CustomUser.objects.filter(role__in=[UserRole.STAFF, UserRole.ADMIN])
        self.fields["referrer"].queryset = backoffice_qs
        self.fields["verified_by"].queryset = backoffice_qs
        if self.context.get("is_own_profile"):
            for f in (
                "referrer",
                "verified_by",
                "verification_status",
                "submitted_at",
                "verified_at",
                "verification_notes",
            ):
                if f in self.fields:
                    self.fields[f].read_only = True

    @staticmethod
    def _build_region_hierarchy(province, district, village):
        """
        Build region display dict from province/district/village FKs.
        Hierarchy: Province <- Regency <- District (Kec) <- Village.
        """
        result = {}
        if province:
            result["province"] = province.name
        if district:
            result["regency"] = district.name
            if not result.get("province") and getattr(district, "province", None):
                result["province"] = district.province.name
        if village:
            result["village"] = village.name
            d = getattr(village, "district", None)
            if d:
                result["district"] = d.name
                regency = getattr(d, "regency", None)
                if regency:
                    if not result.get("regency"):
                        result["regency"] = regency.name
                    if not result.get("province") and getattr(regency, "province", None):
                        result["province"] = regency.province.name
        return result or None

    def get_village_display(self, obj):
        """Full hierarchy for KTP address: Province, Regency, District (Kecamatan), Village."""
        if not obj:
            return None
        return self._build_region_hierarchy(
            getattr(obj, "province", None) if obj.province_id else None,
            getattr(obj, "district", None) if obj.district_id else None,
            getattr(obj, "village", None) if obj.village_id else None,
        )

    def get_family_village_display(self, obj):
        """Full hierarchy for family address."""
        if not obj:
            return None
        return self._build_region_hierarchy(
            getattr(obj, "family_province", None) if obj.family_province_id else None,
            getattr(obj, "family_district", None) if obj.family_district_id else None,
            getattr(obj, "family_village", None) if obj.family_village_id else None,
        )

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
            "full_name",
            "role",
            "password",
            "is_active",
            "email_verified",
            "email_verified_at",
            "date_joined",
            "updated_at",
            "applicant_profile",
        ]
        read_only_fields = ["id", "role", "email_verified_at", "date_joined", "updated_at"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if self.context.get("is_own_profile"):
            for f in ("is_active", "email_verified"):
                if f in self.fields:
                    self.fields[f].read_only = True

    def validate_email(self, value):
        return validate_email_unique(CustomUser, value, self.instance)

    def validate(self, attrs):
        """
        Validasi tambahan pada level user + profil:
        - Uniqueness NIK (butuh instance profil untuk update)
        - Auto-set verified_by untuk status Diterima/Ditolak jika belum diisi
        """
        profile_data = attrs.get("applicant_profile")
        if profile_data:
            # NIK uniqueness
            if profile_data.get("nik"):
                profile_instance = (
                    getattr(self.instance, "applicant_profile", None)
                    if self.instance
                    else None
                )
                validate_nik_unique(profile_data["nik"], profile_instance)

            # Auto-fill verified_by when status becomes ACCEPTED/REJECTED
            status = profile_data.get("verification_status")
            if status in (
                ApplicantVerificationStatus.ACCEPTED,
                ApplicantVerificationStatus.REJECTED,
            ):
                # When moving to ACCEPTED, ensure all documents are approved
                if (
                    status == ApplicantVerificationStatus.ACCEPTED
                    and self.instance
                    and hasattr(self.instance, "applicant_profile")
                ):
                    profile_instance = self.instance.applicant_profile
                    docs_qs = ApplicantDocument.objects.filter(applicant_profile=profile_instance)
                    # If there are documents and any of them is not APPROVED, block acceptance
                    if docs_qs.exists() and docs_qs.exclude(
                        review_status=DocumentReviewStatus.APPROVED
                    ).exists():
                        raise serializers.ValidationError(
                            {
                                "applicant_profile": {
                                    "verification_status": [
                                        "Semua dokumen harus berstatus Diterima sebelum pelamar dapat diverifikasi."
                                    ]
                                }
                            }
                        )

                if not profile_data.get("verified_by"):
                    request = self.context.get("request")
                    user = getattr(request, "user", None)
                    # Hanya Admin/Staff yang boleh menjadi verified_by
                    if user and getattr(user, "is_authenticated", False) and user.role in (
                        UserRole.ADMIN,
                        UserRole.STAFF,
                    ):
                        # update() di ApplicantUserSerializer melakukan setattr(profile, attr, value)
                        # sehingga kita harus mengisi instance CustomUser, bukan PK saja.
                        profile_data["verified_by"] = user

        return attrs

    def create(self, validated_data):
        profile_data = validated_data.pop("applicant_profile", None)
        # full_name can be at top level (CustomUser) or nested in applicant_profile
        full_name = validated_data.pop("full_name", None) or (profile_data.pop("full_name", None) if profile_data else None)
        if not full_name or (isinstance(full_name, str) and not full_name.strip()):
            raise serializers.ValidationError({
                "full_name": [ApiMessage.APPLICANT_FULL_NAME_REQUIRED],
            })
        full_name = full_name.strip() if isinstance(full_name, str) else str(full_name)
        validated_data["full_name"] = full_name
        nik = profile_data.get("nik") if profile_data else None
        if not nik or (isinstance(nik, str) and not nik.strip()):
            raise serializers.ValidationError({
                "applicant_profile": {"nik": [ApiMessage.APPLICANT_NIK_REQUIRED]},
            })
        validate_nik_format(nik if isinstance(nik, str) else str(nik))
        nik_val = nik.strip() if isinstance(nik, str) else str(nik)
        if ApplicantProfile.objects.filter(nik=nik_val).exists():
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
        if profile_data:
            profile_data.pop("user", None)  # avoid duplicate with explicit user=user
            ApplicantProfile.objects.create(user=user, **profile_data)
        else:
            ApplicantProfile.objects.create(user=user)
        return user

    def update(self, instance, validated_data):
        profile_data = validated_data.pop("applicant_profile", None)
        password = validated_data.pop("password", None)
        
        # Handle full_name from top level or nested profile_data
        full_name = validated_data.pop("full_name", None) or (profile_data.pop("full_name", None) if profile_data else None)
        if full_name is not None:
            instance.full_name = full_name.strip() if isinstance(full_name, str) else str(full_name)

        # Update user fields
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        if password is not None:
            instance.set_password(password)
        instance.save()

        if profile_data is not None:
            # full_name with source="user.full_name" can appear as nested "user" in validated_data
            user_data = profile_data.pop("user", None)
            if isinstance(user_data, dict) and user_data.get("full_name") is not None:
                fn = user_data.get("full_name")
                instance.full_name = fn.strip() if isinstance(fn, str) else str(fn)
                instance.save(update_fields=["full_name"])

            profile = getattr(instance, "applicant_profile", None)
            if profile:
                # Capture previous status/timestamps to detect transitions
                old_status = profile.verification_status
                old_submitted_at = profile.submitted_at
                old_verified_at = profile.verified_at

                # Apply incoming profile changes (user is not on ApplicantProfile; already handled above)
                for attr, value in profile_data.items():
                    setattr(profile, attr, value)

                new_status = profile.verification_status

                # Auto-set submitted_at when first moved into SUBMITTED
                if (
                    new_status == ApplicantVerificationStatus.SUBMITTED
                    and old_status != ApplicantVerificationStatus.SUBMITTED
                    and not old_submitted_at
                    and not profile.submitted_at
                ):
                    profile.submitted_at = timezone.now()

                # Auto-set verified_at when first moved into ACCEPTED/REJECTED
                if (
                    new_status
                    in (ApplicantVerificationStatus.ACCEPTED, ApplicantVerificationStatus.REJECTED)
                    and not old_verified_at
                    and not profile.verified_at
                ):
                    profile.verified_at = timezone.now()

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
    """
    Pengalaman kerja per pelamar (aligned with FORM PRA SELEKSI).
    country: ISO 3166-1 alpha-2 (e.g. ID, MY) via CountryField.
    """

    class Meta:
        model = WorkExperience
        fields = [
            "id",
            "company_name",
            "location",
            "country",
            "industry_type",
            "position",
            "department",
            "start_date",
            "end_date",
            "still_employed",
            "description",
            "sort_order",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]
        extra_kwargs = {
            "country": {"allow_blank": True, "required": False},
        }

    def _validate_and_save(self, instance):
        """Run model validation and save. Raises ValidationError on invalid data."""
        try:
            instance.full_clean()
        except DjangoValidationError as e:
            raise serializers.ValidationError(
                e.message_dict if hasattr(e, "message_dict") else e.messages
            )
        instance.save()
        return instance

    def create(self, validated_data):
        instance = WorkExperience(**validated_data)
        return self._validate_and_save(instance)

    def update(self, instance, validated_data):
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        return self._validate_and_save(instance)


# ---------------------------------------------------------------------------
# ApplicantDocument (nested under applicant, file upload)
# ---------------------------------------------------------------------------

class ApplicantDocumentSerializer(serializers.ModelSerializer):
    """
    Dokumen pelamar (satu per tipe: KTP, ijasah, dll.).
    File + OCR fields read-only. Review fields writable by admin/staff.
    """

    document_type = serializers.PrimaryKeyRelatedField(queryset=DocumentType.objects.all())
    reviewed_by = serializers.PrimaryKeyRelatedField(
        queryset=CustomUser.objects.filter(role__in=[UserRole.STAFF, UserRole.ADMIN]),
        required=False,
        allow_null=True,
    )
    reviewed_by_name = serializers.SerializerMethodField(read_only=True)

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
            "review_status",
            "reviewed_by",
            "reviewed_at",
            "review_notes",
            "reviewed_by_name",
        ]
        read_only_fields = [
            "id",
            "uploaded_at",
            "ocr_text",
            "ocr_data",
            "ocr_processed_at",
            "reviewed_at",
        ]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Allow file and document_type to be optional on update (PATCH)
        if self.instance:
            self.fields["file"].required = False
            self.fields["document_type"].required = False

    def get_reviewed_by_name(self, obj) -> str | None:
        """
        Human-readable name for the reviewer (Admin/Staff) who changed the status.
        Prefer full_name, fallback to email.
        """
        user = getattr(obj, "reviewed_by", None)
        if not user:
            return None
        return user.full_name or user.email

    def validate(self, attrs):
        """
        Require review_notes when status is REJECTED.
        """
        # Only validate if review_status is being set to REJECTED
        if "review_status" in attrs and attrs["review_status"] == DocumentReviewStatus.REJECTED:
            review_notes = attrs.get("review_notes", "")
            # Check if notes are provided (either in attrs or already on instance)
            if not review_notes and (not self.instance or not self.instance.review_notes):
                raise serializers.ValidationError(
                    {
                        "review_notes": ["Catatan review wajib diisi ketika status ditolak."],
                    }
                )
        
        return attrs

    def update(self, instance, validated_data):
        """
        Update document with review fields.
        Auto-set reviewed_at and reviewed_by when status changes to APPROVED/REJECTED.
        """
        old_status = instance.review_status
        old_reviewed_at = instance.reviewed_at

        # Apply changes
        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        new_status = instance.review_status

        # Auto-set reviewed_at and reviewed_by when first approved/rejected
        if (
            new_status in (DocumentReviewStatus.APPROVED, DocumentReviewStatus.REJECTED)
            and old_status != new_status
            and not old_reviewed_at
        ):
            instance.reviewed_at = timezone.now()
            # Auto-set reviewed_by if not provided and request.user is available
            if not instance.reviewed_by:
                request = self.context.get("request")
                user = getattr(request, "user", None)
                if (
                    user
                    and getattr(user, "is_authenticated", False)
                    and user.role in (UserRole.ADMIN, UserRole.STAFF)
                ):
                    instance.reviewed_by = user

        # Reset reviewed_at if status goes back to PENDING
        if new_status == DocumentReviewStatus.PENDING and old_status != DocumentReviewStatus.PENDING:
            instance.reviewed_at = None
            instance.reviewed_by = None
            instance.review_notes = ""

        instance.save()
        return instance


# ---------------------------------------------------------------------------
# DocumentType (read-only untuk dropdown / daftar tipe)
# ---------------------------------------------------------------------------

class DocumentTypeSerializer(serializers.ModelSerializer):
    """Tipe dokumen (read-only). Untuk dropdown di admin/frontend."""

    class Meta:
        model = DocumentType
        fields = ["id", "code", "name", "is_required", "sort_order", "description", "created_at"]
        read_only_fields = ["id", "code", "name", "is_required", "sort_order", "description", "created_at"]


# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------

class NotificationSerializer(serializers.ModelSerializer):
    """Serializer untuk notifikasi individual."""

    class Meta:
        model = Notification
        fields = [
            "id",
            "title",
            "message",
            "notification_type",
            "priority",
            "action_url",
            "action_label",
            "is_read",
            "read_at",
            "created_at",
        ]
        read_only_fields = ["id", "is_read", "read_at", "created_at"]


class BroadcastSerializer(serializers.ModelSerializer):
    """Serializer untuk broadcast (create & list)."""
    
    created_by_name = serializers.CharField(source="created_by.full_name", read_only=True)
    recipient_count = serializers.SerializerMethodField()

    class Meta:
        model = Broadcast
        fields = [
            "id",
            "title",
            "message",
            "notification_type",
            "priority",
            "recipient_config",
            "send_email",
            "send_in_app",
            "created_by",
            "created_by_name",
            "scheduled_at",
            "sent_at",
            "total_recipients",
            "recipient_count",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "created_by",
            "created_by_name",
            "sent_at",
            "total_recipients",
            "recipient_count",
            "created_at",
            "updated_at",
        ]

    def get_recipient_count(self, obj) -> int:
        """Get recipient count (preview before sending)."""
        if obj.sent_at:
            return obj.total_recipients
        from .services.notification_recipients import get_recipient_count
        return get_recipient_count(obj.recipient_config)

    def validate(self, attrs):
        """Validate recipient_config and delivery options."""
        recipient_config = attrs.get("recipient_config", {})
        if recipient_config:
            from .services.notification_recipients import validate_recipient_config
            is_valid, error_msg = validate_recipient_config(recipient_config)
            if not is_valid:
                raise serializers.ValidationError({"recipient_config": error_msg})
        
        send_email = attrs.get("send_email", False)
        send_in_app = attrs.get("send_in_app", True)
        if not send_email and not send_in_app:
            raise serializers.ValidationError(
                "Pilih minimal satu metode pengiriman (send_email atau send_in_app)."
            )
        
        return attrs


class BroadcastCreateSerializer(BroadcastSerializer):
    """Serializer khusus untuk create broadcast (includes preview)."""
    
    preview_recipient_count = serializers.SerializerMethodField()

    class Meta(BroadcastSerializer.Meta):
        fields = BroadcastSerializer.Meta.fields + ["preview_recipient_count"]
        read_only_fields = BroadcastSerializer.Meta.read_only_fields + ["preview_recipient_count"]

    def get_preview_recipient_count(self, obj) -> int:
        """Get preview count from recipient_config."""
        if obj.pk:
            return self.get_recipient_count(obj)
        # For new objects, use data from validated_data
        recipient_config = self.validated_data.get("recipient_config", {})
        from .services.notification_recipients import get_recipient_count
        return get_recipient_count(recipient_config)
