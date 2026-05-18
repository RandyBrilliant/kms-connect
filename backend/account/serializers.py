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
    NextOfKinRelationship,
    DocumentType,
    ApplicantDocument,
    ApplicantVerificationStatus,
    DocumentReviewStatus,
    Broadcast,
    Notification,
    NotificationPreference,
    NotificationType,
    NotificationPriority,
    AccountDeletionRequest,
)
from .api_responses import (
    ApiMessage,
    validate_email_unique,
    validate_nik_format,
    validate_nik_unique,
)
from .validators import normalize_indonesian_phone


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
        # Admin accounts are always verified on creation
        validated_data["email_verified"] = True
        validated_data["email_verified_at"] = timezone.now()
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
    """Profil staf (nama dari user, telepon, NIK, foto, alamat)."""

    full_name = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=255,
        write_only=True,  # Only used for writing during create/update, not stored on StaffProfile
        help_text="Nama lengkap (disimpan pada CustomUser, bukan StaffProfile)",
    )

    class Meta:
        model = StaffProfile
        fields = ["id", "full_name", "contact_phone", "nik", "address", "photo", "created_at", "updated_at"]
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
            "apple_id",
            "staff_profile",
        ]
        read_only_fields = ["id", "role", "email_verified_at", "date_joined", "last_login", "updated_at", "referral_code", "google_id", "apple_id"]

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
        # Staff accounts are always verified on creation
        validated_data["email_verified"] = True
        validated_data["email_verified_at"] = timezone.now()
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
    """Profil perusahaan (nama perusahaan, contact person, telepon, alamat)."""

    class Meta:
        model = CompanyProfile
        fields = [
            "id",
            "company_name",
            "contact_person_name",
            "contact_person_position",
            "contact_phone",
            "address",
            "created_at",
            "updated_at",
        ]
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
        # Company accounts are always verified on creation
        validated_data["email_verified"] = True
        validated_data["email_verified_at"] = timezone.now()
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


# Applicant biodata string fields stored UPPERCASE (parity with mobile); exclude emails & phones.
_BIODATA_UPPER_STR_FIELDS = frozenset(
    {
        "birth_place_text",
        "address",
        "education_major",
        "passport_number",
        "passport_issue_place",
        "family_card_number",
        "diploma_number",
        "father_name",
        "father_occupation",
        "mother_name",
        "mother_occupation",
        "spouse_name",
        "spouse_occupation",
        "family_address",
        "heir_name",
        "notes",
        "hasil_medical",
        "disnaker",
        "no_sip",
        "no_jo",
        "bank",
        "no_rek",
        "no_calling_visa",
        "nik",
    }
)


def _staff_rujukan_display_name(*, full_name: str, email: str) -> str:
    """
    Label for daftar pelamar "Rujukan" column: DB full_name when set; otherwise a
    short name from the email local-part (not the full address, not referral_code).
    """
    raw = (full_name or "").strip()
    if raw:
        return raw
    em = (email or "").strip()
    if "@" in em:
        local = em.split("@", 1)[0].strip()
        if local:
            return " ".join(local.replace("_", " ").replace(".", " ").split()).title()
    return ""


class ReferrerListSerializer(serializers.ModelSerializer):
    """Minimal serializer for referrer dropdown (Staff users only)."""

    class Meta:
        model = CustomUser
        fields = ["id", "full_name", "email", "referral_code"]


