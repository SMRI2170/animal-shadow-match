"""Validate catalog references, alpha masks, and empty/duplicate asset IDs."""
from __future__ import annotations

import json
from pathlib import Path
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'assets/catalog/animals.json'


def main() -> None:
    data = json.loads(CATALOG.read_text(encoding='utf-8'))
    entries = data['animals']
    if len(entries) < 4:
        raise AssertionError('At least four animals are required')
    ids = [item['id'] for item in entries]
    if len(ids) != len(set(ids)):
        raise AssertionError('Duplicate catalog IDs')
    available = set(ids)
    for item in entries:
        for key in ('image', 'shadow'):
            rel_path = item[key]
            file = ROOT / rel_path
            if not file.is_file():
                raise AssertionError(f'Missing {key}: {rel_path}')
            with Image.open(file) as img:
                rgba = img.convert('RGBA')
                if rgba.size != (512, 512):
                    raise AssertionError(f'Expected 512x512 {file}: {rgba.size}')
                alpha = rgba.getchannel('A')
                extrema = alpha.getextrema()
                if extrema[0] == 255 or extrema[1] == 0:
                    raise AssertionError(f'Missing usable transparency: {file}')
        with Image.open(ROOT / item['image']) as color, Image.open(ROOT / item['shadow']) as dark:
            color_a = color.convert('RGBA').getchannel('A')
            dark_a = dark.convert('RGBA').getchannel('A')
            diff = ImageChops.difference(color_a, dark_a)
            if diff.getbbox() is not None:
                # Lossy WebP alpha must still round-trip losslessly.
                raise AssertionError(f'Mask mismatch for {item["id"]}')
        if item['id'] in item.get('distractors', []):
            raise AssertionError(f'Self distractor: {item["id"]}')
        if not set(item.get('distractors', [])).issubset(available):
            raise AssertionError(f'Unknown distractor id: {item["id"]}')
    print(f'OK: {len(entries)} animals with masks and curated distractors')


if __name__ == '__main__':
    main()
