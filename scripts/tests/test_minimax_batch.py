"""Offline tests; NEVER call the paid MiniMax endpoint."""
from __future__ import annotations

import base64
from io import BytesIO
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import minimax_batch as mm


class MiniMaxBatchTests(unittest.TestCase):
    def setUp(self):
        self.catalog = mm.read_catalog()

    def test_catalog_has_thirty_unique_items_in_three_groups(self):
        items = self.catalog["items"]
        self.assertEqual(len(items), 30)
        self.assertEqual([sum(1 for i in items if i["category"] == group)
                          for group in ("jelly", "toys", "cosmic")], [12, 10, 8])
        for item in items:
            self.assertLessEqual(len(mm.make_prompt(self.catalog, item)), 1500)

    def test_dino_catalog_has_eight_distinct_playable_prompts(self):
        dino_path = mm.ROOT / "assets/generation/minimax_dino_mvp_prompts.json"
        catalog = mm.read_catalog(dino_path)
        self.assertEqual(len(catalog["items"]), 8)
        self.assertEqual(
            [item["id"] for item in catalog["items"]],
            ["dino_trex", "dino_triceratops", "dino_stegosaurus",
             "dino_brachiosaurus", "dino_ankylosaurus",
             "dino_parasaurolophus", "dino_spinosaurus", "dino_pachy"],
        )
        self.assertEqual({item["category"] for item in catalog["items"]},
                         {"dino_island"})
        self.assertEqual({item["effectPreset"] for item in catalog["items"]},
                         {"squish", "wobble", "bounce", "inflate"})
        for item in catalog["items"]:
            prompt = mm.make_prompt(catalog, item)
            self.assertLessEqual(len(prompt), 1500)
            self.assertIn("original baby dinosaur", prompt.lower())
            self.assertIn(item["shape"], prompt)
        with self.assertRaises(ValueError):
            mm.select_items(catalog, 7, 2)

    def test_dino_dry_run_writes_only_plan_never_calls_api(self):
        dino_path = mm.ROOT / "assets/generation/minimax_dino_mvp_prompts.json"
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(mm, "fetch_image",
                              side_effect=AssertionError("API CALLED")):
                plan = mm.run(start=0, count=4, output=Path(temp),
                              dry_run=True, region="intl", catalog_file=dino_path)
            self.assertEqual(len(plan), 4)
            self.assertEqual(plan[0]["id"], "dino_trex")
            self.assertTrue(all(row["status"] == "planned" for row in plan))
            self.assertEqual(list(Path(temp).glob("*.png")), [])

    def test_batch_budget_and_range_checks(self):
        for invalid in (0, 7, 100, -1):
            with self.assertRaises(ValueError):
                mm.select_items(self.catalog, 0, invalid)
        with self.assertRaises(ValueError):
            mm.select_items(self.catalog, -1, 1)
        with self.assertRaises(ValueError):
            mm.select_items(self.catalog, 29, 2)
        self.assertEqual(len(mm.select_items(self.catalog, 24, 6)), 6)

    def test_dry_run_has_no_network_and_does_not_need_secret(self):
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(mm, "fetch_image", side_effect=AssertionError("API CALLED")):
                with patch.dict("os.environ", {"MINIMAX_API_KEY": ""}):
                    plan = mm.run(start=0, count=2, output=Path(temp),
                                  dry_run=True, region="intl")
            self.assertEqual([i["status"] for i in plan], ["planned", "planned"])
            data = json.loads((Path(temp) / "report.json").read_text())
            self.assertEqual(data["requested_count"], 2)
            self.assertTrue(data["dry_run"])
            self.assertEqual(list(Path(temp).glob("*.png")), [])

    def test_paid_run_missing_secret_fails_before_api(self):
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(mm, "fetch_image", side_effect=AssertionError("API CALLED")):
                with patch.dict("os.environ", {"MINIMAX_API_KEY": ""}):
                    with self.assertRaisesRegex(RuntimeError, "secret is missing"):
                        mm.run(start=0, count=1, output=Path(temp),
                               dry_run=False, region="intl")

    def test_subscription_only_prevents_paygo_key_before_request(self):
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(mm, "fetch_image", side_effect=AssertionError("API CALLED")):
                with patch.dict("os.environ", {
                    "MINIMAX_API_KEY": "paygo-test-key",
                    "MINIMAX_SUBSCRIPTION_ONLY": "1",
                }):
                    with self.assertRaisesRegex(RuntimeError, "Subscription Key"):
                        mm.run(start=0, count=1, output=Path(temp),
                               dry_run=False, region="intl")

    def test_subscription_only_dry_run_never_uses_key(self):
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(mm, "fetch_image", side_effect=AssertionError("API CALLED")):
                with patch.dict("os.environ", {
                    "MINIMAX_API_KEY": "paygo-test-key",
                    "MINIMAX_SUBSCRIPTION_ONLY": "1",
                }):
                    plan = mm.run(start=0, count=1, output=Path(temp),
                                  dry_run=True, region="intl")
            self.assertEqual(plan[0]["status"], "planned")

    def test_image_output_checks(self):
        buffer = BytesIO()
        Image.new("RGB", (1024, 1024), (255, 255, 255)).save(buffer, "PNG")
        raw = buffer.getvalue()
        with tempfile.TemporaryDirectory() as temp:
            saved_name = mm.save_image(raw, Path(temp) / "object_01")
            self.assertEqual(saved_name, "object_01.png")
            self.assertTrue((Path(temp) / saved_name).is_file())
            with self.assertRaises(ValueError):
                mm.save_image(b"not an image", Path(temp) / "invalid")

    def test_request_and_response_contract_offline(self):
        buffer = BytesIO()
        Image.new("RGB", (1024, 1024), (0, 0, 0)).save(buffer, "PNG")
        payload = {
            "base_resp": {"status_code": 0},
            "data": {"image_base64": [base64.b64encode(buffer.getvalue()).decode()]},
        }
        mock_response = BytesIO(json.dumps(payload).encode())
        with patch.object(mm, "urlopen", return_value=mock_response) as fake:
            img = mm.fetch_image("A soft toy", "test-key", region="intl")
        self.assertEqual(img, buffer.getvalue())
        request = fake.call_args.args[0]
        self.assertEqual(request.full_url, mm.REGION_ENDPOINTS["intl"])
        self.assertEqual(request.get_method(), "POST")
        sent = json.loads(request.data)
        self.assertEqual(sent["n"], 1)
        self.assertEqual(sent["response_format"], "base64")
        self.assertEqual(sent["model"], "image-01")

    def test_reject_unapproved_region(self):
        with self.assertRaises(ValueError):
            mm.fetch_image("Hello", "secret", region="untrusted")


if __name__ == "__main__":
    unittest.main()
