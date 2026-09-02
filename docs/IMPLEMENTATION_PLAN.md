# Mandate of Myth — Detailed Implementation Plan

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

The inverse transform reconstructs cell space from the screen point. A selectable cell is `floor(unproject(local_point))`, with boundary clamping. A 96 × 48 tile size will provide enough visual area for generated sprites while fitting the 20 × 16 battlefield in a 1280 × 720 browser viewport. The transform is kept pure so tests can validate centers and boundaries without loading a scene.

The renderer will draw cells in increasing `x + y` order. Entities will use a depth key based on their current continuous cell position. This retains the core separation used by `proto-td`: gameplay state never depends on projection offsets, sprite dimensions, or camera movement.[2]

## 5. Authored Battlefield

The Jade Meridian map will be represented by arrays of terrain row strings. The symbols will distinguish meadow, stone ridge, and water. The map will reserve two base clearings, two safe resource clusters, a contested central Essence cluster, and at least two valid attack routes. Static walkability will be validated at startup.

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

Movement commands calculate paths from the entity’s current cell to the requested destination. If the target is occupied, the simulation searches outward for the nearest walkable cell within a bounded radius. Unit-to-unit collision uses lightweight local separation rather than dynamic path obstacles. This avoids expensive graph mutation for every moving entity while preventing complete visual overlap.

## 8. Input and Camera

The battlefield will interpret input in this order: active placement mode, interface exclusion, selection drag, single selection, and contextual command. The camera transform is view-only. It supports middle-button drag, `WASD` or arrow-key edge-independent panning, mouse-wheel zoom, and `Space` to center the player stronghold. Zoom will be clamped to a readable range and preserve the cursor’s world point.

Selection rules are deterministic. A click chooses the nearest selectable entity within a screen-space radius, with units preferred over structures when distances are equal. A drag selects all visible player units inside the rectangle. Right clicking an enemy issues focused attack orders. Right clicking a resource with workers selected assigns harvesting. Right clicking empty walkable ground issues movement. Pressing `A` arms an attack-move cursor for the next valid map click.

## 9. Economy and Construction

Workers gather from Jade and Essence nodes. A gather cycle transfers a bounded amount into worker cargo. A full worker returns to the nearest friendly stronghold, deposits cargo with faction multipliers, and returns to its resource if it remains available. Resource nodes are finite but sized so a normal match does not exhaust every cluster.

When one or more workers are selected, the command panel exposes **Build War Camp**. Activating the command enters placement mode. A ghost footprint follows the hovered cell and reports validity. Valid placement requires walkable in-bounds cells, no resource or entity overlap, and enough resources. Confirming placement deducts the faction-adjusted cost and creates a partially complete structure. The worker constructs it over time and becomes available when construction completes.

## 10. Production and Population

The stronghold command panel exposes **Train Worker**. A completed War Camp exposes **Train Vanguard** and **Train Mystic**. Clicking a command validates resources and population, deducts the cost, and appends a queue item. Production progresses in simulation time. Completed units spawn at the nearest walkable cell and receive the structure’s rally point.

The vertical slice uses a fixed population cap of 24. This keeps the interface and combat readable while preserving production decisions. Population is refunded on unit death. Structures do not consume population.

## 11. Combat and Faction Passives

Military units in an attack stance search for the closest visible enemy within acquisition range. A focused order pursues its target until the unit enters attack range. An attack applies deterministic damage after the cooldown expires and triggers a short view-only flash. Buildings can be attacked but do not move.

Faction modifiers are applied at explicit seams:

| Faction | Implementation seam |
| --- | --- |
| Celestial | Multiply Essence deposits by 1.15 and increase Mystic range |
| Demon | On enemy kill, heal the killing unit and add a small Essence bounty |
| Beast | Multiply movement speed by 1.18 and reduce Vanguard Jade cost |
| Human | Multiply Jade deposits by 1.10 and structure costs by 0.85 |

The simulation checks both strongholds after every destructive event. Loss of the enemy stronghold yields victory; loss of the player stronghold yields defeat.

## 12. Computer Commander

The computer commander runs a small strategic state machine rather than per-frame cheating. Every strategy interval it evaluates its military count, production structures, resources, and attack timer. It builds one War Camp if none exists, maintains workers up to a small limit, alternates Vanguard and Mystic production, and launches all idle military units toward the player stronghold after reaching a force threshold or maximum wait.

The computer receives a transparent periodic income stipend. The stipend compensates for deliberately simplified worker micro and is disclosed in the in-game help panel as the selected difficulty rule. It does not modify combat statistics, sight, pathfinding, or build times.

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

## 15. Tests and Verification

| Gate | Method | Pass condition |
| --- | --- | --- |
| Projection | Headless GDScript test | Grid centers round-trip and edge cells pick correctly |
| Simulation | Headless GDScript test | Harvest, deposit, production, combat, death, and result transitions succeed |
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
