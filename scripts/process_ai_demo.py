"""Convert AI-generated demo PNGs into ShadowItem-ready WebP pairs.

Pipeline (offline, no network):

1. Load each PNG from ``assets/development/ai_demo_raw/<node_id>.png``.
2. Crop a centred 1024x1024 region down to 512x512 with a 35px margin.
3. Synthesise a transparent PNG by thresholding near-white pixels to alpha
   0. This is intentionally conservative — the AI-generated backgrounds
   are uniform off-white, so a generous threshold produces a clean mask
   without harming jelly/toy silhouettes. It is **only** meant for
   development/demo playthroughs; production placement still routes
   images through `scripts/prepare_assets.py` after a human-approved
   rembg pass.
4. Write ``assets/development/<id>.webp`` (512x512 transparent) and
   ``assets/development/<id>_shadow.webp`` (identical alpha, dark fill).
5. Rewrite ``assets/catalog/development.json`` so the catalog loader
   can resolve these IDs.

Usage::

    python scripts/process_ai_demo.py

The script refuses to overwrite an existing ID; rerun with ``--force``
to regenerate.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "assets/development/ai_demo_raw"
OUT_DIR = ROOT / "assets/development"
INDEX_PATH = ROOT / "assets/catalog/development.json"
PROMPTS_PATH = ROOT / "assets/generation/minimax_object_prompts.json"

SIZE = 512
MARGIN = 35
SHADOW_RGB = (37, 49, 52)
ALPHA_THRESHOLD = 235  # pixels with luminance >= this become fully transparent.
ID_PATTERN = re.compile(r"^[a-z0-9_]+$")

# Demo ids chosen up-front for the first batch (avoid name collisions
# with the procedural placeholders in assets/development/<id>.webp).
DEMO_IDS_BY_NODE = {
    "452202476662848": "demo_gel_star",
    "452200564740400": "demo_cloud_cushion",
    "452200038068591": "demo_soft_moon",
    "452200038068594": "demo_gummy_heart",
    "452202279968844": "demo_bubble_paddle",
    "452202279968848": "demo_fat_spring",
    "452202476662859": "demo_puzzle_bean",
    "452200038068600": "demo_foam_crystal",
    "452202279968857": "demo_soft_comet",
    "452202476662865": "demo_petal_stone",
}


def _safe_id(value: str) -> bool:
    return bool(value) and len(value) <= 64 and ID_PATTERN.fullmatch(value) is not None


def _load_prompts() -> dict:
    if not PROMPTS_PATH.is_file():
        return {}
    return json.loads(PROMPTS_PATH.read_text(encoding="utf-8"))


def _background_mask(image: Image.Image) -> Image.Image:
    """Make near-white pixels transparent; keep coloured pixels opaque."""
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    w, h = rgba.size
    for y in range(h):
        for x in range(w):
            r, g, b, _a = pixels[x, y]
            if r >= ALPHA_THRESHOLD and g >= ALPHA_THRESHOLD and b >= ALPHA_THRESHOLD:
                pixels[x, y] = (r, g, b, 0)
    return rgba


def _center_crop(image: Image.Image, size: int) -> Image.Image:
    """Crop a centred ``size``-px square, then resize to ``size``."""
    w, h = image.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    box = (left, top, left + side, top + side)
    return image.crop(box).resize((size, size), Image.Resampling.LANCZOS)


def _write_pair(item_id: str, transparent: Image.Image, force: bool = False) -> tuple[Path, Path]:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    color_path = OUT_DIR / f"{item_id}.webp"
    shadow_path = OUT_DIR / f"{item_id}_shadow.webp"
    if not force and (color_path.is_file() or shadow_path.is_file()):
        raise FileExistsError(
            f"{color_path.name} or {shadow_path.name} already exists; pass --force"
        )
    transparent.save(color_path, format="WEBP", quality=88, method=6)
    alpha = transparent.getchannel("A")
    shadow = Image.new("RGBA", (SIZE, SIZE), (*SHADOW_RGB, 0))
    shadow.putalpha(alpha)
    shadow.save(shadow_path, format="WEBP", lossless=True, method=6)
    return color_path, shadow_path


def _lookup_prompt(item_id: str, prompts: dict) -> dict | None:
    short = item_id.removeprefix("demo_")
    for entry in prompts.get("items", []):
        if entry.get("id") == short:
            return entry
    return None


def _build_entry(item_id: str, prompts: dict) -> dict:
    short_lookup = item_id.removeprefix("demo_")
    prompt_entry = _lookup_prompt(item_id, prompts)
    return {
        "id": item_id,
        "image": f"assets/development/{item_id}.webp",
        "shadow": f"assets/development/{item_id}_shadow.webp",
        "category": prompt_entry["category"] if prompt_entry else "squishy_object",
        "distractors": [],
        "effectPreset": (
            prompt_entry["effectPreset"] if prompt_entry else "squish"
        ),
        "silhouetteFeatures": ["ai_demo"],
        "sourcePrompt": (
            f"Object shape: {prompt_entry['shape']}. "
            f"Material: {prompt_entry['material']}."
            if prompt_entry
            else None
        ),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true",
                        help="Overwrite previously generated demo files.")
    args = parser.parse_args(argv)

    if not RAW_DIR.is_dir():
        print(f"missing raw dir: {RAW_DIR}", file=sys.stderr)
        return 1

    prompts = _load_prompts()
    new_entries: list[dict] = []
    for node_id, item_id in DEMO_IDS_BY_NODE.items():
        if not _safe_id(item_id):
            print(f"unsafe demo id: {item_id}", file=sys.stderr)
            return 1
        raw = RAW_DIR / f"{node_id}.png"
        if not raw.is_file():
            print(f"missing raw png: {raw}", file=sys.stderr)
            return 1
        image = Image.open(raw)
        cropped = _center_crop(image, SIZE)
        transparent = _background_mask(cropped)
        try:
            color, shadow = _write_pair(item_id, transparent, force=args.force)
        except FileExistsError as exc:
            print(f"skip {item_id}: {exc}", file=sys.stderr)
            continue
        new_entries.append(_build_entry(item_id, prompts))
        print(f"wrote {color.relative_to(ROOT)} + {shadow.relative_to(ROOT)}")

    # Merge with whatever the procedural placeholder generator already put
    # in development.json, preserving its entries.
    existing: list[dict] = []
    if INDEX_PATH.is_file():
        try:
            existing = json.loads(INDEX_PATH.read_text(encoding="utf-8")).get(
                "items", []
            )
        except json.JSONDecodeError:
            existing = []
    seen = {entry["id"] for entry in existing}
    for entry in new_entries:
        if entry["id"] in seen:
            # Replace with the new demo entry if conflict.
            existing = [e for e in existing if e["id"] != entry["id"]]
        existing.append(entry)
    INDEX_PATH.parent.mkdir(parents=True, exist_ok=True)
    INDEX_PATH.write_text(
        json.dumps(
            {
                "version": 1,
                "assets_note": (
                    "Auto-generated by scripts/generate_v6_placeholders.py "
                    "and scripts/process_ai_demo.py. Only read when "
                    "ENABLE_DEVELOPMENT_ASSETS=1. AI demo entries are "
                    "machine-generated and unverified - human review before "
                    "production promotion."
                ),
                "items": existing,
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"wrote {INDEX_PATH.relative_to(ROOT)} with {len(existing)} items")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
