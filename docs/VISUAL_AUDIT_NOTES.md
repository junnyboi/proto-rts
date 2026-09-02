# Visual Audit Notes

The first sections preserve the pre-remediation 20 × 16 audit baseline. The final section records the verified state after integration with the expanded 80 × 64 battlefield and core defect repairs.

## Title screen

The 1280 × 720 title screen has a strong, legible central hierarchy and a distinctive mythic-Chinese battlefield backdrop. The jade-black panel and restrained gold trim create a coherent identity. The background already communicates large-scale faction conflict better than the current in-match presentation. Weaknesses include a visually generic all-caps interface, a relatively static composition, no animated ambient layer, no visible faction identity in the primary call to action, and a low-value implementation/provenance footer competing with atmosphere. The “predictable administrative violence” line is memorable but shifts the tone toward parody; it should remain only if dry comedy is a deliberate pillar.

## Faction selection

The four generated portraits are visually strong, readable, and coherent. Accent colors separate cards effectively. However, the selection screen reveals that each faction differs mainly by one passive and a skin. Cards lack unit-roster previews, difficulty or playstyle tags, strength/weakness summaries, active powers, and a concrete gameplay example. The four full-height cards fill the screen cleanly at 1280 × 720 but rely on small lower-body text and likely degrade at smaller browser windows. There is no persistent selected state, comparative stat visualization, hover animation, voice/ambient sting, or immediate faction-specific feedback beyond the button border.

## Cross-screen visual implication

The front end promises a sweeping mythic war, but the documented playable layer is a compact two-unit skirmish. New systems should close this fantasy-to-play gap with faction-defining active powers, a contested Jade Meridian objective, higher-information combat feedback, environmental motion, and stronger match-end spectacle rather than merely adding more static artwork.

## Skirmish presentation

The battlefield is immediately readable as an isometric board and the two sides have clear color and silhouette differences. The current view also exposes the largest visual gap. The map reads as a tiled board rather than a living mythic valley because it uses a fully visible square grid, hard terrain rectangles, no elevation blending, no foliage or props, no fog of war, and no ambient motion. Units and buildings are small relative to the screen, and their detailed generated art collapses at gameplay scale. Combat telemetry is limited to health bars, flashes, short beams, and rings; there are no anticipatory attack tells, hit-stop, knockback, impact particles, damage numbers, persistent corpses, death dissolves, status icons, formation previews, or strong audio-shaped visual cues.

The bottom command deck reserves roughly one fifth of the screen even when there is no selection, producing a large dead region. The battlefield has no minimap, objective tracker, production overview, idle-worker alert, army composition panel, control groups, queued-command feedback, enemy warning, or strategic camera anchors. The objective panel explains the AI stipend instead of reinforcing immediate strategic goals. The central Jade Meridian is currently only a resource placement pattern, not a capturable or escalating objective.

## Live browser build

The published GitHub Pages build loaded successfully to the title screen. At the browser tool's non-16:9 viewport, Godot preserved the 1280 × 720 game canvas and introduced large black letterbox bands. The game remained legible but the interface scaled down substantially, confirming that the UI is designed around one fixed landscape viewport rather than adapting to arbitrary desktop browser dimensions. This is acceptable for a prototype, but a production browser release should provide a responsive shell, full-window scaling rules, explicit minimum-resolution messaging, and fullscreen support.

## Live interaction note

A coordinate click on the visible title-screen call to action did not transition the canvas in the automated browser. This is not sufficient evidence of a game defect because canvas/WebGL pointer normalization in the browser tool may differ from the rendered game's internal 1280 × 720 coordinate system. It does reveal that the page exposes only a canvas with no accessible DOM controls or fallback navigation, so conventional browser automation and assistive technologies cannot discover the game's interface.

## Browser runtime diagnostics

The live canvas resized to the browser viewport at 1280 × 1100 and held focus. Godot then letterboxed the fixed 16:9 game viewport inside that taller canvas. No engine, asset, or gameplay errors appeared in the browser console during the title-screen check. The earlier failed automated click is therefore more consistent with the browser tool's canvas-event translation than with a loading failure.

## Concept validation: Jade Meridian and Mandate powers

The Jade Meridian concept successfully visualizes the recommended conflict engine: a visually dominant central objective, two approach lanes, shallow crossings, exposed resources, clearer terrain, and fog-darkened edges. It is intentionally an aspirational composition rather than a literal screenshot. Its asset density, elevation, and army scale exceed the current 20 × 16 renderer, so implementation should begin with a flat capture footprint, ownership ring, lane props, and fog overlay before pursuing terrain elevation or this many bespoke structures.

