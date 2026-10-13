#!/usr/bin/env python3
"""Generate reviewed MiniMax candidate images with a strict manual-run budget.

Dry-run never uses MINIMAX_API_KEY or calls any network endpoint.
Generation returns base64 image data; no temporary download URLs are persisted.
The produced images are unreviewed, opaque candidates, NOT game-ready masks.
"""
from __future__ import annotations

import argparse
import base64
import binascii
from datetime import datetime, timezone
from io import BytesIO
import json
import os
from pathlib import Path
import re
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "assets/generation/minimax_object_prompts.json"
MAX_PER_RUN = 6
MAX_BYTES = 12 * 1024 * 1024
REGION_ENDPOINTS = {
    "intl": "https://api.minimax.io/v1/image_generation",
    "cn": "https://api.minimaxi.com/v1/image_generation",
}
FORMAT_EXT = {"JPEG": ".jpg", "PNG": ".png", "WEBP": ".webp"}


def read_catalog(path: Path = CATALOG) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("model") != "image-01" or not isinstance(data.get("style"), str):
        raise ValueError("Expected image-01 and a style string")
    items = data.get("items")
    if not isinstance(items, list) or not items:
        raise ValueError("Empty or missing items")
    ids = []
    for item in items:
        item_id = item.get("id")
        if not isinstance(item_id, str) or re.fullmatch(r"[a-z0-9_]+", item_id) is None:
            raise ValueError(f"Unsafe item id: {item_id!r}")
        for field in ("shape", "material", "category", "effectPreset"):
            if not isinstance(item.get(field), str) or not item[field].strip():
                raise ValueError(f"{item_id}: missing {field}")
        ids.append(item_id)
    if len(ids) != len(set(ids)):
        raise ValueError("Duplicate candidate IDs")
    return data


def select_items(catalog: dict, start: int, count: int) -> list[dict]:
    if count < 1 or count > MAX_PER_RUN:
        raise ValueError(f"Count must be between 1 and {MAX_PER_RUN}; no API calls made")
    if start < 0 or start + count > len(catalog["items"]):
        raise ValueError("Invalid start/count for prompt catalog; no API calls made")
    return catalog["items"][start:start + count]


def make_prompt(catalog: dict, item: dict) -> str:
    prompt = (
        f'{catalog["style"]} '
        f'Object shape: {item["shape"]}. '
        f'Material appearance: {item["material"]}.'
    )
    if len(prompt) > 1500:
        raise ValueError(f'{item["id"]}: prompt exceeds 1500 characters')
    return prompt


def fetch_image(prompt: str, key: str, *, region: str) -> bytes:
    if region not in REGION_ENDPOINTS:
        raise ValueError("Unsupported region; endpoint must be official MiniMax")
    request_body = json.dumps({
        "model": "image-01",
        "prompt": prompt,
        "aspect_ratio": "1:1",
        "n": 1,
        "response_format": "base64",
        "prompt_optimizer": False,
    }).encode("utf-8")
    request = Request(
        REGION_ENDPOINTS[region],
        data=request_body,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urlopen(request, timeout=180) as response:
            result = json.loads(response.read())
    except HTTPError as exc:
        # Do not print request headers, credentials, or untrusted error responses.
        raise RuntimeError(f"MiniMax HTTP {exc.code}") from None
    except URLError:
        raise RuntimeError("MiniMax connection failed") from None

    base_response = result.get("base_resp") or {}
    code = base_response.get("status_code", 0)
    if code != 0:
        raise RuntimeError(f"MiniMax API status_code={code}, see account dashboard")
    data = result.get("data") or {}
    raw_images = data.get("image_base64") or []
    if not isinstance(raw_images, list) or len(raw_images) != 1:
        raise RuntimeError("Expected exactly one image in MiniMax response")
    try:
        return base64.b64decode(raw_images[0], validate=True)
    except (ValueError, binascii.Error):
        raise RuntimeError("MiniMax returned malformed base64 image") from None


def save_image(raw: bytes, target: Path) -> str:
    if not raw or len(raw) > MAX_BYTES:
        raise ValueError("Image is empty or exceeds 12 MiB limit")
    try:
        with Image.open(BytesIO(raw)) as img:
            fmt = img.format
            width, height = img.size
            img.verify()
    except (OSError, ValueError) as exc:
        raise ValueError("MiniMax response is not a valid image") from None
    if fmt not in FORMAT_EXT or min(width, height) < 512 or max(width, height) > 4096:
        raise ValueError("Unrecognized or unexpected MiniMax image dimensions/format")
    dest = target.with_suffix(FORMAT_EXT[fmt])
    dest.write_bytes(raw)
    return dest.name


def run(*, start: int, count: int, output: Path, dry_run: bool, region: str,
        catalog_file: Path = CATALOG) -> list[dict]:
    catalog = read_catalog(catalog_file)
    items = select_items(catalog, start, count)
    if region not in REGION_ENDPOINTS:
        raise ValueError("Invalid region")
    plan = [
        {
            "id": item["id"],
            "category": item["category"],
            "effectPreset": item["effectPreset"],
            "prompt": make_prompt(catalog, item),
            "file": None,
            "status": "planned" if dry_run else "pending",
        }
        for item in items
    ]
    output.mkdir(parents=True, exist_ok=True)
    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "model": catalog["model"],
        "region": region,
        "dry_run": dry_run,
        "requested_count": count,
        "notes": "UNREVIEWED generated candidates. Background removal is a separate manual QA step.",
        "items": plan,
    }
    report_path = output / "report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if dry_run:
        print(f"DRY RUN: would request {count} paid MiniMax image(s); no key or API call used.")
        print("Candidate IDs:", ", ".join(item["id"] for item in plan))
        return plan

    key = os.getenv("MINIMAX_API_KEY", "").strip()
    if not key:
        raise RuntimeError("MINIMAX_API_KEY repository secret is missing. No calls made.")
    for i, item in enumerate(plan):
        try:
            raw = fetch_image(item["prompt"], key, region=region)
            name = save_image(raw, output / item["id"])
            item["file"] = name
            item["status"] = "generated_unreviewed"
            print(f"Created candidate {i + 1}/{count}: {name} ({len(raw)} bytes)")
        except Exception:
            item["status"] = "failed"
            raise
        finally:
            report_path.write_text(
                json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
        if i < count - 1:
            time.sleep(7)  # Official release notes describe a 10 RPM image limit.
    return plan


def main() -> None:
    parser = argparse.ArgumentParser(description="Manual MiniMax asset batch; safe dry-run first")
    parser.add_argument("--start", type=int, default=0, help="Zero-based index in catalog")
    parser.add_argument("--count", type=int, default=1)
    parser.add_argument("--region", choices=sorted(REGION_ENDPOINTS), default="intl")
    parser.add_argument("--output", type=Path, default=Path("generated/minimax"))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    run(start=args.start, count=args.count, output=args.output,
        dry_run=args.dry_run, region=args.region)


if __name__ == "__main__":
    main()
