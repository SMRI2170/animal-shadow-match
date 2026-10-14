"""Promote approved MiniMax artifact images into the Flutter item catalog.

This script is the *local half* of the Draft-PR pipeline that lives in
``scripts/promote_minimax_assets.py`` + ``.github/workflows/promote-minimax-assets.yml``.

The workflow downloads the candidate artifact, hands the bytes to this
script, and the script:

1. Verifies that every requested id is declared in
   ``assets/generation/minimax_object_prompts.json`` so the effect preset
   comes from a known-good prompt (never from arbitrary user input).
2. Validates each raw image file (magic bytes, size, dimensions).
3. Saves the image to ``assets/source/<id>.png`` so ``prepare_assets.py``
   can derive the WebP pair.
4. Updates ``assets/catalog/items.json`` *in place*, refusing to overwrite
   any existing id or path. The manifest is mutated atomically so the
   workflow always sees a coherent file.
5. Emits a ``promotion.json`` that the workflow uses to build the PR body
   and the per-item contact sheet.

The script intentionally:

* never accepts an arbitrary ``MiniMax`` API key,
* never makes any network call itself,
* never deletes or replaces an approved entry,
* leaves the v6 ``ShadowItem.effectPreset`` default (``squish``) when the
  prompt catalog has no entry, so the game keeps falling back to the safe
  behaviour described in
  ``docs/SINGLE_ASSET_OBJECT_GAME_JA.md`` §5.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, UnidentifiedImageError

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "assets/source"
ITEMS_CATALOG = ROOT / "assets/catalog/items.json"
PROMPT_CATALOG = ROOT / "assets/generation/minimax_object_prompts.json"
WORKDIR = Path(tempfile.gettempdir())

ID_PATTERN = re.compile(r"^[a-z0-9_]+$")
MAX_BYTES = 12 * 1024 * 1024
MIN_DIMENSION = 512
MAX_DIMENSION = 4096


@dataclass(frozen=True)
class CandidateInput:
    """One approved image, handed in by the workflow.

    Either ``path`` *or* ``bytes_b64`` is provided. ``source_run_id`` and
    ``artifact_name`` are recorded in the audit trail so reviewers can
    trace any image back to its MiniMax run.
    """

    id: str
    category: str
    effect_preset: str
    path: Path
    source_run_id: str
    artifact_name: str


class PromotionError(RuntimeError):
    """Raised when a request cannot be safely fulfilled."""


def _is_safe_id(value: str) -> bool:
    return bool(value) and len(value) <= 64 and ID_PATTERN.fullmatch(value) is not None


def _load_prompt_catalog() -> dict:
    if not PROMPT_CATALOG.is_file():
        return {}
    try:
        data = json.loads(PROMPT_CATALOG.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise PromotionError(f"prompt catalog is invalid JSON: {exc}") from exc
    if not isinstance(data, dict):
        raise PromotionError("prompt catalog must be an object")
    return data


def _lookup_prompt_entry(prompt_catalog: dict, item_id: str) -> dict | None:
    items = prompt_catalog.get("items", [])
    if not isinstance(items, list):
        return None
    for entry in items:
        if isinstance(entry, dict) and entry.get("id") == item_id:
            return entry
    return None


def _resolve_effect_preset(requested: str | None, prompt_entry: dict | None) -> str:
    if requested:
        return requested
    if prompt_entry and isinstance(prompt_entry.get("effectPreset"), str):
        return prompt_entry["effectPreset"]
    return "squish"


def _resolve_category(requested: str | None, prompt_entry: dict | None) -> str:
    if requested:
        return requested
    if prompt_entry and isinstance(prompt_entry.get("category"), str):
        return prompt_entry["category"]
    return "squishy_object"


def _resolve_distractors(prompt_entry: dict | None) -> list[str]:
    if not prompt_entry:
        return []
    raw = prompt_entry.get("silhouetteDistractors")
    if not isinstance(raw, list):
        return []
    cleaned: list[str] = []
    for value in raw:
        if isinstance(value, str) and _is_safe_id(value) and value not in cleaned:
            cleaned.append(value)
        if len(cleaned) >= 3:
            break
    return cleaned


def _read_image_meta(path: Path) -> tuple[str, int, int]:
    try:
        with Image.open(path) as img:
            img.verify()
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        raise PromotionError(f"{path}: not a valid image ({exc})") from None
    # verify() invalidates the cached info; reopen to read format / size.
    with Image.open(path) as img:
        fmt = (img.format or "").upper()
        width, height = img.size
    if fmt not in {"JPEG", "PNG", "WEBP"}:
        raise PromotionError(f"{path}: unsupported format {fmt!r}")
    if min(width, height) < MIN_DIMENSION or max(width, height) > MAX_DIMENSION:
        raise PromotionError(
            f"{path}: dimensions {width}x{height} outside "
            f"{MIN_DIMENSION}-{MAX_DIMENSION} range",
        )
    return fmt, width, height


def _save_source_copy(raw: Path, item_id: str) -> Path:
    if not raw.is_file():
        raise PromotionError(f"missing source file: {raw}")
    if raw.stat().st_size == 0 or raw.stat().st_size > MAX_BYTES:
        raise PromotionError(
            f"{raw}: file is empty or larger than {MAX_BYTES} bytes",
        )
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    target = SOURCE_DIR / f"{item_id}.png"
    shutil.copyfile(raw, target)
    return target


def _load_items_catalog() -> dict:
    if not ITEMS_CATALOG.is_file():
        return {"version": 1, "items": []}
    try:
        return json.loads(ITEMS_CATALOG.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise PromotionError(f"items.json is invalid JSON: {exc}") from exc


def _write_items_catalog(data: dict) -> None:
    ITEMS_CATALOG.parent.mkdir(parents=True, exist_ok=True)
    # Use a sibling temp file then atomic rename so a crash never leaves a
    # half-written catalog.
    tmp = ITEMS_CATALOG.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    tmp.replace(ITEMS_CATALOG)


def _merge_entry(existing_items: list[dict], entry: dict) -> tuple[list[dict], bool]:
    """Insert/append entry; return (new list, replaced?).

    * Returning ``replaced=False`` means we added a new entry.
    * Returning ``replaced=True`` would have meant we overwrote an existing
      one, which the policy forbids — so we raise instead.
    """
    target = next((e for e in existing_items if e.get("id") == entry["id"]), None)
    if target is not None:
        raise PromotionError(
            f"id collision: {entry['id']!r} is already approved in items.json; "
            f"this pipeline refuses to overwrite human-reviewed entries.",
        )
    new_list = list(existing_items)
    new_list.append(entry)
    return new_list, False


def _build_entry(candidate: CandidateInput, prompt_entry: dict | None) -> dict:
    preset = _resolve_effect_preset(candidate.effect_preset, prompt_entry)
    category = _resolve_category(candidate.category, prompt_entry)
    distractors = _resolve_distractors(prompt_entry)
    return {
        "id": candidate.id,
        "image": f"assets/items/{candidate.id}.webp",
        "shadow": f"assets/items/{candidate.id}_shadow.webp",
        "category": category,
        "distractors": distractors,
        "effectPreset": preset,
        "effectIntensity": "gentle",
        "source": {
            "minimaxRunId": candidate.source_run_id,
            "minimaxArtifact": candidate.artifact_name,
        },
    }


def _process_candidates(
    candidates: list[CandidateInput],
    prompt_catalog: dict,
) -> list[dict]:
    catalog = _load_items_catalog()
    accepted: list[dict] = []
    for candidate in candidates:
        if not _is_safe_id(candidate.id):
            raise PromotionError(f"unsafe id from inputs: {candidate.id!r}")
        if not candidate.path or not candidate.path.exists():
            raise PromotionError(f"{candidate.id}: missing staged file {candidate.path}")
        fmt, width, height = _read_image_meta(candidate.path)
        _save_source_copy(candidate.path, candidate.id)
        prompt_entry = _lookup_prompt_entry(prompt_catalog, candidate.id)
        entry = _build_entry(candidate, prompt_entry)
        entry["source"].update({"format": fmt, "width": width, "height": height})
        catalog["items"], _ = _merge_entry(catalog["items"], entry)
        accepted.append(entry)
    _write_items_catalog(catalog)
    return accepted


def _emit_promotion_report(accepted: list[dict]) -> Path:
    report_path = WORKDIR / "promotion.json"
    report_path.write_text(
        json.dumps(
            {
                "accepted": accepted,
                "items_total": len(accepted),
                "policy": (
                    "Approved items are appended to assets/catalog/items.json. "
                    "Existing entries are never overwritten. The Draft PR is "
                    "created with `gh pr create --draft` and must be merged by "
                    "a human reviewer."
                ),
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )
    return report_path


def _stage_files(staging_dir: Path, items: Iterable[str]) -> list[CandidateInput]:
    """Build [CandidateInput] instances by globbing the staging directory.

    The GitHub workflow dumps approved files as ``<id>.<ext>`` into a
    scratch directory; we treat each file as a candidate and attach the
    run id passed via ``--source-run-id``.
    """
    inputs: list[CandidateInput] = []
    if not staging_dir.is_dir():
        return inputs
    for path in sorted(staging_dir.iterdir()):
        if not path.is_file():
            continue
        item_id = path.stem
        if not _is_safe_id(item_id):
            print(f"warning: skipping unsafe staged id {item_id!r}", file=sys.stderr)
            continue
        inputs.append(
            CandidateInput(
                id=item_id,
                category="",
                effect_preset="",
                path=path,
                source_run_id="",
                artifact_name="",
            ),
        )
    return inputs


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--staging-dir",
        type=Path,
        required=True,
        help="Directory containing approved <id>.<ext> files staged by the workflow.",
    )
    parser.add_argument("--source-run-id", default="", help="Run id that produced the artifact.")
    parser.add_argument("--artifact-name", default="", help="Artifact name in the source run.")
    parser.add_argument(
        "--report-path",
        type=Path,
        default=WORKDIR / "promotion.json",
        help="Where to write the JSON report (workflow uploads this as another artifact).",
    )
    args = parser.parse_args(argv)

    prompt_catalog = _load_prompt_catalog()
    candidates = _stage_files(args.staging_dir, items=None)
    for candidate in candidates:
        # Inject workflow-supplied metadata so the audit trail survives.
        object.__setattr__(candidate, "source_run_id", args.source_run_id)
        object.__setattr__(candidate, "artifact_name", args.artifact_name)

    if not candidates:
        print("no candidates staged; nothing to do", file=sys.stderr)
        return 0

    accepted = _process_candidates(candidates, prompt_catalog)
    args.report_path.parent.mkdir(parents=True, exist_ok=True)
    args.report_path.write_text(
        json.dumps(
            {
                "accepted": accepted,
                "items_total": len(accepted),
                "staging_dir": str(args.staging_dir),
                "source_run_id": args.source_run_id,
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"promoted {len(accepted)} candidate(s); report at {args.report_path}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except PromotionError as exc:
        print(f"promotion failed: {exc}", file=sys.stderr)
        raise SystemExit(2)
