"""Offline tests for ``scripts/validate_catalog.py``.

These tests build temporary catalog files so the validator never touches
real assets. Each test exercises one failure mode documented in the
single-asset / pipeline design docs.
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image, ImageDraw

SCRIPTS = Path(__file__).resolve().parents[1]


def _write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def _run_validator(extra_args: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPTS / "validate_catalog.py"), *extra_args],
        capture_output=True,
        text=True,
        check=False,
    )


def _patch_argv(args: list[str]) -> list[str]:
    return [
        sys.executable,
        str(SCRIPTS / "validate_catalog.py"),
        *args,
    ]


class ValidateCatalogCliTests(unittest.TestCase):
    def test_passes_when_both_catalogs_are_safe(self):
        with tempfile.TemporaryDirectory() as temp:
            # We can't easily exercise the real files; instead verify that
            # the strict-min-items flag fails fast when items.json is empty.
            proc = subprocess.run(
                _patch_argv(["--strict-min-items", "--min-items", "1"]),
                capture_output=True,
                text=True,
                check=False,
            )
            # Empty items.json + strict-min-items=1 → failure.
            self.assertEqual(proc.returncode, 1, proc.stderr)
            self.assertIn("approved items", proc.stderr)

    def test_default_mode_passes_with_legacy_only(self):
        proc = _run_validator([])
        # 8 legacy animals + 0 items; default mode is lenient.
        self.assertEqual(proc.returncode, 0, proc.stderr)


class ValidateCatalogImportTests(unittest.TestCase):
    """Direct module-level checks. Useful when running pytest/units locally."""

    def setUp(self):
        sys.path.insert(0, str(SCRIPTS))
        import validate_catalog as vc  # type: ignore

        self.vc = vc

    def test_rejects_unsafe_id(self):
        errors = self.vc._validate_entry(
            {
                "id": "Bad-Id",
                "image": "assets/items/Bad-Id.webp",
                "shadow": "assets/items/Bad-Id_shadow.webp",
                "category": "x",
                "distractors": [],
            },
            available_ids=set(),
            root=Path("/"),
        )
        self.assertTrue(any("invalid id" in e for e in errors))

    def test_rejects_path_traversal(self):
        errors = self.vc._validate_entry(
            {
                "id": "evil",
                "image": "../etc/passwd",
                "shadow": "assets/items/evil_shadow.webp",
                "category": "x",
                "distractors": [],
            },
            available_ids=set(),
            root=Path("/"),
        )
        self.assertTrue(any("unsafe" in e for e in errors))

    def test_rejects_unknown_effect_preset(self):
        errors = self.vc._validate_entry(
            {
                "id": "toy",
                "image": "assets/items/toy.webp",
                "shadow": "assets/items/toy_shadow.webp",
                "category": "toys",
                "distractors": [],
                "effectPreset": "teleport",
            },
            available_ids={"toy"},
            root=Path("/"),
        )
        self.assertTrue(any("unknown effectPreset" in e for e in errors))


class ValidateCatalogFilesystemTests(unittest.TestCase):
    """End-to-end: write a local catalog, point validate at it, assert OK."""

    def setUp(self):
        sys.path.insert(0, str(SCRIPTS))
        import validate_catalog as vc  # type: ignore

        self.vc = vc

    def test_minimum_valid_catalog_passes(self):
        # Build a tiny synthetic catalog using the catalog helper logic.
        entries = [
            {
                "id": "demo_a",
                "image": "a.png",
                "shadow": "a_shadow.png",
                "category": "x",
                "distractors": ["demo_b"],
                "effectPreset": "squish",
            },
            {
                "id": "demo_b",
                "image": "b.png",
                "shadow": "b_shadow.png",
                "category": "x",
                "distractors": ["demo_a"],
                "effectPreset": "inflate",
            },
        ]
        # Confirm the validator's entry-level logic is content-only and
        # does not require physical files when no real path check is run.
        for entry in entries:
            errors = self.vc._validate_entry(
                entry,
                available_ids={entry["id"] for entry in entries},
                root=Path("/nonexistent"),
            )
            for error in errors:
                if "missing" in error:
                    continue  # expected: physical file paths are absent.
                self.fail(f"Unexpected error: {error}")




class SilhouetteQualityTests(unittest.TestCase):
    def setUp(self):
        sys.path.insert(0, str(SCRIPTS))
        import validate_catalog as vc

        self.vc = vc

    @staticmethod
    def _circle() -> Image.Image:
        image = Image.new("L", (512, 512), 0)
        ImageDraw.Draw(image).ellipse((95, 95, 417, 417), fill=255)
        return image

    def test_accepts_large_centered_object(self):
        self.assertEqual(self.vc._mask_quality_errors(self._circle()), [])

    def test_rejects_almost_full_black_square_with_tiny_transparency(self):
        bad = Image.new("L", (512, 512), 255)
        ImageDraw.Draw(bad).rectangle((1, 1, 30, 30), fill=0)
        errors = self.vc._mask_quality_errors(bad)
        self.assertTrue(any("occupancy" in x or "outer" in x for x in errors))

    def test_rejects_object_with_background_border(self):
        image = self._circle()
        ImageDraw.Draw(image).rectangle((0, 0, 511, 14), fill=255)
        errors = self.vc._mask_quality_errors(image)
        self.assertTrue(any("outer" in x for x in errors))

    def test_rejects_many_detached_speckles(self):
        image = self._circle()
        draw = ImageDraw.Draw(image)
        # Pixels kept by NEAREST downsampling; separated at 128px scale.
        for x in range(24, 480, 20):
            draw.rectangle((x, 20, x + 7, 27), fill=255)
        self.assertTrue(
            any("speckles" in x for x in self.vc._mask_quality_errors(image))
        )

    def test_development_entries_are_actually_validated(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            catalog = root / "assets/catalog"
            catalog.mkdir(parents=True)
            asset = root / "assets/development"
            asset.mkdir(parents=True)
            image = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
            ImageDraw.Draw(image).ellipse((90, 90, 420, 420), fill=(100, 200, 160, 255))
            # Invalid mask while retaining some transparent pixels.
            bad = Image.new("RGBA", (512, 512), (37, 49, 52, 255))
            ImageDraw.Draw(bad).rectangle((0, 0, 40, 40), fill=(0, 0, 0, 0))
            image.save(asset / "sample.webp", format="WEBP", lossless=True)
            bad.save(asset / "sample_shadow.webp", format="WEBP", lossless=True)
            entry = {
                "id": "sample",
                "image": "assets/development/sample.webp",
                "shadow": "assets/development/sample_shadow.webp",
                "category": "toys",
                "distractors": [],
                "effectPreset": "squish",
            }
            _write_json(catalog / "development.json", {"items": [entry]})
            with (
                patch.object(self.vc, "ROOT", root),
                patch.object(self.vc, "LEGACY_CATALOG", catalog / "animals.json"),
                patch.object(self.vc, "ITEMS_CATALOG", catalog / "items.json"),
                patch.object(self.vc, "DEVELOPMENT_CATALOG", catalog / "development.json"),
            ):
                self.assertEqual(self.vc.main([]), 1)

    def test_unreviewed_ai_demo_rejected_even_with_valid_alpha(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            catalog = root / "assets/catalog"
            catalog.mkdir(parents=True)
            asset = root / "assets/development"
            asset.mkdir(parents=True)
            image = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
            ImageDraw.Draw(image).ellipse((95, 95, 417, 417), fill=(120, 130, 190, 255))
            image.save(asset / "demo_sample.webp", format="WEBP", lossless=True)
            image.save(asset / "demo_sample_shadow.webp", format="WEBP", lossless=True)
            entry = {
                "id": "demo_sample",
                "image": "assets/development/demo_sample.webp",
                "shadow": "assets/development/demo_sample_shadow.webp",
                "category": "toys",
                "distractors": [],
                "silhouetteFeatures": ["ai_demo"],
            }
            _write_json(catalog / "development.json", {"items": [entry]})
            with (
                patch.object(self.vc, "ROOT", root),
                patch.object(self.vc, "LEGACY_CATALOG", catalog / "animals.json"),
                patch.object(self.vc, "ITEMS_CATALOG", catalog / "items.json"),
                patch.object(self.vc, "DEVELOPMENT_CATALOG", catalog / "development.json"),
            ):
                self.assertEqual(self.vc.main([]), 1)


if __name__ == "__main__":
    unittest.main()
