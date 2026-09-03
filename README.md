# Game Template — RTS Agent Guide

**Game Template — RTS** is a browser-playable Godot 4.7.2 real-time strategy scaffold. It currently ships one complete four-faction free-for-all skirmish on an 80 × 80 isometric map, with one human player, three AI rivals, asymmetric economies, fog of war, formations, fortifications, capturable monster dens, regenerative wildlife, a guarded escort objective, generated art and audio, settings, and a local leaderboard.[1] [2]

This README is the operational contract for an AI agent that must **reskin the existing game**, **extend it without regressions**, or **pivot it into another strategy game**. Read `AGENTS.md` before editing.

![Game Template — RTS title screen](captures/title.png)

## 1. What exists and what still needs scaffolding

Do not describe a proposed capability as shipped. The current status is:

| Capability | Status | Agent guidance |
| --- | --- | --- |
| Complete game loop | **Implemented** | Title → faction selection → skirmish → result/rematch. |
| Playable stages | **One implemented stage** | The Fourfold Mandate is the current skirmish. Use the stage guidance below to add a tutorial or second scenario. |
| Start screen and faction selection | **Implemented** | Programmatically assembled in `scripts/main.gd`. |
| Match HUD, minimap, objectives, pause, and settings | **Implemented** | Preserve the alignment and input rules in this guide. |
| AI-generated background, foreground, characters, structures, UI, and cursors | **Implemented** | Runtime includes 94 processed visual assets derived from immutable source masters. |
| Visual effects, particles, fog filter, and game juice | **Implemented** | Bounded presentation records; they never own gameplay truth. |
| BGM and small SFX | **Implemented** | One looping score and 23 named SFX use a bounded audio director. |
| Local leaderboard | **Implemented** | Versioned local profile/history with backup recovery. |
| Hosted global leaderboard | **Adapter only** | The Web bridge exists, but this repository does not contain its host/backend. |
| First-play tutorial with callouts | **Not implemented** | The objective tracker and initial toast are guidance, not a tutorial state machine. |
| English/Simplified Chinese localization | **Not implemented** | Visible text is hard-coded English; there are no translation resources or `tr()` calls. |
| Durable gameplay/settings configuration | **Not implemented** | Current effect/audio settings survive screen rebuilds only for the current app session. |
| Config synchronization back to a sandbox/host | **Not implemented** | Add a validated versioned host bridge; a Web export cannot write directly to the sandbox. |
| Player-selectable difficulty | **Not implemented** | AI pacing is currently controlled by simulation constants. |

## 2. Non-negotiable architecture

> **Gameplay truth lives only in `RtsSimulation`.** UI, rendering, audio, fog display, effects, tutorial callouts, and developer tools may observe the model and submit validated commands; they must not become a second simulation.

| Layer | Primary files | Responsibility |
| --- | --- | --- |
| Application shell | `scenes/main.tscn`, `scripts/main.gd` | Builds title, faction, match, pause/settings, leaderboard, and result UI; owns application state and advances an unpaused match. |
| Authoritative model | `scripts/sim/rts_simulation.gd` | Players, entities, economy, fixed ticks, commands, pathfinding, visibility, AI, combat, objectives, score, victory, and semantic events. |
| Game data | `scripts/data/faction_catalog.gd`, `scripts/data/map_catalog.gd` | Faction identity/stats/capabilities/asset paths and authored map/scenario content. |
| Projection and view | `scripts/core/iso_projection.gd`, `scripts/view/` | Isometric conversion, camera, rendering, picking, fog presentation, minimap, and input translation. |
| Game juice | `scripts/view/effects/` | Bounded view-only effects, local transforms, hit flashes, health easing, and regenerated-wildlife fade-in. |
| UI system | `scripts/ui/` | Shared theme, command buttons, fallback icons, cursors, and leaderboard dialog. |
| Audio | `scripts/audio/audio_director.gd`, `default_bus_layout.tres` | Persistent score, cue routing, cooldowns, priorities, pitch variance, fog filtering, and a bounded 16-voice pool. |
| Persistence/services | `scripts/services/` | Local leaderboard profile/history and optional same-origin parent-window Web bridge. |

