# GPT Image 2 Asset Provenance

**Generation date:** 2 September 2026  
**Generator:** GPT Image 2  
**Purpose:** Original representational art for *Mandate of Myth*  
**Source policy:** Files in this directory are immutable generation masters. Runtime changes must be made through `tools/process_assets.py` and written to `assets/runtime/`.

## Shared production brief

All faction units and buildings use painterly two-dimensional strategy-game illustration, a three-quarter isometric view, crisp silhouettes, controlled internal detail, upper-left lighting, complete uncropped subjects, and a flat magenta isolation background. The magenta color is not part of the intended artwork. It exists only to support deterministic alpha extraction on the local execution device.

The title key art uses a 16:9 mythic Chinese battlefield composition with the four factions occupying distinct visual regions and no embedded text. Faction portraits use 3:4 commander-card compositions. Terrain materials use full-frame top-down material studies. Resource nodes use isolated isometric prop compositions.

The Jade Divide expansion adds three full-frame, top-down, seamless terrain masters generated with the built-in GPT Image 2 workflow. Existing terrain sources were supplied only as style references; none of the earlier source masters were edited or overwritten.

The monster-cave expansion adds a neutral Yaoguai Den structure and Jadeclaw creature. Both use the built-in GPT Image 2 workflow and the same isometric lighting and isolation contract. The exact generation and corrective-edit prompts are recorded in `MONSTER_CAVE_GENERATION_PROMPTS.md`.

The idle-worker alert uses the built-in GPT Image 2 workflow and the same magenta isolation contract. Its exact prompt is recorded in `IDLE_WORKER_ALERT_GENERATION_PROMPT.md`.

The wildlife-hunting expansion adds Demon, Beast, and Human Hunter units plus deer, bison, chicken, boar, and bear wildlife. The built-in GPT Image 2 workflow used existing faction units and the Jadeclaw only as style references. Exact prompts are recorded in `WILDLIFE_HUNTING_GENERATION_PROMPTS.md`.

The economy-ribbon refresh adds illustrated Jade, Lumber, Essence, Food, Population, and Yaoguai Den icons. The built-in GPT Image 2 workflow used the existing HUD only as a style-and-scale reference. Exact generation and isolation-correction prompts are recorded in `HUD_RESOURCE_ICON_GENERATION_PROMPTS.md`.

## Source inventory

| Category | Files | Generation intent |
| --- | --- | --- |
| Key art | `key_art/mandate_of_myth_title.png` | Four-faction Jade Meridian battlefield, no text or interface |
| Interface | `ui/idle_worker_alert.png` | Gold-and-jade exclamation marker for visible idle workers |
| Resource HUD icons | `ui/resource_icons/jade.png`, `lumber.png`, `essence.png`, `food.png`, `population.png`, `dens.png` | Compact painted economy-ribbon symbols optimized for recognition at 24–28 pixels |
| Faction portraits | `factions/celestial_portrait.png`, `demon_portrait.png`, `beast_portrait.png`, `human_portrait.png` | Stable faction palette, commander identity, architecture, and mood anchors |
| Workers | `units/*_worker.png` | Practical gathering and construction silhouettes |
| Vanguards | `units/*_vanguard.png` | Durable faction-specific melee silhouettes |
| Mystics | `units/*_mystic.png` | Faction-specific ranged or spiritual silhouettes |
| Hunters | `units/demon_hunter.png`, `units/beast_hunter.png`, `units/human_hunter.png` | Faction-specific economic ranged units for hunting wildlife |
| Wildlife | `wildlife/deer.png`, `bison.png`, `chicken.png`, `boar.png`, `bear.png` | Neutral herd animals with passive or retaliatory silhouettes |
| Strongholds | `buildings/*_stronghold.png` | Primary base structures and match objectives |
| War Camps | `buildings/*_war_camp.png` | Compact military production structures |
| Yaoguai Den | `buildings/neutral_yaoguai_den.png` | Capturable neutral monster objective and forward production structure |
| Jadeclaw | `units/neutral_jadeclaw.png` | Neutral guardian and team-aligned cave-produced melee monster |
| Terrain | `terrain/jade_meadow.png`, `inkstone_ridge.png`, `celadon_water.png`, `jade_forest.png`, `meridian_road.png`, `moon_bridge.png` | Meadow, impassable stone, water, dense forest canopy, worn road, and pale stone crossing material fields |
| Resources | `resources/jade_outcrop.png`, `essence_shrine.png`, `lumber_pine.png`, `lumber_cedar.png`, `lumber_fir.png`, `lumber_juniper.png`, plus retained earlier tree masters | Mineable Jade, harvestable spiritual Essence, and finite Lumber-tree variants |

## Jade Divide prompt set

| Source | Final generation brief | References and invariants |
| --- | --- | --- |
| `terrain/jade_forest.png` | Dense mythic-Chinese broadleaf and bamboo canopy with dark trunks, moss, ferns, jade highlights, and deep cool shadows | Jade Meadow and Inkstone Ridge style references; orthographic top-down; full bleed; seamless; no clearings, paths, water, structures, units, text, logos, or watermark |
| `terrain/meridian_road.png` | Broad ancient war-road of compacted ochre earth, irregular pale pavers, restrained moss, wheel scuffs, and tiny jade pebbles | Jade Meadow and Inkstone Ridge style references; orthographic top-down; full bleed; seamless; no grass border, water, rails, structures, units, text, logos, or watermark |
| `terrain/moon_bridge.png` | Pale weathered flagstone deck with cool jade inlay seams, damp joints, restrained moss, and age cracks | Celadon Water and Inkstone Ridge style references; orthographic top-down; full bleed; seamless; no water border, railings, arches, structures, units, text, logos, or watermark |

## Faction art anchors

| Faction | Palette and motifs |
| --- | --- |
| Celestial Court | Ivory, jade, teal, gold cloud filigree, disciplined divine silhouettes |
| Demon Host | Obsidian, ember red, burnt bronze, horned roof lines, ritual masks |
| Beast Clans | Amber, moss, bone, fur or feather, timber totems, guardian-beast forms |
| Human Dynasty | Cinnabar, dark lacquer, grey tile, warm brass, practical lamellar forms |

## Derivative contract

`tools/process_assets.py` loads each source master, samples the isolation color from the corners, removes pixels by color distance and magenta dominance, feathers only the resulting alpha edge, trims the subject, preserves bottom-center pivot space, and resizes into category-specific canvases. It converts title, portrait, and terrain files to browser-efficient WebP and keeps sprites as transparent PNG. The tool writes dimensions, alpha extrema, source paths, and checksums to `assets/runtime/asset-report.json` and `assets/runtime/SHA256SUMS`.

The source directory includes `.gdignore`, so Godot does not import or export the high-resolution masters. All runtime resource paths resolve exclusively under `assets/runtime/`.
