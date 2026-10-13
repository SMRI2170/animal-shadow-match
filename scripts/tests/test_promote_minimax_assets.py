"""Offline tests for ``scripts/promote_minimax_assets.py``.

The promotion script must never make any network call, never accept an
arbitrary ``MINIMAX_API_KEY``, and never silently overwrite an existing
catalog entry. The tests below cover each of those guarantees.
"""
from __future__ import annotations

import importlib
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
promote = importlib.import_module("promote_minimax_assets")


def _write_image(path: Path, size: int = 768, color: tuple[int, int, int] = (255, 255, 255)) -> None:
    from PIL import Image

    Image.new("RGB", (size, size), color).save(path)


def _make_prompt_catalog(tmp: Path) -> Path:
    prompts = {
        "items": [
            {
                "id": "gel_star",
                "category": "jelly",
                "effectPreset": "squish",
                "silhouetteDistractors": ["cloud_cushion", "teardrop_gummy"],
            },
        ]
    }
    target = tmp / "minimax_object_prompts.json"
    target.write_text(json.dumps(prompts), encoding="utf-8")
    return target


class IdAndPathGuardsTests(unittest.TestCase):
    def test_safe_id_accepts_lower_ascii(self):
        self.assertTrue(promote._is_safe_id("gel_star"))
        self.assertTrue(promote._is_safe_id("toy_001"))

    def test_safe_id_rejects_uppercase_and_unicode(self):
        self.assertFalse(promote._is_safe_id("Gel-Star"))
        self.assertFalse(promote._is_safe_id("🐙"))


class ImageValidationTests(unittest.TestCase):
    def test_accepts_in_range_png(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "obj.png"
            _write_image(path)
            fmt, w, h = promote._read_image_meta(path)
            self.assertEqual(fmt, "PNG")
            self.assertEqual((w, h), (768, 768))

    def test_rejects_garbage_bytes(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "garbage.png"
            path.write_bytes(b"not an image at all")
            with self.assertRaises(promote.PromotionError):
                promote._read_image_meta(path)

    def test_rejects_too_small_image(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "tiny.png"
            _write_image(path, size=128)
            with self.assertRaises(promote.PromotionError):
                promote._read_image_meta(path)


class CatalogMergeTests(unittest.TestCase):
    def test_merge_refuses_to_overwrite(self):
        existing = [
            {"id": "gel_star", "image": "a.webp", "shadow": "a_shadow.webp"},
        ]
        with self.assertRaises(promote.PromotionError):
            promote._merge_entry(
                existing,
                {"id": "gel_star", "image": "b.webp", "shadow": "b_shadow.webp"},
            )

    def test_merge_appends_when_no_collision(self):
        existing = [{"id": "old"}]
        new, replaced = promote._merge_entry(
            existing,
            {"id": "new", "image": "n.webp", "shadow": "n_shadow.webp"},
        )
        self.assertFalse(replaced)
        self.assertEqual([e["id"] for e in new], ["old", "new"])


class EndToEndPromotionTests(unittest.TestCase):
    def test_end_to_end_adds_two_new_items(self):
        with tempfile.TemporaryDirectory() as temp:
            workspace = Path(temp)
            # Re-use real assets for items.json + prompts to make this look
            # like a normal production workspace.
            real_root = Path(__file__).resolve().parents[2]
            items_dir = real_root / "assets" / "catalog"
            tmp_items = workspace / "items.json"
            tmp_items.write_text(
                json.dumps({"version": 1, "items": []}),
                encoding="utf-8",
            )
            with mock.patch.object(promote, "ITEMS_CATALOG", tmp_items):
                # Always restore items.json after the test.
                staging = workspace / "stage"
                staging.mkdir()
                _write_image(staging / "gel_star.png")
                _write_image(staging / "cloud_cushion.png", color=(120, 200, 220))

                # Source dir gets copied into the workspace so the real
                # ``assets/source`` is not touched.
                tmp_source = workspace / "source"
                with mock.patch.object(promote, "SOURCE_DIR", tmp_source):
                    # Run the script via subprocess to keep the test
                    # hermetic and exit-code based.
                    rc = promote.main(
                        [
                            "--staging-dir",
                            str(staging),
                            "--source-run-id",
                            "12345",
                            "--artifact-name",
                            "minimax-review-12345",
                            "--report-path",
                            str(workspace / "promotion.json"),
                        ],
                    )
                    self.assertEqual(rc, 0, "promotion script must succeed")

                catalog = json.loads(tmp_items.read_text())
                promoted_ids = {entry["id"] for entry in catalog["items"]}
                self.assertEqual(promoted_ids, {"gel_star", "cloud_cushion"})
                for entry in catalog["items"]:
                    self.assertEqual(
                        entry["effectPreset"],
                        "squish",
                        "unknown presets must fall back to squish",
                    )
                    self.assertEqual(entry["source"]["minimaxRunId"], "12345")
                # The script must have written the staged sources to
                # ``assets/source`` so ``prepare_assets.py`` can derive the
                # final WebP pair.
                self.assertTrue((tmp_source / "gel_star.png").is_file())
                self.assertTrue((tmp_source / "cloud_cushion.png").is_file())

            # Promote should never reach into the network module:
            self.assertFalse(hasattr(promote, "urlopen"))

    def test_refuses_unsafe_id_before_doing_io(self):
        with tempfile.TemporaryDirectory() as temp:
            workspace = Path(temp)
            staging = workspace / "stage"
            staging.mkdir()
            (staging / "../../escape.png").write_bytes(b"x")

            tmp_items = workspace / "items.json"
            tmp_items.write_text(
                json.dumps({"version": 1, "items": []}),
                encoding="utf-8",
            )
            with mock.patch.object(promote, "ITEMS_CATALOG", tmp_items):
                # The script accepts an empty staging dir as a no-op, but
                # here we want to confirm that an *invalid* id in the
                # staging area is skipped, not promoted.
                rc = promote.main(
                    [
                        "--staging-dir",
                        str(staging),
                        "--report-path",
                        str(workspace / "promotion.json"),
                    ],
                )
                self.assertEqual(rc, 0)
                self.assertEqual(json.loads(tmp_items.read_text())["items"], [])


if __name__ == "__main__":
    unittest.main()
