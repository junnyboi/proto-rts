# GPT Image 2 Monster Cave Generation Record

**Generation date:** 2 September 2026
**Generator:** GPT Image 2 through Codex built-in image generation
**Purpose:** Yaoguai Den and Jadeclaw sprites for *Mandate of Myth*

## `buildings/neutral_yaoguai_den.png`

```text
Use case: stylized-concept
Asset type: capturable monster-cave structure sprite for a painterly 2D isometric real-time strategy game
Primary request: create one ancient Yaoguai Den, a mysterious natural cave objective that neutral monsters inhabit and rival armies can capture
Subject: a broad dark cave mouth set into a compact formation of ink-dark weathered rocks, twisted roots, restrained jade crystal seams, two small ancient Chinese stone warding posts, and a clear flat ground-contact base
Style/medium: polished painterly strategy-game illustration matching classic high-detail isometric RTS sprites; crisp readable silhouette; controlled internal detail; mythic Chinese fantasy
Composition/framing: three-quarter isometric view from above; one complete centered structure; full cave, rocks, roots, posts, and base visible; generous clear padding on all sides; bottom-center ground contact; suitable for a two-tile footprint
Lighting/mood: soft daylight from upper left; ominous but readable; dark interior without blacking out the silhouette
Color palette: charcoal stone, dark warm roots, weathered ivory, subdued jade green accents; keep the neutral base broadly gray so runtime team tints remain legible
Constraints: perfectly flat saturated magenta #FF00FF isolation background extending to every edge; no shadows, smoke, particles, or glow outside the subject; no units or creatures; no scenery; no text; no UI; no logos; no watermark; no cropped elements
Avoid: a full environment scene, photorealism, excessive neon glow, elaborate architecture, multiple cave entrances, fuzzy edges
```

## `units/neutral_jadeclaw.png`

The first generation established the creature. A second built-in edit changed only its noncompliant gradient background to the pipeline's flat magenta key.

```text
Use case: stylized-concept
Asset type: neutral and capturable monster unit sprite for a painterly 2D isometric real-time strategy game
Primary request: create one Jadeclaw Yaoguai, a durable quadrupedal cave monster that can begin neutral and later fight for either rival team
Subject: a stocky lion-sized mythic Chinese guardian beast on four legs, with a broad horned feline-draconic head, powerful shoulders, clawed paws, a short stone-armored mane, restrained jade crystal plates along its spine, and a practical battle-ready stance
Style/medium: polished painterly strategy-game illustration matching classic high-detail isometric RTS sprites; crisp readable silhouette; controlled internal detail; mythic Chinese fantasy rather than realistic wildlife
Composition/framing: three-quarter isometric view from above, facing down-left; one complete centered creature; full horns, tail, legs, claws, and paws visible; generous clear padding; bottom-center ground contact; silhouette readable at 100 pixels tall
Lighting/mood: soft daylight from upper left; alert and dangerous, not berserk
Color palette: charcoal hide, weathered dark stone, muted bone horns, subdued jade green accents; keep most of the body neutral so runtime team rings and tints remain legible
Constraints: perfectly flat saturated magenta #FF00FF isolation background extending to every edge; no cast shadow, glow, smoke, particles, scenery, cave, handler, saddle, armor banners, text, UI, logos, or watermark; no cropped anatomy
Avoid: humanoid posture, wings, multiple creatures, photorealism, cute mascot proportions, excessive neon, fuzzy edges
```

Corrective edit:

```text
Use case: precise-object-edit
Asset type: isolated 2D isometric real-time strategy game unit sprite master
Input images: Image 1 is the edit target
Primary request: replace only the entire existing dark gradient background with one perfectly flat, uniform, saturated magenta color #FF00FF extending to every image edge
Constraints: preserve the Jadeclaw creature exactly—same anatomy, pose, proportions, silhouette, colors, jade crystals, lighting, rendering, sharpness, framing, and padding; do not repaint, resize, crop, rotate, or restyle any part of the creature; no cast shadow, glow, halo, scenery, text, UI, logos, or watermark; the only change is the background color
Avoid: gradients, vignettes, black corners, green backdrop, textured backdrop, edge blur, extra objects
```

## Runtime derivatives

`tools/process_assets.py` generated:

- `assets/runtime/buildings/neutral_yaoguai_den.png` at 320 × 272 RGBA;
- `assets/runtime/units/neutral_jadeclaw.png` at 192 × 176 RGBA.

The processing run also refreshed `assets/runtime/asset-report.json` and `assets/runtime/SHA256SUMS`.
