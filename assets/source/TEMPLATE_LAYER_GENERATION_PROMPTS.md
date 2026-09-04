# Template Presentation Layer — GPT Image 2 Prompts

**Generation date:** 4 September 2026
**Generator:** built-in GPT Image 2
**Use:** replaceable shell background, transparent shell foreground, and pause-menu frame
**Text policy:** every master is text-free; localized copy remains real Godot UI.

## Jade Meridian backdrop

Source: `assets/source/backgrounds/jade_meridian_backdrop.png`
Runtime: `assets/runtime/backgrounds/jade_meridian_backdrop.webp` at 1600 × 900 via `tools/process_assets.py`

```text
Use case: stylized-concept
Asset type: 16:9 game background layer for a browser RTS title, pause, and debrief presentation
Primary request: a mythic Chinese jade-meridian battlefield panorama spanning celestial ivory temples, ember-lit demon mountains, mossy beast-clan wilderness, and a cinnabar human dynasty river city, unified into one coherent distant landscape
Scene/backdrop: immense layered mountain valley and river basin viewed from a high strategic overlook; distant armies and architecture remain tiny atmospheric silhouettes
Style/medium: premium painterly two-dimensional strategy-game key art, stylized realism, matching an elegant dark jade and parchment interface
Composition/framing: 16:9 landscape, full bleed, broad calm center with generous negative space for real UI, strongest environment detail toward the outer thirds, no close foreground objects
Lighting/mood: misty dawn with ivory-gold light in the center, cool jade haze, restrained ember accents, solemn and epic
Color palette: deep ink green, celadon, ivory, muted gold, cinnabar, restrained ember red
Constraints: background layer only; no readable text, glyphs, logos, interface, frames, borders, watermark, close characters, or cropped focal subjects; no foreground branches or rocks; suitable for cover-crop at landscape and portrait aspect ratios
```

## Jade Meridian transparent foreground

Source: `assets/source/foregrounds/jade_meridian_foreground.png`
Runtime: `assets/runtime/foregrounds/jade_meridian_foreground.png` at 1600 × 900 RGBA via `tools/process_assets.py`

```text
Use case: stylized-concept
Asset type: transparent 16:9 foreground overlay for the generated mythic Chinese RTS background
Input images: backdrop is a style and palette reference only, not an edit target
Primary request: an independent foreground layer of elegant dark ink-painted pine branches, bamboo leaves, weathered jade rocks, wisps of low mist, and a few restrained ember motes framing the outer edges
Style/medium: premium painterly two-dimensional strategy-game key art matching the backdrop exactly in brushwork, lighting, atmospheric depth, and jade/ivory/cinnabar palette
Composition/framing: transparent full 16:9 canvas; foliage and rocks concentrated along the bottom corners and thin outer side edges; center 70 percent and upper-middle remain completely clear for real UI; no continuous opaque background
Lighting/mood: dark foreground silhouettes with subtle rim light from the bright valley center
Constraints: genuinely transparent background with preserved alpha; foreground objects only; no landscape fill, sky, architecture, characters, armies, text, glyphs, logos, interface, border, frame, or watermark; clean feathered transparent edges; no magenta isolation color
```

## Pause-menu frame

Source: `assets/source/ui/mandate_pause_frame.png`
Runtime: `assets/runtime/ui/mandate_pause_frame.png` at 560 × 660 RGBA via `tools/process_assets.py`

```text
Use case: stylized-concept
Asset type: transparent pause-menu frame for a mythic Chinese browser RTS
Input images: generated backdrop and foreground are style, palette, and material references only
Primary request: a single elegant rectangular command-table frame made from dark lacquered wood, aged gold corner fittings, carved jade inlays, subtle cloud motifs, and restrained red silk knots
Style/medium: premium painterly two-dimensional game UI ornament matching the referenced mythic Chinese art
Composition/framing: centered portrait-oriented frame on a transparent canvas, approximately 5:6 outer aspect; thick enough edges to read at 420–520 pixels wide; large uninterrupted transparent inner opening for real localized menu controls; symmetrical and front-facing
Lighting/mood: softly rim-lit ivory-gold edges, dark jade shadows, sober military command aesthetic
Constraints: genuinely transparent background and transparent center opening with preserved alpha; frame ornament only; no solid panel fill, no text, symbols, letters, numbers, logos, buttons, characters, scenery, watermark, drop-shadow rectangle, or magenta isolation color; clean alpha edges and complete uncropped silhouette
```

The first frame generation returned an RGB image with a baked checkerboard. GPT Image 2 then received this corrective edit:

```text
Use case: background-extraction
Asset type: corrected transparent game UI frame
Input images: generated frame is the edit target
Primary request: remove only the white-and-gray checkerboard background and replace it with genuine transparency, including the entire large center opening and all space outside the frame
Constraints: preserve the ornate dark wood, aged gold, jade carvings, red knots, exact framing, proportions, colors, lighting, and clean complete silhouette; change only the checkerboard/background pixels; output real alpha transparency; no solid fill, no checkerboard, no text, no logos, no watermark, no magenta
```

## Inspection record

- Backdrop master: 1672 × 941 RGB, full bleed.
- Foreground master: 1672 × 941 RGBA, alpha range 0–255.
- Corrected pause frame: 1155 × 1362 RGBA, alpha range 0–255.
- Runtime derivatives preserve aspect ratio, use mipmapped linear filtering in Godot, and remain presentation-only with no collision geometry.