`RtsSimulation.advance(delta)` clamps one caller update to 0.25 seconds and executes fixed **1/30-second ticks**. The tick order is builder assignment, construction, passive Food, production, worker orders, combat/movement, unit separation, wildlife regeneration, egg synchronization, visibility, cave capture, AI, and state notification. Change this order only when a mechanic requires it and add regression coverage.[3]

Every gameplay action must use the public `command_*` surface. Commands validate issuer team, ownership, entity state, visibility, bounds, availability, affordability, population, placement, and commandability before mutation. Do not call private `_spawn_*` helpers from production UI code.

## 3. Game loop and stage strategy

### Existing one-stage game

The shipped loop is:

1. The title screen opens **Start Game** or the leaderboard.
2. The player chooses one of four factions.
3. `main.gd` creates a fresh simulation and Battlefield.
4. Each team starts with a Stronghold, three Workers, 320 Jade, 30 Lumber, 160 Essence, and 160 Food.
5. The player and three AI teams gather, build, train, hunt, capture dens, contest the Dragon Egg, and destroy Strongholds.
6. Player resignation or Stronghold loss is defeat. Destroying all three rival Strongholds is victory.
7. The result is recorded locally, then the player may rematch, change faction, inspect the leaderboard, or return to title.

### Recommended one-stage pivot

Use this path for a low-risk reskin. Preserve faction IDs, map shape, model commands, asset output names, UI node contracts, and tests. Replace source art, audio candidates, names, prose, colors, and theme. Regenerate derivatives, run focused tests, run the visual harness once, then export Web.

### Recommended two-stage pivot

Use two stages when teaching the game or introducing a larger rules change:

| Stage | Purpose | Recommended scope |
| --- | --- | --- |
| **Stage 1: Guided opening** | Teach selection, movement, gathering, construction, production, and one combat objective. | Smaller authored scenario, one opponent or scripted threat, tutorial callouts, constrained command unlocks, explicit completion condition. |
| **Stage 2: Full skirmish** | Exercise the complete RTS economy and neutral-objective race. | Current four-way map or a new full scenario with fog, AI economy, dens, wildlife, egg escort, and elimination victory. |

Add a data-driven stage definition rather than branching presentation code. A stage record should include a stable ID, map/scenario source, participating teams, starting state, enabled commands/mechanics, AI profile, objectives, tutorial sequence, completion rule, and next-stage ID. `main.gd` may choose and transition stages, but `RtsSimulation` must still own each stage’s gameplay truth. Update `MapCatalog`, startup validation, HUD objectives, persistence, and tests together.

## 4. Core RTS mechanics

### Factions

| Faction | Economy and combat identity | Food path |
| --- | --- | --- |
| **Celestial Court** | +15% deposited Essence; Mystics gain +0.8 range. | Rice Farms; cannot hunt. |
| **Demon Host** | A killer heals 12 HP and gains 3 Essence. | Hunter’s Lodges and hunting; cannot farm. |
| **Beast Clans** | Worker, Hunter, Vanguard, and Mystic speed +18%; Vanguard Jade cost −15. | Hunter’s Lodges and hunting; cannot farm. |
| **Human Dynasty** | +10% deposited Jade; War Camp resource costs −15% after rounding. | May farm and hunt. |

Faction display prose is not a mechanic. If a passive changes, update authoritative stats/deposit/kill/availability logic and tests. For a cosmetic reskin, preserve the `StringName` IDs and change only names, descriptions, colors, and mapped source art.

### Economy, Food, and population

Workers gather 10 units every 0.8 seconds, carry at most 50, and physically return cargo to their own Stronghold. Mixed cargo is banked before reassignment. Depleted lumber orders retarget another tree.

Every trainable unit costs Food and reserves its population and full cost when queued. Cancellation refunds recorded costs and population. A team with no living or queued Worker may queue exactly one free recovery Worker. Population begins at 24; Stronghold upgrades cost 200 and then 300 of every resource, including Food, and add six capacity per level up to level 3.

Rice Farms produce 8 Food every 40 seconds, multiplied fivefold while exactly one eligible nearby Worker staffs the completed Farm. Hunter’s Lodges produce 18 Food every 50 seconds and train Hunters. Keep the existing 12-minute farm-versus-hunting balance test valid when tuning either strategy.

### Combat, commands, formations, and navigation

The command system supports move, attack, attack-move, gather/deposit, Farm staffing, Dragon Egg claim/return, stop, resign, repair, construct, garrison/ungarrison, patrol, wall/gate/structure placement, production/cancellation, Stronghold upgrades, and rally points.

