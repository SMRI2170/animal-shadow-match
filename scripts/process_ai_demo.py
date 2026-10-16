"""Convert AI-generated demo PNGs into ShadowItem-ready WebP pairs.

Pipeline (offline, no network):

1. Load each PNG from ``assets/development/ai_demo_raw/<node_id>.png``.
2. Require a genuinely transparent source PNG. For AI-generated opaque
   PNGs, first perform offline background removal with prepare_assets.py
   --bg-mode auto_draft and review the resulting <id>_rembg.png.
3. Crop/resize the reviewed PNG to 512x512 while preserving its alpha.
4. Validate the mask and write color/shadow WebP pairs to development.
5. Emit a *candidate-only* index (ai_demo_candidates.json). Never append
   unapproved items to the playable development.json catalog. Production
   promotion is handled by Issue #31 after human review.

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
from validate_catalog import _mask_quality_errors

ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "assets/development/ai_demo_raw"
OUT_DIR = ROOT / "assets/development"
CANDIDATE_INDEX_PATH = ROOT / "assets/development/ai_demo_candidates.json"
PROMPTS_PATH = ROOT / "assets/generation/minimax_object_prompts.json"

SIZE = 512
SHADOW_RGB = (37, 49, 52)
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
    """Preserve a reviewed alpha matte; never guess background from RGB."""
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    lo, hi = alpha.getextrema()
    if lo == 255:
        raise ValueError(
            "fully opaque AI image; first remove its background with rembg "
            "(prepare_assets.py --bg-mode auto_draft), review *_rembg.png"
        )
    if hi == 0:
        raise ValueError("fully transparent AI image")
    quality_errors = _mask_quality_errors(alpha)
    if quality_errors:
        raise ValueError("bad silhouette alpha: " + "; ".join(quality_errors))
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
        # rembg drafts are deliberately not inferred from colors in the raw
        # image. A human must inspect and keep the transparent draft first.
        reviewed = raw.with_name(f"{raw.stem}_rembg.png")
        input_path = reviewed if reviewed.is_file() else raw
        try:
            with Image.open(input_path) as image:
                cropped = _center_crop(image, SIZE)
            transparent = _background_mask(cropped)
            color, shadow = _write_pair(item_id, transparent, force=args.force)
        except (OSError, ValueError, FileExistsError) as exc:
            print(f"cannot prepare {item_id}: {exc}", file=sys.stderr)
            return 1
        new_entries.append(_build_entry(item_id, prompts))
        print(f"candidate {color.relative_to(ROOT)} + {shadow.relative_to(ROOT)}")

    # Quarantine: the development gameplay catalog is intentionally
    # untouched. Candidate adoption must go through human review (#31).
    CANDIDATE_INDEX_PATH.parent.mkdir(parents=True, exist_ok=True)
    CANDIDATE_INDEX_PATH.write_text(
        json.dumps(
            {
                "version": 1,
                "approved": False,
                "assets_note": (
                    "UNREVIEWED AI demos. NOT a playable catalog. "
                    "Do not merge into development.json or items.json. "
                    "Review masks at 96dp before Issue #31 promotion."
                ),
                "items": new_entries,
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"wrote candidate-only index {CANDIDATE_INDEX_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
