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

The current project is a four-faction free-for-all played on **The Fourfold Mandate**, an 80 × 80 archipelago. The player keeps their chosen faction; the other three factions are each assigned to an AI with its own island, Stronghold, Workers, economy, and fog state. There are no alliances: every surviving faction is hostile to every other faction. Four resource-light corner islands each have one non-buildable Moon Bridge into a large, resource-rich central continent. The four starts are symmetric; the center contains 24 Jade and Essence deposits, 255 harvestable trees, 68 animals, four guarded Yaoguai Dens, and a neutral Shenlong guarding a Dragon Egg. Defeat Shenlong, claim the unlocked egg with an empty-handed Worker, and physically escort it home to hatch an allied Shenlong. A killed carrier drops the egg for anyone to steal. Destroying one rival no longer ends the match: victory requires the player to be the last surviving Stronghold.

Standing trees block movement and construction; logging them opens routes and build sites. Every new unit requires Food, supplied by Rice Farms, Hunter's Lodges, and hunting. Neutral Jadeclaws guard each den and drop mixed resource bounties. Clear the pack, hold the capture ring, and the den becomes a forward production point for player-aligned monsters. All three computer commanders build, hunt, capture, contest Shenlong, extract the egg, and attack through the same authoritative rules as the player.

| Unit or structure | Function |
| --- | --- |
| **Worker** | Harvests Jade, Lumber, and Essence; returns cargo; and constructs military or food infrastructure |
| **Vanguard** | Durable melee infantry used for direct assaults |
| **Mystic** | Fragile ranged attacker purchased with Jade and Essence |
| **Jadeclaw** | Durable cave monster; neutral guardians drop resources and captured dens produce aligned Jadeclaws |
| **Shenlong** | Mythic combat unit hatched by returning the central Dragon Egg to a living Stronghold |
| **Dragon Egg** | Locked central objective; an empty-handed Worker can carry it after the neutral Shenlong falls |
| **Stronghold** | Resource drop-off, worker production, and primary defeat condition |
| **War Camp** | Produces Vanguards and Mystics; costs Jade, Lumber, and Essence |
| **Rice Farm** | Cheap 2 × 2 producer; yields 8 Food every 40 seconds, or five times that output while staffed by a Worker |
| **Hunter's Lodge** | Compact producer; yields 18 Food every 50 seconds and trains bounty-earning Hunters |
| **Yaoguai Den** | Guarded neutral objective; capture it to unlock Jadeclaw production |

## Controls

| Input | Action |
| --- | --- |
| Left click | Select a friendly entity or inspect any visible rival, neutral, wildlife, or resource entity in the HUD; hold `Shift` to toggle friendly selections |
| Left drag | Box-select friendly units; hold `Shift` to add them |
| Right click ground | Move selected units; hold `Shift` to queue the order |
| Right click resource | Assign selected workers to gather; hold `Shift` to queue the source |
| Right click enemy | Focus-fire selected units; hold `Shift` to queue the target |
| Right click damaged allied structure | Repair it with selected workers |
| Right click Yaoguai Den | Hunt its guardians, move into its capture ring, or set its rally point when owned and selected |
| Right click Dragon Egg | Claim an unlocked egg with selected empty-handed Workers; right click the home Stronghold to reinforce its return order |
| Right click with structure selected | Set rally point |
| `F`, then left click | Attack-move; hold `Shift` while arming or confirming to queue it |
| `T`, then left click | Patrol repeatedly between the unit's position and the destination |
| `R`, then left click | Repair a damaged allied structure with selected workers |
| `Ctrl/Cmd` + `0–9` | Assign the current selection to a control group; add `Shift` to extend it |
| `0–9` | Recall a control group; add `Shift` to merge it with the selection; double-tap to center |
| `X` | Stop selected units and clear queued orders |
| `Q` | Select all workers |
| `I` | Select all idle workers |
| `E` | Select the army |
| `Space` | Select and center the player Stronghold |
| `WASD` or arrow keys | Pan the battlefield |
| Middle mouse drag | Pan the battlefield |
| `Command` + mouse wheel, or trackpad pinch/spread | Zoom |
| Minimap click or drag | Recenter the battlefield camera; the minimap is screen-oriented so `W/A/S/D` move its camera outline up/left/down/right |
| Fog of War button | Toggle battlefield and minimap visibility masking |
| `P` or `Escape` | Pause; `Escape` cancels an armed command first, then clears the current selection before pausing |
| `M` or Audio button | Toggle music, interaction cues, and gameplay SFX |

## Factions

| Faction | Passive |
| --- | --- |
| **Celestial Court** | +15% Essence income; Mystics gain +0.8 range |
| **Demon Host** | Kills heal the attacker and yield 3 Essence |
| **Beast Clans** | Units move 18% faster; Vanguards cost 15 less Jade |
| **Human Dynasty** | +10% Jade income; War Camps cost 15% less |

## Architecture