Group movement assigns unique nearby formation cells and may dispatch a partial formation when space is limited. A* pathfinding prevents diagonal corner cutting and repaths when a path-affecting revision changes. Ordinary friendly structures and friendly gates are traversable; friendly walls and towers remain solid; enemy structures block. Moving friendly units may pass through one another, then use damped separation to spread while idle. Workers are the slowest units and have heavier separation damping than combat units.

Attacks require hostility and current team visibility. Normal acquisition also respects line of sight. Ranged units may reposition tangentially between attacks. Attack-move and patrol resume their saved destination after combat. Hunters deal triple wildlife damage, prioritize wildlife and hostile Hunters, and evade unrelated combat threats unless explicitly ordered to attack.

### Fortifications and garrisons

Walls are 1 × 1. Gates are 4 × 2 on map X or 2 × 4 on map Y. Towers are 2 × 2. A wall drag validates the full dominant-axis line and charges atomically before creating foundations. Only deliberate same-team gate-corner and perpendicular-wall overlap is allowed.

A Sentry Tower holds up to **two** Hunters or Mystics. Garrisoned units are not directly commandable, automatically attack with double range and normal damage/line of sight, and eject when the tower is destroyed.

### Wildlife, caves, and the Dragon Egg

Chicken, deer, and bison flee. Boar and bear retaliate. Hunt-enabled factions receive species-specific Food bounties. Every authored herd regenerates one member at a time from empty to cap over five minutes, avoids solid/live-occupied cells, retries blocked territory without burst spawning, keeps renewable storage bounded, and emits a presentation event that fades the new animal in over 0.85 seconds.

Each neutral Yaoguai Den starts with three leashed Jadeclaw guardians. Each guardian yields 45 Jade, 30 Lumber, and 25 Essence. After all guardians die, one uncontested military team captures the ring in six seconds. Captured dens train Jadeclaws. Recapture cancels only the previous owner’s queued den production; existing Jadeclaws do not convert.

The central Shenlong locks the Dragon Egg until defeated. An empty-handed Worker can claim the unlocked egg and must carry it to a living home Stronghold to hatch one allied Shenlong. Carrier death or loss of the destination Stronghold drops the egg. AI avoids the Shenlong zone for the first ten minutes; the player does not. The current hatch does not reject a full population cap, so treat that behavior as an intentional exception or fix it with tests.

### AI pacing

The three AI teams use the same stockpiles, faction gates, build costs, population rules, fog-valid combat commands, and command APIs as the player. They receive no periodic resource stipend. They recruit Workers, establish War Camps and legal Food infrastructure, staff Farms, train Hunters, gather/scout, hunt, capture dens, contest Shenlong, and assault Strongholds.

AI strategy is timer-driven: decisions begin quickly, assault timers are staggered, standard waves use three military units after an initial delay, the Shenlong goal requires a larger force after the ten-minute lock, and a one-hour skill test sends all available military. There is no difficulty selector. Add difficulty as explicit simulation configuration; do not secretly modify AI resources.

## 5. UI, HUD, alignment, and input rules

All screens are created programmatically in `scripts/main.gd`; `scenes/main.tscn` contains only the root application node. Preserve focus, modal, and screen-rebuild contracts when editing the UI.[4]

### Screen inventory

| Screen or overlay | Existing contents | Required behavior |
| --- | --- | --- |
| Title | Covered key art, title, Start Game, leaderboard | Start receives initial keyboard focus. |
| Faction select | Four catalog-driven portrait cards, Back, control legend | First faction receives focus; callbacks keep the selected faction ID. |
| Match HUD | Score/resources/population/dens/time, objectives, minimap, inspection/selection, production and 4 × 3 command grid | Read state from simulation; expose commands only for valid player-owned selections. |
| Pause | Resume, Settings, Resign | Stops simulation and Battlefield input; Resume receives focus. |
| Settings | Audio, effect quality, reduced motion, camera impulse, damage values | Applies immediately to the active view; values are session-only. |
| Leaderboard | Local/Global tabs, callsign, status, ten rows | Opens above title/result overlays and restores initiating focus on close. |
| Result | Victory/defeat, rematch, leaderboard, faction select, title | Records exactly one local result and blocks further match input. |

