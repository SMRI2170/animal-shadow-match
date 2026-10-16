"""Generate an offline, 96px color-vs-shadow QA sheet (Issue #89).

This is a review artifact, not a playable catalog or an approval signal.
Example:
    python scripts/render_silhouette_sheet.py \
        --catalog assets/catalog/development.json \
        --output silhouette-qa.png
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
PADDING = 12
LABEL_H = 28
SWATCH = 96
GAP = 12


def render_sheet(
    root: Path,
    catalog: Path,
    output: Path,
    *,
    columns: int = 4,
) -> int:
    """Draw a labeled preview with color and shadow at actual 96px width."""
    if columns < 1:
        raise ValueError("columns must be positive")
    data = json.loads(catalog.read_text(encoding="utf-8"))
    entries = data.get("items", data.get("animals", []))
    if not isinstance(entries, list) or not entries:
        raise ValueError("catalog must contain at least one item")

    card_w = PADDING * 2 + SWATCH * 2 + GAP
    card_h = PADDING * 2 + LABEL_H + SWATCH
    rows = math.ceil(len(entries) / columns)
    canvas = Image.new(
        "RGB", (card_w * columns, card_h * rows), (241, 243, 246)
    )
    drawer = ImageDraw.Draw(canvas)
    for index, entry in enumerate(entries):
        x = (index % columns) * card_w
        y = (index // columns) * card_h
        drawer.rounded_rectangle(
            (x + 2, y + 2, x + card_w - 3, y + card_h - 3),
            radius=9,
            fill=(255, 255, 255),
            outline=(205, 210, 217),
        )
        item_id = str(entry["id"])
        drawer.text((x + PADDING, y + 7), item_id[:30], fill=(38, 46, 55))

        for offset, key in ((0, "image"), (SWATCH + GAP, "shadow")):
            path = root / entry[key]
            with Image.open(path) as asset:
                preview = asset.convert("RGBA")
            preview.thumbnail((SWATCH, SWATCH), Image.Resampling.LANCZOS)
            left = x + PADDING + offset + (SWATCH - preview.width) // 2
            top = y + PADDING + LABEL_H + (SWATCH - preview.height) // 2
            canvas.paste(preview, (left, top), preview.getchannel("A"))
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, format="PNG")
    return len(entries)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=Path("assets/catalog/development.json"))
    parser.add_argument("--output", type=Path, default=Path("silhouette-qa.png"))
    parser.add_argument("--columns", type=int, default=4)
    args = parser.parse_args()
    count = render_sheet(ROOT, ROOT / args.catalog, args.output, columns=args.columns)
    print(f"rendered {count} items to {args.output} (color | shadow, 96px each)")


if __name__ == "__main__":
    main()
