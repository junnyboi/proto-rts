# Mandate of Myth

**Mandate of Myth** is a browser-playable real-time strategy skirmish built in Godot 4.7.2. Four original factions inspired by Chinese mythology compete for the Jade Meridian: the **Celestial Court**, **Demon Host**, **Beast Clans**, and **Human Dynasty**.

![Mandate of Myth title screen](captures/title.png)

## Play

The hosted Web build is published at **[junnyboi.github.io/proto-rts](https://junnyboi.github.io/proto-rts/)** after the GitHub Pages workflow completes.

For native play, open the project in Godot 4.7.2 or run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## Complete skirmish loop

The current release is a focused one-versus-one vertical slice. It includes faction selection, asymmetric faction passives, two-resource harvesting, worker cargo and drop-off behavior, War Camp construction, queued unit production, population limits, generated faction-specific unit and building art, click and box selection, formation movement, contextual commands, A* pathfinding, real-time melee and ranged combat, computer production and attacks, faction kill and economy modifiers, victory, defeat, pause, and rematch.

| Unit or structure | Function |
| --- | --- |
| **Worker** | Harvests Jade and Essence, returns cargo, and constructs War Camps |
| **Vanguard** | Durable melee infantry used for direct assaults |
| **Mystic** | Fragile ranged attacker purchased with Jade and Essence |
| **Stronghold** | Resource drop-off, worker production, and primary defeat condition |
| **War Camp** | Produces Vanguards and Mystics |

## Controls

| Input | Action |
| --- | --- |
| Left click | Select one friendly entity |
| Left drag | Box-select friendly units |
| Right click ground | Move selected units |
| Right click resource | Assign selected workers to gather |
| Right click enemy | Focus-fire selected units |
| Right click with structure selected | Set rally point |
| `A`, then left click | Attack-move |
| `S` | Stop selected units |
| `Q` | Select all workers |
| `E` | Select the army |
| `Space` | Select and center the player Stronghold |
| Arrow keys | Pan the battlefield |
| Middle mouse drag | Pan the battlefield |
| Mouse wheel | Zoom |
| `P` or `Escape` | Pause; `Escape` cancels an armed command first |

## Factions

| Faction | Passive |
| --- | --- |
| **Celestial Court** | +15% Essence income; Mystics gain +0.8 range |
| **Demon Host** | Kills heal the attacker and yield 3 Essence |
| **Beast Clans** | Units move 18% faster; Vanguards cost 15 less Jade |
| **Human Dynasty** | +10% Jade income; War Camps cost 15% less |

## Architecture

The simulation stores positions in continuous grid coordinates. `IsoProjection` converts those coordinates to a 2:1 diamond view and performs inverse picking. `RtsSimulation` owns all resources, entities, orders, navigation, gathering, queues, combat, AI, and outcome state. `Battlefield` reads that state for rendering and translates input into simulation commands. `main.gd` owns the application screens and heads-up display.

The design borrows the clean model/view boundary from [`junnyboi/proto-td`](https://github.com/junnyboi/proto-td), but the terrain renderer, map, factions, economy, simulation, controls, assets, interface, and gameplay are original to this repository.

## Generated asset pipeline

All representational game art was generated specifically for this project with **GPT Image 2**. The repository retains 30 immutable source masters under `assets/source/` and 30 optimized derivatives under `assets/runtime/`. The repeatable processing tool removes the isolation background, preserves transparent silhouettes, resizes by asset category, and writes SHA-256 hashes.

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

The suite verifies projection round trips, all 30 runtime asset paths, resource harvesting, deposits, construction, production, combat, and match victory. A native visual harness captures the title, faction selection, and skirmish screens:

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

The authored scope and implementation contract are in [`docs/GAME_PROPOSAL.md`](docs/GAME_PROPOSAL.md) and [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md). Generated-art review and provenance are in [`docs/ASSET_REVIEW.md`](docs/ASSET_REVIEW.md) and [`assets/source/GENERATED_ASSET_PROVENANCE.md`](assets/source/GENERATED_ASSET_PROVENANCE.md).