### Reference geometry

The reference viewport is **1280 × 720** with `canvas_items` stretch. Major regions use anchors, but the current layout is desktop-first and has no breakpoint system.

| Region | Reference rule |
| --- | --- |
| Title action stack | Centered, approximately 520 × 218; primary/secondary actions approximately 340 px wide. |
| Faction cards | Centered 1180 × 500 row, 14 px separation; each card approximately 284 × 500. |
| Top HUD | Full width; 8 px side and 6 px top inset; 50 px height; 40 × 34 pause/audio controls. |
| Bottom HUD | Full width; 8 px side/bottom inset; 234 px height; 236 px minimap, flexible selection panel, 424 px command bay. |
| Command grid | 4 × 3 slots; each approximately 98 × 66. Keep persistent command modes grouped and visibly armed. |
| Objective tracker | Position approximately (10, 64); 326 × 154 expanded or 58 px collapsed. |
| Toast | Centered above the bottom deck, approximately 440 × 38. |
| Pause/settings | Centered approximately 420 × 380 and 460 × 560. |
| Leaderboard | Centered approximately 920 × 660; ten 31 px rows. |

Use `ThemeFactory` for shared colors, panels, buttons, progress bars, spacing, and modal styles. Use anchors and container size flags for major layout; avoid isolated hard-coded offsets except where the existing reference geometry is intentional. After any HUD reskin, test at 1280 × 720 and at least one narrow/short viewport. Add explicit breakpoints, scrolling, or UI scale before claiming mobile-native support.

### Input and focus invariants

`Escape` first cancels an armed command, then clears selection, then pauses. While paused, gameplay input is consumed. `Space` queues the selected producer’s first available unit before a focused HUD button can steal the key. Enemy and neutral entities may be inspected, but their selection must never expose player commands. Title focuses Start; faction select focuses its first card; pause focuses Resume; settings focuses Audio; result focuses Rematch.

### Isometric alignment and picking

`IsoProjection` defines 96 × 48 diamonds:

```text
screen_x = (map_x - map_y) × 48
screen_y = (map_x + map_y) × 24
```

Use `IsoProjection.position_center`, `entity_screen_position`, and existing map/screen conversion helpers. Do not independently change projection constants, center convention, minimap orientation, camera math, or picking.[5]

Sprites are grounded from measured transparent bottom margin and visible-content center. Unit/wildlife feet and selection rings share the projected tile center. Static art grounds on the southeast footprint edge. Painter order sorts by ground depth and then x, y, and entity ID. Garrisoned units are omitted from ordinary map rendering and composited into tower rooftop slots.

Contextual targeting uses visibility-gated tile priority plus transformed sprite alpha masks. Ambiguous sprite overlap falls back to tile picking. Preserve meaningful transparency, bottom-center contact, native facing metadata, and cursor hotspots in any reskin.

## 6. Presentation, particles, filters, and game juice

The presentation layer is deterministic and bounded. `EffectDirector` owns short-lived pulses, trails, impacts, particles, values, traces, residues, and camera impulses. `PresentationState` owns local attack/hit/selection/hover transforms, eased display health, and wildlife spawn opacity. Neither writes model state.[6]

The current feedback vocabulary includes selection/hover rings, placement ghosts, invalid-command pulses, dotted order routes, move/attack/rally/build/repair markers, four attack families, hit flashes, aggregated damage and economy values, construction/repair motes, death collapse/residue, movement facing/bounce/lean/squash/dust, tree sway, water sheen, Stronghold upgrade aura, Shenlong waves/wisps, and regenerated-wildlife fade-in.

The existing **filter layer** is battlefield fog plus organic map-edge fade; water has its own sheen/tint treatment. If adding a color grade, vignette, CRT treatment, weather filter, or faction vision mode, apply it to the Battlefield presentation rather than simulation state. Keep HUD readability outside destructive grading, draw fog after the world, preserve hidden-event filtering, and add a screenshot state for the effect.

Effect settings are `Full/Low`, reduced motion, `Off/Major/Full` camera impulse, and `Off/Contextual/All` damage values. Preserve pool caps, expiry, priority, and the performance budgets. Reduced motion must retain semantic state feedback while removing nonessential lunge, camera kick, foot dust, lean/squash, and collapse motion.

## 7. Full visual reskin playbook

