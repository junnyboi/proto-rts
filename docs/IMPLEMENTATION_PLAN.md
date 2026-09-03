# Game Template - RTS — Detailed Implementation Plan

**Author:** Manus AI  
**Date:** 2 September 2026  
**Implementation root:** `/Users/jun/Documents/Projects/Games/proto-rts`

## 1. Delivery Strategy

The implementation will proceed as a sequence of independently verifiable vertical layers. The first layer establishes a browser-exportable Godot project. The second adds exact isometric projection and the authored battlefield. The third adds an authoritative simulation with entities and pathfinding. The fourth connects selection and contextual commands. The fifth completes economy, construction, production, combat, computer strategy, and match resolution. The sixth integrates generated artwork and presentation polish. The final layer validates native boot, focused tests, the production web export, and browser loading.

The project targets Godot 4.7.2 and uses only GDScript and engine-native APIs. The renderer will be `gl_compatibility`, which is the renderer Godot uses for WebGL 2.0 browser exports.[1]

## 2. Repository and File Layout

| Path | Purpose |
| --- | --- |
| `project.godot` | Runtime configuration, window stretch mode, input actions, and main scene |
| `export_presets.cfg` | Single-threaded Web release preset |
| `scenes/main.tscn` | Minimal root scene that delegates composition to code |
| `scripts/main.gd` | Application state machine for title, faction selection, match, pause, and result |
| `scripts/core/iso_projection.gd` | Pure projection, inverse projection, cell polygon, and depth functions |
| `scripts/data/faction_catalog.gd` | Four faction definitions, entity statistics, costs, passives, and art paths |
| `scripts/data/map_catalog.gd` | Authored map dimensions, terrain cells, starting positions, and resource nodes |
| `scripts/sim/rts_simulation.gd` | Authoritative players, entities, orders, pathfinding, economy, production, combat, AI, and outcome |
| `scripts/view/battlefield.gd` | Terrain and entity rendering, camera, input, selection, command previews, and view effects |
| `scripts/ui/theme_factory.gd` | Deterministic panel, button, label, and color styling |
| `assets/source/` | Immutable GPT Image 2 source images and prompts |
| `assets/runtime/` | Trimmed, resized, browser-efficient derivatives loaded by Godot |
| `tools/process_assets.py` | Deterministic chroma removal, trimming, and derivative generation |
| `tests/` | Headless projection and simulation smoke tests |
| `build/web/` | Exported browser bundle |

## 3. Application State Machine

`scripts/main.gd` will own the high-level states `TITLE`, `FACTION_SELECT`, `MATCH`, `PAUSED`, and `RESULT`. Screen changes will clear only presentation nodes and will create the next screen from deterministic helper methods. Starting a match will instantiate `RtsSimulation`, `Battlefield`, and the heads-up display. Ending a match will freeze simulation advancement while leaving interface animation active.

The title screen will use generated key art with deterministic labels and buttons layered above it. The faction-selection screen will present four generated faction portraits, strategic descriptions, passive summaries, and color-coded selection borders. The match screen will use a top resource bar, full central battlefield, bottom selection panel, bottom-right command grid, and compact help panel.

## 4. Isometric Coordinate System

The simulation stores every dynamic position in continuous **cell space**. A grid point `p = (x, y)` projects to screen space using:

```text
screen_x = (x - y) × tile_width ÷ 2
screen_y = (x + y) × tile_height ÷ 2
```

The inverse transform reconstructs cell space from the screen point. A selectable cell is `floor(unproject(local_point))`, while command handlers reject points outside the authored region. A 96 × 48 tile size provides enough visual area for generated sprites across the camera-scaled 80 × 64 battlefield. The transform is kept pure so tests can validate centers and boundaries without loading a scene.

The renderer will draw cells in increasing `x + y` order. Entities will use a depth key based on their current continuous cell position. This retains the core separation used by `proto-td`: gameplay state never depends on projection offsets, sprite dimensions, or camera movement.[2]

## 5. Authored Battlefield

The Jade Divide is represented by authored terrain and tree row strings expanded from a 40 × 32 macro-grid to an 80 × 64 battlefield. The symbols distinguish meadow, road, ridge, river, and three bridges. The map reserves mirrored base clearings, safe and contested resource clusters, three attack routes, harvestable forest topology, and two guarded Yaoguai Dens. Dimensions, placements, overlaps, resource definitions, and static walkability are validated at startup.

Generated meadow, stone, and water material images will be mapped across diamond polygons using repeated ultraviolet coordinates. The renderer may apply deterministic tint variation by cell to break repetition. It will not synthesize terrain art procedurally. Grid strokes, hover diamonds, and placement colors remain engine-drawn overlays because they communicate interaction state.

## 6. Data Model

Each player state contains the faction identifier, Jade, Essence, population, population cap, production modifiers, and AI timers. Each entity has a stable integer identifier and the following canonical fields:

