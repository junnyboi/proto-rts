# GPT Image 2 Asset Provenance

**Generation date:** 2 September 2026  
**Generator:** GPT Image 2  
**Purpose:** Original representational art for *Mandate of Myth*  
**Source policy:** Files in this directory are immutable generation masters. Runtime changes must be made through `tools/process_assets.py` and written to `assets/runtime/`.

## Shared production brief

All faction units and buildings use painterly two-dimensional strategy-game illustration, a three-quarter isometric view, crisp silhouettes, controlled internal detail, upper-left lighting, complete uncropped subjects, and a flat magenta isolation background. The magenta color is not part of the intended artwork. It exists only to support deterministic alpha extraction on the local execution device.

The title key art uses a 16:9 mythic Chinese battlefield composition with the four factions occupying distinct visual regions and no embedded text. Faction portraits use 3:4 commander-card compositions. Terrain materials use full-frame top-down material studies. Resource nodes use isolated isometric prop compositions.

## Source inventory

| Category | Files | Generation intent |
| --- | --- | --- |
| Key art | `key_art/mandate_of_myth_title.png` | Four-faction Jade Meridian battlefield, no text or interface |
| Faction portraits | `factions/celestial_portrait.png`, `demon_portrait.png`, `beast_portrait.png`, `human_portrait.png` | Stable faction palette, commander identity, architecture, and mood anchors |
| Workers | `units/*_worker.png` | Practical gathering and construction silhouettes |
| Vanguards | `units/*_vanguard.png` | Durable faction-specific melee silhouettes |
| Mystics | `units/*_mystic.png` | Faction-specific ranged or spiritual silhouettes |
| Strongholds | `buildings/*_stronghold.png` | Primary base structures and match objectives |
| War Camps | `buildings/*_war_camp.png` | Compact military production structures |
| Terrain | `terrain/jade_meadow.png`, `inkstone_ridge.png`, `celadon_water.png` | Meadow, impassable stone, and water material fields |
| Resources | `resources/jade_outcrop.png`, `essence_shrine.png` | Mineable Jade and harvestable spiritual Essence |

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
