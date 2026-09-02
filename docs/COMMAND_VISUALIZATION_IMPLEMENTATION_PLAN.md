# Selected-Unit Command Visualization Implementation Plan

## Goal

Show the active destination of selected player units directly on the battlefield without changing gameplay truth. Each displayed unit receives a dotted route from its current position to its active endpoint and one semantic endpoint marker:

- a command flag for movement toward a map tile;
- a rotating interaction ring for resource harvesting or structure interaction;
- crossed swords for an attack target, attached to the target as it moves.

The visualization exists only while its owning unit is selected. A multi-selection may show multiple routes, but no more than ten selected commandable units are projected. Identical visual records are drawn once.

## Architectural boundary

`scripts/sim/rts_simulation.gd` remains authoritative for orders, targets, movement, A* paths, combat, gathering, construction, repair, deposits, patrols, and command queues. This feature does not add, cache, or mutate gameplay state there.

`scripts/view/battlefield.gd` reads the active order, live target, current unit position, unconsumed path, and selection state on each draw. It converts those values into short-lived presentation records and renders them in screen space. This keeps command feedback synchronized with simulation state without creating a second source of truth.

## Affected architecture

```text
proto-rts/
├── assets/
│   ├── source/
│   │   ├── command_indicators/
│   │   │   ├── destination_flag.png
│   │   │   ├── interaction_ring.png
│   │   │   └── attack_swords.png
│   │   └── COMMAND_INDICATOR_GENERATION_PROMPTS.md
│   └── runtime/
│       ├── command_indicators/
│       │   ├── destination_flag.png
│       │   ├── interaction_ring.png
│       │   └── attack_swords.png
│       ├── asset-report.json
│       └── SHA256SUMS
├── docs/
│   └── COMMAND_VISUALIZATION_IMPLEMENTATION_PLAN.md
├── captures/
│   └── command-visualization.png
├── scripts/
│   └── view/
│       └── battlefield.gd
├── tests/
│   ├── assets_test.gd
│   ├── interaction_test.gd
│   └── visual_capture.gd
└── tools/
    └── process_assets.py
```

## Display-record derivation

The battlefield builds at most ten records from `selected_ids`, in stable selection order, and ignores non-player entities and non-unit selections. Each record contains only display data:

- `unit_id`: the selected unit that owns the record;
- `kind`: `flag`, `interact`, or `attack`;
- `target_id`: a live entity ID when the endpoint follows an entity;
- `endpoint`: the current world-space endpoint;
- `points`: current unit position followed by the unconsumed A* path and endpoint;
- `dedupe_key`: semantic endpoint plus the normalized remaining route.

The active order maps to visuals as follows:

| Active state | Endpoint | Indicator |
| --- | --- | --- |
| `move` | final remaining path point | destination flag |
| `attack_move` with no acquired target | attack-move destination | destination flag |
| `patrol` with no acquired target | current patrol leg target | destination flag |
| `gather` | live resource center | spinning interaction ring |
| `return` | live Stronghold center, including automatic cargo return | spinning interaction ring |
| `build` | live construction target center | spinning interaction ring |
| `repair` | live allied structure center | spinning interaction ring |
| `attack`, or attack-move/patrol with a live hostile target | live hostile center | crossed swords |
| idle, invalid target, dead unit, or unsupported state | none | none |

Only the active order is shown. Shift-queued commands become visible when the simulation activates them.

## Path and endpoint behavior

The route begins at the selected unit’s current fractional position, not its integer cell. The path then uses `path_index` and the remaining `path` entries so completed waypoints never remain visible.

For entity targets, the final display point is replaced with the entity’s live center every frame. This provides immediate visual tracking between the simulation’s bounded A* repath intervals. Consecutive equivalent points are collapsed to avoid zero-length segments and dense dot clusters.

When an interaction unit has already reached range and its simulation path is empty, the visualization remains as a direct short route plus endpoint ring until the order completes. When an attacker is already in range, the crossed-swords marker remains attached to the target and the line joins the two live positions.

## Deduplication and performance limit

`MAX_VISIBLE_COMMAND_PATHS` is fixed at 10. Selection traversal stops after ten eligible commandable units, preventing path rendering work from scaling with army-sized selections.

Records are deduplicated only when all of the following match:

1. indicator kind;
2. live target ID, or the quantized static endpoint;
3. the quantized remaining route points.

This removes exact overlaps without merging nearby formations or routes that merely share a destination. The first stable selection record owns the rendered route and icon.

## Rendering

Dotted routes are generated procedurally in screen space with consistent pixel spacing, a dark underlay for terrain contrast, and a jade/gold/red semantic foreground. Drawing circles instead of a dashed polyline preserves the requested dotted appearance through corners and camera zoom.

Endpoint assets are transparent GPT Image 2 masters processed into compact runtime PNGs. The flag receives a restrained hover pulse, the interaction ring continuously rotates, and the crossed swords receive a subtle combat pulse. Indicators remain screen-legible by clamping their screen size across camera zoom levels.

Command feedback is drawn after fog and entities so issued orders remain readable while exploring and target markers remain visible over moving sprites. The display layer does not alter visibility queries, selection hit testing, or minimap state.

## Asset workflow

New masters are added under `assets/source/command_indicators/`; no existing source asset is overwritten. `tools/process_assets.py` trims transparent padding, scales the images into fixed transparent canvases, writes the runtime derivatives, and regenerates `assets/runtime/asset-report.json` plus `assets/runtime/SHA256SUMS`. The exact built-in GPT Image 2 prompts are stored in `assets/source/COMMAND_INDICATOR_GENERATION_PROMPTS.md`.

## Verification

Automated coverage verifies:

- all three runtime textures resolve and the runtime asset count increases by three;
- move, gather/interaction, and attack states map to the correct indicator;
- attack endpoints follow a target after its position changes;
- exact duplicate records collapse to one;
- more than ten selected units never produce more than ten route records;
- deselection produces no records.

The project test gate is run once after implementation. The native visual harness adds one deterministic capture containing a movement flag, an interaction ring, and moving-target attack swords, then runs once. The capture is inspected at original resolution for route contrast, endpoint legibility, animation-safe placement, and overlap behavior.

## Acceptance criteria

- Dotted paths and endpoint markers appear only for selected player units with a supported active order.
- Movement, interaction, and attack use the requested three distinct symbols.
- Attack swords and the last path segment follow the live enemy position.
- Multi-selection renders distinct active routes and removes only exact overlaps.
- No more than ten selected commandable units contribute visualization records.
- No gameplay decision or authoritative order state is introduced in the view.
- New source art is generated with GPT Image 2, runtime art is produced only by `tools/process_assets.py`, and runtime reports/checksums are current.
- Automated tests and one native visual-harness run pass.
