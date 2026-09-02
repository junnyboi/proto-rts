# Game Template - RTS

**Game Template - RTS** is a browser-playable real-time strategy skirmish template built in Godot 4.7.2. Four original factions inspired by Chinese mythology compete for the Jade Meridian: the **Celestial Court**, **Demon Host**, **Beast Clans**, and **Human Dynasty**.

![Game Template - RTS title screen](captures/title.png)

## Play

The hosted Web build is published at **[junnyboi.github.io/proto-rts](https://junnyboi.github.io/proto-rts/)** from the dedicated `gh-pages` branch after the GitHub Pages build completes.

For native play, open the project in Godot 4.7.2 or run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## Complete skirmish loop

The current release is a focused one-versus-one vertical slice played on **The Jade Divide**, an 80 × 64 battlefield with four times the previous map area. Its three-lane layout uses a diagonal river, three crossings, 1,016 harvestable trees forming dense mirrored jungles, protected starting economies, contested expansion resources, two guarded Yaoguai Dens, and a clickable fog-aware tactical minimap. Standing trees block movement and construction; logging them opens permanent shortcuts and new build sites. Every new unit requires Food, supplied by space-efficient Rice Farms or faster Hunter's Lodges. Neutral Jadeclaws guard each den and drop mixed resource bounties when hunted. Clear the pack, hold the capture ring, and the den becomes a forward production point for player-aligned monsters. The computer commander starts with the same resources and workers as the player, harvests every construction resource, builds its War Camp and food infrastructure through normal rules, then hunts, captures, recaptures, and produces without periodic resource grants.

| Unit or structure | Function |
| --- | --- |
| **Worker** | Harvests Jade, Lumber, and Essence; returns cargo; and constructs military or food infrastructure |
| **Vanguard** | Durable melee infantry used for direct assaults |
| **Mystic** | Fragile ranged attacker purchased with Jade and Essence |
| **Jadeclaw** | Durable cave monster; neutral guardians drop resources and captured dens produce aligned Jadeclaws |
| **Stronghold** | Resource drop-off, worker production, and primary defeat condition |
| **War Camp** | Produces Vanguards and Mystics; costs Jade, Lumber, and Essence |
| **Rice Farm** | Cheap 2 × 2 food producer; harvests 8 Food every 4 seconds |
| **Hunter's Lodge** | Compact premium food producer; delivers 18 Food every 5 seconds |
| **Yaoguai Den** | Guarded neutral objective; capture it to unlock Jadeclaw production |

## Controls

| Input | Action |
| --- | --- |
| Left click | Inspect any visible unit, structure, resource, or objective |
| Left drag | Box-select friendly units |
| Right click ground | Move selected units |
| Right click resource | Assign selected workers to gather |
| Right click enemy | Focus-fire selected units |
| Right click Yaoguai Den | Hunt its guardians, move into its capture ring, or set its rally point when owned and selected |
| Right click with structure selected | Set rally point |
| `F`, then left click | Attack-move |
| `X` | Stop selected units |
| `Q` | Select all workers |
| `E` | Select the army |
| `Space` | Select and center the player Stronghold |
| `WASD` or arrow keys | Pan the battlefield |
| Middle mouse drag | Pan the battlefield |
| `Command` + mouse wheel, or trackpad pinch/spread | Zoom |
| Minimap click or drag | Recenter the battlefield camera |
| Fog of War button | Toggle battlefield and minimap visibility masking |
| `P` or `Escape` | Pause; `Escape` cancels an armed command first |

## Factions

| Faction | Passive |
| --- | --- |
| **Celestial Court** | +15% Essence income; Mystics gain +0.8 range |
| **Demon Host** | Kills heal the attacker and yield 3 Essence |
| **Beast Clans** | Units move 18% faster; Vanguards cost 15 less Jade |
| **Human Dynasty** | +10% Jade income; War Camps cost 15% less |

## Architecture

The simulation stores positions in continuous grid coordinates. `IsoProjection` converts those coordinates to a 2:1 diamond view and performs inverse picking. `RtsSimulation` owns all resources, food harvest timers, entities, persistent attack-move destinations, line-of-sight, local unit separation, orders, navigation, gathering, queues, combat, AI, and outcome state. Every public command requires an explicit issuer team and rejects cross-team entities or structures. `Battlefield` translates player input into those authority- and bounds-checked commands; it batches authored terrain, screen-culls entities before sorting, renders each swaying tree once, and uses image-backed minimap layers. `main.gd` owns the application screens and heads-up display.

The design borrows the clean model/view boundary from [`junnyboi/proto-td`](https://github.com/junnyboi/proto-td), but the terrain renderer, map, factions, economy, simulation, controls, assets, interface, and gameplay are original to this repository.

## Generated asset pipeline

All representational game art was generated specifically for this project with **GPT Image 2**. The active runtime manifest contains 42 optimized derivatives generated from immutable masters under `assets/source/`; retired seasonal tree masters remain there for provenance but are excluded from the build. The repeatable processing tool removes the isolation background, preserves transparent silhouettes, resizes by asset category, and writes SHA-256 hashes.

```bash
python3 -m venv .venv
.venv/bin/python -m pip install Pillow
.venv/bin/python tools/process_assets.py
```

Godot ignores `assets/source/` through `.gdignore`, so the high-resolution masters do not enter the browser PCK.

## Tests

Run the focused suite:

```bash
tools/run_tests.sh
```

The suite verifies the expanded map's size, symmetry, startup invariants, crossings, clearable grove density and connectivity, cave placement, tree-blocked paths, projection round trips, all 42 runtime asset paths, fog and minimap visibility, generic structure placement, Food costs and harvest cadence, naturally funded AI construction, attack-move persistence (including external-kill races), arbitrary and capacity-limited formations, live-unit placement blocking, local separation, line-of-sight, selection pruning, cross-team command rejection, command bounds, keyboard focus, interactions, monster bounties, cave capture, Jadeclaw production, economy, combat, and match victory. It also enforces a 16.7 ms p95 CPU draw budget for both the 1,016-tree Battlefield and minimap in fogged and full-map views. A native visual harness captures the title, faction selection, normal fogged skirmish, food economy, monster-cave close-up, and full map overview screens:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/visual_capture.gd
```

## Web export

Install the Godot 4.7.2 Web export templates, then run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . \
  --export-release Web build/web/index.html
```

The preset is intentionally single-threaded, so ordinary static hosting does not require cross-origin isolation headers. Test the exported directory through HTTP rather than `file://`:

```bash
python3 -m http.server 8060 --directory build/web
```

## Design documents

The authored scope and implementation contract are in [`docs/GAME_PROPOSAL.md`](docs/GAME_PROPOSAL.md) and [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md). The wide genre benchmark, prioritized roadmap, and five GPT Image 2 concept designs are in [`docs/RTS_GAMEPLAY_RESEARCH_AND_FEATURE_PROPOSAL.md`](docs/RTS_GAMEPLAY_RESEARCH_AND_FEATURE_PROPOSAL.md). Implemented feature proposals are in [`docs/FOOD_SYSTEM_PROPOSAL.md`](docs/FOOD_SYSTEM_PROPOSAL.md), [`docs/MAP_REDESIGN_PROPOSAL.md`](docs/MAP_REDESIGN_PROPOSAL.md), [`docs/LUMBER_DESIGN_PROPOSAL.md`](docs/LUMBER_DESIGN_PROPOSAL.md), and [`docs/MONSTER_CAVES_PROPOSAL.md`](docs/MONSTER_CAVES_PROPOSAL.md). Generated-art review and provenance are in [`docs/ASSET_REVIEW.md`](docs/ASSET_REVIEW.md), [`assets/source/FOOD_BUILDING_GENERATION_PROMPTS.md`](assets/source/FOOD_BUILDING_GENERATION_PROMPTS.md), [`assets/source/GENERATED_ASSET_PROVENANCE.md`](assets/source/GENERATED_ASSET_PROVENANCE.md), [`assets/source/TREE_GENERATION_PROMPTS.md`](assets/source/TREE_GENERATION_PROMPTS.md), [`assets/source/EVERGREEN_TREE_GENERATION_PROMPTS.md`](assets/source/EVERGREEN_TREE_GENERATION_PROMPTS.md), and [`assets/source/MONSTER_CAVE_GENERATION_PROMPTS.md`](assets/source/MONSTER_CAVE_GENERATION_PROMPTS.md).