### Runtime asset inventory

A complete same-shape reskin replaces **94 runtime visual outputs**. The repository currently has 103 source PNG masters because some retired alternatives and paintovers are retained outside the runtime catalog.[7]

| Category | Count | Runtime outputs and generation rules |
| --- | ---: | --- |
| Title key art | 1 | 1600 × 900 RGB WebP; opaque 16:9 battlefield composition; no embedded title, logo, UI, or text. |
| Faction portraits | 4 | 360 × 480 RGB WebP; opaque 3:4 commander portraits with consistent framing. |
| Terrain materials | 6 | 512 × 512 RGB WebP for meadow, ridge, water, forest, road, bridge; seamless, top-down, full bleed, no props/units/text. |
| Faction units | 15 | Worker/Vanguard/Mystic for four factions plus Hunter for Demon/Beast/Human; isolated, complete, three-quarter isometric, bottom-grounded. |
| Faction structures | 20 | Stronghold, War Camp, Wall, Gate, Sentry Tower for four factions; match footprint and orientation contracts. |
| Shared specials | 6 | Jadeclaw, Shenlong, Dragon Egg, Yaoguai Den, Rice Farm, Hunter’s Lodge; remain neutral/shared unless routing changes. |
| Wildlife | 5 | Chicken, deer, bison, boar, bear; distinct scale and silhouette; isolated and bottom-grounded. |
| Foreground resources | 6 | Jade outcrop, Essence shrine, pine/cedar/fir/juniper trees; no scenery or detached shadow. |
| HUD/command/cursor art | 31 | Idle alert, 6 resource icons, 4 utility icons, 3 command indicators, 17 cursors. Preserve exact semantic names and hotspots. |

### Master-generation contract

Do **not** hand-edit `assets/runtime/`, and do not overwrite an old source master in place. Add a new immutable source master, update the mapping in `tools/process_assets.py` when the source name changes, and keep the existing runtime output name unless code and tests deliberately change.[1] [7]

Use three background classes:

| Asset type | Source background |
| --- | --- |
| Title, portraits, terrain | Opaque full-frame art. Terrain must tile and contain no foreground object. |
| Isolated characters, buildings, wildlife, most resources/icons | Perfectly uniform edge-to-edge **`#FF00FF`** magenta; no gradient, noise, glow, cast shadow, or stray marks in the negative space. |
| Cursors, command indicators, Food icon, Audio Muted icon | Real transparent alpha; never render a checkerboard into RGB. |

**Current exception:** `assets/source/buildings/demon_wall.png` must use real transparency because its processor rule preserves source alpha. A magenta-backed Demon Wall would retain magenta in the runtime image. To remove this exception, change `tools/process_assets.py`, regenerate the derivative, and update the asset/fortification tests together.

A reliable GPT Image 2 prompt includes: **single subject**, gameplay role, faction material/palette, exact three-quarter isometric or top-down camera, readable silhouette at target size, bottom-center ground contact, soft consistent lighting, generous clear margin, and explicit exclusions for scenery, text, logo, watermark, cropping, multiple subjects, detached shadow, particles, and glow. Generate every faction family under one art-direction sheet before generating individual assets so scale, lighting, camera, and material language remain coherent.

Functional structure prompts must reflect gameplay: a repeatable 1 × 1 wall segment; a 2 × 4 gate with a legible opening; a roofless/open-platform 2 × 2 tower that can visibly hold two units; a 2 × 2 Stronghold/Farm/Den; and compact 1 × 1 Camp/Lodge. Preserve the aligned source overrides for current Celestial Wall and Demon Gate, or intentionally revise their processor/render rules and fortification captures.

### Processing and validation

```bash
cd /home/ubuntu/proto-rts
python3 -m venv .venv
.venv/bin/python -m pip install Pillow
.venv/bin/python tools/process_assets.py
sha256sum -c assets/runtime/SHA256SUMS

GODOT_BIN=/path/to/Godot_v4.7.2 tools/run_tests.sh
```

`tools/process_assets.py` rebuilds the full catalog and writes `assets/runtime/asset-report.json` plus `assets/runtime/SHA256SUMS`. Inspect source selection, dimensions, color mode, alpha extrema, and hashes. `assets.lock.json` is not the runtime manifest and is not regenerated by this processor.

