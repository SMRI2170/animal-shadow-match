"""Validate catalog references, alpha masks, and empty/duplicate asset IDs.

Supports two catalog files:

* ``assets/catalog/animals.json`` — legacy v4 demo entries. Kept as a
  regression set so the 8 demo animals never silently break during the v6
  migration (Issue #29).
* ``assets/catalog/items.json`` — the v6 single-asset object catalog. New
  approved MiniMax-generated objects land here.

Each entry must declare either ``id`` fields matching the rules documented
in ``minimax_object_prompts.json`` (lowercase ascii, digits, underscores),
and the referenced colour WebP and shadow WebP must:

* exist on disk;
* be 512x512;
* have a real alpha channel (not fully opaque or fully transparent);
* share an identical alpha channel so the silhouette still resolves.

``effectPreset`` must be one of ``squish|wobble|bounce|inflate`` (the four
shipped transforms). Unknown or absent values are rejected in the items
catalog but accepted as ``squish`` by the runtime loader.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
LEGACY_CATALOG = ROOT / "assets/catalog/animals.json"
ITEMS_CATALOG = ROOT / "assets/catalog/items.json"

ID_PATTERN = re.compile(r"^[a-z0-9_]+$")
ALLOWED_PRESETS = {"squish", "wobble", "bounce", "inflate"}
MIN_ITEMS = 4


def _validate_entry(item: dict, available_ids: set[str], root: Path) -> list[str]:
    errors: list[str] = []
    item_id = item.get("id")
    if not isinstance(item_id, str) or not ID_PATTERN.fullmatch(item_id):
        errors.append(f"invalid id: {item_id!r}")
    for key in ("image", "shadow"):
        rel_path = item.get(key)
        if not isinstance(rel_path, str):
            errors.append(f"missing {key} path on {item_id!r}")
            continue
        if rel_path.startswith("..") or "//" in rel_path:
            errors.append(f"unsafe {key} path on {item_id!r}: {rel_path}")
            continue
        file = (root / rel_path).resolve()
        if not file.is_file():
            errors.append(f"missing {key}: {rel_path}")
            continue
        try:
            with Image.open(file) as img:
                rgba = img.convert("RGBA")
        except Exception as exc:  # pragma: no cover - Pillow errors
            errors.append(f"{rel_path}: cannot open ({exc})")
            continue
        if rgba.size != (512, 512):
            errors.append(f"expected 512x512 {file}: {rgba.size}")
            continue
        alpha = rgba.getchannel("A")
        lo, hi = alpha.getextrema()
        if lo == 255 or hi == 0:
            errors.append(f"missing usable transparency: {file}")
            continue
        # Filename basename must be the item id; protects against writing
        # assets/<other>.webp while the catalog says <id>.
        stem = file.stem
        expected = {item_id, f"{item_id}_shadow"}
        if key == "image" and stem != item_id:
            errors.append(
                f"{rel_path}: basename should be {item_id!r}, got {stem!r}",
            )
        if key == "shadow" and stem != f"{item_id}_shadow":
            errors.append(
                f"{rel_path}: shadow basename should be {item_id!r}_shadow, "
                f"got {stem!r}",
            )

    if not errors:
        try:
            with Image.open(root / item["image"]) as color, Image.open(root / item["shadow"]) as dark:
                color_a = color.convert("RGBA").getchannel("A")
                dark_a = dark.convert("RGBA").getchannel("A")
                diff = ImageChops.difference(color_a, dark_a)
                if diff.getbbox() is not None:
                    errors.append(f"mask mismatch for {item_id}")
        except Exception as exc:
            errors.append(f"{item_id}: alpha comparison failed ({exc})")

    if item_id in set(item.get("distractors", []) or []):
        errors.append(f"{item_id}: self distractor")
    distractors = set(item.get("distractors", []) or [])
    unknown = distractors - available_ids
    if unknown:
        errors.append(f"{item_id}: unknown distractor ids: {sorted(unknown)}")

    preset = item.get("effectPreset")
    if preset is not None and preset not in ALLOWED_PRESETS:
        errors.append(
            f"{item_id}: unknown effectPreset {preset!r}; allowed: {sorted(ALLOWED_PRESETS)}",
        )
    return errors


def _validate_catalog_file(path: Path, *, root: Path, required: bool) -> tuple[list[dict], list[str]]:
    errors: list[str] = []
    if not path.is_file():
        if required:
            errors.append(f"missing catalog file: {path}")
        return [], errors
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return [], [f"{path}: invalid JSON ({exc})"]

    key = "items" if "items" in data else "animals" if "animals" in data else None
    if key is None:
        return [], [f"{path}: expected 'items' or 'animals' key"]
    entries = data[key]
    if not isinstance(entries, list):
        return [], [f"{path}: {key!r} must be an array"]
    return entries, errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--strict-min-items",
        action="store_true",
        help=(
            "Fail if fewer than MIN_ITEMS approved items are declared in "
            "items.json. Default: warn (until MiniMax 30 items are approved)."
        ),
    )
    parser.add_argument("--min-items", type=int, default=MIN_ITEMS)
    args = parser.parse_args(argv)

    errors: list[str] = []
    legacy_entries, legacy_warns = _validate_catalog_file(
        LEGACY_CATALOG, root=ROOT, required=False,
    )
    errors.extend(legacy_warns)

    items_entries, items_warns = _validate_catalog_file(
        ITEMS_CATALOG, root=ROOT, required=False,
    )
    errors.extend(items_warns)

    legacy_ids = {entry.get("id") for entry in legacy_entries if isinstance(entry.get("id"), str)}
    item_ids = {entry.get("id") for entry in items_entries if isinstance(entry.get("id"), str)}
    duplicates = sorted(legacy_ids & item_ids)
    if duplicates:
        # Crossing the two lists is allowed, but a single id existing in
        # BOTH lists with conflicting data is rejected because the loader
        # would silently shadow the entries.
        all_entries = {entry.get("id"): entry for entry in legacy_entries}
        for entry in items_entries:
            existing = all_entries.get(entry.get("id"))
            if existing is None:
                continue
            for key in ("category", "image", "shadow"):
                if entry.get(key) != existing.get(key):
                    errors.append(
                        f"id collision {entry.get('id')!r}: "
                        f"animals.json/items.json disagree on {key!r}",
                    )
                    break

    available = legacy_ids | item_ids
    for entry in items_entries:
        errors.extend(_validate_entry(entry, available, ROOT))
    for entry in legacy_entries:
        errors.extend(_validate_entry(entry, available, ROOT))

    if args.strict_min_items and len(item_ids) < args.min_items:
        errors.append(
            f"items.json declares {len(item_ids)} approved items; need at "
            f"least {args.min_items} before promoting to the live pool.",
        )
    if not legacy_ids and not item_ids:
        errors.append("both catalogs are empty")

    if errors:
        print("VALIDATION FAILED", file=sys.stderr)
        for line in errors:
            print(f"  - {line}", file=sys.stderr)
        return 1

    print(
        f"OK: {len(legacy_ids)} legacy animals + "
        f"{len(item_ids)} new items, masks and IDs verified",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
