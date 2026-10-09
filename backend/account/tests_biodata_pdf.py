"""Biodata PDF pas foto must fill the printed frame, whatever the upload shape."""

from datetime import date
from io import BytesIO

from django.core.files.base import ContentFile
from django.test import TestCase
from PIL import Image

from account.models import (
    ApplicantDocument,
    ApplicantProfile,
    CustomUser,
    DocumentType,
    UserRole,
)
from account.services.biodata_pdf import (
    TEMPLATE_PATH,
    _PHOTO_BOX_PX,
    generate_biodata_pdf,
    photo_box_pt,
    photo_cover,
)


def _gray_frame_px(path: str) -> tuple[int, int, int, int]:
    """Outer gray pas-foto stroke on the biodata template: (x1, y1, x2, y2)."""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()

    def is_gray(rgb: tuple[int, int, int]) -> bool:
        r, g, b = rgb
        return abs(r - g) <= 12 and abs(g - b) <= 12 and 150 <= r <= 220

    x0, x1 = int(w * 0.68), int(w * 0.95)
    y0, y1 = int(h * 0.03), int(h * 0.28)
    rows = []
    for y in range(y0, y1):
        xs = [x for x in range(x0, x1) if is_gray(px[x, y])]
        if len(xs) > 200:
            rows.append(y)
    cols = []
    for x in range(x0, x1):
        ys = [y for y in range(y0, y1) if is_gray(px[x, y])]
        if len(ys) > 200:
            cols.append(x)
    return min(cols), min(rows), max(cols), max(rows)


class BiodataPhotoBoxTests(TestCase):
    def test_photo_box_stays_inside_template_frame(self):
        outer = _gray_frame_px(TEMPLATE_PATH)
        x1, y1, x2, y2 = _PHOTO_BOX_PX
        # Sit inside the stroke, with only a few pixels of inset.
        self.assertGreaterEqual(x1, outer[0])
        self.assertGreaterEqual(y1, outer[1])
        self.assertLessEqual(x2, outer[2])
        self.assertLessEqual(y2, outer[3])
        self.assertLessEqual(x1 - outer[0], 6)
        self.assertLessEqual(y1 - outer[1], 6)
        self.assertLessEqual(outer[2] - x2, 6)
        self.assertLessEqual(outer[3] - y2, 6)

        _x, _y, width, height = photo_box_pt()
        # The printed frame is nearly square. A hard-coded 3:4 well (92×115)
        # hangs out of that box.
        self.assertGreater(width / height, 0.85)
        self.assertLess(height, 100)

    def test_photo_cover_center_crops_non_portrait_uploads(self):
        _x, _y, width, height = photo_box_pt()
        src = Image.new("RGB", (300, 80), (0, 0, 255))
        src.paste(Image.new("RGB", (40, 80), (0, 180, 0)), (130, 0))
        buf = BytesIO()
        src.save(buf, format="JPEG")

        covered = Image.open(photo_cover(buf.getvalue(), width, height))
        self.assertEqual(covered.size, (max(32, int(width * 3)), max(32, int(height * 3))))
        # Center of a wide photo, not the left edge.
        r, g, b = covered.getpixel((covered.width // 2, covered.height // 2))
        self.assertGreater(g, r)
        self.assertGreater(g, b)

    def test_photo_cover_honors_exif_orientation(self):
        # Stored wide with a blue bottom half, tagged orientation 6 (90° CW).
        # After that rotation the blue half is on the left. Cover-crop must
        # use the displayed orientation, or the blue stays on the bottom.
        src = Image.new("RGB", (200, 60), (255, 0, 0))
        src.paste(Image.new("RGB", (200, 30), (0, 0, 255)), (0, 30))
        exif = src.getexif()
        exif[274] = 6
        buf = BytesIO()
        src.save(buf, format="JPEG", quality=95, exif=exif)

        covered = Image.open(photo_cover(buf.getvalue(), 80, 90))
        r, g, b = covered.getpixel((covered.width // 4, covered.height // 2))
        self.assertGreater(b, r + 40)

    def test_generate_biodata_pdf_clips_landscape_pas_foto(self):
        user = CustomUser.objects.create_user(
            email="biodataphoto@example.com",
            password="testpass123",
            role=UserRole.APPLICANT,
            full_name="Aginda Fratini",
            is_active=True,
            email_verified=True,
        )
        profile = ApplicantProfile.objects.create(
            user=user,
            contact_phone="081234567890",
            birth_place_text="DELI SERDANG",
            birth_date=date(2000, 4, 25),
            address="TANDEM HULU II",
        )
        doc_type, _ = DocumentType.objects.get_or_create(
            code="pas-foto",
            defaults={"name": "Pas Foto"},
        )
        wide = BytesIO()
        Image.new("RGB", (640, 200), (30, 90, 200)).save(wide, format="JPEG")
        doc = ApplicantDocument(applicant_profile=profile, document_type=doc_type)
        doc.file.save("pasfoto.jpg", ContentFile(wide.getvalue(), name="pasfoto.jpg"), save=True)

        pdf = generate_biodata_pdf(profile)
        self.assertTrue(pdf.startswith(b"%PDF"))
        self.assertIn(b"/XObject", pdf)