| Field group | Fields |
| --- | --- |
| Identity | `id`, `team`, `kind`, `faction` |
| Spatial | continuous `position`, current `cell`, `radius`, `path`, `path_index` |
| Vital | `hp`, `max_hp`, `alive` |
| Combat | `damage`, `range`, `attack_period`, `attack_cooldown`, `target_id`, `stance` |
| Worker | `cargo_kind`, `cargo_amount`, `gather_target_id`, `gather_timer`, `build_order` |
| Structure | `footprint`, `production_queue`, `production_progress`, `rally_cell` |
| Presentation | `facing`, `flash_timer`, `selection_priority` |

Dictionaries are acceptable for the vertical slice because their serialization shape is transparent and the unit cap is small. Mutation remains private to the simulation. The view receives read-only snapshots by convention and issues commands through public methods.

## 7. Navigation and Occupancy

An `AStarGrid2D` instance will cover the authored map region. It will use four-directional movement, a Manhattan heuristic, and solid points for water, ridges, structures, and reserved resource cells. Godot’s grid A* API is designed for this exact partial-grid use case and supports changing point solidity without rebuilding graph edges manually.[3]

Movement commands calculate paths from the entity’s current cell to the requested destination. If the target is occupied, the simulation searches outward for the nearest walkable cell within a bounded radius. Allied structures are temporarily removed from A* solidity while an allied unit calculates its route, and moving allied units may pass through one another instead of becoming dynamic path obstacles. Workers travel at 1.30 cells per second and are slower than every controllable combat role; Hunters, Vanguards, Mystics, and Jadeclaws use progressively distinct combat travel speeds. The deterministic local solver restores separation as soon as both allied units are stationary, converting overlap penetration into bounded velocity and damping that velocity over subsequent fixed ticks. Workers use lower stiffness, stronger damping, and a lower separation speed cap for a heavy utility-unit feel, while combat units settle with higher stiffness, lighter damping, and a higher cap. Armies therefore ease into readable idle positions without snapping, drifting indefinitely, or creating friendly traffic jams. Hostile and neutral unit pairs continue to separate normally.

## 8. Input and Camera

The battlefield will interpret input in this order: active placement mode, interface exclusion, selection drag, single selection, and contextual command. The camera transform is view-only. It supports middle-button drag, `WASD` or arrow-key edge-independent panning, `Command` + mouse-wheel or trackpad pinch/spread zoom, and `Space` to center the player stronghold. Zoom will be clamped to a readable range and preserve the cursor’s world point.

Selection rules are deterministic. A click chooses the nearest selectable entity within a screen-space radius, with units preferred over structures when distances are equal. A drag selects all visible player units inside the rectangle. Right clicking an enemy issues focused attack orders. Right clicking a resource with workers selected assigns harvesting. Right clicking empty walkable ground issues movement. Pressing `F` arms an attack-move cursor for the next valid map click.

Every simulation command carries an explicit issuer team. Units, workers, production structures, deposit targets, and rally structures must belong to that issuer before state can mutate. The battlefield issues player commands; the computer commander uses the same checked surface as the rival team. Cross-team IDs are rejected even if a future interface or mod passes them directly.

## 9. Economy and Construction

Workers gather from Jade, Lumber, and Essence nodes. A gather cycle transfers a bounded amount into worker cargo. A full worker returns to the nearest friendly stronghold, deposits cargo with faction multipliers, and returns to its resource if it remains available. Lumber trees are finite clearable obstacles; Food is produced by completed Rice Farms and Hunter's Lodges.

When one or more workers are selected, the command panel exposes **Build War Camp**. Activating the command enters placement mode. A ghost footprint follows the hovered cell and reports validity. Valid placement requires walkable in-bounds cells, no resource or entity overlap, and enough resources. Confirming placement deducts the faction-adjusted cost and creates a partially complete structure. The worker constructs it over time and becomes available when construction completes.

## 10. Production and Population

The stronghold command panel exposes **Train Worker**. A completed War Camp exposes **Train Vanguard** and **Train Mystic**. Clicking a command validates resources and population, deducts the cost, and appends a queue item. Production progresses in simulation time. Completed units spawn at the nearest walkable cell and receive the structure’s rally point.

The vertical slice uses a fixed population cap of 24. This keeps the interface and combat readable while preserving production decisions. Population is refunded on unit death. Structures do not consume population.

## 11. Combat and Faction Passives

Military units in an attack stance search for the closest visible enemy within acquisition range and terrain-aware line-of-sight. A focused order pursues its target until the unit enters attack range with an unobstructed grid ray; ridges, trees, resources, and structures block acquisition and ranged damage. An attack applies deterministic damage after the cooldown expires and triggers a short view-only flash. Buildings can be attacked but do not move.

Faction modifiers are applied at explicit seams:

