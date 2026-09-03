# HUD Utility Icon Generation Prompts

**Generated:** 3 September 2026
**Generator:** built-in GPT Image 2 workflow
**Reference:** the supplied Mandate of Myth HUD screenshot was used only as a style-and-scale reference. It was not edited or reproduced.

## Shared generation prompt

```text
Use case: stylized-concept
Asset type: compact real-time strategy game HUD utility icon, transparent PNG master
Input images: Image 1 is a style-and-scale reference for the existing Mandate of Myth HUD only; do not reproduce the screenshot, panels, layout, text, or other controls.
Style/medium: polished hand-painted game UI icon, crisp charcoal-ink outline, tactile dark-jade and antique-gold material, subtle dimensional upper-left highlights, mythic Chinese strategy-game aesthetic; refined but visually simple
Composition/framing: exactly one isolated square-format glyph, centered and front-facing, complete uncropped silhouette, generous transparent padding, designed to remain unmistakable at 24 pixels
Color palette: deep jade-green body, antique-gold edges/highlights, pale celadon highlight; strong contrast on a near-black interface
Constraints: genuinely transparent background and transparent padding; exactly one cohesive icon; bold simple silhouette; no surrounding square, circle, medallion, button, panel, label, text, letters, numbers, logo, watermark, scenery, external shadow, checkerboard pattern, or extra symbol
Avoid: photorealism, thin line art, excessive micro-detail, muddy values, multiple variants in one image
```

## Subject prompts

| Source | Subject appended to the shared prompt |
| --- | --- |
| `ui/utility_icons/pause.png` | A universal Pause symbol made of two parallel vertical lacquered bars, balanced spacing and identical height; readable instantly as pause. |
| `ui/utility_icons/resume.png` | A universal Resume/Play symbol: one solid right-pointing triangular arrow with a subtly carved jade face and antique-gold edge; readable instantly as play. |
| `ui/utility_icons/audio_on.png` | A universal Audio On symbol: one compact left-facing speaker body with two clear curved sound-wave bands on its right, joined visually into one cohesive glyph; readable instantly as sound enabled. |
| `ui/utility_icons/audio_muted.png` | A universal Audio Muted symbol: one compact left-facing speaker body with one bold diagonal antique-gold slash across the sound-wave area; no letters and no separate floating pieces; readable instantly as muted. |

## Isolation correction

GPT Image 2 rendered a checkerboard into the RGB background of the four first-pass masters. The Audio Muted correction returned genuine alpha. The other three masters received an isolation-only edit for deterministic chroma extraction:

```text
Use case: background-extraction
Asset type: game HUD icon isolation master
Input images: Image 1 is the edit target.
Primary request: edit the existing [SUBJECT]; replace only the checkerboard/white background.
Constraints: preserve the icon's exact subject, silhouette, painted detail, colors, material, lighting, scale, orientation, and framing. Replace every background pixel and every checkerboard square with one perfectly uniform, flat, fully opaque chroma-key magenta field, exact color #FF00FF. The magenta must touch every outside edge and fill all negative spaces around and within the isolated icon.
Avoid: gradient, texture, checkerboard, white pixels in the background, floor, scenery, external shadow, transparency, panel, border, text, logo, added object, redesign, or changed proportions. Exactly one preserved centered icon on solid #FF00FF.
```

`tools/process_assets.py` trims, edge-decontaminates, centers, and downsamples the masters into 64×64 transparent runtime PNGs. The HUD displays them at up to 26 logical pixels.
