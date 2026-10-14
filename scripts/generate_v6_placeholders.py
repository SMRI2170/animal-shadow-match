"""Deterministic v6 placeholder generator.

Renders the 30-object catalog in ``assets/generation/minimax_object_prompts.json``
to transparent WebP pairs in ``assets/development/``. Each placeholder has:

* a 512x512 transparent canvas with the object centered;
* a "distinct major bump or notch" so silhouettes stay distinguishable at
  96dp (per docs/SINGLE_ASSET_OBJECT_GAME_JA.md §5);
* a colour image and an identical-alpha shadow written by the same alpha.

Run with::

    python scripts/generate_v6_placeholders.py                 # write all 30
    python scripts/generate_v6_placeholders.py --ids a,b,c     # subset
    python scripts/generate_v6_placeholders.py --dry-run       # preview JSON
    python scripts/generate_v6_placeholders.py --strict        # abort on unsafe ids

The output of this script is intended **only** for the
``ENABLE_DEVELOPMENT_ASSETS=1`` build variant; production builds never
read ``assets/development/``.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "assets/generation/minimax_object_prompts.json"
OUT_DIR = ROOT / "assets/development"
OUT_JSON = ROOT / "assets/catalog/development.json"

SIZE = 512
SHADOW_RGB = (37, 49, 52)
ID_PATTERN = re.compile(r"^[a-z0-9_]+$")


@dataclass(frozen=True)
class Style:
    fill: tuple[int, int, int, int]
    accent: tuple[int, int, int, int]


STYLE_BY_CATEGORY: dict[str, Style] = {
    "jelly": Style(fill=(186, 142, 230, 235), accent=(228, 200, 255, 255)),
    "toys": Style(fill=(102, 178, 222, 235), accent=(170, 220, 245, 255)),
    "cosmic": Style(fill=(244, 174, 110, 235), accent=(255, 220, 170, 255)),
}


def _safe_id(value: str) -> bool:
    return bool(value) and len(value) <= 64 and ID_PATTERN.fullmatch(value) is not None


def _punch_hole(canvas: Image.Image, box: tuple[int, int, int, int]) -> None:
    """Erase alpha pixels inside *box*; used for ring/loop/arch holes."""
    mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(mask).ellipse(box, fill=255)
    pixels = canvas.load()
    mp = mask.load()
    for y in range(canvas.size[1]):
        for x in range(canvas.size[0]):
            if mp[x, y]:
                pixels[x, y] = (0, 0, 0, 0)


Drawer = Callable[[Image.Image, ImageDraw.ImageDraw, Style], None]


def _draw_blob(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    d.ellipse((100, 130, 380, 410), fill=s.fill)
    # Distinctive bump top-right so silhouettes always have a notch.
    d.ellipse((305, 90, 410, 200), fill=s.fill)
    d.ellipse((150, 165, 230, 230), fill=s.accent)


def _draw_star(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    points = [
        (250, 70), (300, 200), (430, 200), (335, 290),
        (370, 430), (250, 350), (130, 430), (165, 290),
        (70, 200), (200, 200),
    ]
    d.polygon(points, fill=s.fill)
    d.ellipse((175, 200, 290, 290), fill=s.accent)


def _draw_ring(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    d.ellipse((80, 130, 432, 410), fill=s.fill)
    d.ellipse((200, 220, 312, 332), fill=s.fill)
    _punch_hole(c, (200, 220, 312, 332))


def _draw_loop(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    d.ellipse((60, 160, 260, 380), fill=s.fill)
    d.ellipse((250, 130, 450, 350), fill=s.fill)
    d.ellipse((120, 220, 200, 300), fill=s.fill)
    d.ellipse((310, 190, 390, 270), fill=s.fill)
    _punch_hole(c, (120, 220, 200, 300))
    _punch_hole(c, (310, 190, 390, 270))


def _draw_twist(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    d.polygon(
        [
            (90, 250), (200, 150), (320, 250), (430, 150),
            (430, 280), (320, 380), (200, 280), (90, 380),
        ],
        fill=s.fill,
    )
    d.ellipse((220, 215, 290, 285), fill=s.accent)


def _draw_arch(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    d.ellipse((140, 70, 372, 302), fill=s.fill)
    d.rectangle((140, 240, 372, 430), fill=s.fill)
    d.rectangle((170, 300, 342, 430), fill=s.fill)
    d.ellipse((220, 320, 292, 380), fill=s.fill)
    _punch_hole(c, (170, 300, 342, 430))


def _draw_cube(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    d.rounded_rectangle((130, 150, 380, 400), radius=40, fill=s.fill)
    d.ellipse((200, 220, 320, 320), fill=s.accent)


def _draw_planet(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    d.ellipse((140, 140, 372, 372), fill=s.fill)
    d.ellipse((40, 200, 472, 320), outline=s.fill, width=28)


def _draw_crystal(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    d.polygon(
        [
            (250, 70), (380, 180), (420, 320), (300, 430),
            (180, 400), (90, 280), (140, 160),
        ],
        fill=s.fill,
    )
    d.polygon([(220, 130), (320, 200), (270, 290), (160, 240)], fill=s.accent)


def _draw_asteroid(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    d.ellipse((110, 160, 412, 412), fill=s.fill)
    d.ellipse((180, 220, 250, 290), fill=s.fill)
    d.ellipse((300, 270, 380, 350), fill=s.fill)
    _punch_hole(c, (180, 220, 250, 290))
    _punch_hole(c, (300, 270, 380, 350))


def _draw_meteor(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    d.polygon(
        [(380, 90), (470, 200), (430, 320), (300, 410), (180, 380), (150, 240)],
        fill=s.fill,
    )
    d.polygon([(150, 240), (60, 280), (180, 380)], fill=s.fill)


def _draw_comet(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    d.ellipse((140, 140, 380, 380), fill=s.fill)
    d.polygon([(380, 240), (470, 220), (480, 280), (380, 300)], fill=s.fill)
    d.ellipse((220, 220, 300, 300), fill=s.accent)


def _draw_moon_stone(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    d.ellipse((120, 200, 420, 380), fill=s.fill)
    d.polygon([(120, 280), (60, 240), (90, 320)], fill=s.fill)


def _draw_petal_stone(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    d.ellipse((180, 160, 340, 320), fill=s.fill)
    for cx, cy in [(155, 250), (365, 250), (175, 380), (340, 380), (250, 140)]:
        d.ellipse((cx - 50, cy - 60, cx + 50, cy + 60), fill=s.fill)


def _draw_disc(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    """Wavy/scalloped disk used by Stack/Disc/etc."""
    d.ellipse((80, 100, 432, 452), fill=s.fill)
    for i in range(8):
        cx = 80 + (432 - 80) * i // 8 + 22
        d.ellipse((cx - 16, 80, cx + 16, 130), fill=s.fill)
        d.ellipse((cx - 16, 420, cx + 16, 470), fill=s.fill)


def _draw_spring(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    d.ellipse((110, 80, 402, 432), outline=s.fill, width=46)


def _draw_cone(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    d.polygon([(110, 400), (402, 400), (256, 110)], fill=s.fill)
    d.arc((140, 140, 372, 372), start=120, end=300, fill=s.accent, width=18)


def _draw_cross(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    d.rounded_rectangle((110, 220, 402, 332), radius=28, fill=s.fill)
    d.rounded_rectangle((220, 110, 332, 432), radius=28, fill=s.fill)


def _draw_heart(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    d.ellipse((120, 170, 280, 320), fill=s.fill)
    d.ellipse((252, 170, 412, 320), fill=s.fill)
    d.polygon([(140, 280), (392, 280), (266, 440)], fill=s.fill)


def _draw_default(c: Image.Image, d: ImageDraw.ImageDraw, s: Style) -> None:
    d.ellipse((110, 110, 402, 402), fill=s.fill)
    d.ellipse((300, 80, 410, 190), fill=s.fill)


_KEYWORD_TABLE: list[tuple[tuple[str, ...], Drawer]] = [
    (("star",), _draw_star),
    (("planet",), _draw_planet),
    (("ring", "donut"), _draw_ring),
    (("loop", "figure-eight", "figure eight"), _draw_loop),
    (("twist", "ribbon"), _draw_twist),
    (("arch", "horseshoe"), _draw_arch),
    (("cube", "block"), _draw_cube),
    (("crystal", "prism"), _draw_crystal),
    (("asteroid",), _draw_asteroid),
    (("meteor",), _draw_meteor),
    (("comet",), _draw_comet),
    (("moon_stone", "crescent", "moon stone"), _draw_moon_stone),
    (("petal",), _draw_petal_stone),
    (("disk", "disc"), _draw_disc),
    (("spring", "coil"), _draw_spring),
    (("cone", "spiral"), _draw_cone),
    (("cross",), _draw_cross),
    (("heart",), _draw_heart),
]


def _select_drawer(shape: str, category: str) -> Drawer:
    text = shape.lower()
    for keywords, fn in _KEYWORD_TABLE:
        if any(word in text for word in keywords):
            return fn
    if category == "cosmic":
        return _draw_crystal
    if category == "toys":
        return _draw_arch
    return _draw_blob


def render_one(item: dict) -> tuple[Path, Path]:
    style = STYLE_BY_CATEGORY.get(item["category"], STYLE_BY_CATEGORY["jelly"])
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    _select_drawer(item["shape"], item["category"])(canvas, ImageDraw.Draw(canvas), style)
    out_dir = OUT_DIR
    out_dir.mkdir(parents=True, exist_ok=True)
    color_target = out_dir / f"{item['id']}.webp"
    canvas.save(color_target, format="WEBP", quality=88, method=6)
    alpha = canvas.getchannel("A")
    shadow = Image.new("RGBA", (SIZE, SIZE), (*SHADOW_RGB, 0))
    shadow.putalpha(alpha)
    shadow_target = out_dir / f"{item['id']}_shadow.webp"
    shadow.save(shadow_target, format="WEBP", lossless=True, method=6)
    return color_target, shadow_target


def load_catalog() -> dict:
    if not CATALOG_PATH.is_file():
        raise SystemExit(f"Missing: {CATALOG_PATH}")
    return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))


def write_development_index(entries: list[dict]) -> None:
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(
        json.dumps(
            {
                "version": 1,
                "assets_note": (
                    "Auto-generated by scripts/generate_v6_placeholders.py. "
                    "Only read when ENABLE_DEVELOPMENT_ASSETS=1."
                ),
                "items": entries,
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ids", default="", help="Comma-separated subset.")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args(argv)

    catalog = load_catalog()
    items = catalog.get("items", [])
    if not isinstance(items, list) or not items:
        raise SystemExit("Catalog has no items.")

    if args.ids:
        wanted = {token.strip() for token in args.ids.split(",") if token.strip()}
        items = [item for item in items if item["id"] in wanted]
        if not items:
            raise SystemExit(f"No items matched: {args.ids}")

    for item in items:
        if not _safe_id(item["id"]):
            if args.strict:
                raise SystemExit(f"Unsafe id: {item['id']}")
            print(f"warning: unsafe id {item['id']!r} skipped", file=sys.stderr)
            continue
        if args.dry_run:
            print(f"DRY: would render {item['id']} ({item['category']})")
            continue
        color, shadow = render_one(item)
        print(f"wrote {color.relative_to(ROOT)} + {shadow.relative_to(ROOT)}")

    if args.dry_run:
        return 0

    write_development_index([
        {
            "id": item["id"],
            "image": f"assets/development/{item['id']}.webp",
            "shadow": f"assets/development/{item['id']}_shadow.webp",
            "category": item["category"],
            "distractors": [],
            "effectPreset": item.get("effectPreset", "squish"),
            "silhouetteFeatures": ["placeholder"],
        }
        for item in items
        if _safe_id(item["id"])
    ])
    print(f"wrote {OUT_JSON.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