Review units at several zoom levels; both wall/gate orientations and corners; tower occupant clearance; terrain tiling; tree/resource readability; cargo and Farm markers; command indicators; all cursor hotspots; and fog contrast. Run the native visual harness once after visible changes.

## 8. BGM and SFX reskin playbook

### BGM

The game uses one persistent looping score. Screen state changes gain instead of restarting playback. For a new reskin, use Manus **`generate_music` with Lyria 3 Pro or the latest available Lyria model**. Request an instrumental, loop-friendly strategy underscore with no speech or vocals, restrained dynamics under UI/SFX, a stable pulse, no abrupt final cadence, and instrumentation tied to the new setting. Generate and review a source comfortably longer than 12 seconds; two to three minutes is a useful production target.

If retaining the current path contract, place the reviewed source at the configured candidate root as `bgm/the_jade_meridian_endures.wav`. **Before processing a Lyria score, update `tools/process_audio_assets.py` so its report generator/provider/model metadata is supplied explicitly rather than using the current hard-coded legacy ElevenLabs value.** Add a validation assertion for that metadata, then process the score. Do not ship an `audio-report.json` that attributes Lyria output to ElevenLabs. Changing the BGM basename also requires updates to `AudioDirector`, manifests, asset tests, and the runtime file together. The current checked-in score was generated with Manus/ElevenLabs-era tooling; do not claim Lyria provenance until a Lyria reskin is actually generated.[8]

### Small SFX

Prefer an ElevenLabs-powered **`generate_sound_effect`** tool when available. Generate three materially distinct, equal-duration A/B/C variants for each cue. Concatenate them in A→B→C order into one reel at `/home/ubuntu/proto-rts-audio-candidates/reels/<cue>.mp3`; the processor splits that file into equal thirds. Use `--candidates /another/root` when storing reels elsewhere. Prompts should request one short, isolated, dry sound; no speech, music bed, long reverb, ambience, or stacked sequence. Keep frequent economy/combat ticks quieter and shorter than objectives, destruction, victory, or defeat.

If the ElevenLabs SFX tool is unavailable, instruct Manus to implement a small Godot fallback using `AudioStreamGenerator` or generated `AudioStreamWAV` data. Route the substitute through the same `AudioDirector` cue name, bus, cooldown, priority, and voice cap. Do not play procedural sounds directly from HUD or simulation code.

The existing SFX contract contains 23 names:

| Family | Cue names |
| --- | --- |
| UI | `ui_confirm`, `ui_cancel`, `ui_error`, `unit_select` |
| Orders | `order_move`, `order_attack`, `order_work` |
| Economy/build | `deposit_resource`, `harvest_food`, `repair_tick`, `structure_placed`, `structure_complete`, `unit_ready` |
| Combat | `attack_melee`, `attack_ranged`, `attack_magic`, `attack_beast`, `impact_damage`, `unit_death`, `structure_destroyed` |
| Objectives/results | `objective_secured`, `victory`, `defeat` |

`structure_complete` is packaged but intentionally not mapped for generic structure completion. The retired `gather_resource.ogg` must not be restored. Hidden non-player events must remain inaudible behind fog.

```bash
cd /home/ubuntu/proto-rts
python3 tools/process_audio_assets.py

# Equivalent with a different candidate root:
python3 tools/process_audio_assets.py --candidates /absolute/candidate/root

# Focused SFX iteration without touching BGM:
python3 tools/process_audio_assets.py \
  --only-sfx ui_confirm ui_cancel ui_error unit_select \
  --skip-bgm

# Deliberate reviewed A/B/C override:
python3 tools/process_audio_assets.py \
  --only-sfx unit_ready --skip-bgm \
  --select-candidate unit_ready=B

cd assets/runtime/audio
sha256sum -c SHA256SUMS
```

Review `assets/runtime/audio/audio-report.json`, then run `tests/audio_test.gd` and `tests/assets_test.gd`. Candidate reels and source BGM are external inputs; a fresh clone cannot recreate the current audio without providing them. The checked-in report contains machine-specific historical absolute paths, and the current processor serializes resolved absolute paths. Verify actual runtime files and SHA-256 values. If portable provenance is required, update the report serializer and its tests to emit repository-relative runtime paths before regenerating it.

## 9. Tutorial, localization, tweaks, and config sync

### First-play tutorial scaffold

