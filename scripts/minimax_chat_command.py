#!/usr/bin/env python3
"""Secure, owner-only GitHub Issue comment controller for MiniMax image-01.

Never interpolate the issue comment into shell commands. Parse the event JSON,
validate a single prompt and the explicit payment acknowledgement, then reuse
minimax_batch.run() (same model, subscription-only key guard and Artifact schema).

Comment syntax:
  /minimax {"id":"gel_star_02","prompt":"A single ...",
            "category":"jelly","effectPreset":"squish",
            "region":"intl","dry_run":true}
For one real image, pass dry_run=false AND confirm="GENERATE_1_IMAGE".
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import re

from minimax_batch import run

COMMAND = "/minimax "
EXPECTED_REPOSITORY = "SMRI2170/animal-shadow-match"
EXPECTED_OWNER = "SMRI2170"
CONTROLLER_ISSUE = 33
ALLOWED = {
    "id", "prompt", "category", "effectPreset", "region", "dry_run", "confirm",
}
PRESETS = {"squish", "wobble", "bounce", "inflate"}
REGIONS = {"intl", "cn"}


class InvalidCommand(ValueError):
    pass


def parse_event(
    event: dict,
    *,
    repository: str = EXPECTED_REPOSITORY,
    owner: str = EXPECTED_OWNER,
    issue_number: int = CONTROLLER_ISSUE,
) -> dict:
    """Reject unauthorized comments and costly requests before API access."""
    if not isinstance(event, dict):
        raise InvalidCommand("expected a GitHub issue_comment JSON object")
    if event.get("action") != "created":
        raise InvalidCommand("only new comments can trigger image generation")
    if event.get("repository", {}).get("full_name") != repository:
        raise InvalidCommand("unexpected repository")
    issue = event.get("issue") or {}
    if issue.get("number") != issue_number or issue.get("pull_request"):
        raise InvalidCommand("unexpected issue or pull request")
    comment = event.get("comment") or {}
    if comment.get("user", {}).get("login") != owner:
        raise InvalidCommand("only the repository owner can trigger this controller")
    if event.get("sender", {}).get("login") != owner:
        raise InvalidCommand("unexpected event sender")
    body = comment.get("body")
    if not isinstance(body, str) or not body.startswith(COMMAND):
        raise InvalidCommand("comment must begin with /minimax followed by JSON")
    if len(body) > 2500:
        raise InvalidCommand("command too long")
    try:
        request = json.loads(body[len(COMMAND):].strip())
    except json.JSONDecodeError as exc:
        raise InvalidCommand(f"invalid JSON payload: {exc.msg}") from None
    if not isinstance(request, dict):
        raise InvalidCommand("payload must be one JSON object")
    if set(request) - ALLOWED:
        raise InvalidCommand("unknown request fields; one image per command")
    if not {"id", "prompt"}.issubset(request):
        raise InvalidCommand("id and prompt are required")
    item_id = request["id"]
    prompt = request["prompt"]
    if (not isinstance(item_id, str) or len(item_id) > 64
            or re.fullmatch(r"[a-z][a-z0-9_]*", item_id) is None):
        raise InvalidCommand("id must be 1-64 lowercase letters, digits or underscore")
    if not isinstance(prompt, str) or not 20 <= len(prompt) <= 1500:
        raise InvalidCommand("prompt must be 20-1500 characters")
    category = request.get("category", "squishy_object")
    if (not isinstance(category, str) or len(category) > 40
            or re.fullmatch(r"[a-z][a-z0-9_]*", category) is None):
        raise InvalidCommand("unsafe category")
    preset = request.get("effectPreset", "squish")
    if not isinstance(preset, str) or preset not in PRESETS:
        raise InvalidCommand("unsupported effectPreset")
    region = request.get("region", "intl")
    if region not in REGIONS:
        raise InvalidCommand("unsupported MiniMax region")
    dry = request.get("dry_run", True)
    if type(dry) is not bool:
        raise InvalidCommand("dry_run must be true or false")
    if not dry and request.get("confirm") != "GENERATE_1_IMAGE":
        raise InvalidCommand("real image requires confirm=GENERATE_1_IMAGE")
    if dry and "confirm" in request:
        raise InvalidCommand("dry run must not include a generation confirmation")
    return {
        "id": item_id,
        "prompt": prompt,
        "category": category,
        "effectPreset": preset,
        "region": region,
        "dry_run": dry,
    }


def main() -> None:
    event_path = os.environ.get("GITHUB_EVENT_PATH")
    if not event_path:
        raise InvalidCommand("GITHUB_EVENT_PATH missing")
    if os.environ.get("GITHUB_REPOSITORY") != EXPECTED_REPOSITORY:
        raise InvalidCommand("unexpected GitHub repository")
    if os.environ.get("GITHUB_REPOSITORY_OWNER") != EXPECTED_OWNER:
        raise InvalidCommand("unexpected GitHub repository owner")
    event = json.loads(Path(event_path).read_text(encoding="utf-8"))
    req = parse_event(event)
    # Do not print the key; GitHub injects it only into this workflow step.
    run(
        start=0,
        count=1,
        region=req["region"],
        output=Path("generated/minimax"),
        dry_run=req["dry_run"],
        custom_request=req,
    )
    print(f"controller finished; id={req['id']}, dry_run={req['dry_run']}")


if __name__ == "__main__":
    try:
        main()
    except InvalidCommand as exc:
        raise SystemExit(f"Rejected MiniMax issue command: {exc}") from None
