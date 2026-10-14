"""Offline tests for ``scripts/generate_v6_placeholders.py``.

The tests build synthetic placeholder PNGs (color + matching shadow) into a
scratch directory, then assert the index JSON file matches. No rendering
of the real catalog happens — keeps CI fast and deterministic.
"""
from __future__ import annotations

import importlib
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
gv = importlib.import_module("generate_v6_placeholders")


class IdGuardTests(unittest.TestCase):
    def test_safe_id_accepts_lowercase_alnum_and_underscore(self):
        self.assertTrue(gv._safe_id("gel_star"))
        self.assertTrue(gv._safe_id("toy_001"))

    def test_safe_id_rejects_uppercase_punct_and_unicode(self):
        self.assertFalse(gv._safe_id("Gel-Star"))
        self.assertFalse(gv._safe_id(""))
        self.assertFalse(gv._safe_id("🐙"))


class DrawerSelectionTests(unittest.TestCase):
    def test_known_keywords_resolve_to_dedicated_drawers(self):
        star = gv._select_drawer("a rounded five-point star with thick soft tips", "jelly")
        ring = gv._select_drawer("a thick wobbly donut ring", "jelly")
        planet = gv._select_drawer("a planet sphere with one very thick tilted ring", "cosmic")
        self.assertIs(star, gv._draw_star)
        self.assertIs(ring, gv._draw_ring)
        self.assertIs(planet, gv._draw_planet)

    def test_unknown_shape_falls_back_per_category(self):
        jelly = gv._select_drawer("completely novel weird shape", "jelly")
        toys = gv._select_drawer("completely novel weird shape", "toys")
        cosmic = gv._select_drawer("completely novel weird shape", "cosmic")
        self.assertIs(jelly, gv._draw_blob)
        self.assertIs(toys, gv._draw_arch)
        self.assertIs(cosmic, gv._draw_crystal)


class CatalogIntegrationTests(unittest.TestCase):
    """Confirm the script reads the real catalog structure without errors."""

    def test_catalog_loads_and_contains_30_unique_items(self):
        catalog = gv.load_catalog()
        items = catalog["items"]
        self.assertEqual(len(items), 30)
        ids = [item["id"] for item in items]
        self.assertEqual(len(ids), len(set(ids)))
        for item in items:
            self.assertIn(item["category"], {"jelly", "toys", "cosmic"})
            self.assertIn(item["effectPreset"], {"squish", "wobble", "bounce", "inflate"})


class IndexWriteTests(unittest.TestCase):
    def test_write_development_index_round_trips_json(self):
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "development.json"
            with mock.patch.object(gv, "OUT_JSON", target):
                entries = [
                    {
                        "id": "gel_star",
                        "category": "jelly",
                        "effectPreset": "squish",
                        "shape": "star",
                        "material": "jelly",
                    },
                ]
                gv.write_development_index([
                    {
                        "id": item["id"],
                        "image": f"assets/development/{item['id']}.webp",
                        "shadow": f"assets/development/{item['id']}_shadow.webp",
                        "category": item["category"],
                        "distractors": [],
                        "effectPreset": item.get("effectPreset", "squish"),
                    }
                    for item in entries
                ])
            data = json.loads(target.read_text())
            self.assertEqual(data["items"][0]["id"], "gel_star")
            self.assertEqual(
                data["items"][0]["shadow"],
                "assets/development/gel_star_shadow.webp",
            )


if __name__ == "__main__":
    unittest.main()