The four-power sheet is internally coherent and correctly maps the proposed faction verbs: Celestial sanctuary/control, Demon kill-fed attrition, Beast mobility/flanking, and Human rapid fortification. All four required headings rendered correctly. The Celestial and Demon visuals are the clearest mechanically; Beast movement needs a stronger destination/trajectory cue in an eventual in-game effect, and Human construction should be represented by a smaller temporary emplacement at gameplay scale to avoid promising a full wall system prematurely.

## Concept validation: combat feedback and HUD

The combat concept demonstrates the correct feedback order: readable wind-up, projectile travel, impact, health change, positional warning, death aftermath, and objective state. Turquoise versus red remains clear despite multiple effects. The image intentionally exaggerates simultaneous effects to document the available vocabulary; implementation should budget effects by event priority so ordinary attacks receive a lean subset and Mandate powers receive the full stack. Persistent scorch marks and fallen banners are particularly cost-effective because they turn an exchange into visible battlefield history.

The HUD concept resolves the current dead-space problem by distributing compact modules around the perimeter. It successfully includes the proposal's objective meter, minimap, composition summary, off-screen warning, selection portraits, production strip, and command grid. The generated text requested in the prompt is legible. This remains a visual mockup, not an exact layout specification: a first implementation should keep the current Godot theme, add the objective meter and alerts, shrink the bottom deck, and reserve the minimap for the fog-of-war milestone rather than attempting every module at once.

## Concept validation: doctrine choice

The doctrine screen clearly communicates a single irreversible fork and gives each option a distinct strategic thesis through color, iconography, and battlefield imagery. The required title, choice names, and closing line rendered correctly. The additional center phrase is consistent with the prompt's exclusivity requirement. This should remain a later milestone: the current game needs a contested objective and deeper combat loop before persistent in-match doctrines can create meaningful opportunity cost.

## Post-remediation visual regression (expanded 80 × 64 build)

The refreshed native skirmish capture passes at 1280 × 720. The revised objective copy fits inside its panel, explicitly states equal economic rules, and does not obscure the starting base. The top resource bar, minimap, fog toggle, revealed terrain, worker silhouettes, idle-worker cue, and bottom command deck remain legible without clipping.

The refreshed full-map overview also passes. The three river crossings, mirrored road network, clearable forest masses, expansion clearings, neutral cave positions, unit silhouettes, full-map camera framing, and HUD remain readable at minimum zoom. No malformed sprites, missing textures, stale selection markers, or camera-edge gaps were observed.

## Performance-remediation visual regression

After renderer optimization, the 1280 × 720 skirmish and full-map overview remain visually coherent. Authored 2 × 2 terrain macro-cells render without cracks or projection discontinuities, the river and three crossings remain unambiguous, nearby tree-grove silhouettes and faction units remain readable, and the cached minimap retains terrain, fog, wildlife, entity, and camera overlays. Tree resource bars are suppressed unless a tree is selected, reducing overview clutter. The simplified single-draw crown sway preserves ambient motion while eliminating the previous twelve-polygon-per-tree cost. At strategic overview zoom, one representative tree per authored 2 × 2 grove cell preserves the map's dense forest masses while unreadable duplicate sprites and grid strokes are intentionally hidden.

The definitive instrumented Godot 4.7.2 suite exercised **2,224 authored trees** and 2,286 total entities. It measured Battlefield p95 CPU draw at **24.135 ms** in the fog-off full-map view and **17.409 ms** in the fogged starting view; minimap p95 draw measured **11.921 ms** without fog and **12.243 ms** with fog. Battlefield results remain inside the enforced **33.3 ms** ambient-redraw budget, while both minimap modes remain inside the stricter **16.7 ms** budget.

## Final HUD-icon and audio-control regression

The post-integration 1280 × 720 skirmish and strategic overview both pass. The generated Jade, Lumber, Essence, Food, Population, and Den icons remain distinct at compact ribbon scale; labels and numeric values retain adequate contrast; and the new **AUDIO ON** control fits without clipping the time or pause modules. The dense one-per-authored-cell strategic grove LOD, river crossings, wildlife silhouettes, objective panel, production queue, command grid, selection composition, minimap overlays, and camera framing remain legible. No terrain seams, malformed sprites, stale markers, or HUD collisions were observed.
