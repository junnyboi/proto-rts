# GPT Image 2 — Game Juice Concept Paintovers

Generated on 3 September 2026 with the built-in GPT Image 2 workflow. Each concept is a non-runtime proposal image produced as a non-destructive paintover of a current native 1280×720 capture. The captures were edit targets; the prompts explicitly preserved the HUD, map geometry, and existing faction art while adding only proposed feedback layers.

These images are immutable source references under the existing `assets/source/.gdignore`. They are not runtime derivatives and do not require changes to `assets/runtime/asset-report.json` or `assets/runtime/SHA256SUMS`.

## Combat feedback

**Input:** `captures/command-visualization.png`  
**Output:** `assets/source/concepts/game-juice-combat-feedback.png`  
**SHA-256:** `c0b218b062929bf681b171bcc55db839924e8acd1c3173173d78a27f6b2bf759`

```text
Use case: precise-object-edit
Asset type: production-feasible RTS combat-feedback paintover for the Mandate of Myth Godot game proposal
Input images: Image 1 is the edit target and the authoritative current 1280x720 game capture
Primary request: Add a restrained but highly satisfying combat-juice pass to the battlefield action only. Show a readable jade ranged projectile with a bright leading core and thin fading trail; a small gold-white contact spark and six to ten short directional shards at one hit; a compact dust kick at a melee unit's feet; one enemy sprite leaning back very slightly from impact; one brief red-orange damage number rising near that target; one small low-opacity expanding impact ring; and a subtle dark scorch/debris mark from a recent death. Add slight translucent motion arcs to one melee swing. Preserve the existing command-path dots and interaction marker so the new layers demonstrate coexistence.
Style/medium: polished in-game paintover matching the existing painterly 2D isometric sprites, terrain textures, crisp UI, and exact camera angle
Composition/framing: keep the full 16:9 screenshot, all HUD regions, terrain layout, units, buildings, selection state, and focal combat cluster in the same places
Lighting/mood: energetic and tactile but tactically readable; effects brightest at the instant of contact, quickly fading outward
Color palette: jade/cyan for allied actions, cinnabar/red-orange for hostile damage, warm ivory-gold at physical impacts, neutral brown dust
Constraints: change only visual feedback layers on the battlefield; keep all UI layout and existing UI text unchanged and legible; keep every existing unit, building, tree, terrain tile, health bar, selection marker, command route, and resource value; no new units or structures; no giant explosions; no full-screen bloom; no thick smoke; no gore; no logos; no watermark
Avoid: particle soup, opaque effects hiding silhouettes, cinematic camera changes, photorealism, redesigning the game
```

## Hover, click, and selection feedback

**Input:** `captures/multi-selection.png`  
**Output:** `assets/source/concepts/game-juice-hover-selection.png`  
**SHA-256:** `60e2b039ef166206577d201a00557d30b856418b7ec0378a9a276e8a13204744`

```text
Use case: precise-object-edit
Asset type: production-feasible RTS hover, click, and selection-feedback paintover for the Mandate of Myth Godot game proposal
Input images: Image 1 is the edit target and the authoritative current 1280x720 game capture
Primary request: Add a coherent interaction-juice pass only. Treat the worker beside the stronghold as the currently hovered unit: add a thin pale-jade silhouette rim light around the sprite, a soft translucent jade ground halo slightly wider than the existing selection ellipse, and a tiny upward nameplate chip reading "WORKER" with a small contextual move cursor hint. Show a left-click confirmation ripple at that unit's feet as two very thin expanding elliptical rings with fading arc gaps. Improve the three currently selected workers' ground rings with a slow-looking dual-band treatment: one steady ivory inner ellipse and one faint jade outer arc, preserving their health bars and idle alerts. Add a subtle illuminated tile footprint under the hovered unit only. In the command panel, show the MOVE button in hover state with a gentle jade edge glow and the REPAIR button in pressed state with a 2-pixel inward offset and small radial glint, while keeping every other button unchanged.
Style/medium: polished in-game paintover matching the existing painterly 2D isometric sprites, crisp flat functional overlays, jade-black-gold HUD, and exact camera angle
Composition/framing: keep the complete 16:9 screenshot and every HUD region, text block, terrain tile, unit, building, and panel in the same position
Lighting/mood: responsive, precise, premium, quiet enough for constant use
Color palette: pale jade and warm ivory for selectable/friendly feedback; gold only for click confirmation and active focus
Constraints: change only interaction feedback layers; keep all existing UI layout and UI text unchanged and legible; keep every unit, building, terrain tile, resource value, health bar, and objective; effects must remain readable at RTS zoom; no new units or buildings; no particles over faces; no large bloom; no logos; no watermark
Avoid: thick neon outlines, opaque highlights, mobile-game bounce exaggeration, particle clutter, photorealism, redesigning the interface
```

## Economy, construction, and ambience

**Input:** `captures/fortifications.png`  
**Output:** `assets/source/concepts/game-juice-world-economy.png`  
**SHA-256:** `f3aece4b89b5d36ac2ab638fe9880957cbf54fe1812aba881b5c2d5d6ef216d7`

```text
Use case: precise-object-edit
Asset type: production-feasible RTS economy, construction, and world-ambience paintover for the Mandate of Myth Godot game proposal
Input images: Image 1 is the edit target and the authoritative current 1280x720 fortifications capture
Primary request: Add restrained environmental and work-cycle juice only. On the pale under-construction building near the upper left, show a thin bottom-to-top golden completion shimmer, three tiny square construction motes traveling inward, one brief hammer spark, and a compact tan dust puff hugging the foundation. Around the manned sentry tower, add a very subtle warm lantern glow in the windows, faint wind motion arcs at one hanging cloth detail, and two tiny dust specks falling from the timber platform. Add a gentle jade-cyan traveling sheen on a short segment of the water at the upper edge; a few scattered leaf motes moving diagonally across open grass; a small contact shadow and soft footstep dust at one nearby worker; and one short-lived floating "+15" repair value in warm gold close to the tower health bar. Give the completed wall and gate a faint grounded ambient-occlusion shadow so they feel seated in the terrain.
Style/medium: polished in-game paintover matching the existing painterly 2D isometric art, crisp functional overlays, jade-black-gold HUD, and exact camera angle
Composition/framing: retain the complete 16:9 screenshot, current HUD, terrain grid, fortification layout, workers, structures, water, fog edge, and selection state exactly where they are
Lighting/mood: living mythic valley, tactile handcrafted timber, calm ambient motion between battles; effects are low opacity and localized
Color palette: jade-cyan water sheen, warm ivory-gold work feedback, tan earth dust, muted green leaves
Constraints: change only ambient, construction, repair, and grounding feedback layers; keep all UI layout and existing UI text unchanged and legible; keep every existing unit, building, wall, gate, tower, terrain tile, health bar, selection marker, and resource value; no new structures or characters; no dramatic weather; no thick fog or smoke; no giant bloom; no logos; no watermark
Avoid: particle soup, magical effects on ordinary timber, cinematic relighting, photorealism, redesigning the game
```
