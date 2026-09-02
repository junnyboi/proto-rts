# HUD Resource Icon Generation Prompts

**Generated:** 2 September 2026  
**Generator:** built-in GPT Image 2 workflow  
**Reference:** the existing Mandate of Myth HUD screenshot was supplied only as a style-and-scale reference. It was not edited or reproduced.

## Shared generation prompt

```text
Use case: stylized-concept
Asset type: premium real-time strategy game economy HUD icon, transparent PNG master
Input images: Image 1 is a style-and-scale reference for the existing Mandate of Myth HUD only; do not reproduce the screenshot or any panel.
Style/medium: polished hand-painted game UI icon, crisp charcoal-ink outline, tactile carved material, subtle dimensional highlights, mythic Chinese strategy-game aesthetic; more refined and expressive than a flat pictogram
Composition/framing: exactly one isolated square-format glyph, centered, front-facing or gentle three-quarter view, complete uncropped silhouette, generous transparent padding; designed to stay immediately recognizable at 24 pixels
Lighting/mood: controlled upper-left highlight, restrained jewel-like glow, strong value separation
Constraints: genuinely transparent background and transparent padding; exactly one icon; bold simple silhouette; no surrounding square, circle, medallion, panel, label, text, letters, numbers, logo, watermark, scenery, drop shadow outside the silhouette, or checkerboard pattern
Avoid: photorealism, thin line art, excessive micro-detail, gradients that erase the silhouette, multiple separate symbols
```

## Subject prompts

| Source | Subject appended to the shared prompt |
| --- | --- |
| `ui/resource_icons/jade.png` | A compact cluster of three angular imperial jade crystal shards, rich celadon green with pale mint facets and two tiny antique-gold binding accents; unmistakably valuable jade, not generic ice. |
| `ui/resource_icons/lumber.png` | A compact bundle of three warm cedar timber logs with visible cut end-rings, bound once by dark jade cord with one small antique-gold clasp; unmistakably lumber, not a scroll or ingot. |
| `ui/resource_icons/essence.png` | One elegant violet spirit-flame wisp rising from a tiny dark-jade ritual vessel, luminous amethyst core with pale lavender edge and restrained antique-gold lip; unmistakably magical essence. |
| `ui/resource_icons/food.png` | One ivory rice bowl with an antique-gold rim, visibly full of white rice grains and one small jade leaf accent; unmistakably food supply, clean lidded-bowl silhouette without steam clutter. |
| `ui/resource_icons/population.png` | A compact group of three stylized command-roster bust silhouettes—one central warrior and two smaller retainers—carved ivory with dark-jade shadow planes and restrained antique-gold collar accents; unmistakably population capacity. |
| `ui/resource_icons/dens.png` | One ancient Yaoguai cave arch with a deep ink-dark entrance, moss-jade stone sides, two subtle pale-jade guardian eyes inside, and restrained antique-gold lintel accents; unmistakably a monster den, not a house. |

## Isolation correction

GPT Image 2 initially rendered a checkerboard into the RGB background. A second edit requested true alpha while preserving each icon. The Food edit returned valid alpha. The other five masters received one final, non-redesign edit using this prompt so the existing deterministic processor could extract clean alpha:

```text
Edit this existing HUD icon rather than redesigning it. Preserve [SUBJECT], its exact silhouette, painted detail, colors, material, lighting, scale, and framing. Replace every background pixel and all checkerboard/white background with one perfectly uniform, flat, fully opaque chroma-key magenta field, exact color #FF00FF. The magenta must touch every outside edge and all negative spaces around the isolated icon. No gradient, texture, checkerboard, floor, shadow outside the subject, transparency, panel, border, text, logo, or added object. Exactly one centered icon on solid #FF00FF. Keep a crisp dark outline and generous magenta padding.
```

`tools/process_assets.py` trims, edge-decontaminates, centers, and downsamples these masters into 64×64 transparent runtime PNGs. The HUD displays them at 28×28 logical pixels.
