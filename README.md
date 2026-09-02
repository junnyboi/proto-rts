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

The current release is a focused one-versus-one vertical slice played on **The Jade Divide**, an 80 × 64 battlefield with four times the previous map area. Its three-route layout uses a diagonal river with two outer crossings and no central bridge, 2,224 harvestable trees forming dense mirrored jungles and an irregular wooded perimeter, protected starting economies, contested expansion resources, two guarded Yaoguai Dens, and a clickable fog-aware tactical minimap. Standing trees block movement and construction; logging them opens permanent shortcuts and new build sites. Every new unit requires Food, supplied by space-efficient Rice Farms or faster Hunter's Lodges. Neutral Jadeclaws guard each den and drop mixed resource bounties when hunted. Clear the pack, hold the capture ring, and the den becomes a forward production point for player-aligned monsters. The computer commander builds food infrastructure, hunts, captures, recaptures, and produces through the same simulation rules.

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
| Left click | Select one friendly entity; hold `Shift` to toggle it in the selection |
| Left drag | Box-select friendly units; hold `Shift` to add them |
| Right click ground | Move selected units; hold `Shift` to queue the order |
| Right click resource | Assign selected workers to gather; hold `Shift` to queue the source |
| Right click enemy | Focus-fire selected units; hold `Shift` to queue the target |
| Right click damaged allied structure | Repair it with selected workers |
| Right click Yaoguai Den | Hunt its guardians, move into its capture ring, or set its rally point when owned and selected |
| Right click with structure selected | Set rally point |
| `F`, then left click | Attack-move; hold `Shift` while arming or confirming to queue it |
| `T`, then left click | Patrol repeatedly between the unit's position and the destination |
| `R`, then left click | Repair a damaged allied structure with selected workers |
| `Ctrl/Cmd` + `0–9` | Assign the current selection to a control group; add `Shift` to extend it |
| `0–9` | Recall a control group; add `Shift` to merge it with the selection; double-tap to center |
| `X` | Stop selected units and clear queued orders |
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

The simulation stores positions in continuous grid coordinates. `IsoProjection` converts those coordinates to a 2:1 diamond view and performs inverse picking. `RtsSimulation` owns all resources, food harvest timers, entities, active and queued orders, repair costs, patrol routes, production refunds, navigation, gathering, combat, AI, and outcome state. `Battlefield` reads that state, owns local control-group selection shortcuts, renders the match, and translates input into simulation commands. `main.gd` owns the application screens and heads-up display.

The design borrows the clean model/view boundary from [`junnyboi/proto-td`](https://github.com/junnyboi/proto-td), but the terrain renderer, map, factions, economy, simulation, controls, assets, interface, and gameplay are original to this repository.

## Generated asset pipeline

All representational game art was generated specifically for this project with **GPT Image 2**. The active runtime manifest contains 50 optimized derivatives generated from immutable masters under `assets/source/`; retired concepts and seasonal tree masters remain outside the runtime build. The repeatable processing tool removes the isolation background, preserves transparent silhouettes, resizes by asset category, and writes SHA-256 hashes.

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

The suite verifies the expanded map's size, symmetry, crossings, clearable grove density and connectivity, mirrored wildlife herds, cave placement, tree-blocked paths, projection round trips, all runtime asset paths, fog and minimap visibility, control groups, Shift-queued orders, repair, patrol, production cancellation, faction food restrictions, contextual hunting, prey flight, boar/bear retaliation, Food bounties, AI hunting, structure placement, harvest cadence, cave capture, economy, combat, and match victory. A native visual harness also captures the faction-specific food economy and a live wildlife hunt:

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

The authored scope and implementation contract are in [`docs/GAME_PROPOSAL.md`](docs/GAME_PROPOSAL.md) and [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md). Implemented feature proposals are in [`docs/COMMAND_SYSTEM_IMPLEMENTATION_PLAN.md`](docs/COMMAND_SYSTEM_IMPLEMENTATION_PLAN.md), [`docs/FOOD_SYSTEM_PROPOSAL.md`](docs/FOOD_SYSTEM_PROPOSAL.md), [`docs/MAP_REDESIGN_PROPOSAL.md`](docs/MAP_REDESIGN_PROPOSAL.md), [`docs/LUMBER_DESIGN_PROPOSAL.md`](docs/LUMBER_DESIGN_PROPOSAL.md), and [`docs/MONSTER_CAVES_PROPOSAL.md`](docs/MONSTER_CAVES_PROPOSAL.md). Generated-art review and provenance are in [`docs/ASSET_REVIEW.md`](docs/ASSET_REVIEW.md), [`assets/source/FOOD_BUILDING_GENERATION_PROMPTS.md`](assets/source/FOOD_BUILDING_GENERATION_PROMPTS.md), [`assets/source/GENERATED_ASSET_PROVENANCE.md`](assets/source/GENERATED_ASSET_PROVENANCE.md), [`assets/source/TREE_GENERATION_PROMPTS.md`](assets/source/TREE_GENERATION_PROMPTS.md), [`assets/source/EVERGREEN_TREE_GENERATION_PROMPTS.md`](assets/source/EVERGREEN_TREE_GENERATION_PROMPTS.md), and [`assets/source/MONSTER_CAVE_GENERATION_PROMPTS.md`](assets/source/MONSTER_CAVE_GENERATION_PROMPTS.md).
