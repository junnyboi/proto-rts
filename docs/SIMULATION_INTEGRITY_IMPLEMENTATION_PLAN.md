# Simulation Integrity Implementation Plan

## Scope and architectural constraint

These changes resolve five command, movement, and fog-of-war defects without weakening the authoritative simulation/view split. `RtsSimulation` remains the owner of orders, resource transfers, movement destinations, unit spacing, visibility, target eligibility, and AI knowledge. `Battlefield` and `BattlefieldMinimap` only project the player team's simulation state and provide interface feedback.

## 1. Range-safe resource deposits

### Invariant

A worker's cargo can increase a player's stockpile only while that worker is within `WORKER_INTERACTION_RANGE` of the footprint of its living, allied Stronghold.

### Implementation

- Reuse `_entity_footprint_distance()` for both manual and automatic drop-off checks so large structures have consistent interaction geometry.
- Keep `command_deposit()` synchronous only for workers already in range.
- For a valid carrying worker outside the range, issue the existing `return` order without changing stockpiles or cargo.
- Update the Stronghold right-click interaction so a scheduled return is not overwritten by the generic ground-move fallback.
- Preserve the method's return value as the number of workers that deposited immediately.

### Regression coverage

- A remote command leaves the stockpile and cargo unchanged and starts a return order.
- Advancing the simulation causes the worker to travel, deposit once in range, and clear its cargo.
- An adjacent worker still deposits immediately.

## 2. Cargo-type integrity

### Invariant

When `cargo_amount` is positive, newly gathered resources must have the same kind as `cargo_kind`. Reassignment can change a worker's intended source, but it cannot relabel cargo already being carried.

### Implementation

- When a worker carrying one kind is assigned to a different resource, retain the new `gather_source_id` but start a return before gathering it.
- After deposit, resume the remembered gather source through the existing return-to-source transition.
- Add a defensive gather-tick check that starts a return if an incompatible source reaches the update loop.
- Set `cargo_kind` only when beginning an empty load; never overwrite it while cargo remains.

### Regression coverage

- Reassign a Lumber-carrying worker to Jade and verify that Lumber is banked first.
- Verify the cargo never changes to Jade while the Lumber amount remains.
- Verify the worker resumes the Jade source after returning its Lumber.

## 3. Persistent attack-move destinations

### Invariant

An attack-move order owns a final destination independently from its transient combat target and chase path.

### Implementation

- Add `attack_move_destination` to unit state and set it to each unit's assigned formation cell.
- Clear this field for direct attacks and all non-attack-move commands.
- Allow acquisition to replace `target_id` and `path` without replacing the saved destination.
- When a target dies or becomes ineligible, reacquire a visible enemy; if none exists, rebuild the route to the saved destination.
- End the attack-move cleanly when that destination is reached.

### Regression coverage

- Issue attack-move past a nearby enemy, allow the unit to chase and kill it, and verify the unit resumes toward the original formation destination.

## 4. Scalable formations and local separation

### Invariant

Every commandable unit in a group receives a unique walkable destination when enough walkable map cells exist. Actively moving allied units and allied building footprints do not block one another, but allied units that have both stopped spread apart whenever nearby walkable space permits. Hostile and neutral unit pairs remain locally separated.

### Implementation

- Replace the fixed 3-by-3 offset list with deterministic expanding square rings.
- Filter ring candidates for map bounds, static walkability, and uniqueness before assignment.
- Run a deterministic pairwise separation pass after movement. Accumulate symmetric displacements, apply them simultaneously, and reject candidates that enter static obstacles or leave the map.
- Use stable unit-id ordering and deterministic fallback directions for exact overlaps so fixed-tick results remain reproducible.
- Temporarily remove allied structures from A* solidity while calculating an allied unit's route, then restore the shared grid immediately after the path is captured.
- Skip local separation for same-team pairs while either unit has an active path; resume separation on the first tick where both paths are exhausted.
- Apply the policy uniformly to Workers, Hunters, Vanguards, Mystics, and aligned Jadeclaws while retaining separation against enemies and neutral wildlife.
- Convert penetration corrections into bounded per-entity separation velocity. Integrate that velocity over the fixed tick, apply exponential damping, and clear sub-threshold residual velocity so post-arrival spreading eases out instead of snapping or drifting indefinitely.
- Clear stale separation velocity on an active path when no hostile or neutral correction is required, preserving authoritative path motion and allied passthrough.
- Tune base travel speeds by role: Workers move at 1.30 cells per second and remain slower than Hunters, Vanguards, Mystics, and aligned Jadeclaws for every faction, including after the Beast movement bonus.
- Give Workers a heavier idle-settling profile with lower separation stiffness, stronger damping, and a lower speed cap. Give combat units higher stiffness, lighter damping, and a higher cap so formations resolve more responsively without reintroducing snapping.

### Regression coverage

- A group larger than nine receives unique saved destinations and paths.
- Every playable unit class can traverse a line containing every friendly unit class without displacing idle blockers.
- Every pair of idle friendly unit classes spawned at the exact same position separates after a simulation tick.
- Every playable unit class routes through an allied structure, while an enemy structure remains path-blocking.
- A Worker and enemy unit spawned together still separate.
- The first idle-separation tick produces visible but partial progress, all friendly class pairs converge within a bounded interval, and residual separation velocity decays to zero.
- Every faction's Worker is slower than every controllable combat role, a Vanguard visibly outpaces a Worker over an equal one-second route, and combat separation advances faster than Worker separation on the first idle tick.

## 5. Simulation-authoritative fog and knowledge

### Invariant

Each playable team has its own current visibility and persistent exploration state. Entity-targeting decisions can use only information permitted by that state. Presentation fog may hide or reveal drawing, but it cannot change simulation knowledge.

### Implementation

- Maintain visible and explored cell dictionaries per playable team in `RtsSimulation`.
- Recompute visibility from living allied units and structures using the existing radii: six cells for structures, five for Mystics, and four for other entities.
- Refresh once per fixed tick after movement, so the next tick's target eligibility and the published view state use authoritative positions without duplicating the entity scan.
- Require current visibility for direct attacks, automatic enemy acquisition, and continued pursuit.
- Require exploration for static resource and cave knowledge; the AI scouts with ground attack-move orders when no objective is known and uses attack-move toward known locations when the specific occupant is not currently visible.
- Expose read-only visibility/exploration queries and snapshots to presentation code.
- Replace `Battlefield`'s visibility calculation with snapshots from the simulation. Keep `fog_enabled` as a rendering-only override.

### Regression coverage

- Player and enemy visibility are distinct and exploration persists after vision moves away.
- Hidden enemies cannot be directly targeted or automatically acquired, even with a large acquisition distance.
- Once revealed, the same target becomes eligible; after it leaves vision, pursuit stops or attack-move resumes.
- Battlefield and minimap queries match the simulation-owned player visibility while the fog toggle affects rendering only.

## Verification gates

1. Run `tools/run_tests.sh` for simulation, projection, interaction, visibility, map, and asset regressions.
2. Run the native `tests/visual_capture.gd` harness once because battlefield fog projection and group positioning changed.
3. Inspect the final diff to ensure unrelated map and documentation work remains untouched.
