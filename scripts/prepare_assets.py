"""Normalize transparent source PNGs and derive identical silhouettes.

Usage:
  python scripts/prepare_assets.py --input assets/source
  python scripts/prepare_assets.py --input assets/source --ids gel_star,cloud_cushion
  python scripts/prepare_assets.py --input assets/source --bg-mode auto_draft --strict

Two operating modes are supported:

* ``raw`` (default): input PNGs **must already have an alpha channel that
  represents the object**. Fully opaque or fully transparent images are
  rejected so we never silently ship a broken silhouette. This is the same
  behaviour the v4 pipeline had.

* ``auto_draft``: if an input PNG is opaque we attempt a CPU-only background
  removal with the optional `rembg` package and write a draft file alongside
  the source. The derived transparent draft is then treated like a normal
  input. If `rembg` is not available the script aborts with instructions
  instead of silently shipping an opaque original.

For every accepted input the script produces two 512×512 WebP files in
``--output`` (default: ``assets/items``):

* ``<id>.webp`` — colour original on a transparent canvas.
* ``<id>_shadow.webp`` — dark silhouette that uses the same alpha channel.

Both files share an identical alpha mask; the python validator confirms this
lossless match before the catalog is committed.
"""
from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path
from typing import Iterable

from PIL import Image

SIZE = 512
MARGIN = 35
SHADOW_RGB = (37, 49, 52)
ID_PATTERN = re.compile(r"^[a-z0-9_]+$")


def _is_valid_id(value: str) -> bool:
    return bool(value) and len(value) <= 64 and ID_PATTERN.fullmatch(value) is not None


def _has_alpha(image: Image.Image) -> bool:
    return image.mode in ("RGBA", "LA") or "A" in image.getbands()


def _auto_remove_background(source: Path) -> Path:
    """Return a transparent draft for *source* using `rembg` if available.

    The draft is written next to the source (so the gitignored
    ``assets/source`` keeps the artefact locally) and never replaces the
    original input. If `rembg` is not installed we raise with a precise
    explanation so the operator knows what to do next.
    """
    try:
        from rembg import remove  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            "background_mode=auto_draft requires the optional 'rembg' "
            "package. Install it once with `python -m pip install rembg` "
            "and re-run, or pre-process images offline and keep this "
            "script in raw mode."
        ) from exc
    destination = source.with_name(f"{source.stem}_rembg.png")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as original:
        original.load()
        cut = remove(original)
    cut.save(destination)
    return destination


def process_file(source: Path, destination: Path) -> str:
    """Convert a transparent source PNG into a color WebP + matching shadow."""
    original = Image.open(source).convert("RGBA")
    alpha = original.getchannel("A")
    lo, hi = alpha.getextrema()
    if lo == 255:
        raise ValueError(
            f"{source}: fully opaque image; remove the background or use --bg-mode auto_draft",
        )
    if hi == 0:
        raise ValueError(f"{source}: fully transparent image")

    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError(f"{source}: empty alpha channel")
    object_only = original.crop(bbox)
    object_only.thumbnail(
        (SIZE - MARGIN * 2, SIZE - MARGIN * 2),
        Image.Resampling.LANCZOS,
    )
    output = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    x = (SIZE - object_only.width) // 2
    y = (SIZE - object_only.height) // 2
    output.alpha_composite(object_only, (x, y))

    destination.mkdir(parents=True, exist_ok=True)
    color_target = destination / f"{source.stem}.webp"
    output.save(color_target, format="WEBP", quality=88, method=6)

    silhouette = Image.new("RGBA", (SIZE, SIZE), (*SHADOW_RGB, 0))
    silhouette.putalpha(output.getchannel("A"))
    shadow_target = destination / f"{source.stem}_shadow.webp"
    silhouette.save(shadow_target, format="WEBP", lossless=True, method=6)
    print(f"processed: {source.stem}")
    return source.stem


def _select_inputs(source_dir: Path, only_ids: Iterable[str] | None) -> list[Path]:
    files = sorted(p for p in source_dir.glob("*.png") if p.is_file())
    if only_ids:
        wanted = set(only_ids)
        files = [p for p in files if p.stem in wanted]
        missing = wanted - {p.stem for p in files}
        if missing:
            raise FileNotFoundError(
                f"Requested ids not found in {source_dir}: {sorted(missing)}"
            )
    return files


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=Path("assets/source"))
    parser.add_argument("--output", type=Path, default=Path("assets/items"))
    parser.add_argument(
        "--ids",
        help="Comma-separated ids to process (default: every *.png in --input).",
    )
    parser.add_argument(
        "--bg-mode",
        choices=("raw", "auto_draft"),
        default="raw",
        help="raw requires a transparent PNG; auto_draft invokes rembg in-process.",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Fail fast when any id is unsafe or a rembg draft is missing.",
    )
    args = parser.parse_args()

    only_ids = None
    if args.ids:
        only_ids = [token.strip() for token in args.ids.split(",") if token.strip()]
        for token in only_ids:
            if not _is_valid_id(token):
                if args.strict:
                    raise ValueError(f"Unsafe item id: {token!r}")
                print(f"warning: skipping unsafe id {token!r}", file=sys.stderr)
                only_ids = [t for t in only_ids if t != token]

    files = _select_inputs(args.input, only_ids)
    if not files:
        raise SystemExit(f"No PNG files found in {args.input}")

    if args.output.resolve() == args.input.resolve():
        raise SystemExit(
            "--output must differ from --input to keep sources out of the bundle",
        )

    processed: list[str] = []
    for source in files:
        if not _is_valid_id(source.stem):
            if args.strict:
                raise ValueError(f"Unsafe filename id: {source.name}")
            print(f"warning: skipping {source.name} (unsafe id)", file=sys.stderr)
            continue
        work = source
        if args.bg_mode == "auto_draft":
            try:
                with Image.open(source) as probe:
                    if not _has_alpha(probe) or probe.convert("RGBA").getchannel("A").getextrema()[0] == 255:
                        work = _auto_remove_background(source)
                    else:
                        print(f"already transparent: {source.stem}")
            except Exception as exc:
                raise RuntimeError(f"background removal failed for {source}: {exc}") from exc
        processed.append(process_file(work, args.output))

    if not processed:
        raise SystemExit("No inputs were processed; check --ids and --strict flags")

    extras = args.output / "report.json"
    import json

    extras.write_text(
        json.dumps(
            {
                "generated_at": __import__("datetime").datetime.utcnow().isoformat() + "Z",
                "bg_mode": args.bg_mode,
                "ids": processed,
                "notes": (
                    "Source-of-truth: assets/source/*.png (gitignored). "
                    "Each entry pairs a colour WebP with an identical-alpha "
                    "shadow WebP; validate_catalog.py confirms the alpha match."
                ),
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"wrote {extras}")


if __name__ == "__main__":
    main()
