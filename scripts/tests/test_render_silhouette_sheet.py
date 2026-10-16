"""Offline test for the color/shadow review contact sheet."""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from render_silhouette_sheet import render_sheet


class SilhouetteSheetTests(unittest.TestCase):
    def test_sheet_outputs_color_and_shadow_at_96px(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            assets = root / "assets/development"
            assets.mkdir(parents=True)
            color = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
            ImageDraw.Draw(color).ellipse((96, 96, 416, 416), fill=(240, 60, 100, 255))
            shadow = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
            ImageDraw.Draw(shadow).ellipse((96, 96, 416, 416), fill=(37, 49, 52, 255))
            color.save(assets / "sample.webp", format="WEBP", lossless=True)
            shadow.save(assets / "sample_shadow.webp", format="WEBP", lossless=True)
            catalog = root / "development.json"
            catalog.write_text(
                json.dumps({"items": [{
                    "id": "sample",
                    "image": "assets/development/sample.webp",
                    "shadow": "assets/development/sample_shadow.webp",
                }]}),
                encoding="utf-8",
            )
            output = root / "qa.png"
            self.assertEqual(render_sheet(root, catalog, output, columns=1), 1)
            with Image.open(output) as rendered:
                self.assertEqual(rendered.size, (228, 148))
                # The same center pixel is pink on the left and dark on the right.
                self.assertEqual(rendered.getpixel((60, 88)), (240, 60, 100))
                self.assertEqual(rendered.getpixel((168, 88)), (37, 49, 52))

    def test_rejects_empty_catalog(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            catalog = root / "empty.json"
            catalog.write_text('{"items": []}', encoding="utf-8")
            with self.assertRaises(ValueError):
                render_sheet(root, catalog, root / "sheet.png")


if __name__ == "__main__":
    unittest.main()