The current objective tracker is always visible and the start toast appears each match. Neither stores progress. A real tutorial should use a separate, versioned model such as:

| Required part | Rule |
| --- | --- |
| Tutorial state | Stable tutorial ID, step ID, completed/skipped flag, schema version, and migration/reset behavior. |
| Trigger | Observe simulation state or semantic events; never mutate game truth from a callout. |
| Callout | Anchor to named HUD/world targets, avoid covering commands, support keyboard/controller dismissal, and remain legible at supported viewports. |
| Progression | Teach select → move → gather → deposit → build → train → attack; stage-specific steps may add fog, hunting, caves, or egg escort. |
| Persistence | Save first-play completion separately from leaderboard data. Offer replay and reset. |
| Tests | Verify trigger order, skip/replay, persistence, pause behavior, missing-anchor fallback, and both locales. |

### EN/CN scaffold

English is currently source text only. To add English and Simplified Chinese:

1. Replace visible hard-coded strings with stable translation keys and parameterized `tr()` formatting.
2. Add Godot translation resources for `en` and `zh_CN`, a fallback locale, and a language selection policy.
3. Localize faction identity, units, structures, commands, resources, objectives, tutorial steps, settings, errors, result copy, leaderboard status, and dynamic numeric phrases.
4. Bundle a font with Latin, punctuation, and Simplified Chinese coverage. Verify fallback and line breaking.
5. Audit fixed widths because Chinese labels may be shorter while mixed numbers/hotkeys can still overflow.
6. Add locale tests and visual captures for title, faction cards, HUD commands, tutorial callouts, pause/settings, and result.

Do not bake language text into generated images. Key art, portraits, icons, cursors, and command indicators must remain language-neutral.

### Tweak UI and synchronization

The shipped Settings pane controls audio mute, effect quality, reduced motion, camera impulse, and damage values. It does not persist. For an agent-facing balance/debug panel, add a typed allowlisted `TuningConfig` with explicit defaults and min/max validation. Useful fields include gather rate, production time, unit speed, AI decision/assault cadence, wildlife cycle, camera limits, effect quality, and tutorial debug step.

Persist local preferences through a separate versioned `ConfigFile` or JSON file under `user://`; never place them in the leaderboard profile. Provide Import/Export JSON for reproducible tuning.

A browser build cannot write directly back to the Manus sandbox. Optional sync requires a same-origin parent host or backend adapter. Use a versioned message envelope, allowlist keys and ranges, reject secrets and unknown fields, define local/host precedence and conflict behavior, provide offline fallback, and require explicit user intent before transmitting preferences. Keep the sync adapter outside simulation and hide developer-only controls in production.

## 10. Leaderboard and persistence

`LeaderboardStore` writes `user://mandate_of_myth_leaderboard.json` with schema version 1, a pseudonymous profile ID, sanitized callsign, lifetime totals, best score, last faction, and at most 30 local runs. It rotates a backup and recovers from a corrupt primary. Callsigns are 3–20 ASCII letters, numbers, spaces, hyphens, or underscores.[9]

The UI shows Local and Global tabs. `LeaderboardBridge` is only a same-origin `window.parent.postMessage` adapter. Without a compatible parent host, the Global tab times out and safely falls back to local data. This repository does not provide authentication, anti-cheat, consent/deletion flows, retry queue, host handler, or backend. Treat every bridge payload as untrusted and never expose local `run_history` publicly.

A production global leaderboard must validate its versioned envelope server-side, enforce bounds/rate limits/identity policy, correlate requests, sanitize rows, and define privacy/retention/deletion behavior. Client-submitted scores are not authoritative.

## 11. Safe pivot workflow

Use this sequence for every substantial pivot:

1. Read `AGENTS.md`, protect any existing uncommitted work, fetch, and use only a fast-forward pull. Never rewrite shared `main` history.
2. Declare whether each existing mechanic is **retained**, **reskinned**, **rebalanced**, **replaced**, or **removed**.
3. For model changes, edit catalogs/simulation first and add focused tests.
4. Adapt HUD/Battlefield/audio to consume the new state and semantic events.
5. Add or remap immutable source masters; regenerate runtime derivatives and manifests.
6. Run the smallest relevant tests while iterating.
7. Run `tools/run_tests.sh` after simulation/projection or cross-system changes.
8. Run the native visual harness once after UI/rendering/art changes; review images rather than trusting code alone.
9. Export Web once and verify non-empty HTML, JavaScript, WASM, and PCK files.
10. Run `git diff --check`, inspect `git status`, then commit only reviewed outputs. A Manus-created commit must include the required `Co-authored-by: Manus <noreply@manus.im>` trailer.