| Faction | Implementation seam |
| --- | --- |
| Celestial | Multiply Essence deposits by 1.15 and increase Mystic range |
| Demon | On enemy kill, heal the killing unit and add a small Essence bounty |
| Beast | Multiply movement speed by 1.18 and reduce Vanguard Jade cost |
| Human | Multiply Jade deposits by 1.10 and War Camp costs by 0.85 |

The simulation checks both strongholds after every destructive event. Loss of the enemy stronghold yields victory; loss of the player stronghold yields defeat.

## 12. Computer Commander

The computer commander runs a small strategic state machine rather than per-frame cheating. Both sides start with identical resources and worker counts. Every strategy interval it evaluates its military count, production structures, harvested resources, Food supply, cave control, and attack timer. It assigns workers across Jade, Lumber, and Essence; constructs and reconstructs its War Camp and food infrastructure through normal costs and build time; falls back to an affordable unit rather than deadlocking production; and hunts, captures, or attacks after reaching force thresholds. It receives no periodic resource stipend and no free production structure.

## 13. Generated Asset Pipeline

GPT Image 2 will create all representational visuals. Every unit and building prompt will use the same painterly isometric strategy style, three-quarter camera angle, upper-left lighting, complete centered silhouette, and flat magenta isolation background. Source images will be stored under `assets/source` with a prompt manifest.

`tools/process_assets.py` will perform deterministic processing:

1. Load a source PNG without altering the master.
2. Flood-fill edge-connected pixels close to the magenta key color.
3. Feather only the new alpha boundary.
4. Trim transparent margins while retaining controlled padding.
5. Resize units, buildings, portraits, and terrain to category-specific bounds.
6. Save optimized PNG or WebP derivatives under `assets/runtime`.
7. Write SHA-256 hashes to `assets/runtime/SHA256SUMS`.

A lightweight validation pass will confirm dimensions, alpha presence for world sprites, non-empty content, and exact file availability. Subjective repeated regeneration is out of scope unless a source has a fatal defect.

## 14. User Interface

The heads-up display will use a dark ink-and-lacquer palette with warm parchment text. Color remains faction-specific only for accents so resource and command semantics stay consistent. Buttons provide hover, pressed, disabled, and keyboard-focus states. Resource values and costs always use both labels and colors.

The bottom information panel will display selected entity name, role, health, current order, and queue state. Multi-selection will display count and composition. The command panel will refresh from the authoritative selection and resource state. A first-match help panel will list controls and the victory condition without blocking play.

The expanded renderer batches each authored 2 × 2 terrain macro-cell, culls entities before sorting, renders each nearby swaying tree with one textured draw, suppresses tree resource bars unless selected, and composites minimap terrain, entity, wildlife, and fog image layers. Strategic overview zoom renders one representative tree per authored grove cell and hides unreadable duplicate sprites and grid strokes. Ambient redraws are capped at 30 Hz while input actions still invalidate immediately.

## 15. Tests and Verification

| Gate | Method | Pass condition |
| --- | --- | --- |
| Projection | Headless GDScript test | Grid centers round-trip and edge cells pick correctly |
| Simulation | Headless GDScript test | Harvest, deposit, production, persistent attack-move, line-of-sight, separation, fair AI construction, combat, death, and result transitions succeed |
| Authority | Headless GDScript test | Player-issued commands cannot mutate rival movement, combat, gathering, repair, patrol, cargo, construction, queues, cancellation, population, or rally state |
| Performance | Instrumented headless draw test | With all 2,224 authored trees active, Battlefield p95 CPU draw stays at or below its 33.3 ms ambient-redraw budget and minimap p95 stays at or below 16.7 ms in full-map and fogged starting views |
| Import | Godot headless import | No parse or missing-resource errors |
| Boot | Bounded headless run | Main scene reaches idle without fatal errors |
| Visual | Native screenshot capture | Title, faction screen, and active match are legible at 1280 × 720 |
| Export | Godot Web release export | Non-empty `.html`, `.js`, `.wasm`, and `.pck` files exist |
| Browser | HTTP-served smoke test | Canvas loads, first screen renders, match starts, and browser console has no fatal errors |

The browser bundle will be served over HTTP for validation. Godot advises using `index.html`, keeping the generated companion filenames together, and testing web exports through a server rather than direct filesystem access.[1]

## 16. Completion Sequence

The final sequence is: regenerate runtime derivatives once, import once, run focused tests, perform one bounded boot, export the Web bundle once, start a local HTTP service, execute one browser smoke test, inspect the final Git diff, commit with asset provenance, create or connect `junnyboi/proto-rts`, push `main`, and verify the remote repository.

## References

[1]: https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html "Godot documentation: Exporting for the Web"
[2]: https://github.com/junnyboi/proto-td/blob/master/scripts/view/iso_projection.gd "proto-td isometric projection implementation"
[3]: https://docs.godotengine.org/en/4.7/classes/class_astargrid2d.html "Godot 4.7 AStarGrid2D class reference"
