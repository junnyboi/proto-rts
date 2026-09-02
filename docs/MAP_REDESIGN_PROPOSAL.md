# The Jade Divide Map Redesign

**Status:** Implemented 2 September 2026
**Target:** Godot 4.7.2 and desktop browsers
**Scope:** One-versus-one skirmish map, terrain presentation, navigation validation, and camera usability

## Proposal

The original 20 × 16 board was readable but compressed economy, army movement, and base assault into one open arena. The Jade Divide first established a 40 × 32 authored layout, then expands every authored cell to a 2 × 2 gameplay block. The resulting 80 × 64 battlefield has four times the previous playable area and sixteen times the original board's area. Its strategic structure is inspired by the useful parts of a classic three-lane arena map—opposing corner bases, a central dividing river, limited crossings, and jungle space between routes—while retaining Game Template - RTS's original art direction, economy, factions, and RTS simulation.

The redesign deliberately changes map topology without adding hidden combat rules. Ridge and water are static blockers; forest space is formed by harvestable tree entities over meadow. Meadow, road, and bridge are walkable when not occupied, and only meadow is buildable. Unit movement, A* navigation, construction checks, resource ownership, and win conditions remain authoritative in `RtsSimulation` and `MapCatalog`; textures, camera state, fog, and minimap feedback remain presentation concerns in `Battlefield` and `BattlefieldMinimap`.

## Spatial contract

| Property | Implemented value | Design purpose |
| --- | --- | --- |
| Dimensions | 80 × 64, 5,120 cells | Four times the previous 1,280-cell area |
| Symmetry | Exact 180-degree rotational terrain symmetry | Equal approach geometry and travel opportunities |
| Bases | Player southwest, enemy northeast | Clear territorial identity and a long strategic front |
| River | Three-cell diagonal band | Hard territorial separator and readable battle line |
| Crossings | Three crossings, each two rows wide | Predictable conflict points without one choke deciding the match |
| Tree groves | 1,016 harvestable blockers in mirrored clusters | Mutable jungle pockets, flanking corridors, ambush edges, and lane separation |
| Roads | 472 walkable, non-buildable cells | Legible primary routes and protected traffic flow |
| Ridge | 40 impassable cells | Small routing knuckles that prevent overly straight jungle movement |
| Economy nodes | 12 Jade/Essence nodes plus 1,016 harvestable trees | Safe openings, progressively riskier expansion, and mutable logging routes |

## Route structure

The three routes form distinct strategic choices:

1. The high route follows the outer bank to a narrow northern crossing. It is the longest approach and exposes an army to multiple jungle exits.
2. The Meridian route is the most direct base-to-base line. It reaches the broad central Moon Gate and is the natural location for early army contact.
3. The low route wraps around the opposite perimeter to the southern crossing. It offers a long flank and access to the second jungle economy pocket.

Each road has a walkable shoulder carved through the tree groves. This supports small formations and prevents a single occupied cell from visually reducing a lane to a thread. Meadow connections between lanes form rotation paths, but standing trees block direct shortcuts and make crossing choice meaningful until players invest worker time in logging.

## River and crossings

The river follows the rotationally invariant diagonal around `x - y = 4`. It separates the two starting territories continuously from one map edge to the other. Ordinary river cells are impassable. Bridge cells use the same A* cost as meadow so no new movement modifier is hidden from the player.

The high and low crossings are paired outer fords at rows 10–13 and 50–53. The central Moon Gate occupies rows 30–33. All three span the complete river width, and automated connectivity validation confirms that starting armies can reach one another through the authored walkable network.

## Forest and jungle design

Trees are arranged as clustered masses rather than a decorative border. Two main jungle bands sit between the three lanes on each side, with smaller edge groves and ridge knuckles shaping their entrances. The former 236 painted forest macro-cells expand into 944 tree entities rooted in meadow, so players see the same objects that actually block A* movement and construction.

The large overlapping pine, cedar, fir, and juniper canopies create a dark, dense evergreen silhouette at gameplay zoom. Their trunks remain anchored to individual cells, and the fog-aware minimap consolidates their green markers into readable grove masses. The warm road and pale bridge provide complementary navigation cues. When a tree is depleted, both the sprite and blocker disappear and the revealed meadow immediately communicates the new route.

## Economy placement

Each faction receives the same six-node Jade/Essence progression under 180-degree rotation:

- A safe Jade and Essence pair sits inside the starting sanctuary for a reliable opening.
- A richer Jade node and Essence shrine sit in the near jungle, rewarding the first expansion.
- A high-yield Jade node and Essence shrine sit closer to river approaches, creating contestable economic pressure before a base assault.

The starting Jade node is close enough to preserve the existing worker-harvest cadence. Resource glades are statically walkable and accessible from more than one adjacent cell, while their resource entities still block their occupied cells through the simulation's normal pathfinding rebuild.

The Lumber implementation adds 36 easily reached trees per territory around the authored meadow glades and converts the remaining jungle into 944 more harvestable trees. Each tree begins as a normal resource blocker and opens its occupied cell when depleted. Small edge clearings support early War Camp placement; deeper logging creates cross-jungle reinforcement routes later in the match.

## Camera, fog, and navigation usability

The initial camera frames the player's sanctuary at a scale derived from the enlarged map rather than centering on empty mid-map terrain. Zoom extends down to 0.14 for a full strategic overview, while keyboard panning is faster to account for doubled dimensions.

The existing fog-aware minimap scales directly from `MapCatalog.SIZE`, so it automatically covers the 80 × 64 layout. It shows road, bridge, ridge, meadow, and river terrain with distinct colors, then projects standing trees as green entity markers while preserving visibility masking. Clicking or dragging inside it recenters the existing battlefield camera; it does not own or mutate gameplay state.

## GPT Image 2 asset plan

Three custom materials were generated using the built-in GPT Image 2 workflow and existing terrain only as visual references:

- `jade_forest.png`: dense jade broadleaf and bamboo canopy, retained in the generated asset inventory but superseded on this map by discrete tree sprites.
- `meridian_road.png`: worn ochre earth and pale pavers, seamless and full-frame.
- `moon_bridge.png`: pale weathered flagstone deck with jade seams, seamless and full-frame.

The immutable masters live under `assets/source/terrain/`. `tools/process_assets.py` alone creates their 512 × 512 WebP runtime derivatives and includes them in `asset-report.json` and `SHA256SUMS`. The source `.gdignore` remains unchanged.

## Verification and acceptance criteria

The implementation is complete when all of the following hold:

- The map is exactly 80 × 64 and every 40 × 32 authored macro-grid row has a matching width.
- Terrain and resource opportunities are rotationally fair.
- A 40 × 32 authored tree layer expands to exactly 1,016 harvestable blockers in meaningful jungle masses.
- The diagonal river remains continuous except for exactly three authored crossings.
- Roads and bridges are walkable but non-buildable; ridge and water remain static blockers.
- Every standing tree blocks navigation and construction, and its meadow cell reopens after depletion.
- Both stronghold footprints and every resource glade are valid.
- A static flood-fill and the simulation's A* navigation can connect the two territories.
- All 39 runtime assets import successfully.
- Focused simulation, projection, map, interaction, visibility, and asset tests pass.
- One native visual capture shows a legible starting base, terrain hierarchy, and unobstructed HUD.

Potential future additions—neutral jungle camps, regrowing groves, elevation, lane objectives, or movement-speed terrain—are intentionally deferred because they require new simulation rules and balance work rather than map-only presentation.