Feature removal must be complete. Remove its command/HUD affordance, event/audio cue, AI branch, catalog entry, map reservation, rendering/effect handling, persistence fields, and assertions. Do not leave a decorative button wired to nothing or a simulation rule with no feedback.

## 12. Verification and Web export

```bash
cd /home/ubuntu/proto-rts
export GODOT_BIN=/path/to/Godot_v4.7.2

# Registered 18-suite regression and performance gate:
GODOT_BIN="$GODOT_BIN" tools/run_tests.sh

# UI/render/art work: native reviewed captures (writes captures/):
"$GODOT_BIN" --path . --script tests/visual_capture.gd
"$GODOT_BIN" --path . --script tests/cursor_visual_capture.gd

# Release build:
mkdir -p build/web
"$GODOT_BIN" --headless --path . \
  --export-release Web build/web/index.html

test -s build/web/index.html
test -s build/web/index.js
test -s build/web/index.wasm
test -s build/web/index.pck

# Browser test; do not use file://:
python3 -m http.server 8060 --directory build/web
```

The Web preset is single-threaded and does not require cross-origin isolation. The preset excludes build outputs, captures, docs, and tests. High-resolution source-master image payloads stay out of the PCK because **`assets/source/.gdignore` must be preserved**; runtime reports may still contain their lightweight provenance path strings. Matching Godot 4.7.2 Web templates are required.[1] [10]

The performance regression expects the instrumented Battlefield to remain below a 33.3 ms p95 redraw budget and the minimap below 16.7 ms. Rebaseline only after deliberate rendering-budget changes, not to conceal regressions.

## 13. Common failure modes

| Failure | Prevention |
| --- | --- |
| UI changes authoritative state | Route intent through validated simulation commands and render returned state/events. |
| Art exists but never appears | Update source mapping, processor output, catalog/preload path, facing/size rule, test enumeration, and manifest together. |
| Units float or pick incorrectly | Preserve bottom-center ground contact, alpha, content margin, projection anchors, and native facing. |
| Fortifications misalign | Review both orientations, seams, gate corners, transparent contour, and faction-specific scale/anchor overrides. |
| AI stalls after rebalance | Recheck costs, reserves, Food path, affordability fallback, build priorities, and no-stipend tests. |
| Hidden actions leak through effects/audio | Keep player-visibility filtering before presentation/audio consumption. |
| Effects or SFX degrade long matches | Preserve bounded pools, expiry, cooldown, active-instance caps, and priority stealing. |
| “Tutorial” is only a toast | Implement versioned first-play state, ordered triggers, persistence, skip/replay, and locale-ready callouts. |
| “EN/CN support” is only themed art | Add translation keys/resources, fonts, locale selection, dynamic formatting, and visual tests. |
| Web config “syncs to sandbox” directly | Use an authenticated/validated host adapter; Web code has no direct sandbox filesystem access. |
| Global leaderboard is assumed secure | Supply the missing host/backend and validate all client data; the current bridge is only an adapter. |
| Generated outputs drift | Use processors, inspect reports, verify SHA-256 manifests, and never hand-edit runtime derivatives. |

## References

[1]: AGENTS.md "Repository contribution and architecture contract"
[2]: scripts/main.gd "Application shell, screens, HUD, and match lifecycle"
[3]: scripts/sim/rts_simulation.gd "Authoritative fixed-step RTS simulation"
[4]: scripts/ui/theme_factory.gd "Shared UI theme and component geometry"
[5]: scripts/core/iso_projection.gd "Isometric projection and inverse picking"
[6]: scripts/view/effects/effect_director.gd "Bounded presentation effects"
[7]: assets/source/GENERATED_ASSET_PROVENANCE.md "Generated visual asset provenance"
[8]: scripts/audio/audio_director.gd "Persistent music and bounded SFX routing"
[9]: scripts/services/leaderboard_store.gd "Local leaderboard profile and history persistence"
[10]: export_presets.cfg "Godot Web export configuration"