class ApplicantProfileSerializer(serializers.ModelSerializer):
    """Profil pelamar (biodata, keluarga, verifikasi). referrer/verified_by = ID user Admin/Staff."""

    village_display = serializers.SerializerMethodField(read_only=True)
    family_village_display = serializers.SerializerMethodField(read_only=True)
    birth_place_display = serializers.SerializerMethodField(read_only=True)
    heir_relationship_display = serializers.SerializerMethodField(read_only=True)
    # Write-only field so applicants can set their referrer via code string
    referral_code_input = serializers.CharField(
        write_only=True,
        required=False,
        allow_blank=True,
        allow_null=True,
        label="Kode Rujukan",
    )
    referrer = serializers.PrimaryKeyRelatedField(
        queryset=CustomUser.objects.none(),
        required=False,
        allow_null=True,
    )
    # SerializerMethodField: nested serializer + same source as `referrer` did not reliably
    # appear in list/retrieve JSON in all DRF versions; explicit method is stable.
    referrer_display = serializers.SerializerMethodField(read_only=True)
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
    birth_place_text = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=200,
    )
    score_breakdown = serializers.SerializerMethodField(read_only=True)
    inbound_transport_stage_costs = serializers.ListField(
        child=serializers.DictField(),
        required=False,
        write_only=True,
    )
    jlh_uang_transport = serializers.SerializerMethodField(read_only=True)
    has_diterima_lamaran = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = ApplicantProfile
        fields = [
            "id",
            "referrer",
            "referrer_display",
            "referral_code_input",
            "registration_date",
            "destination_country",
            "full_name",
            "birth_place_text",
            "birth_place_display",
            "birth_date",
            "address",
            "postal_code",
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
            "father_phone",
            "father_almarhum",
            "mother_name",
            "mother_age",
            "mother_occupation",
            "mother_phone",
            "mother_almarhum",
            "spouse_name",
            "spouse_age",
            "spouse_occupation",
            "spouse_almarhum",
            "family_address",
            "family_postal_code",
            "family_district",
            "family_province",
            "family_village",
            "family_village_display",
            "heir_name",
            "heir_relationship",
            "heir_relationship_display",
            "heir_contact_phone",
            "data_declaration_confirmed",
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
            "tgl_medical",
            "hasil_medical",
            "tgl_bayar_sml",
            "tgl_fwcm_psikotes",
            "tgl_bayar_psikotes",
            "tgl_bayar_bpjs_pra",
            "tgl_bayar_bpjs_purna",
            "no_id_sisko",
            "disnaker",
            "no_sip",
            "no_jo",
            "biaya_ready_paspor",
            "pengembalian_biaya",
            "tgl_pengembalian",
            "jlh_uang_transport",
            "bank",
            "no_rek",
            "tanggal_pengembalian",
            "tgl_kirim_bio_ke_mly",
            "tgl_calling_visa",
            "no_calling_visa",
            "inbound_transport_stage_costs",
            "register_number",
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
            "score_breakdown",
            "has_diterima_lamaran",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "score",
            "score_breakdown",
            "register_number",
            "has_diterima_lamaran",
            "created_at",
            "updated_at",
        ]

    def get_heir_relationship_display(self, obj):
        if not obj.heir_relationship:
            return ""
        return NextOfKinRelationship(obj.heir_relationship).label if obj.heir_relationship in NextOfKinRelationship.values else obj.heir_relationship

    def get_referrer_display(self, obj):
        """Staff/admin perujuk: raw full_name + display_name for tables (never referral_code as name)."""
        if not obj or not getattr(obj, "referrer_id", None):
            return None
        ref = getattr(obj, "referrer", None)
        if ref is None:
            return None
        raw_name = (getattr(ref, "full_name", None) or "").strip()
        email = getattr(ref, "email", None) or ""
        return {
            "id": ref.pk,
            "full_name": raw_name,
            "display_name": _staff_rujukan_display_name(full_name=raw_name, email=email),
            "email": email,
            "referral_code": ref.referral_code,
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Lazy queryset for referrer (staff-only) and verified_by (Admin/Staff)
        backoffice_qs = CustomUser.objects.filter(
            role__in=[UserRole.STAFF, UserRole.MASTER_ADMIN, UserRole.ADMIN]
        )
        self.fields["referrer"].queryset = CustomUser.objects.filter(
            role=UserRole.STAFF
        )
        self.fields["verified_by"].queryset = backoffice_qs
        if not self.context.get("is_own_profile"):
            self.fields.pop("has_diterima_lamaran", None)
        if self.context.get("is_own_profile"):
            for f in (
                "referrer",
                "verified_by",
                "verification_status",
                "submitted_at",
                "verified_at",
                "verification_notes",
                # Admin-only process & finance fields should not be editable by applicant
                "tgl_medical",
                "hasil_medical",
                "tgl_bayar_sml",
                "tgl_fwcm_psikotes",
                "tgl_bayar_psikotes",
                "tgl_bayar_bpjs_pra",
                "tgl_bayar_bpjs_purna",
                "no_id_sisko",
                "disnaker",
                "no_sip",
                "no_jo",
                "biaya_ready_paspor",
                "pengembalian_biaya",
                "tgl_pengembalian",
                "bank",
                "no_rek",
                "tanggal_pengembalian",
                "tgl_kirim_bio_ke_mly",
                "tgl_calling_visa",
                "no_calling_visa",
            ):
                if f in self.fields:
                    self.fields[f].read_only = True
            self.fields.pop("inbound_transport_stage_costs", None)

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        if instance is not None and getattr(instance, "pk", None):
            from .services.inbound_transport_costs import (
                merged_inbound_transport_stage_costs_for_profile,
            )

            ret["inbound_transport_stage_costs"] = (
                merged_inbound_transport_stage_costs_for_profile(instance)
            )
        else:
            ret["inbound_transport_stage_costs"] = []
        return ret

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

    def get_birth_place_display(self, obj):
        """Primary: birth_place_text; legacy fallback if FK still present."""
        if not obj:
            return None
        t = (getattr(obj, "birth_place_text", None) or "").strip()
        if t:
            return t
        bp = getattr(obj, "birth_place", None)
        return bp.name if bp else None

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

    def get_score_breakdown(self, obj):
        """
        Expose the model's score_breakdown property as-is.

        This keeps the serializer thin and lets the model/service decide what
        to include. Safe to use for admin/frontend display only.
        """
        if not obj:
            return None
        return getattr(obj, "score_breakdown", {}) or {}

    def get_jlh_uang_transport(self, obj):
        """Total Rp from inbound stage rows (not a DB column)."""
        if not obj or not getattr(obj, "pk", None):
            return None
        v = getattr(obj, "jlh_uang_transport", None)
        if v is None:
            return None
        return float(v)

    def get_has_diterima_lamaran(self, obj):
        """True if this applicant has at least one lamaran in status DITERIMA."""
        if not obj or not getattr(obj, "pk", None):
            return False
        from main.models import ApplicationStatus, JobApplication

        return JobApplication.objects.filter(
            applicant_id=obj.pk,
            status=ApplicationStatus.DITERIMA,
        ).exists()

    def validate_contact_phone(self, value):
        return normalize_indonesian_phone(value) if value else value

    def validate_father_phone(self, value):
        return normalize_indonesian_phone(value) if value else value

    def validate_mother_phone(self, value):
        return normalize_indonesian_phone(value) if value else value

    def validate_heir_contact_phone(self, value):
        return normalize_indonesian_phone(value) if value else value

    def validate(self, attrs):
        attrs = super().validate(attrs)
        for key in _BIODATA_UPPER_STR_FIELDS:
            if key not in attrs:
                continue
            val = attrs[key]
            if val is None:
                continue
            if isinstance(val, str):
                attrs[key] = val.strip().upper()
        # Pelamar mengubah profil sendiri (mobile self-service / PATCH me): tidak boleh
        # mengatur staff rujukan lewat kode — hanya petugas/backoffice.
        if self.context.get("is_own_profile"):
            raw = attrs.get("referral_code_input")
            if raw is not None and str(raw).strip():
                raise serializers.ValidationError(
                    {
                        "referral_code_input": "Staff rujukan hanya dapat diatur oleh petugas atau admin.",
                    }
                )

        # Passport dates (supports partial PATCH — merge with existing instance).
        instance = getattr(self, "instance", None)
        issue = attrs.get(
            "passport_issue_date",
            getattr(instance, "passport_issue_date", None) if instance else None,
        )
        expiry = attrs.get(
            "passport_expiry_date",
            getattr(instance, "passport_expiry_date", None) if instance else None,
        )
        if issue and expiry and expiry <= issue:
            raise serializers.ValidationError(
                {
                    "passport_expiry_date": (
                        "Tanggal berakhir paspor harus setelah tanggal terbit paspor."
                    ),
                }
            )
        return attrs

    def validate_nik(self, value):
        """Format 16 digit; uniqueness dicek di parent ApplicantUserSerializer (supaya punya akses profile instance)."""
        return validate_nik_format(value) if value else value

    def validate_hasil_medical(self, value):
        raw = (value or "").strip()
        if not raw:
            return ""
        normalized = raw.upper()
        allowed = {"FIT", "UNFIT"}
        if normalized not in allowed:
            raise serializers.ValidationError("Hasil medical harus FIT atau UNFIT.")
        return normalized

    def validate_inbound_transport_stage_costs(self, value):
        if not value:
            return value
        from account.inbound_transport_stages import INBOUND_TRANSPORT_STAGE_CODES

        if not isinstance(value, list):
            raise serializers.ValidationError("Harus berupa array.")
        for item in value:
            if not isinstance(item, dict):
                raise serializers.ValidationError("Setiap item harus berupa object.")
            code = item.get("stage_code")
            if code not in INBOUND_TRANSPORT_STAGE_CODES:
                raise serializers.ValidationError(
                    f"Kode stage_code tidak valid: {code!r}"
                )
        return value

    def update(self, instance, validated_data):
        """
        Update ApplicantProfile. full_name (source='user.full_name') arrives as
        validated_data['user']['full_name'] — we extract it and save it to the
        related CustomUser so the change actually persists.
        Also handles referral_code_input → resolves to referrer FK.
        """
        # Resolve referral_code_input to a referrer FK if provided
        referral_code_input = validated_data.pop("referral_code_input", None)
        if referral_code_input:
            code = referral_code_input.strip().upper()
            try:
                referrer_user = CustomUser.objects.get(
                    referral_code=code,
                    role=UserRole.STAFF,
                    is_active=True,
                )
                validated_data["referrer"] = referrer_user
            except CustomUser.DoesNotExist:
                raise serializers.ValidationError(
                    {"referral_code_input": "Kode rujukan tidak valid atau tidak aktif."}
                )

        # Extract full_name from the nested 'user' dict that DRF builds for source="user.full_name"
        user_data = validated_data.pop("user", None)
        full_name = user_data.get("full_name") if isinstance(user_data, dict) else None

        if full_name is not None:
            stripped = full_name.strip()
            if stripped:
                instance.user.full_name = stripped.upper()
                instance.user.save(update_fields=["full_name"])

        # Single source of truth: text tempat lahir replaces legacy Regency FK.
        if "birth_place_text" in validated_data:
            validated_data["birth_place"] = None

        inbound_payload = validated_data.pop("inbound_transport_stage_costs", None)

        # Update all remaining profile fields normally
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        if inbound_payload is not None:
            from .services.inbound_transport_costs import upsert_inbound_transport_stage_costs

            upsert_inbound_transport_stage_costs(instance, inbound_payload)

        return instance


# Admin-only process & finance fields (same set as ApplicantAdminProcessTab / mobile).
# When a PATCH only touches these keys, skip ApplicantProfile.full_clean() so unrelated
# model.clean() rules (e.g. age 18–45) do not block saving medical / visa progress.
_ADMIN_PROCESS_PROFILE_FIELDS = frozenset(
    {
        "tgl_medical",
        "hasil_medical",
        "tgl_bayar_sml",
        "tgl_fwcm_psikotes",
        "tgl_bayar_psikotes",
        "tgl_bayar_bpjs_pra",
        "tgl_bayar_bpjs_purna",
        "no_id_sisko",
        "disnaker",
        "no_sip",
        "no_jo",
        "biaya_ready_paspor",
        "pengembalian_biaya",
        "tgl_pengembalian",
        "bank",
        "no_rek",
        "tanggal_pengembalian",
        "tgl_kirim_bio_ke_mly",
        "tgl_calling_visa",
        "no_calling_visa",
        "inbound_transport_stage_costs",
    }
)


class BulkAdminProcessSerializer(serializers.Serializer):
    """
    Bulk-update admin-only process fields on ApplicantProfile for multiple pelamar.
    Keys present in the request body are applied (PATCH semantics); omitted keys unchanged.
    """

    applicant_user_ids = serializers.ListField(
        child=serializers.IntegerField(min_value=1),
        min_length=1,
        max_length=500,
    )
    tgl_medical = serializers.DateField(required=False, allow_null=True)
    hasil_medical = serializers.CharField(required=False, allow_blank=True, max_length=255)
    tgl_bayar_sml = serializers.DateField(required=False, allow_null=True)
    tgl_fwcm_psikotes = serializers.DateField(required=False, allow_null=True)
    tgl_bayar_psikotes = serializers.DateField(required=False, allow_null=True)

    def validate_applicant_user_ids(self, value):
        if len(value) != len(set(value)):
            raise serializers.ValidationError("Terdapat ID pelamar duplikat.")
        return value

    def validate(self, attrs):
        raw = self.initial_data
        if not isinstance(raw, dict):
            return attrs
        allowed = (
            "tgl_medical",
            "hasil_medical",
            "tgl_bayar_sml",
            "tgl_fwcm_psikotes",
            "tgl_bayar_psikotes",
        )
        if not any(k in raw for k in allowed):
            raise serializers.ValidationError(
                "Minimal satu field proses (medical, SML, FWCMS/psikotes, dll.) wajib dikirim."
            )
        return attrs


class ApplicantUserSerializer(serializers.ModelSerializer):
    """CRUD untuk pelamar: user + profil pelamar (nested). Admin review & backdoor create."""

    password = serializers.CharField(write_only=True, required=False, validators=[validate_password])
    applicant_profile = ApplicantProfileSerializer(required=False)
    # Optional summary of applications for staff/company views.
    applications_summary = serializers.SerializerMethodField(read_only=True)

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
            "google_id",
            "apple_id",
            "applicant_profile",
            "applications_summary",
        ]
        read_only_fields = [
            "id",
            "role",
            "email_verified_at",
            "date_joined",
            "updated_at",
            "google_id",
            "apple_id",
        ]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # PATCH on the user must partially validate nested profile; DRF does not
        # propagate partial=True to nested serializers by default, which makes every
        # required ApplicantProfile field appear missing → 400 on small updates.
        if self.partial:
            nested = self.fields.get("applicant_profile")
            if nested is not None:
                nested.partial = True
        if self.context.get("is_own_profile"):
            for f in ("is_active", "email_verified"):
                if f in self.fields:
                    self.fields[f].read_only = True

        # For non-staff backoffice views, hide the optional applications summary
        # to avoid extra queries where it isn't needed.
        request = self.context.get("request")
        view = self.context.get("view")
        view_name = getattr(view, "__class__", type("V",(object,),{})).__name__
        is_staff_referral_view = view_name == "StaffReferredApplicantsViewSet"
        is_company_view = bool(view_name and view_name.startswith("Company"))
        include_summary = bool(self.context.get("include_applications_summary"))
        if not (is_staff_referral_view or is_company_view or include_summary):
            self.fields.pop("applications_summary", None)

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
                        UserRole.MASTER_ADMIN,
                        UserRole.ADMIN,
                        UserRole.STAFF,
                    ):
                        # update() di ApplicantUserSerializer melakukan setattr(profile, attr, value)
                        # sehingga kita harus mengisi instance CustomUser, bukan PK saja.
                        profile_data["verified_by"] = user

        return attrs

    def get_applications_summary(self, obj):
        """
        Lightweight summary of this applicant's job applications, used for
        STAFF views so they can see which job/batch/stage their referrals are in.
        """
        profile = getattr(obj, "applicant_profile", None)
        if profile is None:
            return []

        from main.models import ApplicationStatus, JobApplication
        from main.services import ApplicationService

        step_labels = dict(ApplicationService.DOCUMENT_COLLECTION_STEP_ORDER)

        # Limit to a few most-recent applications to keep payload small.
        prefetched = getattr(profile, "_job_apps_summary_prefetch", None)
        if prefetched is None:
            apps = list(
                JobApplication.objects.filter(applicant=profile)
                .select_related("job", "job__company", "batch", "interview_cohort")
                .order_by("-applied_at")[:5]
            )
        else:
            apps = list(prefetched)[:5]

        out = []
        for app in apps:
            try:
                status_label = ApplicationStatus(app.status).label
            except Exception:
                status_label = app.status
            cohort = getattr(app, "interview_cohort", None)
            interview_cohort_name = (
                (getattr(cohort, "name", None) or "").strip() if cohort is not None else ""
            )
            batch = getattr(app, "batch", None)
            batch_name = (getattr(batch, "name", None) or "").strip() if batch is not None else ""
            batch_tahap_label = ""
            if batch is not None:
                batch_tahap_label = (batch.display_tahap_label or "").strip()
            diterima_code = getattr(app, "diterima_current_step", None) or None
            diterima_sub_stage_label = None
            if app.status == ApplicationStatus.DITERIMA and diterima_code:
                diterima_sub_stage_label = step_labels.get(diterima_code, diterima_code)
            out.append(
                {
                    "id": app.id,
                    "status": app.status,
                    "status_label": status_label,
                    "job_id": app.job_id,
                    "job_title": getattr(app.job, "title", "") or "",
                    "batch_id": app.batch_id,
                    "batch_name": batch_name,
                    "batch_tahap_label": batch_tahap_label,
                    "interview_cohort_id": app.interview_cohort_id,
                    "interview_cohort_name": interview_cohort_name,
                    "diterima_current_step": diterima_code
                    if app.status == ApplicationStatus.DITERIMA
                    else None,
                    "diterima_sub_stage_label": diterima_sub_stage_label,
                }
            )
        return out

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
            inbound_c = profile_data.pop("inbound_transport_stage_costs", None)
            profile_data.setdefault("verification_status", ApplicantVerificationStatus.SUBMITTED)
            profile_data.setdefault("submitted_at", timezone.now())
            prof = ApplicantProfile.objects.create(user=user, **profile_data)
            if inbound_c:
                from .services.inbound_transport_costs import upsert_inbound_transport_stage_costs

                upsert_inbound_transport_stage_costs(prof, inbound_c)
        else:
            ApplicantProfile.objects.create(
                user=user,
                verification_status=ApplicantVerificationStatus.SUBMITTED,
                submitted_at=timezone.now(),
            )
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
                profile_keys = set(profile_data.keys())
                inbound_c = profile_data.pop("inbound_transport_stage_costs", None)
                skip_profile_full_clean = bool(profile_keys) and profile_keys.issubset(
                    _ADMIN_PROCESS_PROFILE_FIELDS
                )

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

                if not skip_profile_full_clean:
                    try:
                        profile.full_clean()
                    except DjangoValidationError as e:
                        raise serializers.ValidationError(
                            e.message_dict
                            if hasattr(e, "message_dict")
                            else {"applicant_profile": e.messages}
                        )
                profile.save()
                req_user = getattr(self.context.get("request"), "user", None)
                if inbound_c is not None:
                    from .services.inbound_transport_costs import upsert_inbound_transport_stage_costs

                    try:
                        upsert_inbound_transport_stage_costs(profile, inbound_c)
                    except ValueError as e:
                        raise serializers.ValidationError(
                            {"applicant_profile": {"inbound_transport_stage_costs": [str(e)]}}
                        )
                self._sync_medical_unfit_application(profile=profile, actor=req_user)
            else:
                inbound_c = profile_data.pop("inbound_transport_stage_costs", None)
                prof = ApplicantProfile.objects.create(user=instance, **profile_data)
                if inbound_c:
                    from .services.inbound_transport_costs import upsert_inbound_transport_stage_costs

                    upsert_inbound_transport_stage_costs(prof, inbound_c)
        return instance

    def _sync_medical_unfit_application(self, *, profile: ApplicantProfile, actor: CustomUser | None) -> None:
        """
        Auto-reject active DITERIMA application when medical result is UNFIT.
        """
        if (getattr(profile, "hasil_medical", "") or "").strip().upper() != "UNFIT":
            return

        from main.models import ApplicationStatus, JobApplication
        from main.services import ApplicationService, TransitionError

        app = (
            JobApplication.objects
            .filter(applicant=profile, status=ApplicationStatus.DITERIMA)
            .order_by("-updated_at")
            .first()
        )
        if not app or actor is None:
            return
        try:
            ApplicationService.transition(
                application=app,
                new_status=ApplicationStatus.DITOLAK,
                actor=actor,
                note="MEDICAL UNFIT",
            )
        except TransitionError:
            # Keep profile update successful even if transition is not allowed.
            return


