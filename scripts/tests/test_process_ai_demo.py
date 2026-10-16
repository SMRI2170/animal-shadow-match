"""Offline regressions: AI demos must not be silently thresholded or published."""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import process_ai_demo as demo


def _transparent_object() -> Image.Image:
    image = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    ImageDraw.Draw(image).ellipse(
        (100, 100, 412, 412), fill=(145, 180, 230, 255)
    )
    return image


class ProcessAiDemoTests(unittest.TestCase):
    def test_rejects_opaque_near_white_image_instead_of_thresholding(self):
        image = Image.new("RGB", (512, 512), (230, 230, 230))
        ImageDraw.Draw(image).ellipse((90, 90, 420, 420), fill=(50, 100, 150))
        with self.assertRaisesRegex(ValueError, "fully opaque"):
            demo._background_mask(image)

    def test_preserves_reviewed_alpha(self):
        image = _transparent_object()
        result = demo._background_mask(image)
        self.assertEqual(
            image.getchannel("A").tobytes(),
            result.getchannel("A").tobytes(),
        )

    def test_writes_candidate_index_without_modifying_game_catalog(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            raw = root / "assets/development/ai_demo_raw"
            raw.mkdir(parents=True)
            _transparent_object().save(raw / "123.png")
            out_dir = root / "assets/development"
            index = out_dir / "ai_demo_candidates.json"
            with (
                patch.object(demo, "ROOT", root),
                patch.object(demo, "RAW_DIR", raw),
                patch.object(demo, "OUT_DIR", out_dir),
                patch.object(demo, "CANDIDATE_INDEX_PATH", index),
                patch.object(demo, "PROMPTS_PATH", root / "nonexistent.json"),
                patch.object(demo, "DEMO_IDS_BY_NODE", {"123": "demo_good"}),
            ):
                self.assertEqual(demo.main([]), 0)
            data = json.loads(index.read_text(encoding="utf-8"))
            self.assertFalse(data["approved"])
            self.assertEqual([it["id"] for it in data["items"]], ["demo_good"])
            self.assertTrue((out_dir / "demo_good_shadow.webp").is_file())
            self.assertFalse((root / "assets/catalog/development.json").exists())


if __name__ == "__main__":
    unittest.main()