The simulation stores positions in continuous grid coordinates. `IsoProjection` converts those coordinates to a 2:1 diamond view and performs inverse picking. `RtsSimulation` owns all four team states, resources, food harvest timers, entities, active and queued orders, egg ownership, elimination, repair costs, patrol routes, production refunds, navigation, gathering, line-of-sight combat, AI, outcome state, and semantic effect metadata. Every mutable command requires an explicit issuer team and rejects foreign unit, worker, structure, queue, cargo, or rally IDs before mutation. `Battlefield` reads that state, owns local control-group selection shortcuts, renders the match, translates input into player-authorized simulation commands, and forwards only player-visible events. Its renderer batches authored terrain and fog, culls entities before sorting, uses strategic tree/grid level-of-detail, and caps ambient redraws at 30 Hz; the minimap composites cached image layers. `AudioDirector` persists beneath the root application node, loops the score across screen transitions, maps semantic events to generated cues, and enforces cooldown, priority, pitch variation, visibility, mute, and a bounded 16-voice pool. `main.gd` owns the application screens, heads-up display, and high-level music state.

The design borrows the clean model/view boundary from [`junnyboi/proto-td`](https://github.com/junnyboi/proto-td), but the terrain renderer, map, factions, economy, simulation, controls, assets, interface, and gameplay are original to this repository.

## Generated asset pipelines

All representational game art was generated specifically for this project with **GPT Image 2**. The active runtime manifest contains 82 optimized derivatives generated from immutable masters under `assets/source/`; retired concepts and seasonal tree masters remain outside the runtime build. The repeatable processing tool removes the isolation background, preserves transparent silhouettes, resizes by asset category, and writes SHA-256 hashes.

```bash
python3 -m venv .venv
.venv/bin/python -m pip install Pillow
.venv/bin/python tools/process_assets.py
```

Godot ignores `assets/source/` through `.gdignore`, so the high-resolution masters do not enter the browser PCK.

The complete audio vocabulary was generated specifically for this project with the built-in **ElevenLabs** integrations. It contains one Chinese-mythology strategy score, **The Jade Meridian Endures**, plus 23 runtime SFX covering interface confirmation and rejection, selection, movement and work orders, depositing, food harvests, repairs, construction, production, four attack signatures, damage, deaths, structure destruction, objectives, victory, and defeat. The four interface-family cues use pipa, guzheng, guqin, bamboo, bangu, and paiban; the regenerated unit-completion cue uses a warm deep taiko strike followed by a tighter taiko punctuation. The same score plays continuously on the title screen and in a skirmish; state transitions change gain rather than restarting playback.

`tools/process_audio_assets.py` divides each three-variant audition reel, scores candidates by decoded integrity, active-signal ratio, RMS level, peak headroom, and silence, then trims, fades, normalizes, and writes 48 kHz stereo Ogg Vorbis files. The score receives a four-second equal-power seam crossfade. Full source and runtime SHA-256 hashes, selected variants, durations, and byte sizes are written to `assets/runtime/audio/audio-report.json`.

```bash
python3 tools/process_audio_assets.py
# Focused replacement without re-encoding unrelated SFX or BGM:
python3 tools/process_audio_assets.py --only-sfx ui_confirm ui_cancel ui_error unit_select --skip-bgm
# Reviewed candidate override for the taiko unit-completion cue:
python3 tools/process_audio_assets.py --only-sfx unit_ready --skip-bgm --select-candidate unit_ready=B
```

The project uses `Music`, `SFX`, and `UI` audio buses without runtime effects so the default low-latency Godot Web Sample playback remains compatible with the single-threaded export.

## Tests

Run the focused suite:

```bash
tools/run_tests.sh
```

The 15-suite runner verifies the four-island topology, four independent bridges, symmetric starts and economy, central connectivity, 255-tree grove density, 68 wildlife spawns, four caves, four-team fog and command authority, last-Stronghold victory, the guarded egg lifecycle, carrier drops, allied Shenlong hatching, projection round trips, all 106 runtime image and audio asset paths, cursor and HUD state, control groups, queued orders, repair, patrol, cancellation, formations, line-of-sight combat, fair multi-AI economy, hunting, harvesting, capture, combat, and instrumented Battlefield/minimap draw budgets. A native visual harness captures the map overview, Shenlong objective, egg carrier, food economy, command visualization, redesigned HUD, and wildlife hunt:

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

The implemented archipelago proposal, affected-file plan, acceptance contract, and GPT Image 2 concept designs are in [`docs/FOUR_PLAYER_MAP_PROPOSAL.md`](docs/FOUR_PLAYER_MAP_PROPOSAL.md). The original scope and implementation contract are in [`docs/GAME_PROPOSAL.md`](docs/GAME_PROPOSAL.md) and [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md). The wide RTS benchmark and roadmap are in [`docs/RTS_GAMEPLAY_RESEARCH_AND_FEATURE_PROPOSAL.md`](docs/RTS_GAMEPLAY_RESEARCH_AND_FEATURE_PROPOSAL.md). Other implemented feature proposals and generated-art provenance remain under [`docs/`](docs/) and [`assets/source/`](assets/source/).
