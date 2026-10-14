"""Offline tests: ChatGPT/GitHub comment controller never makes real API calls."""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import minimax_chat_command as ctl
import minimax_batch as mm


def event(
    *,
    body: str | None = None,
    user: str = "SMRI2170",
    issue: int = 33,
    repo: str = "SMRI2170/animal-shadow-match",
    action: str = "created",
) -> dict:
    if body is None:
        body = '/minimax ' + json.dumps({
            "id": "mint_cloud_01",
            "prompt": "A single fluffy mint cloud-shaped foam squishy object, centered, no face, pastel 3D toy.",
            "category": "jelly",
            "effectPreset": "squish",
            "region": "intl",
            "dry_run": True,
        })
    return {
        "action": action,
        "repository": {"full_name": repo},
        "issue": {"number": issue},
        "comment": {"body": body, "user": {"login": user}},
        "sender": {"login": user},
    }


class ChatControllerSecurityTests(unittest.TestCase):
    def test_default_dry_run(self):
        r = ctl.parse_event(event())
        self.assertTrue(r["dry_run"])
        self.assertEqual(r["id"], "mint_cloud_01")
        self.assertEqual(r["region"], "intl")

    def test_owner_only(self):
        with self.assertRaises(ctl.InvalidCommand):
            ctl.parse_event(event(user="untrusted"))

    def test_correct_issue_only(self):
        with self.assertRaises(ctl.InvalidCommand):
            ctl.parse_event(event(issue=29))

    def test_correct_repository_only(self):
        with self.assertRaises(ctl.InvalidCommand):
            ctl.parse_event(event(repo="elsewhere/repo"))

    def test_only_created_event(self):
        with self.assertRaises(ctl.InvalidCommand):
            ctl.parse_event(event(action="edited"))

    def test_not_a_pull_request(self):
        e = event()
        e["issue"]["pull_request"] = {"url": "https://example.invalid"}
        with self.assertRaises(ctl.InvalidCommand):
            ctl.parse_event(e)

    def test_explicit_confirmation_required_for_real_call(self):
        payload = {
            "id": "mint_cloud_01",
            "prompt": "A single fluffy mint cloud-shaped foam squishy object, centered, no face, pastel 3D toy.",
            "dry_run": False,
        }
        with self.assertRaises(ctl.InvalidCommand):
            ctl.parse_event(event(body="/minimax " + json.dumps(payload)))
        payload["confirm"] = "GENERATE_1_IMAGE"
        req = ctl.parse_event(event(body="/minimax " + json.dumps(payload)))
        self.assertFalse(req["dry_run"])

    def test_unknown_fields_refused_to_prevent_multi_image_jobs(self):
        with self.assertRaises(ctl.InvalidCommand):
            ctl.parse_event(event(body='/minimax {"id":"gel","prompt":"'+ "x"*30 +'","count":100}'))

    def test_invalid_id_refused(self):
        with self.assertRaises(ctl.InvalidCommand):
            ctl.parse_event(event(body='/minimax {"id":"../escape","prompt":"'+ "x"*30 +'"}'))

    def test_prompt_required(self):
        with self.assertRaises(ctl.InvalidCommand):
            ctl.parse_event(event(body='/minimax {"id":"gel_star"}'))

    def test_invalid_json_refused(self):
        with self.assertRaises(ctl.InvalidCommand):
            ctl.parse_event(event(body='/minimax {"id":'))

    def test_bool_required(self):
        with self.assertRaises(ctl.InvalidCommand):
            ctl.parse_event(event(body='/minimax {"id":"gel_star","prompt":"'+ "x"*30 +'","dry_run":"false"}'))


class ChatControllerIntegrationTests(unittest.TestCase):
    def test_dry_run_produces_report_without_key_or_api_call(self):
        req = ctl.parse_event(event())
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(mm, "fetch_image", side_effect=AssertionError("API CALLED")):
                with patch.dict("os.environ", {"MINIMAX_SUBSCRIPTION_ONLY": "1", "MINIMAX_API_KEY": ""}):
                    result = mm.run(start=0, count=1, output=Path(tmp), dry_run=True,
                                    region=req["region"], custom_request=req)
            self.assertEqual(result[0]["status"], "planned")
            self.assertEqual(result[0]["prompt"], req["prompt"])
            report = json.loads((Path(tmp) / "report.json").read_text())
            self.assertTrue(report["dry_run"])
            self.assertEqual(len(report["items"]), 1)

    def test_custom_generation_rejects_paygo_key_before_call(self):
        req = ctl.parse_event(event())
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(mm, "fetch_image", side_effect=AssertionError("API CALLED")):
                with patch.dict("os.environ", {"MINIMAX_SUBSCRIPTION_ONLY": "1", "MINIMAX_API_KEY": "sk-api-not-for-go"}):
                    with self.assertRaisesRegex(RuntimeError, "Subscription Key"):
                        mm.run(start=0, count=1, output=Path(tmp), dry_run=False,
                               region="intl", custom_request=req)

    def test_custom_generation_never_allows_many_images(self):
        req = ctl.parse_event(event())
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(ValueError, "exactly one"):
                mm.run(start=0, count=3, output=Path(tmp), dry_run=True,
                       region="intl", custom_request=req)


if __name__ == "__main__":
    unittest.main()
