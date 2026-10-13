# MiniMax art production and silhouette pipeline

## Source model

Use the available MiniMax image-generation product, e.g. `image-01`, for **independent images**. Do not ask the model to create a shadow image, a matching pair, a grid, a layered UI, or a specific difference between two scenes. The **only** strict requirement is one distinguishable animal per image.

## Consistent English prompt template

```text
One single adorable baby {ANIMAL}, full body, recognizable natural silhouette,
soft 3D clay toy illustration, rounded friendly proportions, matte material,
pastel colors, diffuse studio lighting, centered, limbs and tail clearly visible,
one character only, no accessories, no overlapping objects, simple uniform white
background for easy segmentation, generous empty margins, no cast shadow,
no ground, no words, no logos, no watermark, square composition.
```

Use different safe poses when necessary, **but never require identical poses across generations**. Keep the same stylistic baseline per batch. If results are watercolor rather than 3D, allow them as a separate future art pack, rather than mixing styles within a small group.

## Processing procedure

```bash
python -m pip install -r scripts/requirements.txt
# Remove backgrounds with an offline tool of choice; review masks manually.
# Store approved, already-transparent PNGs as assets/source/elephant.png etc.
python scripts/prepare_assets.py --input assets/source
python scripts/validate_catalog.py
```

The script crops to nontransparent bounds, scales to a centered 512x512 transparent canvas, writes the animal as WebP and a dark silhouette with the **identical alpha channel**. It refuses fully opaque images: do not silently assume AI-generated white backgrounds are alpha transparent.

Optional segmentation utilities such as `rembg` may be installed separately, but are **not** required by the gameplay app. Always review segmentation; an automated remover can cut off whiskers, thin antennae, tails, or ears.

## Asset review rubric

| Check | Accept | Reject |
|---|---|---|
| One subject | Exactly one recognizable animal | Several animals, distracting props |
| Silhouette | Head/tail/appendages remain identifiable when black | Could be confused with chosen distractors |
| Alpha | Clean mask at edges | Missing limbs, white outline, background artifacts |
| Composition | Whole body with margin | Part clipped, fills entire frame |
| Child safety | Friendly, age-appropriate and nonviolent | Scary, harmful, sexual, violent or confusing imagery |
| Consistency | Same broad art style within category | Photo combined with clay/cartoon in same early pack |
| Metadata | ID, accessible label, curated distractors | Wrong animal label or duplicated ID |

### QA design

At MVP scale, **human review is mandatory**. Prioritize ambiguity checks on *pairs* of silhouettes used in the same question; even perfectly generated individual animals may make a poor combination. `validate_catalog.py` checks masks and references, but cannot certify that a 3-year-old distinguishes them.

## Scale plan

- Phase A: 8 demo images (included, not release artwork).
- Phase B: 20 manually reviewed MiniMax images. Observe 2- and 3-choice usability.
- Phase C: 100 images, category diversity, batch processing and content review.
- Phase D: 200+ images only if file size and content quality remain acceptable.

At hundreds of assets, record model name, generation date, prompt template version, reviewer, and license/commercial-use verification outside the game runtime. Store optimized source and shadow together; no AI-generated image needs to be fetched by the app.