# ---------------------------------------------------------------------------
# WorkExperience (nested under applicant)
# ---------------------------------------------------------------------------

class WorkExperienceSerializer(serializers.ModelSerializer):
    """
    Pengalaman kerja per pelamar (aligned with FORM PRA SELEKSI).
    country: ISO 3166-1 alpha-2 (e.g. ID, MY) via CountryField.
    We override country as a plain CharField so DRF doesn't try to JSON-serialize
    the Country object returned by django-countries.
    Max 2 entries per applicant (enforced at create time).
    """

    # Override CountryField → plain CharField so serialisation returns a string code.
    country = serializers.CharField(max_length=2, allow_blank=True, required=False, default="")

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

    def to_representation(self, instance):
        data = super().to_representation(instance)
        # django-countries stores an alpha-2 code but the attribute returns a Country
        # object whose str() gives the *display name* — we always want the code.
        raw = getattr(instance, "country", None)
        if raw:
            data["country"] = raw.code if hasattr(raw, "code") else str(raw)
        else:
            data["country"] = ""
        return data

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

    def validate(self, attrs):
        """Enforce max 2 work experiences per applicant (only on create)."""
        # self.instance is None during create, set during update
        if self.instance is None:
            # applicant_profile is injected via perform_create(serializer.save(applicant_profile=...))
            # It will be available in the view context; we check via the request context if possible.
            # The actual limit check happens in perform_create of the viewset.
            # We also expose it here for direct serializer usage.
            request = self.context.get("request")
            applicant_profile = self.context.get("applicant_profile")
            if applicant_profile is not None:
                existing_count = WorkExperience.objects.filter(
                    applicant_profile=applicant_profile
                ).count()
                if existing_count >= 2:
                    raise serializers.ValidationError(
                        {"non_field_errors": [ApiMessage.WORK_EXPERIENCE_LIMIT]}
                    )
        return attrs

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
        queryset=CustomUser.objects.filter(
            role__in=[UserRole.STAFF, UserRole.MASTER_ADMIN, UserRole.ADMIN]
        ),
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
                    and user.role
                    in (UserRole.MASTER_ADMIN, UserRole.ADMIN, UserRole.STAFF)
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
        fields = ["id", "code", "name", "is_required", "sort_order", "description", "phase", "created_at"]
        read_only_fields = ["id", "code", "name", "is_required", "sort_order", "description", "phase", "created_at"]


# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------

class NotificationSerializer(serializers.ModelSerializer):
    """Serializer untuk notifikasi individual."""

    created_at = serializers.SerializerMethodField()
    read_at = serializers.SerializerMethodField()

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

    def _to_jakarta_iso(self, value):
        """Serialize datetime in explicit Asia/Jakarta offset format."""
        if value is None:
            return None
        dt = value
        if timezone.is_naive(dt):
            dt = timezone.make_aware(dt, timezone.get_default_timezone())
        return timezone.localtime(dt).isoformat()

    def get_created_at(self, obj):
        return self._to_jakarta_iso(obj.created_at)

    def get_read_at(self, obj):
        return self._to_jakarta_iso(obj.read_at)


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
            "send_push",
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
        send_push = attrs.get("send_push", False)
        if not send_email and not send_in_app and not send_push:
            raise serializers.ValidationError(
                "Pilih minimal satu metode pengiriman (send_email, send_in_app, atau send_push)."
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


# ---------------------------------------------------------------------------
# Notification Preference Serializer
# ---------------------------------------------------------------------------

class NotificationPreferenceSerializer(serializers.ModelSerializer):
    """
    Read/update per-user notification preferences.
    Only the preference flags are writable; ``user`` and timestamps are read-only.

    Used by:
      GET  /api/me/notification-preferences/  → retrieve own preferences
      PATCH /api/me/notification-preferences/ → partial update
    """

    class Meta:
        model = NotificationPreference
        fields = [
            "id",
            # In-app
            "inapp_enabled",
            # Email
            "email_account_updates",
            "email_profile_updates",
            "email_application_updates",
            "email_job_deadline_reminder",
            "email_batch_departure_reminder",
            "email_job_alerts",
            # Push
            "push_enabled",
            "push_chat_messages",
            "push_application_updates",
            # Timestamps (read-only)
            "updated_at",
        ]
        read_only_fields = ["id", "updated_at"]


# ---------------------------------------------------------------------------
# Account Deletion Request
# ---------------------------------------------------------------------------

class AccountDeletionRequestSerializer(serializers.ModelSerializer):
    """
    Serializer for AccountDeletionRequest.

    - Applicants: create (POST) and read their own request; can cancel via action.
    - Admins: read list, retrieve, approve/reject with admin_notes.
    """

    user_email = serializers.EmailField(source="user.email", read_only=True)
    user_full_name = serializers.CharField(source="user.full_name", read_only=True)
    user_role = serializers.CharField(source="user.role", read_only=True)
    user_is_active = serializers.BooleanField(source="user.is_active", read_only=True)
    reviewed_by_email = serializers.EmailField(source="reviewed_by.email", read_only=True, default=None)

    class Meta:
        model = AccountDeletionRequest
        fields = [
            "id",
            "user",
            "user_email",
            "user_full_name",
            "user_role",
            "user_is_active",
            "reason",
            "status",
            "requested_at",
            "reviewed_at",
            "reviewed_by",
            "reviewed_by_email",
            "admin_notes",
        ]
        read_only_fields = [
            "id",
            "user",
            "user_email",
            "user_full_name",
            "user_role",
            "user_is_active",
            "status",
            "requested_at",
            "reviewed_at",
            "reviewed_by",
            "reviewed_by_email",
        ]

    def validate(self, attrs):
        # Admin-only fields must not be set by applicants
        request = self.context.get("request")
        if request and request.user.role not in (
            UserRole.MASTER_ADMIN,
            UserRole.ADMIN,
        ):
            attrs.pop("admin_notes", None)
        return attrs
