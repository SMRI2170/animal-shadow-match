"""Normalize transparent source PNGs and derive identical silhouettes.

Usage:
  python scripts/prepare_assets.py --input assets/source

IMPORTANT: source PNGs must ALREADY have a real transparent background. Images
with an opaque background are deliberately rejected to avoid broken shadows.
"""
from __future__ import annotations

import argparse
from pathlib import Path
from PIL import Image

SIZE = 512
MARGIN = 35
SHADOW_RGB = (37, 49, 52)


def process_file(source: Path, destination: Path) -> None:
    original = Image.open(source).convert('RGBA')
    alpha = original.getchannel('A')
    lo, hi = alpha.getextrema()
    if lo == 255:
        raise ValueError(f'{source}: fully opaque image: remove the background first')
    if hi == 0:
        raise ValueError(f'{source}: fully transparent image')
    bbox = alpha.getbbox()
    assert bbox is not None
    object_only = original.crop(bbox)
    object_only.thumbnail((SIZE - MARGIN * 2, SIZE - MARGIN * 2), Image.Resampling.LANCZOS)
    output = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    x = (SIZE - object_only.width) // 2
    y = (SIZE - object_only.height) // 2
    output.alpha_composite(object_only, (x, y))
    destination.mkdir(parents=True, exist_ok=True)
    output.save(destination / f'{source.stem}.webp', format='WEBP', quality=88, method=6)

    silhouette = Image.new('RGBA', (SIZE, SIZE), (*SHADOW_RGB, 0))
    silhouette.putalpha(output.getchannel('A'))
    silhouette.save(destination / f'{source.stem}_shadow.webp', format='WEBP', lossless=True, method=6)
    print(f'processed: {source.stem}')


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, default=Path('assets/source'))
    parser.add_argument('--output', type=Path, default=Path('assets/animals'))
    args = parser.parse_args()
    files = sorted(args.input.glob('*.png'))
    if not files:
        raise SystemExit(f'No PNG files found in {args.input}')
    for file in files:
        process_file(file, args.output)


if __name__ == '__main__':
    main()
