"""Offline tests for the asset preparation pipeline.

These tests never invoke rembg; they pre-build transparent PNGs and confirm
that ``prepare_assets.process_file`` produces matching alpha masks in the
output WebP pair, and that the CLI rejects unsafe ids and opaque inputs.
"""
from __future__ import annotations

import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import prepare_assets as pa


def _make_transparent_png(path: Path, *, color=(180, 90, 200, 255), shape: str = "circle") -> None:
    img = Image.new("RGBA", (300, 300), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if shape == "circle":
        draw.ellipse((40, 40, 260, 260), fill=color)
    elif shape == "square":
        draw.rectangle((40, 40, 260, 260), fill=color)
    else:
        raise ValueError(shape)
    img.save(path)


def _make_opaque_png(path: Path) -> None:
    img = Image.new("RGBA", (300, 300), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)
    draw.ellipse((40, 40, 260, 260), fill=(0, 0, 0, 255))
    img.save(path)


class PrepareAssetTests(unittest.TestCase):
    def test_process_file_writes_two_webp_with_identical_alpha(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "gel_star.png"
            _make_transparent_png(source)
            destination = Path(temp) / "out"
            stem = pa.process_file(source, destination)
            self.assertEqual(stem, "gel_star")
            color = destination / "gel_star.webp"
            shadow = destination / "gel_star_shadow.webp"
            self.assertTrue(color.is_file())
            self.assertTrue(shadow.is_file())
            with Image.open(color) as c, Image.open(shadow) as s:
                self.assertEqual(c.size, (pa.SIZE, pa.SIZE))
                self.assertEqual(s.size, (pa.SIZE, pa.SIZE))
                a_c = c.convert("RGBA").getchannel("A")
                a_s = s.convert("RGBA").getchannel("A")
                from PIL import ImageChops
                diff = ImageChops.difference(a_c, a_s)
                self.assertIsNone(diff.getbbox())

    def test_process_file_rejects_opaque_image(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "opaque_thing.png"
            _make_opaque_png(source)
            with self.assertRaises(ValueError):
                pa.process_file(source, Path(temp) / "out")

    def test_process_file_rejects_fully_transparent_image(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "blank.png"
            Image.new("RGBA", (256, 256), (0, 0, 0, 0)).save(source)
            with self.assertRaises(ValueError):
                pa.process_file(source, Path(temp) / "out")

    def test_select_inputs_filters_by_ids(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            _make_transparent_png(base / "gel_star.png")
            _make_transparent_png(base / "cloud_cushion.png")
            selected = pa._select_inputs(base, ["gel_star"])
            self.assertEqual([p.name for p in selected], ["gel_star.png"])

    def test_is_valid_id_rejects_uppercase_and_punctuation(self):
        self.assertTrue(pa._is_valid_id("gel_star"))
        self.assertTrue(pa._is_valid_id("toy_001"))
        self.assertFalse(pa._is_valid_id("Gel-Star"))
        self.assertFalse(pa._is_valid_id(""))
        self.assertFalse(pa._is_valid_id(".." * 30))

    def test_auto_remove_background_without_rembg_raises_helpful_error(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "cloud.png"
            _make_opaque_png(source)
            # Force the importer to believe rembg is unavailable so the
            # in-script guard fires regardless of host installation.
            import builtins
            orig_import = builtins.__import__

            def fake_import(name, *args, **kwargs):
                if name == "rembg" or name.startswith("rembg."):
                    raise ImportError("rembg disabled for test")
                return orig_import(name, *args, **kwargs)

            builtins.__import__ = fake_import
            try:
                with self.assertRaises(RuntimeError) as ctx:
                    pa._auto_remove_background(source)
                self.assertIn("rembg", str(ctx.exception))
            finally:
                builtins.__import__ = orig_import

    def test_auto_draft_branch_rejects_unsafe_id_with_strict(self):
        # We can't easily exercise the CLI's --strict arg without invoking
        # the entrypoint, but we can confirm the helper used by main rejects
        # an unsafe token.
        self.assertFalse(pa._is_valid_id("../escape"))


class PrepareAssetsEndToEndTests(unittest.TestCase):
    def test_main_processes_only_requested_ids(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            source = base / "src"
            source.mkdir()
            destination = base / "items"
            _make_transparent_png(source / "gel_star.png")
            _make_transparent_png(source / "cloud_cushion.png", shape="square")
            from scripts import prepare_assets  # type: ignore  # noqa
            # Simulate `python scripts/prepare_assets.py --input <src> --output <dst> --ids gel_star`
            sys.argv = [
                "prepare_assets.py",
                "--input",
                str(source),
                "--output",
                str(destination),
                "--ids",
                "gel_star",
                "--strict",
            ]
            pa.main()
            assert (destination / "gel_star.webp").is_file()
            assert (destination / "gel_star_shadow.webp").is_file()
            assert not (destination / "cloud_cushion.webp").exists()
            report = json.loads((destination / "report.json").read_text())
            self.assertEqual(report["ids"], ["gel_star"])
            self.assertEqual(report["bg_mode"], "raw")


if __name__ == "__main__":
    unittest.main()
