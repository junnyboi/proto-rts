# Food Building Generation Prompts

These project-bound source masters were generated with the built-in GPT Image 2 workflow on 2 September 2026. The Human War Camp and Beast Stronghold masters were supplied only as style, camera, lighting, isolation-background, and rendering-detail references.

## `buildings/rice_farm.png`

```text
Use case: stylized-concept
Asset type: runtime strategy-game building sprite source master
Primary request: create a compact ancient Chinese-inspired rice farm that reads instantly as a food-producing RTS structure.
Input images: Image 1 and Image 2 are style, camera, lighting, isolation-background, and rendering-detail references only; do not copy either building.
Scene/backdrop: a completely uniform, pure electric magenta (#ff00ff) isolation background extending to every edge.
Subject: one complete rice farm on a tidy square footprint, with terraced golden-green rice paddies, narrow irrigation channels, a small timber-and-tile granary shelter, grain baskets, and a simple water wheel. No people or animals.
Style/medium: polished painterly 2D isometric fantasy strategy-game illustration with crisp silhouette, detailed hand-painted materials, and production-ready readability matching the reference assets.
Composition/framing: three-quarter isometric view from above, centered, entire structure and base visible, generous clear magenta margin on all sides, no cropping.
Lighting/mood: unified soft upper-left daylight, grounded but no cast shadow outside the structure footprint.
Color palette: natural rice gold, celadon green, dark timber, muted gray roof tile; faction-neutral.
Constraints: exactly one structure; square readable footprint; flat pure magenta background; no text, labels, icons, border, UI, watermark, characters, wildlife, extra buildings, scenery, horizon, ground plane, or transparent pixels.
Avoid: photorealism, 3D UI render, blurred edges, magenta spill on the subject, cropped silhouette, floating parts.
```

## `buildings/hunters_lodge.png` (superseded source)

```text
Use case: stylized-concept
Asset type: runtime strategy-game building sprite source master
Primary request: create a compact ancient Chinese-inspired hunter's lodge that reads instantly as a fast food-producing RTS structure.
Input images: Image 1 and Image 2 are style, camera, lighting, isolation-background, and rendering-detail references only; do not copy either building.
Scene/backdrop: a completely uniform, pure electric magenta (#ff00ff) isolation background extending to every edge.
Subject: one complete timber hunter's lodge on a compact square footprint, with a tiled smokehouse roof, covered drying racks, bundled bows, hanging empty game snares, stacked travel baskets, woodpile, and a small smoking chimney. No carcasses, blood, people, or living animals.
Style/medium: polished painterly 2D isometric fantasy strategy-game illustration with crisp silhouette, detailed hand-painted materials, and production-ready readability matching the reference assets.
Composition/framing: three-quarter isometric view from above, centered, entire structure and base visible, generous clear magenta margin on all sides, no cropping.
Lighting/mood: unified soft upper-left daylight, grounded but no cast shadow outside the structure footprint.
Color palette: dark timber, weathered gray tile, forest green cloth, warm leather and copper accents; faction-neutral.
Constraints: exactly one structure; compact square readable footprint; flat pure magenta background; no text, labels, icons, border, UI, watermark, characters, wildlife, extra buildings, scenery, horizon, ground plane, or transparent pixels.
Avoid: gore, meat, photorealism, 3D UI render, blurred edges, magenta spill on the subject, cropped silhouette, floating parts.
```

The initial lodge's semi-transparent smoke inherited the isolation color at its edges. The original is retained for provenance; runtime processing uses the non-destructive revision below.

## `buildings/hunters_lodge_v2.png` (active source)

```text
Use case: precise-object-edit
Asset type: runtime strategy-game building sprite source master
Primary request: change only the chimney smoke above the Hunter's Lodge from pink/magenta to opaque warm light gray smoke with crisp painterly edges.
Input images: Image 1 is the edit target.
Constraints: preserve the lodge, footprint, proportions, camera, lighting, colors, detail, composition, and pure electric magenta (#ff00ff) isolation background exactly; keep the smoke in the same position and approximate shape; make the smoke clearly distinct from the magenta background with no transparency, pink, purple, or magenta contamination; no other changes; no text or watermark.
Avoid: restyling, added objects, removed objects, crop changes, color shifts to the building, translucent smoke, blurred smoke edges.
```
